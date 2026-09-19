# Lift Bug Hunt - Initial Analysis Notes

**Date:** 2026-09-16  
**Researcher:** deviykee  
**Target:** Lift (PlayFi) Node License Sale System

## System Overview

### Architecture
- **PlayFiLicenseSale.sol** - Main sale contract with multiple sale phases (team, friends/family, early access, partner, public, public whitelist)
- **PlayFiLicense.sol** - ERC721 NFT representing node licenses (NON-TRANSFERABLE after minting)
- **PlayFiLicenseMint.sol** - Cross-chain minting contract (Arbitrum → Ethereum L1 via signature verification)
- **PreOrderLicenseClaimer.sol** - Helper contract for batch claiming pre-orders

### Key Mechanisms

#### 1. Sale Phases (PlayFiLicenseSale)
- **Team Sale**: Free licenses for team, merkle-based whitelist, individual caps
- **Friends & Family**: Paid, merkle-based, tier 1 pricing
- **Early Access**: Paid, merkle-based, tier 1 pricing  
- **Partner Sales**: Multiple partner codes, custom tiers per partner, referral commissions
- **Public Sale**: Open to all, multi-tier system, referral commissions
- **Public Whitelist**: Merkle-based during public sale, separate tier system

#### 2. Tier System
```solidity
struct Tier {
    uint256 price;
    uint256 individualCap;  // Max per address
    uint256 totalClaimed;
    uint256 totalCap;       // Max total
}
```
- Regular tiers: `tiers[tierId]`
- Whitelist tiers: `whitelistTiers[tierId]`
- Partner tiers: `partnerTiers[partnerCode][tierId]`

#### 3. Referral System
```solidity
struct Referral {
    address receiver;
    uint256 totalClaims;
}
```
- Commission rates: 10-15% based on totalClaims milestones (20, 40, 60, 80, 100+)
- Discount = Commission (100% passed to buyer)
- Users can set their own referral code via `setReferral()`
- Admins can override via `setReferralForReceiver()`

#### 4. Payment Flow
- ETH payments with automatic refunds for overpayment
- Commission paid immediately to referrer
- Remainder stays in contract
- Admin withdraws via `withdrawProceeds()`

## Initial Observations & Potential Issues

### 🔴 HIGH PRIORITY FINDINGS

#### Finding #1: Referral Code Front-Running & Griefing
**Location:** `PlayFiLicenseSale.sol:523-536` (`_setReferral`)

**Issue:** Anyone can call `setReferral(code)` to claim a referral code for themselves. This creates multiple attack vectors:

1. **Front-running**: Attacker watches mempool, sees someone claiming `code="PROMO10"`, front-runs with their own address
2. **Griefing**: Attacker claims all attractive codes ("LAUNCH", "EARLY", "BONUS", etc.) preventing legitimate users
3. **Code Squatting**: Attacker reserves codes then demands payment to release them

**Code:**
```solidity
function _setReferral(string memory code, address receiver) internal {
    if(referrals[code].receiver != address(0)) revert ReferralCodeInUse();  // ✅ Prevents override
    if(code.equal("")) revert InvalidCode();  // ✅ Prevents empty
    // ❌ But anyone can claim any unused code!
    string memory oldReferralCode = receiverToReferralCode[receiver];
    uint256 totalClaims = 0;
    if(!oldReferralCode.equal("")) {
        totalClaims = referrals[receiverToReferralCode[receiver]].totalClaims;
        delete referrals[receiverToReferralCode[receiver]];  // 🚨 DELETES old code data!
    }
    referrals[code].receiver = receiver;
    referrals[code].totalClaims = totalClaims;  // Preserves totalClaims
    receiverToReferralCode[receiver] = code;
    emit ReferralUpdated(code, receiver);
}
```

**Impact:**
- **Trust/Centralization**: Low severity - permissionless by design, but griefing possible
- **Economic**: Attackers can squat codes, demand ransom, or block legitimate marketing campaigns

**Severity:** Medium (Griefing + potential economic impact on marketing)

---

#### Finding #2: Referral Code Change Breaks Active Referral Links
**Location:** `PlayFiLicenseSale.sol:528-530`

**Issue:** When a receiver changes their referral code, the OLD code is completely deleted:
```solidity
if(!oldReferralCode.equal("")) {
    totalClaims = referrals[receiverToReferralCode[receiver]].totalClaims;
    delete referrals[receiverToReferralCode[receiver]];  // 🚨 OLD CODE DELETED!
}
```

**Attack Scenario:**
1. User shares referral link: `lift.fun/buy?ref=ALICE2024`
2. Alice has 50 claims, earning 12% commission
3. Alice calls `setReferral("ALICE_NEW")` 
4. **OLD CODE "ALICE2024" IS DELETED** - `referrals["ALICE2024"].receiver = address(0)`
5. Anyone clicking old links uses code "ALICE2024" but:
   - `paymentDetailsForReferral()` line 293: `if(referrals[referral].receiver != address(0))` returns FALSE
   - **No commission, no discount** applied
   - Users who expected discount get charged full price

**Impact:**
- **User Experience**: Shared links break silently
- **Economic**: Lost commissions for referrer, users pay more than expected
- **Trust**: Marketing campaigns broken without warning

**Severity:** Medium (Breaks existing integrations, silent failure)

---

#### Finding #3: Commission Calculation Uses Pre-Update `totalClaims`
**Location:** Multiple functions that pay commissions BEFORE incrementing counters

**Issue:** Commission rate is calculated using `referrals[referral].totalClaims` BEFORE the current claim increments it. This creates inconsistent tier progression.

**Example in `claimLicensePublic()` (lines 220-240):**
```solidity
function claimLicensePublic(uint256 amount, uint256 tier, string memory referral) public payable {
    // ...
    (uint256 toPay, uint256 commission,) = paymentDetailsForReferral(amount, tier, referral, false);  // Line 224 - uses OLD totalClaims
    // ...
    referrals[referral].totalClaims += amount;  // Line 229 - AFTER calculation
    // ...
}
```

**Scenario:**
- Referrer has 19 totalClaims (10% commission tier)
- Buyer claims 10 licenses
- Commission calculated at 10% (because totalClaims = 19)
- After transaction: totalClaims = 29
- **Next buyer ALSO gets 10%** even though referrer crossed threshold to 11%

**Impact:**
- Commission tiers progress one transaction later than intended
- Referrers earn slightly less (off-by-one transaction)
- Buyers get slightly more discount

**Severity:** Low (Minor accounting discrepancy, consistent behavior)

---

### 🟡 MEDIUM PRIORITY OBSERVATIONS

#### Observation #4: Reentrancy Guards Missing on Payment Functions
**Status:** ✅ SAFE - No reentrancy risk detected

**Analysis:**
- All external calls (refunds, commissions) happen AFTER state updates
- Follows checks-effects-interactions pattern
- Example from `claimLicensePublic()`:
  ```solidity
  tiers[tier].totalClaimed += amount;           // ✅ State update
  publicClaimsPerAddress[msg.sender] += amount; // ✅ State update
  totalLicenses += amount;                      // ✅ State update
  referrals[referral].totalClaims += amount;    // ✅ State update
  claimsPerTierPerAddress[tier][msg.sender] += amount; // ✅ State update
  
  // THEN external calls:
  (bool sent, ) = payable(referrals[referral].receiver).call{ value: commission }("");
  ```

**Verdict:** No reentrancy vulnerability

---

#### Observation #5: Partner Sale Commission Logic Discrepancy
**Location:** `PlayFiLicenseSale.sol:183-213` (`claimLicensePartner`)

**Issue:** Complex branching logic for partner vs regular referral:
```solidity
if(partnerReferrals[partnerCode].receiver != address(0)) {
    // Pay partner receiver
    if(commission > 0) {
        (bool sent, ) = payable(partnerReferrals[partnerCode].receiver).call{ value: commission }("");
        if (!sent) revert CommissionPayoutFailed();
        emit CommissionPaid(partnerCode, partnerReferrals[partnerCode].receiver, commission);
    }
} else {
    // Pay regular referral receiver
    if(commission > 0) {
        (bool sent, ) = payable(referrals[referral].receiver).call{ value: commission }("");
        if (!sent) revert CommissionPayoutFailed();
        emit CommissionPaid(referral, referrals[referral].receiver, commission);
    }
    referrals[referral].totalClaims += amount;  // 🚨 ONLY incremented in else branch!
}
```

**Problem:** If partner has a receiver, regular referral's `totalClaims` is NEVER incremented even if passed.

**Impact:** Likely intended behavior (partner overrides referral), but could cause confusion.

**Severity:** Low (Documentation/design clarity issue)

---

### 🟢 SAFE MECHANISMS (Verified)

✅ **Merkle Proof Verification** - Correct implementation  
✅ **Individual & Total Caps** - Properly enforced  
✅ **Access Control** - Role-based, properly initialized  
✅ **Refund Logic** - Correct excess ETH handling  
✅ **Non-Transferable NFTs** - `_beforeTokenTransfer` blocks transfers  
✅ **Signature Verification (PlayFiLicenseMint)** - EIP-712 correctly implemented

---

## Next Steps

1. ✅ Read all core contracts
2. 🔄 **Deep dive into referral economics** - build PoC for Finding #1 & #2
3. ⏳ Check for integer overflow scenarios (Solidity 0.8.24 has checked math)
4. ⏳ Review upgrade safety (contracts use OpenZeppelin upgradeable)
5. ⏳ Test tier cap edge cases (totalCap vs individualCap interactions)
6. ⏳ Verify payment calculation correctness across all paths
7. ⏳ Check deployment scripts for configuration errors

## Coverage Status
- Files read: 4/8 (50%)
- Core contracts: 100% (4/4)
- Interfaces: 0% (not yet critical)
