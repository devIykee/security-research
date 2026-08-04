Hey HoodCash / mining team.

I'm Iyke, a security researcher. (http://x.com/deviykee)

I've found and verified a Medium vulnerability in HoodCash's MiningPool claim / unstake reward accounting on Robinhood Chain that when the HCASH reward pool is underfunded, a claim permanently burns unpaid accrued rewards even after the pool is refilled. It's relevant for every staker who claims while pool balance is below their pending. Live stake looks near zero and the pool is well prefunded today, so this is not a "drain it this minute" issue, but the accounting bug is real and PoC'd.

I reproduced it with a local Foundry PoC that mirrors the live claim order, nothing was touched on-chain.

I want to share the full private write-up with whoever owns the contracts.

Who's the right person, or who do I talk to on the team?
