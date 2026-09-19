# Disposition — SunPump

**Date:** 2026-08-28  
**Target:** SunPump (TRON Meme/Fair-Launch Launchpad)  
**Contracts Reviewed:**
- `LaunchpadProxy` (`TTfvyrAz86hbZk5iDpKD78pqLGgi8C7AAw`)
- `Implementation` (`TKYQmYdssV2UVjr7UmNNt4jti1mmm7ZWnX`)
- `PumpSwapRouter` (`TZFs5ch1R1C4mmjwrrmZqeqbUgGpxY1yWB`)
- `PumpSmartExchangeRouter` (`TSiiYf1b1PV1fpT9T7V4wy11btsNVajw1g`)

## Assessment Summary
1. **Access Control & Upgrades:** Admin setters (`setLauncher`, `setVault`, `setOperator`, `_setPendingImplementation`) are strictly gated by `onlyOwner` or `onlyOperator`. No unauthenticated administrative takeovers.
2. **Bonding Curve AMM Accounting:** Constant product $x \cdot y = k$ virtual reserve curve correctly rounds down in favor of the pool on token mint and sale. Slippage bounds (`AmountMin`) are enforced on both buy and sell paths.
3. **Reentrancy Protection:** All state-changing trade functions (`createAndInitPurchase`, `purchaseToken`, `saleToken`) are protected with explicit reentrancy guards and respect the Checks-Effects-Interactions pattern.
4. **Graduation & Migration:** The `launchToDEX` sequence requires authorization from the trusted `launcher` address. Strangers cannot force graduation with front-run empty pools or sandwich the initial liquidity seeding.
5. **Verdict:** **NO PERMISSIONLESS CRITICAL / HIGH EXPLOIT IDENTIFIED**. Centralization risks (owner/operator upgrade keys, trusted launcher bot) are architectural trust-assumptions.
