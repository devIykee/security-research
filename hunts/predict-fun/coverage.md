# Coverage — Predict Fun

Coverage: 4/6 custom files read (67%). Yield-bearing stack only; legacy stack excluded.

Last updated: 2026-08-23 Step 5/6

| File | Read? | Paths traced | Notes |
|------|-------|--------------|-------|
| YieldBearingWrappedCollateral.sol | yes | wrap / unwrap / _release / mint / burn / release | full read (171 L) |
| Venus.sol | yes | _mintVToken, _redeemUnderlying, _claimYield, _enableUnderlying, _disableUnderlying, splitPrincipalAndYield | full read of logic (419 L); exp-math helpers skimmed |
| YieldBearingConditionalTokens.sol | partial | splitPosition -> _mintVToken; mergePositions -> _redeemUnderlying; redeemPositions -> _redeemUnderlying | value paths traced; prepareCondition/reportPayouts not traced |
| IVToken.sol / IComptroller.sol | yes | interface only | trivial |
| CTHelpers.sol | no | — | stock Gnosis position-id math |
| WhitelistedERC1155.sol | no | — | transfer whitelist, not yet traced |
| YieldBearingNegRiskAdapter.sol | no | — | not fetched yet |

## Explicitly excluded

| Path / area | Reason |
|-------------|--------|
| node_modules/** | vendored OZ + solmate |
| Legacy non-yield stack (ConditionalTokens 0x22DA..., WrappedCollateral 0x6623...) | stock Polymarket fork, no Venus layer; ~101k USDT only |
| Blast deployment | $36k dust |
