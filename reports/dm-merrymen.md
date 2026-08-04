Hey Merry Men / PumpClaw.

I'm Iyke, a security researcher. (http://x.com/deviykee)

I've found and verified a High vulnerability in Merry Men's PumpClawFactory createToken flow on Robinhood Chain that lets a stranger permanently freeze all future token launches with gas only (pre-init the next CREATE token's Uniswap v4 pool so createToken always reverts). It's live-exploitable right now on factory 0xfa4B952c15BC9d418ae4f552F7Fc76b4470596fE, so it's time-sensitive.

I reproduced it on a Robinhood Chain mainnet fork / local Foundry PoC, nothing was touched on-chain, with working PoCs (baseline create succeeds; after pre-init create reverts forever).

I want to share the full private write-up with whoever owns the contracts.

Who's the right person, or who do I talk to on the team?
