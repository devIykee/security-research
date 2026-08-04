Hey HoodRich / RobinPump.

I'm Iyke, a security researcher. (http://x.com/deviykee)

I've found and verified a High vulnerability in the RobinPump curve factory on Robinhood Chain (0x3c31119d…540d from your /api/config). When a token graduates, the factory seeds Uniswap V2 liquidity with amountTokenMin and amountETHMin both set to zero. A stranger can pre-skew that pair so the full curve raise is deposited at a hostile ratio. Curve sells are already blocked after graduation, so buyers of that launch are exposed. It's live-exploitable on every un-finalized graduating token while the router is set.

I reviewed the verified on-chain source; nothing was touched on mainnet.

I want to share the full private write-up with whoever owns the contracts.

Who's the right person, or who do I talk to on the team?
