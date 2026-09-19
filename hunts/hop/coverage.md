# Coverage — Hop Protocol

Coverage: 10/30 files (33%). Opened+traced on value-moving cores. Path-scoped.

Last updated: 2026-08-15 hunt close (PoC + keeper bound)

| File | Read? | Paths traced | Notes |
|------|-------|--------------|-------|
| repo/contracts/bridges/L1_Bridge.sol | yes | sendToL2, bondTransferRoot, confirmTransferRoot, challenge/resolve | full read |
| repo/contracts/bridges/Bridge.sol | yes | withdraw, bondWithdrawal, settle, rescue, transferId | full read |
| repo/contracts/bridges/Accounting.sol | yes | stake/unstake, credit/debit, requirePositiveBalance | full read |
| repo/contracts/bridges/L2_Bridge.sol | yes | send, commit, distribute, bondWithdrawalAndDistribute | full read |
| repo/contracts/bridges/L2_AmmWrapper.sol | yes | swapAndSend, attemptSwap | full read |
| src/cctp/contracts/cctp/HopCCTPImplementation.sol | yes | send -> fee -> depositForBurn | full read |
| src/cctp/contracts/cctp/L1_HopCCTPImplementation.sol | yes | constructor only | thin |
| src/live-eth/contracts/bridges/L1_Bridge.sol | yes | live 3-arg challenge/resolve dest mismatch | Sourcify exact, PoC |
| src/live-eth/contracts/bridges/Accounting.sol | yes | live credit/debit/bonder set | full read |
| repo/contracts/bridges/HopBridgeToken.sol | no | | planned |
| repo/contracts/saddle/Swap.sol | no | | not traced |
| repo/contracts/saddle/SwapUtils.sol | no | | not traced |

## Explicitly excluded

| Path / area | Reason |
|-------------|--------|
| repo/contracts/test/** | mocks |
| repo/contracts/interfaces/** | interfaces only |
| repo/contracts/governance/** | Comp-style governor |
| repo/contracts/polygon/lib/** | vendored Polygon proof libs |
