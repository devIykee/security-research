# Aumo - High: NAV prices stuck venues, first redeemers drain healthy liquidity

**Researcher:** deviykee  
**Severity:** High - permissionless once a venue cannot exit but still reports `balanceOf`; bound = liquid venue size  
**Status:** Verified with local Foundry unit PoC. No mainnet state touched. Mainnet pool not observed deployed.  
**Disclosure:** Private. Pre-launch source finding.

## What this means in plain language (read this first)

Depositors think their share price is backed by real, exit-able stablecoins across venues (for example Aave USDT0 and a USDG RWA route). If the USDG route becomes stuck (depeg past the swap floor so withdrawals revert) while the pool still **counts that position in NAV**, the first people to withdraw get paid entirely from the still-working venue. They can walk away whole. Later depositors are left holding shares that only claim the stuck bag. No admin key is required for the run. The pool's isolation fix correctly skips the stuck withdraw so exits do not all brick, but it does not stop healthy liquidity from being used to pay claims that include unrealizable value.

Analogy: a bank that still prints full account balances for a frozen vault, and lets the first customers empty the open teller window.

## Affected contracts (X Layer, chainId 196)

| Role | Location |
|------|----------|
| Core | `contracts/src/AumoPool.sol` (`totalAssets`, `_ensureIdle`, ERC-4626 redeem/withdraw) |
| Stuck model | `contracts/src/adapters/RwaUsdgAdapter.sol` (withdraw reverts when swap < floor; `balanceOf` still returns discounted aUSDG) |
| Deploy surface | `script/DeployPoolMainnet.s.sol` allowlists both Aave and USDG |

Mainnet addresses: not set in web/agent config at hunt time (pre-deploy).

## Summary

One wrong assumption: **share pricing (`totalAssets`) treats every adapter `balanceOf` as realizable liquidity**, while redemption isolation only protects *liveness* of the withdraw call, not *fairness* of who gets the remaining liquid capital.

## Root cause

1. `totalAssets()` always adds live adapter balances (with try/catch only for *reverts*, not for non-realizable-but-positive balances):

```114:127:../repo/contracts/src/AumoPool.sol
    function totalAssets() public view override returns (uint256) {
        uint256 sum = IERC20(asset()).balanceOf(address(this));
        ...
            try IVenueAdapter(_venues[i]).balanceOf(address(this)) returns (uint256 b) {
                sum += b;
            } catch {}
```

2. `_ensureIdle` skips venues whose `withdraw` reverts, then continues with healthy venues:

```225:228:../repo/contracts/src/AumoPool.sol
                try this.retreatSelf(v, pull) {} catch {}
                idle = idleBalance();
```

3. `RwaUsdgAdapter.balanceOf` reports aUSDG face value times a small valuation discount even when a real exit would revert past `maxSlippageBps`:

```182:185:../repo/contracts/src/adapters/RwaUsdgAdapter.sol
    function balanceOf(address) external view returns (uint256) {
        uint256 held = aUsdg.balanceOf(address(this));
        return (held * (10_000 - valuationDiscountBps)) / 10_000;
    }
```

Redeem amount is computed from inflated (or merely non-realizable) NAV; settlement consumes healthy venues first.

## Attack

Precondition: multi-venue pool with material principal in a venue that cannot withdraw (USDG depeg past floor, or any stuck adapter) while `balanceOf` still returns > 0, and remaining capacity in a healthy venue (Aave).

1. Attacker (or any fast depositor) holds pool shares.
2. Stuck condition occurs (or attacker waits for it).
3. Attacker redeems max shares. `_ensureIdle` fails on stuck venue, pulls from Aave.
4. Attacker receives assets ≈ pro-rata of **full NAV including stuck value**, paid from healthy liquidity.
5. Remaining depositors' redemptions fail or only claim the stuck residue.

Capital: existing deposit (or deposit just before/during event). Auth: none. Frequency: once per stuck episode until owner `emergencyWithdraw` / pause / force accounting change.

## Impact

| Dimension | Value |
|-----------|--------|
| Auth | none (any shareholder) |
| Capital | share balance (no flash required) |
| Frequency | per stuck/depeg episode |
| Victims | slower depositors / residual LPs |
| Magnitude | up to healthy-venue TVL transferred against stuck NAV claim; remaining LPs absorb illiquid bag |

Not Critical: needs a stuck-but-still-valued venue (not free drain on a healthy-only Aave launch).

## Proof of concept

Local only:

```bash
cd hunts/aumo/repo/contracts
forge test --match-test test_Residual_NavIncludesStuckVenue_PreferentialExit -vv
```

Result: PASS. Alice redeems ~200 USDT0 fully from the healthy venue while 200 remains stuck; Bob's full redeem reverts; stuck `balanceOf` still 200.

## Fix (concrete options)

Pick one or combine:

1. **Realizability-aware NAV:** adapter `balanceOf` returns 0 (or deep haircut) when a probe shows exit would fail; or owner/oracle pause marks venue non-valuable.
2. **Pro-rata per venue on exit:** redeem only against idle + venues that successfully withdrew in that tx; do not let successful venues fund claims attributable to failed ones (harder UX, fairest).
3. **Global pause on venue health:** agent/owner pause deposits and optionally redemptions when USDG spot < floor; force `emergencyWithdraw` before unpause.
4. **Launch Aave-only** until USDG path has (1) or (3); avoids the multi-venue insolvency shape entirely.
5. Related MED: wrap `_ensureIdle`'s `balanceOf` in try/catch (same as `totalAssets`) so a reverting view cannot brick all pulls.

## Related residual (Medium)

`_ensureIdle` calls `IVenueAdapter(v).balanceOf` **without** try/catch. A listed adapter whose `balanceOf` reverts bricks any redeem that needs a venue pull, even if another venue is healthy. PoC: `test_Residual_EnsureIdle_BalanceOfRevert_BricksWhenNeeded` PASS.

## Disclosure and compensation

Good-faith private disclosure. I would appreciate a bounty commensurate with a High for a pre-launch fix, discretionary if no program. I am not conditioning disclosure or the fix on payment. Happy to walk the team through the PoC and review a patch.

deviykee
