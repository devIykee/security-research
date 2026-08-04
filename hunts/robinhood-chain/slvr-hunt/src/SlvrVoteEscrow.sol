// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {IERC5805} from "@openzeppelin/contracts/interfaces/IERC5805.sol";
import {ISlvrVoteEscrowMetadata} from "./interfaces/ISlvrVoteEscrowMetadata.sol";
import {ISlvrVoteEscrowStaking} from "./interfaces/ISlvrVoteEscrowStaking.sol";
import {VoteCheckpointLib} from "./libraries/VoteCheckpointLib.sol";

/// @title SlvrVoteEscrow
/// @notice Vote escrow NFT contract for locked SLVR staking with time-based voting power and reward multipliers
/// @dev Implements an ERC-5805 voting surface (timestamp clock) with checkpointed history so an
///      on-chain Governor can read past voting power (`getPastVotes` / `getPastTotalSupply`).
///      Checkpoints reproduce the decaying `getVotingPower` curve exactly, except that a lock's
///      governance power ends at the last day boundary at or before its `lockEnd` (its final
///      sub-day tail — where power is near zero anyway — carries no votes). The NFT is soulbound,
///      so votes are fixed to the holder: `delegates(a) == a` and delegation elsewhere reverts.
contract SlvrVoteEscrow is ERC721, Ownable2Step, ReentrancyGuard, IERC5805 {
    using VoteCheckpointLib for VoteCheckpointLib.History;
    using SafeERC20 for IERC20;
    uint256 public constant TMAX = 4 * 30 days; // 4 months max lock
    uint256 public constant MMAX = 2.5e18; // 2.5x max multiplier for normal locks
    uint256 public constant P = 2.0e18; // Permanent factor (multiplier = 1 + (MMAX-1)*P/1e18 = 4.0x)

    // Custom errors
    error ZeroAddress();
    error ZeroAmount();
    error ZeroReceived();
    error InvalidDuration();
    error DurationExceedsMax();
    error LockEndExceedsMax();
    error NotAuthorized();
    error NotOwner();
    error TokenDoesNotExist();
    error PermanentLockExists();
    error LockTypeMismatch();
    error PermanentLock();
    error NotPermanentLock();
    error AlreadyPermanent();
    error LockEmpty();
    error LockNotExpired();
    error TokenNotInList();
    error NonTransferable();
    error SoulboundNFT();
    error ERC5805FutureLookup(uint256 timepoint, uint48 clock_);
    error DelegationNotSupported();

    IERC20 public immutable SLVR;

    /// @notice The metadata contract address (upgradeable)
    ISlvrVoteEscrowMetadata public metadataContract;

    /// @notice The staking contract address (optional, for cleanup on burn)
    ISlvrVoteEscrowStaking public stakingContract;

    uint256 private _tokenIdCounter;

    struct Lock {
        uint256 amount; // Locked SLVR amount
        uint256 lockStart; // Lock start timestamp
        uint256 lockEnd; // Lock expiration timestamp (0 for permanent)
        bool permanent; // True if permanent lock (non-withdrawable)
        bool isMaxTime; // True if this is a TMAX duration lock (lockEnd - lockStart == TMAX)
    }

    mapping(uint256 => Lock) public locks;
    mapping(address => uint256[]) public userTokens; // User's token IDs
    mapping(uint256 => uint256) public tokenIndexInUserList; // tokenId => index+1 (0 means not in list)

    // Explicit tracking of permanent locks (only one per user allowed)
    mapping(address => uint256) public userPermanentLockId; // User's permanent lock token ID (0 if none)

    // Authorized contract that can create locks on behalf of users (e.g., lottery)
    address public authorizedContract;

    // Governance vote checkpoints (ERC-5805): per-account and global (bias, slope) histories,
    // updated on every lock mutation so past voting power is exactly reproducible.
    mapping(address => VoteCheckpointLib.History) private _accountVotes;
    VoteCheckpointLib.History private _totalVotes;

    event LockCreated(uint256 indexed tokenId, address indexed user, uint256 amount, uint256 duration, bool permanent);
    event LockIncreased(uint256 indexed tokenId, uint256 addedAmount, uint256 newLockEnd);
    event LockExtended(uint256 indexed tokenId, uint256 newLockEnd);
    event LockWithdrawn(uint256 indexed tokenId, address indexed user, uint256 amount);
    event LockConvertedToPermanent(uint256 indexed tokenId, uint256 indexed permanentTokenId, uint256 amount);
    event MetadataContractUpdated(address indexed oldContract, address indexed newContract);
    event StakingContractUpdated(address indexed oldContract, address indexed newContract);

    constructor(address slvr_, address owner_) ERC721("Slvr Vote Escrow", "veSLVR") Ownable(owner_) {
        if (slvr_ == address(0)) revert ZeroAddress();
        SLVR = IERC20(slvr_);
        _tokenIdCounter = 1; // Start at 1 so tokenId 0 can be used as "no token" sentinel value
    }

    /// @notice Internal helper to measure actual received SLVR amount (handles fee-on-transfer)
    /// @param amount Expected amount to receive
    /// @return received Actual amount received
    function _measureReceived(uint256 amount) private returns (uint256 received) {
        uint256 beforeBal = SLVR.balanceOf(address(this));
        SLVR.safeTransferFrom(msg.sender, address(this), amount);
        uint256 afterBal = SLVR.balanceOf(address(this));
        received = afterBal - beforeBal;
        if (received == 0) revert ZeroReceived();
    }

    /// @notice Create a normal time-based lock
    /// @param amount Amount of SLVR to lock
    /// @param duration Lock duration in seconds (must be <= TMAX, except for permanent locks)
    function createLock(uint256 amount, uint256 duration) external nonReentrant returns (uint256 tokenId) {
        if (amount == 0) revert ZeroAmount();
        if (duration == 0 || duration > TMAX) revert InvalidDuration();

        // Users can create multiple TMAX locks - no restriction here

        uint256 received = _measureReceived(amount);

        tokenId = _tokenIdCounter++;
        uint256 lockEnd = block.timestamp + duration;
        
        // Explicit safety check: ensure lockEnd never exceeds TMAX from now (except for permanent locks)
        if (lockEnd > block.timestamp + TMAX) revert LockEndExceedsMax();

        locks[tokenId] = Lock({amount: received, lockStart: block.timestamp, lockEnd: lockEnd, permanent: false, isMaxTime: duration == TMAX});
        _votesCreated(msg.sender, tokenId);

        _addTokenToUser(msg.sender, tokenId);
        _mint(msg.sender, tokenId);

        // Optionally stake in staking contract if set
        _autoStakeIfEnabled(tokenId);

        emit LockCreated(tokenId, msg.sender, received, duration, false);
    }

    /// @notice Internal helper to measure actual received SLVR amount from authorized contract (handles fee-on-transfer)
    /// @param amount Expected amount to receive
    /// @return received Actual amount received
    function _measureReceivedFrom(address from, uint256 amount) private returns (uint256 received) {
        uint256 beforeBal = SLVR.balanceOf(address(this));
        SLVR.safeTransferFrom(from, address(this), amount);
        uint256 afterBal = SLVR.balanceOf(address(this));
        received = afterBal - beforeBal;
        if (received == 0) revert ZeroReceived();
    }

    /// @notice Create a lock on behalf of a user (only authorized contract)
    /// @param user The user to create the lock for
    /// @param amount Amount of SLVR to lock
    /// @param duration Lock duration in seconds (must be <= TMAX, except for permanent locks)
    function createLockFor(address user, uint256 amount, uint256 duration) external nonReentrant returns (uint256 tokenId) {
        if (msg.sender != authorizedContract) revert NotAuthorized();
        if (user == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (duration == 0 || duration > TMAX) revert InvalidDuration();

        // Users can create multiple TMAX locks - no restriction here

        uint256 received = _measureReceivedFrom(msg.sender, amount);

        tokenId = _tokenIdCounter++;
        uint256 lockEnd = block.timestamp + duration;
        
        // Explicit safety check: ensure lockEnd never exceeds TMAX from now (except for permanent locks)
        if (lockEnd > block.timestamp + TMAX) revert LockEndExceedsMax();

        locks[tokenId] = Lock({amount: received, lockStart: block.timestamp, lockEnd: lockEnd, permanent: false, isMaxTime: duration == TMAX});
        _votesCreated(user, tokenId);

        _addTokenToUser(user, tokenId);
        _mint(user, tokenId);

        // Optionally stake in staking contract if set
        _autoStakeIfEnabled(tokenId);

        emit LockCreated(tokenId, user, received, duration, false);
    }

    /// @notice Create a permanent lock on behalf of a user (only authorized contract)
    /// @param user The user to create the lock for
    /// @param amount Amount of SLVR to permanently lock and burn
    function createPermanentLockFor(address user, uint256 amount) external nonReentrant returns (uint256 tokenId) {
        if (msg.sender != authorizedContract) revert NotAuthorized();
        if (user == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        // Prevent creating multiple permanent locks - user can only have one permanent lock
        if (userPermanentLockId[user] != 0) revert PermanentLockExists();

        uint256 received = _measureReceivedFrom(msg.sender, amount);

        // Actually burn the tokens to reduce total supply (burn received amount, not expected)
        ERC20Burnable(address(SLVR)).burn(received);

        tokenId = _tokenIdCounter++;

        locks[tokenId] = Lock({amount: received, lockStart: block.timestamp, lockEnd: 0, permanent: true, isMaxTime: false});
        _votesCreated(user, tokenId);

        _addTokenToUser(user, tokenId);
        _mint(user, tokenId);
        userPermanentLockId[user] = tokenId;

        // Optionally stake in staking contract if set
        _autoStakeIfEnabled(tokenId);

        emit LockCreated(tokenId, user, received, 0, true);
    }

    /// @notice Add to max lock or create one if it doesn't exist (only authorized contract)
    /// @param user The user to add to/create max lock for
    /// @param amount Amount of SLVR to lock
    /// @param permanent If true, create/add to permanent lock (burn). If false, create/add to TMAX lock.
    /// @return tokenId The token ID of the max lock (existing or newly created)
    function addToMaxLock(address user, uint256 amount, bool permanent) external nonReentrant returns (uint256 tokenId) {
        if (msg.sender != authorizedContract) revert NotAuthorized();
        if (user == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        if (permanent) {
            // For permanent locks, check for existing permanent lock only
            tokenId = userPermanentLockId[user];
        } else {
            // For TMAX locks, if user has permanent lock, they can't add to TMAX lock
            if (userPermanentLockId[user] != 0) revert PermanentLockExists();
            // Users can have multiple TMAX locks, so we'll create a new one each time
            tokenId = 0;
        }

        if (tokenId == 0) {
            // User doesn't have the requested lock type, create one
            if (permanent) {
                uint256 received = _measureReceivedFrom(msg.sender, amount);
                ERC20Burnable(address(SLVR)).burn(received);
                tokenId = _tokenIdCounter++;
                locks[tokenId] = Lock({amount: received, lockStart: block.timestamp, lockEnd: 0, permanent: true, isMaxTime: false});
                _votesCreated(user, tokenId);
                _addTokenToUser(user, tokenId);
                _mint(user, tokenId);
                userPermanentLockId[user] = tokenId;
                // Optionally stake in staking contract if set
                _autoStakeIfEnabled(tokenId);
                emit LockCreated(tokenId, user, received, 0, true);
            } else {
                uint256 received = _measureReceivedFrom(msg.sender, amount);
                tokenId = _tokenIdCounter++;
                locks[tokenId] = Lock({amount: received, lockStart: block.timestamp, lockEnd: block.timestamp + TMAX, permanent: false, isMaxTime: true});
                _votesCreated(user, tokenId);
                _addTokenToUser(user, tokenId);
                _mint(user, tokenId);
                // Optionally stake in staking contract if set
                _autoStakeIfEnabled(tokenId);
                emit LockCreated(tokenId, user, received, TMAX, false);
            }
        } else {
            // User has existing max lock, add to it
            Lock storage lock = locks[tokenId];
            if (lock.permanent != permanent) revert LockTypeMismatch();
            Lock memory prev = lock;

            uint256 received = _measureReceivedFrom(msg.sender, amount);
            
            if (permanent) {
                ERC20Burnable(address(SLVR)).burn(received);
            }
            
            lock.amount += received;
            
            if (!permanent) {
                // Extend TMAX lock to full duration from now
                lock.lockEnd = block.timestamp + TMAX;
                lock.lockStart = block.timestamp;
                lock.isMaxTime = true;
            }

            _moveVotes(user, prev, lock);

            // Weight increased (amount up, TMAX re-maxed) — checkpoint so the staking contract tracks
            // the new weight instead of leaving the holder earning on a stale, lower balance.
            _autoCheckpointIfEnabled(tokenId);

            emit LockIncreased(tokenId, received, lock.lockEnd);
        }

        return tokenId;
    }

    /// @notice Set authorized contract address (owner only)
    /// @param contract_ The contract address that can create locks on behalf of users
    function setAuthorizedContract(address contract_) external onlyOwner {
        authorizedContract = contract_;
    }

    /// @notice Create a permanent lock (non-withdrawable burn)
    /// @param amount Amount of SLVR to permanently lock and burn
    function createPermanentLock(uint256 amount) external nonReentrant returns (uint256 tokenId) {
        if (amount == 0) revert ZeroAmount();

        // Prevent creating multiple permanent locks - user can only have one permanent lock
        if (userPermanentLockId[msg.sender] != 0) revert PermanentLockExists();

        uint256 received = _measureReceived(amount);

        // Actually burn the tokens to reduce total supply (burn received amount, not expected)
        ERC20Burnable(address(SLVR)).burn(received);

        tokenId = _tokenIdCounter++;

        locks[tokenId] = Lock({amount: received, lockStart: block.timestamp, lockEnd: 0, permanent: true, isMaxTime: false});
        _votesCreated(msg.sender, tokenId);

        _addTokenToUser(msg.sender, tokenId);
        _mint(msg.sender, tokenId);
        userPermanentLockId[msg.sender] = tokenId;

        // Optionally stake in staking contract if set
        _autoStakeIfEnabled(tokenId);

        emit LockCreated(tokenId, msg.sender, received, 0, true);
    }

    /// @notice Increase lock amount and optionally extend duration
    /// @param tokenId Token ID of the lock
    /// @param amount Additional SLVR to add (must be > 0)
    /// @param newDuration New lock duration:
    ///                   - 0 = lock new tokens for remainder of existing lock (no extension)
    ///                   - TMAX = extend to max duration (4 months) from now
    ///                   - Any other value = add that duration to current expiration time
    /// @dev You can always increase the amount in a lock, and optionally extend the duration
    /// @dev When newDuration == 0, new tokens are locked until the existing lock's expiration
    /// @dev When extending, if newDuration == TMAX, the lock is extended to max duration from now
    /// @dev Otherwise, the duration is added to the current expiration time
    /// @dev When newDuration > 0, this resets lockStart to block.timestamp, which changes
    ///      the lock duration and causes staking weight to "snap" to a new value. The staking
    ///      contract handles this via checkpointing.
    function increaseLock(uint256 tokenId, uint256 amount, uint256 newDuration) external nonReentrant {
        if (ownerOf(tokenId) != msg.sender) revert NotOwner();
        if (amount == 0) revert ZeroAmount();

        Lock storage lock = locks[tokenId];
        if (lock.permanent) revert PermanentLock();
        Lock memory prev = lock;

        uint256 received = _measureReceived(amount);

        lock.amount += received;

        if (newDuration > 0) {
            require(newDuration <= TMAX, "duration must be <= TMAX");
            uint256 proposedEnd;
            if (newDuration == TMAX) {
                // Extend to max duration from now (reset to full 4 months)
                proposedEnd = block.timestamp + TMAX;
            } else {
                // Add duration to current expiration time
                uint256 currentEnd = lock.lockEnd > block.timestamp ? lock.lockEnd : block.timestamp;
                proposedEnd = currentEnd + newDuration;
            }
            // Explicit safety check: ensure lockEnd never exceeds TMAX from now (except for permanent locks)
            require(proposedEnd <= block.timestamp + TMAX, "lockEnd exceeds TMAX");
            
            lock.lockEnd = proposedEnd;
            lock.lockStart = block.timestamp; // Reset start time for new duration
            lock.isMaxTime = (proposedEnd == block.timestamp + TMAX);
        }

        _moveVotes(msg.sender, prev, lock);

        // Optionally checkpoint in staking contract if set (weight may have changed)
        _autoCheckpointIfEnabled(tokenId);

        emit LockIncreased(tokenId, received, lock.lockEnd);
    }

    /// @notice Increase lock amount and optionally extend duration (only authorized contract)
    /// @param tokenId Token ID of the lock
    /// @param amount Additional SLVR to add (must be > 0)
    /// @param newDuration New lock duration (see increaseLock for details)
    function increaseLockFor(uint256 tokenId, uint256 amount, uint256 newDuration) external nonReentrant {
        if (msg.sender != authorizedContract) revert NotAuthorized();
        if (ownerOf(tokenId) == address(0)) revert TokenDoesNotExist();
        if (amount == 0) revert ZeroAmount();

        Lock storage lock = locks[tokenId];
        if (lock.permanent) revert PermanentLock();
        Lock memory prev = lock;

        uint256 received = _measureReceivedFrom(msg.sender, amount);

        lock.amount += received;

        if (newDuration > 0) {
            if (newDuration > TMAX) revert DurationExceedsMax();
            uint256 proposedEnd;
            if (newDuration == TMAX) {
                // Extend to max duration from now (reset to full 4 months)
                proposedEnd = block.timestamp + TMAX;
            } else {
                // Add duration to current expiration time
                uint256 currentEnd = lock.lockEnd > block.timestamp ? lock.lockEnd : block.timestamp;
                proposedEnd = currentEnd + newDuration;
            }
            // Explicit safety check: ensure lockEnd never exceeds TMAX from now (except for permanent locks)
            if (proposedEnd > block.timestamp + TMAX) revert LockEndExceedsMax();
            
            lock.lockEnd = proposedEnd;
            lock.lockStart = block.timestamp; // Reset start time for new duration
            lock.isMaxTime = (proposedEnd == block.timestamp + TMAX);
        }

        _moveVotes(ownerOf(tokenId), prev, lock);

        // Optionally checkpoint in staking contract if set (weight may have changed)
        _autoCheckpointIfEnabled(tokenId);

        emit LockIncreased(tokenId, received, lock.lockEnd);
    }

    /// @notice Increase permanent lock amount by burning additional tokens
    /// @param tokenId Token ID of the permanent lock
    /// @param amount Additional SLVR to permanently lock and burn
    function increasePermanentLock(uint256 tokenId, uint256 amount) external nonReentrant {
        if (ownerOf(tokenId) != msg.sender) revert NotOwner();
        if (amount == 0) revert ZeroAmount();

        Lock storage lock = locks[tokenId];
        if (!lock.permanent) revert NotPermanentLock();
        Lock memory prev = lock;

        uint256 received = _measureReceived(amount);

        // Burn the additional tokens (burn received amount, not expected)
        ERC20Burnable(address(SLVR)).burn(received);

        // Increase the lock amount
        lock.amount += received;

        _moveVotes(msg.sender, prev, lock);

        // Optionally checkpoint in staking contract if set (weight has increased)
        _autoCheckpointIfEnabled(tokenId);

        emit LockIncreased(tokenId, received, 0);
    }

    /// @notice Extend lock duration (relock to reset multiplier)
    /// @param tokenId Token ID of the lock
    /// @param duration New lock duration (must be <= TMAX, except for permanent locks)
    /// @dev Resets lockStart to block.timestamp, which changes the lock duration and
    ///      causes staking weight to "snap" to a new value based on the new duration.
    ///      The staking contract handles this via checkpointing.
    function extendLock(uint256 tokenId, uint256 duration) external nonReentrant {
        if (ownerOf(tokenId) != msg.sender) revert NotOwner();
        if (duration == 0 || duration > TMAX) revert InvalidDuration();

        Lock storage lock = locks[tokenId];
        if (lock.permanent) revert PermanentLock();
        Lock memory prev = lock;

        uint256 proposedEnd;
        if (duration == TMAX) {
            proposedEnd = block.timestamp + TMAX;
        } else {
            uint256 currentEnd = lock.lockEnd > block.timestamp ? lock.lockEnd : block.timestamp;
            proposedEnd = currentEnd + duration;
        }
        // Explicit safety check: ensure lockEnd never exceeds TMAX from now (except for permanent locks)
        if (proposedEnd > block.timestamp + TMAX) revert LockEndExceedsMax();

        lock.lockEnd = proposedEnd;
        lock.lockStart = block.timestamp; // Reset start time
        lock.isMaxTime = (proposedEnd == block.timestamp + TMAX);

        _moveVotes(msg.sender, prev, lock);

        // Optionally checkpoint in staking contract if set (weight may have changed)
        _autoCheckpointIfEnabled(tokenId);

        emit LockExtended(tokenId, lock.lockEnd);
    }

    /// @notice Convert a normal lock to a permanent lock by burning the NFT and depositing tokens to permanent lock
    /// @param tokenId Token ID of the normal lock to convert
    /// @dev Burns the normal lock NFT and transfers its tokens to the user's permanent lock (creates one if needed)
    function convertToPermanentLock(uint256 tokenId) external nonReentrant {
        if (ownerOf(tokenId) != msg.sender) revert NotOwner();

        Lock storage lock = locks[tokenId];
        if (lock.permanent) revert AlreadyPermanent();
        Lock memory prevTimeLock = lock;

        uint256 amount = lock.amount;
        if (amount == 0) revert LockEmpty();

        // Get or create permanent lock
        uint256 permanentTokenId = userPermanentLockId[msg.sender];
        
        if (permanentTokenId == 0) {
            // Create permanent lock
            permanentTokenId = _tokenIdCounter++;
            locks[permanentTokenId] = Lock({
                amount: amount,
                lockStart: block.timestamp,
                lockEnd: 0,
                permanent: true,
                isMaxTime: false
            });
            _votesCreated(msg.sender, permanentTokenId);
            _addTokenToUser(msg.sender, permanentTokenId);
            _mint(msg.sender, permanentTokenId);
            userPermanentLockId[msg.sender] = permanentTokenId;
            // Stake the freshly-minted permanent lock so it earns rewards (mirrors every other
            // lock-creation path); without this a converted permanent lock earns nothing until a
            // manual stake.
            _autoStakeIfEnabled(permanentTokenId);
            emit LockCreated(permanentTokenId, msg.sender, amount, 0, true);
        } else {
            // Add to existing permanent lock
            Lock memory prevPermanent = locks[permanentTokenId];
            locks[permanentTokenId].amount += amount;
            _moveVotes(msg.sender, prevPermanent, locks[permanentTokenId]);
            // Weight increased — checkpoint so the holder earns on the new balance, not a stale one.
            _autoCheckpointIfEnabled(permanentTokenId);
            emit LockIncreased(permanentTokenId, amount, 0);
        }

        // Burn the tokens (permanent lock = burn)
        ERC20Burnable(address(SLVR)).burn(amount);

        // Clean up normal lock (removing its remaining decaying votes)
        _votesRemoved(msg.sender, prevTimeLock);
        delete locks[tokenId];

        // Settle staking rewards to the owner and clean up weight before burning the old normal lock
        // (if staking set), so rewards accrued to it aren't stranded by the burn.
        _settleStakingBeforeBurn(tokenId, msg.sender);

        _burnAndRemove(msg.sender, tokenId);

        emit LockConvertedToPermanent(tokenId, permanentTokenId, amount);
    }

    /// @notice Withdraw after lock expires (only for normal locks)
    /// @param tokenId Token ID of the lock
    function withdraw(uint256 tokenId) external nonReentrant {
        if (ownerOf(tokenId) != msg.sender) revert NotOwner();

        Lock storage lock = locks[tokenId];
        if (lock.permanent) revert PermanentLock();
        if (block.timestamp < lock.lockEnd) revert LockNotExpired();

        uint256 amount = lock.amount;
        // Vote bookkeeping (a no-op for votes: the lock is expired, so its contribution is
        // already zero, and its scheduled decay stop fired in the past).
        _votesRemoved(msg.sender, lock);
        delete locks[tokenId];

        // Settle staking rewards to the owner and clean up weight before burning (if staking set).
        // Without this, rewards accrued to this token are stranded once the NFT is burned.
        _settleStakingBeforeBurn(tokenId, msg.sender);

        _burnAndRemove(msg.sender, tokenId);

        SLVR.safeTransfer(msg.sender, amount);

        emit LockWithdrawn(tokenId, msg.sender, amount);
    }

    /// @notice Get current voting power for a token (decays for normal locks)
    /// @param tokenId Token ID
    /// @return ve Current voting power
    function getVotingPower(uint256 tokenId) public view returns (uint256 ve) {
        Lock memory lock = locks[tokenId];
        if (lock.amount == 0) return 0;
        
        // If lock has expired (and not permanent), voting power is 0
        if (!lock.permanent && block.timestamp >= lock.lockEnd) {
            return 0;
        }
        
        if (lock.permanent) {
            // Permanent locks: voting power = amount * multiplier (constant, no decay)
            uint256 multiplier = getRewardMultiplier(tokenId);
            ve = (lock.amount * multiplier) / 1e18;
        } else {
            // Normal locks: voting power decays linearly based on time remaining
            // Calculate initial multiplier based on original lock duration
            uint256 originalDuration = lock.lockEnd - lock.lockStart;
            // Cap duration at TMAX to prevent multiplier from exceeding MMAX
            if (originalDuration > TMAX) {
                originalDuration = TMAX;
            }
            uint256 timeRemaining = lock.lockEnd > block.timestamp ? lock.lockEnd - block.timestamp : 0;
            
            // Initial multiplier at lock creation (based on original duration, capped at MMAX)
            uint256 initialMultiplier = 1e18 + ((MMAX - 1e18) * originalDuration) / TMAX;
            // Additional safety cap to ensure multiplier never exceeds MMAX
            if (initialMultiplier > MMAX) {
                initialMultiplier = MMAX;
            }
            
            // Voting power decays linearly: ve = amount * initial_multiplier * (time_remaining / original_duration)
            if (originalDuration == 0) return 0;
            ve = (lock.amount * initialMultiplier * timeRemaining) / (1e18 * originalDuration);
        }
    }

    /// @notice Get staking weight for a token (non-decaying, for reward distribution)
    /// @param tokenId Token ID
    /// @return w Staking weight (constant based on lock duration, does not decay over time)
    function getStakingWeight(uint256 tokenId) external view returns (uint256 w) {
        Lock memory lock = locks[tokenId];
        if (lock.amount == 0) return 0;

        // If lock has expired (and not permanent), return 0 weight
        if (!lock.permanent && block.timestamp >= lock.lockEnd) {
            return 0;
        }

        if (lock.permanent) {
            // Permanent locks: 4x multiplier (constant)
            uint256 m = 1e18 + ((MMAX - 1e18) * P) / 1e18;
            return (lock.amount * m) / 1e18;
        }

        // Normal locks: constant weight based on original duration at last reset (no decay)
        uint256 d = lock.lockEnd > lock.lockStart ? (lock.lockEnd - lock.lockStart) : 0;
        if (d > TMAX) d = TMAX;

        uint256 m0 = 1e18 + ((MMAX - 1e18) * d) / TMAX;
        if (m0 > MMAX) m0 = MMAX;

        return (lock.amount * m0) / 1e18;
    }

    /// @notice Get current reward multiplier for a token (decays for normal locks)
    /// @param tokenId Token ID
    /// @return m Current reward multiplier (in 1e18 format, e.g., 1.5e18 = 1.5x)
    function getRewardMultiplier(uint256 tokenId) public view returns (uint256 m) {
        Lock memory lock = locks[tokenId];
        if (lock.amount == 0) return 1e18; // 1x for no lock

        if (lock.permanent) {
            // Permanent lock: m = 1e18 + (MMAX - 1e18) * P / 1e18 = 4.0x
            m = 1e18 + ((MMAX - 1e18) * P) / 1e18;
        } else {
            // Normal lock: m = 1e18 + (MMAX - 1e18) * t / TMAX (decays linearly)
            uint256 t = lock.lockEnd > block.timestamp
                ? (lock.lockEnd - block.timestamp > TMAX ? TMAX : lock.lockEnd - block.timestamp)
                : 0;
            m = 1e18 + ((MMAX - 1e18) * t) / TMAX;
            // Safety cap to ensure multiplier never exceeds MMAX for normal locks
            if (m > MMAX) {
                m = MMAX;
            }
        }
    }

    /// @notice Get total voting power for a user across all their NFTs
    /// @param user User address
    /// @return totalVe Total voting power
    function getTotalVotingPower(address user) external view returns (uint256 totalVe) {
        uint256[] memory tokens = userTokens[user];
        for (uint256 i = 0; i < tokens.length; i++) {
            totalVe += getVotingPower(tokens[i]);
        }
    }

    /// @notice Get user's token IDs
    /// @param user User address
    /// @return Array of token IDs
    function getUserTokens(address user) external view returns (uint256[] memory) {
        return userTokens[user];
    }

    /// @notice Get lock details for a token
    /// @param tokenId Token ID
    /// @return lock Lock struct
    function getLock(uint256 tokenId) external view returns (Lock memory) {
        return locks[tokenId];
    }

    /// @notice Get the token ID of a user's permanent lock, if one exists
    /// @param user User address
    /// @return tokenId Token ID of permanent lock, or 0 if none exists
    function getPermanentLockTokenId(address user) public view returns (uint256 tokenId) {
        return userPermanentLockId[user];
    }

    /// @notice Get the token ID of a user's permanent lock, if one exists
    /// @param user User address
    /// @return tokenId Token ID of permanent lock, or 0 if none exists
    /// @dev Users can have multiple TMAX locks, so this only returns permanent lock
    function getMaxLockTokenId(address user) public view returns (uint256 tokenId) {
        return userPermanentLockId[user];
    }

    /// @notice Override tokenURI to use external metadata contract
    /// @param tokenId The token ID
    /// @return The token URI (JSON metadata)
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        _requireOwned(tokenId);
        
        if (address(metadataContract) == address(0)) {
            // Return empty string if no metadata contract is set
            return "";
        }
        
        return metadataContract.tokenURI(tokenId, address(this));
    }

    /// @notice Set or update the metadata contract address (owner only)
    /// @param _metadataContract The address of the new metadata contract
    function setMetadataContract(address _metadataContract) external onlyOwner {
        address oldContract = address(metadataContract);
        metadataContract = ISlvrVoteEscrowMetadata(_metadataContract);
        emit MetadataContractUpdated(oldContract, _metadataContract);
    }

    /// @notice Set or update the staking contract address (owner only)
    /// @param _stakingContract The address of the staking contract (can be address(0) to disable)
    function setStakingContract(address _stakingContract) external onlyOwner {
        address oldContract = address(stakingContract);
        stakingContract = ISlvrVoteEscrowStaking(_stakingContract);
        emit StakingContractUpdated(oldContract, _stakingContract);
    }

    // ------------------------------------------------------------------
    // Governance votes (ERC-5805 / ERC-6372, timestamp clock)
    // ------------------------------------------------------------------

    /// @notice ERC-6372 clock: timestamps, matching the lock/decay math.
    function clock() public view returns (uint48) {
        return uint48(block.timestamp);
    }

    /// @notice ERC-6372 clock mode descriptor.
    // solhint-disable-next-line func-name-mixedcase
    function CLOCK_MODE() public pure returns (string memory) {
        return "mode=timestamp";
    }

    /// @notice Current governance voting power of `account` (checkpointed; see contract @dev for
    ///         how it relates to getTotalVotingPower).
    function getVotes(address account) public view returns (uint256) {
        return _accountVotes[account].valueAt(block.timestamp);
    }

    /// @notice Governance voting power of `account` at a past `timepoint` (seconds).
    function getPastVotes(address account, uint256 timepoint) public view returns (uint256) {
        uint48 current = clock();
        if (timepoint >= current) revert ERC5805FutureLookup(timepoint, current);
        return _accountVotes[account].valueAt(timepoint);
    }

    /// @notice Total governance voting power at a past `timepoint` (for Governor quorum math).
    /// @dev Includes protocol-held permanent locks (team vesting / growth fund); account for
    ///      that when picking a quorum fraction.
    function getPastTotalSupply(uint256 timepoint) public view returns (uint256) {
        uint48 current = clock();
        if (timepoint >= current) revert ERC5805FutureLookup(timepoint, current);
        return _totalVotes.valueAt(timepoint);
    }

    /// @notice Votes are soulbound to the holder; every account is its own delegate.
    function delegates(address account) public pure returns (address) {
        return account;
    }

    /// @notice Delegation is not supported (soulbound votes). Self-delegation is a no-op so
    ///         tooling that calls delegate(self) to "activate" votes keeps working.
    function delegate(address delegatee) public view {
        if (delegatee != msg.sender) revert DelegationNotSupported();
    }

    /// @notice Delegation by signature is not supported (soulbound votes).
    function delegateBySig(address, uint256, uint256, uint8, bytes32, bytes32) public pure {
        revert DelegationNotSupported();
    }

    /// @dev Governance contribution of a lock at the current time, as (bias, slope, govEnd):
    ///      bias is the power now, slope its per-second decay, govEnd the day-aligned time the
    ///      decay is scheduled to stop. Permanent locks are pure bias (no decay). Mirrors
    ///      getVotingPower exactly, except power is measured to govEnd (lockEnd rounded down to
    ///      a day) so decay stops are schedulable at bucket boundaries.
    function _voteParams(Lock memory lock) private view returns (int256 bias, int256 slope, uint256 govEnd) {
        if (lock.amount == 0) return (0, 0, 0);

        if (lock.permanent) {
            uint256 m = 1e18 + ((MMAX - 1e18) * P) / 1e18;
            return (int256((lock.amount * m) / 1e18), 0, 0);
        }

        if (lock.lockEnd <= block.timestamp) return (0, 0, 0);
        govEnd = (lock.lockEnd / VoteCheckpointLib.BUCKET) * VoteCheckpointLib.BUCKET;
        if (govEnd <= block.timestamp) return (0, 0, 0);

        uint256 duration = lock.lockEnd - lock.lockStart;
        if (duration > TMAX) duration = TMAX;
        if (duration == 0) return (0, 0, 0);
        uint256 m0 = 1e18 + ((MMAX - 1e18) * duration) / TMAX;
        if (m0 > MMAX) m0 = MMAX;

        uint256 s = (lock.amount * m0) / (1e18 * duration); // ve per second
        return (int256(s * (govEnd - block.timestamp)), int256(s), govEnd);
    }

    /// @dev Move an account's checkpointed votes from a lock's old state to its new state.
    ///      Pass a zero-amount Lock for "no lock" (creation/removal).
    function _moveVotes(address account, Lock memory oldLock, Lock memory newLock) private {
        (int256 ob, int256 os, uint256 oe) = _voteParams(oldLock);
        (int256 nb, int256 ns, uint256 ne) = _voteParams(newLock);
        if (ob == nb && os == ns && oe == ne) return; // e.g. bookkeeping on an expired lock
        _accountVotes[account].checkpoint(ob, os, oe, nb, ns, ne);
        _totalVotes.checkpoint(ob, os, oe, nb, ns, ne);
    }

    /// @dev Checkpoint votes for a freshly created lock.
    function _votesCreated(address account, uint256 tokenId) private {
        Lock memory none;
        _moveVotes(account, none, locks[tokenId]);
    }

    /// @dev Checkpoint votes for a removed (withdrawn/converted) lock.
    function _votesRemoved(address account, Lock memory prev) private {
        Lock memory none;
        _moveVotes(account, prev, none);
    }

    /// @notice Override approve to revert (soulbound NFT - non-transferable)
    /// @dev This NFT is soulbound, so approvals are not allowed
    function approve(address, uint256) public pure override {
        revert SoulboundNFT();
    }

    /// @notice Override setApprovalForAll to revert (soulbound NFT - non-transferable)
    /// @dev This NFT is soulbound, so approvals are not allowed
    function setApprovalForAll(address, bool) public pure override {
        revert SoulboundNFT();
    }

    /// @notice Override transfer to prevent transfers (non-transferable NFTs)
    function _update(address to, uint256 tokenId, address auth) internal override returns (address) {
        address from = _ownerOf(tokenId);
        // Allow minting (from == address(0)) and burning (to == address(0))
        // But prevent transfers between users (to != from when from != address(0))
        if (from != address(0) && to != address(0) && to != from) revert NonTransferable();
        
        // Clean up permanent lock tracking if token is being burned
        if (to == address(0) && from != address(0)) {
            if (userPermanentLockId[from] == tokenId) {
                delete userPermanentLockId[from];
            }
        }
        
        return super._update(to, tokenId, auth);
    }


    /// @notice Add token to user's token list with O(1) index tracking
    function _addTokenToUser(address user, uint256 tokenId) private {
        uint256[] storage tokens = userTokens[user];
        uint256 index = tokens.length;
        tokens.push(tokenId);
        // Store index+1 (1-based indexing, 0 means not in list)
        tokenIndexInUserList[tokenId] = index + 1;
    }

    /// @notice Remove token from user's token list using O(1) swap-with-last
    function _removeTokenFromUser(address user, uint256 tokenId) private {
        uint256[] storage tokens = userTokens[user];
        uint256 indexPlusOne = tokenIndexInUserList[tokenId];
        if (indexPlusOne == 0) revert TokenNotInList();
        
        uint256 index = indexPlusOne - 1; // Convert to 0-based index
        uint256 lastIndex = tokens.length - 1;
        
        if (index != lastIndex) {
            // Swap with last element
            uint256 lastTokenId = tokens[lastIndex];
            tokens[index] = lastTokenId;
            // Update the moved token's index
            tokenIndexInUserList[lastTokenId] = index + 1;
        }
        
        // Remove last element
        tokens.pop();
        // Clear the removed token's index (0 means not in list)
        delete tokenIndexInUserList[tokenId];
    }

    /// @notice Internal helper to settle staking rewards and clean up weight before burning (if set)
    /// @dev Calls claimOnBurn, which accrues the token's pending staker rewards, removes its weight,
    ///      and re-keys the rewards to `owner` (pull-based) so they survive the burn. Best-effort
    ///      (try/catch) so a broken staking contract can never block withdrawal of the SLVR principal.
    /// @param tokenId The token ID being burned
    /// @param owner The soon-to-be-former owner to credit any accrued rewards to
    function _settleStakingBeforeBurn(uint256 tokenId, address owner) private {
        if (address(stakingContract) != address(0)) {
            try stakingContract.claimOnBurn(tokenId, owner) {
                // Success - rewards settled to owner, weight cleaned up
            } catch {
                // Best-effort: never block the burn / principal withdrawal on a staking issue.
            }
        }
    }

    /// @notice Internal helper to burn a token and remove it from user's token list
    /// @dev Ensures _removeTokenFromUser is always called when burning to maintain userTokens consistency
    /// @param user The owner of the token
    /// @param tokenId The token ID to burn
    function _burnAndRemove(address user, uint256 tokenId) internal {
        _burn(tokenId);
        _removeTokenFromUser(user, tokenId);
    }

    /// @notice Internal helper to optionally stake a token in the staking contract (if enabled)
    /// @dev Called after minting a new token to automatically stake it
    /// @param tokenId The token ID to stake
    function _autoStakeIfEnabled(uint256 tokenId) private {
        if (address(stakingContract) != address(0)) {
            try stakingContract.stake(tokenId) {
                // Success - token staked
            } catch {
                // Ignore errors - stake() may fail if token already staked or contract issue
                // This is best-effort auto-staking, shouldn't block the mint
            }
        }
    }

    /// @notice Internal helper to optionally checkpoint a token in the staking contract (if enabled)
    /// @dev Called after updating a lock to checkpoint weight changes
    /// @param tokenId The token ID to checkpoint
    function _autoCheckpointIfEnabled(uint256 tokenId) private {
        if (address(stakingContract) != address(0)) {
            try stakingContract.checkpoint(tokenId) {
                // Success - token checkpointed
            } catch {
                // Ignore errors - checkpoint() may fail if token not staked or contract issue
                // This is best-effort auto-checkpointing, shouldn't block the update
            }
        }
    }
}
