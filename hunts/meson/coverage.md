# Coverage — Meson Finance

Coverage: 5/16 files (31%). Path-scoped.

Last updated: 2026-08-15 after HTLC pass

| File | Read? | Paths traced | Notes |
|------|-------|--------------|-------|
| repo/contracts/Swap/MesonSwap.sol | yes | post/bond/cancel/execute/direct/simple | full read |
| repo/contracts/Pools/MesonPools.sol | yes | deposit/lock/unlock/release/directRelease | full read |
| repo/contracts/utils/MesonHelpers.sol | yes | packing, fees, share/core, signatures | full read |
| repo/contracts/utils/MesonStates.sol | yes | deposit/transfer/amountFactor | full read |
| repo/contracts/Meson.sol | partial | inheritance surface | skim |
| repo/contracts/MesonManager.sol | no | | planned |
| repo/contracts/utils/MesonTokens.sol | no | token index table | planned |

## Explicitly excluded

| Path / area | Reason |
|-------------|--------|
| repo/contracts/test/** | mocks |
| repo/packages/** | JS SDK (addresses only) |
