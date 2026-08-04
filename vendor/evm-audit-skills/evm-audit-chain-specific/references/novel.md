# evm-audit-chain-specific — NOVEL (Opus 4.6 Does NOT Know)

*Generated: 2026-02-28 | Items: 5*

✅ Verified: Claude Opus 4.6 cannot explain these from training. Highest-signal content.

- [ ] **Chainlink price feed staleness thresholds differ on Arbitrum**: LINK/ETH feed has 24h heartbeat with 18 decimals, while LINK/USD has 1h heartbeat with 8 decimals. Wrong threshold = stale prices accepted. Look for: hardcoded staleness thresholds or decimal values that don't match the specific Arbitrum feed. [Arbitrum Checklist]

- [ ] **Orbit chains with custom fee tokens**: Orbit chains (L3s built on Arbitrum) can use any ERC20 as the fee token instead of ETH. If the fee token has non-18 decimals (e.g., USDC = 6), amounts are scaled between L1 decimals and L2 native currency (18 decimals). Rounding losses occur during conversion. Look for: Orbit chain integrations assuming ETH-denominated fees. [Arbitrum Checklist]

- [ ] **Retryable ticket parameters use mixed denominations on Orbit**: `tokenTotalFeeAmount` uses the fee token's decimals (e.g., 6 for USDC), but `l2CallValue`, `maxSubmissionCost`, and `maxFeePerGas` use 18-decimal native currency denomination. Mixing these causes incorrect fee calculations. Look for: retryable ticket creation on Orbit chains where parameters aren't properly denominated. [Arbitrum Checklist]

- [ ] **`tx.origin == msg.sender` is not always true for EOAs on L2**: On Optimism, L1→L2 messages can have `tx.origin == msg.sender` even when the sender is a smart contract on L1. EOA-only checks using `tx.origin == msg.sender` are bypassable. Look for: `require(tx.origin == msg.sender)` as an EOA check on L2s. [multichain-auditor]

- [ ] **XDai/Gnosis chain token contracts have callbacks**: On Gnosis chain, USDC/WBTC/WETH had post-transfer callbacks unlike their Ethereum counterparts. This enabled reentrancy attacks and led to a chain hard fork. Look for: same-name tokens assumed to behave identically across chains. [multichain-auditor]

