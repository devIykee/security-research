# Hunt status — Stable Chain (Iyke playbook, Duke support)

**Date:** 2026-08-03  
**Researcher:** deviykee  
**Step progress:** 1 PASS · 2 map · 3 surface · 4 auth (admin guarded) · 5–6 partial · 7–10 not started (no verified exploit)

## Ground truth
- Chain **988** live (`https://rpc.stable.xyz`), block ~34.1M, explorer [stablescan.xyz](https://stablescan.xyz)
- Gas = USDT0 dual native+ERC20 (6dec ERC20 view, 18dec native, exact 1e12 scale)

## P0: StableEarn (value-moving core)

| Fact | Value |
|---|---|
| Vault | `0xb7Df8db22A5DBBFA9ebeb94b3910aec6a4f05c08` |
| Name / symbol | StableEarn / gtusdtb |
| Implementation | **Morpho VaultV2** (matches morpho-org/vault-v2) |
| totalAssets | ~**$30.4M** (6dec USDT0) |
| Idle USDT0 | ~**$10.9M** |
| In Morpho adapter | ~**$19.5M** |
| Share price | ~**$2.01** / 1e18 shares (yield-inflated) |
| virtualShares | 1e12 (standard 18−6 offset) |
| Gates | all `address(0)` (open) |
| Fees | performance/management = 0 |
| maxRate | set (caps donation/rate gaming) |
| forceDeallocatePenalty | **1e13 / WAD = 0.001%** (~$10 per $1M) |
| Admin | owner/curator/allocator roles; no open admin from dEaD |

### Morpho Blue markets (via adapter `0x5957…1bEe`)

| # | Collateral | LLTV | Adapter expected supply | Oracle price |
|---|---|---|---|---|
| 0 | **thBILL** `0xfDD2…5A5a` | 94.5% | ~$2.4k | ~$1.0336 |
| 1 | **sthUSD** `0xd1dB…2540` | 86% | ~**$18.6M** | ~$1.0151 |
| 2 | **sthUSD** same | 77% | ~$0.86M | same |

- Main market util high: supply ~$18.6M / borrow ~$16.8M (~90%)
- IRM shared: `0x41e8…940f`
- Morpho: `0xa401…102e`

### Oracles (Morpho Chainlink-style wrapper + RedStone)

| Market | Oracle | BASE_FEED_1 | Description | Decimals | Freshness @ hunt |
|---|---|---|---|---|---|
| thBILL | `0x4fc5…526F` | `0x7532…A62D` | RedStone thBILL_FUNDAMENTAL/USD | 8 | ~40 min old |
| sthUSD | `0xD149…254c` | `0xb811…C2Db` | RedStone sthUSD_FUNDAMENTAL | 8 | ~**6.7 h** old |

Morpho oracle wrappers **do not enforce staleness** (standard Morpho design). RWA fundamental feeds move slowly; severity depends on depeg/lag scenarios, not automatic Critical.

## Attack angles tested / status

| Angle | Result |
|---|---|
| Missing access control on vault admin | **Killed** — owner/curator/allocator guarded; deposit/withdraw need proper args + tokens |
| forceDeallocate permissionless drain | **Killed as theft** — permissionless by design; only moves liquidity to idle with share penalty; no free assets |
| forceDeallocate grief (0.001% penalty) | **Trust/UX note** — very cheap rebalance grief if you hold shares; not unauth theft |
| First-depositor inflation | **Mitigated** — virtualShares 1e12 + live TVL; seed exists |
| USDT0 dual-balance vs Morpho token assumptions | **Likely OK for VaultV2** — accounting uses `IERC20.balanceOf`, not `address(this).balance`. Still footgun for *custom* adapters/integrators that mirror native balance |
| Donation share-price pump | **Bounded** by `maxRate` (Morpho V2 design) |
| Oracle staleness / RWA lag | **Open research** — sthUSD feed ~6.7h lag observed; need depeg path + borrow/liquidation math for severity |
| thBILL/sthUSD custom token bugs | **Open** — owner-controlled, not ERC4626; mint/redeem surface not fully mapped |
| Uniswap V3 migration squat | N/A (no launchpad graduation holding raise) |
| Open admin on OFT/LiFi | Not deep-dived (LiFi codesize 254 = proxy/diamond facet; OFT owner set) |

## Ecosystem scoring (other listed projects)

| Project | Hunt ROI now | Notes |
|---|---|---|
| StableEarn | **High** | Live $30M; custom chain token + RWA oracles |
| Theo (thBILL) | **High** | Collateral for Morpho; owner `0x9487…1295` |
| sthUSD | **High** | Dominates vault allocation |
| Morpho core | Low-medium | Canonical; hunt *config + adapters + oracles* not core |
| Gauntlet / Concrete | Low without custom Stable contracts | Partner strategies |
| Stable Swap (Uni v3) | Low | Standard factory/routers from docs |
| StablePay | Frontend; SSL issues on curl; wallet UX less bounty-like |
| USDT0 / OFT Mesh | Medium | Dual token + LZ; needs dedicated bridge audit time |

## Documented chain footguns (from official docs)

1. Native balance can change **without** entering contract code (ERC-20 `transferFrom`).
2. `EXTCODESIZE` / code hash can oscillate.
3. Zero-address transfers revert.
4. Fractional 6/18 recon emits extra `Transfer` via reserve `0x5113…F7b5`.
5. Do **not** mirror native balance as independent of ERC-20.

These are **integration risks** for any custom contract on Stable. Morpho V2 publicly assumes exact ERC-20 balance deltas and no fee-on-transfer.

## What is NOT claimed
- No permissionless Critical/High with fork PoC yet.
- Owner/curator/allocator powers = **trust/centralization**, not free wins.
- No public disclosure materials (nothing live-exploitable proven).

## Next steps (if continuing)
1. Map **thBILL / sthUSD** mint/redeem/oracle update auth (selectors + source if verified).
2. Fork-test: borrow against collateral with **stale RedStone** answer; measure liquidation / bad-debt bound on main market.
3. Diff adapter bytecode vs morpho-org MorphoMarketV1Adapter; hunt deviations.
4. USDT0 exactness: fork `transfer`/`transferFrom` amount vs `balanceOf` delta under fractional dust.
5. LiFi + USDT0 OApp DVN/config if bounty scope includes bridges.
6. Only then Step 7–10 if a concrete value-moving bug survives kill-your-own-finding.

## Shell env
```bash
export RPC=https://rpc.stable.xyz CID=988
export VAULT=0xb7Df8db22A5DBBFA9ebeb94b3910aec6a4f05c08
export USDT0=0x779Ded0c9e1022225f8E0630b35a9b54bE713736
export ADAPTER=0x595727fF23c47F5a555AAe7604B653D97ebD1bEe
export MORPHO=0xa40103088A899514E3fe474cD3cc5bf811b1102e
```

---

## Deep dive (session 2) — 2026-08-03

### Collateral tokens = LayerZero OFTs (major surface)

| Token | Type | Owner | LZ endpoint | Peers (eid) |
|---|---|---|---|---|
| **thBILL** `0xfDD2…5A5a` | OFT (token()=self) | `0x9487…1295` | `0x6F47…DD5B` (eid **30396** = Stable) | 30101 eth, 30110 arb, 30184 base, **30367 hyperliquid**, **30390 monad** |
| **sthUSD** `0xd1dB…2540` | OFT + pause + blacklist hooks | `0x2bB4…CA02` | same endpoint | 30101 eth, 30102 bsc, 30110 arb |

- `lzReceive` from non-endpoint → `OnlyEndpoint` (guarded).
- `setPeer` from attacker → `OwnableUnauthorizedAccount`.
- Eth mainnet CREATE2 peers set for Stable eid 30396 (same addresses).
- Eth open `mint` reverts (no free public mint observed).
- sharedDecimals=6 matches ERC20 decimals → no OFT dust scale mismatch.

**sthUSD extras (selectors):** `pause`/`unpause`, `updateBlacklist`, `distributeBlacklistedFunds`, `emergencyPauser`, `blacklister`.
- blacklister = `address(0)`, emergencyPauser = `address(0)` → those roles inactive; owner-only paths still exist.
- Attacker `distributeBlacklistedFunds` / `updateBlacklist` / `pause` → revert (not open).

### Adapter = official MorphoMarketV1AdapterV2

- Matches morpho-org/vault-v2 `MorphoMarketV1AdapterV2` surface: `allocate`/`deallocate` only `parentVault`, `adaptiveCurveIrm`, `burnShares` timelocked, `skim` skimRecipient-only.
- Non-vault allocate/deallocate → `Unauthorized` (`0x82b42900`).
- `forceDeallocatePenalty` = 1e13 = **0.001%** (cheap exit/grief of allocation, not theft).
- `liquidityAdapter` = 0 → idle-only auto path; large exits need forceDeallocate or allocator.

### Oracles (RedStone fundamental, no circuit breakers)

| Feed | Price | Age @ probe | min/maxAnswer |
|---|---|---|---|
| thBILL_FUNDAMENTAL/USD | ~$1.034 | ~1.05 h | **none** (reverts) |
| sthUSD_FUNDAMENTAL | ~$1.015 | ~**7.05 h** | **none** |

Morpho oracle wrappers do not check `updatedAt`. Bound for bad debt on 86% LLTV market: need real collateral value ≲ **0.873 × oracle** (e.g. ~14% depeg from $1.015 while feed stuck). Not proven exploitable without a depeg path; residual risk under frozen feed + redemption crisis.

### USDT0 dual-balance

- Vault: `native == erc20 * 1e12` exact; `native % 1e12 == 0`.
- Morpho/VaultV2 account via `IERC20.balanceOf` → dual model does not double-count.
- No proof of amount-desync on standard ERC20 transfer amounts.

### Angles final table

| Angle | Severity | Status |
|---|---|---|
| Open mint / open admin collaterals | — | **Killed** |
| Open lzReceive / setPeer | — | **Killed** |
| Open distributeBlacklistedFunds | — | **Killed** (roles unset / ownable) |
| Adapter non-vault allocate | — | **Killed** |
| forceDeallocate free funds | — | **Killed** |
| Stale RedStone + LLTV over-borrow | Informational / conditional Medium | **Open only with depeg** — no PoC without price dislocation |
| Owner OFT peer / pause / future blacklist Morpho | **Trust** | Document only — can freeze or re-path mint |
| forceDeallocatePenalty 0.001% | Informational | Cheap allocation grief by large LPs |
| USDT0 dual vs Morpho | — | **Likely safe** for this stack |

### Verdict
No permissionless Critical/High with fork-proven theft after deep dive. Stack is mostly Morpho VaultV2 + MorphoMarketV1AdapterV2 + RedStone + Theo OFT collaterals. Residual value is **config/trust** (OFT owners, RWA oracles, low forceDeallocate penalty) and **conditional oracle lag under depeg**, not a free win.

### If continuing (lower ROI)
1. DVN/ULN config on thBILL/sthUSD pathways (Dead DVN / single DVN).
2. Full OFT `_credit`/`_debit` customizations vs stock OFT (bytecode diff).
3. Fork: simulate sthUSD price crash + frozen feed → max bad debt on market1.
4. Concrete/Gauntlet vaults if distinct Stable deployments appear with TVL.
