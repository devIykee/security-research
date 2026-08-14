# Aumo - Medium/High: Permissionless sandwich on redeem-path RWA swap

**Researcher:** deviykee  
**Severity:** Medium (default) to High if large RWA allocation + frequent large redeems  
**Bound:** ~`maxSlippageBps` of each USDG→USDT0 notional pulled on redeem (deploy default **200 bps / 2%**), minus AMM fees and inventory risk  
**Status:** Logic + unit PoC. No mainnet exploit. Pre-deploy config dependent.  
**Disclosure:** Private.

## Route (permissionless)

```text
Anyone redeem() when idle < assets and RWA venue is selected
  → AumoPool._ensureIdle
  → retreatSelf → _doDeallocate(..., enforce=false)
  → RwaUsdgAdapter.withdraw
  → Aave withdraw aUSDG
  → Uniswap v3 exactInputSingle(USDG → USDT0)
       amountOutMinimum = amountIn * (10000 - maxSlippageBps) / 10000
       sqrtPriceLimitX96 = 0
```

No role required for the sandwicher. Victim is any user (or integration) whose redeem pulls the RWA adapter while the Uni pool is publicly observable.

Same swap surface exists on **agent allocate** (USDT0→USDG) and **agent deallocate**; redeem is the fully user-triggered path.

## Attack

1. Observe mempool (or builder bundle) redeem that will retreat RWA (idle short, RWA holds funds).
2. Front-run: trade Uni USDT0/USDG fee tier against the exit (make USDG→USDT0 worse).
3. Redeem executes swap with `minOut` only enforcing the floor (e.g. 98%).
4. Back-run: reverse the trade; capture up to ~floor minus fees.

If price is pushed **past** the floor, adapter reverts; pool `try/catch` skips the venue. Redeem then fails if no other venue/idle can cover (grief / temporary DoS), or succeeds via Aave only (no sandwich on that leg).

## Who pays

ERC-4626 pays the redeemer **`previewRedeem` assets from pre-tx `totalAssets`**.

Worse swap return is **not** taken only from the redeemer. It reduces cash returned to the pool for burned venue face. That shortfall is **socialized to remaining LPs** when the redeem still succeeds.

NAV marks RWA with `valuationDiscountBps` (e.g. 30 bps), but the swap floor is much wider (e.g. 200 bps). Sandwich can realize a gap **above** the valuation haircut.

## PoC

```bash
cd hunts/aumo/repo/contracts
forge test --match-contract AumoPoolRedeemSandwichTest -vv
```

Result (illustrative):
- `navBefore` 20_000, victim redeem claim 10_000 paid in full
- remaining claim after 9_600
- **value destroyed (socialized) 400** (= 2% order of magnitude on pulled size)
- Beyond-floor haircut → redeem reverts (retreat skipped, no idle)

## Preconditions

- Material principal in `RwaUsdgAdapter` (USDG venue allowlisted and funded)
- Redeem large enough that idle cannot cover (forces retreat + swap)
- Public mempool / shared sequencer ordering (X Layer / any EVM MEV surface)
- `maxSlippageBps` not near zero (launch script uses 200)

## Not Critical

- Bounded by slippage floor per swap
- Needs RWA path live (Aave-only launch removes this surface)
- Capital and inventory risk for sandwicher; deep Uni pool reduces extractable edge
- Does not mint free shares or drain idle without a swap victim tx

## Fix options

1. Tighter `maxSlippageBps` for normal ops + only widen via owner for depeg (already partly the emergency path).
2. **TWAP / private fill / RFQ** for large retreats instead of public `exactInputSingle` with wide floor.
3. Pass **caller-supplied minOut** for user-driven retreats (hard with ERC-4626 internal `_ensureIdle`).
4. Prefer pulling **Aave first** always; only hit RWA when necessary; batch retreats off user path (keeper with MEV protection).
5. Valuation discount closer to worst-case executable slippage so remaining LPs are not marked rich pre-sandwich.
6. Aave-only until RWA exits can be protected.

## Relation to other findings

| ID | Link |
|----|------|
| H-1 | Stuck venue (revert past floor) → preferential healthy drain; sandwich is the **in-floor** cousin |
| H-4 | maxWithdraw still assumes marked NAV, not post-MEV cash |
| MEV on agent allocate | Same adapter `_swap`, agent-triggered |

deviykee
