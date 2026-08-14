# Aumo hunt notes (PRIVATE)

**Researcher:** deviykee  
**Lead skill:** iykes-web3-bughunt-skill  
**Support:** duke/kensho playbook, vendor evm-audit-*, web3-start-here  
**Date:** 2026-08-10  
**Status:** Pre-mainnet. Source audit + local Foundry PoCs. Nothing touched on mainnet.

## INTAKE

```
PROJECT_NAME   : Aumo
X_HANDLE       : @aumofinance
WEBSITE        : https://www.aumo.finance/
CHAIN          : X Layer
RPC            : https://rpc.xlayer.tech
CHAIN_ID       : 196
PRODUCT_TYPE   : vault (ERC-4626 agent / RWA + Aave adapters)
BOUNTY/CONTEST : none / discretionary
RESEARCHER     : deviykee
```

## What it is

Autonomous RWA-yield agent for USDT0 on X Layer. `AumoPool` (ERC-4626) custodies funds; an allowlisted agent allocates to venue adapters within on-chain caps. Launch path deploys Aave + RwaUsdg adapters via `DeployPoolMainnet.s.sol`.

## Prior work in-repo

`AUDIT.md` / `AUDIT_FIXES.md` (Duke, same-day) already covered deploy hygiene, loss/deploy budgets, redemption isolation (`retreatSelf` try/catch), valuation discount vs swap floor, emergency exit on USDG adapter. **Most Part 1–2 code fixes are already in `src/`.** Mainnet still undeployed in web/agent config.

## Skills applied (token-efficient)

- Iyke steps 1–8 (source path; no live mainnet core)
- Always: general + precision-math mindset
- Routed: ERC4626, ERC20, access-control, DoS, adapters/AMM slip, flashloans (share inflation already offset)

## Residual findings (this hunt)

| ID | Sev | Title | PoC |
|----|-----|-------|-----|
| R1 | **High** | NAV includes non-realizable (stuck) venue → first redeemers drain healthy venue | `AumoPool_Residual.t.sol::test_Residual_NavIncludesStuckVenue_PreferentialExit` PASS |
| R2 | **Medium** | `_ensureIdle` does not try/catch `balanceOf`; one reverting adapter bricks redemptions that need a pull | `...::test_Residual_EnsureIdle_BalanceOfRevert_BricksWhenNeeded` PASS |
| R3 | Medium | `maxEpochDeploy` defaults **off** (0); unlike `maxEpochLoss` fail-closed. Missed deploy budget re-opens agent+depositor redeem-path churn if USDG live | code review |
| R4 | Medium | `DeployPoolMainnet` still allowlists **USDG on day one** (audit recommended Aave-only); re-exposes R1 under depeg | deploy script |
| R5 | Low/Trust | `script/DeployMainnet.s.sol` (Vault) still `AGENT_ADDRESS` defaults to owner | deploy script |
| R6 | Info/Trust | Owner + malicious allowlisted venue remains full trust root (documented) | design |

## Deep critical hunt (pass 2) — **no Critical**

Honest call: **no permissionless Critical** (unauthenticated unbounded theft / full drain in one shot without special role or rare persistent venue failure).

### Candidates killed (`AumoPool_CriticalHunt.t.sol`, 10/10 pass)

| Candidate | Result |
|-----------|--------|
| Classic ERC4626 inflation (offset-6) | Unprofitable |
| Deposit/redeem round-trip free money | No free assets |
| 50x dust cycle extraction | No profit |
| Donation sandwich | Attacker loses |
| allocated vs live desync over-withdraw | Caps at live value |
| `retreatSelf` / stranger allocate | Auth holds |
| FoT underlying share games | Attacker net loss (USDT0 not FoT) |
| One-block Uni depeg sandwich then restore | Victim recovers fully |
| Persistent stuck preferential exit | **High only**: put 100 get ~100 face; damages residual LPs, does not mint multiple |

### Why R1 is not Critical

- Needs **persistent** non-realizable venue still in NAV (real USDG depeg past floor, or bricked adapter with working `balanceOf`).
- Attacker must hold shares; capital is not multiplied.
- Bound = healthy-venue liquidity, not unbounded protocol mint.
- Temporary AMM manip is not enough: after price restores, remaining LPs exit whole.

### On-chain context (X Layer)

- USDT0/USDG Uni v3 fee-100 `0x0cBe...76dA` ~$1.1M USDT0 + ~$0.84M USDG (not paper-thin).
- Durable >2% depeg to weaponize R1 is capital-heavy.

### Auth surface re-check

- Fund exits: user ERC4626 redeem, Vault owner idle withdraw, adapters `onlyVault`, agent only allowlisted allocate/deallocate.
- Compromised agent cannot send to arbitrary address; churn bounded when budgets set.
- LLM tighten-only; reentrancy guarded on user/agent paths.

## Killed / already fixed (do not re-report as new)

- Redemption hard-brick on single stuck withdraw → fixed via `retreatSelf` try/catch
- Agent allocate/deallocate lossy churn unbounded → `maxEpochLoss` + tests
- Redeem-path re-staging → `maxEpochDeploy` when set by owner/script
- First-depositor inflation → `_decimalsOffset() = 6` + test
- Immutable USDG floor with no rescue → `setMaxSlippageBps` + `emergencyWithdraw`
- NAV step from full swap floor → `valuationDiscountBps` decoupled

## Scope notes

- Mainnet `AumoPool` address not in repo/web yet → findings are **source/pre-launch**.
- Testnet pool exists; prefer not to stress public testnet with noisy churn.
- Keep all writeups private until team is engaged and patch ships.

## PoC run

```bash
cd hunts/aumo/repo/contracts
forge test --match-contract 'AumoPoolResidualTest|AumoPoolCriticalHuntTest' -vv
# 12 tests PASS (R1, R2 + critical-hunt kills)
```

## Next (optional)

1. Package private report for R1 (+ R2) to team after they confirm security contact.
2. If mainnet deploys, re-verify owner/agent/pause/venues/budgets on-chain (Step 1–4).
3. Do not open public GitHub issues while live-exploitable post-deploy.
