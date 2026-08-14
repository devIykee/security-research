# Sheriff.money — Master findings table (PRIVATE)

**Researcher:** deviykee  
**Hunt session:** 2026-08-12  
**Scope:** Sheriff AMM (Algebra Integral CLAMM + Camelot V2 + Plugins + Campaigns) on Robinhood Chain (4663)  
**Coverage:** 29/33 custom implementation files (88%). Path-scoped review.  
**Status:** 1 Confirmed Medium (code defect / sibling mismatch), 2 Lows, 2 Informational. All tested with Foundry PoC.

## Master table

| ID | Sev | Title | Component | PoC | Status |
|----|-----|-------|-----------|-----|--------|
| M-1 | Medium | `_checkStatusOnBurn` reverts when `securityRegistry == address(0)` (exit freeze) | `SecurityPlugin.sol` | `PoC.t.sol::test_burnPath_reverts_whenRegistryZero` | Open (Code Defect / Inactive On-Chain) |
| L-1 | Low | FeeHelper TWAP calculation WINDOW (1 day) does not match VolatilityOracle WINDOW (4 hours) | `SheriffFeeHelper.sol` vs `VolatilityOracle.sol` | Static / code analysis | Open |
| L-2 | Low | Campaign `cancel` does not refund remaining incentives to creator (already pushed to distributor) | `CampaignFactory.sol` | Code analysis | Open |
| I-1 | Info | `CampaignFactory` implementation contract at `0xE1eA...` left uninitialized | `CampaignFactory.sol` (impl) | `eth_call` confirmed | Open |
| I-2 | Info | `communityFeeReceiver` set to zero; accumulated fees stuck in vault | `CommunityVault.sol` | On-chain query | Open |
| KILL-AUTH | — | Probed admin/keeper selectors on live proxies; all guarded | Core proxies | Step 4 trace | Killed |
| KILL-K | — | V2 K/fee desync vs library | `UniswapV2Library.sol` | Library reads pair fee | Killed |
| KILL-DRAIN | — | AlgebraV2Adapter public `swap` leftover drain | `AlgebraV2Adapter.sol` | Adapter balance is 0 | Killed |

## Canonical write-ups

| File | Contents |
|------|----------|
| `reports/FINDINGS-MASTER.md` | This scoreboard |
| `reports/sheriff-medium-burn-registry-zero.md` | Full M-1 report |
| `reports/hunt-notes.md` | Session notes & Step 4/5 checklists |
| `reports/dm-first-contact.md` | Outreach message template |
| `coverage.md` | Audit coverage map (29/33 files) |
| `poc/` | Foundry PoC reproduction suite |

## PoC execution

```bash
cd hunts/sheriff/poc
forge test -vv
```

## Researcher

deviykee / Iyke — private until patched.
