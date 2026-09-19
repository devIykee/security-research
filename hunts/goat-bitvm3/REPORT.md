# Comprehensive Security Audit: GOAT Network BitVM3 Bridge & Verifier Circuits

- **Target**: GOAT Network BitVM3
- **Repository 1**: `https://github.com/GOATNetwork/bitvm2-node` (`bitvm2-node`)
- **Repository 2**: `https://github.com/GOATNetwork/verifiable-circuit` (`bitvm2-gc`)
- **Bounty Program**: $5,000 USD BitVM3 Bug Bounty Campaign
- **Submission Channels**: GitHub Issues / PRs & Tally Form (`https://tally.so/r/EkGa02`)
- **Researcher**: deviykee
- **Date**: 2026-08-21
- **Skill Playbook**: `iykes-solana-bughunt-skill` / `iykes-evm-bughunt-skill`

---

## 1. INTAKE BLOCK

```
PROJECT_NAME   : GOAT Network BitVM3
X_HANDLE       : @GOATRollup
WEBSITE        : https://www.goat.network
BOUNTY_LINK    : https://www.goat.network/news/goat-bitvm3-bug-bounty-campaign
REPOSITORIES   :
  - https://github.com/GOATNetwork/bitvm2-node
  - https://github.com/GOATNetwork/verifiable-circuit
REWARD_POOL    : $5,000 USD
CHAINS         : Bitcoin (L1) <-> GOAT Network (L2 zkRollup)
SUBMISSION     : Tally Form (https://tally.so/r/EkGa02) / GitHub Issues & PRs
RESEARCHER     : deviykee
```

---

## 2. ARCHITECTURE & ATTACK SURFACE

```mermaid
flowchart TD
    subgraph Bitcoin L1 ["Bitcoin L1 Layer"]
        Deposit["Peg-In UTXO (check_pegin_opreturn)"]
        PreKickoff["Pre-Kickoff & Kickoff Transactions"]
        Assert["Assert Init & Commit Transactions (WOTS)"]
        Challenge["Watchtower & Disprove Transactions"]
        Take["Take-1 / Take-2 (Funds Claim)"]
    end

    subgraph Circuits & State Machine ["BitVM3 ZK & Verifier Circuits"]
        HeaderChain["Header Chain Circuit (SPV + MMR + Difficulty)"]
        CommitChain["Commit Chain Circuit (Tendermint Sequencer Set)"]
        StateChain["State Chain Circuit (CBFT + Reth EVM Execution)"]
        Groth16Ckt["Garbled Groth16 Verifier (BN254 Pairing)"]
    end

    subgraph Node & Operators ["GOAT Network Off-Chain Node"]
        Operator["Operator (Prover & Signer)"]
        Watchtower["Watchtowers (Challenge Initiator)"]
        Committee["MuSig2 Federation Committee"]
    end

    Deposit --> Operator
    Operator --> Assert
    Assert --> Circuits & State Machine
    Watchtower --> Challenge
    Circuits & State Machine --> Take
```

---

## 3. AUDIT FINDINGS SUMMARY

| Finding ID | Vulnerability Title | Severity | Impact |
|---|---|---|---|
| **GOAT-01** | State Machine Bypass on Execution Layer Block Verification via Missing Payload Guard (`check_el_block_from_payload`) | **High / Medium** | Unverified EVM block transitions accepted if `tx.body` is `None` |
| **GOAT-02** | Integer Underflow in Difficulty Adjustment Circuit on Timestamp Reordering (`calculate_new_difficulty`) | **Medium** | Circuit panic / proof generation failure on valid Bitcoin block sequences |
| **GOAT-03** | Slice Out-of-Bounds Panic on Truncated OP_RETURN Commitments (`apply_commit`) | **Medium** | Validator / Guest panic on malformed transaction outputs |
| **GOAT-04** | Panic on Empty Vector in `BitcoinMerkleTree::new` (`root()`) | **Low** | Denial of service / panic on empty block transaction sets |

---

## 4. DETAILED VULNERABILITY ASSESSMENTS

---

### [GOAT-01] State Machine Bypass on Execution Layer Block Verification via Missing Message Payload Guard

#### Location
- File: `crates/state-chain/src/cbft.rs:101-131`
- Method: `parse_cbft_tx_payload` & `check_el_block_from_payload`

#### Description
In `crates/state-chain/src/cbft.rs`, the state chain circuit verifies that execution layer (EL) EVM blocks match the payload committed inside Cosmos consensus transactions:

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

#### Vulnerability Mechanics
1. If a transaction has no body (`tx.body == None`), `parse_cbft_tx_payload` returns `None`.
2. In `check_el_block_from_payload`, the block number, block hash, and parent block hash assertions are enclosed inside `if let Some(payload)`.
3. When `None` is returned, **all three equality assertions are completely bypassed**. The function only verifies that the data hash matches `merkle_root_from_base64_txns(txs)`.
4. Furthermore, if `tx_body.messages` is empty, accessing `&tx_body.messages[0]` causes an immediate out-of-bounds panic.

#### Remediation
Refactor `parse_cbft_tx_payload` to return a `Result<ExecutionPayload, Error>` and require that every state chain block payload contains a valid message:
```rust
pub fn parse_cbft_tx_payload(tx_bytes: &[u8]) -> Result<ExecutionPayload, String> {
    let tx = Tx::decode(tx_bytes).map_err(|e| e.to_string())?;
    let tx_body = tx.body.ok_or_else(|| "Missing transaction body".to_string())?;
    if tx_body.messages.is_empty() {
        return Err("Empty messages in tx body".to_string());
    }
    let first_message = &tx_body.messages[0];
    if first_message.type_url != "/goat.goat.v1.MsgNewEthBlock" {
        return Err("Unexpected type_url".to_string());
    }
    let payload = proto::MsgNewEthBlock::decode(&first_message.value[..])
        .map_err(|e| e.to_string())?
        .payload
        .ok_or_else(|| "Missing execution payload".to_string())?;
    Ok(payload)
}
```

---

### [GOAT-02] Integer Underflow in Difficulty Adjustment Circuit on Timestamp Reordering

#### Location
- File: `crates/header-chain/src/header_chain.rs:321-342`
- Method: `calculate_new_difficulty`

#### Description
In Bitcoin, miners can produce blocks whose timestamps are slightly earlier than the epoch start time (as long as they exceed the 11-block Median Time Past).

```rust
fn calculate_new_difficulty(
    epoch_start_time: u32,
    last_timestamp: u32,
    current_target: u32,
) -> [u8; 32] {
    let mut actual_timespan = last_timestamp - epoch_start_time;
    ...
```

#### Vulnerability Mechanics
If a valid sequence of Bitcoin block headers contains `last_timestamp < epoch_start_time`, `last_timestamp - epoch_start_time` underflows:
- In debug mode / ZK guest builds with overflow checking: triggers an immediate panic, halting circuit execution.
- In release mode: wraps to `> 4.29e9`, which exceeds `EXPECTED_EPOCH_TIMESPAN * 4` and forces the maximum allowed difficulty drop (4x).

#### Remediation
Use checked / saturating arithmetic:
```rust
let mut actual_timespan = last_timestamp.saturating_sub(epoch_start_time);
```

---

### [GOAT-03] Slice Out-of-Bounds Panic on Truncated OP_RETURN Commitments

#### Location
- File: `crates/commit-chain/src/commit_chain.rs:165-172`
- Method: `apply_commit`

#### Description
```rust
let expected_latest_commit = extract_op_return_data(&latest_commit_txn_with_wtns.output);
if let Hash::Sha256(latest_sequencer_set_hash) = sequencer_hash(latest_sequencers) {
    assert_eq!(latest_sequencer_set_hash[..], expected_latest_commit[0..32]);
}
```

#### Vulnerability Mechanics
If `extract_op_return_data` extracts an OP_RETURN push with fewer than 32 bytes (or malformed output), `expected_latest_commit[0..32]` panics with slice indexing out of bounds, crashing the verifier node or guest prover.

#### Remediation
Validate slice length prior to indexing:
```rust
if expected_latest_commit.len() < 32 {
    panic!("OP_RETURN commitment is less than 32 bytes");
}
```

---

## 5. SUBMISSION DRAFTS FOR TALLY & GITHUB ISSUES

### Submission Form Draft (Tally / GitHub)
```text
Title:
Bypass of Execution Layer Block Integrity Verification in CBFT check_el_block_from_payload

Category:
State Machine / Verifier Circuit (crates/state-chain)

Severity:
High / Medium

Description:
In crates/state-chain/src/cbft.rs, parse_cbft_tx_payload returns Option<ExecutionPayload> and returns None when tx.body is None. In check_el_block_from_payload, the verification of block_number, block_hash, and parent_hash is placed inside 'if let Some(payload) = parse_cbft_tx_payload(&txs[0])'. When tx.body is None, these assertions are bypassed entirely, allowing unverified execution block transitions to pass through the state chain circuit if the Merkle data hash matches.

Steps to Reproduce:
1. Construct a Cosmos transaction bytes array where tx.body is None.
2. Pass this transaction into check_el_block_from_payload with arbitrary/mismatched el_block_number and el_block_hash.
3. Observe that parse_cbft_tx_payload returns None.
4. Observe that the function completes without validating el_block_number or el_block_hash against the transaction payload.

Remediation:
Enforce that parse_cbft_tx_payload returns a Result with an error when tx.body is missing or messages are empty, and ensure check_el_block_from_payload strictly fails when no valid MsgNewEthBlock payload is present.
```

