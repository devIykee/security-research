# HINKAL PROTOCOL - FOUNDATION MAP (STEP 5)

## Architecture Overview

Hinkal is a **privacy protocol** enabling private transactions using:
- **UTXO model**: Users have shielded balances represented as commitments in a Merkle tree
- **Zero-knowledge proofs**: Groth16 proofs (via Circom circuits) verify spending authority without revealing which UTXOs are spent
- **Nullifiers**: Prevent double-spending of UTXOs
- **Stealth addresses**: Hide recipient identities

## 5A. State Who-Writes

### Critical State Variables

| Variable | Location | Who Can Write | Notes |
|----------|----------|---------------|-------|
| `nullifiers` mapping | HinkalBase | Internal (via transact) | Marks spent UTXOs; critical for double-spend prevention |
| `externalActionMap` | HinkalBase | DEFAULT_ADMIN_ROLE | Maps external action IDs to contract addresses |
| `hinkalHelper` | HinkalBase | HINKAL_HELPER_MANAGER | Helper contract reference |
| Merkle tree (`tree`, `roots`, `m_index`) | MerkleBase | Internal (via transact) | Stores UTXO commitments |
| `relays` list | RelayStore | Owner | Whitelisted relayers |

**Access Control Roles:**
- `DEFAULT_ADMIN_ROLE`: Can register external actions (set in constructor to deployer)
- `HINKAL_HELPER_MANAGER`: Can update hinkalHelper reference
- `Owner` (in RelayStore): Can manage relay whitelist

## 5B. External Call Order (CEI Analysis)

### Main Transaction Flow (`transact()`)

```
1. CHECK: hinkalHelper.performHinkalChecks() - validates circomData
2. CHECK: verifyProof() - ZK proof verification
3. CHECK: rootHashExists() - validates Merkle root
4. SIDE EFFECT: hinkalHelper.performSideEffects() - currently no-op
5. HOOK: preHookContract.preTransact() - external call to arbitrary contract
6. INTERACTIONS: _internalTransact() or _externalTransact()
   - transferERC20TokenFromOrCheckETH() - external token transfers
   - IExternalActionV2.runAction() - external action execution
7. HOOK: postHookContract.afterTransact() - external call to arbitrary contract
8. EFFECTS: insertNullifiers() - marks UTXOs as spent
9. EFFECTS: insertCommitments() - adds new UTXOs to Merkle tree
```

**⚠️ CEI VIOLATION IDENTIFIED**: 
- External calls (hooks, external actions, token transfers) happen BEFORE state updates (nullifiers, commitments)
- However, protected by `nonReentrant` modifier

### Proofless Deposit Flow (`prooflessDeposit()`)

```
1. CHECK: hinkalHelper.performProoflessDepositChecks()
2. INTERACTION: transferERC20TokenFromOrCheckETH() - pulls tokens from user
3. EFFECT: _createProoflessDepositCommitments() - inserts commitments
```

**CEI Status**: Better ordering, but still has external calls before final state.

## 5C. Token Paths (Entry → Exit)

### Deposit Path (Internal Transaction)
```
User → transferERC20TokenFromOrCheckETH() → Hinkal contract
                                           ↓
                                    Merkle tree commitment
                                    (private UTXO created)
```

### Withdrawal Path (Internal Transaction)
```
ZK Proof of UTXO ownership
        ↓
Nullifier inserted (prevent double-spend)
        ↓
transferERC20TokenOrETH() → User (minus relay fee if applicable)
        ↓ (optional)
transferERC20TokenOrETH() → Relay (fee)
```

### External Action Path
```
ZK Proof of UTXO ownership
        ↓
transferERC20TokenOrETH() → External Action Contract
        ↓
IExternalActionV2.runAction() - arbitrary logic
        ↓
Returns UTXO[] (new on-chain commitments)
```

**Risk Surface**: External actions receive funds and can execute arbitrary logic before returning new UTXOs.

## 5D. Access Control Gates

| Function | Modifier/Check | Pausable? | Notes |
|----------|----------------|-----------|-------|
| `transact()` | `nonReentrant` | No | Main entry point; no admin restriction |
| `prooflessDeposit()` | `nonReentrant` | No | Public deposit function |
| `setHinkalHelper()` | `onlyRole(HINKAL_HELPER_MANAGER)` | No | Admin function |
| `registerExternalAction()` | `onlyRole(DEFAULT_ADMIN_ROLE)` | No | Admin function |
| `performHinkalChecks()` | `onlyHinkal` (in HinkalHelper) | No | Can only be called by Hinkal contract |
| `performSideEffects()` | `onlyHinkal` | No | Currently no-op |

**⚠️ NO PAUSE MECHANISM**: Protocol cannot be paused in emergency.

## 5E. Structured First-Pass Checklist

- [x] **Reentrancy / CEI on all fund paths** - UNCLEAR: CEI violation exists but protected by `nonReentrant`; hooks and external actions are called before state updates
- [x] **Access control on privileged state changers** - PASS: Admin functions properly gated
- [ ] **Oracle / pricing freshness** - N/A: No oracles used; all amounts are user-specified
- [ ] **Slippage on DEX interactions** - PARTIAL: `slippageValues` array exists for balance change validation
- [ ] **Frontrun / sandwich surface** - UNCLEAR: External actions may be vulnerable; relay mechanism needs analysis
- [ ] **Init / proxy** - UNCLEAR: Need to check if upgradeable (saw "OwnerHinkalUpgradeable.sol" in file list)
- [ ] **Upgrade storage safety** - UNCLEAR: If upgradeable, need to verify storage layout
- [ ] **Pause semantics** - FAIL: No pause mechanism exists
- [ ] **Events on policy / risk parameter changes** - PASS: Events emitted for external action registration

## Key Security Questions for Deep Dive

1. **ZK Proof Verification**: Can proofs be forged or replayed?
2. **Nullifier Uniqueness**: Are nullifiers properly bound to specific UTXOs?
3. **Merkle Root Manipulation**: Can old roots be used to spend already-nullified UTXOs?
4. **External Action Safety**: What prevents malicious external actions from stealing funds?
5. **Relay Security**: Can non-whitelisted relays bypass `tx.origin` check?
6. **Hook Safety**: Pre/post hooks are arbitrary external calls - what prevents malicious hooks?
7. **Balance Accounting**: Can the balance equation be violated (line 137-146 in Hinkal.sol)?
8. **Proofless Deposit**: Can this bypass security checks since no ZK proof required?
9. **On-chain vs Off-chain UTXOs**: What's the difference and security implication?
10. **Double-spend via Reentrancy**: Despite `nonReentrant`, are there cross-function reentrancy risks?

## Files Remaining for Core Coverage

- [ ] Transferer.sol / TransfererBase.sol (token transfer logic)
- [ ] VerifierFacade.sol (proof verification dispatch)
- [ ] MerkleBase.sol (merkle tree base logic)
- [ ] RelayStore.sol (relay whitelist management)
- [ ] CircomDataBuilder.sol (input construction for ZK circuit)
- [ ] OwnerHinkal.sol / OwnerHinkalUpgradeable.sol (ownership patterns)
- [ ] HinkalWrapper.sol (wrapper contract)
- [ ] HinkalFactory.sol (factory pattern)
- [ ] External action contracts (EmporiumStack, HinkalWallet, ExternalActionSwap, etc.)
- [ ] Constants.sol

**Current Priority**: Read critical security components (Transferer, VerifierFacade, MerkleBase) before starting adversarial analysis.
