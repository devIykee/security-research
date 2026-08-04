# evm-audit-bridges — PARTIAL (Opus Knows Concept, Not Specifics)

*Generated: 2026-02-28 | Items: 18*

⚠️  Opus knows the general class but not the specific protocol/version/formula detail.

- [ ] **Gas limit and msg.value from options are NOT enforced on-chain**: The options metadata is an off-chain agreement with the Executor. ANYONE can call `lzReceive` with different gas/value than specified in options. Look for: receiving contracts that assume msg.value or gas matches what was specified on sending side. Fix: encode expected values in the message payload and check on receive. [LayerZeroV2 checklist]

- [ ] **Un-ordered execution is the DEFAULT**: If nonce 4 fails, nonces 5 and 6 still execute. If you need ordered execution, implement `nextNonce()` AND ensure no reverting transactions (they permanently block all subsequent nonces). Look for: state-dependent cross-chain operations that assume ordering. [LayerZeroV2 checklist]

- [ ] **Dust removal strips 12 digits by default**: Default OFT uses 6 shared decimals. Sending `1.234567890123456789` tokens results in receiving `1.234567000000000000`. The 12 least significant digits are stripped. Dust isn't lost — it's cleaned from the input amount. Look for: custom fee logic that should call `_removeDust` after fee deduction, not before. [LayerZeroV2 checklist]

- [ ] **Default libraries controlled by LayerZero team**: If your OApp doesn't explicitly configure send/receive libraries, it uses system defaults. LayerZero can change defaults at any time, potentially bricking your protocol. ALWAYS explicitly set your library configuration. Look for: OApp deployments without `setSendLibrary`/`setReceiveLibrary` calls. [LayerZeroV2 checklist]

- [ ] **`allowInitializePath` must be implemented for non-default receivers**: Without this, the first DVN verification fails silently. Default OApp checks if sender is a trusted peer. Custom receivers must implement their own logic. Look for: custom OApp receivers without `allowInitializePath`. [LayerZeroV2 checklist]

- [ ] **Default gas limit is 200,000**: If `gasLimit` isn't specified in `extraArgs`, CCIP uses 200K gas. Complex `ccipReceive()` implementations easily exceed this and silently fail. Unspent gas is NOT refunded. Look for: CCIP messages without explicit gas limit in extraArgs. [CCIP checklist]

- [ ] **Token pool gas limit of 90,000**: `balanceOf` + `releaseOrMint` + `balanceOf` on destination must not exceed 90K gas combined. Custom tokens with complex mint/release logic easily exceed this. Look for: custom token pools with gas-intensive operations. [CCIP checklist]

- [ ] **Use mutable `extraArgs`, not hardcoded**: Hardcoded extraArgs prevent adapting to protocol changes. Look for: `Client.EVMExtraArgsV2({gasLimit: 200_000, ...})` as constants. [CCIP checklist]

- [ ] **Validate CCIP inputs before state changes**: If `ccipSend()` is callable by users and state changes occur before the send, wrong inputs can lock funds in the contract. Look for: state mutations before `ccipSend()` without input validation. [CCIP checklist]

- [ ] **Rate limits are per-token AND aggregate per-lane**: Both individual token limits and aggregate USD value limits apply. A large transfer of one token can block transfers of all tokens on a lane. Look for: protocols that assume independent per-token rate limits. [CCIP checklist]

- [ ] **Always use `messageFee()`, never hardcode**: Wormhole's `publishMessage()` requires the current fee. Hardcoding 0 or any fixed value will fail when fees change. Look for: `publishMessage()` or `transferTokensWithPayload()` without dynamic fee lookup. [Wormhole checklist]

- [ ] **Validate both `isRegisteredSender` AND `msg.sender == wormholeRelayer`**: Missing either check allows spoofed messages. The modifier validates source chain/sender, the msg.sender check validates the delivery mechanism. Look for: `receiveWormholeMessages` without both checks. [Wormhole checklist]

- [ ] **Normalize/denormalize creates stuck dust**: Wormhole token bridge strips precision (normalizes to 8 decimals). If you transfer the raw amount but bridge the normalized amount, the difference stays stuck in your contract. Fix: denormalize first, then only transfer the denormalized amount. Look for: transferFrom(amount) where bridge receives normalize(amount). [Wormhole checklist]

- [ ] **Guardian set transition needs `>=` not `==`**: During transitions, both old and new guardian sets must be valid. Using `==` for set index breaks verification when the new set is active but the old set signed a pending message. Look for: strict equality checks on guardian set index. [Wormhole checklist]

- [ ] **Relayers can spoof `handleV3AcrossMessage()` parameters**: Across does NOT guarantee message integrity. A malicious relayer won't be repaid, but if the handler unlocks external funds, damage is done. ALL parameters (tokenSent, amount, message) must be independently validated. Look for: `handleV3AcrossMessage` that trusts parameters without validation. [Across checklist]

- [ ] **Excessive `outputAmount` locks funds**: If output > input × (1 - fees), no rational relayer fills the order. Funds are locked until expiry (hours). Look for: user-provided outputAmount without bounds validation. [Across checklist]

- [ ] **Out-of-order retryable ticket execution**: If multiple retryable tickets are created in one L1 tx, they may execute in different order on L2. If gas price spikes and auto-redemption fails, anyone can manually redeem tickets in any order. Look for: L1 contracts that create multiple retryable tickets with ordering dependencies. [Arbitrum Checklist]

- [ ] **`unsafeCreateRetryableTicket` doesn't alias refund addresses**: The unsafe version doesn't apply aliasing to `excessFeeRefundAddress` and `callValueRefundAddress`. If these are L1 contract addresses, the L2 contract at the same address may not control the refunded funds. Look for: usage of `unsafeCreateRetryableTicket` with L1 contract addresses as refund recipients. [Arbitrum Checklist]

