# Lift Bug Hunt - Quick Reference

## 🎯 Target Information

- **Project:** Lift (PlayFi)
- **Website:** https://lift.fun
- **Docs:** https://www.liftdata.ai/
- **GitHub:** https://github.com/PlayFi-Labs
- **Twitter:** @liftdataai
- **Product:** Node License Sale (NFT-based)
- **Chains:** zkSync Era (primary), EVM-compatible
- **Audit:** Hacken (Nov 2024)

## 📦 Contracts Reviewed

```
PlayFiLicenseSale.sol     - Main sale contract (558 lines)
  ├─ Team sale (merkle)
  ├─ Friends & Family (merkle + paid)
  ├─ Early Access (merkle + paid)
  ├─ Partner sales (custom tiers)
  ├─ Public sale (open + referrals)
  └─ Public whitelist (merkle + referrals)

PlayFiLicense.sol         - ERC721 NFT (114 lines)
  └─ Non-transferable after mint

PlayFiLicenseMint.sol     - Cross-chain minting (151 lines)
  └─ Arbitrum → Ethereum L1 via EIP-712

PreOrderLicenseClaimer.sol - Batch claiming (111 lines)
  └─ Helper for pre-orders
```

## 🐛 Findings Summary

| # | Severity | Issue | Line | Status |
|---|----------|-------|------|--------|
| 1 | Medium | Referral code squatting/front-running | 373-375, 523-536 | ✅ Verified |
| 2 | Medium | Code change breaks active links | 528-530 | ✅ Verified |
| 3 | Low | Commission timing off-by-one | 220-240 | ✅ Verified |

## 🔑 Key Functions Analyzed

### Sale Functions (All Safe - No Fund Loss)
```solidity
✅ claimLicenseTeam()           - Merkle + cap check
✅ claimLicenseFriendsFamily()  - Merkle + payment + refund
✅ claimLicenseEarlyAccess()    - Merkle + payment + refund
⚠️ claimLicensePartner()        - Custom tiers + referrals
⚠️ claimLicensePublic()         - Open + referrals (Finding #3)
⚠️ claimLicensePublicWhitelist()- Merkle + referrals
```

### Referral System (Issues Found)
```solidity
⚠️ setReferral()                - Finding #1: No access control
⚠️ _setReferral()               - Finding #2: Deletes old code
⚠️ paymentDetailsForReferral()  - Finding #3: Timing issue
✅ setReferralForReceiver()     - Admin-only override (safe)
```

### Admin Functions (All Safe)
```solidity
✅ setTiers()                   - Admin-only, correct
✅ setWhitelistTiers()          - Admin-only, correct
✅ setPartnerTiers()            - Admin-only, correct
✅ setXxxMerkleRoot()           - MERKLE_MANAGER only
✅ setXxxSale()                 - GUARDIAN only
✅ withdrawProceeds()           - Admin-only, correct
```

## 💡 Attack Vectors Investigated

### ✅ SAFE (No Issues Found)
- Reentrancy → CEI pattern followed
- Integer overflow → Solidity 0.8.24 checked math
- Access control → Properly enforced
- Merkle verification → Correct implementation
- Refund logic → Excess ETH returned correctly
- NFT transfers → Blocked after minting
- Commission payments → Fail-safe design
- Tier caps → Individual + total enforced
- Signature replay → EIP-712 correct

### ⚠️ ISSUES FOUND
- Referral griefing → Anyone can claim codes
- Code lifecycle → Old codes deleted
- Commission timing → Off-by-one lag

## 📊 Impact Assessment

### Finding #1: Code Squatting
```
Threat: Griefing / Front-Running
Vector: Permissionless setReferral()
Impact: Marketing campaigns disrupted
Exploit: Claim popular codes, demand payment
Severity: Medium (no fund loss, but business disruption)
```

### Finding #2: Link Breaking
```
Threat: UX Failure / Lost Revenue
Vector: Code change deletes old entries
Impact: Shared links break silently
Exploit: Users pay full price unexpectedly
Severity: Medium (affects users & referrers)
```

### Finding #3: Timing Lag
```
Threat: Off-by-One Accounting
Vector: Calculate before increment
Impact: Minor tier progression delay
Exploit: Not exploitable, consistent behavior
Severity: Low (minor discrepancy)
```

## 🛠️ Recommended Fixes

### For Finding #1 (Code Squatting)
```solidity
// Option A: Whitelist
mapping(address => bool) public canSetReferral;
modifier onlyWhitelisted() {
    require(canSetReferral[msg.sender]);
    _;
}

// Option B: Fee
uint256 public constant CODE_FEE = 0.01 ether;
function setReferral(string memory code) public payable {
    require(msg.value >= CODE_FEE);
    // ...
}

// Option C: Reserved prefix
require(!code.startsWith("LIFT_") || isAdmin(msg.sender));
```

### For Finding #2 (Link Breaking)
```solidity
// Keep old codes valid
function _setReferral(string memory code, address receiver) internal {
    string memory oldCode = receiverToReferralCode[receiver];
    if(!oldCode.equal("")) {
        // DON'T delete - keep old code working!
        uint256 claims = referrals[oldCode].totalClaims;
        referrals[code].totalClaims = claims;
    }
    // New code setup...
}
```

### For Finding #3 (Timing)
```solidity
// Update counter BEFORE calculation
function claimLicensePublic(..., string memory referral) public payable {
    referrals[referral].totalClaims += amount;  // FIRST
    (uint256 toPay, uint256 commission,) = 
        paymentDetailsForReferral(amount, tier, referral, false);  // THEN
    // ...
}
```

## 📋 Disclosure Checklist

- [x] Findings verified
- [x] PoCs documented
- [x] Recommendations provided
- [x] Report written
- [ ] Official security contact found
- [ ] Private disclosure sent
- [ ] Confirmation received
- [ ] Fix implemented
- [ ] Public disclosure (if applicable)

## 🔗 Related Resources

- [Hacken Audit](https://hacken.io/audits/lift/sca-lift-playfi-contracts-nov2024/)
- [PlayFi GitHub](https://github.com/PlayFi-Labs)
- [zkSync Docs](https://docs.zksync.io/)
- [OpenZeppelin Upgradeable](https://docs.openzeppelin.com/contracts/4.x/upgradeable)

## 📞 Contact Points (To Be Verified)

- [ ] security@liftdata.ai (check docs)
- [ ] Twitter DM: @liftdataai
- [ ] GitHub: Private issue to PlayFi-Labs
- [ ] Immunefi: Check for program
- [ ] Discord: Check official docs for invite

---

**Last Updated:** 2026-09-16  
**Researcher:** deviykee  
**Status:** Ready for disclosure
