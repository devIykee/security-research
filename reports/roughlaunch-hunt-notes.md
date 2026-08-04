# Inkfeather / RoughLaunch (#9) - hunt notes (no High proven)

**Researcher:** deviykee  
**Date:** 2026-07-20  
**Status:** Live product mapped. LaunchToken verified. Factory + fee locker are UUPS proxies with **unverified** implementations. Bytecode contains `createAndInitializePoolIfNecessary` (same family as Robinlaunch/Openfair). No raise held (single-sided V3). No permissionless High proven without full launch path decompile/source. No mainnet exploit attempted.

---

## What this means in plain language (read this first)

**Inkfeather** is the brand shell for **RoughLaunch** (`https://www.inkfeather.io`).

RoughLaunch is a **hybrid instant Uniswap V3** pad, not a bonding-curve raise vault:

1. Deploy fixed-supply `LaunchToken` (verified, no tax, max wallet + short anti-snipe window)  
2. Mint a **single-sided 1% V3** position from block one  
3. Hold the position NFT in a fee-only locker  
4. At **4.20 ETH** net WETH in the pool, “graduation” is only a **milestone** (progress bar). **Liquidity does not migrate.**

So the classic High where a stranger pre-opens the pool and the pad **dumps a bonding-curve raise** into a fake price is **less direct** here: there is **no pad-held buyer ETH** to dump at graduation. The remaining risk is wrong-price **initial** LP placement if the factory reuses a hostile pre-inited pool.

The factory is **UUPS upgradeable** and **closed-source**. Owner can upgrade the implementation later. That is a trust item, not a permissionless bug by itself.

---

## INTAKE (known only)

```
PROJECT_NAME   : RoughLaunch (Inkfeather)
WEBSITE        : https://www.inkfeather.io
CHAIN          : Robinhood Chain
RPC            : https://rpc.mainnet.chain.robinhood.com
CHAIN_ID       : 4663
EXPLORER       : https://robinhoodchain.blockscout.com
KNOWN_ADDRS    :
  factory_proxy=0x5354c99ad66F48E5e10590E2aBd81A877ba862d2
  factory_impl=0x67eb34840132dd15c2e54969bb19e80e5955a787
  fee_locker_proxy=0x3C31317d3e10E4F3748823fA7E19eebA81aFc63A
  fee_locker_impl=0xa48a5807175a14e2f608fc29db1c9ea8de54aea2
  owner=0xe6Be3494189599918ACDF486EaAeF4509eD0FEBd
  sample_token_PAPERCAT=0x9d769a085e3af5d0fcda993d23e3e2d9f31c2244
  sample_pool=0xb0C382155648Af02951F28c9fDd05e99aFACEF1E
  weth=0x0Bd7D308f8E1639FAb988df18A8011f41EAcAD73
  univ3_factory=0x1f7d7550B1b028f7571E69A784071F0205FD2EfA
  position_manager=0x73991a25C818Bf1f1128dEAaB1492D45638DE0D3
  swap_router=0xCaf681a66D020601342297493863E78C959E5cb2
PRODUCT_TYPE   : launchpad (instant V3 single-sided + fee locker)
BOUNTY/CONTEST : none / discretionary
RESEARCHER     : deviykee
```

Live: `tokenCount = 1`, `launchFee = 0`, `graduationThreshold = 4.2 ETH`, `creatorFeeShareBps = 5000`, `REQUIRED_POOL_FEE = 10000` (1%).

---

## Architecture

| Role | Address | Notes |
|------|---------|--------|
| Launch factory (proxy) | `0x5354c99a…62d2` | EIP-1967 UUPS |
| Factory implementation | `0x67eb3484…a787` | unverified |
| Fee locker (proxy) | `0x3C31317d…c63A` | UUPS |
| Fee locker impl | `0xa48a5807…aea2` | `collectAndDistribute`, `registerPosition` |
| LaunchToken (sample) | `0x9d769a…2244` | **verified** |

Site claim (matches design): Protocol Factory/Locker stay closed-source; LaunchToken auto-verified; current locker cannot decrease liquidity or transfer NFT.

---

## Findings (honest)

| ID | Severity | Title | Status |
|----|----------|--------|--------|
| RL-1 | Lead / unproven | Factory bytecode includes `createAndInitializePoolIfNecessary` + NPM `mint` | Confirmed in impl; **not proven** as exploitable without source (also has `getPool`; no `slot0` string/selector in scan) |
| RL-2 | Info | Single-sided instant listing: no pad-held raise to migrate | Confirmed |
| RL-3 | Trust | UUPS `upgradeToAndCall` on factory (and locker) - owner can change logic | Auth-guarded for attacker (`OwnableUnauthorizedAccount`) |
| RL-4 | Info | Graduation is milestone only (`syncGraduation` / progress); LP does not move at 4.20 ETH | Site + selectors |
| RL-5 | Info | Verified `LaunchToken` max-wallet + same-block buy block from pool | Solid token surface |
| RL-6 | - | Permissionless High fund theft | **Not proven** |

### Why no High claim yet

1. **No verified factory source** showing `amount0Min/amount1Min = 0` and missing post-init price check.  
2. **`getPool` is present** in the same impl. HoodTech-style abort is possible; cannot claim either way from bytecode alone.  
3. Even if pool squat works, **no curve raise** is custodied. Impact is mispriced single-sided inventory / first-trade unfairness, not classic “dump 2–6 ETH of buyer raise.” Prefer source + PoC before rating High.

### Residual lead (what to finish for High)

If factory launch does:

```
createAndInitializePoolIfNecessary(...)
mint(..., amount0Min: 0, amount1Min: 0)
// no slot0 check
// no require(getPool == 0) before
```

then pre-init of the predicted token/WETH 1% pool at a hostile sqrt price is the Robinlaunch/Openfair class applied to **instant listing**. Prove with fork PoC once source or decompile of launch calldata path is solid.

---

## Auth triage (attacker)

| Call | Result |
|------|--------|
| Factory `upgradeToAndCall` | Ownable revert |
| Fee locker owner-gated upgrade surface | Ownable pattern (proxy) |
| LaunchToken `configureLiquidityPool` | Only factory |

---

## Sources on disk

- `hunts/roughlaunch/LaunchToken.sol` (verified sample)  
- Notes: this file  

---

deviykee
