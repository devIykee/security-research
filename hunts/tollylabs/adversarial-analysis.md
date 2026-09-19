# Multi-Angle Adversarial Analysis - Tolly Labs

## Angle 1: Malicious Actor (Drain/Payout Paths)

### Attack Path 1: Pool Initialization Price Manipulation
**Target**: TollyPad.createToken - pool initialization at launch

**Analysis**:
- Line 284-291: CREATE2 walk with up to 64 tries to find unpoisoned address
- Line 305-306: Creates pool if doesn't exist
- Line 311-312: Initializes pool at exact tick boundary (tickFloor or -tickFloor)

**Attack Vector**: Pre-create the pool at a malicious price before the creator launches
- Check: `v3Factory.getPool(predicted, quote, fee) == address(0)` at line 286
- If pool already exists with wrong price, line 312 skips initialization (existing != 0)
- Result: Launch proceeds with attacker's manipulated initial price

**Verification Needed**:
```solidity
// Line 311-312
(uint160 existing,,,,,,) = IV3PoolPad(pool).slot0();
if (existing == 0) IV3PoolPad(pool).initialize(TickMath.getSqrtRatioAtTick(initTick));
```

**CRITICAL FINDING**: If `existing != 0`, initialization is skipped. The single-sided mint at lines 315-316 would then mint at the WRONG price, potentially:
1. Requiring USDC instead of being pure token (breaking `quoteUsed != 0` check at line 457)
2. Consuming far less than expected token supply
3. Opening at attacker's price instead of intended startFdv

**Wait - check line 286**: `v3Factory.getPool(predicted, address(quote), POOL_FEE) == address(0)`

This checks pool doesn't exist BEFORE continuing. So if pool exists, the CREATE2 walk continues to next salt. BUT:

**ISSUE**: The walk only checks 64 salts. An attacker with sufficient compute could:
1. Monitor mempool for createToken transactions
2. Extract the (msg.sender, salt) seed from line 281
3. Compute all 64 possible token addresses
4. Front-run and create pools for all 64 addresses
5. Launch reverts with LaunchGriefed

**Severity**: Medium (DoS, not theft). Expensive attack (64 pool creations * gas), but permanent grief possible.

### Attack Path 2: Single-Sided Mint Manipulation
**Target**: TollyPad._mintSingleSided - LP position creation

**Analysis**:
```solidity
// Lines 443-444
amount0Min: 0,
amount1Min: 0,
```

**No slippage protection on the mint!** Combined with pool initialization check above:

**Scenario**: If pool somehow initialized at wrong price (bypass the line 286 check), the mint would:
- Accept any amount of tokens deposited
- Check only: `tokenUsed >= supply - supply/1000` (99.9% threshold at line 458)
- But if price is far off, this could consume USDC (violating line 457) OR mint tiny liquidity

**Blocked by**: Line 286 pool existence check in the CREATE2 walk, and line 312 only initializes if existing == 0.

**WAIT - RE-READING LINE 305-306**:
```solidity
address pool = v3Factory.getPool(token, address(quote), POOL_FEE);
if (pool == address(0)) pool = v3Factory.createPool(token, address(quote), POOL_FEE);
```

This CREATES the pool after CREATE2 succeeds. So the sequence is:
1. CREATE2 walk finds clean token address (no pool exists for it)
2. Line 305 checks if pool exists (should be address(0) since we just verified)
3. Line 306 creates the pool
4. Line 312 initializes it

**BUT RACE CONDITION**: Between line 291 (CREATE2 succeeds) and line 306 (pool creation), an attacker could:
1. Monitor pending transaction
2. Front-run with `v3Factory.createPool(token, quote, fee)` at attacker's address
3. Initialize the pool at malicious price
4. Victim's transaction hits line 305: pool != address(0) (attacker created it)
5. Line 306 skipped
6. Line 311-312: existing != 0, initialization skipped
7. Line 315: mint proceeds at WRONG price

**CRITICAL VULNERABILITY CONFIRMED**: Time-of-check-time-of-use (TOCTOU) race between:
- Line 286: Check pool doesn't exist for predicted address
- Line 305-306: Create pool (front-runnable)
- Line 311-312: Initialize pool (skipped if already initialized)

### Attack Path 3: Dev Buy Front-Running
**Target**: TollyPad._devBuy - atomic creator buy

**Analysis**:
```solidity
// Line 349
if (devBuyQuote > 0) _devBuy(token, pool, tokenIs0, tickLower, tickUpper, devBuyQuote);
```

**Attack**: Sandwich the launch transaction
1. Creator calls createToken with devBuyQuote = 100 USDC
2. Attacker frontruns: buy tokens from fresh pool
3. Creator's devBuy executes at worse price (pool moved)
4. Attacker backruns: sell for profit

**Slippage protection**: Line 473 sets sqrtLimit to tickUpper/tickLower, so the swap can't exceed the range. But within the range, no min-out check.

**Impact**: Creator pays more per token than intended, but bounded by the range (startFdv to topFdv).

**Severity**: Low-Medium (creator MEV loss, bounded by range, optional feature)

## Angle 2: Economic and Math

### Rounding and Fee Math
**TollyFeeLocker._distribute** (lines 266-272):

```solidity
uint256 tollyBurn = (amount * TOLLY_BURN_BPS) / BPS;    // 9%
uint256 toBurn = (amount * PROJECT_BURN_BPS) / BPS;      // 5%
uint256 toHolders = (amount * HOLDER_BPS) / BPS;         // 12%
uint256 toProtocol = (amount * PROTOCOL_BPS) / BPS;      // 10%
uint256 toCreator = amount - tollyBurn - toBurn - toHolders - toProtocol; // 64%
```

**Rounding**: Dust from integer division goes to creator (line 272 uses subtraction, not division). This is **correct** - no leak.

**Total check**: 900 + 500 + 1200 + 1000 + 6400 = 10000 BPS. Correct.

### Flash Loan / Temporary Balance Inflation
**Not applicable** - no balance-based logic for snapshots or rewards. Fees are collected from Uniswap position, not from balances.

### Internal Books vs Actual Balances
**TollyFeeLocker** - no internal accounting, only the Uniswap position. Fees are pulled directly from position manager (line 230-237).

**No desync risk** - single source of truth is the position.

## Angle 3: State and Access

### Missing Modifiers
Checked in foundation map. All privileged functions guarded:
- TollyPad: setBanned, transferOwnership → onlyOwner
- TollyToken: setPool → onlyPad (msg.sender == pad)
- TollyFeeLocker: initialize → onlyInitializer, register → onlyPad

### Reentrancy
**TollyPad.createToken**: ReentrancyGuard ✓
**TollyFeeLocker.collect**: ReentrancyGuard ✓
**TollyFeeLocker.claim**: ReentrancyGuard ✓

**Cross-function reentrancy**: 
- TollyFeeLocker._distribute (lines 256-374) has multiple external calls:
  - Line 277: furnace.depositToll
  - Line 286: treasury transfer
  - Line 294: holderVault transfer
  - Line 300: holderVault.call (bookAccrual)
  - Line 311: burner transfer
  - Line 348: payout.call (depositPrepaid)
  - Line 363: asset.call (transfer)

**All within one nonReentrant collect()**, so no cross-function reentrancy possible. Single guard covers the whole path.

### Re-init / Proxy Hijack
**TollyFeeLocker.initialize** (lines 169-201):
- Check: `msg.sender != initializer` revert
- Check: `furnace != address(0)` revert (already initialized)
- Effect: burns initializer key (line 199)

**No re-init possible** after first call. Safe.

## Angle 4: Edges

### Unbounded Arrays / Loops
**TollyPad.allTokens** (line 134): Grows unbounded, but only used in view `getTokens()` with offset/limit pagination (lines 543-549). Safe.

### block.timestamp Manipulation
**TollyToken anti-snipe** (line 59):
```solidity
antiSnipeDeadline = block.timestamp + antiSnipeSeconds_;
```

**Check** (line 83):
```solidity
if (block.timestamp <= antiSnipeDeadline && to != address(0) && !antiSnipeExempt[to]) {
```

**Miner can manipulate**: ~15 second window. Could extend anti-snipe by seconds, but not disable it or extend by hours. Low impact.

### Overflow/Underflow
**Solidity 0.8.26** - checked math by default. No unchecked blocks in value-moving paths.

**Tick math** (lines 528-535): Uses int24, bounded by Uniswap V3 tick range. Safe.

## Angle 5: External Integrations

### Uniswap V3 Pause/Revert
**If pool.swap reverts** (e.g., paused): _devBuy would revert, but launch would already be complete (swap is at line 349, after position minted).

**If positionManager.mint reverts**: Launch reverts. Clean rollback.

**If positionManager.collect reverts**: TollyFeeLocker.collect reverts. Fees stay in position. No loss, just delayed harvest.

### Furnace/Treasury/HolderVault Revert in Collect
**Lines 275-305**: Multiple external calls in _distribute

**Furnace.depositToll reverts** (line 277): Entire collect reverts. Fees stuck until furnace fixed.

**Treasury transfer reverts** (line 286): Entire collect reverts.

**HolderVault transfer reverts** (line 294): Entire collect reverts.

**HolderVault.bookAccrual reverts** (line 300): Ignored (non-reverting call). Funds delivered, booking failed. Safe.

**Burner transfer reverts** (line 311): Entire collect reverts.

**CRITICAL ISSUE**: If furnace, treasury, or any burner becomes unable to receive tokens (blacklist, contract bug, selfdestruct), **all fee collection for all tokens is permanently bricked**. No fees can ever be collected again.

**Payout.depositPrepaid reverts** (line 348): Handled gracefully, falls back to direct transfer (line 363). Safe.

**Payout transfer reverts** (line 363): Handled gracefully, parks in claimable (line 368). Safe.

### Weird ERC20 (USDC is the quote)
**USDC on Arc**: Standard Circle USDC, no fee-on-transfer, no rebase. Safe.

**Launched tokens**: Immutable TollyToken.sol, standard ERC20 + anti-snipe. No weirdness.

## Summary of Paths

| Attack Path | Blocked By | Result |
|-------------|------------|--------|
| Pool price manipulation (CREATE2 race) | Line 286 check, but TOCTOU window exists | **CRITICAL - Front-run pool creation** |
| 64-salt grief | Expensive (64 pool creates) | Medium DoS |
| Single-sided mint slippage | Pool initialized at exact tick | Blocked |
| Dev buy sandwich | Bounded by range, optional | Low-Med (creator loss) |
| Fee split rounding | Dust to creator by design | Blocked |
| Reentrancy | ReentrancyGuard on all entry points | Blocked |
| Furnace/treasury/burner revert DoS | No fallback if they revert | **HIGH - Brick all fee collection** |

## Confirmed Findings

### Finding 1: Pool Initialization Front-Running (CRITICAL)
**Root cause**: TOCTOU between CREATE2 address prediction and pool creation/initialization.

**Attack**: Attacker monitors mempool, extracts predicted token address, front-runs pool creation at malicious price.

**Impact**: Launch proceeds with wrong initial price, breaking single-sided invariant or consuming USDC.

**Need to verify with PoC**.

### Finding 2: External Call Revert DoS in Fee Collection (HIGH)
**Root cause**: TollyFeeLocker._distribute has no fallback if furnace/treasury/burner revert.

**Impact**: One malicious burner or broken furnace bricks fee collection for ALL tokens permanently.

**Need to verify scope** - is furnace per-token or global? Let me check the code again...
