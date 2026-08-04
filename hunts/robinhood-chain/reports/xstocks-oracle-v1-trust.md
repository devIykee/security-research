# xStocks CdpEngine / EquityOracle - Trust/Centralization: V1 oracle quorum=1 with single owner-reporter
**Researcher:** deviykee
**Severity:** Trust/Centralization (High impact if the reporter key is compromised or malicious). Not labeled Critical as a permissionless exploit: it requires the reporter/owner key.
**Status:** Verified read-only on Robinhood Chain. No mainnet state touched.
**Disclosure:** Private. Design/trust finding for the live CDP stack.

## What this means in plain language (read this first)
The CDP lets people deposit tokenized stock collateral (for example xTSLA) and mint a stablecoin against it. The amount you can mint, and whether you can be liquidated, depends on a price oracle.

On the live engine that still uses EquityOracle **V1**, the oracle is configured with **quorum = 1** and only **one reporter**. That reporter address is the same as the CDP owner. So one key fully controls the "market price" the CDP believes.

This is not something a random stranger can do without that key. It is a centralization risk: if that key is leaked, phished, or abused, the holder can mint too much stable against fake high prices, or liquidate users with fake low prices.

Your own V2 oracle source comments call the V1 single-key / quorum=1 setup an "arbitrary-price drain" class issue, which is why V2 enforces minimum quorum 2 and a median of independent reporters.

## Affected contracts (Robinhood Chain, chainId 4663)
| Role | Address |
|---|---|
| CdpEngine (getPrice path, live TVL) | 0x5812E883C09535078e0445F66f9f71Bde1fA7dF9 |
| EquityOracle V1 | 0x1E9291EAaB8123D2A76d6DC63f79455A40696f22 |
| collateral (xTSLA) | 0xCDb9089a3B897af2D498e1c96B8dB88443b28566 |
| owner / sole reporter (same) | 0x8EdE0eEb8C03a45886836A1baDec03CdB08cDFb2 |

Related (better, but separate): CdpEngine 0xF408d7AE369C6210a21e4b3364a24aCEE444BCAa uses EquityOracleV2 0xC324F1864516A3005194d240Ecf1b41532BD444c.

Live snapshot (read-only): CDP 0x5812… vault for owner held ~2300 xTSLA collateral and ~330000 xUSD debt. V1 `quorum() == 1`, `reporterCount(xTSLA) == 1`, `isReporter(owner) == true`.

## Summary
V1 price is the median of fresh reports, but with one reporter and quorum 1 the median is that single report. The CDP trusts it for mint, withdraw, and liquidate. That is owner-key risk on user funds, not a permissionless bug.

## Root cause
EquityOracle V1 allows any quorum including 1:

```solidity
function setQuorum(uint256 q) external onlyOwner {
    require(q > 0, "zero quorum");
    quorum = q;
}
```

`getPrice` only requires `freshCount >= quorum`. With one active reporter, that reporter's last fresh price is the feed.

CdpEngine (this deployment) calls `getPrice` for ratio checks on mint / withdraw / liquidate. Owner can also call `setReporter` and is themselves the only reporter.

EquityOracleV2 documents the intended fix:

```text
// Fixes the single-key / quorum=1 arbitrary-price drain of the simple oracle:
// price is ALWAYS the MEDIAN of independent, FRESH reporters,
// never owner-settable, guarded by ... MIN_QUORUM = 2
```

## Attack (requires reporter key; not permissionless)
1. Attacker obtains the owner/reporter key (or the key holder acts maliciously).
2. Inflated price: `report(xTSLA, hugePrice)` then mint max stable against thin collateral; move value out via the stable market.
3. Or crashed price: `report(xTSLA, tinyPrice)` then liquidate healthy vaults at a discount.
4. No third-party auth needed beyond that one key.

## Impact
Auth: reporter/owner key | Capital: depends on key holder | Frequency: while key holds feed | Victims: CDP depositors / stable holders | Magnitude: up to collateral and mint capacity on that engine (~2300 xTSLA class exposure observed)

Honest rubric: **Trust/centralization**, not Critical-permissionless.

## Proof of concept
Read-only checks (no state change):

```bash
RPC=https://rpc.mainnet.chain.robinhood.com
V1=0x1E9291EAaB8123D2A76d6DC63f79455A40696f22
CDP=0x5812E883C09535078e0445F66f9f71Bde1fA7dF9
COL=0xCDb9089a3B897af2D498e1c96B8dB88443b28566
OWNER=0x8EdE0eEb8C03a45886836A1baDec03CdB08cDFb2

cast call $V1 "quorum()(uint256)" --rpc-url $RPC
# 1
cast call $V1 "reporterCount(address)(uint256)" $COL --rpc-url $RPC
# 1
cast call $V1 "isReporter(address)(bool)" $OWNER --rpc-url $RPC
# true
cast call $CDP "owner()(address)" --rpc-url $RPC
# same OWNER
cast call $CDP "oracle()(address)" --rpc-url $RPC
# V1
cast call $CDP "vault(address)(uint256,uint256)" $OWNER --rpc-url $RPC
# collateral ~2300e18, debt ~330000e18
```

A full fork "malicious report then mint" PoC needs a fresh oracle window and is unnecessary to prove the trust model; the configuration is on-chain.

## Fix
1. Migrate all live CDPs off EquityOracle V1 onto EquityOracleV2 (or equivalent) with **minReporters >= 3**, independent reporter keys, deviation circuit breaker, and market-hours policy you actually enforce.
2. Do not leave quorum=1 on any engine with user collateral.
3. Prefer multisig / hardware isolation for remaining admin roles; never co-locate sole reporter with sole owner on a hot key.
4. Document for users that price security is currently trust-based on that key until migration completes.

## Disclosure & compensation
Good-faith private disclosure of a trust/centralization finding on live TVL. A discretionary bounty would be appreciated if this helps you prioritize the V1 retirement. I am NOT conditioning disclosure or fix on payment. Happy to help review a migration plan.

deviykee  
http://x.com/deviykee
