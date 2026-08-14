# Aumo — Master findings table (PRIVATE)

**Researcher:** deviykee  
**Hunt session:** 2026-08-10  
**Scope:** AumoPool, AumoVault, AaveV3Adapter, RwaUsdgAdapter (source / pre-mainnet)  
**Status:** All Highs PoC-backed. Critical: 0 strict-theft; 1 Critical-class amplification (C-1 dust full liq). Reports consolidated below.

## Master table

| ID | Sev | Title | Component | PoC | Status |
|----|-----|-------|-----------|-----|--------|
| C-1 / H-CRIT | High (Critical-class scaling) | Dust withdraw (1 USDT0) forces lastPass full liquidation of lossy/RWA venue; O(TVL) exit+MEV for O(1) redeem | AumoPool._ensureIdle lastPass max | DustLastPass FULL LIQ | Open |
| H-1 | High | Unrealizable NAV → preferential drain of healthy venue | AumoPool totalAssets / redeem | Residual + Adv1 PreferentialRedeem | Open |
| H-2 | High | Loss budget double-counts entry fill → agent cannot retreat | AumoPool allocate / _doDeallocate | Logic L2 | Open |
| H-3 | High | Silent zero-return withdraw wipes principal, frees caps | AumoPool _doDeallocate | Logic L3 | Open |
| H-4 | High | maxWithdraw overstates liquid assets | ERC4626 via totalAssets | Logic L8 | Open |
| H-5 | High | Permissionless redeem-path sandwich on USDG retreat (stranger, no role; ≤maxSlippage per venue turnover, agent-gated refill) | _ensureIdle → RwaUsdgAdapter.withdraw | RedeemSandwich + real-adapter analysis | Open |
| H-5 / M-MEV | Medium (High if large RWA TVL) | Permissionless sandwich on redeem-path USDG→USDT0 swap; loss socialized to remaining LPs; bound maxSlippageBps | RwaUsdgAdapter._swap via _ensureIdle | RedeemSandwich 3/3 | Open |
| M-1 | Medium | balanceOf revert bricks _ensureIdle (view/pull asymmetry) | AumoPool _ensureIdle | Adv5 + Residual R2 | Open |
| M-2 | Medium | Dual ledger: allocated gross vs supplied/live | AumoPool allocate | Logic L4 / Adv2 | Open |
| M-3 | Medium | Epoch length couples deploy window; resets uncoupled | budgets | Logic L5 | Open |
| M-4 | Medium | Discounted balanceOf sizes face pulls | RWA + _ensureIdle | Logic L7 | Open |
| M-5 | Medium | maxEpochDeploy default 0 re-opens redeem-path churn if USDG | policy defaults | code | Open |
| L-1 | Low/Trust | Owner forceRemove writes off NAV | forceRemoveVenue | Adv1 Owner | Trust |
| L-2 | Low | Unbounded _venues gas in totalAssets | _venues list | Adv4 | Open |
| L-3 | Low | lastPass max can over-peel lossy venue by allowlist order | _ensureIdle | Logic L1 | Open |
| L-4 | Low | RWA setSlippage/setValuation no events | RwaUsdgAdapter | Slither | Open |
| ACK-1 | Info | Compromised agent cannot send to arbitrary EOA | trust model | Adv1 agent | By design |
| ACK-2 | Info | Owner + evil allowlisted venue = full loss | trust model | docs | By design |
| KILL-C | — | No permissionless Critical free drain | — | CriticalHunt 10/10 | Killed |
| KILL-TMP | — | Temporary Uni sandwich + restore is not theft | — | Kill temporary stuck | Killed |
| KILL-INF | — | First-depositor inflation unprofitable (offset 6) | ERC4626 | CriticalHunt | Killed |
| KILL-SLITHER-H | — | Slither reentrancy-balance High is FP | _doDeallocate | triage | FP |
| KILL-CRIT-2 | — | Critical pass 2 (2026-08-10): H1-as-stranger net profit, dust last-pass full liq, inflation recheck, agent-depositor churn all dead | AumoPool | CriticalPush 4/4 | Killed |
| H-5-NOTE | — | Sandwich >2% floor reverts the retreat (loss capped); ramp needs agent refill = not unbounded | RwaUsdgAdapter | RedeemSandwich test 2 | Killed-as-Crit |

## Canonical write-ups (all under `hunts/aumo/`)

| File | Contents |
|------|----------|
| `reports/FINDINGS-MASTER.md` | This scoreboard |
| `audit/audit-report.md` | Multi-angle report (H-1..H-4, M-1..) |
| `reports/H1-nav-preferential-exit.md` | H-1 detail |
| `reports/logic-bugs.md` | L2–L8 complex logic |
| `reports/structured-audit.md` | Foundation maps + Slither |
| `reports/hunt-notes.md` | Session notes + INTAKE |
| `poc/*.sol` | Foundry PoC copies |
| `reports/H5-redeem-path-sandwich.md` | Redeem-path MEV sandwich |
| `reports/C-candidate-dust-redeem-full-liquidation.md` | Dust→full liquidation |

## PoC commands

```bash
cd hunts/aumo/repo/contracts
forge test --match-contract 'AumoPoolResidualTest|AumoPoolCriticalHuntTest|AumoPoolLogicBugsTest|AumoPoolAdversarialAnglesTest'
```

## Remediation priority

1. Realizability-aware NAV + honest maxWithdraw (H-1, H-4)  
2. Book `supplied` + loss budget on marked basis (H-2, M-2)  
3. Revert/restore if withdraw returns 0 (H-3)  
4. try/catch balanceOf in _ensureIdle (M-1)  
5. Decouple epoch counters; fail-closed deploy budget when lossy venues live  

## Disclosure

Private. Pre-mainnet timing. Researcher: deviykee / Iyke.
