# Weird ERC20 Token Security Checklist

Every known ERC20 edge case that can break protocols. Not basic "use SafeERC20" advice — specific token behaviors.

## Transfer Behavior Anomalies

- [ ] **Fee-on-transfer tokens (USDT on some chains, STA, PAXG, SAFEMOON)**: Tokens that deduct a fee on every transfer. The received amount ≠ sent amount. Any protocol that records `amount` from the function parameter instead of measuring `balanceAfter - balanceBefore` will have inflated internal accounting. Look for: `token.transferFrom(user, address(this), amount)` followed by recording `amount` as the deposit. [weird-erc20, beirao FT-06]

- [ ] **Rebasing tokens (stETH, AMPL, aTokens, OHM)**: Token balances change automatically without transfers. A protocol holding 100 stETH at time T may hold 101 stETH at time T+1 without any transaction. Internal accounting based on cached balances will drift from actual holdings. Look for: any internal balance tracking that doesn't periodically re-sync with actual `balanceOf`. [weird-erc20, beirao V-01]

- [ ] **Tokens that revert on zero-amount transfer (LEND, BNB)**: Some tokens revert when `transfer(to, 0)` is called. If a reward distribution or fee collection computes zero and then transfers, it causes DoS. Look for: transfer calls where the amount could be 0 in edge cases (empty rewards, rounding to zero). [beirao FT-12]

- [ ] **Tokens that revert on transfer to specific addresses (LUSD)**: LUSD reverts when transferring to certain addresses (its own address, zero address, pool addresses). Look for: protocols that transfer tokens to addresses derived from user input without whitelist checking. [beirao FT-15]

- [ ] **Multiple-address tokens (Synthetix SNX)**: Some tokens are accessible via multiple contract addresses (proxy + implementation, or multiple proxies). If your protocol tracks by token address, the same underlying token appears as different tokens. Look for: allowlists or mappings keyed by token address that could miss an alias. [beirao FT-05]

- [ ] **Flash-mintable tokens (DAI, any token with `flashMint`)**: Tokens supporting flash minting temporarily inflate `totalSupply` within a transaction. Any pricing formula using `totalSupply` (e.g., `price = reserves / totalSupply`) becomes manipulable. Look for: `totalSupply()` used in price or share calculations. [beirao FT-11]

- [ ] **Tokens with blocklists/blacklists (USDC, USDT, cUSDC)**: Transfer to/from blocklisted addresses reverts. If your contract or a user gets blocklisted, funds are permanently stuck. Look for: any protocol that holds user funds in a shared vault — if the vault address gets blocklisted, all users lose funds. [weird-erc20, beirao FT-04]

- [ ] **Tokens with transfer pausing (USDC, USDT, BNB)**: The token issuer can pause ALL transfers. If the collateral token is paused, users can't add collateral but can still be liquidated = unfair liquidation. Look for: collateral/debt tokens that have pause functionality and the protocol's behavior when transfers revert. [Decurity CDP checklist]

- [ ] **Tokens with admin minting/burning (centralized stablecoins)**: Token admins can mint unlimited tokens or burn from any address. A protocol using such a token as collateral faces unbounded dilution risk. Look for: collateral tokens where the admin can inflate supply. [weird-erc20]

## Approval & Allowance Edge Cases

- [ ] **USDT approve race condition**: USDT requires setting allowance to 0 before changing to a new non-zero value. `approve(spender, newAmount)` reverts if current allowance > 0 and newAmount > 0. Look for: `token.approve()` without first resetting to 0, especially on tokens that could be USDT. Fix: use `safeIncreaseAllowance` / `safeDecreaseAllowance`, or always approve(0) first. [beirao FT-02, weird-erc20]

- [ ] **BNB reverts on zero-amount approval**: Unlike USDT, BNB reverts when `approve(spender, 0)` is called. So the "always approve 0 first" pattern fails for BNB. Look for: generic approve-to-zero patterns in protocols supporting multiple tokens. [ERC4626 primer]

- [ ] **Infinite approval can be drained**: If a contract holds user approvals (e.g., a router), a bug in any function that calls `transferFrom` using those approvals can drain all approved tokens. Look for: contracts that receive approvals and make arbitrary calls or have complex transfer logic. [beirao FT-13]

## Missing Return Values

- [ ] **USDT on Ethereum has no return value on `transfer()`/`transferFrom()`**: The ERC20 spec says these should return `bool`, but USDT doesn't. Raw `.transfer()` calls will work, but wrapping in an interface that expects `bool` will revert. Look for: direct `IERC20(token).transfer()` calls without SafeERC20. [weird-erc20, multichain-auditor]

- [ ] **Different interfaces across chains**: USDT on Ethereum: no return value. USDT on Polygon: returns bool. Same token, different interface. Look for: hardcoded interface assumptions in multichain deployments. [multichain-auditor]

- [ ] **Solmate SafeTransferLib doesn't check contract existence**: Unlike OpenZeppelin's SafeERC20, Solmate's `safeTransfer()` returns success for calls to addresses with no code (EOAs, not-yet-deployed contracts). Look for: `import {SafeTransferLib}` from solmate where the token address could be invalid. [beirao FT-09]

## Decimal Quirks

- [ ] **Decimals vary across chains**: USDT/USDC = 6 decimals on Ethereum, 18 decimals on BSC. A protocol hardcoding `10**6` will break on BSC. Look for: hardcoded decimal values, especially `1e6`, `1e18`, or `10**decimals` with assumed values. [multichain-auditor]

- [ ] **Tokens with 0 decimals**: Some tokens use 0 decimals (indivisible). Math that divides by `10**decimals` divides by 1 (no-op) but rounding issues appear in share calculations. Look for: vault/share math that doesn't handle 0-decimal tokens. [weird-erc20]

- [ ] **Tokens with >18 decimals (e.g., YAM-V2 has 24)**: Multiplication of two such values can overflow uint256. Look for: `amount * price` or `amount * rate` calculations without overflow protection for high-decimal tokens. [weird-erc20]

- [ ] **`IERC20(address(0)).decimals()` reverts**: Calling `decimals()` on the zero address reverts. If a token address hasn't been set yet, this causes DoS. Look for: `decimals()` calls on potentially-unset token addresses. [beirao FT-10]

## ERC777 & Hook-Based Tokens

- [ ] **ERC777 tokens disguised as ERC20**: ERC777 is backward-compatible with ERC20. A protocol accepting "any ERC20" may receive an ERC777, enabling reentrancy via `tokensToSend` (before transfer) and `tokensReceived` (after transfer) hooks. Look for: protocols with open token allowlists that don't explicitly block ERC777. [beirao FT-08, Decurity AMM checklist]

- [ ] **ERC677 `transferAndCall` hooks**: Similar to ERC777, ERC677 tokens (like LINK) have a `transferAndCall` that triggers a callback. Look for: protocols interacting with LINK or other ERC677 tokens without reentrancy protection. [Decurity AMM checklist]

## Permit (ERC-2612) Edge Cases

- [ ] **DAI permit uses non-standard signature**: DAI's permit function has a different parameter ordering than ERC-2612. Code that assumes standard permit will fail on DAI. Look for: generic `permit()` wrappers that don't handle DAI's variant. [ERC4626 primer]

- [ ] **Missing `DOMAIN_SEPARATOR()` function**: Some tokens implementing permit lack the `DOMAIN_SEPARATOR()` getter. Look for: code that queries `DOMAIN_SEPARATOR()` on arbitrary tokens. [beirao FT-14]

- [ ] **Permit front-running griefing**: An attacker can front-run a permit transaction by copying the signature and submitting the permit themselves. The original user's subsequent `transferFrom` then succeeds (because allowance is set), but if the user's transaction was `permit + transferFrom` in one call, the permit part reverts with "invalid nonce". Look for: contracts that call permit in the same transaction as other operations. [weird-erc20]

## Protocol-Specific Token Behaviors

- [ ] **USDT is upgradeable on Polygon but immutable on Ethereum**: The same token may behave differently on different chains due to proxy status. Look for: assumptions about token immutability in multichain deployments. [multichain-auditor]

- [ ] **Gnosis Chain USDC/WETH/WBTC have post-transfer callbacks**: On Gnosis (formerly xDai), these tokens had transfer callbacks enabling reentrancy. The chain hard-forked to fix it. Look for: token interaction patterns that assume no callbacks exist for standard tokens on non-mainnet chains. [multichain-auditor]

- [ ] **Rebasing tokens in AMMs**: If a rebasing token is in an AMM pool, the pool doesn't update reserves on rebase. This creates an arbitrage opportunity where someone can extract the rebase yield from the pool. Look for: AMMs or vaults holding rebasing tokens without rebase tracking. [beirao AMM-04]

## Additional Weird ERC20 Behaviors (Expanded)

- [ ] **Tether Gold returns `false` even on success**: Some tokens declare `bool` return but return `false` regardless of transfer success. SafeERC20 patterns checking for `false` return will incorrectly revert. This makes it impossible to build a correct generic transfer wrapper for ALL tokens. Look for: protocols that treat `return false` as failure for all tokens. [weird-erc20]

- [ ] **UNI/COMP revert on amounts > uint96**: UNI and COMP use uint96 for internal balance tracking. `transfer()` and `approve()` revert if amount exceeds `type(uint96).max`. However, `approve(uint256(-1))` sets allowance to `type(uint96).max` as a special case. Look for: protocols that approve `type(uint256).max` and expect it to be reflected exactly in `allowance()`. [weird-erc20]

- [ ] **`transferFrom` with src==msg.sender has inconsistent behavior**: DSToken-style tokens skip allowance deduction when `from == msg.sender`, making `transferFrom(address(this), dst, amt)` equivalent to `transfer(dst, amt)`. OpenZeppelin/Uniswap always deducts allowance. Look for: contracts relying on consistent `transferFrom` allowance behavior. [weird-erc20]

- [ ] **cUSDCv3 `transfer(type(uint256).max)` only sends balance**: Some tokens treat `amount == type(uint256).max` as "transfer all my balance". A protocol that transfers a user-supplied `type(uint256).max` amount and credits the full value in storage will have inflated accounting. Look for: vault systems that don't verify received amounts via balance difference. [weird-erc20]

- [ ] **ERC20 representation of native currency (CELO, POL, zkSync ETH)**: Some chains have ERC20 wrappers for their native token at fixed addresses. A protocol interacting with both native ETH and ERC20 tokens on these chains must guard against double-spending where the same asset can be used as both native and ERC20. Led to critical Uniswap V4 vulnerability on Celo. Look for: protocols on Celo/Polygon/zkSync that accept both native + ERC20 without deduplication. [weird-erc20]

- [ ] **Non-string metadata fields (MKR uses bytes32)**: MKR's `name()` and `symbol()` return `bytes32` not `string`. Contracts that decode metadata as string will get garbage or revert. Look for: `IERC20Metadata(token).name()` calls on arbitrary tokens without try/catch. [weird-erc20]

- [ ] **USDC/USDT have different decimals on different chains**: USDT = 6 decimals on ETH, 18 on BSC. USDC = 6 on ETH, 18 on BSC. A cross-chain protocol using hardcoded decimals will miscalculate values. Look for: `decimals` assumptions in cross-chain or multichain deployments. [multichain-auditor]

- [ ] **Phantom functions on tokens without permit**: Tokens that don't implement `permit()` won't revert on low-level calls — the call succeeds as a no-op (phantom function). Code that calls `permit()` then `transferFrom()` may silently skip the permit. Look for: `try token.permit(...)` patterns that don't verify the permit actually set allowance. [weird-erc20]

- [ ] **Tokens that revert on transfer to self (address(token))**: LUSD and some tokens revert when you transfer to the token's own address. Look for: patterns where `token.transfer(address(token), amount)` could occur, e.g., when destination is derived from user input. [weird-erc20, beirao FT-15]
