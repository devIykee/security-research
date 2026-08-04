# Novapex (#20) - hunt notes (no High proven)

**Researcher:** deviykee  
**Date:** 2026-07-20  
**Status:** Live site + verified **PumpFactory** source reviewed (Sourcify exact match). Bonding-curve → Uniswap **V2** graduation with explicit pollution tolerance and owner rescue. **No permissionless High claimed.** No mainnet exploit attempted.

---

## What this means in plain language (read this first)

Novapex is a pump.fun-style pad on Robinhood Chain. Buyers put ETH into a bonding curve until ~**3 ETH** of raise is collected (constants: virtual ETH 1.02375, 800M of 1B tokens on curve). Then trading on the curve **closes**, and anyone can call `finalizeGraduation` to seed a Uniswap **V2** pair and **burn LP** to `0xdead`.

Compared to Robinfun (High): Robinfun had a tight "pollution" check that **failed migration forever** and left an **owner recovery** that takes the raise to treasury.

Novapex deliberately softens that:

1. Migration uses **95% min amounts** (`MIGRATION_TOLERANCE_BPS = 9500`), so mild pre-seeding still migrates.  
2. Extreme skew reverts; owner can `rescueGraduated` to move ETH + reserved tokens to any address.  
3. Graduating buy does **not** call Uniswap inline (keeps the last buy from bricking on router failure).

That is a better design against permanent permissionless freeze. Residual risks are trust/owner rescue and residual V2 ratio grief — not a clean High for this pass.

---

## INTAKE

```
PROJECT_NAME   : Novapex
WEBSITE        : https://www.novapex.fun
CHAIN          : Robinhood Chain
RPC            : https://rpc.mainnet.chain.robinhood.com
CHAIN_ID       : 4663
EXPLORER       : https://robinhoodchain.blockscout.com
KNOWN_ADDRS    :
  pumpFactory=0xF34a44F20979F66939637F59282Ff80b3bc17DC5
  coinThreads=0x815F77E52AD8ecEc40629abead29A37b29FA3f9A
  deployer=0xC5b0A8B1f1f3c97cdB03dd24880a278fbD83f12a
  weth_canonical=0x0Bd7D308f8E1639FAb988df18A8011f41EAcAD73
  uniswap_v2_router_docs=0x89e5db8b5aa49aa85ac63f691524311aeb649eba
PRODUCT_TYPE   : launchpad (bonding curve → Uniswap V2 LP burn)
BOUNTY/CONTEST : none / discretionary
NOTES          : Frontend hardcodes factory + CoinThreads; ~3 ETH curve raise target from constants
RESEARCHER     : deviykee
```

Sources: `hunts/novapex/PumpFactory.sol`, `CoinThreads.sol`, frontend `assets/index-Ihcnap1X.js`.

---

## Architecture

```
createToken → MemeToken (1B supply to factory)
buy/sell on constant-product virtual reserves
tokensSold >= CURVE_SUPPLY (800M) → graduated=true, curve trading closed
finalizeGraduation(token) [permissionless]
  → addLiquidityETH(token, 200M, ethReserve, mins@95%, LP→dead)
  → leftovers: tokens to dead, ETH to fee path
rescueGraduated(token, to) [onlyOwner] if stuck graduated && !migrated
```

| Constant | Value |
|----------|--------|
| TOTAL_SUPPLY | 1e9 |
| CURVE_SUPPLY | 800M |
| DEX_SUPPLY | 200M |
| VIRTUAL_ETH | 1.02375 ETH |
| TRADE_FEE_BPS | 100 (1%) |
| MIGRATION_TOLERANCE_BPS | 9500 (95%) |
| Target raise (design) | 3 ETH |

---

## Findings reviewed

### 1. V2 pair pollution freeze — mitigated vs Robinfun (not High)

```solidity
IUniswapV2Router02(router).addLiquidityETH{value: ethAmount}(
    token,
    tokenAmount,
    (tokenAmount * MIGRATION_TOLERANCE_BPS) / BPS,
    (ethAmount * MIGRATION_TOLERANCE_BPS) / BPS,
    DEAD,
    block.timestamp
);
```

- No brittle "pair polluted → forever fail with no soft path" gate like Robinfun.  
- Mild skew still migrates; extreme skew reverts entire finalize (effects roll back — no try/catch CEI leak).  
- Owner `rescueGraduated` can unstick; also can send raise to owner-chosen `to` (**trust** if owner is compromised or malicious).

### 2. Trading freeze window after graduation

While `graduated && !migrated`, buy/sell revert `CurveClosed`. Users wait for finalize (or owner rescue). Normal for this design; grief requires extreme V2 skew capital relative to a ~3 ETH raise.

### 3. Fee recipient push DoS — mitigated

Failed fee pushes accrue to `accruedFees` / claim path so a rejecting recipient cannot brick trades. **Good.**

### 4. Ownership

Two-step `pendingOwner` / `acceptOwnership`. Uniswap router/WETH owner-settable (migration can be disabled by setting router to 0). Trust residual only.

### 5. CoinThreads

Comment contract only; requires token exists on factory. Out of scope for fund risk.

### 6. V3 pool squat class

**N/A** — migration is Uniswap V2 `addLiquidityETH`, not V3 NPM.

---

## Severity summary

| Item | Severity |
|------|----------|
| Robinfun-style permanent pollution freeze | **Mitigated** (95% mins + retryable finalize) |
| Owner rescue of full raise | **Trust / centralization** (document, not permissionless High) |
| Curve freeze until migrate | Expected; grief capital-gated |
| Permissionless theft of ethReserve | **Not found** |

**Campaign status: HUNTED-NOTES**

---

## Disclosure

Optional note to @/team: solid separation of graduating buy vs migrate; keep 95% mins + document owner rescue trust model. Verify Uniswap router is set on mainnet (docs cite `0x89e5…9eba`) so graduated tokens do not sit forever with migration disabled.

deviykee
