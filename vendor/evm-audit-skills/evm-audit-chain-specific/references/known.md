# evm-audit-chain-specific — KNOWN (Opus Already Knows)

*Generated: 2026-02-28 | Items: 19*

ℹ️  Opus explains these deeply from training. Lowest priority for skill inclusion.

- [ ] **`block.number` returns L1 block number**: On Arbitrum, `block.number` returns the approximate L1 block number, NOT the L2 block number. Use `ArbSys(0x64).arbBlockNumber()` for L2 block number. Time-based logic using `block.number` will have ~1000x lower resolution than expected. Look for: `block.number` used for timing, deadlines, or block-frequency calculations on Arbitrum. [multichain-auditor, beirao ARB-01]

- [ ] **Multiple L2 transactions per L1 block**: Unlike mainnet (1 tx can change `block.number`), many Arbitrum transactions share the same `block.number`. This breaks assumptions like "different block = different transaction". Look for: `require(block.number > lastBlock)` for uniqueness checks. [multichain-auditor]

- [ ] **Sequencer downtime = stale oracle prices + delayed liquidations**: When the sequencer is down, no new transactions execute. When it resumes, oracle prices are stale and positions may have gone deeply underwater. Check the Chainlink sequencer uptime feed and apply grace periods. Look for: Chainlink usage on Arbitrum without sequencer uptime check. [multichain-auditor, beirao ARB-02]

- [ ] **L2→L1 message delay is 7+ days**: Withdrawals and messages from Arbitrum to L1 are subject to the challenge period (~7 days). Protocols that need faster finality should use a bridge/liquidity network. Look for: UX flows that assume fast L2→L1 message delivery. [Arbitrum docs]

- [ ] **L1→L2 msg.sender is aliased**: When an L1 contract sends a message to L2, the `msg.sender` on L2 is `L1_address + 0x1111000000000000000000000000000000001111`. If access control on L2 checks the raw L1 address, it will ALWAYS fail. Must un-alias the sender. Look for: L1→L2 access control that compares `msg.sender` directly with an L1 contract address. [multichain-auditor, beirao ARB-03]

- [ ] **`block.number` is L2 block number**: Unlike Arbitrum, Optimism returns the L2 block number from `block.number`. But L2 blocks on OP stack are produced every 2 seconds, not 12. Code calibrated for mainnet block times will run 6x faster. Look for: block-number-based timing with mainnet assumptions on OP Stack chains. [multichain-auditor]

- [ ] **3-second block times**: BSC produces blocks every 3 seconds. Block-number-based timing runs 4x faster than Ethereum mainnet. Look for: block-count timing calibrated for 12-second blocks. [multichain-auditor]

- [ ] **Reorgs are more common**: Polygon has more frequent chain reorganizations than Ethereum mainnet. Protocols that rely on block finality with fewer confirmations are at risk. Look for: single-block confirmation assumptions. [multichain-auditor]

- [ ] **PUSH0 support**: Solidity ≥0.8.20 defaults to Shanghai EVM which uses `PUSH0`. Chains that haven't adopted Shanghai (older L2s, app-chains) reject this opcode. Must compile with `--evm-version paris` or earlier. Look for: Solidity ≥0.8.20 deployed to chains without PUSH0 support. [multichain-auditor]

- [ ] **EIP-1559 parameters differ**: Each chain has its own base fee calculation, fee markets, and priority fee handling. Hardcoded gas parameters from mainnet will be wrong. Look for: hardcoded gas prices, base fee assumptions, or priority fee calculations. [multichain-auditor]

- [ ] **Bridged token addresses differ**: USDC on Ethereum ≠ USDC on Arbitrum ≠ USDC on Optimism. Each is a different contract address. Native USDC vs bridged USDC.e are completely different contracts. Look for: hardcoded token addresses in multi-chain config. [multichain-auditor]

- [ ] **Pre-deployed contract addresses may differ**: OpenZeppelin's `Create2` library, Gnosis Safe singleton, Uniswap factories — their addresses may vary across chains. Look for: hardcoded infrastructure contract addresses. [multichain-auditor]

- [ ] **`block.chainid` must be checked dynamically**: After hard forks, `block.chainid` changes. If cached at deploy time and used for signatures, the cached value is wrong on one fork. Look for: `immutable CHAIN_ID` set in constructor vs runtime `block.chainid` check. [multichain-auditor]

- [ ] **Chainlink minAnswer/maxAnswer on Arbitrum feeds**: ETH/USD limited to [$10, $1M], USDC/USD limited to [$0.01, $1000], USDT/USD limited to [$0.01, $1000]. During flash crashes or extreme events, the feed returns min/max instead of real price. Look for: Chainlink integrations without checking `answer > minAnswer && answer < maxAnswer`. [Arbitrum Checklist]

- [ ] **PUSH0 opcode not supported on all chains**: Solidity >=0.8.20 generates PUSH0. Arbitrum added support in ArbOS 11, Optimism in Canyon upgrade, but many chains still don't support it. Deploying 0.8.20+ compiled code to unsupported chains causes deployment failure. Look for: Solidity version >=0.8.20 in multichain deployments. [multichain-auditor, beirao MC-03]

- [ ] **`transfer()` and `send()` fail on chains with different gas costs**: These forward 2300 gas, which may not be enough on chains with different gas pricing (zkSync Era). Use `.call{value: amount}("")` instead. Look for: `.transfer()` or `.send()` in multichain contracts. [multichain-auditor, beirao MC-04]

- [ ] **Frontrunning impossible on some L2s but trivial on others**: Optimism has a private mempool making frontrunning very difficult. Polygon has a public mempool making it cheap. Threat models must be chain-specific. Look for: frontrunning protections assumed unnecessary based on single-chain behavior. [multichain-auditor]

- [ ] **Hardcoded WETH/token addresses invalid across chains**: WETH is 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2 on Ethereum but 0x7ceb23fd6bc0add59e62ac25578270cff1b9f619 on Polygon. Look for: any hardcoded contract address that's assumed same across chains. [multichain-auditor]

- [ ] **Precompile addresses differ across chains**: Precompiled contracts exist at different addresses on Arbitrum, Optimism, and other L2s. Using a precompile address from one chain on another may call empty addresses or different contracts. Look for: hardcoded precompile addresses in multichain deployments. [multichain-auditor]

