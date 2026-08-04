# Robinhood Chain targets — 2026-07-19 (**ARCHIVE**)

> **Superseded.** Use **[robinhood-chain-targets-2026-07-20.md](./robinhood-chain-targets-2026-07-20.md)** as the canonical working list.

Compiled for `/duke-web3-bug-hunting`.

**Filters applied:** non-Nigerian · new/early (chain mainnet ~2026-07-01) · launchpads first  
**Chain defaults (all targets):**

```
CHAIN          : Robinhood Chain
RPC            : https://rpc.mainnet.chain.robinhood.com
CHAIN_ID       : 4663
EXPLORER       : https://robinhoodchain.blockscout.com
RESEARCHER     : @dukedotsol
```

**Before any hunt:** confirm website resolves, find factory/migrator on Blockscout, fill `KNOWN_ADDRS`. Do not invent addresses.

---

## P0 shortlist — launchpads first (hunt these)

Use one `--- TARGET ---` block per session. Say **hunt this** after pasting.

### 1. LaunchHood / hood.fun

```
--- TARGET #1 ---
PROJECT_NAME   : LaunchHood / hood.fun
X_HANDLE       : unknown
WEBSITE        : https://hood.fun
DOCS           : unknown
CHAIN          : Robinhood Chain
RPC            : https://rpc.mainnet.chain.robinhood.com
CHAIN_ID       : 4663
EXPLORER       : https://robinhoodchain.blockscout.com
KNOWN_ADDRS    : none
PRODUCT_TYPE   : launchpad
BOUNTY/CONTEST : none / discretionary
NOTES          : Flagship RH launchpad; bonding curve + graduation surface. Alt URL mentioned: https://launchhood.com. Verify which is canonical.
RESEARCHER     : @dukedotsol
COUNTRY_ORIGIN : unknown
ORIGIN_CONF    : low
HUNT_PRIORITY  : P0
WHY_PRIORITY   : launchpad = high bug density; new chain; likely factory/migrator/locker
```

### 2. Robinlaunch

```
--- TARGET #2 ---
PROJECT_NAME   : Robinlaunch
X_HANDLE       : unknown
WEBSITE        : https://robinlaunch.fun
DOCS           : unknown
CHAIN          : Robinhood Chain
RPC            : https://rpc.mainnet.chain.robinhood.com
CHAIN_ID       : 4663
EXPLORER       : https://robinhoodchain.blockscout.com
KNOWN_ADDRS    : none
PRODUCT_TYPE   : launchpad
BOUNTY/CONTEST : none / discretionary
NOTES          : New RH meme launchpad
RESEARCHER     : @dukedotsol
COUNTRY_ORIGIN : unknown
ORIGIN_CONF    : low
HUNT_PRIORITY  : P0
WHY_PRIORITY   : launchpad = high bug density
```

### 3. Robinfun

```
--- TARGET #3 ---
PROJECT_NAME   : Robinfun
X_HANDLE       : unknown
WEBSITE        : https://robinfun.live
DOCS           : unknown
CHAIN          : Robinhood Chain
RPC            : https://rpc.mainnet.chain.robinhood.com
CHAIN_ID       : 4663
EXPLORER       : https://robinhoodchain.blockscout.com
KNOWN_ADDRS    : none
PRODUCT_TYPE   : launchpad
BOUNTY/CONTEST : none / discretionary
NOTES          : New RH launchpad
RESEARCHER     : @dukedotsol
COUNTRY_ORIGIN : unknown
ORIGIN_CONF    : low
HUNT_PRIORITY  : P0
WHY_PRIORITY   : launchpad = high bug density
```

### 4. RevShare

```
--- TARGET #4 ---
PROJECT_NAME   : RevShare
X_HANDLE       : unknown
WEBSITE        : https://revshare.dev
DOCS           : unknown
CHAIN          : Robinhood Chain
RPC            : https://rpc.mainnet.chain.robinhood.com
CHAIN_ID       : 4663
EXPLORER       : https://robinhoodchain.blockscout.com
KNOWN_ADDRS    : none
PRODUCT_TYPE   : launchpad
BOUNTY/CONTEST : none / discretionary
NOTES          : App may be app.revshare.ltd — confirm canonical domain before connecting anything
RESEARCHER     : @dukedotsol
COUNTRY_ORIGIN : unknown
ORIGIN_CONF    : low
HUNT_PRIORITY  : P0
WHY_PRIORITY   : launchpad / fee-split surface
```

### 5. Nock Terminal (launch)

```
--- TARGET #5 ---
PROJECT_NAME   : Nock Terminal
X_HANDLE       : unknown
WEBSITE        : https://nockterminal.com/launch
DOCS           : unknown
CHAIN          : Robinhood Chain
RPC            : https://rpc.mainnet.chain.robinhood.com
CHAIN_ID       : 4663
EXPLORER       : https://robinhoodchain.blockscout.com
KNOWN_ADDRS    : none
PRODUCT_TYPE   : launchpad
BOUNTY/CONTEST : none / discretionary
NOTES          : Launch + terminal/screener; factory surface if they host creates
RESEARCHER     : @dukedotsol
COUNTRY_ORIGIN : unknown
ORIGIN_CONF    : low
HUNT_PRIORITY  : P0
WHY_PRIORITY   : launchpad path + high activity comparisons
```

### 6. Robin the Hood

```
--- TARGET #6 ---
PROJECT_NAME   : Robin the Hood
X_HANDLE       : unknown
WEBSITE        : https://robinthehood.fun
DOCS           : unknown
CHAIN          : Robinhood Chain
RPC            : https://rpc.mainnet.chain.robinhood.com
CHAIN_ID       : 4663
EXPLORER       : https://robinhoodchain.blockscout.com
KNOWN_ADDRS    : none
PRODUCT_TYPE   : launchpad
BOUNTY/CONTEST : none / discretionary
NOTES          : New RH launchpad
RESEARCHER     : @dukedotsol
COUNTRY_ORIGIN : unknown
ORIGIN_CONF    : low
HUNT_PRIORITY  : P0
WHY_PRIORITY   : launchpad = high bug density
```

### 7. Hood Tech

```
--- TARGET #7 ---
PROJECT_NAME   : Hood Tech
X_HANDLE       : unknown
WEBSITE        : https://hood.tech
DOCS           : unknown
CHAIN          : Robinhood Chain
RPC            : https://rpc.mainnet.chain.robinhood.com
CHAIN_ID       : 4663
EXPLORER       : https://robinhoodchain.blockscout.com
KNOWN_ADDRS    : none
PRODUCT_TYPE   : launchpad
BOUNTY/CONTEST : none / discretionary
NOTES          : New RH launchpad / hood-branded tool
RESEARCHER     : @dukedotsol
COUNTRY_ORIGIN : unknown
ORIGIN_CONF    : low
HUNT_PRIORITY  : P0
WHY_PRIORITY   : launchpad = high bug density
```

### 8. RobinPad

```
--- TARGET #8 ---
PROJECT_NAME   : RobinPad
X_HANDLE       : unknown
WEBSITE        : https://www.robinpad.fi
DOCS           : unknown
CHAIN          : Robinhood Chain
RPC            : https://rpc.mainnet.chain.robinhood.com
CHAIN_ID       : 4663
EXPLORER       : https://robinhoodchain.blockscout.com
KNOWN_ADDRS    : none
PRODUCT_TYPE   : launchpad
BOUNTY/CONTEST : none / discretionary
NOTES          : Check docs/whitepaper for factory addrs
RESEARCHER     : @dukedotsol
COUNTRY_ORIGIN : unknown
ORIGIN_CONF    : low
HUNT_PRIORITY  : P0
WHY_PRIORITY   : launchpad = high bug density
```

### 9. Inkfeather / RoughLaunch

```
--- TARGET #9 ---
PROJECT_NAME   : Inkfeather / RoughLaunch
X_HANDLE       : unknown
WEBSITE        : https://inkfeather.io
DOCS           : unknown
CHAIN          : Robinhood Chain
RPC            : https://rpc.mainnet.chain.robinhood.com
CHAIN_ID       : 4663
EXPLORER       : https://robinhoodchain.blockscout.com
KNOWN_ADDRS    : none
PRODUCT_TYPE   : launchpad
BOUNTY/CONTEST : none / discretionary
NOTES          : RoughLaunch branding on RH
RESEARCHER     : @dukedotsol
COUNTRY_ORIGIN : unknown
ORIGIN_CONF    : low
HUNT_PRIORITY  : P0
WHY_PRIORITY   : launchpad = high bug density
```

### 10. Foragepad / The Furnace

```
--- TARGET #10 ---
PROJECT_NAME   : Foragepad / The Furnace
X_HANDLE       : unknown
WEBSITE        : https://foragepad.com
DOCS           : https://foragepad.com/docs
CHAIN          : Robinhood Chain
RPC            : https://rpc.mainnet.chain.robinhood.com
CHAIN_ID       : 4663
EXPLORER       : https://robinhoodchain.blockscout.com
KNOWN_ADDRS    : none
PRODUCT_TYPE   : launchpad
BOUNTY/CONTEST : none / discretionary
NOTES          : Has docs — good for Step 2/3 source + addrs
RESEARCHER     : @dukedotsol
COUNTRY_ORIGIN : unknown
ORIGIN_CONF    : low
HUNT_PRIORITY  : P0
WHY_PRIORITY   : launchpad + docs (faster verified-source path)
```

### 11. stock.fun

```
--- TARGET #11 ---
PROJECT_NAME   : stock.fun
X_HANDLE       : unknown
WEBSITE        : https://stock.fun
DOCS           : unknown
CHAIN          : Robinhood Chain
RPC            : https://rpc.mainnet.chain.robinhood.com
CHAIN_ID       : 4663
EXPLORER       : https://robinhoodchain.blockscout.com
KNOWN_ADDRS    : none
PRODUCT_TYPE   : launchpad
BOUNTY/CONTEST : none / discretionary
NOTES          : Stock/meme launch meta on RH; alt stockdotfun.com/docs
RESEARCHER     : @dukedotsol
COUNTRY_ORIGIN : unknown
ORIGIN_CONF    : low
HUNT_PRIORITY  : P0
WHY_PRIORITY   : launchpad = high bug density
```

### 12. RobinLaunchpad

```
--- TARGET #12 ---
PROJECT_NAME   : RobinLaunchpad
X_HANDLE       : unknown
WEBSITE        : https://www.robinlaunchpad.com
DOCS           : unknown
CHAIN          : Robinhood Chain
RPC            : https://rpc.mainnet.chain.robinhood.com
CHAIN_ID       : 4663
EXPLORER       : https://robinhoodchain.blockscout.com
KNOWN_ADDRS    : none
PRODUCT_TYPE   : launchpad
BOUNTY/CONTEST : none / discretionary
NOTES          : NFT/inscription + launch claims in source list
RESEARCHER     : @dukedotsol
COUNTRY_ORIGIN : unknown
ORIGIN_CONF    : low
HUNT_PRIORITY  : P0
WHY_PRIORITY   : launchpad = high bug density
```

### 13. MetaLaunch

```
--- TARGET #13 ---
PROJECT_NAME   : MetaLaunch
X_HANDLE       : unknown
WEBSITE        : https://metalaunch.fun
DOCS           : unknown
CHAIN          : Robinhood Chain
RPC            : https://rpc.mainnet.chain.robinhood.com
CHAIN_ID       : 4663
EXPLORER       : https://robinhoodchain.blockscout.com
KNOWN_ADDRS    : none
PRODUCT_TYPE   : launchpad
BOUNTY/CONTEST : none / discretionary
NOTES          : New RH launchpad
RESEARCHER     : @dukedotsol
COUNTRY_ORIGIN : unknown
ORIGIN_CONF    : low
HUNT_PRIORITY  : P0
WHY_PRIORITY   : launchpad = high bug density
```

### 14. PadQuiver

```
--- TARGET #14 ---
PROJECT_NAME   : PadQuiver
X_HANDLE       : unknown
WEBSITE        : https://padquiver.com
DOCS           : unknown
CHAIN          : Robinhood Chain
RPC            : https://rpc.mainnet.chain.robinhood.com
CHAIN_ID       : 4663
EXPLORER       : https://robinhoodchain.blockscout.com
KNOWN_ADDRS    : none
PRODUCT_TYPE   : launchpad
BOUNTY/CONTEST : none / discretionary
NOTES          : New RH launchpad
RESEARCHER     : @dukedotsol
COUNTRY_ORIGIN : unknown
ORIGIN_CONF    : low
HUNT_PRIORITY  : P0
WHY_PRIORITY   : launchpad = high bug density
```

### 15. GoBolt

```
--- TARGET #15 ---
PROJECT_NAME   : GoBolt
X_HANDLE       : unknown
WEBSITE        : https://gobolt.fun
DOCS           : unknown
CHAIN          : Robinhood Chain
RPC            : https://rpc.mainnet.chain.robinhood.com
CHAIN_ID       : 4663
EXPLORER       : https://robinhoodchain.blockscout.com
KNOWN_ADDRS    : none
PRODUCT_TYPE   : launchpad
BOUNTY/CONTEST : none / discretionary
NOTES          : New RH launchpad
RESEARCHER     : @dukedotsol
COUNTRY_ORIGIN : unknown
ORIGIN_CONF    : low
HUNT_PRIORITY  : P0
WHY_PRIORITY   : launchpad = high bug density
```

### 16. HoodTracker (launch)

```
--- TARGET #16 ---
PROJECT_NAME   : HoodTracker
X_HANDLE       : unknown
WEBSITE        : https://www.hoodtracker.com/launch
DOCS           : unknown
CHAIN          : Robinhood Chain
RPC            : https://rpc.mainnet.chain.robinhood.com
CHAIN_ID       : 4663
EXPLORER       : https://robinhoodchain.blockscout.com
KNOWN_ADDRS    : none
PRODUCT_TYPE   : launchpad
BOUNTY/CONTEST : none / discretionary
NOTES          : Tracker + launch path — confirm if they own factory or only UI
RESEARCHER     : @dukedotsol
COUNTRY_ORIGIN : unknown
ORIGIN_CONF    : low
HUNT_PRIORITY  : P1
WHY_PRIORITY   : may be UI-only; verify contracts before deep hunt
```

### 17. launch.win

```
--- TARGET #17 ---
PROJECT_NAME   : launch.win
X_HANDLE       : unknown
WEBSITE        : https://launchwin.app
DOCS           : unknown
CHAIN          : Robinhood Chain
RPC            : https://rpc.mainnet.chain.robinhood.com
CHAIN_ID       : 4663
EXPLORER       : https://robinhoodchain.blockscout.com
KNOWN_ADDRS    : none
PRODUCT_TYPE   : launchpad
BOUNTY/CONTEST : none / discretionary
NOTES          : New RH launchpad
RESEARCHER     : @dukedotsol
COUNTRY_ORIGIN : unknown
ORIGIN_CONF    : low
HUNT_PRIORITY  : P0
WHY_PRIORITY   : launchpad = high bug density
```

### 18. Loxley

```
--- TARGET #18 ---
PROJECT_NAME   : Loxley
X_HANDLE       : unknown
WEBSITE        : https://loxley.app
DOCS           : unknown
CHAIN          : Robinhood Chain
RPC            : https://rpc.mainnet.chain.robinhood.com
CHAIN_ID       : 4663
EXPLORER       : https://robinhoodchain.blockscout.com
KNOWN_ADDRS    : none
PRODUCT_TYPE   : launchpad
BOUNTY/CONTEST : none / discretionary
NOTES          : New RH launchpad
RESEARCHER     : @dukedotsol
COUNTRY_ORIGIN : unknown
ORIGIN_CONF    : low
HUNT_PRIORITY  : P0
WHY_PRIORITY   : launchpad = high bug density
```

### 19. Openfair

```
--- TARGET #19 ---
PROJECT_NAME   : Openfair
X_HANDLE       : unknown
WEBSITE        : https://openfair.app
DOCS           : unknown
CHAIN          : Robinhood Chain
RPC            : https://rpc.mainnet.chain.robinhood.com
CHAIN_ID       : 4663
EXPLORER       : https://robinhoodchain.blockscout.com
KNOWN_ADDRS    : none
PRODUCT_TYPE   : launchpad
BOUNTY/CONTEST : none / discretionary
NOTES          : Fair-launch style surface
RESEARCHER     : @dukedotsol
COUNTRY_ORIGIN : unknown
ORIGIN_CONF    : low
HUNT_PRIORITY  : P0
WHY_PRIORITY   : launchpad = high bug density
```

### 20. Novapex

```
--- TARGET #20 ---
PROJECT_NAME   : Novapex
X_HANDLE       : unknown
WEBSITE        : https://www.novapex.fun
DOCS           : unknown
CHAIN          : Robinhood Chain
RPC            : https://rpc.mainnet.chain.robinhood.com
CHAIN_ID       : 4663
EXPLORER       : https://robinhoodchain.blockscout.com
KNOWN_ADDRS    : none
PRODUCT_TYPE   : launchpad
BOUNTY/CONTEST : none / discretionary
NOTES          : Check /docs if present
RESEARCHER     : @dukedotsol
COUNTRY_ORIGIN : unknown
ORIGIN_CONF    : low
HUNT_PRIORITY  : P0
WHY_PRIORITY   : launchpad = high bug density
```

### 21. Pons

```
--- TARGET #21 ---
PROJECT_NAME   : Pons
X_HANDLE       : unknown
WEBSITE        : https://pons.family/launchpad/create
DOCS           : unknown
CHAIN          : Robinhood Chain
RPC            : https://rpc.mainnet.chain.robinhood.com
CHAIN_ID       : 4663
EXPLORER       : https://robinhoodchain.blockscout.com
KNOWN_ADDRS    : none
PRODUCT_TYPE   : launchpad
BOUNTY/CONTEST : none / discretionary
NOTES          : Create flow at /launchpad/create — good for grepping frontend for factory
RESEARCHER     : @dukedotsol
COUNTRY_ORIGIN : unknown
ORIGIN_CONF    : low
HUNT_PRIORITY  : P0
WHY_PRIORITY   : launchpad create UX implies factory
```

### 22. The Greenwood

```
--- TARGET #22 ---
PROJECT_NAME   : The Greenwood
X_HANDLE       : unknown
WEBSITE        : https://www.thegreenwood.fun/deploy.html
DOCS           : unknown
CHAIN          : Robinhood Chain
RPC            : https://rpc.mainnet.chain.robinhood.com
CHAIN_ID       : 4663
EXPLORER       : https://robinhoodchain.blockscout.com
KNOWN_ADDRS    : none
PRODUCT_TYPE   : launchpad
BOUNTY/CONTEST : none / discretionary
NOTES          : Explicit deploy page
RESEARCHER     : @dukedotsol
COUNTRY_ORIGIN : unknown
ORIGIN_CONF    : low
HUNT_PRIORITY  : P0
WHY_PRIORITY   : launchpad = high bug density
```

### 23. Primehod

```
--- TARGET #23 ---
PROJECT_NAME   : Primehod
X_HANDLE       : unknown
WEBSITE        : https://primehod.lol
DOCS           : unknown
CHAIN          : Robinhood Chain
RPC            : https://rpc.mainnet.chain.robinhood.com
CHAIN_ID       : 4663
EXPLORER       : https://robinhoodchain.blockscout.com
KNOWN_ADDRS    : none
PRODUCT_TYPE   : launchpad
BOUNTY/CONTEST : none / discretionary
NOTES          : Check /docs
RESEARCHER     : @dukedotsol
COUNTRY_ORIGIN : unknown
ORIGIN_CONF    : low
HUNT_PRIORITY  : P0
WHY_PRIORITY   : launchpad = high bug density
```

### 24. Leavehood

```
--- TARGET #24 ---
PROJECT_NAME   : Leavehood
X_HANDLE       : unknown
WEBSITE        : https://leavehood.com
DOCS           : unknown
CHAIN          : Robinhood Chain
RPC            : https://rpc.mainnet.chain.robinhood.com
CHAIN_ID       : 4663
EXPLORER       : https://robinhoodchain.blockscout.com
KNOWN_ADDRS    : none
PRODUCT_TYPE   : launchpad
BOUNTY/CONTEST : none / discretionary
NOTES          : Check /docs
RESEARCHER     : @dukedotsol
COUNTRY_ORIGIN : unknown
ORIGIN_CONF    : low
HUNT_PRIORITY  : P0
WHY_PRIORITY   : launchpad = high bug density
```

### 25. Recurve (formerly HoodPad)

```
--- TARGET #25 ---
PROJECT_NAME   : Recurve (ex-HoodPad)
X_HANDLE       : unknown
WEBSITE        : https://recurve.fi
DOCS           : unknown
CHAIN          : Robinhood Chain
RPC            : https://rpc.mainnet.chain.robinhood.com
CHAIN_ID       : 4663
EXPLORER       : https://robinhoodchain.blockscout.com
KNOWN_ADDRS    : none
PRODUCT_TYPE   : launchpad
BOUNTY/CONTEST : none / discretionary
NOTES          : Rebrand — check if old HoodPad contracts still live / migrated
RESEARCHER     : @dukedotsol
COUNTRY_ORIGIN : unknown
ORIGIN_CONF    : low
HUNT_PRIORITY  : P0
WHY_PRIORITY   : launchpad rebrand often leaves migration bugs
```

### 26. HoodRich / robinpump

```
--- TARGET #26 ---
PROJECT_NAME   : HoodRich
X_HANDLE       : unknown
WEBSITE        : https://robinpump.space/create
DOCS           : unknown
CHAIN          : Robinhood Chain
RPC            : https://rpc.mainnet.chain.robinhood.com
CHAIN_ID       : 4663
EXPLORER       : https://robinhoodchain.blockscout.com
KNOWN_ADDRS    : none
PRODUCT_TYPE   : launchpad
BOUNTY/CONTEST : none / discretionary
NOTES          : Create path on robinpump.space — confirm branding link
RESEARCHER     : @dukedotsol
COUNTRY_ORIGIN : unknown
ORIGIN_CONF    : low
HUNT_PRIORITY  : P0
WHY_PRIORITY   : pump-style launchpad
```

### 27. Merry Men

```
--- TARGET #27 ---
PROJECT_NAME   : Merry Men
X_HANDLE       : unknown
WEBSITE        : https://www.merrymen.fun
DOCS           : unknown
CHAIN          : Robinhood Chain
RPC            : https://rpc.mainnet.chain.robinhood.com
CHAIN_ID       : 4663
EXPLORER       : https://robinhoodchain.blockscout.com
KNOWN_ADDRS    : none
PRODUCT_TYPE   : launchpad
BOUNTY/CONTEST : none / discretionary
NOTES          : New RH launchpad
RESEARCHER     : @dukedotsol
COUNTRY_ORIGIN : unknown
ORIGIN_CONF    : low
HUNT_PRIORITY  : P0
WHY_PRIORITY   : launchpad = high bug density
```

### 28. Flap

```
--- TARGET #28 ---
PROJECT_NAME   : Flap
X_HANDLE       : unknown
WEBSITE        : https://docs.flap.sh
DOCS           : https://docs.flap.sh
CHAIN          : Robinhood Chain
RPC            : https://rpc.mainnet.chain.robinhood.com
CHAIN_ID       : 4663
EXPLORER       : https://robinhoodchain.blockscout.com
KNOWN_ADDRS    : none
PRODUCT_TYPE   : launchpad
BOUNTY/CONTEST : none / discretionary
NOTES          : Multi-chain? Confirm RH-specific contracts vs wrapper
RESEARCHER     : @dukedotsol
COUNTRY_ORIGIN : unknown
ORIGIN_CONF    : low
HUNT_PRIORITY  : P1
WHY_PRIORITY   : may be established elsewhere — hunt only if RH surface is new
```

### 29. Clanker

```
--- TARGET #29 ---
PROJECT_NAME   : Clanker
X_HANDLE       : unknown
WEBSITE        : https://www.clanker.world
DOCS           : unknown
CHAIN          : Robinhood Chain
RPC            : https://rpc.mainnet.chain.robinhood.com
CHAIN_ID       : 4663
EXPLORER       : https://robinhoodchain.blockscout.com
KNOWN_ADDRS    : none
PRODUCT_TYPE   : launchpad
BOUNTY/CONTEST : none / discretionary
NOTES          : Known brand elsewhere — only hunt if NEW RH deploy is distinct
RESEARCHER     : @dukedotsol
COUNTRY_ORIGIN : unknown
ORIGIN_CONF    : low
HUNT_PRIORITY  : P1
WHY_PRIORITY   : may be established on other chains
```

### 30. Bankr

```
--- TARGET #30 ---
PROJECT_NAME   : Bankr
X_HANDLE       : unknown
WEBSITE        : https://bankr.bot
DOCS           : https://docs.bankr.bot
CHAIN          : Robinhood Chain
RPC            : https://rpc.mainnet.chain.robinhood.com
CHAIN_ID       : 4663
EXPLORER       : https://robinhoodchain.blockscout.com
KNOWN_ADDRS    : none
PRODUCT_TYPE   : launchpad
BOUNTY/CONTEST : none / discretionary
NOTES          : Bot/docs surface — confirm on-chain factory on 4663
RESEARCHER     : @dukedotsol
COUNTRY_ORIGIN : unknown
ORIGIN_CONF    : low
HUNT_PRIORITY  : P1
WHY_PRIORITY   : launch-related; verify custody
```

### 31. NOXA Fun

```
--- TARGET #31 ---
PROJECT_NAME   : NOXA Fun
X_HANDLE       : unknown
WEBSITE        : https://noxa.fun
DOCS           : unknown
CHAIN          : Robinhood Chain
RPC            : https://rpc.mainnet.chain.robinhood.com
CHAIN_ID       : 4663
EXPLORER       : https://robinhoodchain.blockscout.com
KNOWN_ADDRS    : none
PRODUCT_TYPE   : launchpad
BOUNTY/CONTEST : none / discretionary
NOTES          : DefiLlama-prominent per source list
RESEARCHER     : @dukedotsol
COUNTRY_ORIGIN : unknown
ORIGIN_CONF    : low
HUNT_PRIORITY  : P0
WHY_PRIORITY   : launchpad + listed activity
```

### 32–35. Thin presence (enrich before full hunt)

| # | Name | Notes | Priority |
|---|------|-------|----------|
| 32 | ArrowPad | DefiLlama; weak public site | P2 until site/addrs |
| 33 | Sentry | DefiLlama-listed | P2 until site/addrs |
| 34 | Prynt | DefiLlama-listed | P2 until site/addrs |
| 35 | DYOR Fun | Factory on Blockscout claim | P1 — find factory via explorer |

### 36. HoodPad variants / mirrors — TREAT AS SCAM RISK

- hoodfun.cc, pad.hoodscan.ai, other .fun mirrors
- Do **not** hunt until canonical domain proven; phishing risk
- Skill rule: sketchy TLD / brand-impersonation = assume phishing

---

## Other early dApps (after launchpads)

| # | Project | Website | Type | Priority note |
|---|---------|---------|------|---------------|
| 46 | Arcus | https://arcus.xyz | perps/DEX | P1 if new RH-only |
| 47 | Lighter | https://lighter.xyz | perps | P2 if established elsewhere |
| 48 | Rialto | search | PropAMM | P1 once site confirmed |
| 49 | Virtuals Protocol | https://virtuals.io | AI agents | P2 if multi-chain mature |
| 50 | Arrakis | https://arrakis.finance | liquidity | P2 established |
| 51 | StalkChain | https://stalkchain.com | analytics | skip if no custody |
| 52 | HoodRuns | https://hoodruns.com | tracker | skip if no custody |
| 53 | Nock Terminal | https://nockterminal.com | terminal | see #5 launch |
| 54 | RobinFlow | unknown | distribution | P0 if claim/vest contracts |
| 55 | Native | https://native.org | execution | P1 if new RH surface |

---

## Hunt queue (recommended order)

1. **hood.fun / LaunchHood** — skill’s own example target  
2. **foragepad.com** — has docs  
3. **pons.family** — explicit create path  
4. **recurve.fi** — rebrand/migration bugs  
5. **noxa.fun** — DefiLlama activity  
6. **robinlaunch.fun / robinfun.live / robinthehood.fun** — pure new pads  
7. **stock.fun / gobolt.fun / metalaunch.fun**  
8. Rest of P0 list as time allows  
9. Skip mirrors (#36) until proven  
10. Non-launchpads only after launchpad pass  

---

## How to run a hunt in this session

1. Pick a number from the queue  
2. Say: `hunt #1` or paste the TARGET block  
3. Agent runs `/duke-web3-bug-hunting` Steps 1→10  
4. Verification = fork / eth_call **only** — never mainnet exploit  

**Reminder:** source list may contain dead/phishing domains. Step 1 gate (RPC + real contracts) kills vaporware before deep work.
