# Coverage — sheriff.money

Coverage: 29/33 unique custom impl files opened with a traced path (88%).
Opened: 29. Traced: 29. Planned-not-yet: 4.
Duplicate factory copies of plugin sources are not double-counted.

Last updated: 2026-08-12 after burn-DoS PoC + leftover/vault probes

Denominator Y = unique Sheriff-custom production implementations (not interface-only, not OZ/Algebra/Uni vendor, not the duplicate `SheriffBasePluginFactory/contracts/{plugins,base,libraries}` copies of the plugin tree).

| File | Read? | Paths traced | Notes |
|------|-------|--------------|-------|
| src/v2/contracts/SheriffFactory.sol | yes | `createPair` CREATE2; `setFeeTo`/`setFeeToSetter`/`setOwnerFeeShare` auth | Camelot-style fee share. 2 live pairs. |
| src/v2/contracts/SheriffPair.sol | yes | `swap` K+fee; `mint`/`burn`; `_mintFee`; `setFee`; `skim`/`sync`; `recoverWrongToken` | Per-pair fee 500/1e5. `initialize` factory-only, not one-shot (factory cannot re-call). |
| src/v2/contracts/SheriffRouter.sol | yes | add/remove LP; `_swap`; FoT `_swapSupportingFeeOnTransferTokens` | Uses pair fee via library. |
| src/v2/contracts/libraries/UniswapV2Library.sol | yes | `pairFor` initcode; `getReserves`/`getAmountOut`/`getAmountsOut` fee wiring | Fee not hardcoded 0.3%. |
| src/v2/contracts/UniswapV2ERC20.sol | yes | permit + DOMAIN_SEPARATOR (chainid at deploy) | stock UniV2 permit |
| src/token/src/SheriffToken.sol | yes | ctor mint; `_update` 30-min EOA 2% cap | Guard expired on-chain (`launchGuardActive=false`). |
| src/CampaignFactory/contracts/CampaignFactory.sol | yes | `initialize`; `create` pull+fee; `cancel` (no refund); `recoverERC20` | Live proxy `0xa1A9…`: owner=deployer, distributor=`0x011b…`, nextId=50, fee=100 BPS. Impl `0xE1eA…` still uninitialized (`_disableInitializers` missing). |
| src/CampaignFactory/contracts/ICampaignFactory.sol | partial | errors/events vs impl | Spec says week; impl uses days. |
| src/Distributor1.sol | yes | `harvest`/`multiHarvest` merkle; `updateRoot`; native push; `recoverERC20` | Same pattern as live `0x011b…`. Shared pot, updater-trusted root. Push-ETH DoS if `token==wNative`. |
| src/SecurityRegistry.sol | yes | `setPoolsStatus`/`setGlobalStatus`/`getPoolStatus`/`_hasAccess` | Guard vs owner split. Live `getPoolStatus(random)=0` ENABLED. Factory=`0x21Fd…`. |
| src/SheriffBasePlugin/contracts/SheriffBasePlugin.sol | yes | `beforeSwap` security→oracle→fee; `beforeModifyPosition` mint vs burn; flash; sentinels | Custom hook order. |
| src/SheriffBasePlugin/contracts/plugins/SecurityPlugin.sol | yes | `_checkStatus` (skips if registry=0); `_checkStatusOnBurn` (no zero-check); `setSecurityRegistry` write-then-`_authorize` | Burn-zero-registry candidate. Live plugin registry is set. |
| src/SheriffBasePlugin/contracts/base/AlgebraBasePlugin.sol | yes | `_authorize` = pluginFactory or factory role | Auth OK if `_authorize` reverts. |
| src/SheriffBasePlugin/contracts/base/BasePlugin.sol | yes | `onlyPool`; `collectPluginFee`; config pin | |
| src/SheriffBasePlugin/contracts/plugins/SlidingFeePlugin.sol | yes | `_getFeeAndUpdateFactors`; factor clamp | uint16 cap; not yet checked vs pool `fee+pluginFee<1e6` under live baseFee. |
| src/SheriffBasePlugin/contracts/plugins/DynamicFeePlugin.sol | yes | `changeFeeConfiguration`; `_getCurrentFee`; `changeDynamicFeeStatus` | `getCurrentFee` omits sliding fee (documented). |
| src/SheriffBasePlugin/contracts/plugins/VolatilityOraclePlugin.sol | yes | `initialize`; `_writeTimepoint`; `prepayTimepointsStorageSlots` | prepay writes timestamp only, not `initialized` |
| src/SheriffBasePlugin/contracts/libraries/AdaptiveFee.sol | yes | `validateFeeConfiguration`; `getFee` sigmoid | max fee capped uint16 |
| src/SheriffBasePlugin/contracts/libraries/VolatilityOracle.sol | partial | `Timepoint` + `write`/`initialize` | WINDOW=4 hours. FeeHelper uses 1 day (mismatch). |
| src/SheriffBasePluginFactory/contracts/base/SheriffPluginFactory.sol | yes | `beforeCreatePoolHook`; `_createPlugin`; `_postDeployWiring` registry | |
| src/SheriffBasePluginFactory/contracts/SheriffBasePluginFactory.sol | yes | ctor + `_deployPlugin` via deployer | thin wrapper |
| src/SheriffBasePluginFactory/contracts/deployers/SheriffBasePluginDeployer.sol | yes | `deploy` onlyFactory; pluginFactory slot = factory | |
| src/SheriffFeeHelper/contracts/helpers/SheriffFeeHelper.sol | yes | `quoteSwapFee`/`getEffectiveFee` fallback; sliding/dynamic sim | View-only. Not a custody path. |
| src/SheriffYakRouter/contracts/SheriffYakRouter.sol | yes | `findBestPath`; `_swapNoSplit` user adapters; fee; permit try/catch | Caller-only spend. Intermediate `amountOutMin=0`. |
| src/SheriffYakRouter/contracts/lib/Maintainable.sol | yes | ctor roles; `transferOwnership` via grant/renounce | |
| src/SheriffYakRouter/contracts/lib/Recoverable.sol | yes | `recoverERC20`/`recoverNative` onlyMaintainer | Trust: maintainer can sweep router balances. |
| src/TeamVestingLocker/src/TeamVestingLocker.sol | yes | cliff then OZ linear vest | ROB/Sheriff team vest; no admin. |
| src/AlgebraFactory.sol | yes | `createPool`/`createCustomPool` role; plugin hooks; vault | Integral 1.2.2 stock. Custom pools need CUSTOM_POOL_DEPLOYER. |
| src/AlgebraV2Adapter.sol | yes | public `swap(...,deployer)`; callback `tempPoolAddress`; leftover refund only on internal `_swap` | No onlyRouter on external swap. Drain only if adapter holds tokens. |
| src/VanillaV2Adapter.sol | yes | `_query`/`_swap` via Sheriff V2 `getPair`+`getAmountOut` | Relies on router pre-funding pair. |
| src/CustomPoolEntry.sol | yes | `createCustomPool` msg.sender==deployer; `setPlugin` onlyCustomDeployer | Cannot retarget default pools. |
| src/LpLocker.sol | yes | `onERC721Received` once; `collectFees` to immutable recipient | No unwind path. |
| src/Distributor2.sol | yes | same 6078-byte Distributor as D1 | Live `0x011b…`. |
| Sheriff Points Token | no | — | unverified; used as campaign 0 incentive |
| src/YakAdapter.sol | yes | public `swap` → `_swap`; no onlyRouter; maintainer recover | Tokens must already sit on adapter/pair. Live adapter balances 0. |

## Opened but not counted in Y (interfaces / vendor / dupes)

| Path | Reason |
|------|--------|
| `src/v2/contracts/interfaces/**` | interfaces only |
| `src/SheriffYakRouter/contracts/interface/**` | interfaces only |
| `src/SheriffBasePlugin/contracts/interfaces/**` | interfaces only |
| `src/SheriffBasePluginFactory/contracts/{plugins,base,libraries,SheriffBasePlugin.sol}` | byte-duplicate of plugin tree |
| `@openzeppelin/**`, `@cryptoalgebra/**`, `@uniswap/**`, `@camelotlabs/**` | vendored |

## Explicitly excluded

| Path / area | Reason |
|-------------|--------|
| Algebra Integral Core (unmodified pool/NPM/SwapRouter/Quoter/TickLens) | battle-tested upstream; hunt Sheriff plugins/config only unless a Sheriff-specific wiring bug appears |
| `lib/**` / `node_modules/**` | vendored |
| `test/**` | none in hunt tree |
| Other chain Algebra factories (`0x28A5…`, empty upgradeable shells) | not Sheriff-owned |
| Frontend `sheriff.money` JS | Cloudflare challenge; bundle grep failed |

## Coverage honesty

Coverage incomplete: 88% (29/33). Findings apply to examined paths only. Not a full audit of Algebra Core pools or the unverified Points token.
Still untraced: Points token source (unverified, 2642 bytes, owner=deployer), unknown create `0xbd32…`.
