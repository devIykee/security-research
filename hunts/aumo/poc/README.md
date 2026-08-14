# Aumo Proof of Concept (PoC) Test Suites

All PoC files in this directory replicate and prove the vulnerabilities identified during the Aumo security review.

## Running Tests

From `hunts/aumo/repo/contracts`:

```bash
cd hunts/aumo/repo/contracts
forge test
```

To run a specific test suite:

```bash
# Residual findings (H-1 preferential exit, M-1 balanceOf revert DoS)
forge test --match-contract AumoPoolResidualTest -vv

# Logic bugs (H-2 loss budget, H-3 silent zero withdraw, H-4 maxWithdraw, etc.)
forge test --match-contract AumoPoolLogicBugsTest -vv

# Redeem-path MEV sandwich (H-5)
forge test --match-contract AumoPoolRedeemSandwichTest -vv

# Critical hunt & candidate kills
forge test --match-contract AumoPoolCriticalHuntTest -vv

# Critical push & dust last-pass full liquidation
forge test --match-contract AumoPoolCriticalPushTest -vv
forge test --match-contract AumoPoolDustLastPassTest -vv

# Multi-angle adversarial review
forge test --match-contract AumoPoolAdversarialAnglesTest -vv
```

## Test Suites Overview

| File | Primary Finding | Description |
|------|-----------------|-------------|
| `AumoPool_Residual.t.sol` | H-1, M-1 | Proves preferential drain of healthy venues when one venue is stuck in NAV, and DoS from unreverted `balanceOf` in `_ensureIdle`. |
| `AumoPool_LogicBugs.t.sol` | H-2, H-3, H-4, M-2, M-3 | Tests for loss budget double counting, silent zero-return principal erasure, over-reporting `maxWithdraw`, and dual-ledger desync. |
| `AumoPool_RedeemSandwich.t.sol` | H-5 | Simulates permissionless sandwich attack on user redemptions that trigger USDG adapter retreat swap. |
| `AumoPool_CriticalHunt.t.sol` | Scope validation | Verifies mitigation of first-depositor inflation (offset-6), proves absence of unauthenticated unbounded mint/drain. |
| `AumoPool_CriticalPush.t.sol` | C-1 / H-CRIT | Demonstrates dust redeem triggering O(TVL) lastPass liquidation on lossy/RWA venues. |
| `AumoPool_DustLastPass.t.sol` | C-1 | In-depth examination of 1-wei / 1-USDT share redemption forcing full liquidation. |
| `AumoPool_AdversarialAngles.t.sol` | Multi-angle | 12 adversarial angles testing auth boundaries, accounting sync, reentrancy effects, and failure isolation. |
