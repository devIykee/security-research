# First DM: Robinfun (private only)

**Channel:** private DM to @robinfunxyz / security contact (not a public reply)  
**From:** Iyke (http://x.com/deviykee)

---

Hey Robinfun.

I'm Iyke, a security researcher. (http://x.com/deviykee)

I've found and verified a High vulnerability in Robinfun's graduation flow on Robinhood Chain. After a token hits the raise, trading freezes and only graduate can finish. Anyone can pre-seed a tiny Uniswap V2 pair so normal graduate reverts as polluted, trapping buyers' ETH until an owner-only recovery that sends the raise to the treasury. It is live-relevant for un-graduated tokens, so it is time-sensitive.

I reproduced the gate math with a local Foundry PoC against your verified Factory V2 source. Nothing was touched on-chain. Factory V5 is listed as current and holds live ETH; full V5 source was not verified when I checked.

I want to share the full private write-up with whoever owns the contracts.

Who's the right person, or who do I talk to on the team?
