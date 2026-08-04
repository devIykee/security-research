# AMM & DEX Security Checklist

## General AMM

- [ ] **Cross-contract view reentrancy on reserve updates**: Even with `nonReentrant`, if `reserves[]` is updated AFTER an external call (e.g., ERC777 token transfer), another contract can read stale reserves via a view function during the callback. Must follow CEI pattern when updating reserves. Look for: reserve state updates after `transfer()`/`transferFrom()` calls. [Decurity AMM]

- [ ] **Flash loan callback ordering**: AMM flash loan (FlashSwap in Uniswap) callback must be invoked AFTER the token transfer, not before. If called before, the borrower receives nothing but the callback has already executed. Look for: flash loan implementations where callback precedes token movement. [Decurity AMM]

- [ ] **Fee-on-transfer token handling**: AMM must either explicitly support FOT tokens (measure balance diff) or explicitly reject them. Neither = accounting mismatch. Balancer lost funds from a deflationary token that reduced reserves without AMM knowledge. Look for: AMMs that accept arbitrary tokens without FOT handling. [Decurity AMM, beirao AMM-03]

- [ ] **Rebasing tokens break AMM accounting**: Rebasing tokens change balance without transfers, but AMMs track reserves internally. The AMM's reserves diverge from actual balances, creating extractable arbitrage. Look for: AMMs holding rebasing tokens without rebase tracking or explicit blocklist. [beirao AMM-04]

- [ ] **Arbitrary call from user input**: If the AMM has a function accepting arbitrary calldata (e.g., for callbacks), an attacker can craft calls to drain approvals. Look for: `address.call(userProvidedData)` patterns. [Decurity AMM]

- [ ] **Signed integer balance updates**: If the AMM tracks balances with signed integers, `-int(amount)` can overflow for edge-case amounts like `type(uint256).max`. Look for: `int256` used for balance deltas without bounds checking. [Decurity AMM]

## Slippage Protection

- [ ] **Hardcoded slippage (especially `minAmountOut = 0`)**: Hardcoded zero slippage = sandwich attack for free. Every swap must have a user-specified or properly-calculated minimum output. Look for: `amountOutMinimum: 0`, `sqrtPriceLimitX96: 0`, or any hardcoded slippage parameter. [beirao U-01, U-02]

- [ ] **On-chain slippage calculation is manipulable**: If `minAmountOut` is calculated from on-chain data (e.g., `getAmountsOut()`, pool reserves), the attacker manipulates the pool first, then the slippage check passes the manipulated value. Must calculate slippage off-chain or use TWAPs. Look for: `minAmountOut` derived from pool.getReserves() or router.getAmountsOut(). [beirao U-02, Dacian]

- [ ] **No expiration deadline**: Swaps without a deadline parameter can be held by validators/MEV bots and executed later at a worse price. Look for: `deadline: type(uint256).max` or missing deadline parameter. [beirao U-02]

- [ ] **Missing refunds after swaps**: If a swap doesn't use all input tokens, the remainder should be refunded. Look for: swap functions that pull exact `amountIn` but may not use all of it. [beirao U-03]

## Uniswap V4 Hooks

- [ ] **Hook permissions derived from address bits, not contract code**: Uniswap V4 checks `uint160(address(hook)) & flag` to determine permissions. If the hook is deployed at an address that doesn't encode the right flag bits, the function is silently never called. Look for: hook deployment without proper address mining for permission flags. [Hacken UniV4]

- [ ] **Incorrect return type from hooks**: `beforeSwap` must return `(bytes4, BeforeSwapDelta, uint24)`. Returning wrong types causes overflow or reverts. Look for: hook functions with non-standard return types. [Hacken UniV4]

- [ ] **BeforeSwapDelta sign confusion**: BeforeSwapDelta is from the HOOK's perspective. Fees (hook takes tokens) must be NEGATIVE. Rebates (hook gives tokens) must be POSITIVE. Getting the sign wrong sends tokens the wrong way. Look for: positive deltas used as fees. [Hacken UniV4]

- [ ] **Delta ordering depends on `zeroForOne`**: The meaning of specified/unspecified in `BeforeSwapDelta` depends on `params.zeroForOne`. Using the wrong mapping causes tokens to flow in the wrong direction. Look for: `toBeforeSwapDelta()` calls that don't check swap direction. [Hacken UniV4]

- [ ] **Unsettled deltas revert `unlock()`**: ALL hook deltas must sum to zero via `settle()`/`take()` before transaction finalization. If any delta is non-zero, `NonzeroDeltaCount` check in `unlock()` reverts the entire transaction. Look for: hooks that modify deltas without corresponding settlement calls. [Hacken UniV4]

- [ ] **Async hooks steal custody**: Async hooks (where `specifiedTokenDelta = -params.amountSpecified`) completely replace Uniswap's swap logic and take full custody of the user's tokens. A malicious async hook can simply transfer tokens to the deployer. Look for: `beforeSwap` returning a specifiedTokenDelta equal to negative amountSpecified. [Hacken UniV4]

- [ ] **Hooks attached to multiple pools**: PoolManager doesn't enforce hook exclusivity. An attacker can create a pool with your hook attached and trigger it from their pool. Look for: hooks that don't validate the PoolKey against an expected pool. [Hacken UniV4]

- [ ] **Upgradeable hooks can't gain new permissions post-deploy**: Hook address encodes permission bits at deploy time. Upgrading the implementation to add `afterSwap()` won't work if the address bits don't include `AFTER_SWAP_FLAG`. Look for: UUPSUpgradeable hooks with planned future function additions. [Hacken UniV4]

- [ ] **Missing access control on hook functions**: If hooks don't check that `msg.sender == poolManager`, anyone can call them directly with arbitrary parameters. Look for: hook functions without `onlyPoolManager` or similar checks. [Hacken UniV4]

- [ ] **Dynamic fee manipulation via front-running**: Hooks that adjust swap fees based on oracle prices or market conditions can be front-run by MEV bots who trade before/after fee changes. Look for: fee logic that depends on manipulable on-chain state. [Hacken UniV4]

- [ ] **Unbounded loops in hooks cause DoS**: A hook with a growing array that's iterated on every swap will eventually hit gas limits, making the pool unusable. Look for: loops over dynamic arrays in hook functions. [Hacken UniV4]

- [ ] **lpFeeOverride can DoS swaps**: If a hook returns an excessive or invalid `lpFeeOverride`, swaps revert. Look for: unconstrained fee return values. [Hacken UniV4]

## TWAMM (Time-Weighted AMM)

- [ ] **Rebasing token balance changes during long-term swaps**: If a TWAMM holds rebasing tokens, balance changes mid-swap corrupt the order execution math. Look for: TWAMM implementations that don't block rebasing tokens. [Decurity AMM]

- [ ] **Insufficient liquidity check before swap execution**: TWAMM must verify sufficient liquidity exists before executing long-term orders. Look for: missing liquidity validation in TWAMM execution logic. [Decurity AMM]

## AMM Integration (for protocols integrating AMMs)

- [ ] **Callback function must verify caller is the pool**: When implementing Uniswap-style callbacks (`uniswapV3SwapCallback`, etc.), the callback must verify `msg.sender` is the legitimate pool contract. Without this, anyone can call the callback to steal tokens. Look for: swap callbacks without pool address verification. [Decurity AMM]

- [ ] **Don't use `pool.swap()` directly**: Always use Router contracts which enforce safety checks (deadline, slippage). Direct pool calls skip all protections. Look for: direct `IUniswapV3Pool.swap()` calls instead of router. [beirao U-07]

- [ ] **Pool reserves are manipulable**: Never use `pool.getReserves()` as a price oracle. Flash loans can manipulate reserves within a single transaction. Look for: `getReserves()` used in price calculations or access control. [beirao U-06]

- [ ] **AMM pool token0/token1 order differs by chain**: On Arbitrum, a pair may be WETH/USDC (WETH=token0), while on Polygon it's USDC/WETH (USDC=token0). Hardcoding the order breaks cross-chain. Look for: hardcoded assumptions about which token is token0 or token1. [multichain-auditor, beirao U-04]

- [ ] **Verify pool factory address**: If pools aren't from a whitelisted factory, they could be fakes. Verify `pool.factory() == expectedFactory`. Look for: pool addresses from user input without factory verification. [beirao U-05]

- [ ] **Hardcoded DEX pool fees prevent optimal routing**: Using a fixed fee tier (e.g., always 0.3%) may route through a suboptimal pool when a better fee tier exists. Look for: hardcoded fee parameters in swap paths. [ERC4626 primer pattern #46]

## Uniswap V4 Hooks Security (Expanded)

- [ ] **Hook address encodes permissions via low bits**: V4 derives hook permissions from the hook contract's address using bitwise operations, NOT from the contract itself. If a hook is deployed at an address missing the required flag bits, PoolManager will never call it. Conversely, extra bits cause calls to non-existent functions → revert → DoS. Look for: hooks deployed without address mining that matches intended permission flags. [Hacken UniV4, OpenZeppelin UniV4]

- [ ] **Hooks on multiple pools without pool isolation**: Any hook can be attached to multiple pools by default (no exclusivity enforcement in PoolManager). If hook state is shared across pools, one pool's operations corrupt another's state. Look for: hooks without per-PoolKey storage mapping or `beforeInitialize` that restricts to one pool. [Hacken UniV4, OpenZeppelin UniV4]

- [ ] **Async hooks take full custody of swap amounts**: Async hooks can set `specifiedTokenDelta = -params.amountSpecified`, completely bypassing Uniswap's swap logic. A malicious async hook can steal all swapped tokens by transferring them to an attacker address. Look for: hooks that return non-zero BeforeSwapDelta that reverses the swap amount. [Hacken UniV4]

- [ ] **Missing `onlyPoolManager` on hook functions**: Hook callback functions (beforeSwap, afterSwap, etc.) should only be callable by PoolManager. Without this check, anyone can call the hook directly and manipulate state or drain funds (see Cork Protocol $11M hack). Look for: hook functions without `msg.sender == address(poolManager)` check. [Hacken UniV4, OpenZeppelin UniV4]

- [ ] **Hook BeforeSwapDelta sign convention**: BeforeSwapDelta is from the hook's perspective: negative = hook takes tokens, positive = hook gives tokens. Wrong sign means the hook pays users instead of charging fees, or vice versa. Look for: positive deltas where fees should be negative. [Hacken UniV4]

- [ ] **Unsettled hook deltas cause revert in `unlock()`**: PoolManager checks `NonzeroDeltaCount` at end of `unlock()`. If a hook modifies deltas but doesn't settle them (via `settle()`/`take()`), the entire transaction reverts. Look for: hooks that return non-zero deltas without corresponding settlement logic. [Hacken UniV4]

- [ ] **Upgradeable hooks break address-encoded permissions**: If a hook is upgradeable (UUPS/Transparent proxy), the deployed address permissions are fixed at deployment. Adding new callback functions in an upgrade won't work because the address bits don't encode the new permissions. Look for: upgradeable hook contracts that plan to add callbacks post-deployment. [Hacken UniV4, OpenZeppelin UniV4]

- [ ] **lpFeeOverride can DoS swaps**: If a hook returns an invalid or excessive lpFeeOverride value, swaps on that pool fail. A centralized hook owner can set fees to 100%, effectively locking pool funds. Look for: hooks with admin-controlled fee parameters without bounds. [Hacken UniV4]

- [ ] **Hook `unlockCallback` data can call arbitrary functions**: The data passed to `unlockCallback` can be crafted to call any function on the hook. If the callback data formation isn't restricted, it acts as an unprotected entry point. Look for: hooks where users can influence unlockCallback calldata. [OpenZeppelin UniV4]

- [ ] **JIT liquidity attacks on hook-managed positions**: If a hook manages liquidity positions, anyone can trigger fee accrual on those positions at any time. Just-in-time liquidity modifications can conflict with the hook's fee accounting. Look for: hooks that accrue fees on positions without protecting against JIT manipulation. [OpenZeppelin UniV4]

- [ ] **Swap direction symmetry in hooks**: A swap can be zeroForOne or oneForZero, exactInput or exactOutput. Hook deltas must correctly handle all 4 combinations. Missing symmetry means hooks work for some swap types but break for others. Look for: hook logic that only handles `params.zeroForOne == true` or `params.amountSpecified < 0`. [OpenZeppelin UniV4, Hacken UniV4]

## AMM General (Expanded from Decurity/Beirao)

- [ ] **TWAMM rebasing token interaction**: If a TWAMM (Time-Weighted AMM) holds a rebasing token during a long-term swap, the balance changes from rebasing create an undercollateralized or overcollateralized position. Look for: TWAMM implementations that don't track rebasing token balance changes. [Decurity AMM]

- [ ] **Signed integer overflow in pool balance updates**: If an AMM uses signed integers for balance deltas, `-int(amount)` can overflow when `amount = type(uint256).max`. Look for: signed casts of user-supplied amounts in pool accounting. [Decurity AMM]

- [ ] **AMM callback address validation**: Callback functions (flash swap callbacks, swap callbacks) must validate that the caller is the expected AMM pool. Without this check, an attacker deploys a fake pool and calls the callback to steal tokens. Look for: callback functions that don't verify `msg.sender` against a known factory/pool address. [Decurity AMM]

- [ ] **AMM `token0`/`token1` order differs across chains**: In Uniswap-style AMMs, `token0 < token1` by address sort. The same token pair has different ordering on different chains because contract addresses differ. Price calculations that assume a fixed order will invert on some chains. Look for: hardcoded assumptions about which token is token0 vs token1. [multichain-auditor, beirao U-04]

- [ ] **Hardcoded slippage is forbidden**: Setting `amountOutMin = 0` or a hardcoded value allows sandwich attacks. Slippage must be calculated off-chain or via oracle and passed as parameter. Look for: `swapExactTokensForTokens(..., 0, ...)` or similar with zero/hardcoded minOut. [beirao U-01, U-02]

- [ ] **On-chain slippage calculation can be manipulated**: If slippage bounds are calculated on-chain from the current pool state, an attacker manipulates the pool state first, then the slippage calculation reflects the manipulated state. Look for: `minAmountOut = pool.getAmountOut(amount) * 99 / 100` patterns. [beirao U-02]

- [ ] **Don't rely on `pool.swap()` directly — use Router**: Direct pool interaction skips safety checks (deadline, slippage, path validation) that the router provides. Look for: direct calls to `IUniswapV3Pool.swap()` instead of going through `SwapRouter`. [beirao U-06, U-07]

- [ ] **Missing swap refund handling**: If a swap function receives more input tokens than needed (exact output swaps), the excess must be refunded. Look for: swap wrappers that don't return unused input tokens to the caller. [beirao U-03]

---

## Dacian — Concentrated Liquidity Manager Vulnerabilities (Phase 3)

- [ ] **Drain protocol via sandwich attack on owner functions missing TWAP check**: If `setPositionWidth()` or `unpause()` calls `_setTicks()` + `_addLiquidity()` without `onlyCalmPeriods` TWAP check, an attacker can sandwich the owner's tx to force liquidity deployment at manipulated prices, draining all protocol tokens. Beefy Finance lost ~$1.2M in this pattern. [Source: Dacian — CLM Vulnerabilities, Cyfrin Beefy Audit]

- [ ] **Owner rug-pull via ineffective TWAP parameters**: If `maxDeviation` and `twapInterval` can be set to arbitrary values by owner (e.g., maxDeviation=100%, twapInterval=1), the TWAP manipulation check becomes ineffective. Gamma Strategies was exploited this way. Fix: enforce min/max bounds on TWAP parameters. [Source: Dacian — CLM Vulnerabilities, Cyfrin Beefy Audit]

- [ ] **Tokens permanently stuck due to fee distribution rounding**: When distributing fees via `nativeEarned * fees.call / DIVISOR` etc., rounding remainders accumulate permanently in the contract. Fix: compute last recipient's share as `total - sum(others)`. [Source: Dacian — CLM Vulnerabilities, Cyfrin Beefy Audit]

- [ ] **Stale token approvals after router address update**: If `setUnirouter()` updates the router address without revoking unlimited `forceApprove` from the old router, the old router can still spend all protocol tokens. [Source: Dacian — CLM Vulnerabilities, Cyfrin Beefy Audit]

- [ ] **Updated management fees retrospectively applied to pending LP rewards**: If owner changes fee % and LP rewards are only collected at next `harvest()`, new higher fees apply retroactively to rewards earned under the previous lower fee. Fix: collect pending rewards before updating fees. [Source: Dacian — CLM Vulnerabilities, Cyfrin Beefy/Arrakis]

- [ ] **CLM overflow for large but valid sqrtPriceX96**: Protocol should not revert due to overflow for valid range of `sqrtPriceX96` values from the Uniswap pool. [Source: Dacian — CLM Vulnerabilities, Cyfrin Beefy Audit]

- [ ] **Withdraw returns 0 tokens while burning positive shares**: Edge case where `withdraw()` returns zero tokens but burns user's shares, effectively stealing from the user. [Source: Dacian — CLM Vulnerabilities, Cyfrin Beefy Audit]

## Dacian — DeFi Slippage Attacks (Phase 3)

- [ ] **No expiration deadline — block.timestamp provides no protection**: Setting deadline to `block.timestamp` offers zero protection because validators can hold the tx and `block.timestamp` will always equal the block it's included in. Deadline must be user-specified future timestamp. [Source: Dacian — DeFi Slippage Attacks]

- [ ] **Slippage enforced on intermediate operation, not final amount**: If `minTokensOut` is checked during `_exitBalancerPool()` but a subsequent treasury skim further reduces the user's output, the user receives less than their specified minimum. Slippage must be enforced on the final step. [Source: Dacian — DeFi Slippage Attacks, Sherlock Olympus Update]

- [ ] **On-chain slippage calculation via Quoter is manipulable**: `Quoter.quoteExactInput()` itself performs a swap and is subject to sandwich manipulation. Slippage parameters must be calculated off-chain by the user. [Source: Dacian — DeFi Slippage Attacks, Sherlock Derby]

- [ ] **Hard-coded slippage freezes user funds during volatility**: Fixed low slippage (e.g., 1%) protects in normal conditions but causes all withdrawals to revert during high volatility, freezing user funds. Users must be able to override default slippage. [Source: Dacian — DeFi Slippage Attacks, Code4rena Sturdy]

- [ ] **Hard-coded UniswapV3 fee tier**: If the swap function hard-codes fee tier (e.g., 3000), it will fail for token pairs where that tier doesn't exist, or provide inferior liquidity vs another tier. Allow users to pass fee tier. [Source: Dacian — DeFi Slippage Attacks]

- [ ] **Minting functions are swaps without slippage**: When protocol mints native tokens based on pool reserves (effectively a swap), users must be able to specify slippage. Without it, the mint is sandwichable. [Source: Dacian — DeFi Slippage Attacks, Code4rena Vader]

- [ ] **Mismatched slippage precision across token decimals**: If `minTokenOut` is calculated in 6 decimals but the output token has 18 decimals, the slippage check is ineffective (off by 12 orders of magnitude). Must scale slippage to output token's precision. [Source: Dacian — DeFi Slippage Attacks, Sherlock RageTrade]
