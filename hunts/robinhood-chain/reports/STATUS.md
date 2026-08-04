# Robinhood Chain Native Projects — Hunt Status
**Researcher:** deviykee (Iyke skill lead)
**Chain:** Robinhood Chain (4663)
**RPC:** https://rpc.mainnet.chain.robinhood.com
**Explorer:** https://robinhoodchain.blockscout.com
**Date:** 2026-08-03
**Mode:** fork/eth_call only. Nothing touched on mainnet.

## Priority ranking (product type × verifiable surface)

| # | Project | Type | Core found? | Verdict this pass |
|---|---------|------|-------------|-------------------|
| 1 | **Pons** | Launchpad | YES `PonsLaunchFactory` | Reviewed. Classic v3 pool-squat **dead** (single-sided + PoolAlreadyExists). Locker permanent. No perm-less Critical. |
| 2 | **xStocks / CdpEngine** (Arrow-class CDP) | CDP | YES multiple engines | Live TVL. Oracle trust model is the story. See FINDINGS. |
| 3 | **RobinoCurve / LaunchpadFactory** | Bonding curve → V4 | YES | Low ETH TVL. Graduation V4 pre-init DoS **candidate**. Marked TESTNET DRAFT in source. |
| 4 | Arrow Finance (brand) | CDP + launchpad | Partial — xStocks CDP stack matches product; site bundle timed out | Need deeper link to arrowfinance.io branding |
| 5 | LONG() | Stock-paired launchpad | No solid core | Frontend timeout; explorer name noise |
| 6 | The Index / IndexFi | Distribution | No core | |
| 7 | SLVR | Mining | MiningPool named, 0 bal | Surface only |
| 8 | Rialto / Meridian / Arcus | DEX/perps | No verified native cores via explorer search | Frontends slow/opaque; likely centralized/offchain or different naming |
| 9 | CASHCAT | Memecoin | Token only | Skip |

## Confirmed cores

### Pons
| Role | Address |
|------|---------|
| PonsLaunchFactory | `0xA5aAb3F0c6EeadF30Ef1D3Eb997108E976351feB` |
| PonsLaunchLocker | `0x736D76699C26D0d966744cAe304C000d471f7F35` |
| Owner | `0xda4bCee76B29EFEc9697Fcf663601c2042043968` |
| Pair (launch0) | `0x0Bd7D308f8E1639FAb988df18A8011f41EAcAD73` (native/WETH-like) |
| DEX | Uniswap V3 factory `0x1f7d7550B1b028f7571E69A784071F0205FD2EfA` |

### CdpEngine (xStocks USD / SPHYNX USD)
| Engine | Collateral | Oracle | Stable supply | Coll held | Notes |
|--------|------------|--------|---------------|-----------|-------|
| `0x5812E883…7dF9` | xTSLA `0xCDb9089a…8566` | **EquityOracle V1** `0x1E9291…` | 330k | 2300 | Uses **getPrice**; V1 **quorum=1**, **1 reporter** (=owner) |
| `0xF408d7AE…BCAa` | xTSLA | **EquityOracleV2** `0xC324F1…` | 100k | 1000 | Uses **peekPrice**; currently `ok=false` (stale) |
| `0x90f9234a…7B90` | WETH | V2 | 0 | 0 | idle |
| `0xc08065d8…B559` | WETH | V1 | tiny | tiny | SPHYNX USD |

### BondingCurve (Robino / LaunchpadFactory)
| Role | Address |
|------|---------|
| LaunchpadFactory | `0x33916bDB1c269f6CBfEb1b277A413097e3FbbF45` |
| RobinoCurveDeployer | `0xe3c886D4b44B38803301a0035FfB6CFf03DC6912` |
| Sample curves | `0xa3E286…`, `0x5EE8e2…`, `0xc6e6fD…` |
| GRADUATION_ETH | 2.5 ETH |
| Live curve ETH | ~0.0001–0.0004 ETH (dust) |

## Findings

### F1 — EquityOracle V1 quorum=1 + single reporter (CDP trust / key-compromise drain)
**Status:** Confirmed on-chain. **Not permissionless** (reporter = owner EOA).
**Class:** Trust/centralization (would be Critical if reporter key compromised).
**Evidence:**
- `quorum() == 1`
- `reporterCount(xTSLA) == 1`
- `isReporter(owner) == true`
- Owner `0x8EdE0eEb8C03a45886836A1baDec03CdB08cDFb2` also CDP owner
- V2 source literally documents fixing "single-key / quorum=1 arbitrary-price drain"
**Impact if reporter key leaks:** report inflated price → mint max xUSD against underpriced reality → drain collateral on repay/swap path; or crash price → liquidate victims.
**Bound:** CDP_OLD coll ~2300 xTSLA (~$0.9M at lastPrice $393), debt 330k xUSD.
**Action:** Private note to team: migrate all live engines off V1; force V2 + min quorum 3 + independent reporters. Not a public Critical claim.

### F2 — CdpEngine fee debt never mints stable (latent accounting)
**Status:** Code-confirmed. `borrowFeeBps==0` live → **not currently exploitable**.
**Root:** mint adds fee to debt without minting fee amount → total debt can exceed total stable supply → unpayable fee slice.
**Severity if fee enabled:** Medium/High systemic insolvency.
**Fix:** mint fee to treasury or don't add unbacked debt.

### F3 — V2 peekPrice ignores marketOpen; CDP uses peekPrice
**Status:** Code-confirmed. Live xTSLA config has `requireMarketOpen=false` anyway.
**Class:** Oracle closed-market class (Iyke #4) — **weak on this config**.
**Note:** maxAge=86400 keeps Fri close prices valid through weekend if reporters stop; with requireMarketOpen false, mint/liquidate can run on stale Friday price Monday pre-open.

### F4 — BondingCurve V4 `initialize` race (graduation DoS)
**Status:** Code-level candidate, low live TVL.
**Path:** `_graduate` calls `poolManager.initialize(key, sqrtPrice)`. If permissionless pre-init of same PoolKey succeeds first, graduation reverts → final buys that would graduate fail → ETH stuck on curve (sells still work until near threshold).
**Severity if confirmed on fork:** Medium (grief / stuck graduation), not full drain.
**Next:** fork-test initialize-then-graduate on a live curve.

### F5 — Pons: no migration-squat Critical
**Status:** Killed.
- Single-sided instant V3 mint of full supply
- `getPool(...) != 0` → `PoolAlreadyExists` before deploy
- Locker has no withdraw/NFT escape hatch
- `amount0Min/1Min=0` and initial-buy `amountOutMinimum=0` are same-tx / self-harm only

## Next steps (token-efficient)
1. **Fork-prove F4** if any curve approaches 2.5 ETH graduation.
2. Map **Arrow Finance** frontend/config to confirm which CdpEngine is production; private DM on F1 if they claim multi-reporter security.
3. **SLVR MiningPool** + **RewardDistributor** source pull if balances grow.
4. Arcus/Meridian/Rialto: need app eth_call traces (browser Step 2C) — bundles timed out from this host.
5. Do not claim F1 as permissionless Critical.

## Tooling notes
- Official RPC works; publicnode flaky.
- Blockscout `search/quick` works; full `search` often empty/timeout.
- step2_bundle_grep parallel races on shared files; run sequential.
- step3_surface_map hangs on large disassemble; prefer Blockscout verified source API.

---

## Pass 2 — VaultManager + SLVR + Arcus/Rialto (2026-08-03)

### VaultManager (Loxley-style buyback vaults — LONG family)
| Addr | ETH | Notes |
|------|-----|-------|
| `0x1491709A…4679` | 0 | factory wired, 1 DIH |
| `0xE1415125…aB44` | ~0.0005 | 1 DIH |
| `0x1FB1f94E…a1de` | ~0.0004 | 1 DIH |

- Design: fees → ETH → USDG → buy mark; `poke` buyback-and-burn only. **No user redemption / drain path.**
- Auth: `registerCoin` factory-only; `wire` deployer once; `execSwap` self-only; `unlockCallback` poolManager-only.
- Soft issues: curve buy in `_buyAndBurn` uses `minOut=0` (MEV on buyback efficiency); permissionless `depositFor` can inflate NAV (grief).
- **No permissionless Critical. TVL negligible.**

### HoodCash MiningPool (SLVR-adjacent / HoodCash mining)
| Role | Address |
|------|---------|
| MiningPool | `0xf275020a10DCD04C63EC4347C41317612e727591` |
| HCASH | `0x6143bDee01d0C403E17DdC8BC1FC24714D92d02D` (40M in pool) |
| Miner NFT | `0x8FC2D503326308273d696538fc45d77d5451d2fA` |
| totalStaked | **0** |
| emissionEnd | ~4y left |

#### F6 — Underfunded claim permanently burns unpaid accrual (**PoC PASS**)
**Root:** `claim`/`unstake` update `lastClaim` to `block.timestamp` **before** `_payout`, and `_payout` silently caps to `balanceOf`.
**Impact:** If pool HCASH < pending, miner gets partial pay and loses the rest forever (even after refill).
**Auth:** none (any staker claiming while underfunded).
**Live exploitability:** **Low right now** (40M HCASH preloaded, 0 staked, default 60/day fits allocation). Becomes live if owner raises rate / underfunds / long emission overruns buffer.
**Severity:** Medium (conditional loss of earned rewards). Not a pool drain.
**Fix:** Only advance `lastClaim` proportional to amount paid, or revert if `balance < reward`.
**PoC:** `slvr/poc` → `forge test -vv` → `test_underfundedClaimBurnsUnpaidPending` **PASS**.

Admin: `setRewardRate` / `sweepUnusedRewards` Ownable-guarded (confirmed eth_call from dEaD).

### RewardDistributor
- Arbitrum-style; `distributeRewards` permissionless with correct recipient/weight hashes (by design).
- All checked instances: **0 ETH**. No finding.

### Arcus / Rialto / PerpEngine (item 4 recon)
| Contract | Address | Notes |
|----------|---------|-------|
| ArcusSettlement | `0xf31022dD…68B4` etc | Operator-gated `execute`; `sweepTokens` onlyOwner; 0 ETH |
| RialtoSettlementRouter | `0xE23747d8…4ef0` | exactInput routers |
| RialtoV4StockSwapExecutor | `0x36E90e3a…717A` | `execute` only `buyer`; setBuyer onlyOwner once |
| RialtoSwapAdapter | `0x423012D7…A43C` | allowlists owner-gated |
| PerpEngine | `0x07c716B5…597F` | open/close/liquidate; admin halt/list guarded; 0 ETH |

No free auth wins on first pass. Frontends still hide runtime configs; settlement engines look centralized-executor pattern (trust operator/buyer). Worth a deeper PerpEngine math pass later if TVL appears.

