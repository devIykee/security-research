# Merry Men (PumpClaw) - High: V4 pool pre-init freezes all future launches

**Researcher:** deviykee  
**Severity:** High - unauthenticated, gas-only pre-init of the next CREATE token's Uniswap v4 pool permanently bricks `createToken` on this factory (nonce rolls back on revert; same predicted address forever). Bound: all future launches on factory `0xfa4B…96fE`. No theft of existing locked LP.  
**Status:** Verified on a local Anvil fork of Robinhood Chain. No mainnet state touched.  
**Disclosure:** Private. Live-exploitable now.

## What this means in plain language (read this first)

Merry Men is a "fair launch" pad: one click deploys a token and lists it on Uniswap v4 with all tokens as single-sided LP. No admin key is needed for the bug.

An attacker looks at the factory's next deployment address (standard CREATE prediction from the factory nonce). Before anyone launches, they open the Uniswap v4 market for that future token at any price (gas only, no tokens required). When a creator later presses create, the pad tries to initialize the market again, silently ignores the fact it already exists, then fails while adding liquidity (`CurrencyNotSettled`). The whole create transaction reverts.

Because the transaction reverts, the factory nonce does not advance. The next attempt predicts the same token address, hits the same pre-opened market, and fails again. The launchpad can never create another token until the team redeploys a fixed factory. Existing locked positions are not drained by this finding.

## Affected contracts (Robinhood Chain, chainId 4663)

| Role | Address |
|------|---------|
| Factory `PumpClawFactory` | `0xfa4B952c15BC9d418ae4f552F7Fc76b4470596fE` |
| LP Locker `PumpClawLPLocker` | `0xd404C0fF8dE11841a4ff9CC4382eA5F6e4010751` |
| Uniswap v4 PoolManager | `0x8366a39CC670B4001A1121B8F6A443A643e40951` |
| Uniswap v4 PositionManager | `0x58daec3116aae6D93017bAAea7749052E8a04fA7` |

## Summary

One wrong assumption: `positionManager.initializePool` is treated as "set our intended price," but Uniswap v4 soft-fails if the pool already exists (returns `type(int24).max` and does not revert). The factory never checks the return value or current `slot0` price, then mints with `amount0Max/amount1Max = type(uint128).max`. After a stranger pre-inits the predicted token's pool, mint settlement fails and `createToken` reverts forever for that factory.

## Root cause

Factory (verified):

```solidity
// Initialize pool at the boundary price
positionManager.initializePool(poolKey, sqrtPriceX96);
// ... no check of return value / slot0 ...
// MINT_POSITION with MAX_SLIPPAGE = type(uint128).max
```

Uniswap v4 periphery `IPoolInitializer_v4`:

```solidity
/// @dev If the pool is already initialized, this function will not revert and just return type(int24).max
function initializePool(PoolKey calldata key, uint160 sqrtPriceX96) external payable returns (int24);
```

Token address is plain `new PumpClawToken(...)` (CREATE), fully predictable from `factory` + `nonce`.

## Attack

1. Read factory nonce `N`; compute `token = create_address(factory, N)`.  
2. Build pool key: `currency0 = ETH (0x0)`, `currency1 = token`, `fee = 10000`, `tickSpacing = 200`, `hooks = 0`.  
3. Call `PoolManager.initialize(key, anyValidSqrtPrice)` (gas only).  
4. Any `createToken` now reverts with `CurrencyNotSettled()`.  
5. Retry fails the same way; factory nonce never advances.

## Impact

| Field | Value |
|-------|--------|
| Auth | none |
| Capital | gas only |
| Frequency | once freezes all future launches |
| Victims | every future creator / the product launch surface |
| Magnitude | permanent DoS of `createToken` on this factory (pad must redeploy) |
| Not claimed | theft of already-locked LP fees / positions |

## Proof of concept

```bash
export PATH="$HOME/.foundry/bin:$PATH"
# local anvil fork of RH (or --fork-url $RPC)
cd hunts/merrymen/poc
forge test --match-contract CreateAfterPreInitTest --fork-url http://127.0.0.1:8545 -vv
# PASS: test_preInit_freezes_createToken
forge test --match-contract BaselineCreateTest --fork-url http://127.0.0.1:8545 -vv
# PASS: create works when pool not pre-inited
forge test --match-contract V4SoftInitForkTest --fork-url http://127.0.0.1:8545 -vv
# PASS: soft init returns type(int24).max
```

Fork block used: `15685524` (Robinhood Chain).

## Fix

1. Prefer hard `poolManager.initialize` and **require success**, or treat `initializePool` return `type(int24).max` as revert.  
2. After init, read `slot0` and require `sqrtPriceX96 == intended`.  
3. Use CREATE2 with salt that includes a pool-uniqueness check, or check `getSlot0`/initialized flag **before** CREATE and abort cleanly with a clear error (still better with hard init).  
4. Optional: owner `rescue`/nonce-bump path is not a substitute for permissionless safety.

## Disclosure & compensation

Good-faith private disclosure. I'd appreciate a bounty commensurate with a High (pad-wide permanent launch freeze, gas-only, no privileged role). I am NOT conditioning the disclosure or fix on payment; act on it now. Happy to walk the team through it and review the fix.

deviykee
