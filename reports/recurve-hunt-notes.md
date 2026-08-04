# Recurve / ex-HoodPad (#25) - hunt notes (no High proven)

**Researcher:** deviykee  
**Date:** 2026-07-20  
**Status:** Verified `RecurveLaunchpad` (Sourcify exact). Instant Uniswap V3 single-sided launches; graduation is read-only. **No permissionless High claimed.** No mainnet exploit attempted.

---

## What this means in plain language (read this first)

Recurve (rebrand from HoodPad) puts the whole token supply into a **Uniswap V3** pool at launch as **single-sided** liquidity held by the launchpad. There is no bonding-curve raise to migrate later. "Graduation" is only a UI signal once enough WETH has been bought into the position.

They explicitly defend against pre-priced pools:

```solidity
pool = factory.getPool(...);
if (pool == address(0)) pool = factory.createPool(...);
(uint160 existing,,,,,) = IUniswapV3Pool(pool).slot0();
if (existing != 0) revert PoolTaken(); // someone pre-created and priced it
IUniswapV3Pool(pool).initialize(startSqrt);
```

That is the correct hard-fail pattern (same idea as MetaLaunch tick checks / Pons getPool gate). Classic Robinlaunch pool-squat High does **not** apply.

---

## INTAKE

```
PROJECT_NAME   : Recurve (ex-HoodPad)
WEBSITE        : https://recurve.fi
DOCS           : https://recurve.fi/docs
CHAIN          : Robinhood Chain
RPC            : https://rpc.mainnet.chain.robinhood.com
CHAIN_ID       : 4663
EXPLORER       : https://robinhoodchain.blockscout.com
KNOWN_ADDRS    :
  launchpad=0xd41a03a01369a734a5e22c3d6484b4040ae9acfd
  recurve_token=0x0FFf0c68b7dd24bDC840c73BcB8B147285653FA6
  univ3_factory=0x1f7d7550B1b028f7571E69A784071F0205FD2EfA
  npm=0x73991a25C818Bf1f1128dEAaB1492D45638DE0D3
  swap_router=0xCaf681a66D020601342297493863E78C959E5cb2
  weth=0x0Bd7D308f8E1639FAb988df18A8011f41EAcAD73
PRODUCT_TYPE   : launchpad (instant single-sided V3)
BOUNTY/CONTEST : none / discretionary
RESEARCHER     : deviykee
```

Local: `hunts/recurve/src/contracts_RecurveLaunchpad.sol`, `RecurveCoin.sol`.

---

## Findings

### 1. V3 pre-init / pool squat — mitigated (`PoolTaken`)

Pre-init causes launch revert, not wrong-price LP. No held raise to dump.

### 2. Instant single-sided + LP held by pad

Liquidity minted to launchpad; no `burn`/withdraw path claimed in comments. Fee modes frozen per coin. Residual: confirm no admin escape on fee collect / ownership (owner can disable launches, set treasury defaults for **future** coins).

### 3. Anti-snipe window on RecurveCoin

Short max-wallet/tx restriction (~36s) for pool buys only. Expected product feature.

### 4. Dev buy slippage

Optional atomic dev buy uses `minTokensOut` (caller-set). Good if UI requires it.

---

## Severity summary

| Item | Severity |
|------|----------|
| V3 migration pool squat | **Mitigated** |
| Raise migrate freeze | **N/A** |
| Permissionless High | **None** |

**Campaign status: HUNTED-NOTES**

deviykee
