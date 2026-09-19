# Coverage — Stake DAO

Coverage: 6/10 files (60%). Path-scoped Curve locker first pass. Not a full audit.

Last updated: 2026-08-15 first-pass close

| File | Read? | Paths traced | Notes |
|------|-------|--------------|-------|
| packages/lockers/src/DepositorBase.sol | yes | deposit; createLock; shutdown; setSdTokenMinterOperator | |
| packages/lockers/src/integrations/curve/Depositor.sol | yes | _lockToken increase_amount/time | live v4 |
| packages/lockers/src/utils/SafeModule.sol | yes | _executeTransaction fail-closed | |
| packages/lockers/src/SDToken.sol | yes | mint/burn operator | |
| packages/lockers/src/AccumulatorBase.sol | yes | notifyReward; _chargeFee | |
| packages/lockers/src/integrations/curve/Accumulator.sol | yes | claimAndNotifyAll; _notifyReward | |
| packages/lockers/src/AccumulatorDelegable.sol | partial | `_shareWithDelegation` | |
| packages/lockers/src/integrations/curve/VeCRVLocker.sol | no | — | Safe locker |
| packages/strategies/** | no | — | later product |
| packages/vlsdt/** | no | — | |

## Explicitly excluded

| Path / area | Reason |
|-------------|--------|
| script/**, test/** | deploy/tests |
| votemarket, periphery | not this pass |
| other locker integrations | CRV locker is the large pot |
