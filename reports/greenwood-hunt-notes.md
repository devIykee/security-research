# The Greenwood (#22) - hunt notes (no High proven)

**Researcher:** deviykee  
**Date:** 2026-07-20  
**Status:** Live site + factory address from HTML. Factory, locker, and vault are **unverified**. Bytecode + selector map + live eth_call completed. Instant Uniswap V3-style deploy surface. **No permissionless High claimed without source/fork PoC.** No mainnet exploit attempted.

---

## What this means in plain language (read this first)

The Greenwood is a simple static launch UI on Robinhood Chain. The page hardcodes factory `0x81de990b…2977` and showcases `$WOOD` (created by that factory). Optional vault language appears in targets/notes; on-chain there is a `vault()` address and `liquidityLocker()`.

Unlike Robinlaunch, bytecode does **not** contain `createAndInitializePoolIfNecessary`. It does contain:

- Uniswap V3 **`createPool`** (×2)  
- Pool **`initialize`** (×2)  
- NPM **`mint`** / `safeTransferFrom` (×2)  

That pattern usually means: create empty pool → initialize price → mint position → lock NFT. If `createPool` **hard-reverts** when the pool already exists, pre-init only DoSes the launch (not a raise dump). If the factory **swallows** create/init failure and mints into a pre-priced pool with zero mins, that would be a High-class lead **only if** a held raise is deposited (this product looks **instant listing**, not bonding curve).

Without verified source, severity stays unclaimed.

---

## INTAKE

```
PROJECT_NAME   : The Greenwood
WEBSITE        : https://www.thegreenwood.fun
CHAIN          : Robinhood Chain
RPC            : https://rpc.mainnet.chain.robinhood.com
CHAIN_ID       : 4663
EXPLORER       : https://robinhoodchain.blockscout.com
KNOWN_ADDRS    :
  factory=0x81de990be508b95540b3c519417e7c0755b42977
  wood_token=0x58941a9b05265e72ddb462f7e5300c4c07edf119
  liquidityLocker=0xa9f3a25fba2e551a23462b5f68521be2591165f1
  vault=0xaf7a64287add93db603cb9356bd8e4d7fef296c0
  owner=0x979fb2099c70f106b9ea11a889f51e2c12a81be9
  weth=0x0Bd7D308f8E1639FAb988df18A8011f41EAcAD73
  univ3_factory=0x1f7d7550B1b028f7571E69A784071F0205FD2EfA
  position_manager=0x73991a25C818Bf1f1128dEAaB1492D45638DE0D3
  swap_router=0xCaf681a66D020601342297493863E78C959E5cb2
PRODUCT_TYPE   : launchpad (instant V3 + locker/vault options)
BOUNTY/CONTEST : none / discretionary
NOTES          : Factory ~17KB unverified; $WOOD creator is factory; deprecated()=false
RESEARCHER     : deviykee
```

---

## Live surface map (eth_call / selectors)

| Selector / view | Meaning |
|-----------------|---------|
| `deployToken(...)` | Main launch |
| `deployTokenWithCustomTeamRewardRecipient(...)` | Launch + custom reward recipient |
| `deployTokenZeroSupply(...)` | Zero-supply variant |
| `liquidityLocker()` | `0xa9f3a25f…165f1` (unverified) |
| `vault()` | `0xaf7a6428…296c0` (unverified) |
| `POOL_FEE()` | 10000 (1%) |
| `TICK_SPACING()` | 200 |
| `TOKEN_SUPPLY()` | large fixed supply |
| `owner()` | `0x979fb209…1be9` |
| `setDeprecated` / `deprecated` | kill switch (live false) |
| `updateLiquidityLocker` / `updateVault` | owner can retarget custody |
| `claimRewards` | reward claim surface |

Bytecode fingerprints: `createPool` yes, `initialize` yes, `createAndInitialize` **no**, `getPool` **no**, `slot0` **no**, `addLiquidityETH` **no**.

---

## Findings

### 1. V3 wrong-price dump — lead only (unverified, likely no raise)

- No bonding-curve state in the selector map.  
- Instant fixed `TOKEN_SUPPLY` + one-sided tick constants strongly suggest single-sided listing.  
- Pre-init without soft-reuse of existing pools → launch fail (grief), not fund theft.  
- **Not claimable High** until source shows soft-reuse + WETH raise deposit + zero mins + no price check.

### 2. Owner can swap locker / vault

`updateLiquidityLocker` / `updateVault` — centralization on **future** deploys; check whether already-locked NFTs can be moved (depends on locker immutability). Unverified residual.

### 3. Locker / vault unverified

No source for `decreaseLiquidity` / withdraw absence. Claims of permanent lock cannot be machine-verified from this pass.

### 4. Site simplicity

Single HTML page; no JS bundle factory beyond hardcoded `GW`. Logs event topic used only for “latest symbol” display.

---

## Severity summary

| Item | Severity |
|------|----------|
| Classic V3 raise squat | **Not proven** (no source; likely no raise) |
| Pre-init launch grief | Possible Medium if createPool hard-reverts forever per salt |
| Owner locker/vault retarget | Trust / centralization |
| Permissionless High | **None claimed** |

**Campaign status: HUNTED-NOTES** (map complete; re-open if factory is verified).

deviykee
