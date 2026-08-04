# RobinLaunchpad (#12) - hunt notes (no High proven)

**Researcher:** deviykee  
**Date:** 2026-07-20  
**Status:** Live site + contracts mapped. Bonding-curve **PumpLaunchpad** is verified and fully reviewed. NFT/inscription marketplace contracts and alternate `tokenLaunchpad` are **unverified**. No permissionless High claimed. No mainnet exploit attempted.

---

## What this means in plain language (read this first)

**RobinLaunchpad** (https://www.robinlaunchpad.com, @robinlaunchpad) is a multichain product on Robinhood Chain (4663) and Arc. On RH it is primarily:

1. **NFT marketplace** + **collection factory** + **inscription / rh-20** tooling  
2. A **pump.fun-style bonding curve** (`PumpLaunchpad`) where tokens graduate into an **internal** constant-product pool that stays inside the launchpad contract  

This is **not** the same architecture as Robinlaunch/Openfair/StockDotFun, which move the raise into Uniswap V3/V4. Here, "graduation" means: drop virtual reserves and keep remaining tokens + raised ETH as a locked internal AMM. There is **no** `createAndInitializePoolIfNecessary` and **no** external pool key to pre-squat.

So the campaign's main High class (V3 migration pool squat / V4 pre-init freeze) **does not apply** to the verified pump path.

---

## INTAKE

```
PROJECT_NAME   : RobinLaunchpad
X_HANDLE       : @robinlaunchpad
WEBSITE        : https://www.robinlaunchpad.com
DOCS           : https://www.robinlaunchpad.com/docs
CHAIN          : Robinhood Chain
RPC            : https://rpc.mainnet.chain.robinhood.com
CHAIN_ID       : 4663
EXPLORER       : https://robinhoodchain.blockscout.com
KNOWN_ADDRS    :
  pumpLaunchpad=0x2997734D67280A9AA81F6403351C6efBD682281f
  pumpLaunchpadLegacy=0xada73516f37468c3560b889dfadc55fa3e5f6a7c
  tokenLaunchpad=0x1eeCbe0C8cc3A02891E72Bd9fb756D74b86cEc94
  collectionFactory=0x538f705f81c43dc892e0682f9d712a1a42638b08
  collectionFactoryPrev=0xE11902e45434f04e08fe819887f5ad15c83848fc
  nft=0xE2f64dfA4110d268b07E4558F7384F3FE3e21D9E
  nftMarket=0xc3B76C8Af58a84f3cA38492ADfcE129A645BAFB5
  inscriptionMarket=0x4e5BDdA89166146BC2C855e89eb4A9a1B3C9D78D
  zapRouter=0x87FDE12C35094d9299174BEfEd1473BC41C80C41
  deployer=0x42BA2337C1d558d1E008bc72d66D5283EEf5E0A6
PRODUCT_TYPE   : launchpad + NFT/inscription marketplace
BOUNTY/CONTEST : none / discretionary
NOTES          : Frontend config in create-page JS; /api/health returns market addresses; multichain Arc RPC also referenced
RESEARCHER     : deviykee
```

Sources: docs HTML, `https://www.robinlaunchpad.com/api/health`, create-page chunk addresses, Blockscout/Sourcify.

Local: `hunts/robinlaunchpad/src/0x299773…sol` (+ LaunchToken extras).

---

## Architecture (verified pump path)

`PumpLaunchpad` (`0x299773…281f`, Sourcify exact match):

| Constant | Value |
|----------|--------|
| SUPPLY | 1e9 tokens |
| CURVE_SUPPLY | 800M sold on curve |
| Remaining at grad | 200M + all `ethReserveReal` stay in contract as locked pool |
| VIRT_ETH / VIRT_TOKEN | 1 ETH / 1.1e9 tokens |
| Fee | owner-set, max 10% (`MAX_FEE_BPS = 1000`); live design default ~6.9% class from comments |
| Anti-whale | `maxWalletBps` stamped per token at launch (default 2%); lifted via `setGraduated()` |

Flow:

1. `createToken` / `createAndBuy` clones `LaunchToken`, mints full supply to launchpad.  
2. `buy` / `sell` on virtual constant-product curve.  
3. Buy that crosses `CURVE_SUPPLY` calls `_buyAndGraduate`: sets `graduated = true`, refunds unused ETH, lifts wallet cap.  
4. After graduation, `_reserves` uses **real** ETH + remaining tokens; buy/sell continue **on the same contract**.  
5. No Uniswap factory, no external LP NFT, no migrate function.

Creator fees: **pull** via `claimCreatorRewards` (good; avoids creator DoS).  
Platform fees: **push** to `feeRecipient` on every trade (if recipient reverts, trades brick - owner-controlled trust surface).

---

## Findings reviewed (none claimed High)

### 1. No V3/V4 migration pool squat (mitigated by design)

Graduation never calls Uniswap. The raise never leaves the launchpad as LP into a stranger-initable pool. **Class absent.**

### 2. Internal "permanent lock"

Comments and docs claim no admin withdraw of pool principal. Source has no `withdraw` / `rescue` of `ethReserveReal` for graduated pools. Owner can only `setFee` / `setMaxWalletBps` / ownership transfer. **By design centralization is limited to fee config.**

### 3. Platform fee push DoS (trust / Medium-ish)

`_routeFee` does `_pay(feeRecipient, platformCut)`. If `feeRecipient` is a contract that reverts on receive, every buy/sell reverts. Owner can change recipient. Label: **trust/centralization**, not permissionless theft.

### 4. Marketing vs code (docs LP wording)

Docs FAQ text mixes "permanently-locked liquidity" with language that sounds like removable LP shares. Verified pump path has **no LP token** and no remove-liquidity. Users trade against the contract AMM only. **Docs inconsistency, not a security bug by itself.**

### 5. Unverified surfaces (open residual)

| Contract | Code size | Verified | Notes |
|----------|-----------|----------|--------|
| tokenLaunchpad `0x1eeCbe…` | ~7.2KB | no | Separate "token" launch path in frontend config |
| pumpLaunchpadLegacy `0xada735…` | ~7.0KB | no | Pre-V2; may still hold history |
| collectionFactory `0x538f70…` | ~11.9KB | no | NFT drop factory |
| nft / nftMarket / inscriptionMarket | various | no | Marketplace + escrow claims in docs |
| zapRouter `0x87FDE1…` | ~12.6KB | no | Zap helper |

Without source, no High claimed on these. Priority if reopened: **tokenLaunchpad** bytecode (possible second bonding/migrate design) and marketplace escrow.

### 6. Clone + initialize same-tx

LaunchToken initialize is same transaction as clone; implementation is pre-locked. Standard safe pattern; no front-run initialize issue observed.

### 7. Rounding

Buy/sell math uses ceil in favor of the pool on several paths (comments match code). No clear free-round-trip drain found on read.

---

## Live notes

- `/api/health`: chainId 4663, market + nftMarket addresses, inscription index (~13 items when checked).  
- PumpLaunchpad contract balance was non-zero (order of ~0.0009 ETH class when read) - small live activity.  
- Deployer EOA for core set: `0x42BA2337…E0A6`.  
- Multichain: Arc RPC also in frontend (`rpc.blockdaemon.mainnet.arc.io`). This hunt scoped RH 4663.

---

## Severity summary

| Item | Severity |
|------|----------|
| V3/V4 migration squat | **N/A** (no external migrate) |
| Permissionless raise theft / freeze | **Not found** on verified pump |
| Fee recipient push DoS | Trust / conditional Medium at most |
| Unverified tokenLaunchpad / markets | Residual; no High without source |

**Campaign status: HUNTED-NOTES** (full pass on verified pump; marketplace residual).

---

## Disclosure

No High DM required. Optional friendly note to @robinlaunchpad: pump path avoids Uniswap migrate class; docs LP wording is confusing; consider verifying marketplace + tokenLaunchpad sources.

deviykee
