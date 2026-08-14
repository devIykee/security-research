# Hunt reports (2026-07-19 / 2026-07-20)

Skill: `/duke-web3-bug-hunting` · Chain: Robinhood Chain (4663)  
Researcher: **deviykee**  
Rules: fork / eth_call / local Foundry only. No mainnet exploits.

**Canonical target list:** [targets/robinhood-chain-targets-2026-07-21.md](../targets/robinhood-chain-targets-2026-07-21.md) (replaces 2026-07-20 list).

| # | Project | Finding | Severity | Report | DM |
|---|---------|---------|----------|--------|-----|
| 2 | **Robinlaunch** | V3 graduation + Direct Pool migration pool squat | **High** | [Robinlaunch-High-V3-migration-pool-squat.md](./Robinlaunch-High-V3-migration-pool-squat.md) | [dm-robinlaunch.md](./dm-robinlaunch.md) |
| 3 | **Robinfun** | Cheap V2 pair pollution freezes graduate; users stuck; owner recovery takes raise | **High** | [Robinfun-High-pair-pollution-graduation-freeze.md](./Robinfun-High-pair-pollution-graduation-freeze.md) | [dm-robinfun.md](./dm-robinfun.md) |
| 4 | **RevShare** | Factory/graduation source unverified; no High proven yet | Notes | [RevShare-hunt-notes.md](./RevShare-hunt-notes.md) | [dm-revshare.md](./dm-revshare.md) (source ask only) |
| 5 | **Nock Terminal** | No shared factory; guided V4 single-sided; no High | Notes | [NockTerminal-hunt-notes.md](./NockTerminal-hunt-notes.md) | [dm-nockterminal.md](./dm-nockterminal.md) |
| 6 | **Slops / Robin the Hood** | Curve->V4 migrate mapped; unverified; residual pool-init lead; no High yet | Notes | [Slops-hunt-notes.md](./Slops-hunt-notes.md) | [dm-slops.md](./dm-slops.md) |
| 7 | **Hood Tech / HoodFUN** | Instant V3; `getPool==0` aborts pre-pool; no High | Notes | [HoodTech-hunt-notes.md](./HoodTech-hunt-notes.md) | [dm-hoodtech.md](./dm-hoodtech.md) |
| 8 | **RobinPad** | Docs factory/locker/fee empty on 4663; no High | Notes | [RobinPad-hunt-notes.md](./RobinPad-hunt-notes.md) | [dm-robinpad.md](./dm-robinpad.md) |
| 9 | **RoughLaunch (Inkfeather)** | Instant V3; factory has createAndInitialize; unverified UUPS; no High | Notes | [RoughLaunch-hunt-notes.md](./RoughLaunch-hunt-notes.md) | [dm-roughlaunch.md](./dm-roughlaunch.md) |
| 10 | **Foragepad / Furnace** | Curve→V3 migrator live, unverified; no High yet | Notes | [Foragepad-hunt-notes.md](./Foragepad-hunt-notes.md) | [dm-foragepad.md](./dm-foragepad.md) |
| 11 | **StockDotFun** | V4 pre-init freezes graduation; full raise trapped; no rescue | **High** | [StockDotFun-High-V4-preinit-graduation-freeze.md](./StockDotFun-High-V4-preinit-graduation-freeze.md) | [dm-stockdotfun.md](./dm-stockdotfun.md) |
| 12 | **RobinLaunchpad** | Verified pump = internal AMM (no Uni migrate); no High | Notes | [RobinLaunchpad-hunt-notes.md](./RobinLaunchpad-hunt-notes.md) | [dm-robinlaunchpad.md](./dm-robinlaunchpad.md) |
| 13 | **MetaLaunch** | V12 TickMisaligned + salt getPool==0 mitigates V3 squat | Notes | [MetaLaunch-hunt-notes.md](./MetaLaunch-hunt-notes.md) | [dm-metalaunch.md](./dm-metalaunch.md) |
| 19 | **Openfair** | Same V3 pool squat class | **High** | [Openfair-High-V3-migration-pool-squat.md](./Openfair-High-V3-migration-pool-squat.md) | [dm-openfair.md](./dm-openfair.md) |
| 20 | **Novapex** | Curve→V2; 95% migrate mins + owner rescue; no High | Notes | [Novapex-hunt-notes.md](./Novapex-hunt-notes.md) | [dm-novapex.md](./dm-novapex.md) |
| 21 | **Pons** | Instant V3; getPool pre-check mitigates squat; site DNS dead | Notes | [Pons-hunt-notes.md](./Pons-hunt-notes.md) | [dm-pons.md](./dm-pons.md) |
| 22 | **The Greenwood** | Instant V3 createPool+init; factory/locker unverified | Notes | [Greenwood-hunt-notes.md](./Greenwood-hunt-notes.md) | [dm-greenwood.md](./dm-greenwood.md) |
| 23 | **Primehod** | Curve milestone only + V3 createPool; no High | Notes | [Primehod-hunt-notes.md](./Primehod-hunt-notes.md) | [dm-primehod.md](./dm-primehod.md) |
| 24 | **Leavehood** | UUPS unverified factory/core; lock is time-lock | Notes | [Leavehood-hunt-notes.md](./Leavehood-hunt-notes.md) | [dm-leavehood.md](./dm-leavehood.md) |
| 35/12 | **RobinLaunchpad** | Same as #12 (NFT paste row) | Notes | [RobinLaunchpad-hunt-notes.md](./RobinLaunchpad-hunt-notes.md) | [dm-robinlaunchpad.md](./dm-robinlaunchpad.md) |
| 36 | **HOODIES Marketplace** | Site timeout; no custom CA located yet | Notes | [HOODIES-hunt-notes.md](./HOODIES-hunt-notes.md) | — |
| 25 | **Recurve** | Instant V3; PoolTaken blocks pre-init | Notes | [Recurve-hunt-notes.md](./Recurve-hunt-notes.md) | [dm-recurve.md](./dm-recurve.md) |
| 26 | **HoodRich / RobinPump** | Curve→V2 graduate with amount mins **0,0** | **High** | [HoodRich-High-V2-zero-min-migration.md](./HoodRich-High-V2-zero-min-migration.md) | [dm-hoodrich.md](./dm-hoodrich.md) |
| 27 | **Merry Men / PumpClaw** | V4 soft init + predictable CREATE freezes all future `createToken` | **High** | [MerryMen-High-V4-preinit-factory-freeze.md](./MerryMen-High-V4-preinit-factory-freeze.md) | [dm-merrymen.md](./dm-merrymen.md) |
| 29 | **Clanker** | Instant V4 modular pad; no raise; no High | Notes | [Clanker-hunt-notes.md](./Clanker-hunt-notes.md) | — |
| Val5 | **bow.fun** | Instant V3; pre-init reverts (mitigated squat) | Notes | [Bow-hunt-notes.md](./Bow-hunt-notes.md) | — |
| 28 | **Flap** | Bonding pad; Portal ~60 ETH; migrator unverified | Notes | [Flap-hunt-notes.md](./Flap-hunt-notes.md) | — |
| 30 | **Bankr** | Agent/terminal; launches via Clanker/Doppler | Notes | [Bankr-hunt-notes.md](./Bankr-hunt-notes.md) | — |
| 31 | **Noxa** | Factory disabled; sites degraded / Rain.fun rebrand | Notes | [Noxa-hunt-notes.md](./Noxa-hunt-notes.md) | — |
| 37 | **Sheriff.money** | `_checkStatusOnBurn` reverts when `securityRegistry == 0` (exit freeze) | **Medium** | [sheriff-medium-burn-registry-zero.md](../hunts/sheriff/reports/sheriff-medium-burn-registry-zero.md) | [dm-first-contact.md](../hunts/sheriff/reports/dm-first-contact.md) |
| 38 | **Aumo (X Layer)** | Multi-strategy NAV stuck venue drain + dust full liquidation + USDG retreat sandwich | **High** | [FINDINGS-MASTER.md](../hunts/aumo/reports/FINDINGS-MASTER.md) | [dm-first-contact.md](../hunts/aumo/reports/dm-first-contact.md) |

**Skipped #1 (hood.fun)** for our session (you already messaged).

## Plain language (Highs so far)

Those Highs (Robinlaunch/Openfair) let a stranger open the Uniswap market for a token *before* the launchpad finishes moving buyer ETH into that market, and set a fake price. When the pad auto-deposits the raise, it does not check the price. Buyers on that token can lose a large share of *that launch's* money. Not a one-click drain of every token on the pad forever; rated **High**.

**#11 StockDotFun** is a related but different High: V4 graduation always calls hard `initialize`. A stranger can pre-initialize the pool key (gas only). Graduation then fails forever; curve trading is already frozen after the target; there is no owner rescue in verified source. Bound = that launch's full `realQuote` (~4.4 ETH class target). Freeze, not wrong-price dump.

**#27 Merry Men** is another V4 pre-init High, but on an **instant** list factory: soft `positionManager.initializePool` ignores pre-init, CREATE token address is predictable from factory nonce, and after pre-init `createToken` reverts with `CurrencyNotSettled` forever (nonce rolls back). Bound = permanent freeze of all future launches on that factory.

#5 Nock does not custody a raise on a factory, so that class does not port. #6 Slops does custody on a curve and migrates to Uniswap v4, but source is unverified and the V4 wrong-price lead is not PoC-complete yet. #7 Hood Tech mitigates V3 squat with an explicit pool-pre-exists check. #8 RobinPad has no deployed custom factory at the docs addresses yet. #9 RoughLaunch is instant V3 (milestone graduation); factory bytecode still contains createAndInitializePoolIfNecessary (lead only). #10 Foragepad has a real curve migrator but unverified source. #12 RobinLaunchpad pump path keeps the raise as an **internal** locked AMM (no external Uni migrate), so V3/V4 squat/freeze classes do not apply there. #13 MetaLaunch V12 checks pool tick equals intended after createAndInitialize (`TickMisaligned`). #20 Novapex uses V2 migrate with 95% mins and owner rescue (not Robinfun-style permanent pollution freeze).

## PoC (proven Highs)

```bash
export PATH="$HOME/.foundry/bin:$PATH"
cd hunts/robinlaunch/poc
forge test --match-contract PoolSquatLogicTest -vv
# 2 passed: createAndInitializePoolIfNecessary ignores intended price if pool pre-inited

cd hunts/stockdotfun/poc
forge test --match-contract V4PreInitGraduationFreezeTest -vv
# 2 passed: V4 pre-init freezes graduation; sell blocked; principal trapped
```

## Shared root cause (Robinlaunch / Openfair)

```
createAndInitializePoolIfNecessary(token0, token1, fee, intendedSqrtPrice)
+ mint(..., amount0Min: 0, amount1Min: 0)
+ NO require(slot0.sqrtPriceX96 == intended)
```

Attacker pre-creates/initializes the pool at a fake price (gas only, zero meme tokens). Pad dumps raise liquidity into that price.

## Live notes

| Project | Core addr | Notes |
|---------|-----------|--------|
| Robinlaunch Factory v8 | `0x108eB6…17ea` | 9 bonding tokens (cast) |
| Robinlaunch DirectFactory v3 | `0x52afeB…a082` | 4 direct launches |
| Openfair LaunchFactory | `0x250552…A0cF` | verified; owner `0x5aF99e…B157` |
| RobinFun Factory v5 | `0xd861cb…5E4d` | ~6.91 ETH balance; source not verified (deferred) |
| Nock | EOA `0x06aD94…` + shared Uni v4 | no factory; registry JSON |
| Slops Factory | `0x248CAA…aA68` | unverified; sample curve `0x8AAe…` |
| Slops MigrationManager | `0x2fc07C…091C` | v4 unlock migrate; hook `0x4589a6…` |
| HoodTechFactory | `0x3345a91b…ffD0` | verified; Positions `0x15FA…` |
| RobinPad docs factory | `0x5C1C1d…e93B` | **empty code** on 4663 |
| RoughLaunch factory proxy | `0x5354c99a…62d2` | UUPS; impl `0x67eb3484…` |
| RoughLaunch fee locker | `0x3C31317d…c63A` | UUPS |
| Foragepad factory | `0x18999cAF…0818` | unverified; migrator `0x1C74Fd…` |
| Foragepad LP locker | `0xCa07e6a3…0d3b` | collect-only selectors |
| StockDotFunFactoryV2 | `0x470aca74…569e` | verified; 11 tokens; grad target 4.4 ETH |
| StockDotFun GradManager / Adapter / Locker | `0x408fA5…` / `0x74993f…` / `0x19f19e…` | verified V4 path |
| RobinLaunchpad PumpLaunchpad | `0x299773…281f` | verified internal AMM; no Uni migrate |
| MetaLaunchFactoryV12 | `0x1B2A2ee9…4660A` | verified; TickMisaligned on open |
| MetaLocker / pad V5 | `0x49A955…` / `0x49A3D3…` | verified legacy path |
| Novapex PumpFactory | `0xF34a44…7DC5` | verified; V2 migrate 95% mins |
| PonsLaunchFactory | `0xA5aAb3…1feB` | verified; PoolAlreadyExists gate |
| Greenwood factory | `0x81de99…2977` | unverified; createPool+initialize |
| PrimehodFactory | `0x57EfC7…794f` | verified; curve + V3 venues |
| Leavehood factory/core proxies | `0x2C81Cd…` / `0x5090C9…` | UUPS; impls unverified |
| LeavehoodLockLP | `0x8F1C12…CBF4` | verified time-lock |
| RecurveLaunchpad | `0xd41a03…acfd` | verified; PoolTaken |
| HoodRich RobinPump | `0x3c3111…540d` | verified; V2 mins 0,0 (**High**) |

## Sources on disk

- `hunts/robinlaunch/clean/src/` (BondingCurve, Factory, DirectFactory, LpFeeCollector)
- `hunts/openfair/src/` (LaunchFactory, OpenLaunch, …)
- `hunts/robinlaunch/poc/` (Foundry PoC)
- `hunts/nock/ADDRESSES.md`
- `hunts/slops/ADDRESSES.md`
- `hunts/hoodtech/` (verified Factory/Positions/Config sources)
- `hunts/roughlaunch/` (LaunchToken + addresses)
- `hunts/foragepad/ADDRESSES.md`
- `hunts/stockdotfun/` (Factory, BondingCurvePoolV2, V4 adapter/locker + PoC)
- `hunts/robinlaunchpad/` (PumpLaunchpad + ADDRESSES)
- `hunts/metalaunch/` (V12 factory, V5 FoundryLaunchpad, MetaLocker)
- `hunts/novapex/` (PumpFactory + CoinThreads)
- `hunts/pons/` (PonsLaunchFactory + token)
- `hunts/greenwood/` (ADDRESSES + bytecode notes)
- `hunts/primehod/src/` (Factory, Curve, V3Locker, Vesting)
- `hunts/leavehood/` (Lock source + proxy/impl addresses)
- `hunts/recurve/src/` (RecurveLaunchpad, RecurveCoin)
- `hunts/hoodrich/` (RobinPump + RobinPumpMeme)

## Extra skills installed (2026-07-20)

Vendor under `vendor/`:

- `awesome-web3-security` (gmh5225)
- `smart-contracts-audit-foundry-slither` (chainstacklabs)
- `web3-bug-bounty-hunting-ai-skills` (shuvonsec)
- `sc-auditor` (Archethect)

Also mirrored into `~/.grok/skills/` and `.grok/skills/` (web3-* skills, sc-auditor, awesome-w3s-*, foundry-slither-audit wrapper).

## Disclosure

Reports are private by design. Contact teams via X / security email; share PoC privately; do **not** post live exploit details until patched.
