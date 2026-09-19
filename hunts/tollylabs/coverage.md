# Coverage — Tolly Labs

Coverage: 3/10 files (30%).

Last updated: Step 3 - surface map

| File | Read? | Paths traced | Notes |
|------|-------|--------------|-------|
| contracts/launchpad/TollyPad.sol | yes | createToken → _mintSingleSided → _devBuy, updateMeta, setBanned | Core launchpad factory - full read |
| contracts/launchpad/TollyToken.sol | yes | _update (anti-snipe), setPool | Launch token template - full read |
| contracts/launchpad/TollyFeeLocker.sol | yes | collect → _distribute (5-way split), claim, setPayout | Fee distribution/lock - full read |
| contracts/launchpad/TollyHolderVault.sol | no | — | Holder vault logic |
| contracts/launchpad/TollyTreasury.sol | no | — | Treasury management |
| contracts/TollySwapRouter.sol | no | — | Swap routing |
| contracts/TollyMultiRouter.sol | no | — | Multi-hop routing |
| contracts/TollyForge.sol | no | — | Forge/factory logic |
| contracts/TollyLens.sol | no | — | View/query helper |
| contracts/launchpad/libraries/TickMath.sol | no | — | Math library |

## Explicitly excluded

| Path / area | Reason |
|-------------|--------|
| node_modules/** | vendored dependencies |
| test/** | test files (not in scope for mainnet hunt) |
| scripts/** | deployment scripts |
