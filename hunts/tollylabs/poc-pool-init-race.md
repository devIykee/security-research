# Finding Verification: Pool Initialization Front-Running

## Hypothesis
An attacker can front-run TollyPad.createToken() by calling pool.initialize() with a malicious price before the legitimate launch transaction, breaking the single-sided launch model.

## Attack Sequence

1. **Victim**: Broadcasts createToken(name, symbol, meta, salt, devBuyQuote)
2. **Attacker monitors mempool**: Extracts transaction parameters
3. **Attacker computes**: 
   - seed = keccak256(abi.encode(msg.sender, salt))
   - Tries each salt from seed to seed+63
   - For each, computes token address via CREATE2
   - Identifies which one will pass the checks
4. **Attacker computes pool address**: 
   - pool = v3Factory.getPool(predictedToken, USDC, 10000)
   - OR uses Uniswap V3 pool address derivation formula
5. **Attacker front-runs**: 
   - Calls v3Factory.createPool(predictedToken, USDC, 10000) (if needed)
   - Calls pool.initialize(maliciousSqrtPriceX96)
6. **Victim transaction executes**:
   - Line 293-299: Token deploys at predicted address ✓
   - Line 305: getPool returns attacker's pool address
   - Line 306: Skipped (pool already exists)
   - Line 307: setPool(attackerPool) - token points to compromised pool ✓
   - Line 311: `existing = attackerPrice` (sqrtPriceX96 from slot0)
   - Line 312: `if (existing == 0)` → FALSE, initialization skipped
   - Line 315: _mintSingleSided proceeds at attacker's price

## Impact Analysis

### Case 1: Attacker initializes BELOW intended tickFloor

**Setup**:
- Intended range: [tickFloor, tickCeil] representing [startFdv, topFdv]
- Attacker initializes at tickMalicious < tickFloor

**Result**:
- Current pool price: tickMalicious
- Mint range: [tickFloor, tickCeil]
- Since currentTick < tickFloor, the range is ABOVE current price
- Position is 100% token (correct side)
- BUT position is INACTIVE until price crosses tickFloor

**Consequences**:
1. First buyers trade with ZERO liquidity until price reaches tickFloor
2. Massive slippage, likely reverts
3. OR price moves instantly from tickMalicious to tickFloor with near-zero USDC spent
4. Attacker buys entire supply for pennies

**This is a CRITICAL vulnerability** - complete launch theft.

### Case 2: Attacker initializes ABOVE intended tickCeil

**Setup**:
- Intended range: [tickFloor, tickCeil]
- Attacker initializes at tickMalicious > tickCeil

**Result**:
- Current pool price: tickMalicious  
- Mint range: [tickFloor, tickCeil]
- Since currentTick > tickCeil, the range is BELOW current price
- Position would be 100% USDC (wrong side!)

**Consequences**:
- Line 452-454 in _mintSingleSided checks which side was used
- Line 457: `if (quoteUsed != 0) revert NotSingleSided()`
- **Transaction REVERTS** - DoS, but no theft

### Case 3: Attacker initializes AT tickFloor (or very close)

**Setup**:
- Intended initTick: tickFloor
- Attacker initializes at tickFloor + epsilon

**Result**:
- Close to intended price
- Mint succeeds normally
- Attacker wasted gas

**No impact** if attacker chooses same price.

## Realistic Attack Cost

**Requirements**:
- Monitor mempool: Free (MEV infrastructure)
- Compute predicted address: Trivial (keccak256)
- Front-run transaction: Standard MEV
- Gas for createPool: ~500k gas
- Gas for initialize: ~50k gas
- Total: ~550k gas (~$X depending on gas price)

**Profit**:
If launch has targetStartFdv = $10k and attacker can buy at 100x cheaper:
- Steal ~99% of token supply
- Profit = $9,900 minus gas cost
- **Highly profitable at scale**

## Kill Conditions

Need to verify:
1. ✓ Can pool be created for not-yet-deployed token? **YES** - Uniswap V3 allows this
2. ✓ Can pool be initialized before TollyPad does it? **YES** - initialize() is permissionless  
3. ✓ Does TollyPad check if already initialized? **YES** - Line 312 checks `existing == 0`
4. ✓ Does mint proceed if wrong price? **DEPENDS** - reverts if price too high (needs USDC), succeeds if too low (inactive position)
5. ? Is there any protection against front-running I missed?

## Check for Additional Protections

Looking for:
- [ ] Transaction deadline parameter?
- [ ] Expected price parameter?
- [ ] Pool address verification?
- [ ] Two-step launch pattern?

Reading lines 255-350...
