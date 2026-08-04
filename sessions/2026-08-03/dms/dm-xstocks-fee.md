Hey xStocks / CDP team.

I'm Iyke, a security researcher. (http://x.com/deviykee)

I've found and verified a Medium (latent) vulnerability in CdpEngine mint fee accounting on Robinhood Chain: if borrowFeeBps is ever set above zero, fee debt is never backed by minted stable and can become unpayable. Scope is all CdpEngine deployments that share this mint path. Live engines I checked still have borrowFeeBps = 0, so this is a footgun before you turn fees on, not an active drain.

I verified it from verified source plus read-only param checks. Nothing was touched on-chain.

I want to share the full private write-up with whoever owns the contracts (can bundle with the oracle note if same team).

Who's the right person, or who do I talk to on the team?
