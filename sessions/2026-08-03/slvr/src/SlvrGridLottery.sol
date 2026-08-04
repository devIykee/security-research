// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IRandomnessProvider} from "./interfaces/IRandomnessProvider.sol";
import {ISlvrJackpot} from "./interfaces/ISlvrJackpot.sol";
import {SlvrToken} from "./SlvrToken.sol";
import {RandomnessLib} from "./libraries/RandomnessLib.sol";
import {MathLib} from "./libraries/MathLib.sol";
import {RoundLib} from "./libraries/RoundLib.sol";
import {BettorLib} from "./libraries/BettorLib.sol";
import {ClaimLib} from "./libraries/ClaimLib.sol";
import {FeeDistributionLib} from "./libraries/FeeDistributionLib.sol";
import {RewardStateLib} from "./libraries/RewardStateLib.sol";
import {ISlvrVoteEscrowStaking} from "./interfaces/ISlvrVoteEscrowStaking.sol";
import {ISlvrVoteEscrow} from "./interfaces/ISlvrVoteEscrow.sol";
import {ISlvrGridLottery} from "./interfaces/ISlvrGridLottery.sol";
import {ISlvrHub} from "./interfaces/ISlvrHub.sol";

/// @title SlvrGridLottery
/// @notice Core 25-square grid game with upgradeable randomness provider, jackpot, and carry-overs.
contract SlvrGridLottery is ReentrancyGuard, Ownable2Step, Pausable {
    using RandomnessLib for uint256;
    using MathLib for uint256;
    using SafeERC20 for IERC20;

    // Custom errors (replaces string literals for smaller bytecode)
    error NotAuthorized();
    error BadArrays();
    error RoundNotOpen();
    error BadSquare();
    error DupSquare();
    error BadAmount();
    error TransferFailed();
    error ZeroAddress();
    error BadGenesis();
    error BadClaim();
    error InvalidRevealBuffer();
    error NotResolved();
    error NotCurrentRound();
    error BadDuration();
    error NotOwner();
    error CannotAddToPermanentLock();
    error PermanentLockExists();
    error RewardNotFound();
    error DelegateRevokedError();
    error ApproveFailed();
    error MustSumTo100Percent();
    error JackpotOutOfRange();
    error StakerOutOfRange();
    error TooEarlyToRequest();
    error AlreadyRequested();
    error TooEarlyToReRequest();
    error BadState();
    error FeeTooLow();
    error FeeTooHigh();
    error CannotDelegateToSelf();
    error ValueNotSum();
    error ResolveRequested();
    error InsufficientValue();
    error BadRandomnessId();
    error RandomnessNotSettled();
    error TargetOutOfBounds();
    error AmountExceedsOwed();
    error FenwickTreeMismatch(uint256 simpleTotal, uint256 fenwickTotal);
    error StakingContractNotSet();
    error JackpotNotSet();
    error NoAccount();
    error NoPendingJackpot();
    error VoteEscrowNotSet();

    uint8 public constant GRID = 25;
    uint256 public constant WAD = MathLib.WAD;
    uint16 public constant BPS = MathLib.BPS;
    uint256 public constant JACKPOT_ODDS = 625;
    
    // Fee allocation constants (in basis points)
    uint16 public constant JACKPOT_FEE_BPS = 200; // 2% of total wager goes to jackpot (default, can be overridden)
    uint16 public constant TEAM_ALLOCATION_BPS = 800; // 8% of slvrPerRound goes to team
    uint16 public constant GROWTH_FUND_ALLOCATION_BPS = 400; // 4% of slvrPerRound goes to growth fund
    
    // Round duration limits (in seconds)
    uint64 public constant MIN_ROUND_DURATION = 10; // Minimum round duration
    uint64 public constant MAX_ROUND_DURATION = 3600; // Maximum round duration (1 hour)
    
    // Fee distribution validation limits (in basis points of protocol fee)
    uint16 public constant MAX_JACKPOT_FEE_BPS = 5000; // Maximum 50% of protocol fee can go to jackpot
    uint16 public constant MIN_STAKER_FEE_BPS = 5000; // Minimum 50% of protocol fee must go to stakers
    
    // Configurable fee distribution (in basis points of total wager)
    // These override the constant JACKPOT_FEE_BPS when set via setFeeDistribution()
    uint16 public jackpotFeeBps = JACKPOT_FEE_BPS; // Jackpot fee in basis points of total wager
    uint16 public stakerFeeBps; // Staker fee in basis points of protocol fee (calculated as protocolFeeBps - jackpotFeeBps)

    uint64 public immutable GENESIS_TIME;
    uint64 public immutable ROUND_DURATION; // full cycle: betting window + reveal window
    uint64 public immutable BETTING_DURATION; // betting window; the remainder of the cycle is the reveal window

    // Extra seconds past betting close before the pinned drand beacon may exist. Absorbs
    // sequencer-timestamp drift vs wall clock (drand rounds are wall-clock; betting close is
    // chain time) so a beacon can never be public while betting is still open. 12s tolerates
    // double-digit chain-clock lag (sequencer skew, node restarts) while still landing the
    // beacon mid reveal window (close+12..15 of the 30s window). If the chain's clock ever
    // lags wall time by MORE than this, the keeper's drift sentinel raises an alarm.
    // Reveal safety buffer (seconds). The pinned drand beacon unlocks at bettingEnd + this value, so
    // it stays un-knowable while betting is open even if the chain clock lags wall time by up to this
    // much. Now a settable storage var (was a constant 12) bounded to [MIN,MAX], so it can be tuned to
    // the chain's real clock drift without redeploying. Public name kept for keeper/frontend ABI compat.
    uint64 public REVEAL_SAFETY_BUFFER = 6;
    uint64 public constant MIN_REVEAL_SAFETY_BUFFER = 3;
    uint64 public constant MAX_REVEAL_SAFETY_BUFFER = 60;

    uint256 public slvrPerRound = 1e18;

    uint16 public protocolFeeBps = 1000; // 10% protocol fee
    uint16 public constant REFINING_FEE_BPS = 1_000; // 10% refining fee
    uint256 public constant ACCOUNT_DEPOSIT = 0.0001e18; // one-time account-opening fee for new miner accounts: anti-dust friction only, so keep it nominal (~$0.20)
    
    // Earliest time before round end when randomness can be requested (in seconds)
    // Default: 1 second (can be configured by owner)
    uint64 public earliestRequestTimeBeforeEnd = 2;

    // If a requested round is not resolved within this window, anyone may
    // re-request randomness (the provider re-pins to a fresh, still-unbiasable
    // future value). Recovers liveness if a beacon submission is missed/stale.
    uint64 public constant RESOLUTION_TIMEOUT = 5 minutes;

    // Fee distribution: Protocol fee is configurable, split as:
    // - Jackpot: 2% of total wager (fixed, not configurable)
    // - Stakers: remainder of protocol fee (default 8% when protocol fee is 10%)
    // - Team: 8% of supply inflation (handled in SlvrToken.mint, not volume-based)

    // New addresses
    address public stakingContract; // New staking contract address
    /// @notice Optional protocol hub. When set (!= 0), SLVR emission and staker rewards route
    ///         through the shared multi-game hub instead of minting/paying directly. When unset,
    ///         the lottery behaves exactly as before (legacy single-game path).
    address public hub;
    bytes32 public constant GAME_TYPE = keccak256("GRID_LOTTERY");
    address public teamWallet; // Team wallet address
    address public revenueRecipient; // Keep for account deposits (backward compatibility)
    ISlvrVoteEscrow public voteEscrow; // Vote escrow NFT contract for locking SLVR

    mapping(address => bool) internal hasAccount; // Track if address has opened a miner account

    IRandomnessProvider public randomnessProvider;

    SlvrToken public immutable SLVR;

    // Separate carry pools to prevent leaking staker/jackpot funds into winner payouts
    uint256 public carryWinnerNativePool; // Winner carry-over (when no winners)
    uint256 public carryStakerNativeOwed; // Staker rewards that failed to distribute
    uint256 public carryJackpotNativeOwed; // Jackpot funds that failed to add
    uint256 public carrySlvrPool;
    // Account-open deposits that could not be forwarded to revenueRecipient (it rejected the ETH).
    // Held in this contract and retryable via flushAccountDeposits() so they can't get stuck.
    uint256 public strandedAccountDeposits;

    // Jackpot contract - separate upgradeable contract
    ISlvrJackpot public jackpot; // Current active jackpot contract
    ISlvrJackpot public pendingJackpot; // Next jackpot contract (upgrades on next hit)

    mapping(uint256 => RoundLib.Round) internal rounds;
    mapping(uint256 => mapping(uint8 => uint256)) internal totalOnSquare;
    mapping(uint256 => mapping(uint8 => uint256)) internal bettorsOnSquare;
    mapping(uint256 => mapping(uint8 => mapping(address => uint256))) internal betOf;
    mapping(uint256 => mapping(uint8 => mapping(address => bool))) private _isBettor;
    // Track which jackpot contract was used for each round (for claiming after upgrades)
    mapping(uint256 => address) internal roundJackpot;
    
    uint256 public latestResolvedRoundId = type(uint256).max;
    // Fenwick tree (Binary Indexed Tree) for O(log N) bet updates and winner selection
    // Append-only bettors array (no sorting needed)
    mapping(uint256 => mapping(uint8 => address[])) private bettorsOnSquareArray;
    // Fenwick tree for prefix sums (size N+1, index 0 unused)
    mapping(uint256 => mapping(uint8 => uint256[])) private fenwickTree;
    // Bet amounts per index (size N, aligned with bettorsOnSquareArray)
    mapping(uint256 => mapping(uint8 => uint256[])) private betAmounts;
    // Mapping from bettor address to index+1 (0 means not found, stored as 1-indexed)
    mapping(uint256 => mapping(uint8 => mapping(address => uint32))) private bettorIndex;
    
    mapping(uint256 => mapping(address => bool)) internal hasClaimed; // Track who has claimed per round
    mapping(uint256 => mapping(address => uint256)) internal unclaimedSlvrPerRound; // Track unclaimed SLVR per miner per round
    // Track which users have had their rewards added to totalUnclaimed (lazy checkpointing)
    mapping(uint256 => mapping(address => bool)) private rewardAddedToTotalUnclaimed;
    // Store minerIndex at round resolution to compute refined rewards correctly
    mapping(uint256 => uint256) internal roundIndexAtResolve;

    // ORE-style checkpointing for refining
    uint256 public minerIndex; // Global index: cumulative refining fees per 1e18 unclaimed SLVR (scaled 1e18)
    uint256 public totalUnclaimed; // Total unclaimed SLVR across all miners
    uint256 public totalRefined; // Total refined SLVR outstanding (owed but not paid out)

    struct MinerState {
        uint256 rewardsSlvr; // User's unclaimed SLVR rewards (matches ORE's rewards_ore)
        uint256 indexSnapshot; // Last minerIndex when user checkpointed (matches ORE's rewards_factor)
        uint256 refinedAccrued; // Accumulated refined SLVR from checkpointing (matches ORE's refined_ore)
    }

    struct ClaimResult {
        uint256 nativeOut;
        uint256 slvrReward;     // raw round slvr reward
        uint256 totalPayout;    // slvrReward + refinedAccrued - fee
        uint256 refiningFee;
        uint256 userBet;
        uint256 winnerTotal;
        bool jackpotHit;
        uint256 refinedBefore;
    }

    struct Config {
        uint16 protocolFeeBps;           // Protocol fee in basis points (0 = no change)
        uint16 jackpotFeeBps;            // Jackpot fee in basis points of protocol fee (0 = no change)
        uint16 stakerFeeBps;             // Staker fee in basis points of protocol fee (0 = no change)
        address revenueRecipient;        // Revenue recipient (address(0) = no change, address(1) = set to zero)
        address stakingContract;         // Staking contract (address(0) = no change, address(1) = set to zero)
        address teamWallet;              // Team wallet (address(0) = no change, address(1) = set to zero)
        address voteEscrow;              // Vote escrow (address(0) = no change, address(1) = set to zero)
        address randomnessProvider;      // Randomness provider (address(0) = no change)
        uint256 slvrPerRound;            // SLVR per round (0 = no change)
        uint64 earliestRequestTimeBeforeEnd; // Earliest request time (type(uint64).max = no change)
    }

    mapping(address => MinerState) internal minerState;

    // Delegate system for claim-to-recipient functionality
    // delegates[user][delegate] = true if delegate is approved to claim on behalf of user
    mapping(address => mapping(address => bool)) internal delegates;

    // Authorized permanent lock contracts that can receive fee-bypassed claims
    // Only these contracts can receive SLVR with bypassFee=true to prevent fee bypass exploitation
    mapping(address => bool) public authorizedPermanentLockContracts;

    // Round events
    event BetPlaced(uint256 indexed roundId, address indexed beneficiary, uint256 total, uint8[] squares);
    event RandomnessRequested(uint256 indexed roundId, bytes32 randomnessId);
    event RandomnessReRequested(uint256 indexed roundId, bytes32 randomnessId);
    event RoundResolved(
        uint256 indexed roundId,
        uint8 winningSquare,
        bool jackpotHit,
        bool singleMinerRound,
        address indexed singleMinerWinner,
        uint256 winnerTotal,
        uint256 potForWinners,
        uint256 slvrForWinners,
        uint256 totalUnclaimedSlvr
    );
    event Claimed(
        uint256 indexed roundId,
        address indexed user,
        uint256 nativeOut,
        uint256 slvrOut,
        uint256 refinedOut,
        uint256 refiningFee
    );
    event JackpotUpdated(address indexed oldJackpot, address indexed newJackpot);
    event PendingJackpotSet(address indexed pendingJackpot);
    event JackpotUpgraded(address indexed oldJackpot, address indexed newJackpot);

    // Account events
    event AccountOpened(address indexed account, uint256 deposit);
    event AccountDepositTransferFailed(address indexed account, uint256 deposit, uint256 newCarryPool);
    event AccountCheckpointed(
        address indexed account, uint256 refinedAccrued, uint256 rewardsSlvr, uint256 indexSnapshot
    );

    // Treasury/Refining events
    event MinerIndexUpdated(uint256 newIndex, uint256 totalUnclaimed, uint256 totalRefined);
    event RefiningFeeApplied(
        address indexed account, uint256 rewardsSlvr, uint256 fee, uint256 newIndex, uint256 totalUnclaimed
    );

    // Configuration events
    event ProtocolFeeUpdated(uint16 oldFee, uint16 newFee);
    event RevenueRecipientUpdated(address indexed oldRecipient, address indexed newRecipient);
    event SlvrPerRoundUpdated(uint256 oldValue, uint256 newValue);
    event RandomnessProviderUpdated(address indexed oldProvider, address indexed newProvider);
    event MintSkippedMaxSupply(uint256 roundId, uint256 requestedAmount, uint256 currentSupply, uint256 maxSupply);
    event FeeDistributionUpdated(uint16 stakerBps, uint16 teamBps, uint16 jackpotBps);
    event TeamWalletUpdated(address indexed oldWallet, address indexed newWallet);
    event StakingContractUpdated(address indexed oldContract, address indexed newContract);
    event HubUpdated(address indexed oldHub, address indexed newHub);
    event VoteEscrowUpdated(address indexed oldContract, address indexed newContract);
    event EarliestRequestTimeBeforeEndUpdated(uint64 oldValue, uint64 newValue);
    event RevealSafetyBufferUpdated(uint64 oldValue, uint64 newValue);
    event PermanentLockContractAuthorized(address indexed contractAddress, bool authorized);
    
    // Delegate events
    event DelegateApproved(address indexed user, address indexed delegate);
    event DelegateRevoked(address indexed user, address indexed delegate);

    // Pausable events (inherited from Pausable: Paused, Unpaused)
    
    // External call failure events (for resilience)
    event StakerRewardsDistributionFailed(uint256 indexed roundId, uint256 amount, uint256 newCarryPool);
    event StakerCarryFlushed(uint256 amount, uint256 remainingCarry);
    event AccountDepositsFlushed(uint256 amount, uint256 remainingStranded);
    event JackpotAddFailed(uint256 indexed roundId, uint256 amount, uint256 newCarryPool);
    event JackpotCheckFailed(uint256 indexed roundId, bytes reason);
    event BribeDistributionFailed(uint256 indexed roundId, bytes reason);

    /// @param genesisTime_ Wall-clock start of round 0. Pass 0 to start immediately
    ///        (GENESIS_TIME = block.timestamp). Pass a future timestamp to delay the
    ///        first betting window (e.g. block.timestamp + 10 minutes) so operators can
    ///        populate addresses / env before betting opens. A past timestamp reverts —
    ///        it would retroactively "start" rounds nobody could bet on.
    constructor(address slvr_, address randomnessProvider_, address revenueRecipient_, uint64 genesisTime_)
        Ownable(msg.sender)
    {
        SLVR = SlvrToken(payable(slvr_));
        if (randomnessProvider_ == address(0)) revert ZeroAddress();
        randomnessProvider = IRandomnessProvider(randomnessProvider_);
        revenueRecipient = revenueRecipient_; // Keep for account deposits
        if (genesisTime_ == 0) {
            GENESIS_TIME = uint64(block.timestamp);
        } else {
            if (genesisTime_ < block.timestamp) revert BadGenesis();
            GENESIS_TIME = genesisTime_;
        }
        // Immutable: changing these post-deploy would break historical round math.
        // A round is a 90s cycle: [start, start+60) betting, then [start+60, start+90)
        // reveal — randomness is pinned strictly after betting closes and resolution
        // lands inside the reveal window, so the next round always opens with its
        // full 60s betting window intact.
        ROUND_DURATION = 90;
        BETTING_DURATION = 60;
        // Contract starts unpaused
    }

    receive() external payable {}

    function currentRoundId() public view returns (uint256) {
        if (block.timestamp < GENESIS_TIME) return 0;
        return (block.timestamp - GENESIS_TIME) / ROUND_DURATION;
    }

    /// @notice Returns the latest resolved round ID
    /// @dev Helps keepers identify which rounds need to be finalized on restart
    /// @return The round ID of the most recently resolved round
    function getLatestResolvedRoundId() external view returns (uint256) {
        return latestResolvedRoundId;
    }

    function roundStart(uint256 roundId) public view returns (uint256) {
        return uint256(GENESIS_TIME) + roundId * ROUND_DURATION;
    }

    function roundEnd(uint256 roundId) public view returns (uint256) {
        return roundStart(roundId) + ROUND_DURATION;
    }

    /// @notice When betting closes for a round. The remainder of the cycle
    ///         ([bettingEnd, roundEnd)) is the reveal window.
    function bettingEnd(uint256 roundId) public view returns (uint256) {
        return roundStart(roundId) + BETTING_DURATION;
    }

    /// @notice Whether bets are currently accepted for a round (the betting window,
    ///         NOT the full cycle — the reveal window is closed to bets).
    function roundOpen(uint256 roundId) public view returns (bool) {
        return block.timestamp >= roundStart(roundId) && block.timestamp < bettingEnd(roundId);
    }

    /// @notice Set (or clear) the protocol hub. When set, emission + staker rewards route through
    ///         it; existing jackpot/claim behavior is unchanged in this integration.
    /// @dev The ISlvrGame view surface (currentEpoch/epochEnd/epochStatus/gameType) is intentionally
    ///      kept out of this 24KB-bound core; a periphery lens contract exposes it for keepers/SDK
    ///      by reading currentRoundId()/roundEnd()/getRound()/GAME_TYPE.
    function setHub(address hub_) external onlyOwner {
        address old = hub;
        hub = hub_;
        emit HubUpdated(old, hub_);
    }

    /// @notice Unified config setter for all admin settings
    /// @dev Use address(1) to set address fields to zero, address(0) to skip
    /// @dev Use type(uint64).max to skip earliestRequestTimeBeforeEnd
    /// @dev Use 0 for numeric fields to skip (no change)
    function setConfig(Config calldata c) external onlyOwner {
        if (c.protocolFeeBps != 0) _setProtocolFee(c.protocolFeeBps);
        if (c.jackpotFeeBps != 0 || c.stakerFeeBps != 0) _setFeeDistribution(c.jackpotFeeBps, c.stakerFeeBps);
        if (c.revenueRecipient != address(0)) _setRevenueRecipient(c.revenueRecipient);
        if (c.stakingContract != address(0)) _setStakingContract(c.stakingContract);
        if (c.teamWallet != address(0)) _setTeamWallet(c.teamWallet);
        if (c.voteEscrow != address(0)) _setVoteEscrow(c.voteEscrow);
        if (c.randomnessProvider != address(0)) _setRandomnessProvider(c.randomnessProvider);
        if (c.slvrPerRound != 0) _setSlvrPerRound(c.slvrPerRound);
        if (c.earliestRequestTimeBeforeEnd != type(uint64).max) _setEarliestRequestTimeBeforeEnd(c.earliestRequestTimeBeforeEnd);
    }

    /// @notice Internal function to set protocol fee
    function _setProtocolFee(uint16 newFee) internal {
        if (newFee < JACKPOT_FEE_BPS) revert FeeTooLow();
        if (newFee > 2_000) revert FeeTooHigh();
        uint16 oldFee = protocolFeeBps;
        protocolFeeBps = newFee;

        // Re-scale the absolute jackpot cut to preserve the configured jackpot:staker RATIO. The
        // stored jackpotFeeBps is absolute (bps of total wager, = protocolFeeBps * share), so
        // lowering protocolFeeBps alone would otherwise leave a stale absolute cut that
        // RoundLib.calculateFeeSplit clamps to the fee — silently starving stakers (100/0) with no
        // event. Deriving the relative share from stakerFeeBps (jackpot share = BPS - stakerFeeBps,
        // since the two sum to BPS) and re-applying it keeps the split proportional. stakerFeeBps is
        // 0 only before any distribution has been configured, where the default absolute cut stands.
        // In a single-tx "lower both" setConfig, _setFeeDistribution runs after this and re-derives
        // jackpotFeeBps from the new ratio, so this intermediate re-scale is harmless.
        if (stakerFeeBps != 0) {
            uint16 jackpotShareBps = BPS - stakerFeeBps;
            jackpotFeeBps = uint16((uint256(newFee) * uint256(jackpotShareBps)) / uint256(BPS));
        }
        emit ProtocolFeeUpdated(oldFee, newFee);
    }

    /// @notice Internal function to set fee distribution
    function _setFeeDistribution(uint16 jackpotFeeBps_, uint16 stakerFeeBps_) internal {
        if (jackpotFeeBps_ + stakerFeeBps_ != BPS) revert MustSumTo100Percent();
        if (jackpotFeeBps_ > MAX_JACKPOT_FEE_BPS) revert JackpotOutOfRange();
        if (stakerFeeBps_ < MIN_STAKER_FEE_BPS || stakerFeeBps_ > BPS) revert StakerOutOfRange();
        jackpotFeeBps = uint16((uint256(protocolFeeBps) * uint256(jackpotFeeBps_)) / uint256(BPS));
        stakerFeeBps = stakerFeeBps_;
        emit FeeDistributionUpdated(stakerFeeBps_, 0, jackpotFeeBps_);
    }

    /// @notice Internal function to set revenue recipient
    function _setRevenueRecipient(address newRecipient) internal {
        address resolvedRecipient = newRecipient == address(1) ? address(0) : newRecipient;
        address oldRecipient = revenueRecipient;
        revenueRecipient = resolvedRecipient;
        emit RevenueRecipientUpdated(oldRecipient, resolvedRecipient);
    }

    /// @notice Internal function to set staking contract
    function _setStakingContract(address newContract) internal {
        address resolvedContract = newContract == address(1) ? address(0) : newContract;
        address oldContract = stakingContract;
        stakingContract = resolvedContract;
        emit StakingContractUpdated(oldContract, resolvedContract);
    }

    /// @notice Internal function to set team wallet
    function _setTeamWallet(address newWallet) internal {
        address resolvedWallet = newWallet == address(1) ? address(0) : newWallet;
        address oldWallet = teamWallet;
        teamWallet = resolvedWallet;
        emit TeamWalletUpdated(oldWallet, resolvedWallet);
    }

    /// @notice Internal function to set vote escrow
    function _setVoteEscrow(address newVoteEscrow) internal {
        address resolvedVoteEscrow = newVoteEscrow == address(1) ? address(0) : newVoteEscrow;
        address oldVoteEscrow = address(voteEscrow);
        voteEscrow = newVoteEscrow == address(1) ? ISlvrVoteEscrow(address(0)) : ISlvrVoteEscrow(newVoteEscrow);
        emit VoteEscrowUpdated(oldVoteEscrow, resolvedVoteEscrow);
    }

    /// @notice Internal function to set randomness provider
    function _setRandomnessProvider(address newProvider) internal {
        if (newProvider == address(1)) revert ZeroAddress();
        address oldProvider = address(randomnessProvider);
        randomnessProvider = IRandomnessProvider(newProvider);
        emit RandomnessProviderUpdated(oldProvider, newProvider);
    }

    /// @notice Internal function to set SLVR per round
    function _setSlvrPerRound(uint256 newValue) internal {
        uint256 oldValue = slvrPerRound;
        slvrPerRound = newValue;
        emit SlvrPerRoundUpdated(oldValue, newValue);
    }

    /// @notice Internal function to set earliest request time before betting close
    function _setEarliestRequestTimeBeforeEnd(uint64 newValue) internal {
        if (newValue > BETTING_DURATION) revert BadDuration();
        uint64 oldValue = earliestRequestTimeBeforeEnd;
        earliestRequestTimeBeforeEnd = newValue;
        emit EarliestRequestTimeBeforeEndUpdated(oldValue, newValue);
    }

    /// @notice Set the reveal safety buffer (seconds), bounded to [MIN,MAX]. Lower = faster round
    ///         resolution; must stay above the chain's worst-case clock-vs-wall drift to keep the
    ///         pinned drand beacon un-knowable while betting is still open.
    function setRevealSafetyBuffer(uint64 newBuffer) external onlyOwner {
        if (newBuffer < MIN_REVEAL_SAFETY_BUFFER || newBuffer > MAX_REVEAL_SAFETY_BUFFER) revert InvalidRevealBuffer();
        uint64 oldBuffer = REVEAL_SAFETY_BUFFER;
        REVEAL_SAFETY_BUFFER = newBuffer;
        emit RevealSafetyBufferUpdated(oldBuffer, newBuffer);
    }

    /// @notice Pause the contract - stops betting, resolving, and claiming
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpause the contract - resumes normal operations
    function unpause() external onlyOwner {
        _unpause();
    }

    /// @notice Approve a delegate to claim rewards on your behalf to a recipient address
    /// @dev This enables contracts like AutoCommit to claim and receive rewards for reinvestment
    /// @param delegate The address that will be allowed to claim on your behalf
    function approveDelegate(address delegate) external {
        if (delegate == address(0)) revert ZeroAddress();
        if (delegate == msg.sender) revert CannotDelegateToSelf();
        delegates[msg.sender][delegate] = true;
        emit DelegateApproved(msg.sender, delegate);
    }

    /// @notice Revoke a delegate's approval to claim on your behalf
    /// @param delegate The address to revoke approval from
    function revokeDelegate(address delegate) external {
        if (delegate == address(0)) revert ZeroAddress();
        delegates[msg.sender][delegate] = false;
        emit DelegateRevoked(msg.sender, delegate);
    }


    /// @notice Set authorized permanent lock contract (e.g., SlvrClaimLocker)
    /// @dev Only authorized contracts can receive fee-bypassed claims (bypassFee=true)
    ///      This prevents anyone from bypassing the 10% refining fee
    /// @param contractAddress The contract address to authorize/unauthorize
    /// @param authorized Whether to authorize (true) or unauthorize (false) the contract
    function setAuthorizedPermanentLockContract(address contractAddress, bool authorized) external onlyOwner {
        if (contractAddress == address(0)) revert ZeroAddress();
        authorizedPermanentLockContracts[contractAddress] = authorized;
        emit PermanentLockContractAuthorized(contractAddress, authorized);
    }

    function bet(uint256 roundId, uint8[] calldata squares, uint256[] calldata amounts) external payable whenNotPaused {
        betFor(roundId, msg.sender, squares, amounts);
    }

    function betFor(uint256 roundId, address beneficiary, uint8[] calldata squares, uint256[] calldata amounts)
        public
        payable
        nonReentrant
        whenNotPaused
    {
        if (beneficiary == address(0)) revert ZeroAddress();
        if (roundId != currentRoundId()) revert NotCurrentRound();
        if (!roundOpen(roundId)) revert RoundNotOpen();
        if (squares.length == 0 || squares.length != amounts.length) revert BadArrays();
        if (msg.value == 0) revert BadAmount();

        // Validate squares and calculate bet amount first
        uint256 sum = _validateSquaresAndAmounts(squares, amounts);

        // Handle account deposit for new accounts
        uint256 betAmount = _handleAccountDeposit(beneficiary, sum);

        if (sum != betAmount) revert ValueNotSum();

        RoundLib.Round storage r = rounds[roundId];
        if (r.resolved) revert NotResolved();
        if (r.requestedAt != 0) revert ResolveRequested();

        r.totalWager += betAmount;
        _recordBets(roundId, beneficiary, squares, amounts);

        emit BetPlaced(roundId, beneficiary, betAmount, squares);
    }

    function _handleAccountDeposit(address beneficiary, uint256 expectedBetAmount) private returns (uint256 betAmount) {
        bool isNewAccount = !hasAccount[beneficiary];
        uint256 requiredAmount;
        
        if (isNewAccount) {
            requiredAmount = expectedBetAmount + ACCOUNT_DEPOSIT;
            if (msg.value < requiredAmount) revert InsufficientValue();
            hasAccount[beneficiary] = true;
            if (revenueRecipient != address(0)) {
                (bool ok,) = payable(revenueRecipient).call{value: ACCOUNT_DEPOSIT}("");
                if (!ok) {
                    // Transfer failed - keep deposit in lottery contract and track it for recovery.
                    // This prevents bricking new account onboarding if revenueRecipient rejects ETH.
                    // Recoverable via flushAccountDeposits() once revenueRecipient can accept ETH.
                    strandedAccountDeposits += ACCOUNT_DEPOSIT;
                    emit AccountDepositTransferFailed(beneficiary, ACCOUNT_DEPOSIT, address(this).balance);
                }
            }
            emit AccountOpened(beneficiary, ACCOUNT_DEPOSIT);
            betAmount = expectedBetAmount;
        } else {
            // For existing accounts, require exact expectedBetAmount
            requiredAmount = expectedBetAmount;
            if (msg.value < requiredAmount) revert InsufficientValue();
            betAmount = expectedBetAmount;
        }
        if (betAmount == 0) revert BadAmount();
        
        // Refund any excess msg.value back to msg.sender (not beneficiary)
        // This prevents silent loss of funds and accounting drift
        if (msg.value > requiredAmount) {
            uint256 excess = msg.value - requiredAmount;
            (bool ok,) = payable(msg.sender).call{value: excess}("");
            if (!ok) revert TransferFailed();
        }
    }

    function _validateSquaresAndAmounts(uint8[] calldata squares, uint256[] calldata amounts)
        private
        pure
        returns (uint256 sum)
    {
        uint256 mask;
        for (uint256 i = 0; i < squares.length; i++) {
            uint8 s = squares[i];
            if (s >= GRID) revert BadSquare();
            uint256 bit = uint256(1) << uint256(s);
            if ((mask & bit) != 0) revert DupSquare();
            mask |= bit;

            uint256 a = amounts[i];
            if (a == 0) revert BadAmount();
            sum += a;
        }
    }

    function _recordBets(uint256 roundId, address beneficiary, uint8[] calldata squares, uint256[] calldata amounts)
        private
    {
        for (uint256 i = 0; i < squares.length; i++) {
            uint8 s = squares[i];
            uint256 a = amounts[i];

            bool isNewBettor = !_isBettor[roundId][s][beneficiary];
            if (isNewBettor) {
                _isBettor[roundId][s][beneficiary] = true;
                bettorsOnSquare[roundId][s] += 1;
            }
            
            BettorLib.addOrUpdateBet(
                bettorsOnSquareArray[roundId][s],
                fenwickTree[roundId][s],
                betAmounts[roundId][s],
                bettorIndex[roundId][s],
                beneficiary,
                a
            );

            // Update legacy betOf mapping for compatibility
            betOf[roundId][s][beneficiary] += a;
            totalOnSquare[roundId][s] += a;
        }
    }

    function requestResolve(uint256 roundId) external nonReentrant whenNotPaused {
        uint256 closeTime = bettingEnd(roundId);
        // Earliest time to request is configurable seconds before betting closes
        // If the window is missed, can still request later (during/after the reveal window)
        if (earliestRequestTimeBeforeEnd > 0 && block.timestamp < closeTime - earliestRequestTimeBeforeEnd) {
            revert TooEarlyToRequest();
        }
        RoundLib.Round storage r = rounds[roundId];
        if (r.resolved) revert NotResolved();
        if (r.requestedAt != 0) revert AlreadyRequested();

        bytes32 rid = RandomnessLib.deriveRandomnessId(address(this), roundId, r.totalWager);
        r.randomnessId = rid;
        r.requestedAt = uint64(block.timestamp);

        // Unlock floor for the beacon: betting close plus a skew buffer, so the
        // pinned drand round can never be public while bets are still accepted even
        // if the chain clock lags wall time by up to REVEAL_SAFETY_BUFFER.
        uint256 unlockTime = closeTime + REVEAL_SAFETY_BUFFER;
        uint256 timeUntilUnlock = unlockTime > block.timestamp ? unlockTime - block.timestamp : 0;
        bytes memory providerData = abi.encode(timeUntilUnlock);

        randomnessProvider.requestRandomness(rid, address(this), providerData);
        emit RandomnessRequested(roundId, rid);
    }

    function resolveRound(uint256 roundId, bytes calldata updateData) external nonReentrant whenNotPaused {
        RoundLib.Round storage r = rounds[roundId];
        if (r.resolved || r.requestedAt == 0) revert NotResolved();
        // Resolution is allowed once betting has closed — i.e. inside the reveal
        // window — so the result lands before the cycle ends and the next round
        // opens with its full betting window. (The provider independently refuses
        // to settle before its unlock floor.)
        if (block.timestamp < bettingEnd(roundId)) revert TooEarlyToRequest();

        randomnessProvider.settleRandomness(r.randomnessId, updateData);
        _processRandomness(r, roundId);
        
        // For zero-wager rounds, skip value calculations and just finalize
        if (r.totalWager > 0) {
            _calculateRoundValues(r, roundId);
            _applyJackpot(r, roundId);
            _applySingleMiner(r, roundId);
        } else {
            // Zero-wager rounds: no fees, no SLVR minting, no jackpot.
            // Preserve any carried-over pot/SLVR so an empty round doesn't wipe
            // it — _finalizeRoundNoWinners re-carries these values unchanged.
            r.fee = 0;
            r.potForWinners = carryWinnerNativePool;
            r.slvrForWinners = carrySlvrPool;
            r.jackpotHit = false;
            r.singleMinerRound = false;

            _distributeStakerRewards(0, roundId);
        }

        if (r.winnerTotal == 0) {
            _finalizeRoundNoWinners(r, roundId);
        } else {
            _finalizeRoundWithWinners(r, roundId);
        }
    }

    /// @notice Re-request randomness for a round that was requested but never
    ///         resolved within `RESOLUTION_TIMEOUT`. Callable by anyone.
    /// @dev The randomnessId is unchanged; the provider re-pins to a fresh
    ///      future value (e.g. a later drand round), which is still unbiasable
    ///      because it isn't known at re-request time. This recovers liveness
    ///      if a beacon submission was missed or the provider request went stale.
    function reRequestResolve(uint256 roundId) external nonReentrant whenNotPaused {
        RoundLib.Round storage r = rounds[roundId];
        if (r.resolved || r.requestedAt == 0) revert NotResolved();
        if (block.timestamp < uint256(r.requestedAt) + RESOLUTION_TIMEOUT) revert TooEarlyToReRequest();

        r.requestedAt = uint64(block.timestamp);
        // The round has ended, so there is no time-until-end; the provider pins
        // the next future beacon.
        randomnessProvider.requestRandomness(r.randomnessId, address(this), abi.encode(uint256(0)));
        emit RandomnessReRequested(roundId, r.randomnessId);
    }

    function _processRandomness(RoundLib.Round storage r, uint256 roundId) private {
        if (r.randomnessId != RandomnessLib.deriveRandomnessId(address(this), roundId, r.totalWager)) revert BadRandomnessId();
        (uint256 value, uint256 settledAt) = randomnessProvider.getRandomness(r.randomnessId);
        if (settledAt == 0) revert RandomnessNotSettled();
        r.randomnessValue = value;
        r.winningSquare = RandomnessLib.calculateWinningSquare(r.randomnessValue, GRID);
        
        // Get winnerTotal from simple counter
        uint256 simpleTotal = totalOnSquare[roundId][r.winningSquare];
        
        address[] storage bettors = bettorsOnSquareArray[roundId][r.winningSquare];
        uint256[] storage fenwick = fenwickTree[roundId][r.winningSquare];
        uint256 fenwickTotal = BettorLib.total(fenwick, bettors.length);
        
        if (simpleTotal != fenwickTotal) {
            revert FenwickTreeMismatch(simpleTotal, fenwickTotal);
        }
        
        r.winnerTotal = simpleTotal;
    }

    function _calculateRoundValues(RoundLib.Round storage r, uint256 roundId) private {
        uint256 jackpotAmount;
        uint256 stakerAmount;
        (r.fee, jackpotAmount, stakerAmount) = RoundLib.calculateFeeSplit(r.totalWager, protocolFeeBps, jackpotFeeBps);
        _distributeStakerRewards(stakerAmount, roundId);
        _addToJackpot(jackpotAmount, roundId);
        // Emission is governed entirely by the shared hub stream (the hub is the sole minter and
        // applies the protocol cap/soft-cap centrally, returning the amount actually minted).
        // LIVENESS: failure-isolated — a hub/registry misconfig degrades to "no emission this
        // round" instead of bricking resolution (round funds must never get stuck).
        uint256 actualSlvrForRound;
        if (hub != address(0)) {
            try ISlvrHub(hub).mintReward(address(this), slvrPerRound) returns (uint256 minted) {
                actualSlvrForRound = minted;
            } catch {
                actualSlvrForRound = 0;
            }
        }
        (r.potForWinners, r.slvrForWinners) = RoundLib.calculateDistributables(r.totalWager, r.fee, carryWinnerNativePool, actualSlvrForRound, carrySlvrPool);
    }

    function _applyJackpot(RoundLib.Round storage r, uint256 roundId) private {
        if (address(jackpot) == address(0)) return;
        try jackpot.checkAndApply(r.randomnessValue, roundId, r.winnerTotal) returns (bool hit, uint256 ethBonus, uint256 slvrBonus) {
            r.jackpotHit = hit;
            if (ethBonus > 0) r.potForWinners += ethBonus;
            if (slvrBonus > 0) r.slvrForWinners += slvrBonus;
            if (r.jackpotHit) {
                roundJackpot[roundId] = address(jackpot);
                _upgradeJackpotIfPending();
                if (r.winnerTotal > 0) _distributeBribes(roundId);
            }
        } catch (bytes memory reason) {
            r.jackpotHit = false;
            emit JackpotCheckFailed(roundId, reason);
        }
    }
    
    /// @notice Upgrade to pending jackpot if set (called automatically on jackpot check)
    function _upgradeJackpotIfPending() private {
        if (address(pendingJackpot) != address(0)) {
            address oldJackpot = address(jackpot);
            jackpot = pendingJackpot;
            pendingJackpot = ISlvrJackpot(address(0)); // Clear pending
            emit JackpotUpgraded(oldJackpot, address(jackpot));
        }
    }

    /// @notice Distribute all bribe tokens when jackpot hits
    /// @dev Bribes are tracked per round and distributed pro-rata to winners in claim()
    /// @dev Uses the jackpot that was active when the round was hit (stored in roundJackpot)
    ///      This ensures bribes are distributed from the correct contract even after upgrades
    /// @param roundId The round ID where jackpot hit
    function _distributeBribes(uint256 roundId) private {
        address roundJackpotAddr = roundJackpot[roundId];
        if (roundJackpotAddr == address(0)) {
            roundJackpotAddr = address(jackpot);
        }
        if (roundJackpotAddr != address(0)) {
            try ISlvrJackpot(roundJackpotAddr).distributeBribes(roundId) {
                // Success - bribes distributed
            } catch (bytes memory reason) {
                emit BribeDistributionFailed(roundId, reason);
            }
        }
    }

    function _applySingleMiner(RoundLib.Round storage r, uint256 roundId) private {
        (r.singleMinerRound,) = RoundLib.processSingleMiner(r.randomnessValue, roundId);
    }

    function _finalizeRoundNoWinners(RoundLib.Round storage r, uint256 roundId) private {
        carryWinnerNativePool = r.potForWinners;
        carrySlvrPool = r.slvrForWinners;
        r.resolved = true;
        r.singleMinerWinner = address(0);
        r.potForWinners = 0;
        r.slvrForWinners = 0;
        r.payoutMulWad = 0;
        r.slvrMulWad = 0;
        r.totalUnclaimedSlvr = 0;
        if (latestResolvedRoundId == type(uint256).max || roundId > latestResolvedRoundId) {
            latestResolvedRoundId = roundId;
        }
        emit RoundResolved(roundId, r.winningSquare, r.jackpotHit, r.singleMinerRound, address(0), 0, 0, 0, 0);
    }

    function _finalizeRoundWithWinners(RoundLib.Round storage r, uint256 roundId) private {
        carryWinnerNativePool = 0;
        carrySlvrPool = 0;
        uint256 rv2 = RandomnessLib.deriveSingleMinerRandomness(r.randomnessValue, roundId);
        (r.payoutMulWad, r.slvrMulWad) = RoundLib.calculatePayoutMultipliers(
            r.potForWinners, r.slvrForWinners, r.winnerTotal, r.singleMinerRound, rv2
        );

        // Determine single miner winner immediately if it's a single miner round
        if (r.singleMinerRound) {
            // Use winnerTotal (which should match Fenwick tree total after _processRandomness validation)
            // Calculate target using winnerTotal to ensure uniform distribution
            if (r.winnerTotal == 0) revert TargetOutOfBounds();
            uint256 target = rv2 % r.winnerTotal;
            r.singleMinerWinner = _determineSingleMinerWinner(roundId, r.winningSquare, target, r.winnerTotal);
        } else {
            r.singleMinerWinner = address(0);
        }

        // Rewards are added lazily when users claim (ORE pattern)
        // This prevents DoS from iterating through many winners at resolution time
        // However, we need totalUnclaimed to be accurate for fee calculations
        // So we add slvrForWinners to totalUnclaimed here (without iterating through winners)
        // Individual rewards are still added lazily to miner state when they claim
        totalUnclaimed += r.slvrForWinners;

        // Store minerIndex at resolution to compute refined rewards correctly
        // This ensures users only earn refined rewards since the round was resolved,
        // not from all historical index increases
        roundIndexAtResolve[roundId] = minerIndex;

        r.resolved = true;
        r.totalUnclaimedSlvr = r.slvrForWinners;
        if (latestResolvedRoundId == type(uint256).max || roundId > latestResolvedRoundId) {
            latestResolvedRoundId = roundId;
        }
        emit RoundResolved(roundId, r.winningSquare, r.jackpotHit, r.singleMinerRound, r.singleMinerWinner, r.winnerTotal, r.potForWinners, r.slvrForWinners, r.totalUnclaimedSlvr);
    }


    /// @notice Add SLVR reward to a user's unclaimed balance (lazy checkpointing)
    /// @dev Called when user claims to add their reward to state and totalUnclaimed
    ///      This prevents DoS from iterating through many winners at resolution time
    ///      For single miner rounds, only the winner gets rewards
    ///      For normal rounds, users get pro-rata rewards based on their bet
    ///      Computes refined rewards only since round resolution to avoid over-crediting
    /// @param user The user address to add rewards for
    /// @param roundId The round ID
    /// @param userBet The user's bet amount on the winning square
    /// @return reward The reward amount that was added
    function _addUserRewardToTotalUnclaimed(address user, uint256 roundId, uint256 userBet) private returns (uint256 reward) {
        RoundLib.Round storage r = rounds[roundId];
        
        // Check if reward already added (idempotent)
        if (rewardAddedToTotalUnclaimed[roundId][user]) {
            return 0;
        }

        reward = RewardStateLib.calculateReward(r, userBet, user);

        if (reward > 0) {
            MinerState storage state = minerState[user];
            uint256 indexAtResolve = roundIndexAtResolve[roundId];
            
            RewardStateLib.RewardStateParams memory params = RewardStateLib.RewardStateParams({
                reward: reward,
                minerIndex: minerIndex,
                indexAtResolve: indexAtResolve,
                totalRefined: totalRefined
            });
            RewardStateLib.RewardStateResult memory result = RewardStateLib.applyRefinedRewards(params);
            
            state.rewardsSlvr += reward;
            state.refinedAccrued += result.refinedFromReward;
            totalRefined = result.newTotalRefined;
            state.indexSnapshot = minerIndex;
            rewardAddedToTotalUnclaimed[roundId][user] = true;
        }

        return reward;
    }

    /// @notice Determine single miner winner deterministically based on target and cumulative bets
    /// @dev Uses Fenwick tree for O(log N) winner lookup
    function _determineSingleMinerWinner(uint256 roundId, uint8 winningSquare, uint256 target, uint256 winnerTotal) private view returns (address) {
        address[] storage bettors = bettorsOnSquareArray[roundId][winningSquare];
        uint256[] storage fenwick = fenwickTree[roundId][winningSquare];
        
        if (target >= winnerTotal) revert TargetOutOfBounds();
        
        uint256 fenwickTotal = BettorLib.total(fenwick, bettors.length);
        if (fenwickTotal != winnerTotal) {
            if (target >= fenwickTotal) revert TargetOutOfBounds();
            return BettorLib.pickWinner(bettors, fenwick, target);
        }
        
        return BettorLib.pickWinner(bettors, fenwick, target);
    }


    /// @notice Fan the round's staker fee into the shared veNFT staker stream via the hub.
    /// @dev The hub owns the sequential counter the staking contract requires. Called every resolved
    ///      round (amount may be 0) to keep the sequence tight. LIVENESS: failure-isolated — if the
    ///      hub rejects or is unset, retain the funds as carry so resolution never bricks.
    function _distributeStakerRewards(uint256 amount, uint256 roundId) private {
        // Fold any previously-stranded carry into this round's payout so a transient hub failure
        // self-heals on the very next resolution, instead of parking ETH until someone remembers to
        // call flushStakerCarry (which no keeper does). The carry funds are already held by this
        // contract, so sending amount + carry is fully covered.
        uint256 total = amount + carryStakerNativeOwed;
        if (total == 0) return;

        if (hub == address(0)) {
            carryStakerNativeOwed = total; // hub is required in production; retain until it's set
            return;
        }

        // Clear carry before the external call; restore on failure (the reverted call returns value).
        carryStakerNativeOwed = 0;
        try ISlvrHub(hub).payStakers{value: total}() {}
        catch {
            carryStakerNativeOwed = total;
            emit StakerRewardsDistributionFailed(roundId, amount, carryStakerNativeOwed);
        }
    }

    function _addToJackpot(uint256 amount, uint256 roundId) private {
        (bool success, bool shouldCarry) = FeeDistributionLib.addToJackpot(amount, jackpot);
        if (shouldCarry) {
            carryJackpotNativeOwed += amount;
        }
        if (!success && amount > 0) {
            emit JackpotAddFailed(roundId, amount, carryJackpotNativeOwed);
        }
    }

    /// @notice Retry forwarding staker rewards that previously failed and were parked in carry.
    /// @dev Permissionless (only moves already-owed funds to the hub's staker stream). Mirrors
    ///      retryJackpotAdd and the hub's own flushStakers, closing the previously write-only
    ///      carryStakerNativeOwed accumulator so those ETH can never get permanently stuck.
    /// @param amount Amount to flush (0 = flush all owed)
    /// @return success Whether the forward succeeded
    function flushStakerCarry(uint256 amount) external nonReentrant returns (bool success) {
        uint256 toFlush = amount == 0 ? carryStakerNativeOwed : amount;
        if (toFlush == 0 || toFlush > carryStakerNativeOwed) revert BadAmount();
        if (hub == address(0)) revert StakingContractNotSet();
        // Reduce before the external call; restore on failure (funds stay in this contract because
        // the reverted call returns the value).
        carryStakerNativeOwed -= toFlush;
        try ISlvrHub(hub).payStakers{value: toFlush}() {
            emit StakerCarryFlushed(toFlush, carryStakerNativeOwed);
            return true;
        } catch {
            carryStakerNativeOwed += toFlush;
            return false;
        }
    }

    /// @notice Retry forwarding account-open deposits that revenueRecipient previously rejected.
    /// @dev Permissionless; only moves the tracked stranded amount to the current revenueRecipient.
    /// @return success Whether the forward succeeded
    function flushAccountDeposits() external nonReentrant returns (bool success) {
        uint256 amount = strandedAccountDeposits;
        if (amount == 0) revert BadAmount();
        if (revenueRecipient == address(0)) revert ZeroAddress();
        strandedAccountDeposits = 0;
        (success,) = payable(revenueRecipient).call{value: amount}("");
        if (success) {
            emit AccountDepositsFlushed(amount, 0);
        } else {
            strandedAccountDeposits = amount; // restore on failure
        }
    }

    /// @notice Retry adding funds to jackpot that previously failed
    /// @dev Owner/keeper can call this to retry failed jackpot additions
    /// @param amount Amount to retry (0 = retry all owed)
    /// @return success Whether the addition succeeded
    function retryJackpotAdd(uint256 amount) external nonReentrant returns (bool success) {
        uint256 toAdd = amount == 0 ? carryJackpotNativeOwed : amount;
        if (toAdd == 0 || toAdd > carryJackpotNativeOwed || address(jackpot) == address(0)) revert BadAmount();
        try jackpot.addEth{value: toAdd}() {
            carryJackpotNativeOwed -= toAdd;
            emit JackpotAddFailed(0, toAdd, carryJackpotNativeOwed);
            return true;
        } catch {
            return false;
        }
    }

    /// @notice Add ETH (native) tokens to jackpot pool
    /// @dev Called by SlvrToken after swapback converts SLVR tax to ETH
    /// @dev Redirects to jackpot contract
    function addEthToJackpot() external payable {
        if (msg.value == 0) revert BadAmount();
        if (address(jackpot) != address(0)) {
            jackpot.addEth{value: msg.value}();
        }
    }

    /// @notice Donate SLVR tokens directly to jackpot pool
    /// @dev Called by SlvrToken when tax is collected (instead of swapping to ETH)
    /// @dev Transfers tokens from caller to this contract, approves jackpot, then calls addSlvr
    /// @param amount Amount of SLVR to donate
    function donateSlvrToJackpot(uint256 amount) public {
        if (amount == 0 || address(jackpot) == address(0)) revert BadAmount();
        IERC20(address(SLVR)).safeTransferFrom(msg.sender, address(this), amount);
        IERC20(address(SLVR)).forceApprove(address(jackpot), amount);
        jackpot.addSlvr(amount);
    }

    /// @notice Whitelist or remove a token from the bribe whitelist
    /// @dev Only owner can manage whitelist
    /// @dev Redirects to jackpot contract
    /// @param token The token address to whitelist/remove
    /// @param whitelisted Whether to whitelist (true) or remove (false) the token
    function setBribeTokenWhitelist(address token, bool whitelisted) external onlyOwner {
        if (address(jackpot) == address(0)) revert JackpotNotSet();
        jackpot.setBribeTokenWhitelist(token, whitelisted);
    }

    /// @notice Deposit tokens as a bribe to the jackpot pool
    /// @dev Only whitelisted tokens can be used as bribes
    /// @dev Redirects to jackpot contract
    /// @param token The token address to deposit
    /// @param amount The amount of tokens to deposit
    function depositBribe(address token, uint256 amount) external nonReentrant whenNotPaused {
        if (address(jackpot) == address(0)) revert JackpotNotSet();
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        IERC20(token).forceApprove(address(jackpot), amount);
        jackpot.depositBribe(token, amount);
    }
    
    /// @notice Set the jackpot contract address
    /// @dev Only owner can set this
    /// @param jackpot_ The new jackpot contract address
    function setJackpot(address jackpot_) external onlyOwner {
        if (jackpot_ == address(0)) revert ZeroAddress();
        address oldJackpot = address(jackpot);
        jackpot = ISlvrJackpot(jackpot_);
        emit JackpotUpdated(oldJackpot, jackpot_);
    }
    
    /// @notice Set the pending jackpot contract (upgrades automatically on next hit)
    /// @dev Only owner can set this
    /// @param pendingJackpot_ The new pending jackpot contract address
    function setPendingJackpot(address pendingJackpot_) external onlyOwner {
        if (pendingJackpot_ == address(0)) revert ZeroAddress();
        pendingJackpot = ISlvrJackpot(pendingJackpot_);
        emit PendingJackpotSet(pendingJackpot_);
    }
    
    /// @notice Force upgrade to pending jackpot immediately (emergency/override)
    /// @dev Only owner can call this
    /// @dev Bypasses the automatic upgrade-on-hit mechanism
    /// @dev Useful if there's a contract issue or urgent upgrade needed
    function forceUpgradeJackpot() external onlyOwner {
        if (address(pendingJackpot) == address(0)) revert NoPendingJackpot();
        address oldJackpot = address(jackpot);
        jackpot = pendingJackpot;
        pendingJackpot = ISlvrJackpot(address(0)); // Clear pending
        emit JackpotUpgraded(oldJackpot, address(jackpot));
    }

    /// @notice Checkpoint a miner to update their refined rewards based on index delta
    /// @dev This implements ORE-style lazy settlement: miners earn refined SLVR based on
    ///      how much the global index has increased since their last checkpoint
    /// @param account The miner account to checkpoint
    function checkpoint(address account) external {
        if (!hasAccount[account]) revert NoAccount();
        _checkpoint(account);
    }

    /// @notice Internal checkpoint function that updates miner's refined rewards
    /// @dev Matches ORE's update_rewards exactly
    function _checkpoint(address account) private {
        MinerState storage state = minerState[account];
        (uint256 refinedDelta, uint256 newTotalRefined) = ClaimLib.calculateCheckpointDelta(
            state.rewardsSlvr,
            minerIndex,
            state.indexSnapshot
        );
        if (refinedDelta > 0) {
            state.refinedAccrued += refinedDelta;
            totalRefined += newTotalRefined;
        }
        state.indexSnapshot = minerIndex;
        emit AccountCheckpointed(account, state.refinedAccrued, state.rewardsSlvr, state.indexSnapshot);
    }

    /// @notice Core claim logic shared by all claim functions
    /// @param user The user address claiming
    /// @param roundId The round ID to claim from
    /// @param bypassFee If true, skip the 10% refining fee on unrefined SLVR (for permanent lock claims only)
    /// @return r ClaimResult struct with all claim data
    function _claimCore(address user, uint256 roundId, bool bypassFee) internal returns (ClaimResult memory r) {
        RoundLib.Round storage round = rounds[roundId];
        if (!round.resolved) revert NotResolved();
        uint8 s = round.winningSquare;
        r.userBet = betOf[roundId][s][user];
        if (r.userBet == 0 || hasClaimed[roundId][user]) revert BadClaim();

        MinerState storage state = minerState[user];
        if (state.rewardsSlvr > 0) _checkpoint(user);

        r.slvrReward = _addUserRewardToTotalUnclaimed(user, roundId, r.userBet);
        if (r.slvrReward == 0) {
            r.slvrReward = _calculateSlvrRewardForUser(round, roundId, r.userBet, user);
            if (r.slvrReward > 0 && state.rewardsSlvr < r.slvrReward) revert RewardNotFound();
        }

        betOf[roundId][s][user] = 0;
        hasClaimed[roundId][user] = true;
        r.nativeOut = MathLib.calculatePayout(r.userBet, round.payoutMulWad);
        r.refinedBefore = state.refinedAccrued;
        (r.totalPayout, r.refiningFee) = _processClaimWithRefining(user, r.slvrReward, bypassFee);
        r.winnerTotal = round.winnerTotal;
        r.jackpotHit = round.jackpotHit;
    }

    /// @notice Unified claim function covering all claim variants
    /// @dev Handles: user vs delegate, native/SLVR recipients, bypassFee, ethOnly
    /// @param params Claim parameters struct
    function claimAdvanced(ISlvrGridLottery.ClaimParams memory params) public nonReentrant whenNotPaused {
        if (params.user == address(0)) revert ZeroAddress();
        _validateClaimAuthorization(params.user);
        
        if (params.ethOnly) {
            // Route native to recipientNative (defaulting to the user) so a delegate — e.g. the
            // auto-commit contract — can pull the ETH back into the plan to recycle, while the SLVR
            // stays unrefined in miner state. Matches the recipientNative semantics of the full path.
            address recipientNativeEth = params.recipientNative == address(0) ? params.user : params.recipientNative;
            _claimEthOnly(params.user, params.roundId, recipientNativeEth);
            return;
        }

        address recipientNative = params.recipientNative == address(0) ? params.user : params.recipientNative;
        address recipientSlvr = params.recipientSlvr == address(0) ? recipientNative : params.recipientSlvr;
        
        if (params.bypassFee && !authorizedPermanentLockContracts[recipientSlvr]) revert NotAuthorized();
        
        ClaimResult memory r = _claimCore(params.user, params.roundId, params.bypassFee);
        
        if (recipientNative == recipientSlvr) {
            _transferRewards(recipientNative, r.nativeOut, r.totalPayout);
        } else {
            if (r.nativeOut > 0 && !FeeDistributionLib.transferNative(payable(recipientNative), r.nativeOut)) revert TransferFailed();
            if (r.totalPayout > 0 && !FeeDistributionLib.transferERC20(SLVR, recipientSlvr, r.totalPayout)) revert TransferFailed();
        }
        
        _handleBribes(params.roundId, params.user, r.userBet, r.winnerTotal, r.jackpotHit);
        emit Claimed(params.roundId, params.user, r.nativeOut, r.slvrReward, r.refinedBefore, r.refiningFee);
    }

    /// @notice Legacy claim function for backward compatibility
    function claim(uint256 roundId) external {
        ISlvrGridLottery.ClaimParams memory params;
        params.user = msg.sender;
        params.roundId = roundId;
        claimAdvanced(params);
    }

    /// @notice Validate claim authorization (user or approved delegate)
    function _validateClaimAuthorization(address user) private view {
        if (msg.sender != user) {
            if (!delegates[user][msg.sender]) revert NotAuthorized();
        }
    }

    function _transferRewards(address to, uint256 nativeOut, uint256 slvrOut) private {
        if (nativeOut > 0 && !FeeDistributionLib.transferNative(payable(to), nativeOut)) revert TransferFailed();
        if (slvrOut > 0 && !FeeDistributionLib.transferERC20(SLVR, to, slvrOut)) revert TransferFailed();
    }

    function _handleBribes(uint256 roundId, address user, uint256 userBet, uint256 winnerTotal, bool jackpotHit) private {
        if (jackpotHit) _distributeBribesToWinner(roundId, user, userBet, winnerTotal);
    }

    /// @notice Distribute bribes pro-rata to a winner based on their bet amount
    /// @dev Only called when jackpot hit and winner is claiming
    /// @dev Uses the jackpot contract that was active when the round resolved (stored in roundJackpot)
    ///      This allows claims to work even after the lottery upgrades to a new jackpot contract
    /// @param roundId The round ID where jackpot hit
    /// @param winner The winner address claiming rewards
    /// @param userBet The winner's bet amount on the winning square
    /// @param winnerTotal The total bet amount on the winning square
    function _distributeBribesToWinner(uint256 roundId, address winner, uint256 userBet, uint256 winnerTotal) private {
        address roundJackpotAddr = roundJackpot[roundId];
        if (roundJackpotAddr == address(0)) {
            roundJackpotAddr = address(jackpot);
        }
        if (roundJackpotAddr != address(0)) {
            ISlvrJackpot(roundJackpotAddr).distributeBribesToWinner(roundId, winner, userBet, winnerTotal);
        }
    }

    /// @notice Calculate SLVR reward for a specific user
    function _calculateSlvrRewardForUser(RoundLib.Round storage r, uint256, /* roundId */ uint256 userBet, address user)
        private
        view
        returns (uint256)
    {
        return ClaimLib.calculateSlvrReward(
            r.slvrMulWad,
            userBet,
            r.singleMinerRound,
            r.singleMinerWinner,
            user,
            r.slvrForWinners
        );
    }

    /// @notice Process claim with ORE-style refining fee
    /// @dev Matches ORE's claim_ore exactly
    /// @param account The account claiming rewards
    /// @param slvrReward The SLVR reward amount for the current round being claimed (unrefined SLVR)
    /// @param bypassFee If true and slvrReward > 0, skip the 10% refining fee on unrefined SLVR (for permanent lock claims only)
    function _processClaimWithRefining(address account, uint256 slvrReward, bool bypassFee) private returns (uint256, uint256) {
        MinerState storage state = minerState[account];
        uint256 refinedAccrued = state.refinedAccrued;
        if (slvrReward > 0) {
            state.rewardsSlvr -= slvrReward;
            totalUnclaimed -= slvrReward;
        }
        if (refinedAccrued > 0) {
            state.refinedAccrued = 0;
            totalRefined -= refinedAccrued;
        }
        bool shouldBypassFee = bypassFee && slvrReward > 0;
        (uint256 refiningFee, uint256 indexIncrement) = ClaimLib.calculateRefiningFee(slvrReward, shouldBypassFee, totalUnclaimed, REFINING_FEE_BPS);
        if (refiningFee > 0) {
            minerIndex += indexIncrement;
            totalRefined += refiningFee;
            emit MinerIndexUpdated(minerIndex, totalUnclaimed, totalRefined);
            emit RefiningFeeApplied(account, slvrReward, refiningFee, minerIndex, totalUnclaimed);
        }
        state.indexSnapshot = minerIndex;
        return (ClaimLib.calculateTotalPayout(slvrReward, refinedAccrued, refiningFee), refiningFee);
    }

    /// @notice Internal function for ETH-only claims
    function _claimEthOnly(address user, uint256 roundId, address recipientNative) private {
        RoundLib.Round storage round = rounds[roundId];
        if (!round.resolved) revert NotResolved();
        uint8 s = round.winningSquare;
        uint256 userBet = betOf[roundId][s][user];
        if (userBet == 0 || hasClaimed[roundId][user]) revert BadClaim();

        MinerState storage stateBefore = minerState[user];
        if (stateBefore.rewardsSlvr > 0) _checkpoint(user);

        uint256 slvrReward = _addUserRewardToTotalUnclaimed(user, roundId, userBet);
        if (slvrReward == 0) {
            slvrReward = _calculateSlvrRewardForUser(round, roundId, userBet, user);
            if (slvrReward > 0 && minerState[user].rewardsSlvr < slvrReward) revert RewardNotFound();
        }

        betOf[roundId][s][user] = 0;
        hasClaimed[roundId][user] = true;
        uint256 nativeOut = MathLib.calculatePayout(userBet, round.payoutMulWad);
        if (nativeOut > 0 && !FeeDistributionLib.transferNative(payable(recipientNative), nativeOut)) revert TransferFailed();
        _handleBribes(roundId, user, userBet, round.winnerTotal, round.jackpotHit);
        emit Claimed(roundId, user, nativeOut, 0, 0, 0);
    }

    /// @notice Withdraw unrefined SLVR rewards from miner state
    /// @dev This allows users to withdraw SLVR rewards that were left in state after claimEthOnly()
    ///      Users can withdraw their unrefined SLVR rewards and pay the 10% refining fee
    /// @dev This function processes all unrefined SLVR in the user's state, not just from a specific round
    /// @return totalPayout The total SLVR payout after refining fee (unrefined + refined - fee)
    /// @return refiningFee The refining fee that was charged
    function withdrawUnrefinedSlvr() external nonReentrant whenNotPaused returns (uint256 totalPayout, uint256 refiningFee) {
        MinerState storage state = minerState[msg.sender];
        if (state.rewardsSlvr > 0) _checkpoint(msg.sender);
        uint256 unrefinedSlvr = state.rewardsSlvr;
        if (unrefinedSlvr == 0 && state.refinedAccrued == 0) revert BadAmount();
        (totalPayout, refiningFee) = _processClaimWithRefining(msg.sender, unrefinedSlvr, false);
        if (totalPayout > 0 && !FeeDistributionLib.transferERC20(SLVR, msg.sender, totalPayout)) revert TransferFailed();
        emit Claimed(0, msg.sender, 0, unrefinedSlvr, state.refinedAccrued, refiningFee);
    }


    /// @notice Calculate expected reward for a user in a specific round (view function, no state changes)
    /// @dev This calculates rewards on-the-fly from round data, matching ORE's lazy pattern
    ///      Use this to check expected rewards before they're added to state (which happens on claim)
    /// @param account The user address
    /// @param roundId The round ID
    /// @return expectedReward The expected SLVR reward for this user in this round
    function getExpectedReward(address account, uint256 roundId) external view returns (uint256 expectedReward) {
        RoundLib.Round storage r = rounds[roundId];
        if (!r.resolved) return 0;
        uint256 userBet = betOf[roundId][r.winningSquare][account];
        if (userBet == 0 || hasClaimed[roundId][account]) return 0;
        return ClaimLib.calculateSlvrReward(r.slvrMulWad, userBet, r.singleMinerRound, r.singleMinerWinner, account, r.slvrForWinners);
    }

    // Explicit view functions for internal mappings (replaces auto-generated getters)
    function getRound(uint256 roundId) external view returns (
        uint64 requestedAt,
        bool resolved,
        bytes32 randomnessId,
        uint256 randomnessValue,
        uint8 winningSquare,
        bool jackpotHit,
        bool singleMinerRound,
        address singleMinerWinner,
        uint256 totalWager,
        uint256 fee,
        uint256 winnerTotal,
        uint256 potForWinners,
        uint256 slvrForWinners,
        uint256 payoutMulWad,
        uint256 slvrMulWad,
        uint256 totalUnclaimedSlvr
    ) {
        RoundLib.Round storage r = rounds[roundId];
        return (
            r.requestedAt,
            r.resolved,
            r.randomnessId,
            r.randomnessValue,
            r.winningSquare,
            r.jackpotHit,
            r.singleMinerRound,
            r.singleMinerWinner,
            r.totalWager,
            r.fee,
            r.winnerTotal,
            r.potForWinners,
            r.slvrForWinners,
            r.payoutMulWad,
            r.slvrMulWad,
            r.totalUnclaimedSlvr
        );
    }

    function getTotalOnSquare(uint256 roundId, uint8 square) external view returns (uint256) {
        return totalOnSquare[roundId][square];
    }

    function getBettorsOnSquare(uint256 roundId, uint8 square) external view returns (uint256) {
        return bettorsOnSquare[roundId][square];
    }

    function getUserBet(uint256 roundId, uint8 square, address bettor) external view returns (uint256) {
        return betOf[roundId][square][bettor];
    }

    function getHasClaimed(uint256 roundId, address user) external view returns (bool) {
        return hasClaimed[roundId][user];
    }

    function getHasAccount(address account) external view returns (bool) {
        return hasAccount[account];
    }

    function getMinerState(address account) external view returns (uint256 rewardsSlvr, uint256 refinedAccrued, uint256 indexSnapshot, bool hasAccount_) {
        MinerState storage state = minerState[account];
        return (state.rewardsSlvr, state.refinedAccrued, state.indexSnapshot, hasAccount[account]);
    }

    function getRoundJackpot(uint256 roundId) external view returns (address) {
        return roundJackpot[roundId];
    }

    function getUnclaimedSlvrPerRound(uint256 roundId, address account) external view returns (uint256) {
        return unclaimedSlvrPerRound[roundId][account];
    }

    function getRoundIndexAtResolve(uint256 roundId) external view returns (uint256) {
        return roundIndexAtResolve[roundId];
    }

    function getDelegate(address user, address delegate) external view returns (bool) {
        return delegates[user][delegate];
    }
}
