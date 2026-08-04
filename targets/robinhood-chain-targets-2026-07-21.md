# Robinhood Chain targets — 2026-07-21 (CANONICAL)

**This file replaces** `robinhood-chain-targets-2026-07-20.md` as the working hunt list.

Compiled for `/duke-web3-bug-hunting` · Researcher: **deviykee**

**Value ranking (most → least):** token MC → revenue/volume/traction → RH Chain narrative fit (AI agents, RWA/stocks, launchpads) → early FDV signals.

**Filters:** non-Nigerian · RH Chain ecosystem · launchpads / custody-bearing protocols first  
**Chain defaults:**

```
CHAIN          : Robinhood Chain
RPC            : https://rpc.mainnet.chain.robinhood.com
CHAIN_ID       : 4663
EXPLORER       : https://robinhoodchain.blockscout.com
RESEARCHER     : deviykee
```

**Before any hunt:** confirm website resolves, find factory/migrator on Blockscout, fill `KNOWN_ADDRS`. Do not invent addresses.  
**Verification:** fork / eth_call / local Foundry only. Never mainnet exploit.

---

## Hunt status legend

| Tag | Meaning |
|-----|---------|
| **HUNTED-HIGH** | Permissionless High written; DM ready |
| **HUNTED-NOTES** | Full pass done; no High claimed (or incomplete source) |
| **SKIPPED** | Intentionally not fully hunted this campaign |
| **OPEN** | Not hunted yet — queue these |
| **SUPPORT** | Analytics/radar only; skip unless custody contracts found |
| **RISK** | Phish/mirror risk — do not connect wallet |
| **WATCH** | Early / thin surface; enrich before deep hunt |

---

## Value-ranked master queue (user list + prior hunts)

Already-hunted rows are marked and **must not be re-hunted** without new factory version / redeploy.

| Val# | Project | X Handle | Token | Approx MC / Value | Category | Website | Status | Notes / Report |
|------|---------|----------|-------|-------------------|----------|---------|--------|----------------|
| 1 | Virtuals Protocol | @virtuals_io | $VIRTUAL | ~$360–450M | AI Agents / Infra | https://virtuals.io | **OPEN** | Multi-chain leader; confirm RH Chain contracts before deep dive |
| 2 | Bankr | @bankrbot | $BNKR | ~$33–38M | AI Financial Infra / Launchpad | https://bankr.bot | **HUNTED-NOTES** | No RH pad factory; uses Clanker/Doppler · [Bankr-hunt-notes](../reports/Bankr-hunt-notes.md) |
| 3 | Pons | @ponsdotfamily | $PONS | ~$24–30M+ | Launchpad | https://pons.family | **HUNTED-NOTES** | Instant V3; getPool pre-check mitigates squat · [Pons-hunt-notes](../reports/Pons-hunt-notes.md) |
| 4 | Clanker | @clanker_world | $CLANKER | ~$15–27M | Launchpad | https://clanker.world | **HUNTED-NOTES** | Instant V4; no raise; no High · [Clanker-hunt-notes](../reports/Clanker-hunt-notes.md) |
| 5 | Bow | @bowdotfun | $BOW | Low–Mid (early) | Launchpad | https://bow.fun | **HUNTED-NOTES** | Instant V3; pre-init reverts · [Bow-hunt-notes](../reports/Bow-hunt-notes.md) |
| 6 | SLVR | @S_L_V_R_FUN | $SLVR | Sub $2M | Gamified Mining | (limited public site) | **OPEN** | High revenue / low MC narrative; confirm contracts |
| 7 | Arcus | @arcus_xyz | (TBD) | High potential DEX | Spot + Perps DEX | https://arcus.xyz | **OPEN** | Waitlist/official ecosystem DEX; after pads if live |
| 8 | Rialto | @rialto_xyz | (Early) | Early / airdrop | Spot DEX | https://rialto.xyz | **OPEN** | Native spot DEX |
| 9 | Karma | @KarmaWallet | $KARMA | Early / Low | AI Social Trading | (On Virtuals) | **WATCH** | Virtuals agent; after Virtuals surface map |
| 10 | Bowyer | @Bowyer_App | $BOWYER | Early / Low | AI Agent Marketplace | (On Virtuals) | **WATCH** | Virtuals agent |
| 11 | Wood | @sherwoodagent | $WOOD | Early / Low | AI Agent Infra | (On Virtuals) | **WATCH** | Virtuals agent |
| 12 | Flap | @flapdotsh | (Early) | Low–Mid | Modular Launchpad | https://flap.sh | **HUNTED-NOTES** | Portal ~60 ETH; migrator lead · [Flap-hunt-notes](../reports/Flap-hunt-notes.md) |
| 13 | Noxa | @noxa_fi | (Early) | Mid (past traction) | Multi-DEX Launchpad | https://noxa.fi / https://noxa.fun | **HUNTED-NOTES** | Factory `launchEnabled=false`; sites degraded · [Noxa-hunt-notes](../reports/Noxa-hunt-notes.md) |
| 14 | DegenLaunchpad | (search) | (Early) | Low | Fair Launch | — | **WATCH** | Confirm domain/CA first |
| 15 | Coinbarrel | @UseCoinbarrel | $CB | Early / Low | Launchpad | — | **WATCH** | Solana pivot → RH / Arc |
| 16 | PMAV | @pmavfun | $PMAV | Early / Low | Data-driven Launchpad | — | **WATCH** | Uni V4 pools on RH |
| 17 | Long | @longdotxyz | (Early) | Low | Hybrid RWA/Meme Launchpad | — | **WATCH** | Stocks + memes |
| 18 | ClutchMarkets | @ClutchMarkets | (Early) | Low–Mid pot. | Launchpad / NFT | — | **WATCH** | $STONEBROKERS team |
| 19 | Circus | @circus_trade | (Early) | Low | Launchpad | — | **WATCH** | Bonk team |
| 20 | FlowrHoodApp | @FlowrHoodApp | (Early) | Low | Gamified | — | **WATCH** | SLVR-like mechanics |
| — | The Index | @theindexfi | — | — | Distribution / index | — | **HUNTED-HIGH** | Flash-inflated snapshot · [TheIndex-High-…](../reports/TheIndex-High-flash-inflated-snapshot.md) |

### New tech / micro-MC (Val 21+) — WATCH / OPEN-P2

| Project | X Handle | Category | Status |
|---------|----------|----------|--------|
| HOODBOT | @HoodbotRHC | Wallet / bot | **WATCH** |
| HBNK / HamsterBunker | @HamsterBunkerRH | AI Trust | **WATCH** |
| RANGE | @range_cash | Liquidity | **WATCH** |
| HOODR | @hoodrdotfun | — | **WATCH** |
| KAIRUE | @usekairune | — | **WATCH** |
| WATCH | @Hoodwatchdotio | Whale tracker | **SUPPORT** |
| ROBINHOODS | @real_Robinhoods | — | **WATCH** |
| STOCK / Stocktopia | @PlayStocktopia | Prediction / stocks | **WATCH** |
| SHARE | @PonsShare | Pons-related | **WATCH** (ties to **HUNTED** Pons) |
| NOVA | @HyperNovaUS | — | **WATCH** |

### Other early watchlist

| Project | X Handle | Category | Status |
|---------|----------|----------|--------|
| Gomintly | @gomintly | DeFi savings | **WATCH** |
| Aaro | @aaro_fun | Memecoin launch | **WATCH** |
| OasisRBH | @oasisRBH | Ownership | **WATCH** |
| Exypnos | @exypnos_xyz | Swap DEX | **WATCH** |
| Hoodmarket | @hoodmarket_ | Prediction | **WATCH** |
| Robinfunxyz | @robinfunxyz | — | **RISK/alias** — related to **HUNTED-HIGH** Robinfun; confirm not same product |
| Robinfarms | @robinfarms | Farming | **WATCH** |

### NFT / early collections (lowest tier)

~50+ handles (MonkeyHoodNFT, QuiversHq, DOOMPS_, Toadlersnft, RobinApesNft, … click_nft_).  
**Status:** **WATCH** lottery / community — not primary bounty queue.  
**Dup note:** @ImpzOnRobin may appear in multiple lists; sherwoodnftss ≠ @sherwoodagent.  
**Rule:** do not prioritize over launchpads/DEX with custody. DYOR on mint claims.

---

## Prior campaign launchpads (still canonical; many already hunted)

Numbering continues from 2026-07-20 where possible for report links.

| # | Project | Website | Type | Status | Report |
|---|---------|---------|------|--------|--------|
| 1 | LaunchHood / hood.fun | https://hood.fun | Bonding curve | **SKIPPED** | User already messaged |
| 2 | Robinlaunch | https://robinlaunch.fun | Bonding + direct | **HUNTED-HIGH** | [Robinlaunch-High-…](../reports/Robinlaunch-High-V3-migration-pool-squat.md) |
| 3 | Robinfun | https://robinfun.live | Bonding curve | **HUNTED-HIGH** | [Robinfun-High-…](../reports/Robinfun-High-pair-pollution-graduation-freeze.md) |
| 4 | RevShare | https://revshare.dev | Multi-mode | **HUNTED-NOTES** | [RevShare-hunt-notes](../reports/RevShare-hunt-notes.md) |
| 5 | Nock Terminal | https://nockterminal.com/launch | Direct V4 | **HUNTED-NOTES** | [NockTerminal-hunt-notes](../reports/NockTerminal-hunt-notes.md) |
| 6 | Slops (ex Robin the Hood) | https://www.slops.lol | Bonding → V4 | **HUNTED-NOTES** | [Slops-hunt-notes](../reports/Slops-hunt-notes.md) |
| 7 | Hood Tech / HoodFUN | https://hood.tech | Instant V3 | **HUNTED-NOTES** | [HoodTech-hunt-notes](../reports/HoodTech-hunt-notes.md) |
| 8 | RobinPad | https://www.robinpad.fi | Direct pool | **HUNTED-NOTES** | [RobinPad-hunt-notes](../reports/RobinPad-hunt-notes.md) |
| 9 | Inkfeather / RoughLaunch | https://inkfeather.io | Hybrid V3 | **HUNTED-NOTES** | [RoughLaunch-hunt-notes](../reports/RoughLaunch-hunt-notes.md) |
| 10 | Foragepad / The Furnace | https://foragepad.com | Bonding curve | **HUNTED-NOTES** | [Foragepad-hunt-notes](../reports/Foragepad-hunt-notes.md) |
| 11 | stock.fun / StockDotFun | https://stockdotfun.com | Stock-token → V4 | **HUNTED-HIGH** | [StockDotFun-High-…](../reports/StockDotFun-High-V4-preinit-graduation-freeze.md) |
| 12 | RobinLaunchpad | https://www.robinlaunchpad.com | Pump + NFT | **HUNTED-NOTES** | [RobinLaunchpad-hunt-notes](../reports/RobinLaunchpad-hunt-notes.md) |
| 13 | MetaLaunch | https://metalaunch.fun | Direct V3 | **HUNTED-NOTES** | [MetaLaunch-hunt-notes](../reports/MetaLaunch-hunt-notes.md) |
| 14 | PadQuiver | https://padquiver.com | Reward-token pad | **OPEN** | — |
| 15 | GoBolt | https://gobolt.fun | Direct V4 | **OPEN** | — |
| 16 | HoodTracker | https://www.hoodtracker.com/launch | Direct launch | **OPEN** | — |
| 17 | launch.win | https://launchwin.app | Direct DEX | **OPEN** | — |
| 18 | Loxley | https://loxley.app | Pad + terminal | **OPEN** | — |
| 19 | Openfair | https://openfair.app | Curve + instant | **HUNTED-HIGH** | [Openfair-High-…](../reports/Openfair-High-V3-migration-pool-squat.md) |
| 20 | Novapex | https://www.novapex.fun | Curve → V2 | **HUNTED-NOTES** | [Novapex-hunt-notes](../reports/Novapex-hunt-notes.md) |
| 21 | Pons | https://pons.family | Instant V3 | **HUNTED-NOTES** | [Pons-hunt-notes](../reports/Pons-hunt-notes.md) |
| 22 | The Greenwood | https://www.thegreenwood.fun | Direct V3 | **HUNTED-NOTES** | [Greenwood-hunt-notes](../reports/Greenwood-hunt-notes.md) |
| 23 | Primehod | https://primehod.lol | Curve or V3 | **HUNTED-NOTES** | [Primehod-hunt-notes](../reports/Primehod-hunt-notes.md) |
| 24 | Leavehood | https://leavehood.com | V3-as-curve | **HUNTED-NOTES** | [Leavehood-hunt-notes](../reports/Leavehood-hunt-notes.md) |
| 25 | Recurve (ex-HoodPad) | https://recurve.fi | Instant V3 | **HUNTED-NOTES** | [Recurve-hunt-notes](../reports/Recurve-hunt-notes.md) |
| 26 | HoodRich / RobinPump | https://robinpump.space | Multi-mode | **HUNTED-HIGH** | [HoodRich-High-…](../reports/HoodRich-High-V2-zero-min-migration.md) |
| 27 | Merry Men | https://www.merrymen.fun | Instant V4 (PumpClaw) | **HUNTED-HIGH** | [MerryMen-High-…](../reports/MerryMen-High-V4-preinit-factory-freeze.md) |
| 28 | Flap | https://flap.sh | Bonding → multi-DEX | **HUNTED-NOTES** | [Flap-hunt-notes](../reports/Flap-hunt-notes.md) |
| 29 | Clanker | https://www.clanker.world | Direct V4 | **HUNTED-NOTES** | [Clanker-hunt-notes](../reports/Clanker-hunt-notes.md) |
| 30 | Bankr | https://bankr.bot | Bot / terminal | **HUNTED-NOTES** | [Bankr-hunt-notes](../reports/Bankr-hunt-notes.md) |
| 31 | NOXA Fun | https://noxa.fun / https://noxa.fi | Multi-DEX pad | **HUNTED-NOTES** | [Noxa-hunt-notes](../reports/Noxa-hunt-notes.md) |
| 35 | RobinLaunchpad (NFT row) | https://www.robinlaunchpad.com | NFT hybrid | **HUNTED-NOTES** | same as #12 |
| 36 | HOODIES Marketplace | https://robinhoodnfts.com | NFT market | **HUNTED-NOTES** | [HOODIES-hunt-notes](../reports/HOODIES-hunt-notes.md) |

### Dedup notes

| Alias | Canonical |
|-------|-----------|
| Robin the Hood, robinthehood.fun | **#6 Slops** |
| RoughLaunch | **#9 Inkfeather** |
| The Furnace | **#10 Foragepad** |
| HoodPad | **#25 Recurve** |
| Pons (Val#3) | **#21** — already hunted |
| Flap (Val#12) | **#28** |
| Clanker (Val#4) | **#29** |
| Bankr (Val#2) | **#30** |
| NOXA (Val#13) | **#31** |
| The Index / theindexfi | **HUNTED-HIGH** (reports/) — not re-hunt |
| SHARE / PonsShare | Pons ecosystem — secondary to #21 |
| stock.fun DNS | Use stockdotfun.com (#11 HUNTED-HIGH) |

---

## Already hunted summary (do not re-hunt without new version)

| Status | Projects |
|--------|----------|
| **HUNTED-HIGH** | Robinlaunch · Robinfun · StockDotFun · Openfair · HoodRich · **TheIndex** · **Merry Men (#27)** |
| **HUNTED-NOTES** | RevShare · Nock · Slops · Hood Tech · RobinPad · RoughLaunch · Foragepad · RobinLaunchpad · MetaLaunch · Novapex · **Pons** · Greenwood · Primehod · Leavehood · Recurve · HOODIES · **Clanker (#29)** |
| **SKIPPED** | hood.fun (#1) |

---

## Hunt queue (value-ordered OPEN only)

### Next (P0 — highest value + hunt surface)

1. **Val#1 Virtuals** (~$360–450M) — only after RH contract footprint proven  
2. **Val#6 SLVR** — revenue beast; confirm CA  
3. **#14–18** PadQuiver, GoBolt, HoodTracker, launch.win, Loxley  
4. **Val#7–8 Arcus / Rialto** — after pads if contracts live  
5. **Rain.fun** (Noxa rebrand surface) — map factory if live launches  
6. **Flap re-open** only with verified migrator source or live near-graduation token

### P1 / after P0

- Virtuals agents (Karma, Bowyer, Wood) once Virtuals RH surface mapped  
- Val#14–20 early launchpads (enrich domain + CA first)  
- Micro tech (HOODBOT, RANGE, …) only if custody + traction  

### Do not re-hunt without new version/addrs

#2 Robinlaunch · #3 Robinfun · #4 RevShare · #5 Nock · #6 Slops · #7 Hood Tech · #8 RobinPad · #9 RoughLaunch · #10 Foragepad · #11 StockDotFun · #12 RobinLaunchpad · #13 MetaLaunch · #19 Openfair · #20 Novapex · #21 Pons · #22 Greenwood · #23 Primehod · #24 Leavehood · #25 Recurve · #26 HoodRich · **#27 Merry Men** · **#28 Flap** · **#29 Clanker** · **#30 Bankr** · **#31 Noxa** · **Bow (Val#5)** · TheIndex  

---

## Known High root causes (reuse when scanning OPEN pads)

1. **V3 migration pool squat:** `createAndInitializePoolIfNecessary` + mins = 0 + no `slot0` check  
   - Found: Robinlaunch, Openfair · Mitigated: Hood Tech, MetaLaunch V12, Pons, Recurve  
2. **V2 pair pollution / zero-min migrate**  
   - Found: Robinfun, HoodRich · Mitigated: Novapex 95% mins  
3. **V4 pool pre-init graduation freeze**  
   - Found: StockDotFun  

3b. **V4 soft `initializePool` + ignored return → factory launch freeze**  
   - Found: Merry Men / PumpClaw (`positionManager.initializePool` soft-fails; CREATE address predictable; `createToken` permanently reverts)  
4. **Flash-inflated permissionless snapshot**  
   - Found: TheIndex  
5. **Leads (not High):** Foragepad migrator, Slops V4, RoughLaunch closed-source factory  

---

## TARGET blocks — P0 OPEN (copy for session)

### Bankr (Val#2 / #30)

```
--- TARGET Bankr ---
PROJECT_NAME   : Bankr
X_HANDLE       : @bankrbot
WEBSITE        : https://bankr.bot
CHAIN          : Robinhood Chain
RPC            : https://rpc.mainnet.chain.robinhood.com
CHAIN_ID       : 4663
EXPLORER       : https://robinhoodchain.blockscout.com
PRODUCT_TYPE   : launchpad
NOTES          : ~$33-38M MC; AI financial infra + token launches; confirm RH factory
RESEARCHER     : deviykee
HUNT_PRIORITY  : P0
```

### Clanker (Val#4 / #29)

```
--- TARGET Clanker ---
PROJECT_NAME   : Clanker
X_HANDLE       : @clanker_world
WEBSITE        : https://www.clanker.world
CHAIN          : Robinhood Chain
RPC            : https://rpc.mainnet.chain.robinhood.com
CHAIN_ID       : 4663
EXPLORER       : https://robinhoodchain.blockscout.com
PRODUCT_TYPE   : launchpad
NOTES          : ~$15-27M; modular V4 + smart sniper tax; multi-chain + RH
RESEARCHER     : deviykee
HUNT_PRIORITY  : P0
```

### Bow (Val#5)

```
--- TARGET Bow ---
PROJECT_NAME   : Bow
X_HANDLE       : @bowdotfun
WEBSITE        : https://bow.fun
CHAIN          : Robinhood Chain
RPC            : https://rpc.mainnet.chain.robinhood.com
CHAIN_ID       : 4663
EXPLORER       : https://robinhoodchain.blockscout.com
PRODUCT_TYPE   : launchpad
NOTES          : Permanent LP lock + creator fee-sharing
RESEARCHER     : deviykee
HUNT_PRIORITY  : P0
```

### Flap (Val#12 / #28)

```
--- TARGET Flap ---
PROJECT_NAME   : Flap
X_HANDLE       : @flapdotsh
WEBSITE        : https://flap.sh
DOCS           : https://docs.flap.sh
CHAIN          : Robinhood Chain
RPC            : https://rpc.mainnet.chain.robinhood.com
CHAIN_ID       : 4663
EXPLORER       : https://robinhoodchain.blockscout.com
PRODUCT_TYPE   : launchpad
NOTES          : Customization-focused; BNB + RH; YziLabs
RESEARCHER     : deviykee
HUNT_PRIORITY  : P0
```

### Merry Men (#27)

```
--- TARGET #27 ---
PROJECT_NAME   : Merry Men
WEBSITE        : https://www.merrymen.fun
KNOWN_ADDRS    : factory=0xfa4B952c15BC9d418ae4f552F7Fc76b4470596fE locker=0xd404C0fF8dE11841a4ff9CC4382eA5F6e4010751
CHAIN          : Robinhood Chain
RPC            : https://rpc.mainnet.chain.robinhood.com
CHAIN_ID       : 4663
EXPLORER       : https://robinhoodchain.blockscout.com
PRODUCT_TYPE   : launchpad
RESEARCHER     : deviykee
HUNT_PRIORITY  : P0
```

---

## How to run

1. Pick highest **OPEN** by Val# (or queue number)  
2. Say: `hunt Bankr` or `hunt Val#4`  
3. Agent runs duke-web3-bug-hunting Steps 1→10 + evm-audit routing  
4. Deliver report under `reports/`, DM under `reports/dm-*.md`, update this table status  

**Archives:**  
- `robinhood-chain-targets-2026-07-20.md` — prior canonical  
- `robinhood-chain-targets-2026-07-19.md` — history only  
**Do not use archives as working queue.**
