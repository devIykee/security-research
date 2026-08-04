// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {ISlvrGridLottery} from "./interfaces/ISlvrGridLottery.sol";

/// @title SlvrAutoCommitV2
/// @notice Allows users to pre-fund N future rounds with deterministic square allocations.
/// @dev V2 replaces V1's economics and claim discovery:
///      - The executor is reimbursed its actual metered gas (plus a premium) from the
///        user's plan balance, instead of V1's flat AUTOMATION_FEE that recovered ~3%
///        of real gas costs and drained the keeper wallet.
///      - Claimable rounds are discovered OFF-chain by the keeper and passed into
///        executeFor()/claimFor() explicitly. V1 re-walked the user's last 50 rounds
///        with 3 external lottery calls each on every execution (~4-14M gas per bet);
///        V2 only verifies the rounds it is told to claim (~1M gas per bet).
///      - No per-user round history is stored (V1's unbounded userRounds array) and
///        there is no executeBatch; the keeper loops per user.
contract SlvrAutoCommitV2 is ReentrancyGuard, Ownable {
    uint16 public constant BPS = 10_000;
    uint32 public constant UNLIMITED_PLAYS = type(uint32).max; // Sentinel value for unlimited plays
    uint32 public constant MAX_PLAYS_PER_EXECUTION = 10;
    uint256 public constant MAX_CLAIMS_PER_EXECUTION = 10;
    uint256 public constant ACCOUNT_DEPOSIT = 0.0001e18; // one-time account-opening fee (matches SlvrGridLottery.ACCOUNT_DEPOSIT)

    // --- Executor fee model ---
    // fee = (meteredGas + FEE_GAS_OVERHEAD) * min(tx.gasprice, block.basefee * 2)
    //       * (BPS + feePremiumBps) / BPS, capped at maxFeePerExecution and the
    //       user's remaining balance.
    // The fee therefore floats with the chain's actual gas price on its own; the
    // basefee cap stops a hostile executor from inflating its own reimbursement
    // with an absurd gas price, and the premium keeps honest keeping profitable.
    // The premium and per-call cap are owner-tunable within the hard ceilings
    // below (so a sustained basefee shift can't strand the keeper underwater the
    // way V1's compile-time AUTOMATION_FEE did), but the owner can never charge
    // more than metered gas + the bounded premium.
    uint256 public constant FEE_GAS_OVERHEAD = 60_000; // intrinsic + calldata + fee transfer, not seen by gasleft() metering
    uint16 public constant FEE_PREMIUM_CEILING_BPS = 3_000; // owner can never set the premium above 30%
    uint256 public constant MAX_FEE_CEILING = 0.01e18; // owner can never set the per-call cap above this

    uint16 public feePremiumBps = 1_000; // 10% premium over reimbursed gas
    uint256 public maxFeePerExecution = 0.001e18; // per-call cap protecting plan balances

    ISlvrGridLottery public immutable LOTTERY;

    struct Plan {
        bool enabled;
        uint256 nextRoundId;
        uint32 playsRemaining; // UNLIMITED_PLAYS means unlimited, 0 means no plays remaining
        uint256 amountPerPlay;
        uint8[] squares;
        uint16[] bpsAlloc;
        uint256 balance;
        bool autoClaim; // If true, keeper-supplied winning rounds are claimed back into balance
        uint256 planStartRoundId; // Round ID when this plan instance started
    }

    mapping(address => Plan) public plans;
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
    event RoundExecuted(address indexed user, uint256 indexed roundId, uint32 playsRemaining);
    event Claimed(address indexed user, uint256 indexed roundId, uint256 nativeAmount, uint256 addedToBalance);
    event BalanceUpdated(address indexed user, uint256 newBalance, uint256 amountAdded);
    event ExecutorFeePaid(address indexed user, address indexed executor, uint256 fee, uint256 gasUsed);
    event FeeParamsUpdated(uint16 feePremiumBps, uint256 maxFeePerExecution);

    error BadConfig();
    error NotEnoughBalance();
    error NothingToExecute();

    constructor(address lottery_, address owner_) Ownable(owner_) {
        LOTTERY = ISlvrGridLottery(lottery_);
    }

    /// @notice Tune the executor-fee safety rails within the hard ceilings.
    /// @dev The fee itself is always metered from actual gas at a basefee-capped
    ///      price — these only bound it. Ceilings keep a compromised owner from
    ///      turning the premium into a drain.
    function setFeeParams(uint16 feePremiumBps_, uint256 maxFeePerExecution_) external onlyOwner {
        require(feePremiumBps_ <= FEE_PREMIUM_CEILING_BPS, "premium too high");
        require(maxFeePerExecution_ > 0 && maxFeePerExecution_ <= MAX_FEE_CEILING, "bad max fee");
        feePremiumBps = feePremiumBps_;
        maxFeePerExecution = maxFeePerExecution_;
        emit FeeParamsUpdated(feePremiumBps_, maxFeePerExecution_);
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
        _configurePlan(plays, amountPerPlay, squares, bpsAlloc, autoClaim_);
    }

    /// @notice Configure a plan and deposit funds in a single transaction
    function configurePlanAndDeposit(
        uint32 plays,
        uint256 amountPerPlay,
        uint8[] calldata squares,
        uint16[] calldata bpsAlloc,
        bool autoClaim_
    ) external payable nonReentrant {
        require(msg.value > 0, "value=0");
        _configurePlan(plays, amountPerPlay, squares, bpsAlloc, autoClaim_);
        plans[msg.sender].balance += msg.value;
        emit Deposited(msg.sender, msg.value);
    }

    function _configurePlan(
        uint32 plays,
        uint256 amountPerPlay,
        uint8[] calldata squares,
        uint16[] calldata bpsAlloc,
        bool autoClaim_
    ) private {
        // plays = UNLIMITED_PLAYS means unlimited (run until balance runs out)
        // plays = 0 means no plays (plan will be disabled immediately)
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

    function disablePlan() external nonReentrant {
        plans[msg.sender].enabled = false;
        emit PlanDisabled(msg.sender);
    }

    /// @notice Cancel the plan and refund all remaining balance to the caller
    function cancelPlan() external nonReentrant {
        Plan storage p = plans[msg.sender];
        uint256 refundAmount = p.balance;

        p.enabled = false;
        p.balance = 0;

        if (refundAmount > 0) {
            (bool ok,) = payable(msg.sender).call{value: refundAmount}("");
            require(ok, "refund failed");
        }

        emit PlanCancelled(msg.sender, refundAmount);
        emit PlanDisabled(msg.sender);
    }

    /// @notice Execute a user's plan: claim the given winning rounds into the plan
    ///         balance, then bet on due rounds. Callable by anyone; the caller is
    ///         reimbursed metered gas + premium from the user's plan balance.
    /// @param user The plan owner
    /// @param maxPlays Max bets to place this call (1..MAX_PLAYS_PER_EXECUTION)
    /// @param claimRounds Rounds the keeper determined off-chain to be claimable wins
    ///        (resolved, user on winning square, not yet claimed). Each is re-verified
    ///        on-chain; a non-claimable entry is a harmless no-op, not a revert.
    function executeFor(address user, uint32 maxPlays, uint256[] calldata claimRounds) external nonReentrant {
        uint256 g0 = gasleft();

        uint256 claimed = _claimRounds(user, claimRounds);
        uint32 executed = _executePlays(user, maxPlays);

        if (executed == 0 && claimed == 0) revert NothingToExecute();

        _chargeExecutorFee(user, g0);
    }

    /// @notice Claim winning rounds into the plan balance without betting.
    ///         Useful when the balance is too low to bet until winnings land.
    ///         Caller is reimbursed like executeFor.
    function claimFor(address user, uint256[] calldata claimRounds) external nonReentrant returns (uint256 claimed) {
        uint256 g0 = gasleft();

        claimed = _claimRounds(user, claimRounds);
        if (claimed == 0) revert NothingToExecute();

        _chargeExecutorFee(user, g0);
    }

    function _claimRounds(address user, uint256[] calldata claimRounds) private returns (uint256 claimed) {
        if (claimRounds.length == 0) return 0;
        require(claimRounds.length <= MAX_CLAIMS_PER_EXECUTION, "too many claims");
        if (!plans[user].autoClaim) return 0;

        for (uint256 i = 0; i < claimRounds.length; i++) {
            if (_claimForUser(user, claimRounds[i])) {
                claimed++;
            }
        }
    }

    function _executePlays(address user, uint32 maxPlays) private returns (uint32 executed) {
        require(maxPlays > 0, "max=0");
        require(maxPlays <= MAX_PLAYS_PER_EXECUTION, "max too high");

        Plan storage p = plans[user];
        if (!p.enabled) return 0;

        uint8[] storage squares = p.squares;
        uint16[] storage bpsAlloc = p.bpsAlloc;
        if (squares.length == 0 || squares.length != bpsAlloc.length) revert BadConfig();

        // Continue until maxPlays reached, or playsRemaining hits 0 (if not unlimited), or balance runs out
        while (executed < maxPlays) {
            if (p.playsRemaining != UNLIMITED_PLAYS && p.playsRemaining == 0) {
                break;
            }

            uint256 r = LOTTERY.currentRoundId();
            // Only bet when the current round has reached nextRoundId — cannot bet in advance
            if (r < p.nextRoundId) {
                break;
            }

            // If rounds were missed, skip ahead to the current round
            if (r > p.nextRoundId) {
                p.nextRoundId = r;
            }

            // If the current round is not open, wait for the next one
            if (!LOTTERY.roundOpen(p.nextRoundId)) {
                p.nextRoundId = r + 1;
                break;
            }

            uint256 usedRound = p.nextRoundId;
            if (executedRounds[user][usedRound]) {
                p.nextRoundId = usedRound + 1;
                continue;
            }

            // New lottery accounts pay a one-time account deposit on their first bet
            bool needsAccountDeposit = !LOTTERY.getHasAccount(user);
            uint256 betValue = p.amountPerPlay + (needsAccountDeposit ? ACCOUNT_DEPOSIT : 0);

            // Reserve maxFeePerExecution so the executor fee can always be paid
            // after the bets go out; the reserve stays withdrawable by the user.
            if (p.balance < betValue + maxFeePerExecution) {
                break;
            }
            require(address(this).balance >= betValue, "insufficient contract balance");

            uint256[] memory amounts = _buildAllocations(p.amountPerPlay, bpsAlloc);

            p.balance -= betValue;
            if (p.playsRemaining != UNLIMITED_PLAYS) {
                p.playsRemaining -= 1;
            }
            // Mark executed BEFORE the external call / nextRoundId bump
            executedRounds[user][usedRound] = true;
            p.nextRoundId = usedRound + 1;
            executed += 1;

            emit RoundExecuted(user, usedRound, p.playsRemaining);

            LOTTERY.betFor{value: betValue}(usedRound, user, squares, amounts);

            if (p.playsRemaining == 0) {
                p.enabled = false;
                emit PlanDisabled(user);
            }
        }
    }

    /// @notice Reimburse msg.sender for the gas this call consumed, from the user's
    ///         plan balance. See fee-model constants at the top of the contract.
    function _chargeExecutorFee(address user, uint256 g0) private {
        Plan storage p = plans[user];

        uint256 gasUsed = g0 - gasleft() + FEE_GAS_OVERHEAD;
        uint256 gasPrice = tx.gasprice;
        uint256 priceCap = block.basefee * 2;
        if (priceCap > 0 && gasPrice > priceCap) {
            gasPrice = priceCap;
        }

        uint256 fee = (gasUsed * gasPrice * (uint256(BPS) + feePremiumBps)) / BPS;
        if (fee > maxFeePerExecution) fee = maxFeePerExecution;
        if (fee > p.balance) fee = p.balance;
        if (fee == 0) return;

        p.balance -= fee;
        (bool ok,) = msg.sender.call{value: fee}("");
        require(ok, "fee transfer failed");

        emit ExecutorFeePaid(user, msg.sender, fee, gasUsed);
    }

    /// @dev Claims one round for the user via the lottery's delegate claim.
    ///      Verifies claimability on-chain (callers are untrusted); returns false
    ///      instead of reverting when the round is not claimable.
    function _claimForUser(address user, uint256 roundId) private returns (bool) {
        (bool resolved, uint8 winningSquare) = _roundResult(roundId);
        if (!resolved) return false;

        if (LOTTERY.getHasClaimed(roundId, user)) return false;

        uint256 userBet = LOTTERY.getUserBet(roundId, winningSquare, user);
        if (userBet == 0) return false;

        // Requires the user to have approved this contract as a delegate
        if (!LOTTERY.getDelegate(user, address(this))) {
            return false;
        }

        // Set claimingUser so receive() can attribute the ETH.
        // Reentrancy protection is provided by nonReentrant on the external callers.
        claimingUser = user;

        uint256 balanceBefore = address(this).balance;
        uint256 claimedAmount = 0;
        bool success = false;

        // ethOnly: pull ONLY the ETH winnings back into the plan (recipientNative = this
        // contract) to recycle into the next bet, and leave the user's SLVR unrefined in
        // miner state — so it keeps accruing and earning dividends instead of being
        // auto-refined every round (which charged the 10% refining fee).
        ISlvrGridLottery.ClaimParams memory params;
        params.user = user;
        params.roundId = roundId;
        params.recipientNative = address(this);
        params.recipientSlvr = user;
        params.bypassFee = false;
        params.ethOnly = true;
        try LOTTERY.claimAdvanced(params) {
            uint256 balanceAfter = address(this).balance;
            claimedAmount = balanceAfter > balanceBefore ? balanceAfter - balanceBefore : 0;
            success = true;
        } catch {
            success = false;
        }

        claimingUser = address(0);

        // claimAdvanced can succeed with nativeOut == 0 (tiny bets rounding to 0);
        // still counts as claimed so the keeper stops resubmitting the round.
        if (success) {
            emit Claimed(user, roundId, claimedAmount, claimedAmount);
            return true;
        }

        return false;
    }

    function _roundResult(uint256 roundId) private view returns (bool resolved, uint8 winningSquare) {
        (, resolved,,, winningSquare,,,,,,,,,,,) = LOTTERY.getRound(roundId);
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

    /// @notice Check if a plan needs execution (ready to bet on the next round).
    ///         Mirrors _executePlays' preconditions, including the fee reserve.
    function needsExecution(address user) external view returns (bool ready, string memory reason) {
        Plan storage p = plans[user];

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

        uint256 targetRound = currentRound > p.nextRoundId ? currentRound : p.nextRoundId;

        if (executedRounds[user][targetRound]) {
            return (false, "round already executed");
        }

        if (!LOTTERY.roundOpen(targetRound)) {
            return (false, "round not open");
        }

        bool needsAccountDeposit = !LOTTERY.getHasAccount(user);
        uint256 betValue = p.amountPerPlay + (needsAccountDeposit ? ACCOUNT_DEPOSIT : 0);

        if (p.balance < betValue + maxFeePerExecution) {
            return (false, "insufficient balance");
        }

        return (true, "");
    }
}
