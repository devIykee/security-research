Hey Hood Tech.

I'm Iyke, a security researcher. (http://x.com/deviykee)

I reviewed Hood Tech / HoodFUN's live Uniswap V3 factory and positions contracts on Robinhood Chain (verified source). Good news on the scary launchpad class: createLaunch aborts if the pool already exists, so the classic "pre-init pool at a fake price and dump liquidity into it" issue does not apply the way it does on some other RH pads. I did not find a permissionless High against user funds in that path.

One practical issue: the public registry on hood.tech still lists TeleHoodFactory / Positions / Config addresses that currently have no code on chain 4663 (they look like local Hardhat defaults). The live factory fun.hood.tech uses is different. Worth fixing so people do not verify the wrong contracts.

I only used read-only RPC / verified source. Nothing was touched on-chain.

Happy to share the short private notes with whoever owns the contracts if useful.

Who's the right person on the team?
