# Aumo multi-angle adversarial audit (private index)

All files for this hunt live under `hunts/aumo/` only.

| Path | Role |
|------|------|
| `reports/FINDINGS-MASTER.md` | Master findings table |
| `audit/audit-report.md` | Full multi-angle report |
| `audit/audit-context.md` | Scope / assumptions |
| `audit/audit-debug.md` | Debug log |
| `reports/logic-bugs.md` | Complex dual-ledger bugs |
| `reports/structured-audit.md` | Maps + Slither triage |
| `reports/H1-nav-preferential-exit.md` | H-1 deep dive |
| `poc/` | Foundry PoC copies |

## Skills used
- iykes-web3-bughunt-skill (lead)
- forefy: smart-contract-audit, tiny-auditor, foundry-poc

## PoC summary
| Suite | Result |
|-------|--------|
| AumoPoolAdversarialAnglesTest | 12/12 PASS |
| AumoPoolLogicBugsTest | 8/8 PASS |
| Residual + CriticalHunt | 12/12 PASS |

## Top findings
H-1 NAV preferential exit · H-2 loss budget double-count · H-3 phantom principal wipe · H-4 maxWithdraw lie  
Critical: **0**
