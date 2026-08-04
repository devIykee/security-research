# bow.fun — hunt notes (no High)

**Researcher:** deviykee  
**Date:** 2026-07-21  
**Severity:** Notes only  
**Status:** Live RH factory, fork PoC. Source unverified. Nothing touched on mainnet.

## Product

Instant Uniswap V3 launch on Robinhood Chain (4663). Full supply as LP, locker holds NPM position, vanity suffix `b03`, CREATE2 `predictToken`. `launchCount` ~7460. `launchFee` = 0. Graduation threshold token `GRADUATION_WETH` = 3.7 ETH; `checkMigration` present on tokens.

## Addresses

See `hunts/bow/ADDRESSES.md`. Config: https://bow.fun/config.js

## Classic classes

| Class | Result |
|-------|--------|
| V3 pool pre-init / wrong-price dump | **Mitigated** — baseline `launch` succeeds; after attacker `createPool+initialize` on predicted token, `launch` **reverts** (empty reason). Creator can re-salt CREATE2. |
| V3 soft init factory freeze (Merry Men style) | **N/A** (V3 hard path; salt free) |
| Migration raise dump | Instant list (no bonding raise). Residual: unverified `checkMigration` / fee collect only. |
| Auth free-win | Owner-gated config; not proven open. |

## PoC

```bash
cd hunts/bow/poc
forge test --match-contract BowTest --fork-url <anvil-fork-RH> -vv
# test_baseline PASS; test_preinit PASS (launch reverts after pre-init)
```

## Residual

- Unverified source → no full audit of locker collect / migration / max-wallet.
- Re-open if factory redeployed with verified source or new migrate path that holds ETH.

deviykee
