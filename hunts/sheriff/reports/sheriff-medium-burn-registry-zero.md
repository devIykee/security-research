# sheriff.money - Medium: LP burns revert when securityRegistry is unset
**Researcher:** deviykee
**Severity:** Medium - LP exits freeze if the plugin registry is address(0). Not a stranger drain. Live 17/17 Sheriff pools currently have the registry set. Bound: only pools whose plugin registry is 0.
**Status:** Verified with a local Foundry unit PoC of the exact sibling checks. Live config does not currently trigger it.
**Coverage:** 29/33 custom impl files (88%). Path-scoped. See `hunts/sheriff/coverage.md`.

## What this means in plain language (read this first)
Sheriff's pool plugin has a safety switch (SecurityRegistry). If that switch is turned off by setting the registry to the zero address, swaps and new LP deposits keep working, but withdrawing liquidity reverts. Users who already deposited cannot get their tokens back until an admin sets a real registry again. No special role is needed to be the victim. An admin who thinks "registry = 0 means security is off" will lock exits without meaning to.

## Affected contracts (Robinhood Chain, chainId 4663)
| Role | Address |
|---|---|
| SheriffBasePlugin (logic) | per-pool, e.g. `0xe3Bb07d5561775b921Dc103Fc5E1Ca3b2bbC6557` |
| SheriffBasePluginFactory | `0x7Ec0248158e4D536B6A47e5Eec3852283941Fb97` |
| SecurityRegistry (live) | `0x0AeB152d8A037afc1237F05d9501c761D53906A8` |

## Summary
`_checkStatus` (mint/swap/flash) skips the call when `securityRegistry == 0`. `_checkStatusOnBurn` always calls `getPoolStatus` on that address. A zero registry is treated as "open" for entry and "broken" for exit.

## Root cause
```solidity
// _checkStatus — mint / swap / flash
if (securityRegistry != address(0)) {
    ISecurityRegistry.Status status = ISecurityRegistry(securityRegistry).getPoolStatus(msg.sender);
    ...
}

// _checkStatusOnBurn — burn / decrease liquidity
ISecurityRegistry.Status status = ISecurityRegistry(securityRegistry).getPoolStatus(msg.sender);
if (status == ISecurityRegistry.Status.DISABLED) {
    revert PoolDisabled();
}
```

Factory `setSecurityRegistry` has no zero-address check, so `address(0)` is a reachable config. Wiring copies that value onto every new plugin.

## Attack
1. Admin sets factory or plugin `securityRegistry` to `address(0)` (intending to disable the halt switch), or a plugin is deployed before a registry is configured.
2. Swaps and mints still pass `_checkStatus`.
3. Any `burn` / `decreaseLiquidity` hits `address(0).getPoolStatus` and reverts.
4. Existing LP cannot exit until an admin sets a non-zero registry.

## Impact
Auth: admin config, then unauthenticated victims | Capital: none to trigger | Frequency: while registry is 0 | Victims: all LPs on that pool | Magnitude: 100% of that pool's liquidity is stuck (live TVL on WETH/USDG pool ~16.7 WETH + ~23.7k USDG, but those plugins currently have a registry)

## Proof of concept
`cd hunts/sheriff/poc && forge test --match-contract PoC -vv` → 3/3 pass. Mint/swap check succeeds, burn check reverts when registry is 0.

## Fix
Use the same zero-registry short-circuit in `_checkStatusOnBurn` as in `_checkStatus`. Reject `address(0)` in factory/plugin `setSecurityRegistry` unless that is an explicit "security off" mode, in which case burn must also no-op.

## Disclosure & compensation
Good-faith private disclosure. I'd appreciate a bounty commensurate with a Medium. I am NOT conditioning the disclosure or fix on payment. Act on it now.
Happy to walk the team through it and review the fix.
deviykee
