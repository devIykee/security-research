Hey MetaLaunch.

I'm Iyke, a security researcher. (http://x.com/deviykee)

I did a security pass on your Robinhood Chain launchpad stack, focusing on MetaLaunchFactoryV12 (0x1B2A2ee9…4660A) and the legacy V5 pad / MetaLocker addresses from your site.

I did **not** find a permissionless High on the current V12 path. The post-init `TickMisaligned` check (pool tick must equal the intended opening tick) plus salt-side `getPool == 0` correctly blocks the Uniswap V3 "pre-init / pool squat" class that has hit other RH pads that dump a held raise.

Full private notes available if useful (legacy V5 residual first-buy minOut=0 / no tick equality). Who's the right person for security mail?
