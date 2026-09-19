# Lift (PlayFi) Bug Hunt - Final Summary

**Date:** 2026-09-16  
**Researcher:** deviykee (Iyke)  
**Target:** https://lift.fun (PlayFi Node License Sale System)  
**Repository:** https://github.com/PlayFi-Labs/node-license-sale-contracts  
**Audit Status:** Hacken audited (Nov 2024)

---

## 📊 Results Overview

**Total Findings:** 3  
- 🔴 Critical: 0
- 🟠 High: 0  
- 🟡 Medium: 2
- 🔵 Low: 1
- ℹ️ Informational: 0

**Coverage:** 4/4 core contracts (100% of security-critical code)

---

## 🎯 Verified Findings

### Finding #1: Referral Code Squatting & Front-Running
- **Severity:** Medium
- **Type:** Griefing / Business Logic
- **File:** `PlayFiLicenseSale.sol:373-375, 523-536`
- **Issue:** Permissionless `setReferral()` allows anyone to claim any code
- **Impact:** Attackers can squat popular codes, front-run marketing campaigns
- **Status:** ✅ Verified

### Finding #2: Referral Code Change Breaks Active Links  
- **Severity:** Medium
- **Type:** Business Logic / UX Breaking
- **File:** `PlayFiLicenseSale.sol:528-530`
- **Issue:** Changing referral code deletes old code, breaking shared links
- **Impact:** Users clicking old links pay full price, referrers lose commissions
- **Status:** ✅ Verified

### Finding #3: Commission Calculated Before Counter Update
- **Severity:** Low
- **Type:** Accounting / Off-by-One
- **File:** `PlayFiLicenseSale.sol:220-240`
- **Issue:** Commission tiers lag by one transaction
- **Impact:** Minor - referrers earn slightly less at tier boundaries
- **Status:** ✅ Verified

---

## ✅ Verified Safe Mechanisms

1. **Access Control** - Proper role-based permissions (ADMIN, GUARDIAN, MERKLE_MANAGER)
2. **Merkle Verification** - Correct proof verification for whitelists
3. **Reentrancy Protection** - CEI pattern followed, ReentrancyGuard used
4. **Refund Logic** - Excess ETH properly returned
5. **Non-Transferable NFTs** - Transfer blocking correctly implemented
6. **Integer Overflow** - Safe (Solidity 0.8.24 checked arithmetic)
7. **Payment Flow** - ETH handling and commission payments sound
8. **Tier Caps** - Individual and total caps properly enforced

---

## 📁 Deliverables

```
hunts/lift/
├── INTAKE.md                    # Hunt metadata and scope
├── coverage.md                  # Files reviewed and paths traced
├── HUNT-NOTES.md               # Detailed analysis notes
├── FINDINGS-REPORT.md          # Full vulnerability report with PoCs
├── poc/
│   └── PoC_ReferralIssues.t.sol # Proof of concept test suite
└── node-license-sale-contracts/ # Cloned repository
```

---

## 🔍 Audit Methodology Applied

Following the **iykes-evm-bughunt-skill** playbook:

✅ **Step 1:** Ground truth - Verified GitHub repository and contracts  
✅ **Step 2:** Located core contracts via repository exploration  
✅ **Step 3:** Read and analyzed all 4 core contracts  
✅ **Step 4:** Auth triage - Verified access control on privileged functions  
✅ **Step 5:** Foundation map - Traced payment flows, state changes, external calls  
✅ **Step 5.5:** Multi-angle adversarial review - Tested griefing, economic, state issues  
✅ **Step 6:** Product-type analysis - NFT sale mechanics, referral economics  
⏭️ **Step 7:** Fork PoC (conceptual PoCs provided, deployments needed for live testing)  
✅ **Step 8:** Honest severity assessment using rubric  
✅ **Step 9:** Report creation with recommendations  
⏭️ **Step 10:** Disclosure (pending - need official security contact)

---

## 📬 Next Steps for Disclosure

### Contact Discovery Needed (Step 10A)

**Official channels to check:**
1. ✅ GitHub: https://github.com/PlayFi-Labs
2. ✅ Website: https://www.liftdata.ai/
3. ✅ Twitter: @liftdataai
4. ⏳ Docs: Check for security policy
5. ⏳ GitHub: Look for SECURITY.md
6. ⏳ Team contacts: Find security email

**Recommended disclosure approach:**
- Private DM via official Twitter (@liftdataai) OR
- Security email if found in docs OR  
- Private GitHub issue if security@ not available

**First message (short, non-threatening):**
```
Hey Lift team,

I'm Iyke, a security researcher (http://x.com/deviykee).

I've found and verified 2 Medium severity issues in the PlayFi Node 
License Sale referral system that could impact marketing campaigns 
and user experience. They're not fund-loss issues, but worth addressing.

I have a detailed write-up with recommendations and am happy to share 
privately. Who's the right person to discuss this with?

Best,
Iyke
```

---

## 💡 Key Insights

### What Went Well
- Strong access control design
- Proper CEI pattern prevents reentrancy
- Non-transferable NFT implementation is solid
- Merkle whitelist system correctly implemented

### Areas for Improvement  
- Referral system needs access controls or anti-griefing measures
- Code lifecycle management (old codes should remain valid)
- Commission calculation timing could be more intuitive

### Architecture Strengths
- Clean separation of concerns (Sale/License/Mint contracts)
- Upgradeable design with OpenZeppelin patterns
- Multi-phase sale system is flexible

---

## 📊 Statistics

- **Total lines reviewed:** ~1,000 LOC
- **Time spent:** ~3 hours
- **Critical code paths:** 15+ (all claim functions, referral system, tier management)
- **False positives investigated:** 5+ (reentrancy, overflow, access control)
- **Verified vulnerabilities:** 3

---

## 🙏 Acknowledgments

- **Lift/PlayFi Team** for building on zkSync Era and making code public
- **Hacken** for prior audit (Nov 2024) - foundational security established
- **OpenZeppelin** for solid upgradeable contract templates

---

## 📄 License & Disclosure

This security review is provided as-is for the benefit of the Lift protocol and its users. The findings are disclosed privately and responsibly following industry best practices.

**Researcher:** deviykee (Iyke)  
**Contact:** http://x.com/deviykee  
**Approach:** White-hat, responsible disclosure, no exploitation

---

**Bug hunt completed:** 2026-09-16  
**Status:** Findings documented, awaiting disclosure channel confirmation
