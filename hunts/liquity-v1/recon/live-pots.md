# Liquity V1 live snapshot (eth_call only)

RPC: https://ethereum.publicnode.com  
Block ~25761271 (2026-08-15)  
ETH/USD (PriceFeed.fetchPrice): ~1881.51  
PriceFeed.status: 0 (chainlinkWorking)  
lastGoodPrice: ~1877.12

## Pots

| Location | ETH (wei / ~ETH) | LUSD | Notes |
|----------|------------------|------|-------|
| ActivePool | 74317.55 ETH (tracker == balance) | debt book 27,739,427 | all live trove coll |
| DefaultPool | 0 (tracker == 0) | debt book 0 | no pending redistributions |
| StabilityPool | 626.45 ETH (tracker == balance) | 7,584,810 deposits | P=0.1179, scale=0 |
| CollSurplusPool | 1616.44 ETH (tracker == balance) | — | unclaimed redemption/recovery surplus |
| LQTYStaking | 79.66 ETH | 298,982 | 57.15M LQTY staked |
| GasPool | 0 ETH | 15,800 | 79 * 200 LUSD reserve |

DefiLlama protocol TVL ~$211.5M Ethereum (includes staking variant). Active coll at ~$1881 ≈ $140M.

## System

- Trove count: 79
- Entire system coll: 74317.55 ETH
- Entire system debt == LUSD totalSupply: 27,739,427
- TCR ≈ 504% (not recovery mode)
- L_ETH = 0, L_LUSDDebt = 0
- totalStakes == ActivePool ETH (no stake skew vs current coll)
- All core owners: 0x0 (renounced)
- Live SP does **not** implement `getMaxAmountToOffset` / `MIN_LUSD_IN_SP` (repo main has drifted)

## Codesizes

BorrowerOperations 14129 · TroveManager 23163 · StabilityPool 14628 · ActivePool 3005 · PriceFeed 4582 · LUSD 5297
