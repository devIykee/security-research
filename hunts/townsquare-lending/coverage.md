# Coverage — TownSquare

Coverage: 8/Y files traced (opened % high on vaults; **traced % of full protocol is low**).
Denominator Y not the whole hub/spoke (excluded as Q3 2025 audited). Vault-side Y ≈ 12 production files (`TownSqVault.sol` + factory + Yield-Vault CreditVault/LP/RFQ/WrappedTLP/WithdrawQueue + new-yield-vault Yield/Manager/Token).

Last updated: 2026-08-24 disposition

Opened % (vault-side): 8/12 (67%). Traced % of live value-moving lending hub: **not in Y**.

| File | Read? | Paths traced | Notes |
|------|-------|--------------|-------|
| repo/TownSqVault/src/TownSqVault.sol | yes | `deposit`/`depositNative` → `_supplyToTownSq`; `initiateWithdraw` → `_withdrawFromTownSq`; `withdraw` mint-back; `skim`; `_accruedFeeAndAssets`; `reinitiateDeposit` | full read |
| repo/TownSqVault/test/SkimDrainPoC.t.sol | yes | C-01 skim vs pending withdraw | regression of a fix |
| repo/TownSqVault/test/FlowGapPoC.t.sol | partial | C-04 idle stranding, H-02 redeem, M-02 over-burn | comments vs current src |
| repo/TownSqVault/README.md | yes | deploy/init params | |
| repo/Yield-Vault/src/CreditVault.sol | yes | `swapCallback`, `epochUpdate`, `settle`, `pay`, `addCollateral` | pay gated to LP tokens |
| repo/Yield-Vault/src/TownSquareLPToken.sol | yes | `_deposit`/`_redeem`/`distributeYield`/`_transfer` | dual-ledger yield is accounting-only |
| repo/Yield-Vault/src/WrappedTLP.sol | yes | `wrap`/`depositAndWrap`/`instantRedeem` | share-denominated wNLP |
| repo/Yield-Vault/src/TownSquareRFQPool.sol | partial | `tradeRFQT` → `_transferAndCallback` | router+signer gated |
| repo/new-yield-vault/src/Yield.sol | partial | `distributeYield` comment on amount vs feeAmount | rebalancer-gated; not live-mapped |

## Explicitly excluded

| Path / area | Reason |
|-------------|--------|
| Q3 2025 hub/spoke (`ts-crosschain-protocol` Hub/LoanManager) | Sherlock + Astrasec; bytecode not diffed this pass |
| `crosschain-contracts-hub` / `spoke` | Cosmos/Rust, not live Monad custody |
| Move-era Aptos repos | not Monad |
| lib/** / node_modules/** / test/** | vendored / fixtures |
| TownSqVaultFactory.t.sol compile | ABI drift, tests did not run |
