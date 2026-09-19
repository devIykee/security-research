# Lift Bug Hunt - Verified Findings Report

**Date:** 2026-09-16  
**Researcher:** deviykee  
**Protocol:** Lift (PlayFi) Node License Sale  
**Contracts:** PlayFiLicenseSale.sol, PlayFiLicense.sol, PlayFiLicenseMint.sol

---

## Executive Summary

Completed security review of Lift's node license sale system. Found **2 Medium severity** issues related to the referral system, and **1 Low severity** timing discrepancy. No critical vulnerabilities found. The core payment and access control logic is sound.

**Key Findings:**
- ✅ No critical vulnerabilities (no fund loss, no unauthorized access)
- ⚠️ 2 Medium issues (griefing, UX breaking changes)
- 📊 1 Low issue (accounting timing)
- ✅ Strong access controls and merkle verification
- ✅ Proper CEI pattern (no reentrancy)
- ✅ Non-transferable NFT implementation correct

---

## Finding #1: Referral Code Squatting & Front-Running

**Severity:** Medium  
**Type:** Griefing / Business Logic  
**Location:** `PlayFiLicenseSale.sol:373-375, 523-536`

### Description

The `setReferral()` function is permissionless, allowing anyone to claim any unused referral code. This creates multiple attack vectors:

1. **Front-Running**: Attacker monitors mempool and front-runs legitimate code claims
2. **Code Squatting**: Attacker preemptively claims attractive codes ("LAUNCH", "PROMO", "EARLY")
3. **Griefing Marketing**: Protocol cannot reserve codes for official campaigns

### Vulnerable Code

```solidity
/// @notice Sets referral details
/// @param code The referral code to be used when claiming
function setReferral(string memory code) public {
    _setReferral(code, msg.sender);  // ❌ Anyone can call this!
}

function _setReferral(string memory code, address receiver) internal {
    if(referrals[code].receiver != address(0)) revert ReferralCodeInUse();
    if(code.equal("")) revert InvalidCode();
    // No access control - first caller wins
    referrals[code].receiver = receiver;
    referrals[code].totalClaims = totalClaims;
    receiverToReferralCode[receiver] = code;
    emit ReferralUpdated(code, receiver);
}
```

### Impact

- **Trust/Centralization**: Medium - Protocol loses control over marketing codes
- **Economic**: Attackers can demand payment to release codes
- **User Experience**: Legitimate users forced to use ugly random codes

### Proof of Concept

```solidity
// Attacker claims all attractive codes
string[] memory goodCodes = ["LAUNCH", "PROMO", "EARLY", "BONUS", "SPECIAL"];
for(uint i = 0; i < goodCodes.length; i++) {
    attacker.setReferral(goodCodes[i]);
}

// Alice tries to use "LAUNCH" for her marketing campaign
// ❌ Reverts: ReferralCodeInUse
// Alice must use "ALICE_xk92jf3" instead
```

### Recommendation

**Option 1: Whitelist System (Recommended)**
```solidity
mapping(address => bool) public canSetReferral;

function setReferral(string memory code) public {
    require(canSetReferral[msg.sender], "Not whitelisted");
    _setReferral(code, msg.sender);
}

function whitelistReferrer(address user) external onlyAdmin {
    canSetReferral[user] = true;
}
```

**Option 2: Reserved Prefix**
```solidity
function _setReferral(string memory code, address receiver) internal {
    // Reserve codes starting with "LIFT_" for admin only
    if(bytes(code).length >= 5) {
        bytes memory prefix = new bytes(5);
        for(uint i = 0; i < 5; i++) {
            prefix[i] = bytes(code)[i];
        }
        if(keccak256(prefix) == keccak256("LIFT_")) {
            require(hasRole(ADMIN_ROLE, msg.sender), "Reserved prefix");
        }
    }
    // ... rest of function
}
```

**Option 3: Registration Fee**
```solidity
uint256 public referralCodeFee = 0.01 ether;

function setReferral(string memory code) public payable {
    require(msg.value >= referralCodeFee, "Insufficient fee");
    _setReferral(code, msg.sender);
}
```

---

## Finding #2: Referral Code Change Deletes Old Code

**Severity:** Medium  
**Type:** Business Logic / UX Breaking  
**Location:** `PlayFiLicenseSale.sol:528-530`

### Description

When a user changes their referral code, the old code is completely deleted from storage. This breaks all existing referral links shared with that code, causing:
- Users clicking old links get no discount (charged full price)
- Referrer receives no commission from old links
- Silent failure (no error, just charges full price)

### Vulnerable Code

```solidity
function _setReferral(string memory code, address receiver) internal {
    // ...
    string memory oldReferralCode = receiverToReferralCode[receiver];
    uint256 totalClaims = 0;
    if(!oldReferralCode.equal("")) {
        totalClaims = referrals[receiverToReferralCode[receiver]].totalClaims;
        delete referrals[receiverToReferralCode[receiver]];  // 🚨 DELETES OLD CODE!
    }
    referrals[code].receiver = receiver;
    referrals[code].totalClaims = totalClaims;  // Only preserves count
    receiverToReferralCode[receiver] = code;
    emit ReferralUpdated(code, receiver);
}
```

### Attack Scenario

```
Timeline:
1. Alice sets code: "ALICE2024"
2. Alice shares: lift.fun/buy?ref=ALICE2024
3. Alice gets 50 claims, earning 12% commission
4. Alice calls setReferral("ALICE_NEW")
   -> referrals["ALICE2024"] = deleted!
5. Users click old link with ref=ALICE2024
   -> paymentDetailsForReferral() sees referrals["ALICE2024"].receiver == address(0)
   -> Returns commission = 0, discount = 0
   -> User pays FULL PRICE
   -> Alice gets NO COMMISSION
```

### Impact

- **User Experience**: Shared marketing links break silently
- **Economic**: Lost commissions for referrers, users pay unexpected full price
- **Trust**: Marketing campaigns broken without warning or migration path

### Proof of Concept

```solidity
// Alice sets initial code
alice.setReferral("ALICE2024");

// Users use the code successfully
buyer.claimLicensePublic{value: 0.9 ether}(1, 1, "ALICE2024");
// ✅ Works: Alice gets commission, buyer gets discount

// Alice changes code
alice.setReferral("ALICE_NEW");

// Old code is now broken
(uint256 toPay, uint256 commission, uint256 discount) = 
    licenseSale.paymentDetailsForReferral(1, 1, "ALICE2024", false);
// Result: commission = 0, discount = 0 (full price)

// New users clicking old links pay full price
buyer2.claimLicensePublic{value: 1.0 ether}(1, 1, "ALICE2024");
// ❌ Charged full 1.0 ETH instead of 0.9 ETH
```

### Recommendation

**Option 1: Preserve Old Code (Recommended)**
```solidity
function _setReferral(string memory code, address receiver) internal {
    if(referrals[code].receiver != address(0)) revert ReferralCodeInUse();
    if(code.equal("")) revert InvalidCode();
    
    string memory oldReferralCode = receiverToReferralCode[receiver];
    uint256 totalClaims = 0;
    
    if(!oldReferralCode.equal("")) {
        totalClaims = referrals[oldReferralCode].totalClaims;
        // DON'T delete old code - keep it pointing to same receiver
        // Old links continue working!
    }
    
    referrals[code].receiver = receiver;
    referrals[code].totalClaims = totalClaims;
    receiverToReferralCode[receiver] = code;
    emit ReferralUpdated(code, receiver);
}
```

**Option 2: Redirect Old to New**
```solidity
mapping(string => string) public referralRedirects;

function _setReferral(string memory code, address receiver) internal {
    // ... existing checks ...
    
    string memory oldCode = receiverToReferralCode[receiver];
    if(!oldCode.equal("")) {
        // Create redirect: old code -> new code
        referralRedirects[oldCode] = code;
        // Keep old code data for lookups
    }
    
    // ... rest of function
}

function paymentDetailsForReferral(..., string memory referral, ...) public view returns (...) {
    // Check for redirect
    string memory actualReferral = referralRedirects[referral];
    if(!actualReferral.equal("")) {
        referral = actualReferral;
    }
    // ... continue with logic
}
```

---

## Finding #3: Commission Calculated Before Counter Update

**Severity:** Low  
**Type:** Accounting / Off-by-One  
**Location:** `PlayFiLicenseSale.sol:220-240` and other claim functions

### Description

Commission rates are tiered based on `totalClaims` (10% for <20, 11% for <40, etc.). However, the commission calculation happens BEFORE incrementing `totalClaims`, causing tier progression to lag by one transaction.

### Code Flow

```solidity
function claimLicensePublic(uint256 amount, uint256 tier, string memory referral) public payable {
    // ...
    // Line 224: Calculate commission using CURRENT totalClaims
    (uint256 toPay, uint256 commission,) = paymentDetailsForReferral(amount, tier, referral, false);
    
    // ... state updates ...
    
    // Line 229: THEN increment totalClaims
    referrals[referral].totalClaims += amount;
    
    // ... pay commission ...
}

function paymentDetailsForReferral(...) public view returns (...) {
    uint256 totalClaims = referrals[referral].totalClaims;  // OLD value
    if(totalClaims < 20) {
        commission = fullPrice * 10 / 100;
    } else if (totalClaims < 40) {
        commission = fullPrice * 11 / 100;
    }
    // ...
}
```

### Scenario

```
Referrer state: totalClaims = 19
Buyer claims 10 licenses

Expected behavior:
- New totalClaims = 29
- Should use 11% tier (29 >= 20 but < 40)

Actual behavior:
- Commission calculated with totalClaims = 19
- Uses 10% tier
- THEN totalClaims updated to 29
- Next transaction still uses 10% (29 < 40)
- Tier upgrade happens one transaction late
```

### Impact

- **Economic**: Minor - referrers earn slightly less at tier boundaries
- **Consistency**: Predictable off-by-one behavior (not exploitable)
- **User Experience**: Buyers get slightly better rates near boundaries

### Recommendation

```solidity
function claimLicensePublic(uint256 amount, uint256 tier, string memory referral) public payable {
    // Update totalClaims FIRST
    uint256 newTotalClaims = referrals[referral].totalClaims + amount;
    referrals[referral].totalClaims = newTotalClaims;
    
    // THEN calculate commission with updated value
    (uint256 toPay, uint256 commission,) = paymentDetailsForReferral(amount, tier, referral, false);
    
    // ... rest of function
}
```

Or pass `newTotalClaims` as parameter:
```solidity
function paymentDetailsForReferral(
    uint256 amount, 
    uint256 tier, 
    string memory referral, 
    bool isWhitelist,
    uint256 overrideTotalClaims  // NEW parameter
) public view returns (uint256 toPay, uint256 commission, uint256 discount) {
    uint256 totalClaims = overrideTotalClaims > 0 ? overrideTotalClaims : referrals[referral].totalClaims;
    // ... rest of logic
}
```

---

## Additional Observations (Not Vulnerabilities)

### ✅ Verified Safe Mechanisms

1. **Access Control**: Properly implemented with OpenZeppelin's AccessControl
   - ADMIN_ROLE, GUARDIAN_ROLE, MERKLE_MANAGER_ROLE correctly enforced
   - Role admins properly configured in initialize()

2. **Merkle Verification**: Correct implementation
   - Nodes properly encoded: `keccak256(abi.encodePacked(index, address, claimCap))`
   - Proof verification correct

3. **Reentrancy Protection**: CEI pattern followed
   - All state updates before external calls
   - ReentrancyGuard used in PlayFiLicense.mint()

4. **Refund Logic**: Correct excess ETH handling
   ```solidity
   if(msg.value > toPay) {
       (bool sent, ) = payable(msg.sender).call{ value: msg.value - toPay }("");
       if (!sent) revert RefundPaymentFailed();
   }
   ```

5. **Non-Transferable NFTs**: Correctly implemented
   ```solidity
   function _beforeTokenTransfer(...) internal virtual override {
       if (from != address(0)) revert TransferNotAllowed(from, to, firstTokenId);
       // Only minting allowed
   }
   ```

6. **Integer Overflow**: Safe (Solidity 0.8.24 has checked arithmetic)

---

## Coverage Summary

**Files Reviewed:** 4/8 core contracts (100% of critical code paths)

| File | Status | Critical Paths Traced |
|------|--------|----------------------|
| PlayFiLicenseSale.sol | ✅ Complete | All claim functions, referral system, tier management |
| PlayFiLicense.sol | ✅ Complete | Minting, transfer restrictions, tokenURI |
| PlayFiLicenseMint.sol | ✅ Complete | Cross-chain minting, signature verification |
| PreOrderLicenseClaimer.sol | ✅ Complete | Batch claiming logic |

**Not Reviewed:** Interfaces (not security-critical), deployment scripts, tests

---

## Recommendations Priority

### High Priority
1. **Fix Finding #2** - Preserve old referral codes to prevent link breakage
2. **Address Finding #1** - Implement code reservation system for official campaigns

### Medium Priority  
3. **Fix Finding #3** - Update commission calculation timing (or document behavior)
4. **Add Events** - Emit events when old referral codes are replaced

### Low Priority
5. **Documentation** - Clarify referral code lifecycle in user docs
6. **Testing** - Add test cases for referral edge cases

---

**Audit completed:** 2026-09-16  
**Researcher:** deviykee (Iyke)  
**Contact:** http://x.com/deviykee

