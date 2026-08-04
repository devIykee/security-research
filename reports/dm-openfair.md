# First DM: Openfair (private only)

**Channel:** private DM to @OpenFairApp / security contact (not a public reply)  
**From:** Iyke (http://x.com/deviykee)

---

Hey Openfair.

I'm Iyke, a security researcher. (http://x.com/deviykee)

I've found and verified a High vulnerability in Openfair's graduation and Uniswap seed flow on Robinhood Chain (LaunchFactory / OpenLaunch). Anyone can pre-create the Uniswap V3 pool at a fake price so that when a fair launch graduates or an instant list seeds liquidity, the raised ETH for that token can be stolen or left badly mispriced. It is live-exploitable on un-graduated / about-to-list tokens, so it is time-sensitive.

I reproduced the root cause against your verified contracts with a local Foundry PoC. Nothing was touched on-chain.

I want to share the full private write-up with whoever owns the contracts.

Who's the right person, or who do I talk to on the team?
