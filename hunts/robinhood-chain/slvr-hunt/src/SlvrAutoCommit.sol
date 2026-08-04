// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {ISlvrGridLottery} from "./interfaces/ISlvrGridLottery.sol";

/// @title SlvrAutoCommit
/// @notice Allows users to pre-fund N future rounds with deterministic square allocations.
contract SlvrAutoCommit is ReentrancyGuard {
    uint16 public constant BPS = 10_000;
    uint256 public constant AUTOMATION_FEE = 0.00001e18; // 0.00001 ETH (~a cent) per round per user
    uint32 public constant UNLIMITED_PLAYS = type(uint32).max; // Sentinel value for unlimited plays
    uint256 public constant ACCOUNT_DEPOSIT = 0.0001e18; // one-time account-opening fee (matches SlvrGridLottery.ACCOUNT_DEPOSIT)

    ISlvrGridLottery public immutable LOTTERY;

    struct Plan {
        bool enabled;
        uint256 nextRoundId;
        uint32 playsRemaining; // UNLIMITED_PLAYS means unlimited, 0 means no plays remaining
        uint256 amountPerPlay;
        uint8[] squares;
        uint16[] bpsAlloc;
        uint256 balance;
        bool autoClaim; // If true, automatically claim and reinvest winnings
        uint256 planStartRoundId; // Round ID when this plan instance started
    }

    mapping(address => Plan) public plans;
    // Track rounds bet on per user for auto-claiming
    mapping(address => uint256[]) public userRounds;
    // Track which rounds have been executed for each user (prevents duplicate executions)
    mapping(address => mapping(uint256 => bool)) public executedRounds;
    // Track which user is currently claiming (for receive() attribution)
    address private claimingUser;

    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount, address to);
    event PlanConfigured(
        address indexed user, uint256 nextRoundId, uint32 plays, uint256 amountPerPlay, bool autoClaim
    );
    event PlanDisabled(address indexed user);
    event PlanCancelled(address indexed user, uint256 refundAmount);
    event Executed(
        address indexed user,
        uint256 indexed roundId,
        uint256 betAmount,
        uint256 executionFee,
        address indexed executor
    );
    event Claimed(address indexed user, uint256 indexed roundId, uint256 nativeAmount, uint256 addedToBalance);
    event RoundExecuted(address indexed user, uint256 indexed roundId, uint32 playsRemaining);
    event BalanceUpdated(address indexed user, uint256 newBalance, uint256 amountAdded);

    error BadConfig();
    error NotEnoughBalance();
    error NothingToExecute();

    constructor(address lottery_) {
        LOTTERY = ISlvrGridLottery(lottery_);
    }

    receive() external payable {
        if (claimingUser != address(0)) {
            require(msg.sender == address(LOTTERY), "Unexpected ETH during auto-claim");
            Plan storage p = plans[claimingUser];
            p.balance += msg.value;
            emit BalanceUpdated(claimingUser, p.balance, msg.value);
        } else {
            revert("Use deposit() to add funds");
        }
    }

    function deposit() public payable nonReentrant {
        require(msg.value > 0, "value=0");
        plans[msg.sender].balance += msg.value;
        emit Deposited(msg.sender, msg.value);
    }

    function withdraw(uint256 amount, address payable to) external nonReentrant {
        Plan storage p = plans[msg.sender];
        require(to != address(0), "bad to");
        require(amount > 0 && amount <= p.balance, "bad amount");
        p.balance -= amount;
        (bool ok,) = to.call{value: amount}("");
        require(ok, "transfer failed");
        emit Withdrawn(msg.sender, amount, to);
    }

    function configurePlan(
        uint32 plays,
        uint256 amountPerPlay,
        uint8[] calldata squares,
        uint16[] calldata bpsAlloc,
        bool autoClaim_
    ) external nonReentrant {
        // plays = UNLIMITED_PLAYS means unlimited (run until balance runs out)
        // plays = 0 means no plays (plan will be disabled immediately)
        // plays > 0 means that many plays remaining
        require(amountPerPlay > 0, "amt=0");
        require(squares.length > 0 && squares.length == bpsAlloc.length, "bad arrays");

        uint256 mask;
        uint256 sumBps;
        for (uint256 i = 0; i < squares.length; i++) {
            uint8 s = squares[i];
            require(s < 25, "square oob");
            uint256 bit = uint256(1) << uint256(s);
            require((mask & bit) == 0, "dup square");
            mask |= bit;

            uint16 b = bpsAlloc[i];
            require(b > 0, "bps=0");
            sumBps += b;
        }
        require(sumBps == BPS, "bps sum != 10000");

        Plan storage p = plans[msg.sender];

        delete p.squares;
        delete p.bpsAlloc;
        for (uint256 i = 0; i < squares.length; i++) {
            p.squares.push(squares[i]);
            p.bpsAlloc.push(bpsAlloc[i]);
        }

        p.enabled = true;
        // If autoClaim is enabled, automatically use UNLIMITED_PLAYS to prevent the confusing
        // "enabled but inert" state where playsRemaining=0 but enabled=true
        // Auto-claim plans are intended to reinvest winnings indefinitely
        if (autoClaim_) {
            p.playsRemaining = UNLIMITED_PLAYS;
        } else {
            p.playsRemaining = plays;
        }
        p.amountPerPlay = amountPerPlay;
        p.autoClaim = autoClaim_;
        p.nextRoundId = LOTTERY.currentRoundId();
        p.planStartRoundId = p.nextRoundId;

        emit PlanConfigured(msg.sender, p.nextRoundId, p.playsRemaining, amountPerPlay, autoClaim_);
    }

    /// @notice Configure a plan and deposit funds in a single transaction
    /// @dev This is a convenience function that combines configurePlan and deposit
    /// @param plays Number of plays remaining (or UNLIMITED_PLAYS for unlimited)
    /// @param amountPerPlay Amount to bet per play
    /// @param squares Array of square IDs (0-24)
    /// @param bpsAlloc Array of basis point allocations (must sum to 10000)
    /// @param autoClaim_ Whether to automatically claim and reinvest winnings
    function configurePlanAndDeposit(
        uint32 plays,
        uint256 amountPerPlay,
        uint8[] calldata squares,
        uint16[] calldata bpsAlloc,
        bool autoClaim_
    ) external payable nonReentrant {
        require(msg.value > 0, "value=0");
        
        // Configure the plan (reuse the same logic)
        require(amountPerPlay > 0, "amt=0");
        require(squares.length > 0 && squares.length == bpsAlloc.length, "bad arrays");

        uint256 mask;
        uint256 sumBps;
        for (uint256 i = 0; i < squares.length; i++) {
            uint8 s = squares[i];
            require(s < 25, "square oob");
            uint256 bit = uint256(1) << uint256(s);
            require((mask & bit) == 0, "dup square");
            mask |= bit;

            uint16 b = bpsAlloc[i];
            require(b > 0, "bps=0");
            sumBps += b;
        }
        require(sumBps == BPS, "bps sum != 10000");

        Plan storage p = plans[msg.sender];

        delete p.squares;
        delete p.bpsAlloc;
        for (uint256 i = 0; i < squares.length; i++) {
            p.squares.push(squares[i]);
            p.bpsAlloc.push(bpsAlloc[i]);
        }

        p.enabled = true;
        if (autoClaim_) {
            p.playsRemaining = UNLIMITED_PLAYS;
        } else {
            p.playsRemaining = plays;
        }
        p.amountPerPlay = amountPerPlay;
        p.autoClaim = autoClaim_;
        p.nextRoundId = LOTTERY.currentRoundId();
        p.planStartRoundId = p.nextRoundId;

        // Deposit the funds
        p.balance += msg.value;

        emit PlanConfigured(msg.sender, p.nextRoundId, p.playsRemaining, amountPerPlay, autoClaim_);
        emit Deposited(msg.sender, msg.value);
    }

    function disablePlan() external nonReentrant {
        plans[msg.sender].enabled = false;
        emit PlanDisabled(msg.sender);
    }

    /// @notice Cancel the plan and refund all remaining balance to the caller
    /// @dev Disables the plan and transfers the entire remaining balance back to the user
    /// @dev Also clears userRounds to reset winnings tracking for this plan
    function cancelPlan() external nonReentrant {
        Plan storage p = plans[msg.sender];
        uint256 refundAmount = p.balance;

        // Disable the plan
        p.enabled = false;

        // Clear the balance before transfer to prevent reentrancy
        p.balance = 0;

        // Clear userRounds to reset winnings tracking
        delete userRounds[msg.sender];

        // Refund the remaining balance
        if (refundAmount > 0) {
            (bool ok,) = payable(msg.sender).call{value: refundAmount}("");
            require(ok, "refund failed");
        }

        emit PlanCancelled(msg.sender, refundAmount);
        emit PlanDisabled(msg.sender);
    }

    uint32 public constant MAX_PLAYS_PER_EXECUTION = 10;

    function executeFor(address user, uint32 maxPlays) external nonReentrant {
        Plan storage p = plans[user];
        
        // Call internal function - fees are charged per play inside
        (uint32 executed, uint256 totalFees) = _executeForInternal(user, maxPlays, msg.sender);

        // Pay fees to executor after successful execution (0.1 ETH per executed play)
        if (totalFees > 0) {
            (bool ok,) = msg.sender.call{value: totalFees}("");
            require(ok, "fee transfer failed");
        }
    }

    /// @notice Claim winnings for a user from a specific round
    /// @dev Calls the lottery's claimToSplit function to receive native rewards at this contract
    /// @dev and send SLVR rewards directly to the user (preventing stuck tokens)
    /// @dev The ETH from the claim will be received via receive() and attributed to the user
    /// @dev Reentrancy protection is provided by nonReentrant modifier on callers
    /// @dev Requires the user to have approved this contract as a delegate via approveDelegate()
    function _claimForUser(address user, uint256 roundId) private returns (bool) {
        // Check if round is resolved and user can claim
        (bool resolved, uint8 winningSquare,,,,,,) = _getRoundInfo(roundId);
        if (!resolved) return false;

        if (LOTTERY.getHasClaimed(roundId, user)) return false;

        uint256 userBet = LOTTERY.getUserBet(roundId, winningSquare, user);
        if (userBet == 0) return false;

        // Check if this contract is approved as a delegate for the user
        // If not, the claimTo call will fail, but we catch it below
        if (!LOTTERY.getDelegate(user, address(this))) {
            return false;
        }

        // Set claimingUser so receive() can attribute the ETH
        // Reentrancy protection is handled by nonReentrant on callers
        claimingUser = user;

        // Get balance before claim to track how much was added
        uint256 balanceBefore = address(this).balance;
        uint256 claimedAmount = 0;
        bool success = false;

        // Call the lottery's claimAdvanced function to receive native rewards at this contract
        // and send SLVR rewards directly to the user (preventing stuck tokens)
        // This requires the user to have approved this contract as a delegate
        // Use try-catch to determine if the call succeeded (didn't revert)
        // claimAdvanced can succeed even when nativeOut == 0 (tiny bets rounding to 0, or certain multiplier edge cases)
        // ethOnly: pull ONLY the ETH winnings back into the plan (recipientNative = this contract) to
        // recycle into the next bet, and leave the user's SLVR unrefined in miner state — so it keeps
        // accruing and earning dividends instead of being auto-refined every round (which charged the
        // 10% refining fee). The user cashes out their mined SLVR whenever they choose.
        ISlvrGridLottery.ClaimParams memory params;
        params.user = user;
        params.roundId = roundId;
        params.recipientNative = address(this);
        params.recipientSlvr = user;
        params.bypassFee = false;
        params.ethOnly = true;
        try LOTTERY.claimAdvanced(params) {
            // Call succeeded - check how much ETH was received
            uint256 balanceAfter = address(this).balance;
            claimedAmount = balanceAfter > balanceBefore ? balanceAfter - balanceBefore : 0;
            success = true;
        } catch {
            // Claim failed (call reverted) - success remains false
            success = false;
        }

        // Always clear claimingUser after external call
        // This is safe because callers have nonReentrant modifier
        claimingUser = address(0);

        // Emit event and return result
        // Emit Claimed even if nativeAmount is 0, as long as the call succeeded
        // This handles cases where claimToSplit succeeds but nativeOut == 0
        if (success) {
            emit Claimed(user, roundId, claimedAmount, claimedAmount);
            return true;
        }

        return false;
    }

    /// @notice Helper to get round info
    function _getRoundInfo(uint256 roundId)
        private
        view
        returns (
            bool resolved,
            uint8 winningSquare,
            uint256 payoutMulWad,
            uint256 slvrMulWad,
            bool singleMinerRound,
            address singleMinerWinner,
            uint256 slvrForWinners,
            uint256 totalUnclaimedSlvr
        )
    {
        (
            , // requestedAt
            resolved,
            , // randomnessId
            , // randomnessValue
            winningSquare,
            , // jackpotHit
            singleMinerRound,
            singleMinerWinner,
            , // totalWager
            , // fee
            , // winnerTotal
            , // potForWinners
            slvrForWinners,
            payoutMulWad,
            slvrMulWad,
            totalUnclaimedSlvr
        ) = LOTTERY.getRound(roundId);
    }

    /// @notice Auto-claim winnings from previous rounds for a user
    /// @dev Checks the last 50 rounds the user has bet on and claims any that are claimable
    /// @dev For users with more than 50 rounds, use claimRangeForUser() to claim older rounds
    function _autoClaimForUser(address user) private returns (uint256 totalClaimed) {
        if (!plans[user].autoClaim) return 0;

        uint256[] storage rounds = userRounds[user];
        uint256 len = rounds.length;

        // Limit to last 50 rounds to avoid gas issues during normal execution
        // Users with more than 50 rounds can use claimRangeForUser() to claim older rounds
        uint256 start = len > 50 ? len - 50 : 0;

        for (uint256 i = start; i < len; i++) {
            uint256 roundId = rounds[i];

            // Skip if already claimed
            if (LOTTERY.getHasClaimed(roundId, user)) continue;

            // Check if round is resolved
            (bool resolved, uint8 winningSquare,,,,,,) = _getRoundInfo(roundId);
            if (!resolved) continue;

            // Check if user has a bet on winning square
            uint256 userBet = LOTTERY.getUserBet(roundId, winningSquare, user);
            if (userBet == 0) continue;

            // Try to claim
            if (_claimForUser(user, roundId)) {
                totalClaimed++;
            }
        }

        return totalClaimed;
    }

    /// @notice Internal execution logic (without fee handling)
    /// @dev This function doesn't handle fees - callers must handle fee collection separately
    /// @dev Can be called internally from executeFor() or via executeForInternalWrapper() for batch operations
    function _executeForInternal(address user, uint32 maxPlays, address executor) internal returns (uint32 executed, uint256 totalFees) {
        require(maxPlays > 0, "max=0");
        require(maxPlays <= MAX_PLAYS_PER_EXECUTION, "max too high");

        Plan storage p = plans[user];
        require(p.enabled, "disabled");

        uint8[] storage squares = p.squares;
        uint16[] storage bpsAlloc = p.bpsAlloc;
        if (squares.length == 0 || squares.length != bpsAlloc.length) revert BadConfig();

        // Auto-claim winnings from previous rounds if enabled
        uint256 autoClaimed = 0;
        if (p.autoClaim) {
            autoClaimed = _autoClaimForUser(user);
        }

        // Continue until maxPlays reached, or playsRemaining hits 0 (if not unlimited), or balance runs out
        // playsRemaining == UNLIMITED_PLAYS means unlimited (run until balance runs out)
        while (executed < maxPlays) {
            // If playsRemaining is not unlimited, check if we've reached the limit
            if (p.playsRemaining != UNLIMITED_PLAYS && p.playsRemaining == 0) {
                // No plays remaining
                break;
            }

            uint256 r = LOTTERY.currentRoundId();
            // Only bet when current round matches nextRoundId (the round we're waiting for)
            // This ensures we bet once per round as it starts, not immediately when capital is deployed
            // Cannot bet in advance - must wait for the round to become current
            if (r < p.nextRoundId) {
                // Current round hasn't reached nextRoundId yet, wait for next round to start
                break;
            }

            // If we've missed rounds (current round is ahead of nextRoundId), skip to current round
            // This allows the plan to continue even if rounds were missed
            if (r > p.nextRoundId) {
                // Round has advanced beyond nextRoundId, update to current round
                // This handles the case where rounds were missed - we skip them and continue
                p.nextRoundId = r;
            }

            // Ensure we're betting on the current round (cannot bet in advance)
            require(p.nextRoundId == r, "can only bet on current round");
            
            // If the current round is not open, skip it and move to next round
            // This prevents the plan from getting stuck if a round closes before execution
            // If we've caught up to current round but it's closed, skip to next and wait
            if (!LOTTERY.roundOpen(p.nextRoundId)) {
                // Round is closed, skip to next round
                p.nextRoundId = r + 1;
                // Break to wait for next round to become current
                break;
            }

            // Check if this round has already been executed for this user
            // This prevents duplicate executions even if autominer runs multiple times
            uint256 usedRound = p.nextRoundId;
            if (executedRounds[user][usedRound]) {
                // Round already executed, skip to next round
                p.nextRoundId = usedRound + 1;
                continue;
            }

            // Check if user needs to pay account deposit (new account in lottery)
            bool needsAccountDeposit = !LOTTERY.getHasAccount(user);
            uint256 accountDeposit = needsAccountDeposit ? ACCOUNT_DEPOSIT : 0;
            
            // Calculate total needed: bet amount + account deposit (if new) + execution fee (0.1 ETH per round)
            uint256 betValue = p.amountPerPlay + accountDeposit;
            uint256 need = betValue + AUTOMATION_FEE;
            
            if (p.balance < need) {
                if (executed == 0) revert NotEnoughBalance();
                break;
            }

            // Ensure contract has enough ETH to pay bet and account deposit (if needed)
            require(address(this).balance >= need, "insufficient contract balance");

            uint256[] memory amounts = _buildAllocations(p.amountPerPlay, bpsAlloc);

            // Deduct from user's balance (bet + account deposit + execution fee)
            p.balance -= need;
            totalFees += AUTOMATION_FEE;
            // Decrement playsRemaining only if not unlimited
            if (p.playsRemaining != UNLIMITED_PLAYS) {
                p.playsRemaining -= 1;
            }
            // Mark this round as executed BEFORE incrementing nextRoundId
            // This prevents race conditions where autominer runs multiple times
            executedRounds[user][usedRound] = true;
            p.nextRoundId = usedRound + 1;
            executed += 1;

            // Track this round for auto-claiming
            userRounds[user].push(usedRound);
            
            // Emit event for round execution
            emit RoundExecuted(user, usedRound, p.playsRemaining);

            // Send bet to lottery (includes account deposit if user is new)
            // The lottery contract will handle the account deposit internally
            LOTTERY.betFor{value: betValue}(usedRound, user, squares, amounts);

            emit Executed(user, usedRound, p.amountPerPlay, AUTOMATION_FEE, executor);

            if (p.playsRemaining == 0) {
                p.enabled = false;
                delete userRounds[user];
                emit PlanDisabled(user);
            }
        }

        // Allow execution to succeed if auto-claim claimed at least one round, even if no bets were executed
        // This handles cases where auto-claim succeeds (e.g., with 0 nativeOut) but no new bets can be placed
        if (executed == 0 && autoClaimed == 0) revert NothingToExecute();
        
        return (executed, totalFees);
    }

    function _buildAllocations(uint256 amountPerPlay, uint16[] storage bpsAlloc)
        private
        view
        returns (uint256[] memory amounts)
    {
        uint256 n = bpsAlloc.length;
        amounts = new uint256[](n);
        uint256 allocated;
        for (uint256 i = 0; i < n; i++) {
            uint256 a = (amountPerPlay * bpsAlloc[i]) / BPS;
            amounts[i] = a;
            allocated += a;
        }
        if (n > 0 && allocated != amountPerPlay) {
            amounts[0] += (amountPerPlay - allocated);
        }
    }

    function planInfo(address user)
        external
        view
        returns (
            bool enabled,
            uint256 nextRoundId,
            uint32 playsRemaining,
            uint256 amountPerPlay,
            uint256 balance,
            bool autoClaim,
            uint8[] memory squares,
            uint16[] memory bpsAlloc,
            uint256 planStartRoundId
        )
    {
        Plan storage p = plans[user];
        return (
            p.enabled,
            p.nextRoundId,
            p.playsRemaining,
            p.amountPerPlay,
            p.balance,
            p.autoClaim,
            p.squares,
            p.bpsAlloc,
            p.planStartRoundId
        );
    }

    /// @notice Get the rounds a user has bet on (for tracking claims)
    function getUserRounds(address user) external view returns (uint256[] memory) {
        return userRounds[user];
    }

    /// @notice Manually claim winnings for a user from a specific round
    /// @dev Can be called by anyone to claim winnings for a user (useful for keepers)
    function claimForUser(address user, uint256 roundId) external nonReentrant returns (bool) {
        require(plans[user].autoClaim, "auto-claim not enabled");
        return _claimForUser(user, roundId);
    }

    /// @notice Manually claim winnings for a user from multiple rounds
    /// @dev Can be called by anyone to claim winnings for a user (useful for keepers)
    function claimMultipleForUser(address user, uint256[] calldata roundIds)
        external
        nonReentrant
        returns (uint256 claimed)
    {
        require(plans[user].autoClaim, "auto-claim not enabled");
        for (uint256 i = 0; i < roundIds.length; i++) {
            if (_claimForUser(user, roundIds[i])) {
                claimed++;
            }
        }
        return claimed;
    }

    /// @notice Claim winnings for a user from a range of rounds (paginated)
    /// @dev Allows claiming older rounds that are beyond the 50-round auto-claim limit
    /// @dev Can be called by anyone to claim winnings for a user (useful for keepers)
    /// @param user The user address to claim for
    /// @param startIndex Starting index in userRounds array (inclusive)
    /// @param endIndex Ending index in userRounds array (exclusive, use array length for all remaining)
    /// @param maxRounds Maximum number of rounds to process (gas limit protection)
    /// @return claimed Number of rounds successfully claimed
    function claimRangeForUser(
        address user,
        uint256 startIndex,
        uint256 endIndex,
        uint256 maxRounds
    ) external nonReentrant returns (uint256 claimed) {
        require(plans[user].autoClaim, "auto-claim not enabled");
        
        uint256[] storage rounds = userRounds[user];
        uint256 len = rounds.length;
        
        require(startIndex < len, "startIndex out of bounds");
        require(endIndex <= len, "endIndex out of bounds");
        require(startIndex < endIndex, "invalid range");
        require(endIndex - startIndex <= maxRounds, "range too large");
        
        for (uint256 i = startIndex; i < endIndex; i++) {
            uint256 roundId = rounds[i];
            
            // Skip if already claimed
            if (LOTTERY.getHasClaimed(roundId, user)) continue;
            
            // Check if round is resolved
            (bool resolved, uint8 winningSquare,,,,,,) = _getRoundInfo(roundId);
            if (!resolved) continue;
            
            // Check if user has a bet on winning square
            uint256 userBet = LOTTERY.getUserBet(roundId, winningSquare, user);
            if (userBet == 0) continue;
            
            // Try to claim
            if (_claimForUser(user, roundId)) {
                claimed++;
            }
        }
        
        return claimed;
    }

    /// @notice Trigger auto-claim for a user without executing a bet
    /// @dev Can be called by anyone to claim winnings for a user (useful for keepers)
    /// @dev This allows claiming winnings even when balance is insufficient to place a bet
    /// @param user The user address to claim for
    /// @return claimed Number of rounds successfully claimed
    function claimWinnings(address user) external nonReentrant returns (uint256 claimed) {
        require(plans[user].autoClaim, "auto-claim not enabled");
        return _autoClaimForUser(user);
    }

    /// @notice Check if a plan needs execution (ready to bet on next round)
    /// @param user The user address to check
    /// @return ready True if the plan is enabled and ready to execute
    /// @return reason Reason why it doesn't need execution (empty if ready is true)
    function needsExecution(address user) external view returns (bool ready, string memory reason) {
        Plan storage p = plans[user];

        // If playsRemaining is UNLIMITED_PLAYS, it means unlimited (only stops when balance runs out)
        // If playsRemaining is 0, it means no plays remaining (plan should be disabled)
        // Check this first, as it's the primary reason for not executing
        if (p.playsRemaining == 0) {
            return (false, "no plays remaining");
        }

        if (!p.enabled) {
            return (false, "plan disabled");
        }

        uint256 currentRound = LOTTERY.currentRoundId();
        if (currentRound < p.nextRoundId) {
            return (false, "waiting for round to start");
        }

        // If current round is ahead of nextRoundId, update nextRoundId to current round
        uint256 targetRound = currentRound > p.nextRoundId ? currentRound : p.nextRoundId;
        
        // Check if this round has already been executed
        if (executedRounds[user][targetRound]) {
            return (false, "round already executed");
        }

        if (!LOTTERY.roundOpen(targetRound)) {
            return (false, "round not open");
        }

        // Check if user needs to pay account deposit (new account in lottery)
        bool needsAccountDeposit = !LOTTERY.getHasAccount(user);
        uint256 accountDeposit = needsAccountDeposit ? ACCOUNT_DEPOSIT : 0;
        
        // Calculate total needed: bet amount + account deposit (if new) + automation fee
        uint256 betValue = p.amountPerPlay + accountDeposit;
        uint256 need = betValue + AUTOMATION_FEE;
        
        if (p.balance < need) {
            // If auto-claim is enabled and user has rounds that might be claimable,
            // allow execution because auto-claim runs first and might add funds
            if (p.autoClaim && userRounds[user].length > 0) {
                return (true, "");
            }
            return (false, "insufficient balance");
        }

        return (true, "");
    }

    /// @notice Wrapper function for batch execution with try/catch
    /// @dev External function that wraps internal _executeForInternal for try/catch support
    /// @dev Only used by executeBatch() to handle errors gracefully
    function executeForInternalWrapper(address user, uint32 maxPlays, address executor) external returns (uint32 executed, uint256 totalFees) {
        // Only allow this contract to call this wrapper (for batch operations)
        require(msg.sender == address(this), "unauthorized");
        return _executeForInternal(user, maxPlays, executor);
    }

    /// @notice Execute plans for multiple users in one transaction
    /// @param users Array of user addresses to execute for
    /// @param maxPlays Maximum plays to execute per user
    /// @dev Continues execution even if some users fail (gas efficient for keepers)
    /// @dev Uses atomic fee handling: fees are only deducted after successful execution
    /// @dev This ensures all-or-nothing semantics: either execution succeeds and fee is deducted,
    ///      or execution fails and no state changes occur (no fee deduction, no refund needed)
    function executeBatch(address[] calldata users, uint32 maxPlays) external nonReentrant {
        require(users.length > 0, "empty users");
        require(maxPlays > 0 && maxPlays <= MAX_PLAYS_PER_EXECUTION, "bad maxPlays");

        uint256 successful = 0;
        uint256 totalFee = 0;

        // Execute for each user (continue on errors to process all users)
        for (uint256 i = 0; i < users.length; i++) {
            Plan storage p = plans[users[i]];
            
            // Check if user has enough balance for at least one play (bet + execution fee)
            // The actual fee will be calculated per play inside executeForInternalWrapper
            uint256 minNeeded = plans[users[i]].amountPerPlay + AUTOMATION_FEE;
            if (p.balance >= minNeeded) {
                try this.executeForInternalWrapper(users[i], maxPlays, msg.sender) returns (uint32 execCount, uint256 fees) {
                    // Fees are already deducted inside executeForInternalWrapper
                    if (execCount > 0) {
                        successful++;
                        totalFee += fees;
                    }
                } catch {
                }
            }
        }

        // Require at least one successful execution
        require(successful > 0, "no executions succeeded");

        // Pay automation fees to executor (after execution completes)
        if (totalFee > 0) {
            (bool ok,) = msg.sender.call{value: totalFee}("");
            require(ok, "fee transfer failed");
        }
    }
}
