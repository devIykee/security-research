# Convex Finance hunt notes

Researcher: deviykee
Status: first pass on Ethereum Booster / reward / stash / locker. No permissionless Critical confirmed.

## Live

- TVL ~$486.5M (DefiLlama)
- Booster 0xF403…AE31, codesize 14398, isShutdown false, poolLength 582
- owner BoosterOwner 0x3cE6…f1E6; feeManager/multisig 0xa3C5…2FB
- Fees: lock 1000, staker 450, earmark 50, platform 200 / 10000
- treasury 0x1389…Bb7
- Sample pools live (compound pid0 no stash; stETH pid25 has stash)

## Foundation (short)

- User LP → Booster.deposit → VoterProxy gauge stake → mint DepositToken 1:1 → optional stake in BaseRewardPool
- Withdraw burns DepositToken, unstakes gauge, returns LP
- earmarkRewards permissionless: claim CRV, split fees, queue SNX-style 7-day rewards, mint CVX on CRV claim via rewardClaimed
- ExtraRewardStashV3 wraps extras; CRV extras returned to Booster; rewardHook owner-set
- Owner/poolManager/feeManager: add/shutdown pools, fees, treasury. **Trust, not stranger Critical**
- Reward factory / lockRewards immutable after first set (blocks owner mint redirect)

## 5.5 scoreboard

| Path | Result |
|------|--------|
| Stranger mint DepositToken / CVX | **Killed** — operator only; CVX mint silent-return if not operator |
| withdrawTo from stranger | **Killed** — only crvRewards |
| VoterProxy.execute | **Killed** — operator (Booster) only |
| Stash pull protected LP | **Killed** — protectedTokens + stash withdraw returns 0 |
| Redeem/withdraw more LP than minted | **Killed** — burn then withdraw same amount |
| Donate LP to proxy, next deposit stakes it | **Killed as theft** — extra stuck in gauge, not minted |
| Extra wrapper donation inflates claims | **Killed** — earned from notify, not wrapper balance |
| processStash CRV double-count | **Killed** — CRV sent to booster; claimRewards asserts booster CRV unchanged |
| CrvDepositor incentive extra cvxCRV | **Killed** — conserved with locked CRV |
| Locker kick | **By design** after grace; takes % of expired lock |
| queueNewRewards / first-staker leftover | **Known SNX** — operator-gated notify |
| Malicious gauge via addPool | **Trust** poolManager |

## Step 4

From `0x…dEaD` on live Booster: `setOwner`, `setFees`, `shutdownSystem`, `addPool`, `rewardClaimed`, `withdrawTo` all **guarded**.

`earmarkRewards(uint256)` is **OPEN**. That is the intended permissionless harvest. Caller gets `earmarkIncentive` (50/10000). Not missing admin. **Killed as Critical.**

No Step 7/9.

Wrappers (`ConvexStakingWrapper*`) not traced this pass (later, more reviewed).
