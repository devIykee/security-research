# Coverage — Synapse Protocol

Coverage: 5/225 files (2%). Path-scoped to bridge + FastBridge + CCTP. Not a full audit.

Last updated: 2026-08-15 after bridge/RFQ/CCTP pass

| File | Read? | Paths traced | Notes |
|------|-------|--------------|-------|
| repo/contracts/bridge/SynapseBridge.sol | yes | deposit/redeem, mint/withdraw, mintAndSwap, withdrawAndRemove, redeemV2 | full read |
| src/fastbridge/contracts/FastBridge.sol | yes | bridge/relay/prove/claim/dispute/refund | full read (live Sourcify) |
| src/fastbridge/contracts/Admin.sol | yes | roles, fee rate, sweep | full read |
| src/fastbridge/contracts/libs/UniversalToken.sol | yes | ETH/ERC20 transfer | full read |
| repo/contracts/cctp/SynapseCCTP.sol | yes | sendCircleToken, receiveCircleToken, forwarder mint, fulfill/swap fallback | full read |

## Explicitly excluded

| Path / area | Reason |
|-------------|--------|
| repo/contracts/**/mocks/** | mocks |
| repo/contracts/**/testing/** | tests |
| repo/contracts/amm/** | Saddle fork; not traced this pass |
| repo/contracts/amm08/** | older AMM |
| repo/lib/** | vendored |
