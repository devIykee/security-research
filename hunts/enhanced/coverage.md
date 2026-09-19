# Coverage — Enhanced

Coverage: 3/22 files (14%), one partial. **Hunt abandoned — see `DISPOSITION.md`.**

`Coverage incomplete: 14% (3/22). Findings apply to examined paths only.`
No findings were confirmed and none reached PoC. This is not an audit.

Denominator Y = 22 production `.sol` files under `src/` excluding `src/core/mocks/**`
and pure-interface files (`src/**/interfaces/**`). Interfaces read as needed for
signatures but not counted.

Last updated: hunt stood down (target dropped: audited + deployed code matches
audited repo + ~$173k TVL + no bounty program)

| File | Read? | Paths traced | Notes |
|------|-------|--------------|-------|
| src/periphery/vault/EnhancedVault.sol | no | — | 1781 L, primary target. Deployed bytecode diffed IDENTICAL to repo HEAD. Logic not read. |
| src/periphery/vault/libs/EnhancedVaultRecordsLib.sol | no | — | 443 L. Deployed source diffed IDENTICAL. Logic not read. |
| src/periphery/vault/libs/EnhancedVaultCycleLib.sol | no | — | 135 L. Deployed source diffed IDENTICAL. Logic not read. |
| src/core/EnhancedOptions.sol | partial | `ingressoTransferAsset` → `_doTransferAsset` → `mmarket.operate`; `ingressoMMarketDeposit` → `_doDepositTransferAsset` (effectivePayer sig check); composite deposit-and-open | 1059 L. Read state layout, error set, transfer paths only. RFQ position/settle paths NOT read. |
| src/core/libs/EnhancedOptionsTimelockLib.sol | yes | schedule / execute / cancel / pendingConfigUpdate for all 4 configTypes; instant revoke paths; `_requireReady` 48h gate | 341 L, POST-AUDIT, unaudited. Read in full. Caller-side auth in EnhancedOptions.sol NOT verified. |
| src/core/libs/Parser.sol | yes | `parseQuoteAndConfirmation` 377-byte assembly layout; `parseTransfer` 130/150-byte; `quoteStructHash` / `confirmationStructHash` / `transferStructHash` type strings | 241 L. Read in full. Confirmed `fee` (M-4) and `payer` absent from type strings. |
| src/core/MMarket.sol | no | — | 160 L, maker balance ledger. **Needed to close the `payer` lead; not read.** |
| src/core/libs/MMarketOperations.sol | no | — | 49 L |
| src/core/Controller.sol | no | — | 958 L, Opyn-derived |
| src/core/ControllerLogic.sol | no | — | 609 L |
| src/core/MarginCalculator.sol | no | — | 1279 L |
| src/core/MarginPool.sol | no | — | 256 L |
| src/core/Oracle.sol | no | — | 367 L |
| src/core/ManualPricer.sol | no | — | 148 L |
| src/core/Otoken.sol | no | — | 285 L |
| src/core/OtokenFactory.sol | no | — | 270 L |
| src/core/Whitelist.sol | no | — | 265 L |
| src/core/AddressBook.sol | no | — | 264 L |
| src/core/libs/Actions.sol | no | — | 311 L |
| src/core/libs/MarginVault.sol | no | — | 190 L |
| src/core/libs/Parser.sol | no | — | 241 L |
| src/core/libs/FixedPointInt256.sol | no | — | 199 L |
| src/core/packages/BokkyPooBahsDateTimeLibrary.sol | no | — | 74 L, vendored date lib |

## Explicitly excluded

| Path / area | Reason |
|-------------|--------|
| lib/** | vendored deps (OZ 5.6.1, forge-std) |
| test/** | test fixtures |
| script/** | deploy scripts (read only for addresses/config) |
| src/core/mocks/** | mock ERC20 |
| src/**/interfaces/** | pure interfaces, read for signatures only |
