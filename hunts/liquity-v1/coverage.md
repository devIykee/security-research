# Coverage — Liquity V1

Coverage: 14/16 files (88%). Path-scoped first pass on core money contracts. Not a full audit.

Last updated: 2026-08-15 first-pass close (steps 1–6)

| File | Read? | Paths traced | Notes |
|------|-------|--------------|-------|
| contracts/TroveManager.sol | yes | `liquidate` → batch/sequence → `_liquidateNormalMode` / `_liquidateRecoveryMode` → offset/redistribute/surplus/gas; `redeemCollateral` → `_redeemCollateralFromTrove` / `_redeemCloseTrove`; `_applyPendingRewards`; `_redistributeDebtAndColl`; `_computeNewStake`; fee/baseRate | 1562 lines; live bytecode may omit repo `getMaxAmountToOffset` call |
| contracts/BorrowerOperations.sol | yes | `openTrove`; `_adjustTrove`; `closeTrove`; `claimCollateral`; recovery-mode ICR/TCR gates; mint/repay | ownership renounced in `setAddresses` |
| contracts/StabilityPool.sol | yes | `provideToSP`; `withdrawFromSP`; `offset`; P/S/G/`_getCompoundedStakeFromSnapshots`; ETH/LUSD send | **live ≠ repo**: no `getMaxAmountToOffset` / `MIN_LUSD_IN_SP` on chain |
| contracts/ActivePool.sol | yes | `sendETH`; receive; debt inc/dec | tracker == live balance |
| contracts/DefaultPool.sol | yes | `sendETHToActivePool`; receive; debt | live empty |
| contracts/CollSurplusPool.sol | yes | `accountSurplus`; `claimColl`; receive | 1616 ETH unclaimed; tracker == balance |
| contracts/LUSDToken.sol | yes | mint/burn/sendToPool/returnFromPool; transfer recipient lock | mint BO-only |
| contracts/PriceFeed.sol | yes | `fetchPrice` status machine; broken/frozen/Tellor fallback; lastGoodPrice | status 0 live |
| contracts/Dependencies/LiquityBase.sol | yes | MCR/CCR/gas/min debt; TCR; entire system coll/debt | |
| contracts/Dependencies/LiquityMath.sol | yes | `_computeCR` / NICR / `_decPow` | |
| contracts/LQTY/LQTYStaking.sol | yes | stake/unstake; `increaseF_ETH` / `increaseF_LUSD`; pending gains | zero-stake fee stick killed as theft |
| contracts/LQTY/CommunityIssuance.sol | yes | `issueLQTY`; `sendLQTY` | issuance curve; SP-only |
| contracts/SortedTroves.sol | partial | `insert` auth + hint fallback; list invariants from comments | not every `_findInsertPosition` branch |
| contracts/GasPool.sol | yes | empty holder | comment says 50 LUSD; live reserve is 200 |
| contracts/Dependencies/TellorCaller.sol | yes | `getTellorCurrentValue` | fallback only |
| contracts/LQTY/LQTYToken.sol | no | — | planned if issuance/lockup path reopened |

## Explicitly excluded

| Path / area | Reason |
|-------------|--------|
| contracts/TestContracts/** | fixtures |
| contracts/Interfaces/** | ABI only |
| contracts/Proxy/** | frontend scripts, no custody |
| contracts/LPRewards/** | Unipool / LP mining, not core CDP pot |
| contracts/LQTY/LockupContract*.sol | investor vesting |
| contracts/Integrations/** | price adapter helper |
| contracts/Dependencies/{IERC*,Ownable,SafeMath,CheckContract,console,Aggregator*} | std / interfaces |
| packages/dev-frontend/**, lib-*, subgraph, fuzzer | not custody |
| Liquity V2 / V3 | different deploys |
