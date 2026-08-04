# MetaLaunch (#13) - hunt notes (no High proven)

**Researcher:** deviykee  
**Date:** 2026-07-20  
**Status:** Live multi-version stack mapped from frontend + Blockscout/Sourcify. Current **MetaLaunchFactoryV12** reviewed end-to-end for V3 pool-squat class. Legacy V5 `FoundryLaunchpad` also reviewed. **No permissionless High claimed.** No mainnet exploit attempted.

---

## What this means in plain language (read this first)

MetaLaunch is an **instant Uniswap V3** memecoin launchpad on Robinhood Chain (not a bonding-curve raise pad). One transaction deploys a fixed-supply token, opens a 1% V3 pool, and locks 100% of the initial position in a permanent locker.

The campaign High that paid on Robinlaunch/Openfair is: pre-create the pool at a fake price, then the pad dumps a **held raise** into it with zero min amounts and no price check.

MetaLaunch is different:

- There is **no curve raise** sitting on a contract waiting to graduate. Liquidity is **single-sided token** only at launch.  
- **Current V12** (frontend "current" factory) **reverts** if the live pool tick is not exactly the intended opening tick (`TickMisaligned`). That kills the classic wrong-price dump.  
- Salt search also requires `getPool(predicted, pair, fee) == 0`, so vanity CREATE2 addresses with a pre-existing pool are skipped.

So the main High class is **mitigated on current production**, and is **not raise-theft** on legacy pads either (single-sided listing). Residual notes below only.

---

## INTAKE

```
PROJECT_NAME   : MetaLaunch
WEBSITE        : https://metalaunch.fun
CHAIN          : Robinhood Chain
RPC            : https://rpc.mainnet.chain.robinhood.com
CHAIN_ID       : 4663
EXPLORER       : https://robinhoodchain.blockscout.com
KNOWN_ADDRS    :
  factory_v12_current=0x1B2A2ee9E66862e6323B0D43b26f60235214660A
  locker_v11=0x68BE04B93F732B7ed4dA06305EC0A7a82e456092
  token_deployer_v12=0x543293FE04C84FedFBf008b9889f294FDb158070
  factory_v11=0x76f1d938d4917B615eaC478754951Ed4aa92420C
  factory_v6=0x6813de2fC38775f7E1c311645aFE03E6315CC0DE
  pad_v5=0x49A3D384cd90A58815df31C1852dB4095B90c0De
  metalocker_v3_to_v6=0x49A955A2818069C4320b52602deF1706411bC0De
  owner_treasury=0x4F298f5991661150Ee85A5b0690653D13e0fc42c
  weth=0x0Bd7D308f8E1639FAb988df18A8011f41EAcAD73
  univ3_factory=0x1f7d7550B1b028f7571E69A784071F0205FD2EfA
  position_manager=0x73991a25C818Bf1f1128dEAaB1492D45638DE0D3
  swap_router=0xCaf681a66D020601342297493863E78C959E5cb2
PRODUCT_TYPE   : launchpad (instant single-sided Uniswap V3 + permanent locker)
BOUNTY/CONTEST : none / discretionary
NOTES          : Frontend labels V7 factory as current; bytecode name is MetaLaunchFactoryV12. Vanity suffix c0de.
RESEARCHER     : deviykee
```

Sources: `hunts/metalaunch/MetaLaunchFactoryV12.sol`, `FoundryLaunchpad.sol` (V5), `MetaLocker.sol`, frontend `/assets/index-B2XF_vqU.js`.

---

## Architecture

| Generation | Role | Address | Verified |
|------------|------|---------|----------|
| **V12 current** | MetaLaunchFactoryV12 | `0x1B2A2ee9…4660A` | yes |
| V11 | MetaLaunchFactoryV11 | `0x76f1d938…420C` | yes |
| V11 locker | MetaLaunchLockerV11 | `0x68BE04B9…6092` | source present / check twin |
| V12 deployer | MetaLaunchTokenDeployerV12 | `0x543293FE…8070` | yes |
| V6 | MetaLaunchFactory | `0x6813de2f…C0DE` | yes |
| V5 | FoundryLaunchpad (VERSION=7 in source comment lineage) | `0x49A3D384…c0De` | yes |
| V3–V6 locker | MetaLocker | `0x49A955A2…C0De` | yes |

Launch (V12): CREATE2 vanity token → `createAndInitializePoolIfNecessary` → **require pool tick == intended** → one-sided mint → permanent lock → optional first buy with `minInitialBuyOut`.

---

## Findings

### 1. V3 pool squat / wrong-price dump — mitigated on V12 (not High)

```solidity
x.pool = npm.createAndInitializePoolIfNecessary(t0, t1, x.dex.poolFee, sqrtP);
(, int24 tickNow,,,,,) = IUniswapV3Pool(x.pool).slot0();
if (tickNow != x.poolTick) revert TickMisaligned();
// mint still uses amount0Min/amount1Min = 0, but only after tick match
```

Salt grind also requires:

```solidity
IUniswapV3Factory(dex.factory).getPool(predicted, cfg.pairToken, dex.poolFee) == address(0)
```

**Result:** Attacker pre-init at a wrong price makes the **launch revert**, not a silent dump of a raise (there is no raise). Correct-price pre-init does not misprice the open.

Compare Hood Tech (`getPool == 0` abort) and this V12 tick equality check — both close the Robinlaunch-class High.

### 2. Legacy V5 FoundryLaunchpad — residual Medium lead only

```solidity
// FoundryLaunchpad (0x49A3…)
pool = positionManager.createAndInitializePoolIfNecessary(t0, t1, POOL_FEE, sqrtPrice);
(, int24 tick, , , , , ) = IUniswapV3PoolMin(pool).slot0(); // used for range only — no equality check
// mint amount0Min/amount1Min = 0
// optional first buy: amountOutMinimum: 0
```

- Single-sided token mint only → **no bonding raise** to steal (duke playbook: pool-squat High is **dead** without a held raise).  
- Opening market can still be polluted if someone pre-inits before a CREATE-based launch (nonce-predictable).  
- Optional creator first buy with **`amountOutMinimum: 0`** can get bad fills if the pool is hostile. Bound = creator's first-buy ETH only.  
- Not claimed High for this campaign pass (legacy pad; no large raise vector).

### 3. Locker custody

MetaLocker / LockerV11: no decreaseLiquidity / transfer path for principal in verified design. Collect fees only to bound controller. **Good.** Trust residual is fee-controller binding at lock time only.

### 4. Owner surfaces

Owner can retune mcap / treasury / incentives fund on older pads; V12 uses Ownable2Step-style surfaces per docs. Centralization only — not permissionless theft.

---

## Severity summary

| Item | Severity |
|------|----------|
| V12 wrong-price pool dump | **Mitigated** (`TickMisaligned` + salt `getPool==0`) |
| V12 raise theft via migrate | **N/A** (instant single-sided, no curve raise) |
| Legacy V5 opening pollution + first-buy minOut=0 | Residual **Medium** lead at most |
| Locker rug of principal | **Not found** in verified locker surface |

**Campaign status: HUNTED-NOTES**

---

## Disclosure

Optional private note to MetaLaunch: current V12 tick check is the right mitigation; keep it on all future factory versions. Legacy V5 still lacks tick equality if they still care about that generation.

deviykee
