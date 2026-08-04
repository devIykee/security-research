Hey Slops (Robin the Hood).

I'm Iyke, a security researcher. (http://x.com/deviykee)

I've been reviewing Slops' bonding-curve launch + Uniswap v4 migration path on Robinhood Chain. I mapped Factory, per-token curves, FeeDistributor, MigrationManager, and the v4 hook, and confirmed migrate is permissionless once a curve is graduating. Core contracts are currently unverified, so I have not published a High. I do have a residual lead around pool initialization vs hook flags that needs your source (or a completed fork PoC) before I call severity.

I only used fork / eth_call / local analysis. Nothing was touched on-chain.

I want to share the full private notes with whoever owns the contracts, and ideally get verified source for Factory + MigrationManager + Hook so we can close the lead cleanly.

Who's the right person, or who do I talk to on the team?
