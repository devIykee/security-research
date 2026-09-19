# Key Attack Surface Analysis

## Based on Documentation and ABI Analysis

### Finding #1: Potential Pool Squat (Needs Source Code Verification)

**Pattern**: Launchpad graduation pool manipulation

**The Flow**:
1. User buys enough tokens to complete the bonding curve
2. This triggers automatic graduation in the same transaction
3. Graduation calls `lister.listPool(token0, token1, abi.encode(sqrtPriceX96))`
4. Lister creates pool and sets initial price
5. Launch verifies it got the right pool at the right price

**Docs claim**: "Graduation reverts if the target pool already exists"

**Critical Question**: WHEN does it check?
- **Safe**: Check BEFORE calling lister (pool exists → revert)
- **Vulnerable**: Check AFTER calling lister (pool created with wrong price → too late)

**Mitigation mentioned**: "constant-product pools aren't open to public listing"
- Need to verify Public Lister actually blocks CP (type 1) pools
- CurveNotOpen error in ABI suggests this protection exists

**To confirm vulnerability status, I need**:
- Source code of LunyaLaunchCP graduation logic
- Source code of Terms Lister to see if it checks pool existence first
- Confirmation that Public Lister blocks CP pools

### Finding #2: Access Control on Launch Factory Admin Functions

**Functions requiring investigation**:
- `openPool()` - who can call this? Missing onlyOwner?
- `depositFees()` - anyone can deposit fees for any token?
- `sweepFees()` - anyone can sweep (sends to feeRecipient, but timing control?)

### Finding #3: Liquidity Locker - Only DEPOSITOR Can Lock

From ABI error: `NotDepositor`
- Only the hardcoded DEPOSITOR address can call `lock()`
- If DEPOSITOR is the Launch Factory, this should be fine
- But if DEPOSITOR can be manipulated or is not the factory, positions could be locked by wrong party

**Need to verify**: DEPOSITOR address in Liquidity Locker

### Finding #4: Implementation Upgrade Risk

`setImplementation()` allows owner to change launch implementation
- This could rug existing launches if they use delegatecall to implementation
- Or it might only affect NEW launches (safer)
- Need source code to determine impact

## Next Steps
1. Get source code for graduation flow verification
2. Test Public Lister CP pool restriction
3. Check DEPOSITOR address in Liquidity Locker
4. Examine openPool() access control
5. Review fee collection mechanisms

## Coverage Update Needed
- Files examined: ABIs only (LaunchFactory, LaunchCP, LiquidityLocker, PublicLister)
- Source code: NOT AVAILABLE YET (need to find or decompile)
- Current coverage: ABI analysis only (~10% confidence)
