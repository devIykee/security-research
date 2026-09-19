# HINKAL PROTOCOL - MEDIUM/LOW SEVERITY FINDINGS & EDGE CASES

## 1. Missing Pause Mechanism

**Severity**: Medium  
**Component**: All contracts (Hinkal.sol, HinkalBase.sol)

**Issue**: Protocol has no emergency pause functionality.

**Impact**:
- If a critical vulnerability is discovered, protocol cannot be paused
- Funds continue to be at risk until fix is deployed
- Cannot stop ongoing attacks

**Evidence**:
```solidity
// No pause mechanism in Hinkal.sol or HinkalBase.sol
function transact(...) public payable nonReentrant {
    // No whenNotPaused modifier
}
```

**Recommendation**: Implement Pausable from OpenZeppelin:
```solidity
import "@openzeppelin/contracts/security/Pausable.sol";

function transact(...) public payable nonReentrant whenNotPaused {
```

**Status**: MEDIUM - Lack of emergency controls

---

## 2. Admin Centralization Risks

**Severity**: Trust/Centralization (Medium)  
**Component**: VerifierFacade.sol, HinkalBase.sol, Hinkal.sol

**Issue**: Admin (DEFAULT_ADMIN_ROLE) has significant power without timelock.

**Admin Capabilities**:
1. Register malicious external actions
2. Update HinkalHelper to malicious contract
3. Register/remove verifiers (can brick the protocol)

**Evidence**:
```solidity
// Hinkal.sol line 22-28
function registerExternalAction(uint256 externalActionId, address externalActionAddress) 
    public onlyRole(DEFAULT_ADMIN_ROLE) {
    externalActionMap[externalActionId] = externalActionAddress;
}

// HinkalBase.sol line 46-50
function setHinkalHelper(address _hinkalHelper) 
    external onlyRole(HINKAL_HELPER_MANAGER) {
    hinkalHelper = IHinkalHelper(_hinkalHelper);
}

// VerifierFacade.sol line 13-21
function registerVerifiers(uint256[] calldata verifierIds, address[] calldata verifierAddresses) 
    external onlyOwner {
    for (uint i = 0; i < verifierIds.length; i++) {
        verifierMap[verifierIds[i]] = IVerifier(verifierAddresses[i]);
    }
}
```

**Attack Scenario** (compromised admin):
1. Admin registers malicious external action
2. External action appears legitimate
3. Users interact with it via private transactions
4. Malicious external action manipulates return values or has backdoors

**Mitigation**: Already in place - external actions are whitelisted and should be audited before registration.

**Recommendation**: Add timelock for sensitive admin operations.

**Status**: TRUST/CENTRALIZATION - Document in security report

---

## 3. Relay Authorization Using tx.origin

**Severity**: Low to Medium  
**Component**: HinkalHelper.sol

**Issue**: Relay validation uses `tx.origin` check.

**Evidence**:
```solidity
// HinkalHelper.sol lines 30-35
function relayerIsValid(address relay) internal view {
    if (relay != address(0)) {
        require(tx.origin == relay, "Unauthorized relay");
        require(isRelayInList(relay), "Relay is not whitelisted");
    }
}
```

**Why tx.origin is used**: To ensure the relay EOA initiated the transaction.

**Potential Issues**:
1. **Anti-pattern**: `tx.origin` is generally discouraged in Solidity
2. **Contract wallets**: Users with smart contract wallets cannot use relay feature
3. **Future incompatibility**: Some L2s or account abstraction may break this

**Edge Case**:
- User with Gnosis Safe or Argent wallet wants to use relay
- Safe/Argent is contract, not EOA
- `tx.origin` would be the Safe owner, not the Safe itself
- Relay check might behave unexpectedly

**Severity Assessment**: LOW - Design choice for relay authorization, not exploitable for fund theft

**Recommendation**: Document that relay feature requires EOA transactions.

---

## 4. No Upper Bound on Merkle Tree Size

**Severity**: Low  
**Component**: Merkle.sol, MerkleBase.sol

**Issue**: Merkle tree can grow indefinitely until hitting the level limit.

**Evidence**:
```solidity
// Merkle.sol lines 20-24
function insert(uint256 leaf) internal override returns (uint256) {
    uint256 newIndex = ++m_index;
    uint256 currentNodeIndex = newIndex - 1;
    
    require(m_index <= uint256(2) ** LEVELS, "Tree is full.");
```

**Analysis**:
- Tree depth is set at deployment (immutable `LEVELS`)
- Maximum insertions = 2^LEVELS
- Once full, no more commitments can be added
- Protocol would be bricked

**For typical values**:
- If LEVELS = 20: max 1,048,576 commitments
- If LEVELS = 30: max 1,073,741,824 commitments

**Questions**:
1. What is the actual LEVELS value in deployment?
2. Is there a plan for tree migration when full?

**Impact**: 
- High tree depth increases proof generation cost and gas
- Low tree depth means tree fills up faster
- No migration mechanism visible in code

**Recommendation**: 
- Document expected tree lifetime
- Plan for tree migration/upgrade

**Status**: LOW - Operational concern, not immediate security risk

---

## 5. Potential Front-Running of Deposits

**Severity**: Low  
**Component**: prooflessDeposit()

**Issue**: Anyone can deposit to anyone's stealth address.

**Evidence**:
```solidity
// Hinkal.sol lines 263-295
function prooflessDeposit(
    address[] calldata erc20Addresses,
    uint256[] calldata amounts,
    StealthAddressStructure[] calldata stealthAddressStructures,
    bytes[] calldata onChainEncryptedOutputs,
    bool createBlockedUtxos,
    string calldata orderId
) public payable nonReentrant {
```

**Scenario**:
1. Alice wants to deposit 100 USDC to her stealth address
2. Alice broadcasts transaction
3. Bob sees Alice's transaction in mempool
4. Bob front-runs and deposits 1 wei to Alice's stealth address
5. Alice's transaction executes after

**Impact**:
- Minimal - Alice still gets her deposit
- Could be used for dusting attacks (privacy degradation)
- `createBlockedUtxos` flag could be manipulated by front-runner

**Actually, re-reading**:
```solidity
if (createBlockedUtxos) {
    markUtxosAsBlocked();
}

function markUtxosAsBlocked() internal {
    emit BlockedUtxosCreated();
}
```

This just emits an event. Off-chain indexers track blocked UTXOs, but anyone can emit this event.

**Real Issue**: `createBlockedUtxos` flag has no access control. Anyone can create "blocked" UTXOs for any stealth address.

**Impact**: Privacy/UX issue - blocked UTXOs tracked off-chain, attacker could pollute someone's UTXO set

**Severity**: LOW - Privacy/UX issue, not fund loss

---

## 6. No Slippage Check on Internal Transactions (Withdrawals)

**Severity**: Low  
**Component**: Hinkal.sol _internalTransact()

**Issue**: Slippage check (line 111-114) applies to all tokens, but for pure withdrawals, slippage is unnecessary.

**Evidence**:
```solidity
// Hinkal.sol lines 111-114
require(
    balanceDif >= circomData.slippageValues[i],
    "slippage param is violated"
);
```

**Analysis**:
For pure withdrawal (no swaps):
- User expects exact amount
- No slippage should occur
- But user must still provide slippageValues

**Edge Case**:
- User withdraws 100 USDC
- Sets slippageValues[0] = -100 (expecting -100 balance change)
- If relay fee is deducted, actual balance change might be -100.5
- Check: -100.5 >= -100 ? FALSE → reverts

**Wait, let me check the relay fee logic again...**

Looking at lines 206-216 in Hinkal.sol:
```solidity
relayFee = sumAbs - recipientAmount;

if (relayFee > 0) {
    transferERC20TokenOrETH(circomData.erc20TokenAddresses[i], circomData.relay, relayFee);
}
```

Relay fee is paid from the withdrawn amount, not extra. So:
- User withdraws 100 USDC (sumAbs = 100)
- Relay fee = 10 USDC
- User receives 90 USDC
- Hinkal balance change = -100

So balance change includes the relay fee. No issue here.

**Status**: FALSE ALARM - No issue

---

## 7. CircomData calldataHash Integrity

**Severity**: Informational  
**Component**: CircomDataBuilder.sol, HinkalHelper.sol

**Analysis**: 
```solidity
// HinkalHelper.sol lines 221-225
require(
    CircomDataBuilder.getHashedCalldata(circomData) == circomData.calldataHash,
    "Calldata Hash Integrity Check Failed"
);
```

**Purpose**: User's ZK proof commits to `calldataHash`, which is hash of circomData fields.

**Protection**: Ensures user consented to all the transaction parameters (hooks, relay, fees, etc.)

**This is GOOD** - Prevents anyone from modifying the transaction parameters after proof generation.

**Status**: ✅ GOOD DESIGN

---

## SUMMARY OF FINDINGS

### Critical: None Found

### High: None Found

### Medium:
1. **Missing Pause Mechanism** - No emergency stop
2. **Admin Centralization** - Admin trust required for external actions

### Low:
1. **tx.origin for Relay** - Anti-pattern, contract wallet incompatibility
2. **Merkle Tree Finality** - No migration plan when tree is full
3. **Proofless Deposit Front-Running** - Privacy/UX issue with createBlockedUtxos flag

### Informational:
1. CalldataHash integrity check is good design

## Recommendation: Focus on Trust/Centralization Documentation

The protocol is well-designed with strong security properties. Main recommendations:
1. Add pause mechanism for emergency response
2. Document admin trust assumptions
3. Consider timelock for admin operations
4. Document relay feature limitations (EOA only)
5. Plan for merkle tree migration
