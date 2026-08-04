Hey SLVR.

I'm Iyke, a security researcher. (http://x.com/deviykee)

I've reviewed the live slvr.fun stack on Robinhood Chain read-only (lottery + Drand RNG, ve staking ~34 ETH rewards, AutoCommit V1/V2 ~0.85 ETH plans, MultiClaim, ClaimLocker, LP staking/zap, hub, jackpot). Nothing was touched on-chain.

Main finding: Medium trust issue in SlvrGridLottery.claimAdvanced. An approved claim delegate can set arbitrary recipientNative / recipientSlvr (and ethOnly recipient) and redirect a user's claim proceeds. Not a permissionless stranger drain without prior approveDelegate. Your MultiClaim contract documents the same risk (why Multicall3 is unsafe as a lottery delegate). AutoCommit and ClaimLocker hardcode safe recipients, but the core API still allows full redirect for any approved delegate.

Also noted (lower / by design): AutoCommitV2 keepers can force-execute enabled plans and charge a capped fee (max 0.003 ETH + 10% premium). No free open-admin Critical found on this pass.

I want to share the full private write-up with whoever owns the contracts.

Who's the right person, or who do I talk to on the team?
