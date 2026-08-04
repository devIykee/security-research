# evm-audit-bridges — NOVEL (Opus 4.6 Does NOT Know)

*Generated: 2026-02-28 | Items: 11*

✅ Verified: Claude Opus 4.6 cannot explain these from training. Highest-signal content.

- [ ] **`lzReceive` OOG from lazy nonce loop**: `_clearPayload` loops from `lazyInboundNonce` to current nonce. If many messages are verified but not received, the loop causes OOG. Fix: process messages with lower nonces first to keep the gap small. Look for: large gaps between `lazyInboundNonce` and current nonce in message processing. [LayerZeroV2 checklist]

- [ ] **`lzCompose` must validate `from` AND `msg.sender`**: In composed messages, `from` must match the expected OFT contract (the one that queued the message via `sendCompose`). `msg.sender` must be EndpointV2. Missing either check allows unauthorized execution with arbitrary composed message data. Look for: `lzCompose` implementations without both validations. [LayerZeroV2 checklist]

- [ ] **Native airdrop cap per chain**: The default LayerZero Executor limits native token airdrops per destination chain (e.g., 1500 MATIC for Polygon). Exceeding this silently fails. Look for: `lzSend` with native airdrop amounts near chain limits. [LayerZeroV2 checklist]

- [ ] **`_toSD` truncates to uint64 silently**: When `localDecimals == sharedDecimals == 18`, the conversion rate is 1, and `_toSD` casts to `uint64`. Any amount > `uint64.max` (~18.4e18) is silently truncated, losing value. Look for: OFT implementations that override `sharedDecimals` to match `localDecimals`. [LayerZeroV2 checklist]

- [ ] **Pausing one direction**: `setPeer` enables bidirectional communication. To disable sending from one direction only, set `maxMessageSize` to 1 byte on the send library config — all sends revert. Look for: protocols that need unidirectional communication. [LayerZeroV2 checklist]

- [ ] **Reverting read functions block all subsequent messages**: If `readCount`, `lzMap`, or `lzReduce` revert, DVNs can't verify that nonce. All messages with higher nonces are blocked until that nonce is resolved (via `EndpointV2::skip`). Look for: any revert possibility in read/compute functions. [LayerZeroV2 checklist]

- [ ] **Out-of-order execution flag is REQUIRED on some lanes**: When `allowOutOfOrderExecution` is Required (not Optional), setting it to `false` causes the message to revert entirely. Look for: CCIP messages to lanes with Required out-of-order execution that hardcode `false`. [CCIP checklist]

- [ ] **8-hour Smart Execution window**: If a message can't execute within 8 hours, ALL subsequent messages on that lane fail until the failing one succeeds (via manual execution). Look for: any scenario where `ccipReceive()` could permanently revert. [CCIP checklist]

- [ ] **No origin sender in Across messages**: Across doesn't send the origin sender address, making messages inherently spoofable. Include depositor signatures in the message for verification. Look for: message handling that assumes knowledge of origin sender. [Across checklist]

- [ ] **Burned nonce from failed auto-redemption**: If a retryable ticket fails auto-redemption (out of gas), the sender's nonce is spent. If the L1 contract predicted a deployment address based on nonce 0, the actual deployment (via manual redemption) will use nonce 1, creating a different address. Look for: L1 contracts that predict L2 contract addresses based on nonce. [Arbitrum Checklist]

- [ ] **`callValueRefundAddress` can cancel tickets**: The `callValueRefundAddress` parameter in `createRetryableTicket` gets permission to cancel the ticket permanently. A malicious actor can set themselves as refund address, intentionally set gas too low, then cancel the ticket before anyone redeems it. Look for: permissionless L1 functions where users control `callValueRefundAddress`. [Arbitrum Checklist]

