Hey Primehod.

I'm Iyke, a security researcher. (http://x.com/deviykee)

I reviewed your verified PrimehodFactory on Robinhood Chain (0x57EfC7cE…794f): curve venue + createTokenV3.

I did **not** find a permissionless High. Curve graduation is a milestone only (no DEX migrate / freeze). The V3 path uses hard `createPool` + `initialize` (pre-existing pools fail launch rather than silent wrong-price dumps), with single-sided liquidity into a permanent fee-collect locker.

Happy to share the full private notes. Who's the right person on the team?
