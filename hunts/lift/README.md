# Lift Bug Hunt - Complete

## 🎯 Hunt Overview

**Protocol:** Lift (PlayFi) - AI-powered node license sale platform  
**Website:** https://lift.fun  
**GitHub:** https://github.com/PlayFi-Labs/node-license-sale-contracts  
**Researcher:** deviykee (Iyke) - http://x.com/deviykee  
**Date:** 2026-09-16  
**Duration:** ~3 hours  
**Methodology:** iykes-evm-bughunt-skill  

---

## 📍 Deployed Contracts (Production)

### Arbitrum One (Sale Platform)
- **PlayFiLicenseSale (Proxy):** `0x66F49158826a5A3953636ff63350bA815C9665AD`
- **PreOrderLicenseClaimer:** Deployed (check deployments/arbitrumOne/)

### Ethereum Mainnet (NFT Minting)
- **PlayFiLicenseMint (Proxy):** `0xDEAf6a76b670aD210F3e9966EE5d63CdaeB7b0e6`
- **PlayFiLicense (NFT):** Deployed (check deployments/ethereum/)

**Architecture:** Cross-chain system
- Sale happens on Arbitrum One (lower fees)
- NFTs minted on Ethereum L1 (via signature verification)

---

## 🐛 Verified Findings

### 🟡 Finding #1: Referral Code Squatting & Front-Running
- **Severity:** Medium
- **CVSS:** 5.3 (AV:N/AC:L/PR:N/UI:N/S:U/C:N/I:L/A:N)
- **Type:** Griefing / Business Logic
- **CWE:** CWE-841 (Improper Enforcement of Behavioral Workflow)

**Vulnerability:**
The `setReferral()` function is permissionless, allowing anyone to claim any unused referral code. No whitelist, no fee, no access control.

**Impact:**
- Attackers can squat popular codes ("LAUNCH", "PROMO", "EARLY")
- Marketing campaigns can be front-run or griefed
- Protocol loses control over official referral codes
- Code squatters can demand payment to release codes

**Affected Function:**
```solidity
function setReferral(string memory code) public {
    _setReferral(code, msg.sender);  // ❌ No access control
}
```

**Recommendation:** Implement whitelist, registration fee, or reserved prefix system.

---

### 🟡 Finding #2: Referral Code Change Breaks Active Links
- **Severity:** Medium
- **CVSS:** 4.3 (AV:N/AC:L/PR:L/UI:N/S:U/C:N/I:L/A:N)
- **Type:** Business Logic / Data Loss
- **CWE:** CWE-404 (Improper Resource Shutdown)

**Vulnerability:**
When users change their referral code, the old code is completely deleted from storage. All previously shared referral links break silently.

**Impact:**
- Shared marketing links stop working
- Users clicking old links pay FULL PRICE (no discount)
- Referrers lose ALL commission from old links
- Silent failure (no error, just unexpected charges)

**Affected Code:**
```solidity
function _setReferral(string memory code, address receiver) internal {
    string memory oldReferralCode = receiverToReferralCode[receiver];
    if(!oldReferralCode.equal("")) {
        totalClaims = referrals[oldReferralCode].totalClaims;
        delete referrals[oldReferralCode];  // 🚨 OLD CODE DELETED!
    }
    // ... setup new code ...
}
```

**Recommendation:** Preserve old codes or implement redirect system.

---

### 🔵 Finding #3: Commission Calculated Before Counter Update
- **Severity:** Low
- **CVSS:** 2.0 (AV:N/AC:L/PR:N/UI:N/S:U/C:N/I:N/A:N)
- **Type:** Accounting / Off-by-One
- **CWE:** CWE-682 (Incorrect Calculation)

**Vulnerability:**
Commission rates are tiered based on `totalClaims` count, but the commission is calculated BEFORE incrementing the counter, causing tier progression to lag by one transaction.

**Impact:**
- Minor: Referrers earn slightly less at tier boundaries
- Predictable behavior (not exploitable)
- Consistent one-transaction delay

**Affected Pattern:**
```solidity
// Calculate commission with OLD totalClaims
(uint256 toPay, uint256 commission,) = 
    paymentDetailsForReferral(amount, tier, referral, false);

// THEN increment
referrals[referral].totalClaims += amount;
```

**Recommendation:** Update counter before calculation or document behavior.

---

## ✅ Security Strengths Verified

1. **Access Control** ✅
   - Role-based permissions correctly implemented
   - ADMIN, GUARDIAN, MERKLE_MANAGER properly enforced
   - No unauthorized access vectors found

2. **Reentrancy Protection** ✅
   - CEI (Checks-Effects-Interactions) pattern followed
   - State updates before external calls
   - ReentrancyGuard used in critical functions

3. **Merkle Verification** ✅
   - Correct proof verification
   - Proper node encoding: `keccak256(abi.encodePacked(index, address, claimCap))`

4. **Payment Logic** ✅
   - Excess ETH properly refunded
   - Commission payouts with failure handling
   - No fund loss vectors identified

5. **Tier System** ✅
   - Individual caps enforced
   - Total caps enforced
   - No overflow possible (Solidity 0.8.24)

6. **Non-Transferable NFTs** ✅
   - Transfer blocking correctly implemented
   - Only minting allowed after initial mint

7. **EIP-712 Signatures** ✅
   - Cross-chain minting uses proper signature verification
   - Domain separator correctly configured

---

## 📊 Coverage Report

**Core Contracts:** 4/4 (100%)  
**Total LOC Reviewed:** ~1,000  
**Critical Paths Traced:** 15+

| Contract | Status | Coverage |
|----------|--------|----------|
| PlayFiLicenseSale.sol | ✅ Complete | 100% of security-critical paths |
| PlayFiLicense.sol | ✅ Complete | 100% |
| PlayFiLicenseMint.sol | ✅ Complete | 100% |
| PreOrderLicenseClaimer.sol | ✅ Complete | 100% |

**Functions Analyzed:**
- `claimLicenseTeam()` ✅
- `claimLicenseFriendsFamily()` ✅
- `claimLicenseEarlyAccess()` ✅
- `claimLicensePartner()` ⚠️ (Finding #3)
- `claimLicensePublic()` ⚠️ (Finding #3)
- `claimLicensePublicWhitelist()` ⚠️ (Finding #3)
- `setReferral()` ⚠️ (Finding #1)
- `_setReferral()` ⚠️ (Finding #2)
- All admin functions ✅
- Payment flows ✅
- Refund logic ✅

---

## 📁 Deliverables

```
hunts/lift/
├── INTAKE.md                    # Hunt metadata
├── SUMMARY.md                   # Executive summary
├── FINDINGS-REPORT.md          # Detailed vulnerability report
├── HUNT-NOTES.md               # Analysis notes
├── QUICK-REFERENCE.md          # Quick lookup guide
├── coverage.md                 # Coverage tracking
├── poc/
│   └── PoC_ReferralIssues.t.sol # Proof of concepts
└── node-license-sale-contracts/ # Source repository
```

---

## 🔐 Security Assessment

### Overall Rating: **GOOD** ✅

The protocol demonstrates strong security fundamentals with proper access controls, reentrancy protection, and payment handling. The identified issues are non-critical and relate to referral system design choices rather than fund-loss vulnerabilities.

### Risk Summary
- **Critical Risk:** None found ✅
- **High Risk:** None found ✅
- **Medium Risk:** 2 (Referral system UX/griefing)
- **Low Risk:** 1 (Accounting timing)

### Audit Coverage
- **Smart Contract Security:** ✅ Comprehensive
- **Business Logic:** ✅ Comprehensive
- **Access Control:** ✅ Verified
- **Economic Attacks:** ✅ Analyzed
- **Reentrancy:** ✅ Not vulnerable
- **Overflow/Underflow:** ✅ Safe (0.8.24)

---

## 💬 Disclosure Status

**Status:** ✅ Ready for disclosure  
**Approach:** Private, responsible disclosure  
**Tone:** Collaborative, solution-oriented

### Recommended Disclosure Channels (In Order)
1. **Direct Security Email** (if found in docs/GitHub)
2. **Twitter DM:** @liftdataai
3. **GitHub:** Private security advisory
4. **Immunefi:** Check for bug bounty program

### First Contact Template
```
Subject: Security Research - Referral System Issues

Hey Lift team,

I'm Iyke, a security researcher (http://x.com/deviykee).

I've completed a security review of the PlayFi Node License Sale contracts 
and found 2 Medium severity issues in the referral system. These are not 
critical fund-loss bugs, but they affect user experience and marketing 
campaigns:

1. Referral code squatting/front-running
2. Code changes breaking active referral links

Both have straightforward fixes. I have a detailed write-up with PoCs and 
recommendations. Happy to share privately and help with the fixes.

Who's the right person to discuss this with?

Best,
Iyke (deviykee)
```

---

## 🎓 Lessons Learned

### For Protocol Teams
1. **Referral Systems Need Access Controls** - Even non-financial functions can be griefed
2. **Data Migration Matters** - Deleting old data breaks user expectations
3. **Timing is Subtle** - Off-by-one errors in counters are easy to introduce

### For Researchers
1. **Read the Audit** - Hacken already covered the basics (Nov 2024)
2. **Focus on Business Logic** - Not everything is reentrancy or overflow
3. **UX is Security** - Broken links and griefing are real impacts

---

## 🙏 Acknowledgments

- **Lift/PlayFi Team** for open-source contracts and building on Arbitrum/Ethereum
- **Hacken** for establishing the security baseline
- **OpenZeppelin** for solid upgradeable contract patterns
- **iykes-evm-bughunt-skill** playbook for systematic methodology

---

## 📞 Researcher Contact

**Name:** deviykee (Iyke)  
**Twitter:** http://x.com/deviykee  
**Approach:** White-hat, responsible disclosure, collaborative  
**Expertise:** EVM security, DeFi protocols, smart contract auditing

---

**Hunt Completed:** 2026-09-16  
**Next Step:** Await disclosure channel confirmation from Lift team  
**Files Ready:** ✅ All reports and PoCs documented
