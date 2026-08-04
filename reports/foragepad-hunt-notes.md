# Foragepad / The Furnace (#10) - hunt notes (no High proven)

**Researcher:** deviykee  
**Date:** 2026-07-20  
**Status:** Live factory + migrator + LP locker + curves mapped from API and eth_call. **All custom contracts unverified.** Bonding-curve → Uniswap V3 graduation surface is real. No permissionless High proven without source/fork PoC. No mainnet exploit attempted.

---

## What this means in plain language (read this first)

**Foragepad** (branded **The Furnace**) is a Robinhood Chain launchpad with:

- **Bonding-curve** launches that raise ETH on a curve, then **graduate** near a target (~4 ETH on a live sample curve) into **Uniswap V3**  
- **Instant** pool launches (no curve)  
- Protocol fee **50 bps** (`PLATFORM_FEE_BPS = 50`), with a $FURNACE buyback/burn story  
- After graduation, LP NFT is supposed to sit in **FurnaceLPLocker** with **no withdraw / decreaseLiquidity** in bytecode strings

The dangerous class here is the same one that paid on Robinlaunch/Openfair: if migration **creates or reuses a V3 pool without checking price** and mints LP with **zero min amounts**, a stranger can pre-set a fake price and the pad pours the **curve raise** into it.

Right now:

- Factory and migrator are **unverified**  
- Migrator bytecode uses **`createPool`** (not `createAndInitializePoolIfNecessary`) and has **no `getPool` / `slot0`** hits in a simple selector scan  
- `migrateToUniswap` on a live non-graduated curve reverts (custom error) for attacker, migrator, and factory alike  
- UI sometimes says “awaiting first launch” while the public launches API already lists several tokens - treat UI as lagging

So the **surface is High-class**, but **severity is not claimable** until the migrate path is proven end-to-end on a fork.

---

## INTAKE (known only)

```
PROJECT_NAME   : Foragepad / The Furnace
X_HANDLE       : @Foragepad
WEBSITE        : https://foragepad.com  (also www)
DOCS           : https://foragepad.com/docs
CHAIN          : Robinhood Chain
RPC            : https://rpc.mainnet.chain.robinhood.com
CHAIN_ID       : 4663
EXPLORER       : https://robinhoodchain.blockscout.com
KNOWN_ADDRS    :
  factory=0x18999cAFeB211fbc66ADe096C4B72AC56C290818
  graduation_migrator=0x1C74FdffEF68b4E5ADf755895F63a0465725Ebb7
  lp_locker=0xCa07e6a35Ac02346b3d535beDEf13EeDc5420d3b
  owner_treasury=0x367fC81A2205587DF2ae6F9BA0af28EF75A88b07
  sample_curve=0x6DF00b83C30DF1A8090946A0534015C8106fDb97
  sample_curve_token=0xb6365c27b7ff05E7aB9103986B662D8A79B1976E
  sample_furnace_token=0x0b484B7bd84A3566acf3Df6E2d215F3538155250
  weth=0x0Bd7D308f8E1639FAb988df18A8011f41EAcAD73
  univ3_factory=0x1f7d7550B1b028f7571E69A784071F0205FD2EfA
  position_manager=0x73991a25C818Bf1f1128dEAaB1492D45638DE0D3
  swap_router=0xCaf681a66D020601342297493863E78C959E5cb2
PRODUCT_TYPE   : launchpad (bonding curve + instant V3 + graduation)
BOUNTY/CONTEST : none / discretionary
RESEARCHER     : deviykee
```

API: `GET https://www.foragepad.com/api/launch/prepare` returns factory.  
`GET https://www.foragepad.com/api/launches` returns launch list (curve + instant).

Live factory: `launchCount = 3`, `PLATFORM_FEE_BPS = 50`, owner = treasury address above.

Sample curve state:

| Field | Value |
|-------|--------|
| token | `0xb6365c…976E` |
| virtualEth | 2 ETH |
| virtualTokens | 7.5e26 |
| graduationEth | 4 ETH |
| realEthReserve | 0 |
| graduationProgressBps | 0 |
| graduated / migrated | false |
| v3Pool | zero |

---

## Architecture

```
FurnaceLaunchFactory 0x18999c…
  |-- launchToken / curve launches
  |-- graduationMigrator() -> 0x1C74Fd…
  v
BondingCurve (per token)
  buy/sell until graduationEth
  migrateToUniswap()  [reverts if not graduated; custom error 0x8523b62a observed]
  v
GraduationMigrator
  createPool + (implied) mint path to NPM
  lpLocker() -> FurnaceLPLocker 0xCa07e6…
  v
FurnaceLPLocker
  onERC721Received / collectForToken / collect
  strings: no withdraw / decreaseLiquidity selectors found
```

---

## Findings (honest)

| ID | Severity | Title | Status |
|----|----------|--------|--------|
| FP-1 | Info | Factory / curve / migrator **unverified** | Confirmed |
| FP-2 | Lead | Graduation migrator present; docs describe raise → V3 + lock | Confirmed |
| FP-3 | Lead / unproven | Migrator uses `createPool` not `createAndInitializePoolIfNecessary`; **no getPool/slot0** in simple scan | Confirmed bytecode; impact unknown |
| FP-4 | Info | Pre-create of V3 pool may **DoS migration** if migrator always `createPool` (reverts when pool exists) rather than silent wrong-price mint | Hypothesis |
| FP-5 | Info | FurnaceLPLocker appears fee-collect only (`collectForToken`); no `withdraw` / `decreaseLiquidity` selector hits | Bytecode scan |
| FP-6 | Trust | Owner = protocol treasury; can set staking pool / config on factory surface | By design |
| FP-7 | - | Proven permissionless theft of curve raise via pool squat | **Not proven** |

### Why no High claim yet

1. **Unverified migrate path** - cannot quote `amount0Min/amount1Min` or price checks.  
2. Migrator does **not** embed the classic `createAndInitializePoolIfNecessary` selector (unlike RoughLaunch factory and Robinlaunch).  
3. Live curves have **near-zero real ETH** - no fork proof of full graduation economics yet.  
4. `migrateToUniswap` reverts before useful state change when not graduated.

### How to promote to High (next work)

1. Get verified source (or solid decompile) of `GraduationMigrator` + curve `migrateToUniswap`.  
2. Fork PoC: fund a curve to `graduationEth`, pre-create V3 pool at hostile price (if code allows reuse), call migrate, measure attacker gain.  
3. If path is `createPool` only and reverts on pre-exist → Medium grief (stuck graduation), not High theft.  
4. If path reuses existing pool without price check → High with bound = that launch’s realEthReserve / LP inventory.

---

## Auth triage (attacker)

| Call | Result |
|------|--------|
| Curve `migrateToUniswap` (not graduated) | Revert custom `0x8523b62a` for attacker / migrator / factory |
| Factory admin-style views | owner readable; several unknown mutators not fully triaged without ABI |

---

## Docs vs live UI

- Docs: full graduation + LP locker fee-for-life narrative.  
- Home UI sometimes: “Contracts deployed - awaiting first launch” while API lists launches. Prefer on-chain + API over marketing copy.

---

## Sources on disk

- `hunts/foragepad/` (partial; no verified source files yet)  
- Notes: this file  

---

deviykee
