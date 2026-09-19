> For the complete documentation index, see [llms.txt](https://docs.tropicalwater.xyz/llms.txt). Markdown versions of documentation pages are available by appending `.md` to page URLs; this page is available as [Markdown](https://docs.tropicalwater.xyz/architecture/function-reference.md).

# Function Reference

### User Functions

| Function                    | Signature                                                             | Returns                                                                      | Description                                                                                  |
| --------------------------- | --------------------------------------------------------------------- | ---------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------- |
| `deposit`                   | `deposit(uint256 assets, address receiver)`                           | `uint256 shares`                                                             | Transfer USDC to vault, receive shares. Requires prior `approve`.                            |
| `requestRedemption`         | `requestRedemption(uint256 shares)`                                   | —                                                                            | Lock shares for fee-free redemption. Yield frozen at call time. One active request per user. |
| `cancelRedemption`          | `cancelRedemption()`                                                  | —                                                                            | Cancel active request, return shares to caller.                                              |
| `completeRedemption`        | `completeRedemption(address receiver)`                                | `uint256 assets`                                                             | Complete request after lockup. Payout = value at request time.                               |
| `redeemEarly`               | `redeemEarly(uint256 shares, address receiver, uint256 minAssetsOut)` | `uint256 assets`                                                             | Instant redemption with fee. `minAssetsOut = 0` disables slippage guard.                     |
| `previewRedeemEarly`        | `previewRedeemEarly(uint256 shares)`                                  | `(uint256 assets, uint256 fee)`                                              | Preview early redemption output.                                                             |
| `previewCompleteRedemption` | `previewCompleteRedemption(address user)`                             | `uint256 assets`                                                             | Preview payout for pending request. Returns 0 if no active request.                          |
| `getRedemptionRequest`      | `getRedemptionRequest(address user)`                                  | `(uint256 shares, uint256 requestTime, uint256 unlockTime, bool isUnlocked)` | Full details of a user's pending request.                                                    |

### Admin Functions

| Function                | Signature                                                        | `payable` | Description                                                                       |
| ----------------------- | ---------------------------------------------------------------- | :-------: | --------------------------------------------------------------------------------- |
| `setRate`               | `setRate(uint256 newRate)`                                       |     ✅     | Set yield rate. Broadcasts to all peers if source chain.                          |
| `setLockupPeriod`       | `setLockupPeriod(uint256 newPeriod)`                             |     ✅     | Set lockup duration. Only affects future requests.                                |
| `setEarlyRedemptionFee` | `setEarlyRedemptionFee(uint256 newFeeBps)`                       |     ✅     | Set early redemption fee in basis points (500 = 5%).                              |
| `setCap`                | `setCap(uint256 newCap)`                                         |     ✅     | Set deposit cap. `0` = unlimited.                                                 |
| `addPeerEndpoint`       | `addPeerEndpoint(uint32 eid)`                                    |     ❌     | Register a chain EID for state sync broadcast and reception.                      |
| `removePeerEndpoint`    | `removePeerEndpoint(uint32 eid)`                                 |     ❌     | Deregister a chain EID.                                                           |
| `getPeerEndpoints`      | `getPeerEndpoints()`                                             |     ❌     | Return all registered peer EIDs.                                                  |
| `adminWithdraw`         | `adminWithdraw(address token, uint256 amount, address receiver)` |     ❌     | Emergency withdrawal. Transfers any token (including USDC) or ETH. **No limits.** |

### ERC-4626 View Functions

| Function                          | Returns          | Notes                                                                                             |
| --------------------------------- | ---------------- | ------------------------------------------------------------------------------------------------- |
| `asset()`                         | `address`        | Returns `ASSET` (USDC).                                                                           |
| `totalAssets()`                   | `uint256`        | Virtual: `totalSupply × cumulativeRateFactor / RAY / decimalOffset`. Not the actual USDC balance. |
| `convertToAssets(uint256 shares)` | `uint256`        | Shares → USDC at current rate factor.                                                             |
| `convertToShares(uint256 assets)` | `uint256`        | USDC → shares at current rate factor.                                                             |
| `previewDeposit(uint256 assets)`  | `uint256 shares` | Shares received for `assets`.                                                                     |
| `previewRedeem(uint256 shares)`   | `uint256 assets` | Assets received for `shares` via queue path.                                                      |
| `previewMint(uint256 shares)`     | `uint256 assets` | Assets needed to mint exact `shares`.                                                             |
| `maxDeposit(address)`             | `uint256`        | `type(uint256).max` if uncapped; `cap - totalAssets()` otherwise.                                 |
| `maxMint(address)`                | `uint256`        | `type(uint256).max` if uncapped; shares equivalent of `maxDeposit`.                               |
| `maxWithdraw(address)`            | `uint256`        | **Always returns 0** — use redemption request system.                                             |
| `maxRedeem(address)`              | `uint256`        | **Always returns 0** — use redemption request system.                                             |
| `apy()`                           | `uint256`        | Current APY as `_compoundFactor(currentRate, 365 days)` in RAY.                                   |

### State Variables (Public)

| Variable               | Type                                                     | Description                                                              |
| ---------------------- | -------------------------------------------------------- | ------------------------------------------------------------------------ |
| `ASSET`                | `address immutable`                                      | Underlying ERC-20 token (USDC).                                          |
| `IS_SOURCE_CHAIN`      | `bool immutable`                                         | Chain role. Set at construction. Cannot change.                          |
| `currentRate`          | `uint256`                                                | Active per-second yield rate in RAY units.                               |
| `cumulativeRateFactor` | `uint256`                                                | Running yield growth product. Starts at `RAY`. Monotonically increasing. |
| `lockupPeriod`         | `uint256`                                                | Duration of queue-based lockup in seconds.                               |
| `earlyRedemptionFee`   | `uint256`                                                | Early redemption fee in basis points.                                    |
| `cap`                  | `uint256`                                                | Deposit cap in USDC (`0` = unlimited).                                   |
| `redemptionRequests`   | `mapping(address => RedemptionRequest)`                  | Per-user pending redemption data.                                        |
| `configuredPeers`      | `mapping(uint32 => bool)`                                | EIDs registered for state sync.                                          |
| `peerEndpoints`        | `uint32[]`                                               | Ordered list of registered peer EIDs.                                    |
| `lastBroadcastNonce`   | `mapping(StateUpdateType => uint256)`                    | Per-parameter nonce for outbound syncs (source chain).                   |
| `lastSyncNonce`        | `mapping(uint32 => mapping(StateUpdateType => uint256))` | Per-source, per-parameter replay protection (destination chain).         |
