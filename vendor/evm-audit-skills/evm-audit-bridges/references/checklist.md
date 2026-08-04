# Bridge & Cross-Chain Security Checklist

## LayerZero V2

### Core Protocol
- [ ] **`lzReceive` OOG from lazy nonce loop**: `_clearPayload` loops from `lazyInboundNonce` to current nonce. If many messages are verified but not received, the loop causes OOG. Fix: process messages with lower nonces first to keep the gap small. Look for: large gaps between `lazyInboundNonce` and current nonce in message processing. [LayerZeroV2 checklist]

- [ ] **`lzCompose` must validate `from` AND `msg.sender`**: In composed messages, `from` must match the expected OFT contract (the one that queued the message via `sendCompose`). `msg.sender` must be EndpointV2. Missing either check allows unauthorized execution with arbitrary composed message data. Look for: `lzCompose` implementations without both validations. [LayerZeroV2 checklist]

- [ ] **Gas limit and msg.value from options are NOT enforced on-chain**: The options metadata is an off-chain agreement with the Executor. ANYONE can call `lzReceive` with different gas/value than specified in options. Look for: receiving contracts that assume msg.value or gas matches what was specified on sending side. Fix: encode expected values in the message payload and check on receive. [LayerZeroV2 checklist]

- [ ] **Un-ordered execution is the DEFAULT**: If nonce 4 fails, nonces 5 and 6 still execute. If you need ordered execution, implement `nextNonce()` AND ensure no reverting transactions (they permanently block all subsequent nonces). Look for: state-dependent cross-chain operations that assume ordering. [LayerZeroV2 checklist]

- [ ] **Native airdrop cap per chain**: The default LayerZero Executor limits native token airdrops per destination chain (e.g., 1500 MATIC for Polygon). Exceeding this silently fails. Look for: `lzSend` with native airdrop amounts near chain limits. [LayerZeroV2 checklist]

### OFT Standard
- [ ] **Dust removal strips 12 digits by default**: Default OFT uses 6 shared decimals. Sending `1.234567890123456789` tokens results in receiving `1.234567000000000000`. The 12 least significant digits are stripped. Dust isn't lost — it's cleaned from the input amount. Look for: custom fee logic that should call `_removeDust` after fee deduction, not before. [LayerZeroV2 checklist]

- [ ] **`_toSD` truncates to uint64 silently**: When `localDecimals == sharedDecimals == 18`, the conversion rate is 1, and `_toSD` casts to `uint64`. Any amount > `uint64.max` (~18.4e18) is silently truncated, losing value. Look for: OFT implementations that override `sharedDecimals` to match `localDecimals`. [LayerZeroV2 checklist]

### Configuration
- [ ] **Default libraries controlled by LayerZero team**: If your OApp doesn't explicitly configure send/receive libraries, it uses system defaults. LayerZero can change defaults at any time, potentially bricking your protocol. ALWAYS explicitly set your library configuration. Look for: OApp deployments without `setSendLibrary`/`setReceiveLibrary` calls. [LayerZeroV2 checklist]

- [ ] **`allowInitializePath` must be implemented for non-default receivers**: Without this, the first DVN verification fails silently. Default OApp checks if sender is a trusted peer. Custom receivers must implement their own logic. Look for: custom OApp receivers without `allowInitializePath`. [LayerZeroV2 checklist]

- [ ] **Pausing one direction**: `setPeer` enables bidirectional communication. To disable sending from one direction only, set `maxMessageSize` to 1 byte on the send library config — all sends revert. Look for: protocols that need unidirectional communication. [LayerZeroV2 checklist]

### LayerZero Read
- [ ] **Reverting read functions block all subsequent messages**: If `readCount`, `lzMap`, or `lzReduce` revert, DVNs can't verify that nonce. All messages with higher nonces are blocked until that nonce is resolved (via `EndpointV2::skip`). Look for: any revert possibility in read/compute functions. [LayerZeroV2 checklist]

## Chainlink CCIP

- [ ] **Default gas limit is 200,000**: If `gasLimit` isn't specified in `extraArgs`, CCIP uses 200K gas. Complex `ccipReceive()` implementations easily exceed this and silently fail. Unspent gas is NOT refunded. Look for: CCIP messages without explicit gas limit in extraArgs. [CCIP checklist]

- [ ] **Out-of-order execution flag is REQUIRED on some lanes**: When `allowOutOfOrderExecution` is Required (not Optional), setting it to `false` causes the message to revert entirely. Look for: CCIP messages to lanes with Required out-of-order execution that hardcode `false`. [CCIP checklist]

- [ ] **8-hour Smart Execution window**: If a message can't execute within 8 hours, ALL subsequent messages on that lane fail until the failing one succeeds (via manual execution). Look for: any scenario where `ccipReceive()` could permanently revert. [CCIP checklist]

- [ ] **Token pool gas limit of 90,000**: `balanceOf` + `releaseOrMint` + `balanceOf` on destination must not exceed 90K gas combined. Custom tokens with complex mint/release logic easily exceed this. Look for: custom token pools with gas-intensive operations. [CCIP checklist]

- [ ] **Use mutable `extraArgs`, not hardcoded**: Hardcoded extraArgs prevent adapting to protocol changes. Look for: `Client.EVMExtraArgsV2({gasLimit: 200_000, ...})` as constants. [CCIP checklist]

- [ ] **Validate CCIP inputs before state changes**: If `ccipSend()` is callable by users and state changes occur before the send, wrong inputs can lock funds in the contract. Look for: state mutations before `ccipSend()` without input validation. [CCIP checklist]

- [ ] **Rate limits are per-token AND aggregate per-lane**: Both individual token limits and aggregate USD value limits apply. A large transfer of one token can block transfers of all tokens on a lane. Look for: protocols that assume independent per-token rate limits. [CCIP checklist]

## Wormhole

- [ ] **Always use `messageFee()`, never hardcode**: Wormhole's `publishMessage()` requires the current fee. Hardcoding 0 or any fixed value will fail when fees change. Look for: `publishMessage()` or `transferTokensWithPayload()` without dynamic fee lookup. [Wormhole checklist]

- [ ] **Validate both `isRegisteredSender` AND `msg.sender == wormholeRelayer`**: Missing either check allows spoofed messages. The modifier validates source chain/sender, the msg.sender check validates the delivery mechanism. Look for: `receiveWormholeMessages` without both checks. [Wormhole checklist]

- [ ] **Normalize/denormalize creates stuck dust**: Wormhole token bridge strips precision (normalizes to 8 decimals). If you transfer the raw amount but bridge the normalized amount, the difference stays stuck in your contract. Fix: denormalize first, then only transfer the denormalized amount. Look for: transferFrom(amount) where bridge receives normalize(amount). [Wormhole checklist]

- [ ] **Double normalization/denormalization**: If a value is already normalized, normalizing again causes massive precision loss. Look for: multiple normalize/denormalize calls on the same value through call chains. [Wormhole checklist]

- [ ] **Guardian set transition needs `>=` not `==`**: During transitions, both old and new guardian sets must be valid. Using `==` for set index breaks verification when the new set is active but the old set signed a pending message. Look for: strict equality checks on guardian set index. [Wormhole checklist]

- [ ] **Duplicate guardian signatures bypass quorum**: If signature uniqueness per guardian index isn't enforced, one guardian's signature can be submitted multiple times to meet the 2/3+1 quorum. Look for: signature verification loops without guardian index deduplication. [Wormhole checklist]

## Across Protocol

- [ ] **Relayers can spoof `handleV3AcrossMessage()` parameters**: Across does NOT guarantee message integrity. A malicious relayer won't be repaid, but if the handler unlocks external funds, damage is done. ALL parameters (tokenSent, amount, message) must be independently validated. Look for: `handleV3AcrossMessage` that trusts parameters without validation. [Across checklist]

- [ ] **`handleV3AcrossMessage` must check `msg.sender == acrossSpokePool`**: Without this check, anyone can call with arbitrary data. Look for: missing sender validation in Across message handlers. [Across checklist]

- [ ] **No origin sender in Across messages**: Across doesn't send the origin sender address, making messages inherently spoofable. Include depositor signatures in the message for verification. Look for: message handling that assumes knowledge of origin sender. [Across checklist]

- [ ] **Excessive `outputAmount` locks funds**: If output > input × (1 - fees), no rational relayer fills the order. Funds are locked until expiry (hours). Look for: user-provided outputAmount without bounds validation. [Across checklist]

## Bridge Security Fundamentals

- [ ] **Signed messages must include**: token type, both chain IDs, receiver, amount, nonce, and EIP-712 domain separator. Missing any field enables replay or spoofing. [Spearbit bridge checklist C6.1]

- [ ] **Used signatures must be invalidated**: After execution, the signature/message hash must be marked as used to prevent replay. [Spearbit bridge checklist C6.2]

- [ ] **Chain identifier cannot be spoofed**: Source and destination chain IDs must be in the signed message and verified against actual execution chain. [Spearbit bridge checklist C6.4, C6.5]

- [ ] **Challenge window long enough for human response**: For optimistic bridges, the challenge period must allow incident response (30+ min minimum). Consider per-chain based on weakest chain's finality. [Spearbit bridge checklist]

## Bridge Security Verification (Expanded from Spearbit)

- [ ] **All necessary values must be in signed bridge message**: Token type, chain IDs (source + destination), receiver address, amount, nonce. Missing any field allows replay or spoofing. Look for: bridge message encoding that omits chain ID, nonce, or receiver. [Spearbit Bridge C6.1]

- [ ] **Signature invalidation after use**: Used bridge signatures must be marked as spent. Without this, the same message can be replayed. Look for: bridge relay functions that don't mark message hashes as consumed. [Spearbit Bridge C6.2]

- [ ] **Message hash collision resistance**: If message hashing uses `abi.encodePacked` with variable-length fields, hash collisions are possible. Use `abi.encode` instead. Look for: `keccak256(abi.encodePacked(...))` in bridge message hashing with multiple dynamic types. [Spearbit Bridge C6.3]

- [ ] **Chain identifier spoofing**: If source/destination chain IDs aren't included in the signed message AND verified against expected values, an attacker can spoof cross-chain messages. Look for: bridge relayers that don't verify chain IDs match the expected source/destination. [Spearbit Bridge C6.4, C6.5]

- [ ] **Nonce required for duplicate operations**: Without a nonce, identical operations (same sender, receiver, amount) can't be distinguished, potentially blocking legitimate duplicate transfers. Look for: bridge message schemas without nonce field. [Spearbit Bridge C6.6]

- [ ] **EIP-712 domain separator for bridge messages**: Bridge signed messages should use EIP-712 domain separator to prevent cross-protocol replay. Look for: bridge signatures without domain separator or with incomplete domain parameters. [Spearbit Bridge C6.7]

## Arbitrum Retryable Ticket Pitfalls (from Arbitrum Checklist)

- [ ] **Out-of-order retryable ticket execution**: If multiple retryable tickets are created in one L1 tx, they may execute in different order on L2. If gas price spikes and auto-redemption fails, anyone can manually redeem tickets in any order. Look for: L1 contracts that create multiple retryable tickets with ordering dependencies. [Arbitrum Checklist]

- [ ] **Address aliasing in cross-chain auth**: When L1 contracts send messages to L2, `msg.sender` on L2 is the aliased address (`L1_address + 0x1111000000000000000000000000000000001111`). Auth checks on L2 must use `AddressAliasHelper.applyL1ToL2Alias()`. Look for: L2 contracts checking `msg.sender == L1_counterpart` without aliasing. [Arbitrum Checklist]

- [ ] **Burned nonce from failed auto-redemption**: If a retryable ticket fails auto-redemption (out of gas), the sender's nonce is spent. If the L1 contract predicted a deployment address based on nonce 0, the actual deployment (via manual redemption) will use nonce 1, creating a different address. Look for: L1 contracts that predict L2 contract addresses based on nonce. [Arbitrum Checklist]

- [ ] **`callValueRefundAddress` can cancel tickets**: The `callValueRefundAddress` parameter in `createRetryableTicket` gets permission to cancel the ticket permanently. A malicious actor can set themselves as refund address, intentionally set gas too low, then cancel the ticket before anyone redeems it. Look for: permissionless L1 functions where users control `callValueRefundAddress`. [Arbitrum Checklist]

- [ ] **`unsafeCreateRetryableTicket` doesn't alias refund addresses**: The unsafe version doesn't apply aliasing to `excessFeeRefundAddress` and `callValueRefundAddress`. If these are L1 contract addresses, the L2 contract at the same address may not control the refunded funds. Look for: usage of `unsafeCreateRetryableTicket` with L1 contract addresses as refund recipients. [Arbitrum Checklist]

## Cross-Chain Message Security (from Beirao/Multichain-Auditor)

- [ ] **Unsupported chain whitelisting**: If a protocol accepts cross-chain messages from any chain, an attacker can deploy on an unsupported chain and send malicious messages. All compatible source chains must be whitelisted. Look for: cross-chain receivers without source chain validation. [beirao MC-10]

- [ ] **Bridge contract upgradability differs across chains**: A bridge contract may be immutable on one chain but upgradeable on another. A compromised upgrade on one chain can affect the entire bridge. Look for: cross-chain systems where upgrade authority differs per chain. [multichain-auditor]
