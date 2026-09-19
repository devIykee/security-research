# Saga Mustang - SG-01 KILLED / FALSE POSITIVE
**Researcher:** deviykee
**Original claim:** openTrove paths missing isBranchActive guard allow minting Bold against delisted collateral after branch removal.
**Final status:** DISPROVEN by executable PoC on 2026-08-25. Not a vulnerability. Do not disclose.

## What happened
A code-review pass flagged BorrowerOperations.openTrove (:206) and openTroveAndJoinInterestBatchManager (:247) as lacking the `require(isBranchActive())` present on all other debt-increase paths (:407,:424,:479,:499), with BoldToken-side failsafe also absent.

The fork-based PoC proved the claim wrong:

```
forge test --match-contract SG01RemovedBranchOpenTrove   (saga/poc)
[FAIL: "TroveManager: Collateral is not active"]
```

Sequence executed in PoC:
1. Deployed full 2-branch Liquity V2 stack from repo harness (real contracts, not mocks).
2. Alice opened trove #x on branch 1 while active - succeeded.
3. Governor removed branch 1 (`removeCollateral(1)`), `isActiveCollateral == false`.
4. Guarded op `withdrawBold` reverted - guard present as expected.
5. Attacker attempted fresh `openTrove` on the removed branch - **REVERTED** with "TroveManager: Collateral is not active".

## Why the claim failed
While BorrowerOperations lacks an EARLY require, the actual mint path routes through `TroveManager.onOpenTrove` / `onOpenTroveAndJoinBatch`, both of which call `_requireIsActiveBranch()` (TroveManager.sol:1271,1328 -> :1246):
```solidity
function _requireIsActiveBranch() internal view {
    require(isActive(), "TroveManager: Collateral is not active");
}
```
The failsafe exists, just one layer deeper than the review looked.

## Residual notes (not vulnerabilities)
- Governor can mutate MCR/CCR/SCR/debtLimit instantly without timelock (trust/config note; 2-step governor transfer confirmed).
- BatchSender dust-lock on overpayment remainder (cosmetic).

## Artifacts
- Disproof PoC: `hunts/cosmos-evm/saga/poc/mpov/DeploymentCore.t.sol` (contract SG01RemovedBranchOpenTrove)
- Live state check 2026-08-25: all 8 branches active on CollateralRegistry 0xf39b...c22 (precondition unmet anyway)

Disclosure action: NONE. No contact made. dm-mustang.md withdrawn before sending.
