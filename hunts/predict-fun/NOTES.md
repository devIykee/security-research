# Predict Fun — hunt notes (Step 1-6)

Researcher: deviykee / Iyke. Chain: BSC 56. RPC: https://bsc.publicnode.com

## Step 1 ground truth

PASS. chainId 56, block 117623382.

## Live backing measured (2026-08-23)

| Contract | idle USDT | Venus balanceOfUnderlying | total |
|---|---|---|---|
| ybCTF `0x9400...1d9F` | 0.0166 | 5,927,742.82 | ~5.93M |
| ybWrappedCollateral `0xCfb9...34D9` | 0.0211 | 2,617,527.42 | ~2.62M |
| ybNegRiskAdapter `0x41dC...2A40` | 0.0019 | 0 | dust |
| ybNegRisk CT `0xF64b...A07F` | 0 | 0 | 0 |
| WrappedCollateral legacy `0x6623...39e7` | 101,844.71 | n/a | ~102k |

Yield-bearing system backing ~8.55M USDT. Consistent with DefiLlama ~11.36M BSC once the
legacy stack is included. **The main pot is ybCTF at ~5.93M, all of it inside Venus.**

## Solvency checks (killed leads)

1. **WCOL supply vs backing is NOT insolvency.** WCOL totalSupply is 194,693,104 while only
   ~2.62M USDT backs the wrapper. All 194.69M WCOL sits inside the NegRisk ConditionalTokens
   `0xF64b...A07F`. `mint(uint256)` / `burn(uint256)` / `release()` are `onlyOwner` (owner =
   YieldBearingNegRiskAdapter) and exist precisely so the adapter can mint unbacked WCOL as
   intermediate collateral for NegRisk position conversion. This is the stock Polymarket
   NegRiskAdapter pattern, not a bug. KILLED.
2. **ybWrapped is solvent against its own book.** `balanceOfUnderlying` 2,617,527.42 vs
   `depositedAmount` 2,616,644.40 = +883.02 USDT accrued yield. Invariant holds. KILLED.
3. **`unwrap` is permissionless but safe.** No modifier, but it `_burn(msg.sender, amount)`
   first, so solmate underflow-reverts unless the caller owns the WCOL. KILLED.

## LEAD-1 (live): emergency escape hatch fails closed in the emergency it exists for

`Venus.sol::_disableUnderlying` is the documented kill-switch: "useful for emergency cases
where Venus is exploited or when there is a liquidity crunch and we need to remain
operational and solvent."

It cannot run during that emergency.

```solidity
uint256 redeemAmount = IVToken(vToken).balanceOfUnderlying(address(this));
uint256 originalDepositedAmount = depositedAmount[underlying];
if (redeemAmount < originalDepositedAmount) {
    redeemAmount = originalDepositedAmount;      // forces a redeem of the FULL book
}
if (redeemAmount > 0) {
    uint256 err = IVToken(vToken).redeemUnderlying(redeemAmount);
    if (err != 0) revert VTokenCallFailed(err);  // (a) reverts on shortfall
}
depositedAmount[underlying] = 0;
uint256 amountRedeemed = IERC20(underlying).balanceOf(address(this)) - balanceOfUnderlying;
uint256 yieldClaimed = amountRedeemed - originalDepositedAmount;   // (b) underflow reverts
```

Two independent revert paths when Venus is short or illiquid:
(a) `redeemUnderlying` for the whole ~5.93M returns a non-zero error code -> `VTokenCallFailed`.
(b) If it somehow partially fills, `amountRedeemed - originalDepositedAmount` underflows
    (Solidity 0.8 checked math) -> revert.

Lines 255-257 show the authors anticipated `balanceOfUnderlying < depositedAmount`, but the
mitigation makes it worse: it raises the redeem request to the full book, which is the single
hardest amount to source from an illiquid market.

### Why this freezes user exits

`YieldBearingConditionalTokens` has no non-Venus fallback while `underlyingIsEnabled` is true:

- `mergePositions` L313-318: `if (underlyingIsEnabled) { _redeemUnderlying(...) }` else raw transfer
- `redeemPositions` L378-389: same shape

There is no `try/catch`. ybCTF holds 0.0166 USDT idle against ~5.93M in Venus. So if Venus
`redeemUnderlying` reverts, every merge and every redeem reverts. The only switch to the raw
path is `disableUnderlying`, which is strictly harder to execute than a single user's exit
because it must redeem the entire book at once.

Net: user exits are blocked, and the intended remedy is blocked by the same condition, with
`underlyingIsEnabled` stuck at true because the write on L248 reverts with the rest of the tx.

### Honest severity: Medium

Not Critical, not theft. Bound and kill-checks applied:
- No attacker profit, no fund extraction. This is liveness / freeze only.
- Precondition is external: Venus USDT market illiquidity or a Venus shortfall. Not
  attacker-triggerable at ~5.93M scale on a deep market.
- **Temporary vs persistent (rule 9):** if Venus liquidity returns, exits resume and users are
  whole, so the ordinary case is a temporary freeze = Medium. It only becomes a persistent
  loss if Venus takes a permanent shortfall, in which case the freeze is the smaller problem.
- Per-user exits are small and keep working under partial illiquidity; the systemic freeze
  needs near-total illiquidity for the requested size.

Escalate to High only with evidence that Venus USDT utilization realistically reaches a point
where 5.93M cannot be sourced.

### Fix options

1. Wrap the per-user redeem in `try/catch` and fall back to the idle raw balance.
2. In `_disableUnderlying`, redeem `min(balanceOfUnderlying, depositedAmount)` and use
   `saturating` subtraction for `yieldClaimed` so a shortfall still flips the flag off.
3. Allow a partial/incremental disable that flips `underlyingIsEnabled = false` first and
   drains Venus over multiple txs.
4. Keep a liquidity buffer of idle underlying sized to recent exit volume.

## LEAD-2 (live, lower): Venus governance can brick all deposits

`Venus.sol::_mintVToken` L133-136:

```solidity
IComptroller comptroller = IComptroller(IVToken(vToken).comptroller());
if (comptroller.treasuryPercent() > 0) revert VTokenTreasuryPercentMustBeZero();
```

Every `splitPosition` from collateral routes through `_mintVToken` while enabled. If Venus
governance sets `treasuryPercent > 0`, every split reverts and the market stops accepting new
collateral. Exits still work. Severity: Low/Medium ops DoS, external trigger, no fund loss.
Note the asymmetry: the check protects deposits but exits do not have an equivalent guard.

## LEAD-3 (informational): permissionless `splitPrincipalAndYield` can revert-brick yield claims

`splitPrincipalAndYield` is `public`:

```solidity
(, principal) = divScalarByExpTruncate(depositedAmount[underlying], Exp({mantissa: exchangeRateCurrent}));
yield = IVToken(vToken).balanceOf(address(this)) - principal;
```

If `principal > vTokenBalance` the subtraction underflows and reverts, which also bricks
`_claimYield`. Impact is protocol revenue only, not user funds. `principal` is truncated down,
which biases against underflow. Informational.

## LEAD-4 (informational): idle underlying gets booked as principal on enable

`_enableUnderlying` deposits the entire contract balance and `_mintVToken` adds all of it to
`depositedAmount`. Any idle underlying that is not CT collateral (donation, stray fee) is
permanently counted as principal, so it is never claimable as yield and it overstates the CT
liability book. Requires `YIELD_MANAGER_ROLE` timing, no attacker profit. Informational.

## Trust / centralization

- `YIELD_MANAGER_ROLE` on ybCTF controls `connectVTokenToUnderlying`, `enableUnderlying`,
  `disableUnderlying`, `claimYield`. `claimYield` takes an arbitrary `vTokenAmount`, bounded
  only by the trailing `Insolvent()` check (`balanceOfUnderlying < depositedAmount` reverts).
  That guard is the real protection and it is present. Good design.
- `disableUnderlying(underlying, yieldRecipient)` sends `yieldClaimed` to an arbitrary
  yieldRecipient chosen by the yield manager. Accrued yield is diverted at will. By design.
- `DEFAULT_ADMIN_ROLE` can gate/ungate split and merge (`setIsSplitPositionGated`,
  `setIsMergePositionsGated`). Admin can halt merges, which is an exit path. Disclose.
- `YieldBearingWrappedCollateral.updateYieldManager` is `onlyYieldManager`, so the role can
  hand itself off. Standard.

## Killed this pass (do not reopen without new evidence)

1. WCOL unbacked mint = insolvency (it is the NegRisk pattern; WCOL locked in NegRisk CT)
2. ybWrapped insolvency (solvent, +883 USDT yield)
3. Permissionless `unwrap` drain (burn-first underflow protects)
4. `_redeemUnderlying` shortchanging users into a protocol deficit (book and payout both move
   by the same `amount`; user eats Venus dust, no protocol deficit)
5. `claimYield` unbounded drain by yield manager (trailing `Insolvent()` check blocks it)

## Not yet done

- `YieldBearingNegRiskAdapter` (18,634 bytes) not fetched or read
- `WhitelistedERC1155` transfer gating not traced
- `prepareCondition` / `reportPayouts` oracle path not traced (UMA adapter)
- No fork PoC written; LEAD-1 needs a forked-Venus illiquidity harness to prove the revert

## LEAD-1 severity bound (measured, 2026-08-23)

Venus vUSDT market at block 117623382:

| Metric | Value |
|---|---|
| `getCash()` (available liquidity) | 81,346,125 USDT |
| `totalBorrows()` | 126,417,737 USDT |
| Implied total supplied | ~207.76M USDT |
| Utilization | ~60.8% |

Predict Fun's full yield-bearing book is ~8.55M (ybCTF 5.93M + ybWrapped 2.62M). Available
Venus cash is **9.5x** that. A `disableUnderlying` today would succeed comfortably.

For LEAD-1 to bite, Venus USDT cash must fall below the redeem request:
- below ~5.93M for the ybCTF full-book disable to fail, i.e. utilization above ~97%
- individual user exits are small and keep working well past that point

**This is the honest bound: the bug is real in code, but the precondition currently has a
9.5x margin.** It is a latent freeze that surfaces only in a severe Venus stress event, which
is why I am calling it Medium and not High. Reporting it as an imminent High would be wrong.

The finding is still worth disclosing because the fix is cheap (saturating subtraction plus a
try/catch fallback) and because the current code makes the kill-switch strictly harder to fire
than the condition it defends against.
