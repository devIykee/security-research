# First DM: Robinlaunch (private only)

**Channel:** private DM / security contact for robinlaunch.fun (not a public reply)  
**From:** Iyke (http://x.com/deviykee)

---

Hey Robinlaunch.

I'm Iyke, a security researcher. (http://x.com/deviykee)

I've found and verified a High vulnerability in Robinlaunch's graduation and Direct Pool flow on Robinhood Chain. Anyone can pre-create the Uniswap V3 pool at a fake price so that when a token graduates or lists, the raised ETH for that token can be stolen or left badly mispriced. It is live-exploitable on un-graduated / about-to-list tokens, so it is time-sensitive.

I reproduced the root cause with a local Foundry PoC that mirrors your verified contracts. Nothing was touched on-chain.

I want to share the full private write-up with whoever owns the contracts.

Who's the right person, or who do I talk to on the team?
