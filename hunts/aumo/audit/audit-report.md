# Aumo Multi-Angle Adversarial Audit Report

**Researcher:** deviykee  
**Scope:** `AumoPool`, `AumoVault`, `AaveV3Adapter`, `RwaUsdgAdapter`  
**Skills:** forefy `.context` (smart-contract-audit, tiny-auditor, foundry-poc)  
**Status:** Private research. Local Foundry PoCs only. No mainnet state touched.  
**PoCs:** `AumoPool_AdversarialAngles.t.sol` (12/12), `AumoPool_LogicBugs.t.sol` (8/8), residual/critical suites  

---

## Executive Summary

Aumo is a multi-strategy ERC-4626 yield vault. Custody for external attackers is mostly sound: no path for a stranger to allocate, no path for a compromised agent to pull USDT0 to their own wallet, and Pool allocate uses CEI + `nonReentrant`.

The dangerous surface is **cross-module accounting**: principal book vs adapter NAV vs cash returned, plus multi-venue redeem when one venue fails while still priced. That is where High findings live. No permissionless Critical (unbounded free drain) was proven.

---

## Findings Summary Table

| ID | Risk | Status | Component |
|----|------|--------|-----------|
| H-1 | High | Open | AumoPool redeem / totalAssets multi-venue |
| H-2 | High | Open | AumoPool loss budget vs allocate book |
| H-3 | High | Open | AumoPool `_doDeallocate` zero-return |
| H-4 | High | Open | AumoPool maxWithdraw / NAV |
| M-1 | Medium | Open | AumoPool `_ensureIdle` balanceOf |
| M-2 | Medium | Open | allocate gross vs supplied |
| M-3 | Medium | Open | epoch length coupling |
| L-1 | Low | Open | owner forceRemove / trust root |
| L-2 | Low | Open | gas O(n) venues |
| ACK | Info | Acknowledged | agent cannot arbitrary withdraw (by design) |

---

## Angle 1 — Adversarial roleplay

### Three drain paths attempted

1. **Preferential redeem (works under stuck venue)**  
   Deposit as minority LP, wait until funds split across stuck+healthy, redeem full face claim paid from healthy. Victim full redeem reverts.  
   PoC: `test_Adv1_DrainPath_PreferentialRedeem` PASS → **H-1**

2. **Stranger allocate / retreatSelf**  
   Reverts `NotAgent` / `NotSelf`. PoC PASS. Dead path.

3. **Compromised agent self-send**  
   Agent can only move pool ↔ allowlisted venues. After allocate/deallocate, attacker USDT0 balance unchanged; pool still holds deposits. PoC PASS. Dead as theft.

### Freeze / DoS

- All venues stuck: redeem reverts, NAV still full → **soft lock** until owner acts. PoC `test_Adv1_Freeze_AllVenuesStuck` PASS. Severity High if both venues fail; more typically Medium temporary if Aave-only.

### Compromised owner maximum damage

- `forceRemoveVenue` zeros NAV while aTokens remain in adapter; shareholders redeem for 0. PoC PASS.  
- `setVenueAllowed(evil)` + `setAgent(self)` can route all deposits to a malicious adapter (documented trust root) → full TVL. **L-1 / Trust**, not permissionless.

---

## Angle 2 — Economic and math

### Donation / free mint

- First-depositor inflation: mitigated by `_decimalsOffset = 6` (prior suite).  
- Live-TVL donation: donor put 1k+9k, victim put 10k; donor out ~10k, victim ~10k — **no free profit**. PoC PASS.  
- Dust round-trip cycles: no free mint. PoC PASS.

### Flash loan / oracle

- No Chainlink. “Oracle” is adapter `balanceOf` (aToken face × discount). Flash-inflating aToken balance would require supplying to Aave as the adapter (only vault). Spot depeg on Uni does not change NAV until withdraw.  
- Flash loan does **not** open a free share mint; temporary Uni manip + restore does not steal (prior kill test).

### Accounting desync (book vs cash)

- Gross `allocated` vs post-entry live: PoC PASS → **M-2 / feeds H-2**  
- Phantom zero-withdraw principal wipe: LogicBugs L3 → **H-3**

---

## Angle 3 — State manipulation and access control

| Function class | Control | CEI |
|----------------|---------|-----|
| deposit/mint/withdraw/redeem | public + nonReentrant (+ pause on deposit) | OZ + `_ensureIdle` before transfer |
| allocate | onlyAgent + pause + nonReentrant | effects then deposit |
| deallocate | onlyAgent + nonReentrant | effects then withdraw (Pool) |
| retreatSelf | self-only | via _doDeallocate |
| policy/pause/venues | onlyOwner | n/a |
| adapter deposit/withdraw | onlyVault | n/a |

- Vault.deallocate still writes `allocated` **after** withdraw (CEI inverted) but nonReentrant + onlyAgent limits impact.  
- Reenter allocate from venue deposit blocked. PoC PASS.  
- No proxy / re-init surface.

---

## Angle 4 — Edge cases

- **Gas:** `totalAssets` / `_ensureIdle` loop all `_venues` (never shrinks until prune). n=15 works; large n is owner DoS latent → **L-2**  
- **Timestamp:** daily epoch budgets; ±seconds irrelevant  
- **Overflow:** Solidity 0.8.24 checked math; no raw unchecked on value paths  
- **lastPass max pull:** can over-peel lossy venue (LogicBugs L1)

---

## Angle 5 — External integrations

| External | Failure mode | Pool reaction | Finding |
|----------|--------------|---------------|---------|
| Uni swap (RWA) | reverts past floor | try/catch skip venue | enables H-1 bank-run |
| Aave pause | withdraw reverts | same | H-1 / freeze |
| Adapter balanceOf reverts | pricing try/catch OK | `_ensureIdle` no try → brick | **M-1** |
| Weird ERC20 FoT | not expected for USDT0 | OZ pulls nominal amount | residual if asset changes |
| Fee / rebasing | out of design | would desync | assume standard USDT0 |

Redeem from healthy while Uni-like stuck: PASS (`test_Adv5_ExternalFail_IsolatedRedeemFromHealthy`).

---

# Findings

## H-1 Preference of healthy liquidity via unrealizable NAV

**Severity:** High  
**Probability:** Medium (needs multi-venue + persistent venue non-exit)  
**Locations:** `AumoPool.totalAssets`, `_ensureIdle`, `RwaUsdgAdapter.balanceOf` / `withdraw`

**Description:**

AumoPool is a multi-strategy ERC-4626 vault that prices shares from idle balances plus every listed adapter `balanceOf`.

During the audit it was found that a venue can remain fully counted in NAV while `withdraw` reverts (USDG depeg past slippage floor, Aave pause). Redeem isolation skips the failed withdraw and settles claims from healthy venues.

Although temporary one-block AMM manipulation that is restored does not leave residual LPs insolvent, a persistent stuck-but-priced venue lets early redeemers take face claims from the healthy leg.

An attacker that already holds shares can exit at full NAV while slower depositors are left with the illiquid bag.

**Attack Flow:**
- Agent allocates across RWA + Aave
- RWA withdraw becomes permanently reverting; balanceOf still positive
- Attacker redeems max shares → paid from Aave
- Victim full redeem reverts or is under-collateralized in liquid terms

**Remediations:**
- Mark non-realizable venues at 0 in NAV (health probe / owner flag / depeg oracle)
- Or pro-rata redeem only against successfully withdrawn venues
- Override `maxWithdraw` to liquid capacity only
- Prefer Aave-only until RWA exit is realizability-aware

**PoC:** `test_Adv1_DrainPath_PreferentialRedeem`, residual NAV tests

---

## H-2 Loss budget double-counts entry fill and freezes agent retreat

**Severity:** High  
**Probability:** Medium (RWA live + tight maxEpochLoss sized for exit-only)  
**Locations:** `AumoPool.allocate`, `_doDeallocate` loss metering

**Description:**

Allocate books gross `amount` into `allocated` while RWA `deposit` returns post-swap `supplied` and NAV already reflects entry loss.

Deallocate charges `pulledPrincipal - returned` against the loss budget using the gross book, so entry loss is metered again on exit.

Although this is fail-closed for value destruction, a normal RWA round-trip can exceed a budget that operators sized for exit cost only, freezing legitimate agent de-risk.

**Attack Flow:**
- (Ops) set maxEpochLoss ≈ expected exit bps only
- Agent allocate into RWA (entry burn)
- Agent deallocate full position → LossBudgetExceeded
- Position stuck on agent path; only user redeem or owner budget raise works

**Remediations:**
- Book `allocated += supplied`
- Meter loss vs marked post-entry basis
- Document that budgets must cover entry+exit if gross booking remains

**PoC:** `test_Logic_LossBudget_DoubleCountsEntryFill`

---

## H-3 Silent zero-return withdraw wipes principal and frees caps

**Severity:** High  
**Probability:** Low (needs adapter that returns 0 without revert while balanceOf > 0)  
**Locations:** `AumoPool._doDeallocate`

**Description:**

`_doDeallocate` decrements principal before `withdraw`. User path does not require `returned > 0`.

A non-reverting empty withdraw (buggy or malicious allowlisted adapter) burns principal accounting while face remains in the venue, reopening `totalDeployed` headroom under caps.

Although honest Aave/RWA adapters typically revert or align balanceOf with withdrawable cash, the pool contract does not enforce that invariant.

**Attack Flow:**
- Owner allowlists defective venue (or bug in adapter)
- Partial user redeem triggers retreatSelf on that venue
- Principal reduced, zero cash returned
- Agent allocates into freed cap; real face > book

**Remediations:**
- Revert (or restore principal) if `returned == 0` for nonzero pull
- Optionally require returned within tolerance of min(amount, live)

**PoC:** `test_Logic_SilentZeroWithdraw_WipesPrincipal_WhenIdleShort`

---

## H-4 maxWithdraw overstates liquid assets

**Severity:** High  
**Probability:** Medium (same conditions as H-1)  
**Locations:** inherited ERC4626 `maxWithdraw` via `totalAssets`

**Description:**

EIP-4626 `maxWithdraw` is derived from share claim against full NAV, including unrealizable venue value.

Callers and UIs that trust maxWithdraw will overpromise exits. `withdraw(maxWithdraw)` can revert while partial withdraws implement H-1.

**Attack Flow:**
- Multi-venue with stuck leg
- Observe maxWithdraw >> liquid
- Use partial withdraw / redeem to drain healthy liquidity

**Remediations:**
- Override maxWithdraw/maxRedeem to min(claim, liquid probe)
- Fix NAV realizability (H-1)

**PoC:** `test_Logic_MaxWithdraw_OverstatesLiquid`

---

## M-1 balanceOf revert bricks _ensureIdle

**Severity:** Medium  
**Probability:** Low  
**Locations:** `AumoPool._ensureIdle` vs `totalAssets` try/catch asymmetry

**Description:**

`totalAssets` try/catches adapter `balanceOf`. `_ensureIdle` does not. With idle empty, a single reverting balanceOf aborts all redemptions that need a venue pull even if another venue is healthy.

**PoC:** `test_Adv5_BalanceOfRevert_BricksEnsureIdle`

**Remediations:** try/catch balanceOf in `_ensureIdle` (mirror totalAssets).

---

## M-2 / M-3 (condensed)

- **M-2** Gross vs supplied dual ledger (feeds H-2). PoC Adv2 desync.  
- **M-3** `lossEpochLength` drives deploy rollover; setLossBudget/setDeployBudget reset different counters. PoC Logic L5.

---

## L-1 Owner forceRemove write-off

Owner can zero NAV while funds sit in adapter; shareholders redeem 0. Trusted role. PoC Adv1 Owner.

## L-2 Unbounded venue list gas

Owner-controlled `_venues` growth; totalAssets O(n). PoC Adv4 n=15 OK, risk at scale.

---

## Killed Critical candidates

| Candidate | Result |
|-----------|--------|
| Stranger drain | Blocked |
| Compromised agent arbitrary withdraw | Blocked |
| Donation free mint | No profit beyond capital |
| Rounding free mint | Dead |
| Temporary Uni sandwich theft | Dead (prior) |
| Inflation first depositor | Offset-6 (prior) |

---

## PoC commands

```bash
cd hunts/aumo/repo/contracts
forge test --match-contract AumoPoolAdversarialAnglesTest -vv
forge test --match-contract AumoPoolLogicBugsTest -vv
forge test --match-contract 'AumoPoolResidualTest|AumoPoolCriticalHuntTest' -vv
```

---

## Remediation priority

1. Realizability-aware NAV + honest maxWithdraw (H-1, H-4)  
2. Book supplied + fix loss budget basis (H-2, M-2)  
3. Revert on zero returned withdraw (H-3)  
4. try/catch balanceOf in _ensureIdle (M-1)  
5. Decouple epoch counters (M-3)

deviykee
