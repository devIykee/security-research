# Mezo - Med-High: Single-oracle fail-closed price gate locks borrows AND liquidations during any >60s oracle stall
**Researcher:** deviykee
**Severity:** Med-High - conditional on an oracle outage occurring; when it occurs, loss is protocol-wide bad debt plus total user exit lockout until feed resumes
**Status:** Verified on Mezo mainnet fork (block 11394888), read-only. No mainnet state touched.
**Disclosure:** Private. Not currently exploitable for theft; availability risk is standing.

## What this means in plain language (read this first)
MUSD is Mezo's BTC-backed stablecoin. Every important action in the system - opening a loan, repaying, closing, and crucially LIQUIDATING underwater loans - first asks one question: what is BTC worth right now? The contract accepts exactly one answer source and gives it a 60-second freshness window with no backup plan. If that single feed stalls for more than a minute, the entire MUSD machine seizes: nobody can borrow, nobody can repay, nobody can close their position to safety, and - worst of all - the protocol cannot liquidate risky positions either. If BTC crashes during such a stall, underwater positions sit unliquidated and the losses land on the protocol's stability pool (i.e., MUSD holders and stakers) instead of the borrowers who took the risk. This is a design that fails closed: it protects against wrong prices by refusing all prices, which converts an oracle hiccup into system-wide lockout plus potential bad debt.

## Affected contracts (Mezo mainnet, chainId 31612)
| Role | Address |
|---|---|
| PriceFeed | 0xc5aC5A8892230E0A3e1c473881A2de7353fFcA88 |
| Oracle (Mezo priceoracle precompile, node-native) | 0x7b7c000000000000000000000000000000000015 |
| Consumers (all revert via fetchPrice) | TroveManager, BorrowerOperations, StabilityPool, CollSurplusPool, HintHelpers |

## Summary
One wrong assumption: "the BTC price feed will never be silent for more than 60 seconds." There is no lastGoodPrice cache, no fallback oracle, no deviation band - just `require(block.timestamp - updatedAt <= 60)`.

## Root cause
`musd/solidity/contracts/PriceFeed.sol` lines 14 and 46-58:

```solidity
uint256 private constant MAX_PRICE_DELAY = 60;
...
(, int256 price, , uint256 updatedAt, ) = oracle.latestRoundData();
require(
    block.timestamp - updatedAt <= MAX_PRICE_DELAY,
    "PriceFeed: Oracle is stale."
);
return _scalePriceByDigits(uint256(price), oracle.decimals());
```

Single `oracle` address (owner-settable via `setOracle`, no timelock). The upstream Liquity V1 pattern (stale -> switch to cached lastGoodPrice + recovery mode) was replaced by revert-on-stale.

## Attack / failure sequence
1. Normal ops verified live 2026-08-25: precompile updates per-block (`updatedAt == block.timestamp == 1787669598` at block 11,383,457).
2. Oracle outage >60s: validator vote-extension stall, Connect oracle incident, or relayer halt.
3. All fetchPrice() consumers revert atomically: liquidations blocked while collateral value falls.
4. On resumption, liquidations execute against the NEW lower price with debts unchanged -> shortfall socialized to StabilityPool (MUSD savers), not the borrower.
5. During the stall, even risk-averse borrowers cannot closeTrove to de-risk.

## Impact
Auth: none needed (nobody attacks; everyone loses) | Capital: unbounded bad debt proportional to BTC drawdown during stall | Frequency: every qualifying outage | Victims: MUSD savers/stability providers primarily | Magnitude: function of outage length x market volatility

## Proof of result
`cd mezo/poc && forge test --fork-url https://mezo-mainnet.boar.network --fork-block-number 11394888 -vv`

```
[PASS] test_fresh_price_passes()               // updatedAt==now -> returns price
[PASS] test_exploit_stale_price_locks_everything() // updatedAt==now-61 -> reverts "PriceFeed: Oracle is stale."
```
Differential proof: identical state, 61-second timestamp delta flips the entire system between functional and fully locked.

## Fix
1. Cache `lastGoodPrice` on every successful read; on staleness serve cache + flag recovery mode (upstream Liquity V1 behavior).
2. Add secondary fallback source (e.g., SEDA-style store or TWAP) before failing.
3. At minimum: exempt liquidation paths from the staleness gate with a conservative haircut price, so underwater troves stay liquidatable in outages.
