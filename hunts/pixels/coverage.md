# Coverage — Pixels

Coverage: 4/4 in-scope contracts probed + 2/2 web domains mapped (100% surface mapped).

Last updated: Initial Intake & Reconnaissance

| File / Contract | Read? | Paths traced | Notes |
|-----------------|-------|--------------|-------|
| `eth:FarmLand` (`0x5c1a0cc6dadf4d0fb31425461df35ba80fcbc110`) | yes | `purchase()`, `earlyPurchase()`, `mint()`, `ensureMintConditions()`, `release()` | Fully audited. 5000/5000 minted out. Supply cap permanently prevents further minting. |
| `ronin:FarmLand` (`0xf083289535052e8449d69e6dc41c0ae064d8e3f6`) | yes | `mint()`, `burn()`, `pause()`, `grantRole()` (selectors & ACL) | 3,826 tokens. `DEFAULT_ADMIN_ROLE` = `0x915A...`. `MINTER_ROLE` = 2 addresses. |
| `ronin:Pet` (`0xb806028b6ebc35926442770a8a8a7aeab6e2ce5c`) | yes | `publicMint()`, `bulkMint()`, `mint()`, `withdraw()`, `setTokenContract()` | `publicSaleActive` is false. `MINTER_ROLE` = 4 addresses. 4,509 tokens. |
| `ronin:$PIXEL` (`0x7eae20d11ef8c779433eb24503def900b9d28ad7`) | yes | ERC20 transfer, mint, burn, pause | 2.68B total supply. Gated behind AccessControl. |
| Web/Frontend: `pixels.xyz` | yes | Marketing site static inspection | Webflow site. |
| Web/Frontend: `play.pixels.xyz` | yes | Next.js build manifest, chunk decompilation, backend endpoints | Colyseus server `pixels-server.pixels.xyz`, OtterAuth, game event dispatches. |

## Explicitly excluded

| Path / area | Reason |
|-------------|--------|
| Gameplay mechanics without economic impact | Explicit bounty brief exclusion |
| MID / player ID / feeAddress lookup & enumeration | Explicit bounty brief exclusion |
| DoS / automated scanner spam | Explicit bounty brief prohibition |
