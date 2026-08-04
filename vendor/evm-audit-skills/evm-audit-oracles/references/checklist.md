# Oracle & Pricing Security Checklist

## Chainlink Price Feeds

### Staleness & Liveness
- [ ] **Check `updatedAt` for staleness**: Chainlink returns `(roundId, answer, startedAt, updatedAt, answeredInRound)`. If `block.timestamp - updatedAt > heartbeat`, the price is stale. Different feeds have different heartbeats (ETH/USD: 1h on mainnet, 24h on some L2s). Look for: `latestRoundData()` without staleness check or with wrong heartbeat value. [SigmaPrime oracle, beirao O-01]

- [ ] **Hardcoded staleness threshold across chains**: ETH/USD heartbeat is 3600s on Ethereum, 86400s on Arbitrum. Deploying with a hardcoded 3600s threshold on Arbitrum causes constant "stale price" rejections. Look for: single staleness constant used across multi-chain deployments. [multichain-auditor, beirao O-03]

- [ ] **`answeredInRound < roundId` = stale answer from old round**: The answer wasn't updated in the current round. This is a secondary staleness signal beyond timestamp. Look for: missing `answeredInRound >= roundId` check. [beirao O-02]

- [ ] **`startedAt == 0` means round hasn't started**: A round with `startedAt == 0` is invalid — no price update has occurred for this round. Look for: missing `startedAt > 0` check. [SigmaPrime oracle]

### Answer Bounds
- [ ] **`minAnswer` / `maxAnswer` circuit breakers**: Chainlink feeds have hard-coded min/max bounds (e.g., LUNA/USD had `minAnswer = $0.10`). When the real price drops below min, the feed reports `minAnswer` instead of the real price, enabling massive over-borrowing. Look for: protocols that don't check if `answer == aggregator.minAnswer()` or `answer == aggregator.maxAnswer()`. [SigmaPrime oracle, beirao O-04]

- [ ] **Negative prices**: Some feeds CAN return negative prices (oil futures in 2020). `int256 answer` cast to `uint256` becomes a massive number. Look for: `uint256(answer)` without `answer > 0` check. [beirao O-05]

- [ ] **Price = 0 not handled**: If Chainlink returns 0, any multiplication-based valuation stays 0 (allowing free borrows) or any division by price reverts. Look for: missing `answer != 0` check. [SigmaPrime oracle]

### L2 Sequencer
- [ ] **L2 sequencer uptime feed**: On Arbitrum/Optimism, when the sequencer goes down and comes back up, stale prices from before the outage are used. Must check the L2 sequencer uptime feed and apply a grace period after restart. Look for: Chainlink usage on L2s without sequencer uptime feed check. [beirao O-06, multichain-auditor]

- [ ] **Grace period too short after sequencer restart**: After the sequencer comes back, oracles need time to update. A grace period of < 1 hour can still use stale prices. Look for: sequencer grace period < 3600 seconds. [SigmaPrime oracle]

### Feed Configuration
- [ ] **Chainlink feed decimals vary**: ETH/USD = 8 decimals, ETH/BTC = 8 decimals, but some feeds use 18 decimals. Using `feed.decimals()` is mandatory. Look for: hardcoded `10**8` or `10**18` adjustments on oracle prices. [beirao O-07, SigmaPrime oracle]

- [ ] **Deprecated feeds**: Chainlink can deprecate feeds. Using deprecated feeds may return stale data. Check: https://docs.chain.link/data-feeds/deprecating-feeds. Look for: hardcoded feed addresses without admin-changeable configuration. [SigmaPrime oracle]

- [ ] **Oracle assumes base=USD when it's actually ETH**: If a protocol needs USD price but uses a `/ETH` denominated feed (or vice versa), all valuations are wrong by the ETH/USD ratio. Look for: feed denomination assumptions without validation. [SigmaPrime oracle]

## TWAP Oracles

- [ ] **TWAP manipulation via low liquidity**: A TWAP oracle averages price over a window, but in low-liquidity pools, even the TWAP can be cheaply manipulated by holding a price position across multiple blocks. Cost: `(manipulation_amount × blocks × block_time) / pool_depth`. Look for: TWAP windows < 30 minutes on pools with < $10M TVL. [SigmaPrime oracle, beirao O-08]

- [ ] **Uniswap V3 TWAP uses geometric mean**: Unlike V2's arithmetic mean, V3 TWAP is geometric. The geometric mean is ALWAYS ≤ arithmetic mean for non-constant prices. This systematically underprices volatile assets. Look for: protocols using V3 TWAP without understanding it returns geometric mean. [SigmaPrime oracle]

- [ ] **TWAP window too long hides current conditions**: A 24-hour TWAP during a flash crash still shows a near-normal price. This delays liquidations. Look for: TWAP windows > 4 hours used for liquidation triggers. [SigmaPrime oracle]

- [ ] **TWAP on rebasing token**: If a rebasing token's supply doubles, its price halves. TWAP doesn't capture this instantly, creating arbitrage. Look for: TWAP oracles for rebasing token pairs. [SigmaPrime oracle]

- [ ] **Uniswap V3 `observe()` reverts if oracle not initialized**: The oracle must have at least `cardinality` observations. If `cardinality == 1` (default), only the current block is available and any historical query reverts. Look for: `pool.observe()` calls without prior `increaseObservationCardinalityNext()`. [SigmaPrime oracle]

## Spot Price Manipulation

- [ ] **NEVER use spot reserves as a price oracle**: `pool.getReserves()` can be manipulated within a single transaction via flash loans. Any pricing based on instantaneous reserves is attackable. Look for: `IUniswapV2Pair.getReserves()`, `pool.slot0()`, or `balanceOf()` used for pricing. [beirao O-09, SigmaPrime oracle]

- [ ] **Read-only reentrancy on Balancer/Curve**: During a Balancer/Curve callback (before state update), calling a view function (like `getRate()`) returns a manipulated rate because the pool state is mid-update. Classic exploit: Sentiment ($1M). Look for: any price query to Balancer/Curve pools within a callback or the same transaction as a pool interaction. [beirao O-10]

## Price Peg Assumptions

- [ ] **Assuming 1 WBTC = 1 BTC**: WBTC consistently trades at a slight discount to BTC. Using 1:1 creates systematic mispricing. Look for: WBTC valued using BTC/USD feed without WBTC/BTC adjustment. [SigmaPrime oracle, beirao O-11]

- [ ] **Assuming 1 stETH = 1 ETH**: stETH depegged to 0.93 ETH in June 2022. Any protocol assuming 1:1 was exploitable during the depeg. Must use actual stETH/ETH price feed. Look for: stETH, wstETH, cbETH, rETH valued 1:1 with ETH. [SigmaPrime oracle, beirao O-12]

- [ ] **Assuming 1 USDC = 1 USD**: USDC depegged to $0.87 in March 2023 (SVB). Protocols hardcoding $1 USDC were exposed. Look for: stablecoin valuations without actual price feed (hardcoded to 1). [SigmaPrime oracle]

- [ ] **LP token valuation via reserves**: `LP_value = 2 * sqrt(reserve0 * reserve1) * price` (Alpha Homora formula) is manipulation-resistant. Using `(reserve0 * price0 + reserve1 * price1) / totalSupply` is manipulable. Look for: LP token pricing formulas that use raw reserves. [SigmaPrime oracle]

## Pyth Network

- [ ] **Pyth prices are pull-based**: Unlike Chainlink (push), Pyth prices must be pushed on-chain by the caller. If nobody pushes, the price is stale. Look for: Pyth integration that assumes prices update automatically. [SigmaPrime oracle]

- [ ] **Pyth confidence interval**: Pyth returns `(price, conf, expo, publishTime)`. During high volatility, `conf` (confidence interval) can be very wide, meaning the price is uncertain. Protocols should check that `conf / price < threshold` (e.g., 5%). Look for: Pyth price usage without confidence interval check. [SigmaPrime oracle]

- [ ] **Pyth `publishTime` staleness**: Must check `publishTime` is recent, similar to Chainlink `updatedAt`. Look for: Pyth prices without publishTime freshness check. [SigmaPrime oracle]

## General Oracle Security

- [ ] **Single oracle dependency**: If the protocol relies on one oracle and it fails/is manipulated, everything breaks. Use multiple oracles with fallback logic (Chainlink primary, TWAP fallback, manual override emergency). Look for: single `priceFeed.latestRoundData()` without fallback. [SigmaPrime oracle]

- [ ] **Oracle update frequency vs protocol tick frequency**: If the oracle updates every hour but the protocol checks prices every minute, 59 out of 60 checks use a "stale" price. This is expected behavior for Chainlink, but the protocol must design around it. Look for: high-frequency price checks on low-frequency oracle feeds. [SigmaPrime oracle]

- [ ] **Multi-hop price derivation accumulates error**: ETH/USD = ETH/BTC × BTC/USD — each feed has its own error range. Multi-hop prices compound errors. Look for: price derivation using 3+ oracle hops. [SigmaPrime oracle]

## Chainlink Deep Dive (Expanded from Beirao/Arbitrum Checklist)

- [ ] **ETH pricefeeds used for stETH, BTC pricefeeds used for WBTC**: Using ETH/USD feed for stETH ignores the stETH/ETH discount during depegs. Using BTC/USD for WBTC ignores WBTC's depeg risk. Must use the specific derivative price feed or account for the exchange rate. Look for: oracle price feeds used for derivative tokens without accounting for the peg. [beirao CL-13]

- [ ] **Oracle price update front-running**: When an oracle submits a price update tx, it's visible in the mempool. Attackers can front-run the update to profit from the price change (e.g., borrow before a collateral price increase is recorded). Look for: protocols where user actions and oracle updates interact in time-sensitive ways. [beirao CL-11]

- [ ] **Flash crash: minAnswer/maxAnswer circuit breakers**: Some Chainlink feeds have min/max answer bounds. During flash crashes, the feed returns `minAnswer` instead of the actual (lower) price. Protocol still prices collateral at `minAnswer`, which may be much higher than reality. Look for: Chainlink integrations without `require(answer > minAnswer && answer < maxAnswer)` style checks. [beirao CL-14, Arbitrum Checklist]

- [ ] **Pricefeed heartbeat too slow for use case**: A 24-hour heartbeat feed is fine for weekly settlements but dangerous for real-time liquidations. If the actual price drops 50% between heartbeats, the protocol uses a 50% stale price. Look for: protocols using feeds with heartbeats longer than their position health check frequency. [beirao CL-08]

- [ ] **Hardcoded pricefeed addresses can become deprecated**: Chainlink deprecates feeds over time (especially for uncommon pairs). A hardcoded address will return stale data indefinitely if deprecated. Look for: hardcoded Chainlink feed addresses without a governance mechanism to update them. [beirao CL-10]

- [ ] **Different decimal precision across feeds**: Feed decimals aren't always 8 or 18 — they vary by feed. LINK/ETH uses 18 decimals, LINK/USD uses 8. Incorrect decimal handling causes 10^10x price errors. Look for: hardcoded `10**8` or `10**18` divisors in oracle price normalization. [beirao CL-09, Arbitrum Checklist]

- [ ] **L2 sequencer down = stale prices**: On Arbitrum/Optimism, if the sequencer goes down, oracle prices don't update. When the sequencer comes back, the first reported price may jump significantly from the last pre-downtime price. Look for: oracle integrations on L2 without sequencer uptime feed checks. [beirao CL-06, Arbitrum Checklist]

## Oracle Price Zero Edge Case

- [ ] **Oracle returns price of zero**: Some feeds may return 0 during initialization or error conditions. A zero price means infinite collateral value or zero debt value, depending on usage. Look for: oracle integrations that don't check `price > 0`. [Decurity CDP]

---

## Cyfrin — Chainlink Oracle Security Considerations (Phase 3)

- [ ] **Same heartbeat used for multiple feeds with different update frequencies**: If both BTC/USD (1hr heartbeat) and USDC/USD (24hr heartbeat) use the same staleness threshold, one will be too strict (false stale) or too lenient (actually stale). Each feed needs its own heartbeat constant. [Source: Cyfrin — Chainlink Oracle Security, Sherlock JOJO]

- [ ] **Oracle price feed not updated frequently — high deviation threshold**: Similar feeds can have different heartbeat & deviation thresholds. A feed with 1% deviation and 1hr heartbeat will be more accurate than one with 5% deviation and 24hr heartbeat. Use the most responsive feed available. [Source: Cyfrin — Chainlink Oracle Security]

- [ ] **Wrong price feed address in constructor vs comments**: Developers copy the correct address in comments but hardcode the wrong address in the constructor (e.g., ETH/USD instead of BTC/USD). Verify all hardcoded addresses against Chainlink's official feed list. [Source: Cyfrin — Chainlink Oracle Security, Sherlock USSD]

- [ ] **Oracle price update front-running for stablecoin protocols**: Stablecoin mint/burn operations can be sandwich-attacked around oracle price updates. The attacker sees the oracle update in the mempool and trades before/after. Fix: add mint/burn fees, enforce deposit-to-withdraw delay. [Source: Cyfrin — Chainlink Oracle Security, Angle Research]

- [ ] **Unhandled oracle revert causes complete DoS**: Chainlink multisigs can block price feed access at will. If calls aren't wrapped in try/catch, a disabled feed bricks the entire protocol. Provide functionality to update oracle addresses post-deployment. [Source: Cyfrin — Chainlink Oracle Security, Code4rena Inverse]

- [ ] **WBTC depeg not detected when using BTC/USD feed**: If WBTC bridge is compromised, WBTC depegs from BTC but the protocol still prices WBTC at BTC/USD. Attacker buys cheap WBTC, deposits at BTC price. Use WBTC/BTC feed to monitor depeg. [Source: Cyfrin — Chainlink Oracle Security]

- [ ] **Oracle minAnswer/maxAnswer masks flash crash prices**: During flash crashes, the oracle returns its floor price (minAnswer) instead of actual price. Attacker buys asset cheaply on DEX, deposits at oracle's minAnswer price. Check: `minAnswer < answer < maxAnswer`. Read these from the aggregator contract. [Source: Cyfrin — Chainlink Oracle Security, Venus/Blizz exploit]

- [ ] **AMPL/USD uses 18 decimals, breaking the "USD feeds = 8 decimals" assumption**: Not all USD-denominated feeds use 8 decimals. Always call `AggregatorV3Interface.decimals()` to get the actual precision. [Source: Cyfrin — Chainlink Oracle Security]

- [ ] **VRF REQUEST_CONFIRMATIONS too low for target chain reorg depth**: Default value of 3 from Chainlink tutorial is insufficient for Polygon (frequent 30+ block reorgs). Chain-specific values needed per deployment. [Source: Cyfrin — Chainlink Oracle Security]

- [ ] **Bets/inputs accepted after randomness request**: If users can place bets or modify inputs after the VRF randomness request but before fulfillment, they can front-run the oracle response to game the outcome. [Source: Cyfrin — Chainlink Oracle Security]

- [ ] **Randomness callback selects against MUTABLE shared state (word-informed steering)**: The VRF word is *unbiasable* but *public in the mempool* for `requestConfirmations` blocks before the callback mines. If `fulfillRandomWords` computes the outcome from live state that anyone can change in that gap — `word % totalWeight`, an array length/order, a live balance/supply, a cumulative-weight tree/index — then whoever reads the pending word can move the result onto a chosen target. The mutating actor need NOT be the purchaser and need NOT touch "their own" input: a *third party's* deposit/mint/list that changes the *shared selection pool* every pending request resolves against is enough. Fix: snapshot all outcome-inputs at request time, or reject any callback that could have observed a post-request mutation (e.g. stage deposits so they can't enter the pool until after the last honorable callback block: `requestConfirmations + activationDelay > maxCallbackDelay`). Note: even when the Chainlink VRF wrapper itself is trusted/out-of-scope, the contract's *use* of the word (selection against mutable state) is in scope. Look for: `fulfillRandomWords`/reveal callbacks that read storage which any external function mutates; deposit/mint/list/withdraw/reprice functions with no lock while a request is pending. [Source: FWA / TokenWorks CryptoPunk #5450 incident, 2026]

- [ ] **One-directional lock on the selection window**: A window-lock that blocks *withdrawals* (pool shrink) but not *deposits* (pool growth) — or the reverse — still lets an attacker steer a pending randomness callback from the unguarded direction. Additive steering is as strong as subtractive. Look for: a `block.number < lastRequestBlock + lock` (or `withdrawLockBlocks`) guard on the withdraw path but no equivalent on deposit/mint/list, often with a comment like "pool growth never invalidates a pending request." [Source: FWA / TokenWorks CryptoPunk #5450 incident, 2026]

- [ ] **Fee/price slippage guard mistaken for a selection guard**: A callback that re-checks `fee`/`price` drift within a tolerance does NOT protect *which* item is selected. Selection via `word % N` is discontinuous in `N`, so a mutation far too small to push a smooth fee past its slippage tolerance can still relocate the selection target arbitrarily — the guard and the exploit have different sensitivities. Also: "selection always lands on a valid active item" is an invariant that stays true *during* the exploit; it is not proof that the item cannot be chosen by an adversary. Look for: a slippage/tolerance check inside the fulfillment that guards an amount/price, while the winning item is chosen from mutable weight/index/length. [Source: FWA / TokenWorks CryptoPunk #5450 incident, 2026]

## Sigma Prime — Oracles & Pricing (Phase 3)

- [ ] **Spot price manipulation via flash loans even with slippage checks**: Harvest Finance had 3% slippage checks but attacker profited $24M through repeated small cycles, each within the slippage tolerance. Avoid raw spot prices entirely; use TWAPs or off-chain oracles. [Source: Sigma Prime — Oracles & Pricing]

- [ ] **Homegrown oracle — multiple feeds dominated by single source**: Synthetix's multiple price feeds were all heavily influenced by the UniswapV1 MKR/ETH pool. Verify feed independence; median of correlated feeds provides false security. [Source: Sigma Prime — Oracles & Pricing]

- [ ] **Oracle front-running/backrunning via timing delays**: Users can observe pending oracle updates and trade just before/after to profit from the price delta. Use pull-style oracles, faster L2s, or settlement periods. [Source: Sigma Prime — Oracles & Pricing, Synthetix]

- [ ] **Gas congestion delays oracle updates — cascading liquidations**: On Black Thursday 2020, high gas caused Maker oracle lag, then a sudden 20% price drop caused mass liquidations. Bidding software couldn't handle gas spikes, allowing $0 bids to win $8.3M of ETH. Audit off-chain software too. [Source: Sigma Prime — Oracles & Pricing, MakerDAO]

- [ ] **Hardcoded price peg assumptions**: USDC/DAI can depeg (USDC hit $0.88 during SVB collapse). Never hardcode token==$1. Even tokens pegged to ETH (stETH, rETH) should use their own price feeds, not ETH's. [Source: Sigma Prime — Oracles & Pricing]

- [ ] **Manual multi-sig oracle update acts as hardcoded during delays**: If token price bounds require multi-sig to update, delayed signatures effectively hardcode the stale price, enabling exploitation. USDR/TNGBL was exploited this way. [Source: Sigma Prime — Oracles & Pricing, Tangible USDR]

- [ ] **TWAP mean can be skewed by single extreme reading**: With readings [10, 9999, 12, 11], mean TWAP = 2508 despite 75% of prices being ~10-12. Especially dangerous for illiquid pools. Consider median or trimmed mean. [Source: Sigma Prime — Oracles & Pricing]

- [ ] **Wrong decimal conversion factor in lending pool setup**: Morpho user deployed PAXG lending pool with incorrect decimal conversion between collateral and loan tokens. $230K drained. Test deployments with small amounts first. [Source: Sigma Prime — Oracles & Pricing]
