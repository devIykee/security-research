> For the complete documentation index, see [llms.txt](https://docs.tropicalwater.xyz/llms.txt). Markdown versions of documentation pages are available by appending `.md` to page URLs; this page is available as [Markdown](https://docs.tropicalwater.xyz/architecture/yield-mechanics.md).

# Yield Mechanics

### The Cumulative Rate Factor

Yield is not distributed as new token mints. A single global variable — `cumulativeRateFactor` — tracks how much one share is worth in asset terms. It starts at `RAY` (1 × 10²⁷) and only ever increases. Share count stays constant; purchasing power grows.

```
cumulativeRateFactor at 10% APY example:

Day   0:  1.000000  →  1,000 shares worth 1,000.00 USDC
Day  30:  1.008214  →  1,000 shares worth 1,008.21 USDC
Day  90:  1.024684  →  1,000 shares worth 1,024.68 USDC
Day 180:  1.049964  →  1,000 shares worth 1,049.96 USDC
Day 365:  1.100000  →  1,000 shares worth 1,100.00 USDC
```

### Share Pricing Formulas

USDC has 6 decimals; vault shares have 18 decimals (from ERC-20 / OFT). A `_decimalOffset = 10^(18 - 6) = 10^12` normalises all conversions.

```
Deposit → shares:
  shares = assets × decimalOffset × RAY / cumulativeRateFactor

Redeem → assets:
  assets = shares × cumulativeRateFactor / RAY / decimalOffset
```

### Compounding Formula

`_compoundFactor(rate, timeDelta)` approximates `e^(rate × timeDelta / RAY)` using a 3-term Taylor series. `rate` is stored as a **per-second** value in RAY units.

```
rt  = rate × timeDelta
rt2 = rt × rt / RAY          ← normalised to RAY units
result = RAY + rt + rt2/2 + rt2·rt/RAY/6
```

This matches `RollingBond.MAX_RATE` encoding and agrees with the true exponential to \~6 decimal places across all practical inputs. The approximation always rounds down (conservative).

### Redemption Mode Comparison

|                     | Standard Redemption                         | Early Redemption          | Cross-Chain Bridge         |
| ------------------- | ------------------------------------------- | ------------------------- | -------------------------- |
| **Wait time**       | Lockup period (configurable, default 5 min) | None                      | 5–10 min (LayerZero relay) |
| **Fee**             | None                                        | Configurable (default 5%) | LayerZero gas              |
| **Yield at payout** | Frozen at request time                      | Current live value        | N/A — shares transfer      |
| **Best for**        | Long-term holders                           | Emergency liquidity       | Multi-chain positioning    |
| **Function**        | `requestRedemption` → `completeRedemption`  | `redeemEarly`             | OFT `send`                 |
