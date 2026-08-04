# Flap (RH) — hunt notes (no High)

**Researcher:** deviykee  
**Date:** 2026-07-21  
**Severity:** Notes only — no permissionless High PoC completed  
**Status:** Portal verified; migrators mapped by bytecode; fork/eth_call only.

## What this is

Multi-chain launchpad (Flap). On Robinhood Chain: bonding curve → DEX migration, tax/non-tax tokens, vault modules. Portal is a TransparentUpgradeableProxy holding **~60 ETH** (live balance at hunt). Product is mature (changelog through v5.x with explicit migration price-jump fixes).

## Surface

| Piece | Notes |
|-------|--------|
| Portal | Verified `Portal` / `PortalBase` — dispatcher + facets via immutable addresses |
| Trade | `buy`/`sell` on Portal currently `FeatureDisabled`; live trade via TradeV2 facet |
| Launch | `newTokenV2`…`V7`, `commitNewTokenV5`, two-step launchers |
| Migration | V2 / V3 / V4 / PCS Infinity migrator immutables; auto when curve hits DEX thresh |
| UniV3 migrator bytecode | Contains `getPool`, `createPool`, `initialize(uint160)`, NPM `mint(...)` with min amounts in struct |

## Classic High classes

| Class | Result |
|-------|--------|
| V3 migration pool squat | **Lead, not proven.** Migrator has `getPool` + `createPool` (not `createAndInitializePoolIfNecessary`). Changelog: *“v5.5.0 - Does not allow price jump when fallback to V2 migrator”*, *“v4.6.3 - fix price discrepancy on PortalUniV2Migrator”*. Suggests prior price bugs fixed; need verified migrator source or end-to-end migrate fork to claim High. |
| V4 pre-init freeze | V4 PM/NPM present; RH path may use V3 primary. Not PoC’d. |
| Auth free-win | Roles (`DEFAULT_ADMIN`, `GUARDIAN`, etc.) on Portal; no open admin found this pass. |
| Instant list squat | N/A for curve path. |

## Why no High this pass

1. UniV3/V2 migrator **source not verified** on chain 4663 (large runtime only).  
2. Backend token list API Cloudflare-blocked; no easy “near graduation” live target for fork migrate.  
3. Claiming squat without migrate PoC would violate honest severity.

## Residual / re-open checklist

- Verify or decompile `PortalUniV3Migrator` at `0xa80c…7dd4`: does `createPool` path check `getPool==0` and/or re-read `slot0` after init; mint mins.  
- Fork: find Tradable token with progress ≈ 1e18, pre-`createPool+initialize` at wrong price, buy past thresh, measure raise vs attacker.  
- V4 migrator / hook fee modules if RH uses V4 listing.  
- Tax token dividend / claim helpers.

## Addresses

`hunts/flap/ADDRESSES.md` · Portal proxy `0x26605f322f7fF986f381bB9A6e3f5DAb0bEaEb09`

deviykee
