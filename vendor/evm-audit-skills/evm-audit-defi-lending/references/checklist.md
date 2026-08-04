# Lending, CDP & Liquidation Security Checklist

## Liquidation Mechanics

- [ ] **Self-liquidation for profit**: If liquidation bonus exceeds gas + price impact, a user can borrow, let position go underwater, and liquidate themselves to net the bonus. Check if the liquidation incentive is small enough that self-liquidation is unprofitable. Look for: liquidation functions callable by the position owner. [beirao LEN-02, Decurity CDP]

- [ ] **Paused collateral token blocks defense**: If a collateral token is paused (USDC, USDT have pause), users can't add collateral or repay debt, but can still be liquidated. This creates unfair liquidation. Look for: collateral tokens with pause functionality and whether the protocol handles it. [beirao LEN-03, LEN-07]

- [ ] **Large price drops make liquidation unprofitable**: If oracle price drops 50%+ in one update (Maker Black Thursday scenario), the liquidation bonus may not cover the liquidator's cost. Liquidators won't participate, leaving bad debt. Look for: liquidation incentive size vs potential price drop scenarios. [beirao LEN-04, Sigmaprime oracles]

- [ ] **Small positions unincentivized**: Gas costs for liquidating a $10 position may exceed the liquidation bonus. These tiny positions accumulate as bad debt. Look for: minimum position size enforcement or gas-subsidized liquidation. [beirao LEN-09]

- [ ] **Front-running liquidation with dust collateral**: An attacker watches the mempool, sees a liquidation transaction, and front-runs it by adding 1 wei of collateral — just enough to make the position healthy and revert the liquidation. Look for: liquidation functions that re-check health factor without minimum improvement threshold. [beirao LEN-08]

- [ ] **Liquidation pause + unpause = cascading crisis**: When liquidations are paused (oracle issues, upgrades) and then unpaused, all positions that became unhealthy during the pause are liquidatable simultaneously. Mass liquidations can cascade through shared collateral pools. Look for: time-based position accumulation during pause periods. [beirao LEN-06]

- [ ] **Liquidator receives less than expected**: If liquidation uses a swap to convert collateral, slippage during the swap may make the liquidation unprofitable. Look for: swap-based liquidation without slippage protection. [beirao LEN-05]

- [ ] **Cannot repay loan = permanent bad debt**: If the repayment function has a bug or dependency that can fail, the loan can never be closed. Look for: repay functions with external dependencies that could revert. [Decurity CDP]

- [ ] **Single borrower can't be liquidated**: Some implementations skip liquidation when `borrowerCount == 1`. During protocol sunsetting, the last borrower is immune to liquidation. Look for: liquidation loops with `count > 1` conditions. [ERC4626 primer pattern #18]

- [ ] **Liquidation before grace period**: After repayments resume (post-pause), borrowers need a grace period to repay. Liquidating immediately is unfair. Look for: post-unpause liquidation without delay. [ERC4626 primer]

- [ ] **Infinite loan rollover**: If a borrower can continuously extend their loan maturity, they never have to repay. Look for: rollover/extend functions without limits. [ERC4626 primer]

## Auction Liquidations

- [ ] **Flash loan to prove solvency during auction**: If a liquidated user can prove solvency to cancel an auction, they can flash-loan collateral, cancel, then return it. Look for: auction cancel functions that don't prevent flash loans. [Decurity CDP]

- [ ] **Incomplete auction launch**: Missing input validation when starting an auction can create auctions in invalid states. Look for: auction start functions without proper parameter bounds checking. [Decurity CDP]

- [ ] **Partial collateral auction math**: When only a portion of collateral is auctioned, the math for splitting must be exact. Rounding errors can leave dust or under-collateralize the remaining position. Look for: arithmetic in partial liquidation functions. [Decurity CDP]

- [ ] **Interrupted bid funds not returned**: If a bidder is outbid, their funds must be returned. If the auction creator cancels, the last bidder's funds must be returned. Look for: bid escrow that doesn't handle all cancellation/interruption paths. [Decurity CDP]

## CDP-Specific

- [ ] **Closed vault storage not cleaned**: When a CDP is closed (debt repaid), if the storage entry isn't erased, code that checks existence may behave incorrectly. Look for: state reads on potentially-deleted vault entries. [Decurity CDP]

- [ ] **Pool value calculation with fee split**: If borrower fees split between lender and pool, verify both calculations sum correctly and neither path rounds in the wrong direction. Look for: fee distribution math with multiple recipients. [Decurity CDP]

- [ ] **Stablecoin arbitrage via different collateral types**: If a CDP accepts multiple stablecoins as equivalent (1:1), an attacker can deposit the depegged stablecoin and borrow against it at full value. Look for: stablecoin collateral without independent price feeds. [Decurity CDP]

- [ ] **Health ratio checked AFTER safeTransferFrom**: ERC721 `safeTransferFrom` calls `onERC721Received` callback before the health ratio check. An attacker can reenter during the callback when the health ratio is invalid. Look for: health factor checks after `safeTransferFrom` or `_safeMint`. [Decurity CDP]

- [ ] **Interest rate calculated before or after close/liquidation**: Wrong ordering = user pays too much or too little interest. Look for: interest accrual timing relative to vault close/liquidation. [Decurity CDP]

## AAVE/Compound Integration

- [ ] **High utilization blocks withdrawal**: At 100% utilization rate, lenders can't withdraw their deposits. The protocol should handle this gracefully rather than reverting. Look for: withdrawal functions that assume utilization < 100%. [beirao AC-01]

- [ ] **cETH has no `underlying()` function**: Unlike other cTokens, Compound's cETH doesn't implement `underlying()`. Generic code calling `underlying()` on all cTokens will revert for cETH. Look for: `ICToken(address).underlying()` without special-casing cETH. [beirao AC-07]

- [ ] **AAVE siloed assets prevent all other borrows**: Borrowing a siloed asset on AAVE prohibits borrowing ANY other asset. If the protocol doesn't check `getSiloedBorrowing()`, a user's position can be locked. Look for: AAVE borrow functions without siloed asset checks. [beirao AC-08]

- [ ] **AAVE flashloans inflate pool index**: Each AAVE flashloan slightly inflates the pool index. Max 180 flashloans per block. This can be used to manipulate lending rates. Look for: rate-sensitive logic that doesn't account for flashloan-induced index inflation. [beirao AC-05]

- [ ] **Max debt on isolated assets = DoS**: On AAVE, when the debt ceiling for an isolated asset is reached, all new borrows revert. An attacker can fill the ceiling to DoS other users. Look for: borrow functions against AAVE isolated markets without ceiling checks. [beirao AC-09]

- [ ] **Protocol pause blocks everything**: If AAVE/Compound is paused, all integrated protocol operations that touch the lending market will revert. Look for: external calls to lending markets without try/catch or fallback logic. [beirao AC-02]

- [ ] **Deprecated pool still holds funds**: If a lending pool is deprecated, existing positions may be stuck. Look for: integration code that doesn't handle pool deprecation. [beirao AC-03]

- [ ] **eMode category interactions**: If the protocol's assets are in the same eMode category on AAVE, liquidation parameters are different. Look for: eMode-specific LTV/threshold values not accounted for. [beirao AC-04]

- [ ] **AAVE/Compound reward claims**: If the protocol deposits user funds in AAVE/Compound, reward token claims (COMP, stkAAVE) must be properly distributed to users. Look for: missing reward claim functionality or rewards stuck in contract. [beirao AC-06]

## LP Token Collateral

- [ ] **LP token valuation via `pool.getReserves()` is manipulable**: Flash loans can manipulate reserves to inflate LP token value, allowing over-borrowing. Must use fair pricing formulas (e.g., Alpha Homora's formula). Look for: LP token price calculations using raw reserve amounts. [Decurity CDP]

- [ ] **Multiple pool types for same pair**: Uniswap has 0.01%, 0.05%, 0.3%, 1% fee tiers for the same token pair. Each has different LP token value. Look for: LP token handling that doesn't account for fee tier differences. [Decurity CDP]

## Earn/Yield-Bearing Collateral

- [ ] **Pegged asset collateral depeg risk**: renBTC, WBTC, stETH as collateral — if they depeg, counting them 1:1 with the underlying asset creates bad debt instantly. Look for: pegged-asset collateral priced without its own oracle feed. [Decurity CDP]

- [ ] **Staked collateral share manipulation**: If collateral is staked in an external protocol, the share calculation can be manipulated if it depends on instantaneous balance. Look for: share-based collateral valuation without TWAP or time-weighted averaging. [Decurity CDP]

## CDP Specific (Expanded from Decurity)

- [ ] **Closed CDP storage not erased**: When a user repays all debt and closes their CDP/vault, if the storage entry isn't erased, stale data may be used by other code paths that don't check for vault existence. Look for: vault closure functions that don't delete the storage struct or mapping entry. [Decurity CDP]

- [ ] **Impossible debt repayment condition**: Edge cases where a user CANNOT repay their loan — e.g., repayment requires a token that's paused, or interest has accrued to exceed uint256, or the repayment function has a logic error that reverts. Look for: repay functions with conditions that could become impossible to satisfy. [Decurity CDP]

- [ ] **Stablecoin arbitrage via collateral swapping**: If a CDP allows depositing one stablecoin and withdrawing a different one at 1:1, an attacker can arbitrage any depeg. Look for: CDPs that treat all stablecoins as equal value without checking their actual price. [Decurity CDP]

- [ ] **LP token collateral pricing via `pool.getReserves()` is manipulable**: Pricing LP tokens using reserve ratios is vulnerable to flash loan manipulation. Correct approach uses fair LP pricing formulas. Look for: `pair.getReserves()` used in collateral valuation for Uniswap LP positions. [Decurity CDP]

- [ ] **Different Uniswap fee tiers for same pair**: Multiple pools exist for the same token pair (0.01%, 0.05%, 0.3%, 1%). If a protocol doesn't specify which pool, it may interact with the wrong one. Look for: LP collateral handling that doesn't distinguish fee tiers. [Decurity CDP]

- [ ] **Earn token depeg risk**: Wrapped tokens pegged to an asset (renBTC, cbETH) may depeg. If the protocol prices them 1:1 with the underlying, a depeg means the collateral is worth less than assumed. Look for: `1:1` price assumptions for wrapped/pegged tokens. [Decurity CDP]

- [ ] **Interest rate calculation timing — before or after liquidation**: If interest is calculated AFTER liquidation, the liquidation uses stale interest data. If BEFORE, the liquidation uses current but the vault may accrue interest between check and execution. Look for: interest accrual timing relative to liquidation execution. [Decurity CDP]

- [ ] **Auction math when partial collateral is auctioned**: If only part of a vault's collateral goes to auction, the remaining collateral-to-debt ratio must be recalculated correctly. Common bug: remaining collateral is overvalued or remaining debt is undervalued. Look for: partial liquidation functions that don't recompute the remaining position's health. [Decurity CDP]

- [ ] **Interrupted auction bid refunds**: If an auction is interrupted (debtor repays, higher bid, premature close), the previous bidder's funds must be returned. Look for: auction mechanisms where bid deposits aren't tracked and refunded on interruption. [Decurity CDP]

## Lending Integration (AAVE/Compound - from Beirao)

- [ ] **Utilization rate too high — collateral can't be retrieved**: If AAVE/Compound pool utilization approaches 100%, withdrawals revert because there's not enough idle liquidity. Protocols built on top that need to withdraw collateral will fail. Look for: protocols wrapping AAVE/Compound positions that don't handle high-utilization scenarios. [beirao AC-01]

- [ ] **AAVE siloed asset prohibition**: Borrowing an AAVE siloed asset prohibits borrowing ANY other asset. If a protocol borrows a siloed asset without knowing, all subsequent borrow operations fail. Look for: protocols that auto-select borrow assets on AAVE without checking `getSiloedBorrowing()`. [beirao AC-08]

- [ ] **AAVE isolated asset max debt cap**: On AAVE isolated assets, there's a maximum total debt. If the cap is reached, no one can borrow more — potential DoS for protocols relying on borrowing that asset. Look for: protocols that borrow isolated assets without checking remaining capacity. [beirao AC-09]

- [ ] **cETH has no `underlying()` function**: Compound's cETH token doesn't implement `underlying()` (since its underlying is native ETH). Code that calls `cToken.underlying()` generically will revert on cETH. Look for: generic Compound integrations that call `underlying()` on all cTokens. [beirao AC-07]

- [ ] **Paused AAVE/Compound markets**: If the integrated market is paused, deposit/withdraw/borrow/repay all fail. Protocol built on top needs fallback behavior. Look for: AAVE/Compound wrappers without handling for paused markets. [beirao AC-02]

- [ ] **Deprecated AAVE pools**: Pools can be deprecated, changing behavior. Look for: long-lived protocol integrations that don't monitor pool status. [beirao AC-03]

---

## Dacian — Lending/Borrowing DeFi Attacks (Phase 3)

- [ ] **Liquidation before default — paymentDefaultDuration < paymentCycleDuration**: If the liquidation threshold timer starts from `acceptedTimestamp` (loan acceptance) rather than the next payment due date, borrowers can be liquidated before their first repayment is even due when `paymentDefaultDuration` is small. Fix: calculate liquidation threshold as offset from when the next repayment is due. [Source: Dacian — Lending/Borrowing DeFi Attacks, Sherlock TellerV2]

- [ ] **Liquidation via unchecked collateralToken parameter**: If `liquidate(collateralToken, position)` doesn't validate that `collateralToken` actually corresponds to the position's collateral, an attacker can pass address(0) or a different token to force the collateral valuation to 0, triggering liquidation of non-defaulting borrowers. [Source: Dacian — Lending/Borrowing DeFi Attacks, Hats Finance Tempus Raft]

- [ ] **Borrower overwrites collateral to zero via unchecked AddressSet.add()**: If `commitCollateral()` uses `EnumerableSetUpgradeable.AddressSet.add()` without checking its boolean return value, calling it again with the same token and 0 amount silently overwrites the collateral record. Borrowers can zero their collateral after loan validation. [Source: Dacian — Lending/Borrowing DeFi Attacks, Sherlock TellerV2]

- [ ] **Debt closed without repayment via non-existent ID decrement**: If `close(id)` doesn't validate that `id` exists in the credits mapping, calling with non-existent IDs still decrements the loan `count` variable. Repeatedly calling with bogus IDs gets `count == 0`, marking the loan as fully repaid. [Source: Dacian — Lending/Borrowing DeFi Attacks, Code4rena DebtDAO]

- [ ] **Token disallow stops existing loan repayment but not liquidation**: If `repay()` has `onlyWhitelistedToken` modifier but `liquidate()` doesn't, disallowing a previously-allowed token creates an asymmetric state where borrowers can't repay but can be liquidated. Token disallow should only affect new loans. [Source: Dacian — Lending/Borrowing DeFi Attacks, Sherlock Blueberry Update 1]

- [ ] **No grace period after repayment resumption**: When repayments are unpaused, borrowers who became liquidatable during the pause are instantly liquidated by MEV bots. Grace period equal to pause duration (capped at max hours) should be implemented. [Source: Dacian — Lending/Borrowing DeFi Attacks, Sherlock Blueberry]

- [ ] **Liquidator takes all collateral by repaying smallest debt position**: If liquidation share calculation uses `share / oldShare` from a single position rather than total debt across all positions, a liquidator can drain all collateral by repaying only the smallest debt tranche. [Source: Dacian — Lending/Borrowing DeFi Attacks, Sherlock Blueberry]

- [ ] **Infinite loan rollover**: If the borrower can rollover their loan without any limit on count, duration, or lender approval, the lender may never be repaid and never be able to liquidate. [Source: Dacian — Lending/Borrowing DeFi Attacks, Sherlock Cooler]

- [ ] **Repayment sent to zero address after storage deletion**: If `loans[loanID]` is deleted before `debt.transferFrom(msg.sender, loan.lender, repaid)`, `loan.lender` resolves to address(0). Many ERC20s will silently succeed, losing the repayment forever. [Source: Dacian — Lending/Borrowing DeFi Attacks, Sherlock Cooler]

- [ ] **Borrower permanently unable to repay — repay() always reverts**: If the system can enter a state where `repay()` always reverts (e.g., due to token accounting bugs, whitelist changes, or paused dependencies), both borrower and lender lose — borrower loses collateral to liquidation, lender never gets repaid. [Source: Dacian — Lending/Borrowing DeFi Attacks]

- [ ] **Bulk repayment overflow not credited to subsequent loans**: When a borrower's single repayment amount exceeds the first loan's remaining debt, the excess must roll over to pay subsequent loans. If it doesn't, the borrower's total repayment is only partially credited while lender receives full amount. [Source: Dacian — Lending/Borrowing DeFi Attacks, Sherlock Astaria]

- [ ] **Liquidation leaves traders with unhealthier collateral basket**: If multi-collateral liquidation uses the more stable collaterals first instead of the riskiest, post-liquidation positions have worse risk profiles. Liquidation should prioritize less stable, riskier collateral. [Source: Dacian — Lending/Borrowing DeFi Attacks, Cyfrin Zaros]

## Dacian — DeFi Liquidation Vulnerabilities (Phase 3)

- [ ] **Profitable user withdraws all collateral, removing liquidation incentive**: In perpetuals, users with large positive PNL can withdraw all deposited collateral while remaining solvent. If PNL reverses, there's nothing to seize for liquidation reward. Fix: enforce minimum collateral deposit regardless of PNL. [Source: Dacian — DeFi Liquidation Vulnerabilities]

- [ ] **Partial liquidation bypasses bad debt accounting**: If bad debt coverage check only triggers on full position closure (`if (!hasPosition)`), a partial liquidator can strategically avoid closing the position entirely, bypassing the requirement to cover bad debt. [Source: Dacian — DeFi Liquidation Vulnerabilities, Code4rena Predy]

- [ ] **EnumerableSet ordering corruption prevents multi-position liquidation**: When liquidating accounts with multiple active markets, iterating over `EnumerableSet` while removing elements causes swap-and-pop ordering corruption, resulting in `panic: array out-of-bounds`. Fix: iterate over `values()` memory copy. [Source: Dacian — DeFi Liquidation Vulnerabilities, Cyfrin Zaros]

- [ ] **Front-running liquidation via nonce increment or micro self-liquidation**: If user-controlled variables (nonce, cooldown timer) are checked during liquidation, a liquidatable user can front-run the liquidation tx to change these variables, forcing the liquidation to revert. [Source: Dacian — DeFi Liquidation Vulnerabilities]

- [ ] **Pending withdrawal blocks liquidation**: If liquidation checks `require(balance - pendingWithdrawals > 0)`, a user can create a pending withdrawal equal to balance, making all subsequent liquidation attempts revert. [Source: Dacian — DeFi Liquidation Vulnerabilities, Dolomite]

- [ ] **ERC721 onReceived callback reverts liquidation**: If an NFT is "pushed" to a user-controlled address during liquidation, the attacker can revert in `onERC721Received`, making liquidation impossible. Same applies to ERC20 tokens with transfer hooks. Fix: use pull-based claims. [Source: Dacian — DeFi Liquidation Vulnerabilities, Code4rena Revert Lend]

- [ ] **Yield vault collateral not seized during liquidation**: If the protocol allows depositing collateral into external yield vaults but the liquidation code doesn't account for vault-deposited collateral, attackers can take loans, get liquidated, then withdraw collateral from the vault. [Source: Dacian — DeFi Liquidation Vulnerabilities, Cyfrin The Standard]

- [ ] **Insurance fund exhaustion blocks liquidation permanently**: If `liquidation reverts when badDebt > insuranceFund`, the protocol enters a permanent state where large insolvent positions cannot be liquidated until the fund accrues enough fees. [Source: Dacian — DeFi Liquidation Vulnerabilities]

- [ ] **Fixed liquidation bonus causes revert below bonus threshold**: A fixed 10% bonus causes liquidation to revert when user has <110% collateral ratio, even though they're under-collateralized. Fix: cap bonus to maximum available amount. [Source: Dacian — DeFi Liquidation Vulnerabilities]

- [ ] **Liquidation fails for non-18 decimal collateral tokens**: Multi-collateral protocols using mixed 18-decimal internal math and native-decimal transfers can have inconsistencies slip in that cause liquidation to revert for non-standard decimal tokens. [Source: Dacian — DeFi Liquidation Vulnerabilities, Pashov GainsNetwork]

- [ ] **Two nonReentrant modifiers in liquidation path**: Complex liquidation code that optionally calls multiple contracts can hit two `nonReentrant` modifiers on the same contract, causing liquidation to revert. [Source: Dacian — DeFi Liquidation Vulnerabilities, SigmaPrime August]

- [ ] **Zero-value transfer reverts block liquidation**: If liquidation code calculates small fee/reward amounts that round to zero, and the token reverts on zero-value transfers, liquidation is blocked. [Source: Dacian — DeFi Liquidation Vulnerabilities]

- [ ] **Token deny list (USDC blacklist) blocks liquidation via push mechanism**: If liquidation sends tokens to addresses on a deny list (e.g., USDC blacklist), the transfer reverts, making liquidation impossible. Fix: use pull-based claims. [Source: Dacian — DeFi Liquidation Vulnerabilities]

- [ ] **Single-borrower liquidation edge case**: Some protocols have `while (troveCount > 1)` in liquidation logic, preventing the last remaining borrower from ever being liquidated. [Source: Dacian — DeFi Liquidation Vulnerabilities, Cyfrin Bima]

- [ ] **Liquidation reward calculated using wrong token decimals**: If reward is paid in 18-decimal collateral but calculated using 6-decimal debt position value, the reward shrinks by 12 orders of magnitude, removing all liquidation incentive. [Source: Dacian — DeFi Liquidation Vulnerabilities, Code4rena Size]

- [ ] **Liquidation fee as % of seized collateral makes liquidation unprofitable**: A 30% protocol fee on total seized collateral (rather than on liquidator profit) removes incentive to liquidate many positions. Fee should be % of profit, not raw collateral. [Source: Dacian — DeFi Liquidation Vulnerabilities, Sherlock Sentiment V2]

- [ ] **Liquidation fees not included in minimum collateral requirement**: If min collateral to avoid liquidation doesn't account for liquidation fees, insufficient collateral exists at liquidation time, causing reverts or bad debt. [Source: Dacian — DeFi Liquidation Vulnerabilities, CodeHawks Zaros]

- [ ] **Earned yield not factored into collateral value — unfair liquidation**: If deposited collateral earns yield but yield isn't included in collateral valuation, users can be unfairly liquidated while their actual collateral value is sufficient. [Source: Dacian — DeFi Liquidation Vulnerabilities]

- [ ] **Borrow interest accumulates while protocol is paused**: If users can't repay during pause but interest keeps accruing, they can be instantly liquidated when unpaused due to interest buildup. [Source: Dacian — DeFi Liquidation Vulnerabilities, Code4rena BendDAO]

- [ ] **isLiquidatable doesn't refresh interest/funding fees before check**: View functions checking liquidation eligibility must first calculate latest accrued fees. Stale fee data means positions appear healthier than they are. [Source: Dacian — DeFi Liquidation Vulnerabilities]
