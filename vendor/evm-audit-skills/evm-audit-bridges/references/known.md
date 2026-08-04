# evm-audit-bridges — KNOWN (Opus Already Knows)

*Generated: 2026-02-28 | Items: 16*

ℹ️  Opus explains these deeply from training. Lowest priority for skill inclusion.

- [ ] **Double normalization/denormalization**: If a value is already normalized, normalizing again causes massive precision loss. Look for: multiple normalize/denormalize calls on the same value through call chains. [Wormhole checklist]

- [ ] **Duplicate guardian signatures bypass quorum**: If signature uniqueness per guardian index isn't enforced, one guardian's signature can be submitted multiple times to meet the 2/3+1 quorum. Look for: signature verification loops without guardian index deduplication. [Wormhole checklist]

- [ ] **`handleV3AcrossMessage` must check `msg.sender == acrossSpokePool`**: Without this check, anyone can call with arbitrary data. Look for: missing sender validation in Across message handlers. [Across checklist]

- [ ] **Signed messages must include**: token type, both chain IDs, receiver, amount, nonce, and EIP-712 domain separator. Missing any field enables replay or spoofing. [Spearbit bridge checklist C6.1]

- [ ] **Used signatures must be invalidated**: After execution, the signature/message hash must be marked as used to prevent replay. [Spearbit bridge checklist C6.2]

- [ ] **Chain identifier cannot be spoofed**: Source and destination chain IDs must be in the signed message and verified against actual execution chain. [Spearbit bridge checklist C6.4, C6.5]

- [ ] **Challenge window long enough for human response**: For optimistic bridges, the challenge period must allow incident response (30+ min minimum). Consider per-chain based on weakest chain's finality. [Spearbit bridge checklist]

- [ ] **All necessary values must be in signed bridge message**: Token type, chain IDs (source + destination), receiver address, amount, nonce. Missing any field allows replay or spoofing. Look for: bridge message encoding that omits chain ID, nonce, or receiver. [Spearbit Bridge C6.1]

- [ ] **Signature invalidation after use**: Used bridge signatures must be marked as spent. Without this, the same message can be replayed. Look for: bridge relay functions that don't mark message hashes as consumed. [Spearbit Bridge C6.2]

- [ ] **Message hash collision resistance**: If message hashing uses `abi.encodePacked` with variable-length fields, hash collisions are possible. Use `abi.encode` instead. Look for: `keccak256(abi.encodePacked(...))` in bridge message hashing with multiple dynamic types. [Spearbit Bridge C6.3]

- [ ] **Chain identifier spoofing**: If source/destination chain IDs aren't included in the signed message AND verified against expected values, an attacker can spoof cross-chain messages. Look for: bridge relayers that don't verify chain IDs match the expected source/destination. [Spearbit Bridge C6.4, C6.5]

- [ ] **Nonce required for duplicate operations**: Without a nonce, identical operations (same sender, receiver, amount) can't be distinguished, potentially blocking legitimate duplicate transfers. Look for: bridge message schemas without nonce field. [Spearbit Bridge C6.6]

- [ ] **EIP-712 domain separator for bridge messages**: Bridge signed messages should use EIP-712 domain separator to prevent cross-protocol replay. Look for: bridge signatures without domain separator or with incomplete domain parameters. [Spearbit Bridge C6.7]

- [ ] **Address aliasing in cross-chain auth**: When L1 contracts send messages to L2, `msg.sender` on L2 is the aliased address (`L1_address + 0x1111000000000000000000000000000000001111`). Auth checks on L2 must use `AddressAliasHelper.applyL1ToL2Alias()`. Look for: L2 contracts checking `msg.sender == L1_counterpart` without aliasing. [Arbitrum Checklist]

- [ ] **Unsupported chain whitelisting**: If a protocol accepts cross-chain messages from any chain, an attacker can deploy on an unsupported chain and send malicious messages. All compatible source chains must be whitelisted. Look for: cross-chain receivers without source chain validation. [beirao MC-10]

- [ ] **Bridge contract upgradability differs across chains**: A bridge contract may be immutable on one chain but upgradeable on another. A compromised upgrade on one chain can affect the entire bridge. Look for: cross-chain systems where upgrade authority differs per chain. [multichain-auditor]

