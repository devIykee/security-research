# Critical Finding Analysis: Pool Initialization Race

## Trace of TollyPad.createToken Pool Handling

### Step-by-Step Execution

```solidity
// STEP 1: CREATE2 address prediction and validation (lines 281-291)
uint256 seed = uint256(keccak256(abi.encode(msg.sender, salt)));
uint256 tries;
address predicted;
for (; tries < MAX_SALT_TRIES;) {
    predicted = _computeTokenAddress(bytes32(seed), initCodeHash);
    if (v3Factory.getPool(predicted, address(quote), POOL_FEE) == address(0) && predicted.code.length == 0) {
        break;  // Found clean address
    }
    unchecked { ++tries; ++seed; }
}
if (tries == MAX_SALT_TRIES) revert LaunchGriefed();
```

**Time T0**: CHECK - Pool doesn't exist for predicted address

```solidity
// STEP 2: Deploy token (lines 293-299)
token = address(
    new TollyToken{salt: bytes32(seed)}(...)
);
assert(token == predicted);
```

**Time T1**: Token deployed at predicted address

```solidity
// STEP 3: Pool creation (lines 305-307)
address pool = v3Factory.getPool(token, address(quote), POOL_FEE);
if (pool == address(0)) pool = v3Factory.createPool(token, address(quote), POOL_FEE);
TollyToken(token).setPool(pool);
```

**Time T2**: CREATE pool (if doesn't exist)
**Time T3**: Set pool in token

```solidity
// STEP 4: Pool initialization (lines 311-312)
(uint160 existing,,,,,,) = IV3PoolPad(pool).slot0();
if (existing == 0) IV3PoolPad(pool).initialize(TickMath.getSqrtRatioAtTick(initTick));
```

**Time T4**: INITIALIZE pool (only if not already initialized)

```solidity
// STEP 5: Mint single-sided LP (lines 315-316)
(uint256 lpTokenId, uint128 liquidity, uint256 tokenSeeded) =
    _mintSingleSided(token, tokenIs0, tickLower, tickUpper);
```

**Time T5**: Mint LP position at current pool price

## Attack Vector Analysis

### TOCTOU Window 1: Between T0 (check) and T2 (create)

**Attacker action**: Monitor mempool, see createToken tx with salt X
1. Extract predicted token address from (msg.sender, salt)
2. Front-run: deploy dummy contract at predicted address
3. Result: Line 286 `predicted.code.length == 0` fails on next iteration
4. Force all 64 salts to be consumed (deploy 64 dummy contracts)
5. Victim tx reverts with LaunchGriefed

**Cost**: 64 contract deployments * gas (~100-200k gas each = 6.4-12.8M gas)
**Impact**: DoS only, no theft
**Severity**: Medium (expensive grief)

**BLOCKED**: Cannot deploy contract at CREATE2 address before the CREATE2 actually happens (predictable address, but can't preempt the actual deployment).

**WAIT - Re-analyzing**: Attacker can't deploy at the predicted address BEFORE the token deploys there. But attacker CAN:
1. See the transaction
2. Predict the 64 possible addresses
3. Front-run and CREATE POOLS for all 64 addresses (pool creation doesn't require token to exist!)

**Uniswap V3 Factory allows pool creation for not-yet-deployed tokens!**

So the attack is:
1. Monitor mempool for createToken(name, symbol, meta, salt, devBuy)
2. Compute seed = keccak256(abi.encode(msg.sender, salt))
3. Compute all 64 possible token addresses from seed, seed+1, ..., seed+63
4. Front-run with 64 x `v3Factory.createPool(predicted[i], quote, fee)` transactions
5. Victim's line 286 check fails for all 64 salts
6. Victim tx reverts with LaunchGriefed

**This is CONFIRMED - DoS vulnerability**.

### TOCTOU Window 2: Between T2 (pool create) and T4 (pool initialize)

**Attacker action**: 
1. Monitor mempool for createToken tx
2. Wait for T2 (pool created) - or extract pool address from tx calldata
3. Front-run: call pool.initialize(attackerPrice)
4. Victim's T4 check: `existing != 0`, skips initialization
5. Victim's T5: mints LP at attacker's price

**Problem**: Can attacker call pool.initialize() before the createToken transaction does?

**Uniswap V3 pool.initialize() is permissionless!** Any address can initialize an uninitialized pool.

So the attack is:
1. Monitor mempool for createToken(...)
2. Extract token address (will be deployed in the tx) and compute pool address
3. Front-run with pool.initialize(maliciousPrice)
4. Victim's line 311-312: existing != 0, skip initialization
5. Victim's line 315: mint at malicious price

**Impact**: 
- If maliciousPrice is far from intended startFdv, the single-sided mint will fail safety checks
- Line 457: `if (quoteUsed != 0) revert NotSingleSided()` - if price is wrong, mint consumes USDC
- Line 458: `if (liquidity == 0 || tokenUsed < supply - supply/1000) revert SeedFailed()` - wrong price may mint tiny liquidity

**WAIT - Checking lines 302 and 500-501**:

```solidity
bool tokenIs0 = token < address(quote);
(int24 tickLower, int24 tickUpper, int24 initTick) = _rangeFor(tokenIs0);

function _rangeFor(bool tokenIs0) internal view returns (int24 tickLower, int24 tickUpper, int24 initTick) {
    if (tokenIs0) return (tickFloor, tickCeil, tickFloor);
    return (-tickCeil, -tickFloor, -tickFloor);
}
```

So the intended init tick is tickFloor (or -tickFloor if token > quote).

The range is [tickFloor, tickCeil] (or [-tickCeil, -tickFloor]).

**If attacker initializes at a price OUTSIDE this range**, the mint will:
- Line 439-440: tickLower, tickUpper are the intended range
- positionManager.mint with these ticks
- If current price is outside [tickLower, tickUpper], the mint will be 100% USDC or 100% token depending on direction

**If attacker initializes at a price FAR ABOVE tickCeil**:
- Current price > tickCeil
- Range is [tickFloor, tickCeil], all BELOW current price
- Mint will consume 100% USDC, 0% token
- Line 457 check: `quoteUsed != 0` → **REVERTS**

**If attacker initializes at a price FAR BELOW tickFloor**:
- Current price < tickFloor
- Range is [tickFloor, tickCeil], all ABOVE current price
- Mint will consume 0% USDC, 100% token (this is intended!)
- But line 458 check tokenUsed >= supply * 99.9% would pass
- LP is minted at wrong price, creator is offering tokens far cheaper than intended

**ATTACK CONFIRMED**: 
1. Front-run pool.initialize() at price far below tickFloor
2. Mint succeeds (single-sided token, check passes)
3. Pool opens at attacker's price instead of intended startFdv
4. Attacker immediately buys the underpriced tokens

**BUT WAIT - checking line 312 more carefully**:

```solidity
(uint160 existing,,,,,,) = IV3PoolPad(pool).slot0();
if (existing == 0) IV3PoolPad(pool).initialize(TickMath.getSqrtRatioAtTick(initTick));
```

The check is `existing == 0`. In Uniswap V3, slot0 returns (sqrtPriceX96, tick, ...). If the pool is initialized, sqrtPriceX96 > 0.

So if attacker calls pool.initialize(attackerPrice), then:
- existing = attackerPrice (sqrtPriceX96)
- Line 312 check: existing == 0? FALSE
- Initialization skipped
- Pool remains at attackerPrice

**THEN** at line 315, the mint happens at attackerPrice.

**If attackerPrice is at exactly tickFloor**: Mint works as intended, just attacker wasted gas.

**If attackerPrice is below tickFloor**: 
- Mint at [tickFloor, tickCeil] when current price < tickFloor
- Mint consumes 100% token (correct), 0% USDC (correct)
- But post-mint, the pool price is STILL attackerPrice (mint doesn't move price if minting into inactive range)
- First buy will happen at attackerPrice, not tickFloor

**NO - Uniswap V3 mint DOES affect price if minting into the active tick!**

Let me reconsider: If current price is P0 (attacker's price) and we mint a position at range [tickFloor, tickCeil]:

- If P0 < tickFloor: Position is 100% token, inactive. Price stays P0. First swap will move through [P0, tickFloor] with no liquidity, then hit the position.

**Actually, this BREAKS the launch**. The single-sided position is supposed to be active from the first trade. If attacker initializes below tickFloor, the position is inactive until price crosses into range.

**CRITICAL FINDING CONFIRMED**: Pool initialization front-running breaks the single-sided launchpad model.
