# Hood Tech (#7) - hunt notes (no High)

**Researcher:** deviykee  
**Date:** 2026-07-20  
**Status:** Live factory + positions **verified** (Sourcify/Blockscout). Source reviewed. Classic V3 pool squat is **mitigated** by explicit `getPool == 0` check. No permissionless High. No mainnet exploit attempted.

---

## What this means in plain language (read this first)

Hood Tech is a Telegram + web (HoodFUN) launcher on Robinhood Chain. The **real** on-chain product that fun.hood.tech talks to is a **one-shot Uniswap V3** launcher:

1. Deploy a fixed 1B supply ERC-20  
2. Create a **token/WETH 1%** V3 pool and set the starting price (1 ETH market cap)  
3. Put the **entire** supply into a single-sided LP position  
4. Lock that LP NFT forever in `HoodTechPositions`  
5. Optional same-tx creator buy with leftover ETH  

Unlike Robinlaunch/Openfair, this design **does not** use `createAndInitializePoolIfNecessary` with zero mins and hope for the best. It **refuses to launch** if the pool already exists. So the "stranger pre-opens the pool at a fake price and the pad dumps the raise into it" High **does not apply** here (and there is no bonding-curve raise to dump).

The marketing site still lists **placeholder Hardhat-style addresses with no bytecode**. Users who verify only that registry can be misled. Use the live addresses from the web app / explorer instead.

---

## INTAKE (known only)

```
PROJECT_NAME   : Hood Tech / HoodFUN
X_HANDLE       : @HoodTechBot
WEBSITE        : https://www.hood.tech  (web board: https://fun.hood.tech)
DOCS           : https://www.hood.tech/underthehood/
CHAIN          : Robinhood Chain
RPC            : https://rpc.mainnet.chain.robinhood.com
CHAIN_ID       : 4663
EXPLORER       : https://robinhoodchain.blockscout.com
KNOWN_ADDRS    :
  factory_live=0x3345a91bF13eBDdab02cFF80B70316c1A848ffD0
  config=0x0a049edC3D44BD47e8BB047852526A067f0E8E62
  positions=0x15FA411D1E104d8652E2A888a363562ab9b78433
  swap_router=0xCaf681a66D020601342297493863E78C959E5cb2
  quoter=0x33e885ED0eC9bF04ECfB19341582AadCb4C8A9E7
  weth=0x0Bd7D308f8E1639FAb988df18A8011f41EAcAD73
  univ3_factory=0x1f7d7550B1b028f7571E69A784071F0205FD2EfA
  owner=0x504Bd001090e9D94a722E7996075e80870D1cb71
  hot_token=0x56cb1A3e464619393B08632c3aa3cF654235FB18
PRODUCT_TYPE   : launchpad (instant V3 single-sided + permanent LP locker)
BOUNTY/CONTEST : none / discretionary
NOTES          : Marketing registry lists empty Hardhat defaults (0xa513…, 0x2279…, 0x0165…)
RESEARCHER     : deviykee
```

Live reads: `totalLaunches = 13`, `launchFee = 0.0005 ETH`, `paused = false` (as of hunt).

---

## Architecture

| Role | Address | Verified |
|------|---------|----------|
| HoodTechFactory | `0x3345a91b…ffD0` | yes |
| HoodTechConfig | `0x0a049edC…8E62` | yes |
| HoodTechPositions | `0x15FA411D…8433` | yes |
| Uniswap V3 factory (canonical) | `0x1f7d7550…2EfA` | infra |
| Swap router (app) | `0xCaf681a6…5cb2` | used by app |
| WETH | `0x0Bd7D308…AD73` | infra |

**Marketing placeholders (NO code on 4663):**

- TeleHoodFactory `0xa513E6E4…C853`  
- TeleHoodPositions `0x2279B7A0…eBe6`  
- TeleHoodConfig `0x0165878A…Eb8F`  

These match common local Hardhat deployment addresses. **Do not use them.**

---

## Why V3 pool squat is dead here

From verified `HoodTechFactory._createPool`:

```solidity
require(
    v3Factory.getPool(token, address(weth), HoodTechConstants.POOL_FEE) == address(0),
    "Pool pre-exists"
);
pool = v3Factory.createPool(token, address(weth), HoodTechConstants.POOL_FEE);
// ... compute intended sqrtPrice ...
IUniswapV3Pool(pool).initialize(sqrtPriceX96);
```

- No `createAndInitializePoolIfNecessary` path that reuses a hostile pool  
- Hostile pre-create causes **launch abort**, not silent wrong-price liquidity  
- Mint uses `amount0Min/amount1Min = 0` **after** same-tx create+init (comment is honest for that model)

Liquidity: entire token supply, **zero ETH** seeded. Trading opens immediately. No graduation migration of a pad-held raise.

---

## Residual issues (honest severity)

| ID | Severity | Title |
|----|----------|--------|
| HT-1 | Info / Trust | Marketing registry publishes empty placeholder factory/locker addresses |
| HT-2 | Medium (grief) | Predictable token address (CREATE nonce or CREATE2 salt) can be pre-pooled so `createLaunch` reverts `"Pool pre-exists"` | Attacker spends gas; **no fund theft** of a raise (single-sided, launch aborts before fee is meaningfully "stuck" beyond gas) |
| HT-3 | Info | Docs mix "bonding → graduate" marketing with pure instant-V3 code; UI milestone only |
| HT-4 | Trust | Owner can pause, set launch fee (capped 0.01 ETH), set treasury; `setPositions` once |
| HT-5 | Low / Info | Dev buy uses `amountOutMinimum: 0` (same tx as pool create; limited sandwich surface) |
| HT-6 | - | Permissionless High theft of user funds | **Not found** |

Fee path in `HoodTechPositions`: anyone may `collectFees`; 50/50 split; creator pulls via `claim`; treasury push with pull fallback if ETH push fails. No LP NFT withdrawal.

---

## Attack questions checklist

| Question | Result |
|----------|--------|
| Pad holds raise then migrates at unchecked price? | No raise held; instant single-sided |
| V3 squat via createAndInitializePoolIfNecessary? | Mitigated by getPool==0 + create+init |
| V2 pair pollution freeze? | No V2 bonding path on live factory |
| Missing onlyOwner on critical fund moves? | Positions mint factory-only; no LP withdraw |
| Placeholder vs live addresses? | Marketing mismatch (HT-1) |

---

## Sources on disk

- `hunts/hoodtech/src/` (Sourcify sources)  
- `hunts/hoodtech/Factory.sol`, `Positions.sol`, `Config.sol`  
- Live config embedded in `fun.hood.tech/app.js` (`CFG.factory` etc.)

---

## Optional DM

Share HT-1 with the team so they replace Hardhat placeholders on hood.tech with live addresses. No High disclosure packet.

---

deviykee
