# Argus Launchpad Bug Hunt

**Target**: https://argus.world (Token launchpad on Arc Chain)  
**Researcher**: deviykee (Iyke)  
**Date**: 2026-09-19  
**Status**: ⚠️ **HIGH RISK - Unverified Implementation**

---

## 🎯 Quick Summary

Completed security assessment of Argus, the dominant token launchpad on Arc Chain (86% market share). 

**Verdict**: ✅ Access control PASS | 🔴 Pool squat vulnerability UNVERIFIABLE

The implementation contract is not source-verified, preventing validation of the #1 launchpad vulnerability (pool squat attack during graduation).

**Recommendation**: **DO NOT USE until source verified and audited.**

---

## 📊 Key Findings

### ✅ Verified & Secure
- All critical functions have proper access control
- `graduate()`, `swapBack()`, `setShare()` - all restricted ✓
- No missing auth vulnerabilities found
- Tax system: 1% buy/sell

### 🔴 Critical Risks (Unverified)
- **Pool Squat Vulnerability**: Cannot verify if `graduate()` validates pool price
- **Impact**: Zero-capital attack could drain all token liquidity
- **Affected**: Entire ecosystem (86% of Arc token launches)

### 🟡 Additional Risks (Unverified)
- UniswapV3 callback authentication
- Tax manipulation post-graduation
- Reentrancy in swapBack
- Holder rewards calculation

---

## 📁 Report Files

| File | Description | Size |
|------|-------------|------|
| **FINAL_REPORT.md** | ⭐ Complete assessment with detailed findings | 11 KB |
| **HUNT_SUMMARY.md** | Technical summary and methodology | 5.9 KB |
| **INTAKE.md** | Hunt metadata and progress tracking | 2.2 KB |
| **AUTH_TRIAGE.md** | Access control test results | 1.5 KB |
| **ANALYSIS_PLAN.md** | Approach and constraints | 1.5 KB |
| **NOTES.md** | Investigation blockers | 1.2 KB |
| **coverage.md** | Coverage tracking | 338 B |

**📖 Read FINAL_REPORT.md for complete analysis**

---

## 🔍 What Was Tested

**Scope**:
- ARGUS Token: `0xeCe5cA8bf9220718E5727754026757512212cb3c`
- Implementation: `0x122c82cfca7a3a2227285cc21f4522e8f551db3a` (unverified)
- Chain: Arc mainnet (5042)

**Methods**:
- RPC validation ✓
- Bytecode analysis (20+ functions mapped) ✓
- Access control testing (all critical functions) ✓
- Function selector extraction ✓
- Fork test setup (blocked by missing addresses) ⚠️
- Source code review (blocked - no verification) ❌

**Coverage**: ~30% (surface + auth only)

---

## ⚠️ User Warnings

### For Traders
- 🛑 **DO NOT trade** tokens before graduation
- Wait for source verification
- Wait for independent audit
- High systemic risk (86% market dominance)

### For Token Creators
- Request source verification from Argus team
- Consider independent audit before launch
- Understand unverified contract risks

---

## 🔬 Technical Details

### Architecture
- **Pattern**: Bonding curve → Uniswap V3 graduation
- **Proxy**: EIP-1167 minimal proxy
- **Total Supply**: 1e27 (1B tokens)
- **Graduation**: Not yet executed

### Key Functions
- `graduate()` - Migrates to Uniswap V3 (CRITICAL)
- `swapBack()` - Swaps accumulated taxes
- `setShare()` - Sets holder rewards
- `uniswapV3SwapCallback()` - V3 callback handler

### Chain Info
- Network: Arc (Circle's USDC-native L1)
- Chain ID: 5042
- RPC: https://rpc.mainnet.arc.io
- Gas: USDC (6 decimals)

---

## 📚 References

- [Bitrue: What is Argus](https://www.bitrue.com/blog/what-is-argus)
- [Arc Chain Documentation](https://trustswap.com/arc/build)
- [Uniswap on Arc](https://github.com/Uniswap/UniswapX/blob/main/playbook/chains/arc.md)
- [Arc Launch Analysis](https://www.binance.com/en/square/post/367627821888235)

---

## 🛠️ Tools Used

- Foundry/Cast - RPC calls and chain interaction
- Python - Bytecode analysis and selector extraction
- Manual disassembly - Function mapping
- Fork testing framework (Foundry)

---

## 📞 Contact

**Researcher**: deviykee (Iyke)  
**X/Twitter**: [@deviykee](http://x.com/deviykee)  
**Duration**: ~3 hours  
**Date**: 2026-09-19

---

## ⚖️ Disclaimer

This assessment is based on bytecode analysis and black-box testing only. A complete security audit requires source code review. Findings represent what could be verified given the constraints. This is not financial advice.

**Assessment Status**: Incomplete due to unverified implementation contract.
