# xStocks CdpEngine - Medium (latent): Borrow fee debt is never minted
**Researcher:** deviykee
**Severity:** Medium (latent) - Only material if `borrowFeeBps > 0`. Live engines observed with `borrowFeeBps == 0`, so not currently exploitable.
**Status:** Verified from verified source plus read-only param checks. No mainnet state touched.
**Disclosure:** Private. Latent accounting bug / footgun.

## What this means in plain language (read this first)
When someone borrows (mints) the stablecoin, the engine can charge a fee in basis points. That fee is added to the user's **debt**, but the fee amount is **not minted** as stable tokens.

Debt goes up faster than the amount of stable that exists. Later, paying back the fee portion requires burning stable that was never created. If fees are used for a long time, some debt becomes hard or impossible to clear with circulating stable alone.

Today the fee is set to 0 on the engines I checked, so nothing is broken in production yet. Turning the fee on without changing the accounting would create the problem.

## Affected contracts (Robinhood Chain, chainId 4663)
| Role | Address |
|---|---|
| CdpEngine (peekPrice / V2-style, example) | 0xF408d7AE369C6210a21e4b3364a24aCEE444BCAa |
| CdpEngine (getPrice / V1-style, example) | 0x5812E883C09535078e0445F66f9f71Bde1fA7dF9 |
| Pattern | All CdpEngine copies with this mint fee logic |

Live: `borrowFeeBps() == 0` on checked engines.

## Summary
Fee is accounted as extra debt without a matching mint (to treasury or elsewhere). System-wide debt can exceed system-wide stable supply.

## Root cause
```solidity
function mint(uint256 stableAmount) external nonReentrant {
    require(stableAmount > 0, "zero amount");
    Vault storage v = vaults[msg.sender];

    uint256 fee = (stableAmount * borrowFeeBps) / BPS;
    uint256 newDebt = v.debt + stableAmount + fee;

    require(_ratioBps(v.collateral, newDebt) >= minCollateralRatioBps, "undercollateralized");

    v.debt = newDebt;
    // Mint requested amount to the user; fee accrues as extra debt only.
    stableToken.mint(msg.sender, stableAmount);
    emit Mint(msg.sender, stableAmount, fee);
}
```

`repay` burns stable 1:1 against debt. Fee debt has no corresponding tokens.

## Attack / trigger path
1. Owner sets `borrowFeeBps > 0` (or deploys with non-zero fee).
2. Users mint over time; total debt grows by fees without new supply.
3. Aggregate debt can exceed total stable supply.
4. Some debt remains unpayable without external mint/admin help; liquidations that need fee-debt coverage get messier.

Not permissionless theft. It is insolvency / accounting breakage after a config change.

## Impact
Auth: owner enables fee (or non-zero default) | Capital: n/a | Frequency: ongoing while fee on | Victims: borrowers / system solvency | Magnitude: cumulative fees as unbacked debt

## Proof of concept
Source-level invariant:

```text
For each mint(S) with fee F = S * borrowFeeBps / 10000:
  delta_debt = S + F
  delta_supply = S
  => delta_debt - delta_supply = F >= 0
```

Summed over history: `totalDebt - totalSupply == sum(fees)` when no other mint paths exist.

Read-only: `cast call <CDP> "borrowFeeBps()(uint256)"` returned 0 on live engines checked.

A Foundry unit test can assert `stable.totalSupply() < sumVaultDebt` after mints with fee > 0; happy to add if useful.

## Fix
Pick one consistent model:

1. **Mint fee to treasury:** `stableToken.mint(treasury, fee)` and still add fee to user debt (user owes protocol, supply backs it), or  
2. **Do not add fee to debt:** take fee from minted amount (`mint(user, S - fee)`, `mint(treasury, fee)`) with debt `+= S - fee` or `+= S` clearly documented, or  
3. **Interest index:** accrue fee via a global rate rather than unbacked principal.

Keep `borrowFeeBps == 0` until fixed.

## Disclosure & compensation
Good-faith private disclosure of a latent Medium. Discretionary bounty appreciated if useful; not conditioned on payment. Happy to review a patch.

deviykee  
http://x.com/deviykee
