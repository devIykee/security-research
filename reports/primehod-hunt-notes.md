# Primehod (#23) - hunt notes (no High proven)

**Researcher:** deviykee  
**Date:** 2026-07-20  
**Status:** Fully verified factory + curve + V3 locker (Sourcify exact). Two venues: bonding curve and instant Uniswap V3. **No permissionless High claimed.** No mainnet exploit attempted.

---

## What this means in plain language (read this first)

Primehod launches tokens two ways:

1. **Curve venue** (`createToken`): fixed-supply token + self-contained ETH bonding curve. "Graduation" is only a **milestone flag** when raised ETH hits a USD-converted cap. Trading on the curve **continues**; there is **no Uniswap migration** of the raise.  
2. **V3 venue** (`createTokenV3`): single-sided token liquidity into a Uniswap V3 1% pool, NFT held in a **permanent** per-launch locker (fees collectable only).

The campaign High (pre-init pool, pad dumps held raise at wrong price) does **not** apply cleanly:

- Curve: no external pool at all.  
- V3: uses hard `v3Factory.createPool` then `pool.initialize` (not `createAndInitializePoolIfNecessary`). Pre-existing pool makes **createPool revert** (launch fails), not silent wrong-price mint. Single-sided, no WETH raise deposited.

---

## INTAKE

```
PROJECT_NAME   : Primehod
WEBSITE        : https://primehod.lol
DOCS           : https://primehod.lol/docs
CHAIN          : Robinhood Chain
RPC            : https://rpc.mainnet.chain.robinhood.com
CHAIN_ID       : 4663
EXPLORER       : https://robinhoodchain.blockscout.com
KNOWN_ADDRS    : factory=0x57EfC7cE5250C96B0b0E7C554c9d9743A18b794f
PRODUCT_TYPE   : launchpad (curve OR instant V3)
BOUNTY/CONTEST : none / discretionary
NOTES          : Open-source claim; multi fee tiers on curve; owner sets ethUsdPrice for caps
RESEARCHER     : deviykee
```

Local: `hunts/primehod/src/` (PrimehodFactory, Curve, V3Locker, Vesting, Token).

---

## Architecture

| Component | Role |
|-----------|------|
| PrimehodFactory | Mint 1B supply, allocate vest/dist, deploy curve or V3 |
| PrimehodCurve | Constant-product virtual reserves; fees split creator/platform; graduate flag |
| PrimehodV3Locker | Holds LP NFT forever; permissionless fee collect + split |
| PrimehodVesting | Default public path: 20% vest 1%/30d (config defaults, per-launch frozen) |

V3 path core:

```solidity
pool = v3Factory.createPool(token, weth, V3_FEE);
IUniswapV3PoolMin(pool).initialize(TickMath.getSqrtPriceAtTick(poolTick));
// single-sided mint amount0Min/amount1Min = 0 → recipient locker
locker.lock(positionId);
```

Curve path: ETH stays in curve; `graduated` does not block `buy`/`sell`.

---

## Findings

### 1. V3 pool squat — mitigated by createPool hard-fail

Pre-create + initialize causes `createPool` to revert. No soft-reuse path. Instant single-sided → no raise dump. **Not High.**

### 2. Curve "graduation" is not a migration High surface

`_maybeGraduate` only sets a bool and emits. No LP seed, no router call, no freeze. Residual product risk: raise sits on curve forever (by design / old comment "no DEX yet") — not an exploit.

### 3. Owner centralization

`setEthUsdPrice`, fee defaults, distribution list (owner-instant path), platform address. Affects **future** launches only (documented). Trust residual.

### 4. V3 mint mins = 0

Acceptable after hard `initialize` in same tx with no pre-existing pool. Residual dust/rounding only (`require(used > 0)`).

### 5. Locker permanence

Verified: no decreaseLiquidity / transfer of NFT. Collect only. **Good.**

---

## Severity summary

| Item | Severity |
|------|----------|
| V3 wrong-price raise dump | **N/A / mitigated** |
| Curve freeze + migrate pollution | **N/A** (no migrate) |
| Owner ethUsdPrice / fee defaults | Trust |
| Permissionless High | **None** |

**Campaign status: HUNTED-NOTES**

deviykee
