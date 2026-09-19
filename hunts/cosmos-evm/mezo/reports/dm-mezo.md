Hey Mezo team.

I'm Iyke, a security researcher. (http://x.com/deviykee)

I've found and verified two vulnerabilities in Mezo's on-chain stack, both live right now, so time-sensitive in the sense that they're active on mainnet today:

1. MUSD PriceFeed: a single-oracle 60-second staleness gate with no fallback (PriceFeed.sol MAX_PRICE_DELAY=60). During any oracle outage longer than 60s, every borrow, repay, AND liquidation reverts while troves can go under water - bad debt accrues with no way for borrowers to even closeTrove to de-risk. I verified on mainnet that the priceoracle precompile normally updates per-block, so this is an outage-contingency design risk rather than a routine brick.

2. Tigris Voter: emissions distributed to zero-supply gauges are permanently bricked (Voter._distribute has no totalSupply gate; killGauge sweeps only Voter.claimable, not gauge balances). Any voted-but-empty gauge strands its weekly emission slice forever.

Both reproduced by code-path analysis against deployed mainnet state (block ~11.38M), nothing touched on-chain.

I want to share the full private write-ups with whoever owns the contracts.

Who's the right person, or who do I talk to on the team?
