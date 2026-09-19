# CircleWarp Bug Hunt - Notes

## Architecture Summary

CircleWarp is a bonding curve token launchpad on Arc (Circle's USDC-native L1). 

### Core Contracts

1. **Factory/Implementation**: `0x34988939648578a1d90Db742bc1C903fD6F7c1b0` (39KB)
   - Implementation contract with launchpad logic
   - Key functions: `createToken()`, `buy()`, `sell()`, `migrate()`
   - Bonding curve parameters: virtualTokens, virtualUsdc, graduationMcap
   - Fee collection: protocol fees (`feeBps`, `withdrawFees()`) + creator fees

2. **Factory Proxy**: `0x0dCad158e98bC24455f9e94F46709d8a5F6D1255` (proxy)
   - Active factory instance
   - 513 tokens created
   - Creates token instances

3. **Uniswap V4 Integration**:
   - PoolManager: `0x8366a39cc670b4001a1121b8f6a443a643e40951` (5.2M USDC balance)
   - V4 Router: `0x53bf6b0684ec7ef91e1387da3d1a1769bc5a6f77`
   - Migration target for graduated tokens

4. **V2 Router**: `0x33c2bfa0684342b210b62ca7e92abe3fecb0bfa3`

### Product Flow

1. **Launch**: Creator calls `createToken(name, symbol, uri, createFee)` on factory
2. **Trading**: Users `buy(minOut)` and `sell(amount, minOut)` against bonding curve
3. **Graduation**: When marketCap reaches `graduationMcap`, anyone calls `migrate()`
4. **Migration**: Token graduates to Uniswap V4 pool with liquidity

### Key Attack Surfaces (Launchpad-specific)

Based on Step 6 launchpad attack questions:

#### A. Graduation/Migration to DEX Pool
- **Classic vulnerability**: Pool squat attack (Uniswap V3 pattern)
  - If `migrate()` calls `createAndInitializePoolIfNecessary` without price check
  - Attacker pre-creates pool at fake price (requires 0 tokens in V4)
  - Migration dumps bonding curve liquidity into manipulated pool
  - **CRITICAL if** migration has `amount0Min/amount1Min = 0` and no post-init `slot0()` check

#### B. LP Lock / Fee Split
- Where does graduated LP go? 
- Can LP be stolen/rug pulled after migration?
- Fee split between creator/protocol/liquidity

#### C. Single-sided vs Raise-holding Model
- Does bonding curve hold USDC or is it single-sided?
- Token reserve accounting vs actual balance

#### D. Anti-snipe / Transfer Restrictions
- Can bots front-run `createToken()` transactions?
- Transfer restrictions during bonding curve phase?

#### E. Bonding Curve Math
- Virtual reserve manipulation
- Rounding in buy/sell
- First buyer advantage
- Slippage protection (`minOut` parameter usage)

## Key Questions to Answer

### Critical Priority (Migration/Graduation Flow)

1. **Pool squat check**: Does `migrate()` verify pool price after creation?
   ```solidity
   // VULNERABLE pattern:
   pool = createAndInitializePoolIfNecessary(...);
   addLiquidity(..., amount0Min: 0, amount1Min: 0);  // NO PRICE CHECK
   
   // SAFE pattern:
   pool = createAndInitializePoolIfNecessary(...);
   (sqrtPriceX96, , ,) = pool.slot0();
   require(sqrtPriceX96 == expectedPrice, "price mismatch");
   addLiquidity(...);
   ```

2. **Who can call migrate()?** Permissionless or owner-only?

3. **What happens to LP tokens after migration?** 
   - Burned? 
   - Sent to creator?
   - Locked in contract?

4. **Are there slippage protections in migration?**

### High Priority (Bonding Curve Accounting)

5. **Virtual reserve accounting**: Can reserves be manipulated?
   - `virtualTokens` vs actual token balance
   - `virtualUsdc` vs actual USDC balance
   - Direct donation attack surface

6. **Buy/sell math**: Rounding direction, overflow checks

7. **Fee on transfer**: Does bonding curve handle fee-on-transfer tokens?

8. **First depositor inflation**: Can attacker inflate price via donation?

### Medium Priority (Access Control & Edge Cases)

9. **Graduation threshold bypass**: Can attacker prevent migration?

10. **Reentrancy**: CEI pattern in buy/sell/migrate

11. **Fee extraction**: Can owner/creator drain accumulated fees unfairly?

## Analysis Plan

### Step 5 - Foundation Map (in progress)
- [ ] Map state variables (virtualTokens, virtualUsdc, usdcReserve, graduated, migrated)
- [ ] External call order in buy/sell/migrate
- [ ] Token paths: user → bonding curve → Uniswap V4
- [ ] Access control gates

### Step 5.5 - Multi-angle Adversarial Pass
Focus on **migration flow** (highest risk for launchpad):
- Angle 1: Malicious actor pre-creates V4 pool at wrong price
- Angle 2: Economic - rounding in bonding curve, virtual reserve manipulation
- Angle 3: State - reentrancy in migrate, double-migration
- Angle 4: Edges - graduation threshold manipulation, DoS migration
- Angle 5: External - V4 pool creation assumptions

### Step 6 - Bug-class Hunt
Priority: **Migration pool squat (v3 → v4 variant)**

## Sources

- [Chainstack Arc Guide](https://chainstack.com/what-is-arc/)
- [Arc Documentation](https://docs.arc.io/)
- Chain ID: 5042 (verified via cast)
- RPC: https://rpc.mainnet.arc.io

## Status

- Chain verified: ✓
- Factory found: ✓
- Auth triage: ✓ (all admin functions guarded)
- Unverified contracts: Source needed for deep analysis
- Next: Disassemble bytecode OR find verified source OR test migration flow via live tokens
