# Coverage — Liquid Royalty

Coverage: 8/13 core impl files (~62% traced). Path-scoped. Not a full audit.

Last updated: 2026-08-24 disposition

Denominator Y = 13 production impl files under `repo/LiquidRoyaltyContracts/src` excluding `interfaces/**`, `integrations/I*.sol`, and `mocks`. ProtocolVault live impls are extra and unverified this pass (not in Y).

| File | Read? | Paths traced | Notes |
|------|-------|--------------|-------|
| src/abstract/BaseVault.sol | yes | `deposit`/`mint` → `_vaultValue+=`; `_withdraw` fee+CEI; `totalAssets=_vaultValue`; `executeVaultValueAction`; `seedVault`; `_ensureLiquidityAvailable` | full value path |
| src/abstract/JuniorVault.sol | yes | `receiveSpillover`; `provideBackstop` LP transfer | |
| src/concrete/ConcreteJuniorVault.sol | yes | `initialize`/`V2`/`V3`; cooldown `_withdraw` | |
| src/abstract/UnifiedSeniorVault.sol | yes | `deposit` 1:1; `withdraw` cooldown; `rebase`; `_executeProfitSpillover`; `_executeBackstop` | |
| src/concrete/UnifiedConcreteSeniorVault.sol | yes | `_transferToJunior/Reserve` silent-0; V4 migrate; post-migration rebase mints to admin | |
| src/libraries/SpilloverLib.sol | yes | zone / 80-20 / backstop waterfall | |
| src/libraries/MathLib.sol | partial | constants + backing ratio | not every helper |
| src/libraries/RebaseLib.sol | partial | `selectDynamicAPY` waterfall | |
| src/integrations/KodiakVaultHook.sol | yes | `onAfterDepositWithSwaps`; `liquidateLPForAmount`; `transferIslandLP`; admin aggregator | |
| src/abstract/AdminControlled.sol | partial | roles / modifiers | skim |
| src/abstract/ReserveVault.sol | partial | spillover/backstop + InvestKodiak | skim |
| src/concrete/ConcreteReserveVault.sol | no | — | |
| src/libraries/FeeLib.sol | no | — | penalty math inferred from call sites |

## Explicitly excluded

| Path / area | Reason |
|-------------|--------|
| src/interfaces/** | ABI only |
| src/integrations/I*.sol | ABI only |
| src/mocks/** | mocks |
| lib/** | OZ / forge-std |
| certora/** | specs, not live |
| script/** / broadcast/** | deploy |
| ProtocolVault private repo | no source this pass; live snrUSD/ALAR-TS impls unverified |
| BeraHub reward vaults | PoL wrappers |
