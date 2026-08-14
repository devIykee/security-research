# Aumo — complex logic bugs (private)

**Researcher:** deviykee  
**Focus:** multi-step accounting / control-flow, not textbook reentrancy  
**PoC suite:** `contracts/test/AumoPool_LogicBugs.t.sol` — **8/8 PASS**  
**Date:** 2026-08-10

---

## Executive scoreboard

| ID | Sev | Title | Trust needed |
|----|-----|-------|--------------|
| **L2** | **High** | Loss budget double-counts entry fill → agent cannot retreat after normal RWA round-trip | none (agent ops break) |
| **L3** | **High** | Silent `withdraw→0` (no revert) wipes `allocated` / frees caps while face stays locked | buggy or malicious venue |
| **L8** | **High** | `maxWithdraw` overstates liquid (stuck value in NAV) — EIP-4626 lie + enables R1 | multi-venue stuck |
| **L4** | Medium | Dual ledger: `allocated += amount` not `supplied` | any fill-lossy venue |
| **L5** | Medium | `lossEpochLength` couples deploy-window rollover; resets uncoupled | owner ops |
| **L7** | Medium | Discounted `balanceOf` sizes pulls in face units → principal/live desync | RWA valuationDiscount |
| **L6** | Low/Info | Exact-principal deallocate leaves orphan yield (intentional but sharp) | — |
| **L1** | Low/Med | lastPass `pull=max` can over-touch lossy venue depending on allowlist order | venue order |

---

## L2 — High: loss budget meters gross principal, not post-entry basis

### Mechanism

```solidity
// allocate: books GROSS
allocated[venue] += amount;          // not `supplied`
uint256 supplied = venue.deposit(amount); // may be amount - entrySwap

// deallocate enforce=true:
loss = pulledPrincipal - returned;   // pulledPrincipal from gross book
```

RWA entry already burns value into NAV at allocate time (swap). On exit, budget compares **returned vs gross book**, so entry loss is charged **again**.

### PoC

`test_Logic_LossBudget_DoubleCountsEntryFill`  
Entry 2% + exit 1%, budget set to ~exit-only (12). Full `deallocate` reverts `LossBudgetExceeded` while position remains fully booked.

### Impact

- Legitimate agent de-risk **frozen** after normal RWA allocate when budget was sized for exit cost only.
- Forces user-path exits (unmetered) or owner `setLossBudget` raise — operational liveness failure, not free mint.
- Interacts with security model claim “agent can always retreat.”

### Fix

Book `allocated += supplied` (or mark-to-market post-entry), and/or charge loss only vs last marked basis; do not re-charge entry already reflected in NAV.

---

## L3 — High: phantom retreat when `withdraw` returns 0 without revert

### Mechanism

```solidity
allocated[venue] = principal - pulledPrincipal;  // effects FIRST
totalDeployed -= pulledPrincipal;
IVenueAdapter(venue).withdraw(amount);           // may return 0, no revert
returned = balAfter - balBefore;                 // 0
// enforce=false (user path): no budget check, success
```

`_ensureIdle` only skips venues with `balanceOf == 0` or **reverting** withdraw (try/catch). A venue that **reports live > 0** and **no-ops withdraw** silently burns principal accounting.

### PoC

`test_Logic_SilentZeroWithdraw_WipesPrincipal_WhenIdleShort`  
Lie venue + Aave: partial redeem → lie principal 1000→500, face still 1000, `totalDeployed` understates; agent reallocates into freed cap; **real face > book**.

### Impact

- Cap invariant `totalDeployed ≤ maxTotalDeployed` no longer bounds **real** venue exposure.
- NAV still counts lie `balanceOf` (R1-adjacent) while principal headroom reopens.
- Requires non-reverting empty withdraw (malicious/buggy adapter). Honest Aave/RWA revert or return value consistently with `balanceOf==0`. Still a **real logic hole** in the pool’s adapter contract.

### Fix

After withdraw, require `returned > 0 || amount handled`; or if `returned == 0`, **restore** principal (or revert). Prefer: `if (returned == 0) revert EmptyWithdraw();` unless amount was 0.

---

## L8 — High: `maxWithdraw` / share math overstate liquid assets

### Mechanism

`totalAssets()` sums adapter `balanceOf` including non-withdrawable venues. OZ `maxWithdraw` = convert shares→assets from that NAV. Liquid idle+healthy can be far smaller.

### PoC

`test_Logic_MaxWithdraw_OverstatesLiquid`  
maxWithdraw = 1000, liquid Aave = 400. `withdraw(maxW)` reverts. UI/integrators that trust maxWithdraw will misprice exit capacity; successful partial paths implement **R1** bank-run on healthy leg.

### Fix

Override `maxWithdraw`/`maxRedeem` to min(share claim, idle + sum of **successfully probeable** venue liquidity), or mark unrealizable venues at 0 in NAV (ties to R1).

---

## L4 — Medium: dual ledger (gross principal vs live / supplied)

### PoC

`test_Logic_AllocateBooksGrossNotSupplied` — 5% entry burn → allocated 1000, live 950.

### Impact

Caps tighter than real (fail-closed-ish) but **loss budget and totalDeployed semantics lie**; combines with L2 into agent freeze. Receipts emit `supplied` while state stores gross — operators misread risk.

### Fix

`allocated[v] += supplied` (and only if supplied > 0).

---

## L5 — Medium: epoch length shared, resets not shared

### Mechanism

Deploy rollover: `timestamp >= epochDeployStart + **lossEpochLength**`  
`setLossBudget` mutates `lossEpochLength` and resets **loss** counters only.  
`setDeployBudget` resets **deploy** counters only.

### PoC

`test_Logic_EpochLengthCoupling_DeployWindowDesync` — shrink length → deploy window rolls early; lengthen → deploy capacity stuck mid-window.

### Impact

Owner footgun: unexpected deploy thrash or stuck allocate; not permissionless theft.

### Fix

Separate `deployEpochLength` or reset both windows whenever either budget/length changes.

---

## L7 — Medium: discounted live used as face pull size

### Mechanism

RWA `balanceOf` = face × (1 - valuationDiscountBps).  
`_ensureIdle` sets `pull = need` when `need < live`, then `_doDeallocate` → `withdraw(need)` which peels **face** aUSDG 1:1.

### PoC

`test_Logic_DiscountedLive_PartialPull_FaceDesync` — after half redeem, principal ≈ face > live (discounted).

### Impact

Systematic principal/live skew (feeds L2); partial exits peel face faster relative to discounted NAV. Magnitude ~ discount bps (30 default), not full drain.

### Fix

Size pulls in face units: `face = adapter.faceBalance()` or invert discount; or report undiscouned in pull path and keep discount only for NAV.

---

## L6 — Low: orphan yield after exact-principal deallocate

### PoC

`test_Logic_WithdrawAmountNotCappedToPrincipal_LeavesOrphanYieldPath` — intentional product behavior (totalAssets still counts). Sharp edge for agents that deallocate `allocated` not `balanceOf`.

---

## L1 — Low/Med: lastPass max pull ordering

### PoC

`test_Logic_LastPass_OverLiquidatesLossyBeforeHealthy` — with RWA allowlisted first, large redeem peels RWA face heavily (9k→6.1k) while Aave also moves. Deploy script uses Aave first (mitigates). Owner re-order / first-seen `_venues` permanence is the footgun.

### Fix

Sort retreat order: lossless / highest liquidity first; never `pull=max` until per-venue residual pass; prefer healthy venues for dust shortfall.

---

## Cross-links

| Prior finding | Relationship |
|---------------|--------------|
| R1 NAV stuck preferential exit | Same root as L8 (unrealizable value in NAV) |
| R2 balanceOf revert bricks `_ensureIdle` | Sister of L3 (L3 is non-revert empty withdraw) |
| R3 maxEpochDeploy default 0 | Orthogonal churn path |

---

## Root-cause theme

The pool maintains **three inconsistent notions of “value in a venue”**:

1. **Principal book** (`allocated` / `totalDeployed`) — gross inputs, CEI-decremented on any successful `_doDeallocate` call  
2. **NAV** (`balanceOf` adapters) — live / discounted / can lie or stick  
3. **Cash returned** (`balanceOf` delta after withdraw)

Logic bugs appear wherever code **updates (1) from a call that does not guarantee (3)** or **prices exits using (2) while moving (1)/(3) in different units**.

---

## PoC command

```bash
cd hunts/aumo/repo/contracts
forge test --match-contract AumoPoolLogicBugsTest -vv
```

---

deviykee — private research
