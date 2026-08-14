# Audit context — Aumo multi-angle pass

**Project:** Aumo (USDT0 autonomous RWA/Aave yield pool on X Layer)  
**Researcher:** deviykee  
**Date:** 2026-08-10  
**Method:** Adversarial roleplay + economic + state/AC + edge + external integration angles  
**Skills:** forefy smart-contract-audit, tiny-auditor, foundry-poc; Iyke lead playbook  

## Assumptions
- Pre-mainnet / mainnet pool address not live in web config
- Owner is trusted root (documented); agent semi-trusted
- USDT0 is standard 6dp (not FoT) on X Layer
- USDG/USDT0 Uni pool is relatively deep (~$1M+ each side)

## Boundaries
- Permissionless Critical = unauthenticated unbounded theft without rare conditions
- High may require multi-venue + stuck venue or privileged mis-ops on agent budgets

## Finding summary (this + prior passes)
- Critical: 0
- High: preferential NAV exit (R1), loss-budget double-count freeze (L2), phantom principal wipe (L3), maxWithdraw lie (L8)
- Medium: deploy budget default, epoch coupling, discounted pull units, balanceOf brick
- Low/Trust: owner forceRemove, gas O(n) venues, MEV sandwich on agent swaps
