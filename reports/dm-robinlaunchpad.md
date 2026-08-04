Hey RobinLaunchpad.

I'm Iyke, a security researcher. (http://x.com/deviykee)

I did a security pass on your Robinhood Chain contracts, focusing on the verified PumpLaunchpad at 0x299773…281f and the addresses published in docs /api/health.

I did **not** find a permissionless High on the verified bonding-curve path. Graduation stays inside your contract (internal locked AMM), so the Uniswap V3/V4 "pre-init / pool squat" class that has hit other RH pads does not apply there.

A few residual notes if useful: marketplace / tokenLaunchpad / zap are still unverified on Blockscout, and the docs wording about removable LP shares does not match the verified pump (no LP token, no removeLiquidity). Happy to share the full private notes or re-check once those other contracts are verified.

Who's the right person for security mail on the team?
