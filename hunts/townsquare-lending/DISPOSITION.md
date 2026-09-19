# TownSquare — hunt disposition (24 Aug 2026)

**Researcher:** deviykee
**Status:** Path-scoped intake + recon. **No permissionless Critical confirmed.** No Step 7/9.
**Coverage:** incomplete (see `coverage.md`). Findings apply to examined paths only.

## Verdict

**Do not deep-dive the Q3 2025 hub/spoke lending core this session.** It is a Folks-style money market with two published Q3 2025 audits (Sherlock collaborative + Astrasec). Live TVL is real but modest (~$0.54m lending + ~$0.21m loop vaults; DefiLlama parent ~$753k). The app-claimed ~$46m is inflated; DefiLlama warns about unproductive positions.

**Post-audit custom custody that looked like the edge does not currently hold material funds:**

| Surface | Live funds | Notes |
|---------|------------|-------|
| `TownSqVault` proxy `0x96ed8d9a…dfcfb1` ("USDC TURTLE VAULT", V2) | **$0** USDC. `totalAssets=0`, leftover `totalSupply≈0.2` shares | Upgradeable ERC-4626 2-step vault. Repo already contains patched C-01 skim drain + C-02 fToken dust notes. Empty, not a payout target. |
| TownSquare CreditVault `0x6B00868e…97E7` | Dust (enzoBTC ~2.2e6 raw, rwaUSDi $3) | Owner = signer = epochUpdater = feeWithdrawer `0x131Cc648…`. Trust concentration. `minRedeemInterval=0`, `earlyWithdrawFeeBips=0`. |
| Native-curated CreditVault `0xcD1D2D60…e5B4` | **The ~$210k loop TVL** (≈81 WETH + 0.17 cbBTC + $94 USDC + 4 WMON) | LP tokens are branded `Native-LP:*`. White-label Native credit vault, not unaudited TownSquare math. |
| Lending pools (DefiLlama adapter) | **~$0.54m** (MON pool is the bulk; USDC ~$24.5k dep / $18.2k bor; earnAUSD ~$46k if 6dp) | `getDepositData` / `getVariableBorrowData`. Folks-style. Q3 2025 audited. |

## HARD-criteria gate

| Criterion | Result |
|-----------|--------|
| Live on-chain TVL | PASS (~$0.75m parent; re-verified pool views + CreditVault LP `totalUnderlying`) |
| Permissionless entry | PASS on lending deposit/borrow/withdraw/liquidate; PASS on LP `deposit`/`redeem` |
| 0–1 audit | **FAIL.** Docs: two Q3 2025 audits. GitHub `TowneSquare/audit-reports-2025Q3`. pkqs90 also lists a Sherlock collaborative "Townsquare" dated 14 Aug 2026 (unpublished on docs). |
| Not on Immunefi/Cantina/H1 | PASS (no live public bounty found; Sherlock was collaborative audit, not a public contest) |
| Funded + reachable | PASS. $17.57m raised. X `@TownSquarexyz`. Docs + GitHub org. |
| Post-audit new code with funds | **Thin.** TownSqVault/new-yield-vault/Yield-Vault exist and were updated Jul–Aug 2026, but live balances in those custom contracts are dust. Loop TVL is Native-curated. |

## Killed / not-Critical paths

1. **C-01 skim drain** (`skim`/`skimNative` pulling funds parked between `initiateWithdraw` and `withdraw`): **fixed** in current `TownSqVault.sol` (`onlyOwner` + `CannotSkimVaultAsset`). Repo test is a regression, not a live exploit.
2. **H-02 fake ERC-4626 `redeem`:** current src **reverts** `UseInitiateWithdraw()`.
3. **WrappedTLP cooldown griefing** (one wrap resetting `lastDepositTimestamp` for the wrapper): **dead on live params** (`minRedeemInterval=0`, `earlyWithdrawFeeBips=0`).
4. **Uncapped `reserveFee` in `epochUpdate`:** only callable by `epochUpdater`. On TS vault that is the same EOA as owner. **Trust/centralization**, not a stranger Critical.
5. **FlowGap C-04 stranded idle after failed payout:** current src caps with `freeIdleBalance`. Local PoC suite did not compile (unrelated `TownSqVaultFactory.t.sol` ABI drift). Not claimed live. TVL=0 anyway.

## Leftover leads (only if TVL grows)

- Re-check `TownSqVault` if deposits return. Dual-ledger: `lostAssets` ratchet vs idle cash vs `_expectedSupplyAssets()` (TownSq collateral only).
- `earnAUSD` stock-price oracle node `0xacC0a0cF…fd62` if that market's live book is material.
- Native CreditVault vs upstream Native source: only hunt a **diff**, and only if Native has no bounty.

## Contacts (not for a live bug)

Official: https://docs.townsq.xyz , https://www.townsq.xyz/ , https://x.com/TownSquarexyz
Audits page: https://docs.townsq.xyz/security/audits.md — "2 audits in Q3 2025"; "Further audits will be published here."
No `security@` harvested this pass (Step 10A not completed; no report to send).
