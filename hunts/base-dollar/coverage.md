# Coverage — Base Dollar (BD)

Coverage: 0/40 diff files (0%).

Last updated: Step 3 inventory

Scope = the **diff** between `basedollar/basedollar` and its fork parent
`NeriteOrg/liquity2-template` (itself a Liquity V2 monorepo fork). Files identical
to upstream are out of scope. Denominator Y = 40 (30 modified + 10 new .sol under
`contracts/src`, excluding interfaces-only changes counted as 1 each).

## New files (original BD code — highest priority)

| File | LOC | Read? | Paths traced | Notes |
|------|-----|-------|--------------|-------|
| src/PriceFeeds/AeroLPTokenPriceFeedBase.sol | 520 | no | — | LP pricing core |
| src/AeroManager.sol | 538 | no | — | gauge/fee skim |
| src/Zappers/WrappedTokenZapper.sol | 387 | no | — | |
| src/Dependencies/FixedPointMathLib.sol | 265 | no | — | likely Solady vendor |
| src/PriceFeeds/AeroLPTokenPriceFeed.sol | 154 | no | — | |
| src/PriceFeeds/TokenPriceFeedBase.sol | 132 | no | — | |
| src/PriceFeeds/cbBTCPriceFeed.sol | 80 | no | — | |
| src/PriceFeeds/cbETHPriceFeed.sol | 68 | no | — | |
| src/PriceFeeds/AEROPriceFeed.sol | 52 | no | — | |
| src/ERC20Wrappers/WrappedToken.sol | 47 | no | — | |

## Modified files (diff lines vs upstream)

| File | Diff lines | Read? | Paths traced | Notes |
|------|-----------|-------|--------------|-------|
| src/CollateralRegistry.sol | 340 | no | — | redemption routing |
| src/HintHelpers.sol | 220 | no | — | |
| src/ActivePool.sol | 104 | no | — | gauge staking suspected |
| src/MultiTroveGetter.sol | 70 | no | — | view only |
| src/Dependencies/Constants.sol | 69 | no | — | params |
| src/BoldToken.sol | 52 | no | — | |
| src/RedemptionHelper.sol | 51 | no | — | |
| src/PriceFeeds/WSTETHPriceFeed.sol | 51 | no | — | |
| src/PriceFeeds/RETHPriceFeed.sol | 40 | no | — | |
| src/TroveNFT.sol | 38 | no | — | |
| src/DebtInFrontHelper.sol | 38 | no | — | |
| src/BorrowerOperations.sol | 28 | no | — | |
| src/TroveManager.sol | 26 | no | — | |
| src/CollSurplusPool.sol | 21 | no | — | |
| src/StabilityPool.sol | 16 | no | — | |
| src/AddressesRegistry.sol | 15 | no | — | |
| src/DefaultPool.sol | 11 | no | — | |
| src/PriceFeeds/WETHPriceFeed.sol | 8 | no | — | |
| src/NFTMetadata/MetadataNFT.sol | 8 | no | — | |
| src/PriceFeeds/MainnetPriceFeedBase.sol | 6 | no | — | |
| src/Zappers/WETHZapper.sol | 4 | no | — | |
| src/Zappers/GasCompZapper.sol | 4 | no | — | |
| Interfaces/* (9 files) | ~90 | no | — | declarations only |

## Explicitly excluded

| Path / area | Reason |
|-------------|--------|
| everything byte-identical to `NeriteOrg/liquity2-template` | upstream, audited by Liquity |
| contracts/lib/** | vendored deps (OZ, forge-std, Solady) |
| contracts/test/**, contracts/fuzz/**, contracts/certora/** | tests / formal specs |
| frontend/**, backend/**, subgraph/** | off-chain; no custody |
| contracts/script/**, contracts/deploy/** | deployment scripts (revisit only for param sanity) |
