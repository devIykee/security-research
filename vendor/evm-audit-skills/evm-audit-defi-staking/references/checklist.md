# Staking, LSD & Yield Security Checklist

## Liquid Staking Derivative (LSD) Integration

### stETH (Lido)
- [ ] **stETH is a rebasing token**: Balance changes on every oracle report (~daily). DeFi protocols should use wstETH instead, which is a non-rebasing wrapper. If a protocol holds stETH, internal accounting will drift from actual balance. Look for: `stETH` in contract imports/addresses without wstETH wrapping logic. [beirao LSD-01]
- [ ] **stETH→wstETH conversion must handle rebasing**: When converting between stETH and wstETH, the rebase that occurs between wrapping and unwrapping must be accounted for. Look for: wrap/unwrap logic without balance-difference checks. [beirao LSD-02]
- [ ] **stETH/wstETH withdrawal has a queue**: Withdrawing from Lido involves a queue (days-weeks), receiving an NFT, and withdrawal amount limits. Protocols assuming instant withdrawal will fail. Look for: withdrawal functions that assume immediate liquidity. [beirao LSD-03]

### rETH (Rocket Pool)
- [ ] **rETH `burn()` reverts if RocketDepositPool is empty**: If the Rocket Pool deposit pool has no ETH, burning rETH to get ETH reverts. Protocols must handle this gracefully. Look for: `rETH.burn()` without try/catch or fallback. [beirao LSD-04]
- [ ] **rETH/ETH rate CAN decrease**: Unlike common belief, rETH rate can decrease due to validator slashing. Don't assume monotonically increasing rate. Look for: code that assumes rETH value only goes up. [beirao LSD-05]
- [ ] **Consensus attack on RPL nodes**: Malicious RPL node operators can submit incorrect exchange rate data. Look for: rETH rate used without sanity bounds. [beirao LSD-06]

### cbETH (Coinbase)
- [ ] **cbETH has full blacklisting**: Blacklist applies to transfers, approvals, mints, and burns. If a protocol's vault is blacklisted, all cbETH is frozen. Look for: cbETH held in shared vaults. [beirao LSD-07]
- [ ] **cbETH/ETH rate changeable by oracle**: A small set of addresses (onlyOracle modifier) can change the exchange rate. Rate manipulation by the oracle = instant profit/loss. Look for: cbETH rate used without deviation checks. [beirao LSD-08]
- [ ] **cbETH/ETH rate can decrease**: Unlike stETH, cbETH explicitly can decrease in value. Look for: assumptions of monotonically increasing cbETH rate. [beirao LSD-09]

### sfrxETH (Frax)
- [ ] **sfrxETH can temporarily detach from frxETH**: During reward transfers by Frax's multi-sig, the sfrxETH/frxETH rate temporarily deviates. An attacker can exploit this timing. Look for: sfrxETH rate used in MEV-sensitive operations without deviation checks. [beirao LSD-10]

## LSD Protocol Design

- [ ] **WithdrawCredentials front-running**: When staking ETH to a validator, a malicious validator can front-run the deposit transaction to set their own WithdrawCredentials, stealing all future withdrawals. The credentials are immutable once set. Look for: deposit flows that don't verify WithdrawCredentials match expectations. [Decurity LSD]

- [ ] **Derivative must handle slashing/burn**: If a validator is slashed, the derivative token's backing decreases. The protocol must support burning proportional derivative tokens or adjusting the rate. Look for: derivative token implementations without burn capability or rate decrease handling. [Decurity LSD]

- [ ] **DepositContract.deposit() gas limit**: If the protocol accumulates large ETH balances and calls `deposit()` in a loop, too many iterations hit block gas limit. Look for: batch deposit functions without iteration limits. [Decurity LSD]

- [ ] **Validator array iteration gas**: Operations iterating over all validators (e.g., for rewards, slashing) can hit gas limits. Look for: unbounded loops over validator data arrays. [Decurity LSD]

- [ ] **Inflation attack on empty LSD pool**: When creating a new staking pool, if no initial deposit is made, an attacker can manipulate the share price. Look for: pool creation without initial deposit or virtual shares. [Decurity LSD]

- [ ] **Slashing penalty exceeds operator balance**: If the slashing penalty is larger than the operator's staked balance, the excess comes from user funds. Look for: slashing math that doesn't cap at operator balance. [Decurity LSD]

- [ ] **Operator withdraws collateral while still validating**: If an operator can withdraw their bonded collateral before exiting as a validator, there's no slashing protection. Look for: operator withdrawal functions without exit verification. [Decurity LSD]

## Staking Rewards

- [ ] **Reward rate dilution attack**: Calling `notifyRewardAmount(0)` extends the reward period, diluting the rate by ~20% each call. Repeated calls compound the dilution. Look for: `notifyRewardAmount` callable with zero amount without rate floor. [ERC4626 primer pattern #39]

- [ ] **Expired vault tokens earning rewards**: After an epoch ends, worthless vault tokens still earn staking rewards because the staking contract doesn't know about epoch expiry. Look for: staking contracts that don't validate token expiry/value. [ERC4626 primer pattern #40]

- [ ] **Missing totalSupply sync before reward claims**: If fee shares are minted or totalSupply changes between updating reward integrals and claiming, rewards are miscalculated. Look for: reward claim functions that don't sync totalSupply first. [ERC4626 primer pattern #9]

- [ ] **Disabled emissions receivers lose allocated rewards**: If a rewards receiver is disabled but doesn't call `allocateNewEmissions`, the allocated tokens are lost forever. Allow anyone to trigger allocation for disabled receivers. Look for: emission systems where disabled receivers block token distribution. [ERC4626 primer pattern #19]

## Staking Lock Mechanisms

- [ ] **Staking for others reduces lock time**: If user A can stake on behalf of user B, and B already has a locked position, the new stake may extend or reset the lock differently than intended. Look for: `stake(address onBehalfOf)` functions that affect lock timing. [beirao LS-01]

- [ ] **Liquid wrapper bypasses lock entirely**: A smart contract can wrap locked/staked tokens and issue liquid receipt tokens, completely defeating the time-lock. Look for: token interfaces that allow third-party wrapping of locked positions. [beirao LS-02]

- [ ] **Early/delayed reward claims**: Can rewards be claimed before they vest or delayed beyond the intended payout schedule? Look for: claim functions without proper vesting schedule enforcement. [beirao LS-03]

- [ ] **Deposited assets stuck in protocol**: Can assets get stuck (partially or fully) or be improperly delayed in withdrawal? Look for: withdrawal functions with external dependencies that could permanently block. [beirao LS-04]

- [ ] **Reward token value manipulation**: If rewards are paid in a protocol-minted token, the reward value can be manipulated within the protocol scope. Look for: reward tokens minted by the same protocol without external price anchoring. [beirao LS-05]

## Vault Strategy Risks

- [ ] **Flash deposit-harvest-withdraw**: An attacker deposits right before a harvest/compound, captures the yield, then withdraws immediately. Look for: yield distribution that doesn't use time-weighted accounting. [beirao V-07]

- [ ] **Strategy loss handling**: Strategies MUST handle losses (negative yield). If they don't, withdrawal may revert or return wrong amounts. Look for: strategy withdraw functions that assume `received >= expected`. [beirao V-07]

- [ ] **Black swan: integrated protocol gets hacked**: If a yield strategy deposits into Protocol X and Protocol X is exploited, the vault must handle total loss gracefully. Look for: strategy emergency withdrawal and loss socialization mechanisms. [beirao V-07]

- [ ] **Locked funds in strategy**: When vault funds are deployed to a strategy, what happens if the strategy locks funds (e.g., lending market at 100% utilization)? Look for: vault withdrawal paths that fail when strategies can't return funds. [beirao V-07]

## LSD Protocol-Level Risks (Expanded from Decurity LSD)

- [ ] **WithdrawCredentials front-running on validator deposit**: When a protocol calls `DepositContract.deposit()`, a malicious validator operator can front-run with their own deposit using the same pubkey but different `WithdrawCredentials`, redirecting staked ETH to their address. Look for: validator registration flows that don't verify withdrawal credentials post-deposit. [Decurity LSD]

- [ ] **Slashing-induced depeg**: If validators are slashed, the derivative token should be worth less than 1:1 with ETH. If the protocol doesn't support burning derivatives to reflect the loss, a depeg occurs. Look for: LSD protocols without burning mechanisms or slashing loss distribution. [Decurity LSD]

- [ ] **DepositContract.deposit() out-of-gas with accumulated ETH**: If the protocol accumulates ETH and calls `DepositContract.deposit()` in a loop for multiple validators, the loop can run out of gas. Look for: batch deposit functions without gas limits per iteration or maximum batch size. [Decurity LSD]

- [ ] **Validator array iteration gas exhaustion**: Functions that iterate over all validators (e.g., to calculate total staked, distribute rewards) can exceed block gas limit as validator count grows. Look for: `for (i = 0; i < validators.length; i++)` patterns in LSD protocols. [Decurity LSD]

- [ ] **Operator slashing exceeds operator balance**: If slashing penalty > operator's staked balance, the protocol absorbs the loss. Look for: slashing handlers that don't account for the scenario where penalty > operator collateral. [Decurity LSD]

- [ ] **Operator withdraws collateral while still validating**: If an operator can withdraw their staked collateral while their validators are still active, there's no penalty for misbehavior. Look for: operator withdrawal functions without checking validator exit status. [Decurity LSD]

- [ ] **Derivative price oracle manipulation via sandwich**: When the derivative token price is updated by oracles (e.g., rETH/ETH rate), an attacker can sandwich the price update transaction. Look for: price update transactions that can be sandwiched for profit. [Decurity LSD]

## Specific LSD Tokens (Expanded from Beirao)

- [ ] **rETH burn() can revert if RocketDepositPool is empty**: The `rETH.burn()` function requires enough ETH in the RocketDepositPool. If the pool is depleted, burns (and thus unstaking) fail. Look for: protocols that rely on rETH → ETH conversion without handling the revert. [beirao LSD-04]

- [ ] **rETH/ETH rate can decrease during slashing**: Unlike stETH which rebases, rETH's exchange rate decreases when validators are slashed. Protocols assuming monotonically increasing rETH value will have accounting errors. Look for: share price calculations assuming rETH only appreciates. [beirao LSD-05]

- [ ] **RPL node consensus attacks**: Rocket Pool nodes submit exchange rate data. A coordinated attack by nodes could submit incorrect rETH/ETH rate data. Look for: protocols using rETH price without additional validation source. [beirao LSD-06]

- [ ] **cbETH has blacklisting on transfers, approvals, mints, and burns**: cbETH (Coinbase) can blacklist addresses at the token level. A protocol address getting blacklisted traps all cbETH holdings. Look for: protocols holding cbETH without considering blacklist risk. [beirao LSD-07]

- [ ] **cbETH/ETH rate controlled by `onlyOracle` modifier**: A few authorized addresses can change the cbETH/ETH exchange rate. Rate can also decrease. Look for: protocols assuming cbETH rate is immutable or only increases. [beirao LSD-08, LSD-09]

- [ ] **sfrxETH may detach from frxETH during Frax team operations**: The sfrxETH/frxETH rate can temporarily diverge when the Frax team's multisig transfers rewards. Look for: protocols that price sfrxETH based on expected 1:1+ ratio with frxETH without tolerance. [beirao LSD-10]

## Staking Lock-time Issues (from Beirao)

- [ ] **Users can reduce others' lock-time by staking for them**: If a protocol allows staking on behalf of another address and the lock timer resets on each stake, an attacker can stake a tiny amount for a victim to reset their lock timer. Look for: `stakeFor(address beneficiary)` functions that reset lock timers. [beirao LS-01]

- [ ] **Wrapper contracts for liquid staked positions**: A contract can wrap locked staking positions and issue liquid tokens against them, defeating the purpose of the lock. Look for: staking contracts without anti-wrapping mechanisms (e.g., transfer restrictions on staked positions). [beirao LS-02]

---

## Sigma Prime — Liquid Restaking Protocol Vulnerabilities (Phase 3)

- [ ] **Incorrect accounting for stakedButUnverifiedNativeETH**: When 32 ETH is staked, `stakedButUnverifiedNativeETH += 32 ether`. During verification, the protocol subtracts `effectiveBalance` (which can be < 32 ETH) instead of 32 ETH, leaving phantom ETH in the accounting that overstates TVL and inflates token price. [Source: Sigma Prime — Liquid Restaking, Kelp LRT KLP2-01]

- [ ] **Infinite loop from strategy not in _strategyParams**: If `_getSelfDelegations()` iterates strategies and uses `continue` when a strategy isn't found in `_strategyParams`, but doesn't increment the outer loop counter `i`, the same incompatible strategy is checked forever → DoS. [Source: Sigma Prime — Liquid Restaking, Omni OMNI-01]

- [ ] **Beacon Chain proof verification breaks after Deneb upgrade**: BeaconChainProofs assumes constant tree height of 4 for ExecutionPayload. Deneb added 2 fields (EIP-4844 blobs), increasing tree height to 5. Post-Deneb: valid withdrawal proofs fail, and second pre-image attacks can fabricate false proofs. [Source: Sigma Prime — Liquid Restaking, EigenLayer EGN3-01]

- [ ] **Malicious validator front-running — withdrawal credential hijack**: Node operator generates two deposit data instances with same pubkey but different withdrawal credentials. Deposits 1 ETH with attacker-controlled credentials first (setting them permanently), then the pool's 32 ETH deposit becomes a balance increase for the attacker's credentials. Attacker receives 33 ETH on exit. [Source: Sigma Prime — Liquid Restaking, RocketPool/Lido Immunefi]

- [ ] **Deterministic address calculation broken by metadata changes**: `create2()` addresses depend on bytecode including the metadata hash. Compiler version updates, settings changes, or source file modifications change metadata → different address → users can't withdraw funds from expected contract address. [Source: Sigma Prime — Liquid Restaking]

- [ ] **Cooldown period exploitation to evade slashing**: If deposit/stake amounts are only validated at deposit time and can be reduced later without invalidating the node, operators can drain their deposit to zero, making slashing ineffective. [Source: Sigma Prime — Liquid Restaking, Mantle Network]

- [ ] **Double rounding loss in mint amount calculation**: Computing `inflationPercentage` and `newEzETHSupply` as two separate multiply-divide operations causes two rounding losses. Restructure as single calculation to minimize precision loss. [Source: Sigma Prime — Liquid Restaking]

- [ ] **TVL manipulation via forced delegation share tracking flaw**: If share tracking after forced undelegations has accounting errors, attacker can manipulate TVL → manipulate token exchange rate → drain value via flash loan deposit/withdrawal. [Source: Sigma Prime — Liquid Restaking]
