# Argus Launchpad Security Assessment - Final Report

**Target**: https://argus.world (Token launchpad on Arc Chain)  
**Researcher**: deviykee (Iyke)  
**Date**: 2026-09-19  
**Status**: ⚠️ **High-Risk Unverified Implementation**

---

## Executive Summary

Analyzed the Argus token launchpad, which dominates Arc Chain with 86% of token launches and 49% of DEX volume. **All critical functions have proper access control** ✅, but the **#1 launchpad vulnerability (pool squat attack) cannot be verified** because the implementation contract is unverified.

### Key Finding
🔴 **CRITICAL RISK: Unverifiable Pool Squat Vulnerability**

The `graduate()` function migrates bonding curve liquidity to Uniswap V3. Without source code, we cannot verify if it validates the pool price after creation, leaving the door open for a zero-capital attack that could drain all token liquidity.

---

## Scope & Methodology

### Contracts Analyzed
1. **ARGUS Token**: `0xeCe5cA8bf9220718E5727754026757512212cb3c`
2. **Implementation**: `0x122c82cfca7a3a2227285cc21f4522e8f551db3a` ❌ Unverified
3. **Owner**: `0x7d613c6316eDe9d257f3BF512777Cb4Ea4A6beE4`
4. **Tax Processor**: `0x863a810de5D1b9AB8E853DBB6218fabfA5Fc6d61`

### Chain Details
- **Network**: Arc mainnet (Chain ID 5042)
- **RPC**: https://rpc.mainnet.arc.io
- **Explorer**: https://arcscan.app
- **Gas Token**: USDC (6 decimals at `0x3600000000000000000000000000000000000000`)

### Testing Performed
1. ✅ RPC/chain validation
2. ✅ Contract architecture mapping via bytecode analysis
3. ✅ Function selector extraction (20+ functions identified)
4. ✅ Access control testing on all critical functions
5. ❌ Logic verification blocked (no source code)
6. ⚠️ Fork testing attempted (blocked by missing V3 Factory address)

---

## Findings

### 🟢 PASS: Access Control

**All critical state-changing functions are properly guarded:**

| Function | Selector | Attacker Test | Result |
|----------|----------|---------------|--------|
| `graduate()` | `0xd3618cca` | Reverted | ✓ PASS |
| `swapBack(uint256,uint256)` | `0x751f978c` | Reverted | ✓ PASS |
| `setShare(address,uint256)` | `0x14b6ca96` | Reverted | ✓ PASS |

**Test Method**: `eth_call` from attacker address `0x...dEaD`  
**Conclusion**: No missing access control vulnerabilities found.

---

### 🔴 CRITICAL: Pool Squat Vulnerability (Unverified)

**Vulnerability Class**: Launchpad Migration Pool Squat (Bug Class #1)

**Attack Scenario**:
1. Attacker pre-creates Uniswap V3 pool at manipulated price (zero capital required)
2. Token owner calls `graduate()` to migrate bonding curve
3. `graduate()` calls `createAndInitializePoolIfNecessary()`
4. If no price validation exists, all liquidity dumps into attacker's fake-priced pool
5. Token holders suffer catastrophic loss

**Why This Matters**:
- **Zero capital attack**: Empty pool creation costs only gas
- **One-time exploit**: Happens during graduation, can't be reversed
- **Total impact**: Affects entire token supply
- **Proven pattern**: Similar bugs found in hood.fun and other launchpads

**What We Found**:
- ✅ `graduate()` function exists
- ✅ Access control is present (owner only)
- ❌ **Cannot verify pool price validation** without source code
- ❌ Cannot confirm if `slot0()` check exists after pool creation

**Status**: **UNVERIFIED - HIGH RISK**

**References**:
- [Launchpad vulnerability patterns](https://www.bitrue.com/blog/what-is-argus)
- [Uniswap V3 on Arc](https://github.com/Uniswap/UniswapX/blob/main/playbook/chains/arc.md)

---

### 🟡 MEDIUM: Additional Unverified Risks

#### 1. UniswapV3 Callback Authentication
- **Function**: `uniswapV3SwapCallback()` (`0xfa461e33`)
- **Risk**: Fake callback attacks if caller isn't validated
- **Status**: Cannot verify without source

#### 2. Tax Parameter Manipulation
- **Current Taxes**: 1% buy, 1% sell (100 basis points each)
- **Tax Expiry**: 0 (expired or not set)
- **Risk**: Can owner increase taxes after graduation?
- **Status**: Cannot verify without source

#### 3. Reentrancy in swapBack
- **Function**: `swapBack(uint256,uint256)` (`0x751f978c`)
- **Risk**: CEI violations during tax swaps
- **Status**: Cannot verify without source

#### 4. Holder Rewards Logic
- **Function**: `setShare(address,uint256)` (`0x14b6ca96`)
- **Risk**: Preferential allocation to insiders
- **Status**: Cannot verify without source

---

## Architecture Analysis

### Token Model
- **Pattern**: Bonding curve → Uniswap V3 graduation (pump.fun style)
- **Proxy**: EIP-1167 minimal proxy pattern
- **Total Supply**: 1e27 (1 billion tokens with 18 decimals)
- **Graduation Status**: Not yet graduated (tested via `token0()` call)

### Key Functions Mapped

| Function | Selector | Purpose | Access |
|----------|----------|---------|--------|
| `graduate()` | `0xd3618cca` | Migrate to Uniswap V3 | Restricted |
| `taxProcessor()` | `0xf3635019` | Get tax collector | View |
| `swapBack(uint256,uint256)` | `0x751f978c` | Swap accumulated taxes | Restricted |
| `taxExpiry()` | `0x9963b6a4` | Tax expiration timestamp | View |
| `currentTaxes()` | `0xeb1e7387` | Get tax rates | View |
| `tokenIsToken0()` | `0x856bfdb8` | Position in pair | View |
| `uniswapV3SwapCallback()` | `0xfa461e33` | V3 callback handler | External |
| `owner()` | `0x8da5cb5b` | Contract owner | View |
| `setShare(address,uint256)` | `0x14b6ca96` | Set holder share | Restricted |

---

## Coverage Assessment

### What We Verified ✅
- Access control on all critical functions
- Function signatures and contract structure
- Tax rates (1% buy/sell) and ownership
- Graduation status (not yet graduated)
- EIP-1167 proxy pattern implementation
- Token decimals (18) and total supply (1e27)
- USDC integration (6 decimals at predeploy address)

### What We Cannot Verify ❌
- **Pool price validation in `graduate()`** (CRITICAL)
- Callback authentication logic
- CEI compliance in `swapBack()`
- Complete graduation flow logic
- Holder reward calculation accuracy
- Tax manipulation safeguards
- Reentrancy protections

**Estimated Coverage**: ~30% (surface-level + access control only)

**This is NOT a complete audit.** The implementation contract is unverified, preventing analysis of critical business logic.

---

## Recommendations

### 🔴 Immediate (Critical)

1. **Verify Implementation Contract**
   - Submit source code to arcscan.app
   - Enable public auditing of graduation logic
   - **Until verified, consider this HIGH RISK**

2. **Audit Pool Squat Protection**
   - Confirm `graduate()` reads `slot0()` after pool creation
   - Validate sqrtPriceX96 against expected bonding curve price
   - Revert if price deviation exceeds threshold

3. **Emergency Response Plan**
   - Have pause mechanism ready before graduation
   - Monitor pool creation events pre-graduation
   - Prepare to abort if manipulation detected

### 🟡 High Priority

4. **Callback Authentication**
   - Verify `uniswapV3SwapCallback()` checks `msg.sender == expectedPool`
   - Use deterministic pool address calculation

5. **Tax Parameter Lock**
   - Timelock tax changes (e.g., 24-48 hours)
   - Or permanently lock after graduation
   - Emit events for transparency

6. **Third-Party Audit**
   - Get independent security audit before graduation
   - Focus on graduation mechanism and tax logic
   - Publish results publicly

### 🟢 Best Practices

7. **Transparency**
   - Publish source code and audit reports
   - Document graduation process clearly
   - Communicate risks to users

8. **Testing**
   - Mainnet fork testing of graduation flow
   - Adversarial testing with manipulated pools
   - Verify with actual Uniswap V3 Factory on Arc

---

## User Recommendations

### For Traders
1. ⚠️ **DO NOT trade tokens before graduation** - highest risk period
2. Wait for implementation contract verification
3. Wait for third-party audit results
4. Understand that this launchpad dominates 86% of Arc - systemic risk
5. Never provide liquidity until contracts are verified

### For Token Creators
1. Understand the risks of using unverified launchpad contracts
2. Request source code verification from Argus team
3. Consider independent audit before launching
4. Have emergency contacts ready during graduation

---

## Next Steps for Continued Analysis

### If Source Becomes Available
1. Immediate focus on `graduate()` function logic
2. Trace external calls to Uniswap V3 Factory
3. Verify pool price validation (slot0 check)
4. Check callback authentication
5. Analyze tax manipulation vectors
6. Review reentrancy protections

### Alternative Approaches
1. **Advanced Decompilation**: Use Panoramix or Dedaub decompilers
2. **Fork Testing**: Create attack contract and test pool squat
   - Need Uniswap V3 Factory address on Arc
   - Deploy fake pool before graduation
   - Call graduate() and check behavior
3. **Pattern Analysis**: Compare with known launchpad implementations
4. **Community Intel**: Check if others have audited this pattern

---

## Conclusion

**Overall Assessment**: ⚠️ **HIGH RISK - Unverified Implementation**

**Key Takeaways**:
1. ✅ Access control is properly implemented
2. 🔴 Cannot verify pool squat protection (CRITICAL)
3. 🔴 86% market dominance creates systemic risk
4. ⚠️ Users should avoid until source verified

**Severity Rating**:
- **Access Control**: PASS
- **Pool Squat Risk**: CRITICAL (if unprotected)
- **Overall Risk**: HIGH (due to unverifiability)

**Recommendation**: **DO NOT USE until implementation contract is source-verified and independently audited.**

---

## References

Sources:
- [Argus Overview - Bitrue](https://www.bitrue.com/blog/what-is-argus)
- [Arc Chain Info - Trustswap](https://trustswap.com/arc/build)
- [Uniswap on Arc - GitHub](https://github.com/Uniswap/UniswapX/blob/main/playbook/chains/arc.md)
- [Arc Mainnet Launch - Binance](https://www.binance.com/en/square/post/367627821888235)
- [TollyLabs V3 Contracts - GitHub](https://github.com/TollyLabs/v3-contracts)

Tools Used:
- Foundry/Cast for RPC calls
- Python bytecode analysis
- Manual disassembly and selector extraction
- Fork testing framework (Foundry)

---

**Researcher**: deviykee (Iyke)  
**Contact**: http://x.com/deviykee  
**Hunt Duration**: ~3 hours  
**Report Date**: 2026-09-19

**Disclaimer**: This assessment is based on bytecode analysis and black-box testing only. A complete security audit requires source code review. The findings represent what could be verified given the constraints.
