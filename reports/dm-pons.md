Hey Pons.

I'm Iyke, a security researcher. (http://x.com/deviykee)

I reviewed your verified PonsLaunchFactory on Robinhood Chain (0xA5aAb3F0…1feB). Site DNS did not resolve from my side, so this is on-chain only.

I did **not** find a permissionless High. Checking `getPool(predictedToken, …) == 0` before deploy correctly blocks the Uniswap V3 pre-init / pool-squat class that has hit other RH pads, and launches are single-sided (no held bonding raise).

Happy to share the full private notes (including the optional first-buy minOut=0 residual). Who's the right person on the team?
