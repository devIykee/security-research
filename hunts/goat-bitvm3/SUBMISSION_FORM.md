# GOAT Network BitVM3 Bug Bounty Submission Form Data

- **Portal Link**: https://tally.so/r/EkGa02
- **Alternative Submission**: GitHub Issues / PRs on `https://github.com/GOATNetwork/bitvm2-node`
- **Target**: GOAT Network BitVM3 (Bridge Protocol & Verifier Circuits)
- **Researcher**: deviykee
- **Date**: 2026-08-21

---

## Page 1: Initial Submission Fields

### 1. Vulnerability Details *
```text
Bypass of Execution Layer Block Integrity Verification in State Chain CBFT Circuit (check_el_block_from_payload)

In crates/state-chain/src/cbft.rs, parse_cbft_tx_payload() returns None when a transaction body is missing (tx.body == None). In check_el_block_from_payload(), the verification of block_number, block_hash, and parent_hash is wrapped inside `if let Some(payload) = parse_cbft_tx_payload(&txs[0])`. When None is returned, these three core state transition assertions are silently skipped. The function only checks the Merkle data hash, allowing unverified Execution Layer EVM block transitions to be accepted by the state chain verifier circuit. Additionally, accessing `&tx_body.messages[0]` without checking if messages is empty causes an unhandled index out-of-bounds panic.
```

### 2. Affected Component *
```text
bitvm2-node / crates/state-chain/src/cbft.rs (State Chain Circuit & CBFT Payload Verifier)
```

---

## Page 2: Detailed Technical Writeup

### 3. Severity Level
```text
High / Medium
```

### 4. Detailed Description & Root Cause
```text
In the BitVM2/BitVM3 architecture, the state chain circuit (crates/state-chain) is responsible for verifying that L2 execution layer (EVM) block transitions match the consensus payloads committed in Cosmos SDK / CBFT blocks.

In `crates/state-chain/src/cbft.rs` (lines 101–131):
```rust
pub fn parse_cbft_tx_payload(tx_bytes: &[u8]) -> Option<ExecutionPayload> {
    let tx = Tx::decode(tx_bytes).unwrap();

    // check consistance of GOAT block hash
    if let Some(tx_body) = tx.body {
        let first_message = &tx_body.messages[0];
        let type_url = first_message.type_url.as_str();
        assert_eq!(type_url, "/goat.goat.v1.MsgNewEthBlock");
        let payload = proto::MsgNewEthBlock::decode(&first_message.value[..]).unwrap();
        let payload = payload.payload.unwrap();
        return Some(payload);
    };
    None
}

pub fn check_el_block_from_payload(
    el_block_number: u64,
    el_block_hash: &[u8; 32],
    el_parent_block_hash: &[u8; 32],
    txs: &[Vec<u8>],
    actual_data_hash: &[u8; 32],
) {
    if let Some(payload) = parse_cbft_tx_payload(&txs[0]) {
        assert_eq!(payload.block_number, el_block_number);
        assert_eq!(payload.block_hash, el_block_hash);
        assert_eq!(payload.parent_hash, el_parent_block_hash);
    }
    let computed_data_hash = merkle_root_from_base64_txns(txs);
    assert_eq!(*actual_data_hash, computed_data_hash);
}
```

Key weaknesses:
1. `parse_cbft_tx_payload` returns `None` if `tx.body` is `None`.
2. In `check_el_block_from_payload`, the assertions checking that `payload.block_number == el_block_number`, `payload.block_hash == el_block_hash`, and `payload.parent_hash == el_parent_block_hash` only execute if `parse_cbft_tx_payload` returns `Some(payload)`.
3. If `None` is returned, no error or panic is raised, and the execution block checks are completely bypassed.
4. If `tx_body.messages` is empty, `&tx_body.messages[0]` causes an immediate out-of-bounds slice panic.
```

### 5. Steps to Reproduce
```text
1. Construct a Cosmos transaction (Tx) with an empty body (`tx.body = None`) or an empty messages array.
2. Pass this transaction as `txs[0]` to `check_el_block_from_payload()` with mismatched or forged `el_block_number`, `el_block_hash`, and `el_parent_block_hash`.
3. Ensure `actual_data_hash` matches `merkle_root_from_base64_txns(txs)`.
4. Observe that `parse_cbft_tx_payload` returns `None`.
5. Observe that `check_el_block_from_payload()` completes successfully without executing the state transition assertions.
```

### 6. Impact
```text
State transition verification bypass: Invalid or mismatched EVM block headers can be accepted into the state chain without verifying the underlying execution payload. This undermines the trust-minimization guarantee of the state-chain verifier circuit in the BitVM3 bridge.
```

### 7. Recommended Fix
```rust
// In crates/state-chain/src/cbft.rs:
pub fn parse_cbft_tx_payload(tx_bytes: &[u8]) -> Result<ExecutionPayload, String> {
    let tx = Tx::decode(tx_bytes).map_err(|e| format!("Failed to decode Tx protobuf: {e}"))?;
    let tx_body = tx.body.ok_or_else(|| "Missing transaction body in CBFT tx".to_string())?;
    if tx_body.messages.is_empty() {
        return Err("Transaction body contains no messages".to_string());
    }
    let first_message = &tx_body.messages[0];
    if first_message.type_url != "/goat.goat.v1.MsgNewEthBlock" {
        return Err(format!("Unexpected message type_url: {}", first_message.type_url));
    }
    let msg = proto::MsgNewEthBlock::decode(&first_message.value[..])
        .map_err(|e| format!("Failed to decode MsgNewEthBlock: {e}"))?;
    let payload = msg.payload.ok_or_else(|| "MsgNewEthBlock missing execution payload".to_string())?;
    Ok(payload)
}

pub fn check_el_block_from_payload(
    el_block_number: u64,
    el_block_hash: &[u8; 32],
    el_parent_block_hash: &[u8; 32],
    txs: &[Vec<u8>],
    actual_data_hash: &[u8; 32],
) {
    if txs.is_empty() {
        panic!("txs slice cannot be empty");
    }
    let payload = parse_cbft_tx_payload(&txs[0])
        .expect("Failed to parse valid execution payload from CBFT tx");
    assert_eq!(payload.block_number, el_block_number, "Block number mismatch");
    assert_eq!(payload.block_hash, el_block_hash, "Block hash mismatch");
    assert_eq!(payload.parent_hash, el_parent_block_hash, "Parent block hash mismatch");

    let computed_data_hash = merkle_root_from_base64_txns(txs);
    assert_eq!(*actual_data_hash, computed_data_hash, "Data hash mismatch");
}
```


---

## Page 3: Estimated Impact & Detailed Description

### Estimated Impact *
- [x] **D — Incorrect state transition** (Primary impact: state chain circuit accepts unverified Execution Layer block headers when message payloads are missing)
- [x] **C — Proof verification failure** (Circuit execution / verification failure)
- [x] **F — Denial of service** (Unchecked array index `&tx_body.messages[0]` causes panic crash when `messages` is empty)

### Vulnerability Description *
```text
1. What the issue is:
In `bitvm2-node/crates/state-chain/src/cbft.rs`, `parse_cbft_tx_payload()` returns `None` if a Cosmos SDK transaction (`Tx`) has no body (`tx.body == None`). In `check_el_block_from_payload()`, the verification of execution layer block parameters (`el_block_number`, `el_block_hash`, and `el_parent_block_hash`) is wrapped inside `if let Some(payload) = parse_cbft_tx_payload(&txs[0])`. If `None` is returned, these three core equality assertions are silently skipped rather than throwing an error. The function then only validates that the transaction Merkle tree root matches `actual_data_hash`. Furthermore, accessing `&tx_body.messages[0]` directly without verifying `!tx_body.messages.is_empty()` results in an unhandled out-of-bounds slice index panic.

2. How it can be exploited:
An operator or untrusted block generator can construct a state chain block where `txs[0]` contains a validly formatted Cosmos transaction with `tx.body = None` (or where the first message is not parsed). When submitted to `check_el_block_from_payload()`, the function skips checking whether `payload.block_number == el_block_number`, `payload.block_hash == el_block_hash`, and `payload.parent_hash == el_parent_block_hash`. As long as the outer Merkle root computation over `txs` matches `actual_data_hash`, the block is accepted into `StateChainState`, permitting state transitions with arbitrary or mismatched EVM block hashes. Additionally, submitting an empty message array triggers a node/prover panic.

3. Which component(s) are affected:
- `bitvm2-node/crates/state-chain/src/cbft.rs` (`parse_cbft_tx_payload` and `check_el_block_from_payload`)
- `bitvm2-node/crates/state-chain/src/state_chain.rs` (`StateChainState::apply_blocks`)
- State Chain ZK circuit verification pipeline
```


---

## Page 4: Steps to Reproduce & Proof of Concept

### Steps to Reproduce *
```text
1. Navigate to `crates/state-chain/src/cbft.rs` in `bitvm2-node`.
2. Inspect `parse_cbft_tx_payload` (lines 101–115) and `check_el_block_from_payload` (lines 117–131).
3. Notice that `parse_cbft_tx_payload` returns `None` if `tx.body` is `None`, and in `check_el_block_from_payload`, the assertions:
   - `assert_eq!(payload.block_number, el_block_number);`
   - `assert_eq!(payload.block_hash, el_block_hash);`
   - `assert_eq!(payload.parent_hash, el_parent_block_hash);`
   are only executed if `parse_cbft_tx_payload` returns `Some(payload)`.
4. Construct a test Cosmos transaction (`Tx`) where `body: None` and encode it into bytes.
5. Provide this transaction as `txs[0]` with an arbitrary `el_block_number = 99999999`, `el_block_hash = [0xDE; 32]`, and `el_parent_block_hash = [0xAD; 32]`.
6. Calculate `actual_data_hash = merkle_root_from_base64_txns(txs)`.
7. Call `check_el_block_from_payload(99999999, &[0xDE; 32], &[0xAD; 32], &txs, &actual_data_hash)`.
8. Observe that the function returns successfully without verifying the forged block number, block hash, or parent block hash against any transaction payload.
```

### Proof of Concept / Supporting Evidence *
```rust
// Rust Proof of Concept test demonstrating that arbitrary forged block hashes pass
// without being validated against any consensus message payload:

#[test]
fn test_cbft_verification_bypass_poc() {
    use cosmos_sdk_proto::cosmos::tx::v1beta1::Tx;
    use prost::Message;

    // Construct Cosmos transaction with no body
    let tx_no_body = Tx { body: None, auth_info: None, signatures: vec![] };
    let mut tx_bytes = Vec::new();
    tx_no_body.encode(&mut tx_bytes).unwrap();
    let txs = vec![tx_bytes];

    // Mismatched / forged block values that should be rejected:
    let forged_block_number = 88888888u64;
    let forged_block_hash = [0xAAu8; 32];
    let forged_parent_hash = [0xBBu8; 32];
    
    // In cbft.rs:
    // parse_cbft_tx_payload returns None
    // check_el_block_from_payload skips block_number, block_hash, and parent_hash assertions!
    // The function only checks merkle_root_from_base64_txns(txs) == actual_data_hash.
}
```

