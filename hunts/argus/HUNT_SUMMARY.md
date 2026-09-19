# Argus Launchpad Bug Hunt - Session Summary

## Target
- **Project**: Argus (ArgusPad) - Token launchpad on Arc Chain
- **Website**: https://argus.world
- **Chain**: Arc mainnet (Chain ID 5042, Circle's USDC-native L1)
- **Market Position**: Dominates Arc with 86% of token launches, 49% of DEX volume

## Contracts Identified
1. **ARGUS Token** (ecosystem token): `0xeCe5cA8bf9220718E5727754026757512212cb3c`
2. **Implementation**: `0x122c82cfca7a3a2227285cc21f4522e8f551db3a` (EIP-1167 proxy pattern)
3. **Owner**: `0x7d613c6316eDe9d257f3BF512777Cb4Ea4A6beE4`
4. **Tax Processor**: `0x863a810de5D1b9AB8E853DBB6218fabfA5Fc6d61`

## Architecture Analysis

### Token Model
- **Pattern**: pump.fun-style bonding curve → Uniswap V3 graduation
- **Tax System**: 1% buy / 1% sell (100 basis points each)
- **Graduation Status**: Not yet graduated (token0() call reverts)
- **Total Supply**: 1e27 (1 billion tokens)

### Key Functions Identified
| Function | Selector | Risk Level | Purpose |
|----------|----------|------------|---------|
| `graduate()` | `0xd3618cca` | **CRITICAL** | Migrates bonding curve to Uniswap V3 |
| `swapBack(uint256,uint256)` | `0x751f978c` | Medium | Swaps accumulated taxes |
| `setShare(address,uint256)` | `0x14b6ca96` | High | Sets holder reward share |
| `taxProcessor()` | `0xf3635019` | Low | Returns tax collector address |
| `currentTaxes()` | `0xeb1e7387` | Low | Returns current tax rates |
| `uniswapV3SwapCallback()` | `0xfa461e33` | High | V3 callback handler |

## Security Testing Performed

### ✅ Step 1: Ground Truth
- RPC confirmed alive: https://rpc.mainnet.arc.io
- Chain ID verified: 5042
- Current block: 21,636,875+

### ✅ Step 2: Contract Location
- Located ARGUS ecosystem token
- Identified EIP-1167 minimal proxy pattern
- Found implementation contract

### ✅ Step 3: Surface Map
- Extracted function selectors from bytecode
- Identified 20+ functions via PUSH4 analysis
- Mapped key launchpad mechanisms

### ✅ Step 4: Auth Triage
**All critical functions are properly guarded:**
- `graduate()` - REVERTS from attacker ✓
- `swapBack()` - REVERTS from attacker ✓  
- `setShare()` - REVERTS from attacker ✓

No missing access control vulnerabilities found.

## Critical Unknowns (Blocked by Unverified Code)

### 🔴 HIGH PRIORITY: Pool Squat Vulnerability
**Question**: Does `graduate()` validate the Uniswap V3 pool price after creation?

**Risk**: Bug Class #1 from launchpad patterns:
- Attacker pre-creates the pool at a manipulated price
- `graduate()` calls `createAndInitializePoolIfNecessary()` 
- If no price check exists, liquidity dumps into the fake-priced pool
- All token holders suffer catastrophic loss

**Status**: CANNOT VERIFY without source code or deep bytecode decompilation

**Why It Matters**: This is the #1 launchpad vulnerability. Examples:
- Requires zero capital (create empty pool)
- One-time attack during graduation
- Affects entire token supply
- Similar to hood.fun graduation bugs

### 🟡 MEDIUM PRIORITY: Other Unverified Risks

1. **UniswapV3 Callback Validation**
   - Does `uniswapV3SwapCallback()` verify caller is authentic pool?
   - Risk: Flash loan manipulation, fake callback attacks

2. **Tax Manipulation Post-Graduation**
   - Can owner change tax rates after pool is live?
   - Risk: Rug via tax increase on existing holders

3. **Reentrancy in swapBack**
   - Are checks-effects-interactions followed?
   - Risk: Reentrancy during tax swaps

4. **Holder Rewards Logic**
   - How does `setShare()` affect distribution?
   - Risk: Preferential allocation to insiders

## Coverage Assessment

### What We Verified
- ✅ Access control on critical functions
- ✅ Function signatures and contract structure
- ✅ Tax rates and ownership
- ✅ Graduation status (not yet graduated)
- ✅ EIP-1167 proxy pattern

### What We Cannot Verify (No Source)
- ❌ Pool price validation in graduate()
- ❌ Callback authentication
- ❌ CEI compliance in swapBack
- ❌ Complete graduation flow logic
- ❌ Holder reward calculation accuracy

**Coverage**: ~30% (surface-level + auth only)

This is NOT a complete audit. The implementation contract is unverified,
preventing analysis of critical business logic.

## Recommendations

### For Argus Team
1. **Verify the implementation contract** on arcscan.app
2. Get independent audit of graduation mechanism
3. Add pool price validation if missing
4. Consider time-lock on tax parameter changes

### For Users/Traders
1. **High Risk**: Trading tokens before graduation due to unverified pool squat risk
2. Wait for source verification or third-party audit
3. Do not provide liquidity until contracts are verified
4. Be aware this launchpad dominates 86% of Arc - systemic risk

### For This Hunt
**Next Steps if Continuing**:
1. Use Panoramix or Dedaub decompiler on implementation
2. Manually trace graduate() execution flow
3. Create fork test: pre-create pool → call graduate() → check behavior
4. Look for other launchpad tokens using same implementation

## Files Generated
- `INTAKE.md` - Hunt metadata and progress
- `AUTH_TRIAGE.md` - Access control test results
- `NOTES.md` - Investigation blockers
- `function_analysis.txt` - Function inventory
- `coverage.md` - Coverage tracking (empty, source needed)
- `HUNT_SUMMARY.md` - This file

## Time Investment
- Initial reconnaissance: ~30 min
- RPC/chain validation: ~10 min
- Contract analysis: ~45 min
- Bytecode function extraction: ~25 min
- Auth testing: ~15 min
- Documentation: ~20 min

**Total**: ~2.5 hours

## Conclusion

**Auth Baseline**: PASS (all critical functions guarded)
**Pool Squat Risk**: UNKNOWN (blocked by unverified source)
**Recommendation**: DO NOT TRADE until source verified

This hunt identified the attack surface but cannot verify the #1 critical
vulnerability (pool squat) without source code access or significant
additional reverse engineering effort.

---
**Researcher**: deviykee (Iyke)
**Date**: 2026-09-19
**Status**: Incomplete - awaiting source verification
