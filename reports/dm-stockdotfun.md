Hey StockDotFun.

I'm Iyke, a security researcher. (http://x.com/deviykee)

I've found and verified a High vulnerability in StockDotFun's Uniswap V4 graduation flow on Robinhood Chain that lets a stranger permanently freeze a token's full curve raise after the graduation target is hit. Buyers can no longer sell, and migration keeps failing. It's live-exploitable right now on every un-graduated launch whose V4 pool key can be pre-initialized (gas only), so it's time-sensitive.

I reproduced the control flow against your verified V2 source with a local Foundry PoC, nothing was touched on-chain.

I want to share the full private write-up with whoever owns the contracts (factory 0x470aca74…569e / GraduationManager 0x408fA5…D835).

Who's the right person, or who do I talk to on the team?
