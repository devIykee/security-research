# evm-audit-chain-specific — PARTIAL (Opus Knows Concept, Not Specifics)

*Generated: 2026-02-28 | Items: 18*

⚠️  Opus knows the general class but not the specific protocol/version/formula detail.

- [ ] **`block.basefee` returns L1 basefee on Arbitrum**: Use `ArbGasInfo.getL1BaseFeeEstimate()` for L1 fees, and `ArbGasInfo` precompile methods for L2 gas prices. Look for: `block.basefee` used for gas calculations on Arbitrum. [multichain-auditor]

- [ ] **Retryable ticket auto-redeem failure**: If a retryable ticket's auto-redeem fails (insufficient gas), it must be manually redeemed within 7 days or funds are permanently lost. Look for: L1→L2 message passing that assumes auto-redemption always succeeds. [Arbitrum docs]

- [ ] **L1 data fees**: Transactions on OP Stack pay both L2 execution gas AND L1 data posting gas. The L1 portion can be 90%+ of total cost. Protocols must account for this in gas estimation. Look for: gas estimation using only `gasleft()` without L1 data fee component. [multichain-auditor]

- [ ] **No `prevrandao` / `difficulty`**: On OP Stack L2s, `block.prevrandao` (formerly `block.difficulty`) returns a fixed value. It's NOT random. Look for: `block.prevrandao` or `block.difficulty` used as randomness source. [multichain-auditor]

- [ ] **`msg.sender == tx.origin` is true for smart contracts**: In zkSync Era, account abstraction is native — ALL accounts (including smart contracts) have `tx.origin == msg.sender` when they initiate transactions. This breaks the common "is EOA" check. Look for: `require(msg.sender == tx.origin)` as a contract-blocking mechanism. [multichain-auditor]

- [ ] **`EXTCODESIZE` returns 0 for non-EVM contracts**: zkSync has system contracts and native AA accounts that are contracts but return 0 for `extcodesize`. Look for: `extcodesize`-based contract detection. [multichain-auditor]

- [ ] **Different CREATE/CREATE2 address derivation**: zkSync uses a different formula for CREATE/CREATE2 addresses than EVM. Counterfactual addresses computed using the EVM formula will be wrong. Look for: off-chain address pre-computation using standard EVM CREATE2 formula. [multichain-auditor]

- [ ] **Missing opcodes**: `SELFDESTRUCT` is a no-op. `CALLCODE` is not supported. `EXTCODECOPY` may behave differently. Look for: usage of these opcodes on zkSync. [multichain-auditor]

- [ ] **No `receive()` / `fallback()` for ETH transfers**: On zkSync, receiving ETH may require explicit function handling. The default receive/fallback may not work as expected for system-level transfers. Look for: contracts expecting ETH via `receive()` on zkSync. [multichain-auditor]

- [ ] **Native yield accrual on ETH balances**: On Blast, ETH held by contracts automatically earns yield. If a contract's logic depends on `address(this).balance` being stable, the balance will drift upward. Look for: precise balance checks like `require(address(this).balance == expectedAmount)`. [Blast docs]

- [ ] **USDB/WETH rebasing**: Blast-native tokens (USDB, WETH) are rebasing by default. Protocols that assume stable balances will have accounting errors. Opt for non-rebasing mode via `IERC20Rebasing(token).configure(YieldMode.CLAIMABLE)` or `YieldMode.VOID`. Look for: Blast deployments using USDB/WETH without configuring yield mode. [Blast docs]

- [ ] **Gas refund claim**: Blast refunds gas fees to contracts. If the contract doesn't implement yield/gas claiming, the refund is stuck. Look for: Blast contracts without `IBlast.claimAllGas()` functionality. [Blast docs]

- [ ] **BNB token quirks**: BNB reverts on `approve(addr, 0)` but requires approval reset for USDT pattern. There's no universal approve pattern that works for both BNB and USDT. Look for: generic approve-to-zero patterns on BSC. [weird-erc20]

- [ ] **Different precompiles**: BSC has custom precompiles for BLS signature verification and other functions at non-standard addresses. Look for: precompile address assumptions. [multichain-auditor]

- [ ] **MATIC → POL migration**: MATIC is being replaced by POL as the native gas token. Protocols hardcoding WMATIC addresses or assuming MATIC will need updates. Look for: hardcoded MATIC/WMATIC addresses. [multichain-auditor]

- [ ] **USDT on Polygon returns bool (unlike Ethereum)**: Ethereum USDT has no return value; Polygon USDT returns bool. SafeERC20 handles both, but custom transfer wrappers may not. Look for: custom token interaction code that assumes no return value. [multichain-auditor]

- [ ] **`block.number` on Arbitrum returns L1 block number, not L2**: The L1 block number updates approximately every minute (~5 block jumps). Short-term timing based on `block.number` is unreliable. For L2 block numbers, use `ArbSys(100).arbBlockNumber()`. Look for: `block.number` used for short-term timing on Arbitrum. [Arbitrum Checklist]

- [ ] **zkSync ERA has fundamentally different opcode behavior**: CREATE, CREATE2, CALL, STATICCALL, DELEGATECALL, MSTORE, MLOAD, CALLDATALOAD, CALLDATACOPY all behave differently on zkSync. Direct EVM contract deployment often fails. Look for: contracts deployed to zkSync without ERA-specific adaptation. [multichain-auditor, beirao MC-11]

