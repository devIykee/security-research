# Governance & DAO Security Checklist

## Flash Loan Governance Attacks

- [ ] **Flash loan voting**: An attacker flash-loans governance tokens, delegates to themselves, votes, and returns tokens — all in one block. Classic exploits: Beanstalk ($182M), Build Finance DAO. Mitigation: snapshot-based voting where voting power is recorded at a past block, not current balance. Look for: `balanceOf(msg.sender)` or `getVotes(msg.sender)` checked at current block in voting. [SigmaPrime governance, beirao GOV-01]

- [ ] **Flash loan + proposal creation**: Even if voting uses snapshots, proposal CREATION may not. An attacker flash-loans tokens to meet the proposal threshold, creates a malicious proposal, returns tokens. Look for: proposal creation that checks current balance instead of a past snapshot. [SigmaPrime governance]

- [ ] **Vote buying via DeFi composability**: Governance tokens deposited in lending protocols can be borrowed by attackers for voting. The original depositor doesn't realize their voting power is being used against them. Look for: governance tokens without delegation exclusion when deposited in DeFi protocols. [SigmaPrime governance]

## Proposal Execution

- [ ] **Proposal execution front-running**: After a proposal passes and the timelock expires, the execution transaction is public. An attacker can front-run execution with a transaction that changes state to make the proposal harmful. Look for: proposals that depend on specific protocol state at execution time. [beirao GOV-02]

- [ ] **CREATE2 + proposal hash collision**: An attacker proposes executing code from a CREATE2-deployed contract. Before execution, they `selfdestruct` and redeploy different code at the same address. The proposal's target address is the same, but the code is malicious. Look for: proposals targeting CREATE2-deployed contracts or contracts with `selfdestruct`. [SigmaPrime governance]

- [ ] **Proposal with block number deadline + different L2 block times**: Block numbers vary wildly across chains. A proposal with `endBlock = currentBlock + 40_320` (7 days on mainnet) lasts only ~14 hours on Arbitrum. Look for: governance timeouts measured in blocks on L2s with different block times. [multichain-auditor]

- [ ] **Proposals without expiry become time bombs**: A queued proposal that never expires can be executed months later when conditions have completely changed. Look for: missing expiration/grace period on queued proposals. [beirao GOV-05]

- [ ] **Cross-chain proposal execution**: In multi-chain DAOs, proposal execution on chain A may need to be propagated to chains B, C. If the bridge message fails or is delayed, execution is inconsistent. Look for: multi-chain proposal execution without confirmation/retry mechanisms. [SigmaPrime governance]

## Quorum & Voting Thresholds

- [ ] **Quorum based on percentage, not absolute**: If quorum = 10% of totalSupply, and totalSupply is infinite (mintable governance token), the quorum can be trivially met by minting. Also: as tokens get locked/lost, 10% of circulating supply becomes >> 10% of active supply, making quorum unreachable. Look for: quorum calculation using `totalSupply()` as denominator. [SigmaPrime governance]

- [ ] **Dynamic quorum calculated at wrong time**: If quorum requirement is checked at proposal creation vs execution, it can be manipulated between those times. Look for: quorum threshold computed at execution time, not snapshot time. [beirao GOV-03]

- [ ] **Quorum excluding abstentions**: If "abstain" votes count toward quorum but not toward approval, an attacker can abstain with enough tokens to reach quorum, ensuring a small number of "for" votes passes the proposal. Look for: quorum counting that includes abstain votes. [SigmaPrime governance]

- [ ] **Voting power from locked/staked tokens still active**: If tokens in a staking contract or LP pool still have voting power, the staking contract/LP becomes a super-voter that nobody controls. Look for: voting power delegation that persists after deposit into DeFi protocols. [SigmaPrime governance]

## Timelock Security

- [ ] **Timelock bypass via emergency function**: If the DAO has an "emergency" function that bypasses the timelock, it's a centralization vector. An attacker who gains the emergency role can execute instantly. Look for: any function with `onlyEmergency` that modifies critical state without timelock. [beirao GOV-06]

- [ ] **Timelock with too-short delay**: Timelocks with delays < 24h don't give users time to exit before a malicious upgrade executes. Standard: 48h minimum for critical changes. Look for: timelock delay configurable below 24 hours. [SigmaPrime governance]

- [ ] **Timelock admin is itself (circular)**: If the timelock's admin is the timelock itself, and there's no DAO proposal to change it, the timelock is permanently locked. If the admin is the DAO and the DAO loses quorum capability, same result. Look for: timelock admin address and whether it's changeable. [beirao GOV-07]

## Centralization Risks

- [ ] **Multi-sig with insufficient signers**: A 1-of-3 multi-sig = single point of failure. For treasuries: minimum 3-of-7. Look for: multi-sig configurations, especially Gnosis Safe `threshold` setting. [beirao GOV-08]

- [ ] **Owner renouncement traps**: `renounceOwnership()` on a contract that still needs admin functions (pause, upgrade, parameter changes) permanently bricks the contract. Look for: contracts that inherit `Ownable` and call `renounceOwnership` while admin functions still exist. [beirao GOV-09]

- [ ] **Gnosis Safe module can bypass signatures**: A Safe module can execute transactions WITHOUT threshold signatures. If a module is compromised, the entire Safe is compromised. Look for: active modules on Gnosis Safes with `execTransactionFromModule`. [beirao GOV-10]

- [ ] **Gnosis Safe `delegatecall` from module**: `execTransactionFromModule` with operation=1 (delegatecall) runs arbitrary code in the Safe's context. A module with delegatecall capability can drain the Safe. Look for: modules that use `operation: 1` in `execTransactionFromModule`. [beirao GOV-11]

- [ ] **Single admin can rug via parameter changes**: Even without direct fund access, an admin who can set fees to 100%, change oracle addresses, whitelist malicious tokens, or set exchange rates can effectively rug. Look for: admin-settable parameters without bounds or timelock. [beirao GOV-12]

## Reward Distribution

- [ ] **Reward rate too low for totalSupply**: If `rewardAmount / duration / totalStaked` rounds to 0, all rewards are permanently lost in the contract. Look for: reward notification with amounts too small relative to staked amounts. [SigmaPrime governance, Dacian]

- [ ] **New reward notification before period ends**: Calling `notifyRewardAmount()` before the current period ends should add remaining rewards to the new period. If it doesn't, remaining rewards are lost. If it adds them incorrectly, rewards are inflated. Look for: reward notification math when `block.timestamp < periodFinish`. [beirao GOV-13]

- [ ] **Reward token same as staking token**: If staking token = reward token, and the contract uses `balanceOf(address(this))` to track either, one interferes with the other. Staking inflates apparent rewards, or claiming reduces apparent stakes. Look for: contracts where staking and reward token addresses can be the same. [SigmaPrime governance]

## Governance Edge Cases (Expanded from Beirao)

- [ ] **Gnosis Safe module bypasses Guard hooks**: If a Gnosis Safe has a Guard installed (for transaction validation), modules that call `execTransactionFromModule()` bypass the Guard's `checkTransaction()` and `checkAfterExecution()` hooks. A malicious module can execute arbitrary transactions without guard checks. Look for: Safe integrations that rely on Guards for security but also use modules. [beirao GS-01]

- [ ] **Gnosis Safe nonce not incremented by modules**: `execTransactionFromModule()` doesn't increment the Safe's nonce. If signatures or off-chain systems rely on the Safe nonce for uniqueness, module transactions are invisible to them. Look for: systems using Safe nonce for signature replay protection that also use modules. [beirao GS-02]

## Merkle Tree Governance (from Beirao)

- [ ] **Merkle proofs are front-runnable**: If a merkle proof allows claiming a reward, the proof can be extracted from a pending transaction and used by a front-runner. The claim function should verify `msg.sender` matches the address in the leaf. Look for: `claim(bytes32[] proof, uint256 amount)` without `msg.sender` validation in the leaf. [beirao MT-01, MT-03]

- [ ] **Zero hash as merkle leaf**: If the zero hash (`0x000...000`) is a valid leaf, an attacker can construct a proof for it without being in the original tree. Look for: merkle trees where empty/default values aren't explicitly excluded. [beirao MT-04]

- [ ] **Duplicate proofs in merkle tree**: If the same proof appears twice in the tree, a user can claim twice. Look for: merkle trees without deduplication of leaves and claim-tracking mappings. [beirao MT-05]

---

## Dacian — DAO Governance DeFi Attacks (Phase 3)

- [ ] **Flash-loan + delegated voting bypasses all flash-loan mitigations**: Attacker takes flash loan, deposits to receive voting power, delegates to slave contract, slave votes (reaching quorum), master undelegates and withdraws — all in one tx. The gap: undelegation works while proposal is in Locked state. [Source: Dacian — DAO Governance Attacks, Cyfrin DeXe Audit]

- [ ] **Destroy all NFT voting power at powerCalcStartTimestamp**: If `getNftPower()` returns 0 when `block.timestamp <= startTime` but `recalculateNftPower()` continues when `block.timestamp < startTime`, calling recalculate at exactly `startTime` sets all NFT powers to 0 and drains totalPower. [Source: Dacian — DAO Governance Attacks, Cyfrin DeXe Audit]

- [ ] **Amplify individual voting power via non-existent tokenId**: Calling `recalculateNftPower(nonExistentId)` with non-existent token IDs decreases `totalPower` without reducing any real NFT's power, artificially amplifying all existing holders' voting influence. [Source: Dacian — DAO Governance Attacks, Cyfrin DeXe Audit]

- [ ] **Incorrect totalPower snapshot at proposal creation**: If `ERC721Power.totalPower` isn't refreshed (all individual NFT powers recalculated) before snapshot, the proposal stores a stale totalPower that doesn't match sum of individual powers, incorrectly amplifying or reducing votes. [Source: Dacian — DAO Governance Attacks, Cyfrin DeXe Audit]

- [ ] **Static totalPowerInTokens makes quorum impossible**: If NFTs lose all voting power but `totalPowerInTokens` (the fixed ERC20 equivalent allocated to NFTs) remains in the quorum denominator, ERC20 voting power is permanently diluted, making quorum unreachable. [Source: Dacian — DAO Governance Attacks, Cyfrin DeXe Audit]

- [ ] **Delegated treasury voting power used to acquire more treasury power**: Expert users with treasury-delegated voting power should be prohibited from voting on proposals that give them more delegated power or remove existing delegations. [Source: Dacian — DAO Governance Attacks, Cyfrin DeXe Audit]

- [ ] **Bypass voting restriction via delegation to slave address**: If a user is restricted from voting on a proposal, they can delegate voting power to a second address they control and vote from there. Restrictions must also check delegated power source. [Source: Dacian — DAO Governance Attacks, Cyfrin DeXe Audit]

- [ ] **Vote with same tokens multiple times via transfer**: If voting uses `balanceOf()` without locking or snapshotting, users vote, transfer tokens to another address, vote again. Also: vetoing may lack the same protections as voting. [Source: Dacian — DAO Governance Attacks]

- [ ] **Voting tokens locked forever in proposals without deadlines**: If proposals don't have expiration deadlines and quorum is never reached, voters' tokens remain locked indefinitely. Proposals must auto-expire with a Defeated state. [Source: Dacian — DAO Governance Attacks, Code4rena Olympus]

- [ ] **Anyone can pass proposals before voting tokens are minted**: When `totalSupply == 0`, checks like `balance * 10000 < totalSupply * threshold` become `0 < 0` which is false, failing to revert. Anyone can create, endorse, and execute proposals before first mint. [Source: Dacian — DAO Governance Attacks, Code4rena Olympus]

- [ ] **Token sale proposal — from18() returns 0 for non-18-decimal purchase tokens**: If sale expects 18-decimal input but purchase token has 6 decimals, `from18()` conversion returns 0, allowing attacker to "buy" DAO tokens for free. Validate conversion result > 0. [Source: Dacian — DAO Governance Attacks, Cyfrin DeXe Audit]

## Sigma Prime — Governance & DAO Vulnerabilities (Phase 3)

- [ ] **Proposal execution order not enforced in multi-step proposals**: If anyone can trigger proposal execution and individual steps can be executed separately, attacker can include the market-opening tx but skip the safety-initialization tx, then exploit the empty market. Package multi-step proposals into one Multicall. [Source: Sigma Prime — Governance & DAOs, Sonne Finance]

- [ ] **Fake proposals via CREATE/CREATE2 contract substitution**: Attacker submits seemingly harmless proposal contract, which is approved by voters. Before execution, attacker self-destructs the contract and deploys a malicious one at the same address via CREATE2 (same salt). Fix: enforce proposals from EOAs or verify bytecode hash. [Source: Sigma Prime — Governance & DAOs, Tornado Cash]

- [ ] **Multi-sig quorum failure from unresponsive signers**: If multi-sig signers become unavailable (arrested, lost keys, hostile), the DAO becomes permanently unable to execute operations. Have backup slow-path governance via token voting. [Source: Sigma Prime — Governance & DAOs, Swerve Finance]

- [ ] **Abandoned project governance takeover**: Attacker buys cheap governance tokens of abandoned project, creates vote to redirect accrued fees and liquidity to their address. Monitor token accumulation, restrict vote power over user funds, use timelocks. [Source: Sigma Prime — Governance & DAOs, Swerve Finance]

- [ ] **Timelock prevents emergency response to buggy proposals**: Compound's `>` vs `>=` bug caused $147M in erroneous COMP distribution, but the timelock prevented any swift fix. Consider multiple governance speeds — instant pause mechanisms with shorter timelocks for emergencies. [Source: Sigma Prime — Governance & DAOs, Compound Finance]
