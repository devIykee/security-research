# Coverage — Convex Finance

Coverage: 10/14 files (71%). Path-scoped first pass on core booster money path. Not a full audit.

Last updated: 2026-08-15 first-pass close

| File | Read? | Paths traced | Notes |
|------|-------|--------------|-------|
| contracts/Booster.sol | yes | deposit/withdraw/withdrawTo; earmarkRewards; rewardClaimed; add/shutdown; setters | live 582 pools |
| contracts/BaseRewardPool.sol | yes | stake/stakeFor/withdraw/withdrawAndUnwrap; getReward; queueNewRewards | SNX 7-day |
| contracts/VoterProxy.sol | yes | deposit full balance; withdraw; execute; claimCrv; stash withdraw protect | |
| contracts/ExtraRewardStashV3.sol | yes | claimRewards; processStash; setToken/wrapper; crvChange assert | |
| contracts/StashTokenWrapper.sol | yes | balanceOf rewardPool; transfer only from pool | |
| contracts/CrvDepositor.sol | yes | deposit lock/defer; lockCurve incentive | |
| contracts/DepositToken.sol | yes | mint/burn operator | |
| contracts/Cvx.sol | yes | mint operator + cliffs | |
| contracts/VirtualBalanceRewardPool.sol | yes | virtual stake from main pool; queue/getReward | |
| contracts/CvxLockerV2.sol | yes | lock; process/kick expired; notifyReward | owner kick params |
| contracts/wrappers/ConvexStakingWrapper.sol | partial | skim deposit/withdraw names | not traced |
| contracts/BoosterOwner.sol | no | — | owner proxy, trust |
| contracts/RewardFactory.sol | no | — | |
| contracts/cvxRewardPool.sol | no | — | CVX staking pool |

## Explicitly excluded

| Path / area | Reason |
|-------------|--------|
| contracts/test/**, FakeGauge, Debug* | tests |
| contracts/interfaces/** | ABI |
| Frax/Prisma/FX side boosters | other products; lower rank this pass |
| MasterChef / airdrop / treasury swap | not core LP pot |
