# Robinhood Chain targets — 2026-07-20 (CANONICAL)

**This file replaces** `robinhood-chain-targets-2026-07-19.md` as the working hunt list.

Compiled for `/duke-web3-bug-hunting` · Researcher: **deviykee**

**Filters:** non-Nigerian · early RH Chain pads · launchpads first  
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

---

## A. Launchpads — master table (deduped)

| # | Project | Website | Type | Key features | Status | Report |
|---|---------|---------|------|--------------|--------|--------|
| 1 | LaunchHood / hood.fun | https://hood.fun (alt: launchhood.com) | Bonding curve | Factory + locker + V3/V4 graduation, creator fees | **SKIPPED** | User already messaged |
| 2 | Robinlaunch | https://robinlaunch.fun | Bonding + direct pool | V3 graduation, creator rewards | **HUNTED-HIGH** | [Robinlaunch-High-…](../reports/Robinlaunch-High-V3-migration-pool-squat.md) |
| 3 | Robinfun | https://robinfun.live | Bonding curve | Auto-migration, LP burn, fee split | **HUNTED-HIGH** | [Robinfun-High-…](../reports/Robinfun-High-pair-pollution-graduation-freeze.md) |
| 4 | RevShare | https://revshare.dev | Multi-mode | Curve + direct, multi-chain claims | **HUNTED-NOTES** | [RevShare-hunt-notes](../reports/RevShare-hunt-notes.md) |
| 5 | Nock Terminal | https://nockterminal.com/launch | Direct V4 | Single-sided, LP to dead address | **HUNTED-NOTES** | [NockTerminal-hunt-notes](../reports/NockTerminal-hunt-notes.md) |
| 6 | Robin the Hood → **Slops** | https://robinthehood.fun / https://www.slops.lol | Bonding → V4 | Rebranded Slops; migrate path | **HUNTED-NOTES** | [Slops-hunt-notes](../reports/Slops-hunt-notes.md) |
| 7 | Hood Tech / HoodFUN | https://hood.tech / https://fun.hood.tech | Instant V3 | Telegram + web; LP locked | **HUNTED-NOTES** | [HoodTech-hunt-notes](../reports/HoodTech-hunt-notes.md) |
| 8 | RobinPad | https://www.robinpad.fi / https://robinpad.meme | Direct pool | Docs factories empty on 4663 | **HUNTED-NOTES** | [RobinPad-hunt-notes](../reports/RobinPad-hunt-notes.md) |
| 9 | Inkfeather / RoughLaunch | https://inkfeather.io | Hybrid single-sided V3 | Milestone graduation only | **HUNTED-NOTES** | [RoughLaunch-hunt-notes](../reports/RoughLaunch-hunt-notes.md) |
| 10 | Foragepad / The Furnace | https://foragepad.com | Bonding curve | Gas-only launch, V3 migrate + locker | **HUNTED-NOTES** | [Foragepad-hunt-notes](../reports/Foragepad-hunt-notes.md) |
| 11 | stock.fun / StockDotFun | https://stockdotfun.com (stock.fun DNS dead) | Stock-token paired curve → V4 | Verified V2 factory + graduation | **HUNTED-HIGH** | [StockDotFun-High-…](../reports/StockDotFun-High-V4-preinit-graduation-freeze.md) |
| 12 | RobinLaunchpad | https://www.robinlaunchpad.com | Launchpad + NFT/inscriptions | Pump AMM + marketplace/inscriptions hybrid | **HUNTED-NOTES** | [RobinLaunchpad-hunt-notes](../reports/RobinLaunchpad-hunt-notes.md) |
| 13 | MetaLaunch | https://metalaunch.fun | Direct V3 | V12 tick check mitigates squat | **HUNTED-NOTES** | [MetaLaunch-hunt-notes](../reports/MetaLaunch-hunt-notes.md) |
| 14 | PadQuiver | https://padquiver.com | Reward-token pad | Locked liquidity | **OPEN** | — |
| 15 | GoBolt | https://gobolt.fun | Direct V4 | Configurable positions | **OPEN** | — |
| 16 | HoodTracker | https://www.hoodtracker.com/launch | Direct launch | Max-wallet, creator fees | **OPEN** | — |
| 17 | launch.win | https://launchwin.app | Direct DEX pool | Position NFT at factory | **OPEN** | — |
| 18 | Loxley | https://loxley.app | Launchpad + terminal | Meme + stock lab | **OPEN** | — |
| 19 | Openfair | https://openfair.app | Curve + instant | Configurable fees, permanent lock | **HUNTED-HIGH** | [Openfair-High-…](../reports/Openfair-High-V3-migration-pool-squat.md) |
| 20 | Novapex | https://www.novapex.fun | Curve → V2 | 95% migrate mins + owner rescue | **HUNTED-NOTES** | [Novapex-hunt-notes](../reports/Novapex-hunt-notes.md) |
| 21 | Pons | https://pons.family/launchpad/create | Instant V3 | getPool pre-check mitigates squat | **HUNTED-NOTES** | [Pons-hunt-notes](../reports/Pons-hunt-notes.md) |
| 22 | The Greenwood | https://www.thegreenwood.fun | Direct V3 | Unverified factory; createPool+init | **HUNTED-NOTES** | [Greenwood-hunt-notes](../reports/Greenwood-hunt-notes.md) |
| 23 | Primehod | https://primehod.lol | Curve or V3 | Verified; no migrate High surface | **HUNTED-NOTES** | [Primehod-hunt-notes](../reports/Primehod-hunt-notes.md) |
| 24 | Leavehood | https://leavehood.com | V3-as-curve | UUPS unverified impl; lock is time-lock | **HUNTED-NOTES** | [Leavehood-hunt-notes](../reports/Leavehood-hunt-notes.md) |
| 25 | Recurve (ex-HoodPad) | https://recurve.fi | Instant V3 | PoolTaken mitigates pre-init | **HUNTED-NOTES** | [Recurve-hunt-notes](../reports/Recurve-hunt-notes.md) |
| 26 | HoodRich / RobinPump | https://robinpump.space | Multi-mode | Curve V2 grad **zero mins** | **HUNTED-HIGH** | [HoodRich-High-…](../reports/HoodRich-High-V2-zero-min-migration.md) |
| 27 | Merry Men | https://www.merrymen.fun | Configurable curve | Creator-set graduation | **OPEN** | — |
| 28 | Flap | https://docs.flap.sh / https://flap.sh/robinhood | Constant-product curve | RH-specific integration | **OPEN** | — |
| 29 | Clanker | https://www.clanker.world | Direct configurable V4 | Per-token fee settings | **OPEN** | — |
| 30 | Bankr | https://bankr.bot | Bot / terminal launch | Confirm RH factory | **OPEN** | — |
| 31 | NOXA Fun | https://noxa.fun | Prominent pad | High activity historically; may be degraded | **OPEN** | — |

### A2. NFT marketplaces (not launchpads)

| # | Project | Website | Type | Key features | Status | Report |
|---|---------|---------|------|--------------|--------|--------|
| 35 | RobinLaunchpad | https://www.robinlaunchpad.com | NFT + inscriptions + pump | See **#12** (same product; do not double-hunt) | **HUNTED-NOTES** | [RobinLaunchpad-hunt-notes](../reports/RobinLaunchpad-hunt-notes.md) |
| 36 | HOODIES Marketplace | https://robinhoodnfts.com | NFT marketplace | Claims 0% fee immutable / verified drops | **HUNTED-NOTES** | [HOODIES-hunt-notes](../reports/HOODIES-hunt-notes.md) |

### Dedup notes

| Alias | Canonical row |
|-------|----------------|
| Robin the Hood, robinthehood.fun | **#6 Slops** (rebrand) |
| RoughLaunch | **#9 Inkfeather** |
| The Furnace | **#10 Foragepad** |
| HoodPad (old brand) | **#25 Recurve** (not separate hunt) |
| pad.hoodscan.ai | Recurve redirect / old surface — do not double-count |
| Nock terminal screener | Same product as **#5** launch path |
| Openfair listed as #18 in some pastes | Canonical is **#19** (matches prior reports) |
| **#35 RobinLaunchpad** (NFT table) | Same as **#12** — already hunted |
| listings row typo under #36 | Ignore; single HOODIES row |

---

## B. Support / analytics (new or secondary — not primary hunt)

| # | Project | Website | Type | Status | Notes |
|---|---------|---------|------|--------|-------|
| 37 | StalkChain | https://stalkchain.com | Launch radar + analytics | **SUPPORT** | Skip unless custody contracts found |
| 38 | HoodRuns | https://hoodruns.com | Tracker | **SUPPORT** | Same rule |
| 39 | ArrowPad | — | Thin presence | **OPEN-P2** | Enrich before hunt |
| 40 | Sentry | — | Thin presence | **OPEN-P2** | Enrich before hunt |
| 41 | Prynt | — | Thin presence | **OPEN-P2** | Enrich before hunt |
| 42 | DYOR Fun | — | Factory claim on Blockscout | **OPEN-P1** | Find factory via explorer |
| 43 | Arcus | https://arcus.xyz | Perps/DEX | **OPEN-P1** | After launchpad pass |
| 44 | Rialto | — | PropAMM | **OPEN-P1** | Confirm site first |
| 45 | RobinFlow | — | Distribution | **OPEN-P0** if claim contracts | Enrich |

---

## C. Risk / skip

| # | Project | Status | Rule |
|---|---------|--------|------|
| 50 | hoodfun.cc, random .fun mirrors, brand-impersonation | **RISK** | Do not connect wallet; phishing until proven |
| 51 | NOXA / Vlad-style dead sites with spoof clones | **RISK** | Verify domain + contracts only |

---

## Known High root causes (reuse when scanning OPEN pads)

1. **V3 migration pool squat:** `createAndInitializePoolIfNecessary` + `amount0Min/amount1Min = 0` + no `slot0` price check  
   - Found: Robinlaunch, Openfair  
   - Mitigated example: Hood Tech (`getPool == 0` abort)  

2. **V2 pair pollution / zero-min migrate:** weak or no pollution check + `addLiquidityETH(..., 0, 0)`  
   - Found: Robinfun (freeze + owner recovery); **HoodRich RobinPump** (zero mins dump after graduate freeze)  
   - Mitigated example: Novapex (95% mins)

3. **V4 pool pre-init graduation freeze:** hard `PoolManager.initialize` on graduate + trading frozen after target + no rescue  
   - Found: StockDotFun (High)  

4. **Leads (not claimed High):** Foragepad migrator, Slops V4 init/hook flags, RoughLaunch `createAndInitialize` in closed-source factory  

5. **Mitigated by design:** RobinLaunchpad PumpLaunchpad keeps raise as internal AMM (no external Uni migrate)  

6. **Mitigated (MetaLaunch V12):** `createAndInitialize` + `if (tickNow != intended) revert TickMisaligned` + salt requires `getPool==0`  

7. **Mitigated (Novapex):** V2 migrate with 95% amount mins + permissionless retry + owner `rescueGraduated` (trust residual only)  

8. **Mitigated (Pons):** `getPool(predictedToken)==0` or `PoolAlreadyExists` before CREATE2 deploy + instant single-sided  

9. **Mitigated (Recurve):** `if (slot0.sqrtPriceX96 != 0) revert PoolTaken()` before `initialize`

---

## Hunt queue (OPEN only — use this going forward)

### Next (P0)

1. **#27 Merry Men**  
2. **#28 Flap**  
3. **#29 Clanker**  
4. **#30 Bankr**  
5. **#31 NOXA Fun** (if site live)  
6. **#14–18** PadQuiver, GoBolt, HoodTracker, launch.win, Loxley  
7. Optional full pass on **#1 hood.fun** if not already covered by user DMs  

### Do not re-hunt without new version/addrs

#2 Robinlaunch · #3 Robinfun · #4 RevShare · #5 Nock · #6 Slops · #7 Hood Tech · #8 RobinPad · #9 RoughLaunch · #10 Foragepad · #11 StockDotFun · #12 RobinLaunchpad · #13 MetaLaunch · #19 Openfair · #20 Novapex · #21 Pons · #22 Greenwood · #23 Primehod · #24 Leavehood · #25 Recurve · #26 HoodRich  

(Re-open only if new factory version, re-verified source, or major redeploy.)

---

## TARGET blocks — next OPEN pads (copy for session)

### 11. stock.fun

```
--- TARGET #11 ---
PROJECT_NAME   : stock.fun
WEBSITE        : https://stock.fun
CHAIN          : Robinhood Chain
RPC            : https://rpc.mainnet.chain.robinhood.com
CHAIN_ID       : 4663
EXPLORER       : https://robinhoodchain.blockscout.com
PRODUCT_TYPE   : launchpad
NOTES          : Stock-token paired launches; specialized for tokenized assets
RESEARCHER     : deviykee
HUNT_PRIORITY  : P0
```

### 12. RobinLaunchpad

```
--- TARGET #12 ---
PROJECT_NAME   : RobinLaunchpad
WEBSITE        : https://www.robinlaunchpad.com
CHAIN          : Robinhood Chain
RPC            : https://rpc.mainnet.chain.robinhood.com
CHAIN_ID       : 4663
EXPLORER       : https://robinhoodchain.blockscout.com
PRODUCT_TYPE   : launchpad
NOTES          : Launchpad + NFT/inscriptions hybrid
RESEARCHER     : deviykee
HUNT_PRIORITY  : P0
```

### 13. MetaLaunch

```
--- TARGET #13 ---
PROJECT_NAME   : MetaLaunch
WEBSITE        : https://metalaunch.fun
CHAIN          : Robinhood Chain
RPC            : https://rpc.mainnet.chain.robinhood.com
CHAIN_ID       : 4663
EXPLORER       : https://robinhoodchain.blockscout.com
KNOWN_ADDRS    : Launchpad_V5=0x49A3D384cd90A58815df31C1852dB4095B90c0De MetaLocker=0x49A955A2818069C4320b52602deF1706411bC0De
PRODUCT_TYPE   : launchpad
NOTES          : Direct V3 path; addrs from public RH launchpad registry
RESEARCHER     : deviykee
HUNT_PRIORITY  : P0
```

### 20. Novapex

```
--- TARGET #20 ---
PROJECT_NAME   : Novapex
WEBSITE        : https://www.novapex.fun
CHAIN          : Robinhood Chain
RPC            : https://rpc.mainnet.chain.robinhood.com
CHAIN_ID       : 4663
EXPLORER       : https://robinhoodchain.blockscout.com
PRODUCT_TYPE   : launchpad
NOTES          : Constant-product / graduation + locked liquidity
RESEARCHER     : deviykee
HUNT_PRIORITY  : P0
```

### 21. Pons

```
--- TARGET #21 ---
PROJECT_NAME   : Pons
WEBSITE        : https://pons.family/launchpad/create
CHAIN          : Robinhood Chain
RPC            : https://rpc.mainnet.chain.robinhood.com
CHAIN_ID       : 4663
EXPLORER       : https://robinhoodchain.blockscout.com
PRODUCT_TYPE   : launchpad
NOTES          : Explicit create path on site
RESEARCHER     : deviykee
HUNT_PRIORITY  : P0
```

### 22. The Greenwood

```
--- TARGET #22 ---
PROJECT_NAME   : The Greenwood
WEBSITE        : https://www.thegreenwood.fun
CHAIN          : Robinhood Chain
RPC            : https://rpc.mainnet.chain.robinhood.com
CHAIN_ID       : 4663
EXPLORER       : https://robinhoodchain.blockscout.com
KNOWN_ADDRS    : factory=0x81de990be508b95540b3c519417e7c0755b42977
PRODUCT_TYPE   : launchpad
NOTES          : Form embeds factory; optional vault lock
RESEARCHER     : deviykee
HUNT_PRIORITY  : P0
```

### 23. Primehod

```
--- TARGET #23 ---
PROJECT_NAME   : Primehod
WEBSITE        : https://primehod.lol
DOCS           : https://primehod.lol/docs
CHAIN          : Robinhood Chain
RPC            : https://rpc.mainnet.chain.robinhood.com
CHAIN_ID       : 4663
EXPLORER       : https://robinhoodchain.blockscout.com
KNOWN_ADDRS    : factory=0x57EfC7cE5250C96B0b0E7C554c9d9743A18b794f
PRODUCT_TYPE   : launchpad
NOTES          : Open-source factory claim; multi fee tiers
RESEARCHER     : deviykee
HUNT_PRIORITY  : P0
```

### 24. Leavehood

```
--- TARGET #24 ---
PROJECT_NAME   : Leavehood
WEBSITE        : https://leavehood.com
DOCS           : https://leavehood.com/docs
CHAIN          : Robinhood Chain
RPC            : https://rpc.mainnet.chain.robinhood.com
CHAIN_ID       : 4663
EXPLORER       : https://robinhoodchain.blockscout.com
KNOWN_ADDRS    : factory_proxy=0x2C81Cd8acF4886F4abAd332216b4444aE927FDb7 core_proxy=0x5090C9cd2228b0C4e6a83Ee44ab77Ce2e4cd89E3 lock=0x8F1C12050BB6aAA89f8fB5ddcA77c3EdF022CBF4
PRODUCT_TYPE   : launchpad
NOTES          : UUPS proxies + 100y lock claim
RESEARCHER     : deviykee
HUNT_PRIORITY  : P0
```

### 25. Recurve

```
--- TARGET #25 ---
PROJECT_NAME   : Recurve (ex-HoodPad)
WEBSITE        : https://recurve.fi
DOCS           : https://recurve.fi/docs
CHAIN          : Robinhood Chain
RPC            : https://rpc.mainnet.chain.robinhood.com
CHAIN_ID       : 4663
EXPLORER       : https://robinhoodchain.blockscout.com
KNOWN_ADDRS    : launch=0xd41a03a01369a734a5e22c3d6484b4040ae9acfd
PRODUCT_TYPE   : launchpad
NOTES          : Rebrand risk; direct single-sided V3
RESEARCHER     : deviykee
HUNT_PRIORITY  : P0
```

### 26–31. Short blocks

```
--- TARGET #26 ---
PROJECT_NAME   : HoodRich
WEBSITE        : https://robinpump.space
NOTES          : Multi-mode factories via /api/config
RESEARCHER     : deviykee

--- TARGET #27 ---
PROJECT_NAME   : Merry Men
WEBSITE        : https://www.merrymen.fun
KNOWN_ADDRS    : factory=0xfa4B952c15BC9d418ae4f552F7Fc76b4470596fE locker=0xd404C0fF8dE11841a4ff9CC4382eA5F6e4010751
RESEARCHER     : deviykee

--- TARGET #28 ---
PROJECT_NAME   : Flap
WEBSITE        : https://docs.flap.sh
NOTES          : Also flap.sh/robinhood
RESEARCHER     : deviykee

--- TARGET #29 ---
PROJECT_NAME   : Clanker
WEBSITE        : https://www.clanker.world
NOTES          : Direct configurable V4
RESEARCHER     : deviykee

--- TARGET #30 ---
PROJECT_NAME   : Bankr
WEBSITE        : https://bankr.bot
RESEARCHER     : deviykee

--- TARGET #31 ---
PROJECT_NAME   : NOXA Fun
WEBSITE        : https://noxa.fun
NOTES          : May be offline after fee drama; verify before deep work
RESEARCHER     : deviykee
```

---

## How to run

1. Pick an **OPEN** number from the queue  
2. Say: `hunt #11` or `hunt 11 and 12`  
3. Agent runs duke-web3-bug-hunting Steps 1→10 + evm-audit routing  
4. Deliver report under `reports/`, DM under `reports/dm-*.md`, update this table status  

**Archive:** previous list kept at `robinhood-chain-targets-2026-07-19.md` for history only — **do not use as working queue**.
