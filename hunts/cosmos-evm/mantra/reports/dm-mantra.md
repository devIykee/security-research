Hey MANTRA team.

I'm Iyke, a security researcher. (http://x.com/deviykee)

I've found and verified a Medium-severity vulnerability in MANTRA's QuickSwap AlgebraEternalFarming deployment (0x50FC...27bA): setRates() and deactivateIncentive() check only the INCENTIVE_MAKER role and never bind the caller to incentive ownership. Any current incentive maker can point max reward rates at another maker's live incentive (reserve converts to growth within one block and goes to whoever is staked) or deactivate it outright. Severity is bounded by how many makers you have whitelisted - if it's one trusted address, it's latent config risk; if several, it's maker-vs-maker fund redirection.

Also noted (trust/config, lower): SedaPriceStore relayers can push future timestamps, which defeats the 600s staleness guards in downstream Chainlink adapters, and there are no deviation bounds on pushed prices.

Verified from explorer-verified sources + role config on mainnet, nothing touched on-chain.

I want to share the full private write-up with whoever owns the farming deployment.

Who's the right person, or who do I talk to on the team?
