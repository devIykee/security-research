# Aumo — Structured adversarial audit (private)

**Researcher:** deviykee  
**Scope:** `contracts/src/{AumoPool,AumoVault,adapters/*}`  
**Tools:** manual map + Slither 0.11.6 + Foundry PoCs  
**Date:** 2026-08-10  
**Assumption:** code is guilty until proven otherwise.

Slither artifact: `hunts/aumo/repo/contracts/slither-report.json`  
PoCs: `test/AumoPool_Residual.t.sol`, `test/AumoPool_CriticalHunt.t.sol`

---

# Part 0 — Foundation maps

## 0.1 State variables and who can modify them

### AumoPool

| State | Who writes | Notes |
|-------|------------|--------|
| `agent` | owner (`setAgent`), constructor | no zero-check |
| `venueAllowed[v]` | owner | allowlist |
| `maxMoveSize`, `perVenueCap`, `maxTotalDeployed` | owner `setPolicy` | default 0 = fail-closed allocate |
| `allocated[v]`, `totalDeployed` | agent allocate; agent/user via `_doDeallocate`; owner prune | principal basis (not live) |
| `maxEpochLoss`, `lossEpochLength`, `epochLoss*`, `maxEpochDeploy`, `epochDeploy*` | owner setters; agent allocate/dealloc updates counters | deploy budget **0 = off** |
| `_venues[]`, `_inList` | owner setVenueAllowed / prune | never shrinks except prune |
| ERC20 share balances / supply | public deposit/mint/withdraw/redeem | OZ ERC4626 |
| Ownable owner / pendingOwner | Ownable2Step | renounce disabled |
| Pausable `_paused` | owner pause/unpause | deposits/allocate gated; redeem not |

### AumoVault

| State | Who writes |
|-------|------------|
| `agent`, policy, `venueAllowed` | owner |
| `allocated`, `totalDeployed` | agent allocate; agent deallocate (**after** external call) |
| idle USDT0 balance | owner deposit/withdraw; agent alloc/dealloc |

### AaveV3Adapter / RwaUsdgAdapter

| State | Who writes |
|-------|------------|
| immutables (`token`, `pool`, `vault`, …) | constructor only |
| aToken / aUSDG balances | Aave via vault-only deposit/withdraw |
| `maxSlippageBps`, `valuationDiscountBps` (RWA) | adapter owner |
| residual ERC20 in adapter | swaps / emergency |

## 0.2 External calls (execution order)

### AumoPool.allocate (onlyAgent, whenNotPaused, nonReentrant)

1. Checks: amount, venueAllowed, caps, idle, deploy budget  
2. **Effects:** `allocated += amount`, `totalDeployed +=`, epoch deploy counter  
3. **Interactions:** `forceApprove(venue)` → `venue.deposit(amount)` → `forceApprove(0)`  
4. Event `Allocated(supplied)`

### AumoPool._doDeallocate (internal; agent path enforce=true; user path enforce=false)

1. Checks: amount != 0  
2. **Effects first:** decrease `allocated`, `totalDeployed`  
3. `balBefore = balanceOf(pool)`  
4. **Interaction:** `venue.withdraw(amount)`  
5. `returned = balAfter - balBefore`  
6. If enforce && loss: update `epochLoss*` (may revert budget)  
7. Event `Deallocated`

### AumoPool.redeem/withdraw (public, nonReentrant)

1. OZ computes assets from **current** `totalAssets()` (includes venue `balanceOf`s)  
2. `_ensureIdle(assets)`: loop venues → `balanceOf` (**no try**) → `this.retreatSelf` → `_doDeallocate(..., false)`  
3. OZ burns shares, transfers assets to receiver  

### RwaUsdgAdapter.deposit (onlyVault)

`transferFrom` → Uni `exactInputSingle` (minOut floor) → Aave `supply` → zero approvals  

### RwaUsdgAdapter.withdraw (onlyVault)

Aave `withdraw` → Uni swap (floor) → `transfer(vault, got)`  

### AumoVault.deallocate (onlyAgent, nonReentrant) — CEI inverted

1. Read principal  
2. **Interaction first:** `venue.withdraw`  
3. **Effects after:** `allocated`, `totalDeployed`  

## 0.3 Token movement paths (entry → exit)

```
User USDT0 ──deposit/mint──► AumoPool idle
                │
                │ allocate (agent)
                ▼
         allowlisted adapter
                │
     ┌──────────┴──────────┐
     ▼                     ▼
 AaveV3Adapter        RwaUsdgAdapter
 supply aUSDT0        swap→USDG→supply aUSDG
     │                     │
     └──────────┬──────────┘
                │ withdraw / _ensureIdle / deallocate
                ▼
         AumoPool idle ──redeem/withdraw──► User USDT0
```

**No path** sends USDT0 to agent or arbitrary EOA from Pool (adapters hardcode vault recipient).  
**Vault-only** owner can withdraw idle; cannot pull deployed without agent deallocate.

## 0.4 Access control gates

| Function | Gate |
|----------|------|
| Pool deposit/mint | `whenNotPaused` + `nonReentrant` + public |
| Pool withdraw/redeem | `nonReentrant` only (works while paused) |
| Pool allocate | `onlyAgent` + `whenNotPaused` + `nonReentrant` + caps |
| Pool deallocate | `onlyAgent` + `nonReentrant` + `_inList` |
| Pool retreatSelf | `msg.sender == address(this)` |
| Pool policy/pause/venues/budgets/agent | `onlyOwner` |
| Adapter deposit/withdraw | `onlyVault` |
| RWA emergency / setSlippage | adapter `onlyOwner` |
| Vault deposit/withdraw | `onlyOwner` |
| Vault allocate/deallocate | `onlyAgent` (+ pause on allocate) |

---

# Part 1 — First-pass checklist

| Item | Verdict | Justification |
|------|---------|----------------|
| **Reentrancy:** External calls follow CEI | **FAIL** (partial) | Pool allocate + `_doDeallocate` principal CEI is sound + `nonReentrant`; **AumoVault.deallocate writes `allocated` after external `withdraw`** (CEI inverted). Practical theft blocked by `nonReentrant` + allowlisted venues, but layout is wrong. |
| **Access control:** Privileged functions gated | **PASS** | Owner/agent/vault gates present; `retreatSelf` self-only; stranger cannot allocate. Residual: `setAgent(0)` allowed (grief). |
| **Oracle safety:** freshness/staleness | **FAIL** | No price oracle; RWA `balanceOf` assumes ~1:1 USDG/USDT0 face (aToken) and ignores spot depeg — accounting oracle is the adapter itself. |
| **Slippage:** DEX protection | **PASS** (normal path) | `exactInputSingle` uses `_floor` from `maxSlippageBps` (validated `!=0 && <10000`). **Caveat:** `emergencyWithdraw(minOut)` allows owner `minOut=0`. |
| **Frontrunning / sandwich** | **FAIL** | Agent RWA allocate/deallocate swaps are sandwichable up to floor (2%); share pricing can be raced around agent moves; no commit-reveal / private relay. |
| **Initialization:** uninit proxies | **PASS** | No proxy/UUPS; constructors set immutables and Ownable. |
| **Upgradeability:** storage layout | **PASS** / N/A | Non-upgradeable implementations. |
| **Emergency controls:** pause admin-only | **PASS** (with product note) | `pause`/`unpause` owner-only; deposits+allocate blocked; **redeem intentionally not paused** (by design). |
| **Event emissions:** all state changes | **FAIL** (partial) | Pool policy/agent/budget/venue events OK; **RWA `setMaxSlippageBps` / `setValuationDiscountBps` emit nothing** (Slither `events-maths`); share mint/burn via OZ Deposit/Withdraw. |

---

# Part 2 — Second opinion on prior finding R1

**Prior finding:**  
*High — NAV includes non-realizable (stuck) venue value; first redeemers drain healthy-venue liquidity; residual LPs left with illiquid bag.*

### Challenge

1. **Gas limits?**  
   Executable. `_ensureIdle` loops `O((n+2)*n)` venue calls; with 2 venues (Aave+RWA) gas is trivial. Even 10 venues is fine.

2. **Access control blocking it?**  
   **No.** `redeem`/`withdraw` are public. No role required beyond holding shares. Pause does not block redeem.

3. **Unreachable state?**  
   Reachable when: (a) multi-venue allocation with material principal in RWA **and** (b) RWA `withdraw` reverts (USDG depeg past `maxSlippageBps`, or Aave USDG reserve paused) **while** `balanceOf` still returns discounted aUSDG face. That is the designed depeg-revert behavior of `RwaUsdgAdapter`, not a fantasy mock-only path.  
   **Not reachable** on Aave-only launch (no second venue / no stuck swap).  
   **Temporary** one-block Uni manip then restore does **not** leave victims stranded (PoC kill).

4. **Mitigations elsewhere?**  
   - `try/catch` on `retreatSelf` prevents full exit brick (good for liveness, **enables** preferential exit).  
   - `valuationDiscountBps` only ~30 bps — does **not** model full depeg.  
   - `emergencyWithdraw` is owner-reactive, not automatic.  
   - Deploy budgets do not affect user redeem.  
   - No per-venue share accounting / pro-rata venue claims.

### Verdict: **CONFIRMED** (High, not Critical)

**Reasoning:** Foundry PoCs prove preferential drain under persistent stuck + face NAV; attacker does not mint multiple capital (puts X, gets ~X face) so not Critical unbounded theft; damage is socialized onto slower LPs via healthy liquidity. Bound = liquid venue size. Condition = persistent venue non-exitability still marked in `totalAssets`.

PoC: `test_Residual_NavIncludesStuckVenue_PreferentialExit`, `test_High_PersistentStuck_PreferentialDrain_NotFullCrit`  
Kill of false-Crit sandwich: `test_Kill_TemporaryStuckSandwich_NoVictimLoss`

---

# Part 3 — Slither results: genuine vs false positive

Slither: **33 detectors** (1 High, 9 Medium, 21 Low, 2 Info). Scope filtered to `src/`.

| Slither | Impact | Verdict | Why |
|---------|--------|---------|-----|
| `reentrancy-balance` on `_doDeallocate` | High | **FALSE POSITIVE** | `balBefore` only measures `returned`; `epochLoss` is updated from that delta under `nonReentrant`. No cross-function balance desync that steals funds with real adapters. |
| `reentrancy-no-eth` AumoVault.deallocate | Medium | **GENUINE code smell / Low practical** | CEI inverted (`allocated` after `withdraw`). Exploit needs malicious allowlisted venue + reenter non-guarded path; Vault user surface is owner-only. Treat as **Low** hygiene, not Medium fund risk on Pool product. |
| `incorrect-equality` (`live==0`, `pull==0`, …) | Medium | **FALSE POSITIVE** | Intentional empty checks; not balances that can be forced equal via donation in a harmful way here. |
| `unused-return` on `withdraw` | Medium | **FALSE POSITIVE / accepted** | Pool uses balance delta by design (handles fee-on-transfer-ish under-delivery); return ignored deliberately. |
| `missing-zero-check` agent/vault | Low | **GENUINE Low** | `setAgent(0)` freezes agent ops (grief), not drain. |
| `events-maths` RWA setters | Low | **GENUINE Low** | Slippage/valuation changes silent. |
| `calls-loop` totalAssets | Low | **GENUINE Low / DoS latent** | Many venues → gas grief on all ERC4626 math; owner controls list length. |
| `timestamp` epoch budgets | Low | **FALSE POSITIVE for exploit** | ±15s validator skew irrelevant to daily epochs. |
| `dead-code` `_withdraw`/`_ensureIdle` | Info | **FALSE POSITIVE** | Override used via ERC4626 inheritance; Slither missed virtual dispatch. |
| `reentrancy-benign` / `reentrancy-events` | Low | **Informational** | epochLoss/events after call under `nonReentrant`. |

### High-impact Slither → PoC?

`reentrancy-balance` **High** was challenged: no profitable reentrancy PoC with `onlyVault` adapters and Pool `nonReentrant`. **Not building a theft PoC** (would be dishonest).  
Vault CEI order fixed as test of hygiene only if needed — not fund Critical.

---

# Part 4 — What Slither missed (manual / economic)

These are the real audit value. Slither cannot see multi-tx economics.

| ID | Sev | Finding | Status |
|----|-----|---------|--------|
| **R1** | **High** | NAV marks non-realizable venue; first redeemers drain healthy venue | Confirmed + PoC |
| **R2** | **Medium** | `_ensureIdle` bare `balanceOf` (no try); one reverting view bricks redeem needing pull | Confirmed + PoC |
| **R3** | Medium | `maxEpochDeploy == 0` disables allocate-side rate limit; agent+depositor can socialize swap loss via unmetered redeem path if USDG live | Code-confirmed |
| **R4** | Medium | Mainnet script allowlists USDG day-one (re-opens R1/R3 class) | Deploy script |
| **R5** | Medium (ops) | Sandwich / MEV on agent RWA swaps up to `maxSlippageBps` | Economic |
| **R6** | Low | Silent RWA param changes; agent zero address | Slither+manual |
| **R7** | Trust | Malicious allowlisted venue + owner = full loss (documented trust root) | Design |
| **R8** | Info | `allocate` books `amount` not `supplied` (inflates principal vs RWA entry fill) | Accounting skew, conservative on caps |

**Not found:** permissionless Critical drain, broken `onlyVault`, open `retreatSelf`, inflation steal past `_decimalsOffset=6`, stranger allocate.

---

# Part 5 — Adversarial attack paths (attacker with partial knowledge)

| Attacker model | Path | Blocked by | Residual |
|----------------|------|------------|----------|
| Random EOA | Call allocate/deallocate/retreatSelf | onlyAgent / NotSelf | — |
| Shareholder | Redeem during stuck RWA + live Aave | nothing | **R1 High** |
| Shareholder | Grief redeem via… | cannot break others' balanceOf | — |
| Compromised agent | Send funds to self | no path | churn loss if budgets off (**R3**) |
| Compromised agent + depositor | deposit→alloc lossy→redeem loop | deploy/loss budgets if set | **R3** if deploy budget 0 |
| MEV searcher | Sandwich agent RWA swap | floor only | fee ≤ slippage bps |
| Owner evil | allowlist evil venue, setAgent(self) | none (trusted) | full loss |
| Inflator | 1 wei + donate | virtual shares offset 6 | killed in PoC |

---

# Part 6 — PoC commands

```bash
cd hunts/aumo/repo/contracts
source ../../.venv/bin/activate   # slither env if needed
forge test --match-contract 'AumoPoolResidualTest|AumoPoolCriticalHuntTest' -vv
# 12 passed

slither . --filter-paths 'lib|test|script' --json slither-report.json
```

---

# Part 7 — Summary scoreboard

| Severity | Count | Top item |
|----------|-------|----------|
| Critical | **0** | — |
| High | **1** | R1 NAV / preferential exit |
| Medium | **3–4** | R2 balanceOf brick; R3 deploy budget off; R4 USDG day-one; R5 MEV |
| Low / Trust | several | zero-agent, events, trust root |

**Recommendation before mainnet TVL:**  
1) Fix R1 (realizability-aware NAV or pro-rata venue exits or Aave-only until then).  
2) try/catch `balanceOf` in `_ensureIdle` (R2).  
3) Fail-closed `maxEpochDeploy` default or require non-zero when lossy venues allowed.  
4) Do not treat Slither High reentrancy-balance as a bounty Critical without a working exploit.

---

deviykee — private research only; no public disclosure of live issues.
