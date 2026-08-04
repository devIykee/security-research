# Recurve — addresses (Robinhood Chain 4663)

**Website:** https://recurve.fi  
**Researcher:** deviykee · **Date:** 2026-07-20

| Role | Address | Verified |
|------|---------|----------|
| RecurveLaunchpad | `0xd41a03a01369a734a5e22c3d6484b4040ae9acfd` | yes |
| $RECURVE (docs) | `0x0FFf0c68b7dd24bDC840c73BcB8B147285653FA6` | token |

**Mitigation:** `if (slot0.sqrtPriceX96 != 0) revert PoolTaken()` before initialize  
**Report:** `reports/Recurve-hunt-notes.md`
