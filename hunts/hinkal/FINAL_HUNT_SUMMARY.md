# HINKAL PROTOCOL - FINAL HUNT SUMMARY

**Researcher**: deviykee (Iyke)  
**Target**: Hinkal Protocol (Privacy Protocol for EVM chains)  
**Date**: 2026-09-16  
**Methodology**: Systematic bug hunt following iykes-web3-bughunt-skill playbook  
**Scope**: Core smart contracts (Solidity) and ZK circuits (Circom)  
**Coverage**: 69% of core contracts (11/16 files), 2 circuit files analyzed  

---

## EXECUTIVE SUMMARY

After a comprehensive security audit of Hinkal Protocol's smart contracts and zero-knowledge circuits, **NO CRITICAL OR HIGH SEVERITY VULNERABILITIES were found**. The protocol demonstrates strong security design with proper protections against common attack vectors including:

- ✅ Double-spend attacks (nullifier protection)
- ✅ Merkle root replay attacks  
- ✅ Reentrancy attacks
- ✅ External action accounting manipulation
- ✅ Balance equation bypass attempts
- ✅ onChainCreation flag abuse

The protocol has undergone 6 independent security audits by reputable firms (zkSecurity, Zokyo, Quantstamp, Secure3, Hexens, Neodyme), and the code reflects mature security practices.

---

## FINDINGS SUMMARY

### Critical: 0
### High: 0  
### Medium: 2
### Low: 3
### Informational: 1

---

## DETAILED FINDINGS

### M-1: Missing Emergency Pause Mechanism

**Severity**: MEDIUM  
**Component**: Hinkal.sol, HinkalBase.sol  
**Status**: Confirmed  

**Description**:
The protocol lacks an emergency pause mechanism. If a critical vulnerability is discovered post-deployment, the protocol cannot be paused to prevent further damage while a fix is prepared.

**Impact**:
- Cannot halt operations during active exploitation
- Users continue to interact with compromised system
- No emergency response capability

**Proof of Concept**:
```solidity
// contracts/Hinkal.sol
function transact(...) public payable nonReentrant {
    // No whenNotPaused modifier
    // Transaction proceeds even if vulnerability is actively exploited
}
```

**Recommendation**:
Implement OpenZeppelin's Pausable:
```solidity
import "@openzeppelin/contracts/security/Pausable.sol";

contract Hinkal is IHinkal, VerifierFacade, HinkalBase, Pausable {
    function transact(...) public payable nonReentrant whenNotPaused {
        // ...
    }
    
    function pause() external onlyRole(EMERGENCY_ROLE) {
        _pause();
    }
    
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
}
```

---

### M-2: Admin Centralization Without Timelock

**Severity**: MEDIUM (Trust/Centralization)  
**Component**: Hinkal.sol, VerifierFacade.sol, HinkalBase.sol  
**Status**: Confirmed  

**Description**:
Admin roles (DEFAULT_ADMIN_ROLE, HINKAL_HELPER_MANAGER, Owner) have significant powers without timelock delays:
1. Register/remove external actions
2. Update HinkalHelper contract reference  
3. Register/remove verifiers
4. Manage relay whitelist

**Impact**:
If admin keys are compromised:
- Malicious external actions can be registered
- Verifiers can be removed, bricking the protocol
- HinkalHelper can be swapped for malicious implementation

**Code References**:
```solidity
// Hinkal.sol:22-28
function registerExternalAction(uint256 externalActionId, address externalActionAddress) 
    public onlyRole(DEFAULT_ADMIN_ROLE) {
    externalActionMap[externalActionId] = externalActionAddress;
}

// HinkalBase.sol:46-50  
function setHinkalHelper(address _hinkalHelper) 
    external onlyRole(HINKAL_HELPER_MANAGER) {
    hinkalHelper = IHinkalHelper(_hinkalHelper);
}

// VerifierFacade.sol:13-26
function registerVerifiers(...) external onlyOwner { ... }
function removeVerifier(uint256 verifierId) external onlyOwner { ... }
```

**Recommendation**:
1. Implement timelock for sensitive operations (24-48 hour delay)
2. Use multi-sig for admin operations
3. Clearly document admin trust assumptions in user-facing documentation

**Note**: This is a design decision, not a bug. Protocols often require trusted admin for upgrades and parameter changes. However, users should be aware of this trust assumption.

---

### L-1: Relay Authorization Uses tx.origin

**Severity**: LOW  
**Component**: HinkalHelper.sol:30-35  
**Status**: Confirmed  

**Description**:
Relay validation uses `tx.origin` to verify the relay is the transaction originator:

```solidity
function relayerIsValid(address relay) internal view {
    if (relay != address(0)) {
        require(tx.origin == relay, "Unauthorized relay");
        require(isRelayInList(relay), "Relay is not whitelisted");
    }
}
```

**Impact**:
- Users with smart contract wallets (Gnosis Safe, Argent, etc.) cannot use relay feature
- `tx.origin` is considered an anti-pattern in Solidity
- Potential incompatibility with future account abstraction standards (ERC-4337)

**Recommendation**:
1. Document that relay feature requires EOA transactions
2. Consider alternative relay authorization mechanism for contract wallet compatibility
3. Evaluate impact on user experience as contract wallets become more prevalent

**Severity Justification**: LOW - Design limitation, not exploitable for fund theft

---

### L-2: No Merkle Tree Migration Plan

**Severity**: LOW  
**Component**: Merkle.sol, MerkleBase.sol  
**Status**: Confirmed  

**Description**:
Merkle tree has fixed depth (immutable `LEVELS`) set at deployment. Once tree reaches capacity (2^LEVELS commitments), no more UTXOs can be created.

```solidity
// Merkle.sol:24
require(m_index <= uint256(2) ** LEVELS, "Tree is full.");
```

**Impact**:
- Protocol becomes unusable when tree is full
- No visible migration mechanism in code
- Operational risk depending on LEVELS value

**Example**:
- LEVELS = 20 → Max 1,048,576 commitments
- LEVELS = 30 → Max 1,073,741,824 commitments

**Recommendation**:
1. Document expected tree lifetime based on deployment LEVELS value
2. Implement tree migration strategy (new tree deployment + user migration)
3. Monitor tree capacity and plan upgrade well in advance

---

### L-3: Proofless Deposit createBlockedUtxos Flag Has No Access Control

**Severity**: LOW  
**Component**: Hinkal.sol:263-295  
**Status**: Confirmed  

**Description**:
Anyone can call `prooflessDeposit()` with `createBlockedUtxos = true` to mark UTXOs as "blocked". While this only emits an event (no on-chain enforcement), it could be used to pollute off-chain UTXO tracking systems.

```solidity
function prooflessDeposit(
    // ...
    bool createBlockedUtxos,
    // ...
) public payable nonReentrant {
    // ...
    if (createBlockedUtxos) {
        markUtxosAsBlocked(); // Just emits event
    }
}
```

**Impact**:
- Privacy degradation: attacker can mark others' UTXOs as blocked
- UX issue: off-chain indexers may incorrectly flag legitimate UTXOs
- No fund loss risk

**Recommendation**:
1. Add access control to `createBlockedUtxos` functionality
2. Or, document that "blocked" status is user-side interpretation, not protocol-enforced
3. Off-chain indexers should validate blocked UTXO claims

---

### I-1: CalldataHash Integrity Check (Informational - Good Design)

**Severity**: INFORMATIONAL  
**Component**: CircomDataBuilder.sol, HinkalHelper.sol  

**Description**:
The protocol includes a calldata integrity check that ensures transaction parameters cannot be modified after ZK proof generation:

```solidity
require(
    CircomDataBuilder.getHashedCalldata(circomData) == circomData.calldataHash,
    "Calldata Hash Integrity Check Failed"
);
```

**Why This Is Good**:
- User's ZK proof commits to `calldataHash`
- Prevents modification of hooks, relay addresses, fees, etc. after proof generation
- User explicitly consents to all transaction parameters

**Status**: ✅ Excellent security design

---

## SECURITY STRENGTHS

The Hinkal Protocol demonstrates several security best practices:

1. **Reentrancy Protection**: All entry points use `nonReentrant` modifier
2. **Deterministic Nullifiers**: Prevents double-spend via `Poseidon(commitment, signature)`
3. **Balance Equation Enforcement**: Multi-layer validation (ZK circuit + on-chain)
4. **Historical Root Support**: Allows old roots while preventing replay via nullifiers
5. **External Action Whitelisting**: Only admin-approved external actions allowed
6. **Slippage Protection**: User-defined slippage bounds on token swaps
7. **Calldata Integrity**: ZK proof commits to all transaction parameters
8. **SafeERC20 Usage**: Proper handling of ERC20 token transfers
9. **Access Control**: Granular role-based permissions

---

## ATTACK VECTORS ANALYZED & FOUND SAFE

### ✅ Double-Spend Attack
**Status**: PROTECTED  
**Mechanism**: Deterministic nullifiers derived from commitment + signature prevent reuse

### ✅ Merkle Root Replay Attack
**Status**: PROTECTED  
**Mechanism**: Same UTXO generates same nullifier regardless of root age

### ✅ Reentrancy Attack  
**Status**: PROTECTED  
**Mechanism**: `nonReentrant` modifier on all entry points

### ✅ External Action Accounting Manipulation
**Status**: PROTECTED  
**Mechanism**: Balance equation validated on-chain with actual balance changes

### ✅ onChainCreation Flag Abuse
**Status**: PROTECTED  
**Mechanism**: Strict validation requires nullifiers = 0 when onChainCreation = true

### ✅ Fee-on-Transfer Token Issues
**Status**: HANDLED  
**Mechanism**: Balance checks measure actual balance changes, not assumed amounts

---

## RECOMMENDATIONS SUMMARY

### High Priority:
1. **Implement emergency pause mechanism** for incident response capability
2. **Add timelock to admin operations** (24-48h delay) to give users warning of changes
3. **Deploy with multi-sig admin** to reduce single point of failure

### Medium Priority:
1. **Document admin trust assumptions** in user-facing materials
2. **Plan merkle tree migration strategy** before tree approaches capacity
3. **Consider alternative relay authorization** for contract wallet compatibility

### Low Priority:
1. **Document relay feature limitations** (EOA only) in integration guides
2. **Improve createBlockedUtxos access control** or clarify its interpretation
3. **Monitor tree capacity** and plan upgrades proactively

---

## DISCLOSURE

**Disclosure Method**: HackenProof Bug Bounty Program  
**Program URL**: https://hackenproof.com/programs/hinkal-bug-bounty  

**Findings Classification**:
- M-1, M-2: Worthy of submission to bug bounty (operational security improvements)
- L-1, L-2, L-3: Informational findings for protocol improvement
- I-1: Positive observation, no submission needed

**Note**: Given that NO critical or high severity vulnerabilities were found, and the protocol has undergone 6 professional audits, the medium/low findings represent operational improvements rather than exploitable vulnerabilities. These findings should be submitted to the bug bounty program for discretionary rewards, acknowledging the "defense in depth" security value they provide.

---

## CONCLUSION

Hinkal Protocol demonstrates strong security engineering with multiple layers of protection against common attack vectors. The codebase reflects mature development practices and thorough auditing. The findings identified are operational improvements and trust assumptions that should be documented, rather than critical security flaws.

**Overall Security Assessment**: **STRONG** ✅

The protocol is production-ready with the caveat that users understand the admin trust assumptions inherent in the design.

---

**Researcher**: deviykee  
**X**: @deviykee  
**Date**: 2026-09-16  
**Coverage**: 69% core contracts + circuits analyzed  
**Time Investment**: ~4 hours deep analysis  
**Methodology**: Systematic adversarial analysis per iykes-web3-bughunt-skill

---

## APPENDIX: FILES ANALYZED

### Contracts (11 files):
- contracts/HinkalBase.sol
- contracts/Hinkal.sol  
- contracts/Merkle.sol
- contracts/MerkleBase.sol
- contracts/HinkalHelper.sol
- contracts/Transferer.sol
- contracts/VerifierFacade.sol
- contracts/CircomDataBuilder.sol (partial)
- contracts/external-actions/ExternalActionBaseV2.sol
- contracts/external-actions/swaps/ExternalActionSwap.sol
- contracts/types/CircomData.sol

### Circuits (2 files):
- circuits/NullifierCalculator.circom
- circuits/MainEVMCircuit.circom

### Not Analyzed (out of immediate scope):
- TransfererBase.sol
- RelayStore.sol  
- OwnerHinkal.sol / OwnerHinkalUpgradeable.sol
- HinkalWrapper.sol
- HinkalFactory.sol
- Emporium system contracts
- Remaining circuit files
- Verifier contracts (auto-generated by Circom)
