# Coverage — SunPump

Coverage: 4/4 contracts (100%).

Last updated: 2026-08-28 (Complete toolkit review)

| File / Contract | Read? | Paths traced | Notes |
|---|---|---|---|
| `LaunchpadProxy` (`TTfvyrAz86hbZk5iDpKD78pqLGgi8C7AAw`) | yes | `createAndInitPurchase`, `purchaseToken`, `saleToken`, `launchToDEX`, admin setters | Full decompiled bytecode + ABI + doc analysis |
| `Launchpad Implementation` (`TKYQmYdssV2UVjr7UmNNt4jti1mmm7ZWnX`) | yes | Virtual AMM math, bonding curve state transitions, reentrancy guards | Full logic path review |
| `PumpSwapRouter` (`TZFs5ch1R1C4mmjwrrmZqeqbUgGpxY1yWB`) | yes | `swapExactETHForTokens`, `swapTokensForExactETH`, `isAllowedTradingPair` | Router integration & pair verification |
| `PumpSmartExchangeRouter` (`TSiiYf1b1PV1fpT9T7V4wy11btsNVajw1g`) | yes | `swapExactInput`, multi-hop routing, SunSwap V3 fee integration | Route validation review |

## Explicitly excluded

| Path / area | Reason |
|---|---|
| SunSwap V2 Core Factory (`TKWJdrQkqHisa1X8HUdHEfREvTzw4pMAaY`) | Standard UniswapV2-derived factory audited in SunSwap core |
