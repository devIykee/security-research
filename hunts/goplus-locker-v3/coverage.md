# Coverage — GoPlus Locker V3

Coverage: 4/4 files (100% of Y). Path-scoped to UniV3LPLocker. Not a full GoPlus product audit.

Last updated: step 5–6 close

| File | Read? | Paths traced | Notes |
|------|-------|--------------|-------|
| contracts/UniV3LPLocker.sol | yes | `lock`/`lockWithCustomFee` → `_lock` → NFT in + lpFee decrease; `unlock`; `relock`; `transferLock`/`acceptLock`; `increaseLiquidity`; `decreaseLiquidity`; `collect`/`_collect`; `adminRefund*`; `_verifySignature` | 568 lines, Sourcify exact |
| contracts/libs/TransferHelper.sol | yes | `safeTransfer`/`safeTransferFrom`/`safeApprove`/`safeTransferETH` | Uniswap-style low-level calls |
| contracts/interface/INonfungiblePositionManager.sol | yes | structs used by lock/collect/increase/decrease | interface only |
| contracts/interface/IUniswapV3Factory.sol | yes | `getPool` used by `_getPool` | interface only |

## Explicitly excluded

| Path / area | Reason |
|-------------|--------|
| src/@openzeppelin/** | vendored OZ 0.8.20 |
| GoPlus Locker V2 TokenLocker 0xF17A…C04b | V2 remnant; live TVL ~$333k. Skimmed increment/vesting only |
| UniV4LPLocker | not in V3 adapter; no BSC TVL |
| test/** | none in Sourcify bundle |
