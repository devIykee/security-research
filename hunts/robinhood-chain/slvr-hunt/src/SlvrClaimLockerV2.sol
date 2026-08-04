// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {ISlvrGridLottery} from "./interfaces/ISlvrGridLottery.sol";
import {ISlvrVoteEscrow} from "./interfaces/ISlvrVoteEscrow.sol";
import {ISlvrClaimLockerV2} from "./interfaces/ISlvrClaimLockerV2.sol";

/// @title SlvrClaimLockerV2
/// @notice The vote-escrow locking hub. Replaces SlvrClaimLocker as the vote
///         escrow's single `authorizedContract`, and serves two paths:
///
///         1. MANUAL — `claimAndLock`/`batchClaimAndLock`, byte-compatible with
///            SlvrClaimLocker's signatures so the UI only changes the address.
///            Callable only by the user themselves (griefing protection: a
///            delegate must never be able to force someone's rewards into a
///            permanent, non-withdrawable lock).
///         2. AUTO — `lockFromClaim`, callable only by owner-authorized locker
///            contracts (SlvrAutoCommitV3). Consent comes from the user having
///            set a lock mode on their own auto-commit plan; the auto-commit
///            contract routes claimed SLVR here and this contract locks it.
///
///         The vote escrow has no registry of a user's TMAX locks (its
///         getMaxLockTokenId only knows permanent locks) and addToMaxLock mints
///         a NEW TMAX NFT on every call — so the auto path tracks its own
///         per-user target NFT (`autoLockTokenId`) and tops it back up to TMAX
///         on every claim instead of minting one NFT per win.
///
/// @dev SLVR amounts are always measured as balance deltas by the callers and
///      passed in explicitly; SLVR never legitimately rests in this contract
///      between transactions. The auto path never reverts for lock-shaped
///      reasons — when a lock is impossible (e.g. the user wants a TMAX lock
///      but holds a permanent one) the refined SLVR falls back to their wallet.
contract SlvrClaimLockerV2 is Ownable, ISlvrClaimLockerV2 {
    using SafeERC20 for IERC20;

    ISlvrGridLottery public immutable LOTTERY;
    ISlvrVoteEscrow public immutable VOTE_ESCROW;
    IERC20 public immutable SLVR;
    /// @dev The vote escrow's TMAX is a compile-time constant there — cached at
    ///      deploy so lock paths don't pay an external call per claim.
    uint256 private immutable TMAX;

    /// @notice Contracts allowed to call lockFromClaim (SlvrAutoCommitV3).
    mapping(address => bool) public authorizedLockers;

    /// @notice The veNFT the auto path adds a user's TMAX locks into. Created on
    ///         first auto-lock; users may point it at an NFT they already own.
    mapping(address => uint256) public autoLockTokenId;

    event ClaimedAndLocked(
        uint256 indexed roundId,
        address indexed user,
        uint256 tokenId,
        bool permanent,
        uint256 duration
    );
    event AutoLocked(address indexed user, uint256 indexed tokenId, uint256 amount, bool permanent);
    /// @notice The auto path could not lock (e.g. TMAX requested but a permanent
    ///         lock exists, or the vote escrow reverted) — the refined SLVR was
    ///         sent to the user's wallet instead.
    event AutoLockFallback(address indexed user, uint256 amount);
    event AuthorizedLockerSet(address indexed locker, bool authorized);
    event AutoLockTargetSet(address indexed user, uint256 indexed tokenId);

    error VoteEscrowNotSet();
    error NotUser();
    error NotOwner();
    error NotAuthorizedLocker();
    error CannotAddToPermanentLock();
    error BadDuration();
    error TransferFailed();
    error InsufficientSlvr();
    error PermanentLockExists();
    error BadTarget();
    error PermanentLockUnavailable();

    constructor(address _lottery, address _voteEscrow, address _slvr, address _owner) Ownable(_owner) {
        LOTTERY = ISlvrGridLottery(_lottery);
        VOTE_ESCROW = ISlvrVoteEscrow(_voteEscrow);
        SLVR = IERC20(_slvr);
        TMAX = ISlvrVoteEscrow(_voteEscrow).TMAX();
    }

    /// @inheritdoc ISlvrClaimLockerV2
    function canAutoLock(address caller) external view returns (bool) {
        return authorizedLockers[caller] && VOTE_ESCROW.authorizedContract() == address(this);
    }

    /// @inheritdoc ISlvrClaimLockerV2
    function maxLockAvailable(address user) external view returns (bool) {
        if (VOTE_ESCROW.getPermanentLockTokenId(user) == 0) return true;
        uint256 target = autoLockTokenId[user];
        return target != 0 && _usableAutoTarget(user, target);
    }

    /// @notice Authorize/deauthorize a contract for the auto lock path.
    function setAuthorizedLocker(address locker, bool authorized) external onlyOwner {
        authorizedLockers[locker] = authorized;
        emit AuthorizedLockerSet(locker, authorized);
    }

    /// @notice Point your auto-lock at a veNFT you already own (0 clears — the
    ///         next auto-lock creates a fresh TMAX lock). The target must be a
    ///         non-permanent lock you own; it is re-validated at lock time.
    function setAutoLockTarget(uint256 tokenId) external {
        if (tokenId != 0) {
            if (!_usableAutoTarget(msg.sender, tokenId)) revert BadTarget();
        }
        autoLockTokenId[msg.sender] = tokenId;
        emit AutoLockTargetSet(msg.sender, tokenId);
    }

    // ---------------------------------------------------------------------
    // AUTO PATH — called by SlvrAutoCommitV3 after a delegate claim delivered
    // refined SLVR to this contract.
    // ---------------------------------------------------------------------

    /// @inheritdoc ISlvrClaimLockerV2
    function lockFromClaim(address user, uint256 amount, bool permanent)
        external
        returns (uint256 tokenId)
    {
        if (!authorizedLockers[msg.sender]) revert NotAuthorizedLocker();
        if (amount == 0) return 0;
        // The claim that just executed must have delivered the SLVR here.
        if (SLVR.balanceOf(address(this)) < amount) revert InsufficientSlvr();

        if (permanent) {
            // addToMaxLock(permanent=true) creates the user's single permanent
            // lock or adds to it — no revert paths beyond genuine failures.
            //
            // NO wallet fallback here, deliberately: a permanent-mode claim was
            // taken with the refining fee BYPASSED on the promise the SLVR gets
            // burned. Falling back to a transfer would hand out fee-free liquid
            // SLVR (a refining-fee evasion during any mis-wired window), so a
            // lock failure reverts instead — the caller (SlvrAutoCommitV3)
            // pre-checks canAutoLock/authorizedPermanentLockContracts and takes
            // the ETH-only claim path when locking isn't operational, making
            // this revert unreachable outside truly exceptional states.
            SLVR.forceApprove(address(VOTE_ESCROW), amount);
            try VOTE_ESCROW.addToMaxLock(user, amount, true) returns (uint256 id) {
                emit AutoLocked(user, id, amount, true);
                return id;
            } catch {
                revert PermanentLockUnavailable();
            }
        }

        // TMAX mode: reuse the tracked target so wins compound into ONE NFT,
        // re-extending it to full TMAX on every claim.
        uint256 target = autoLockTokenId[user];
        if (target != 0 && _usableAutoTarget(user, target)) {
            SLVR.forceApprove(address(VOTE_ESCROW), amount);
            try VOTE_ESCROW.increaseLockFor(target, amount, TMAX) {
                emit AutoLocked(user, target, amount, false);
                return target;
            } catch {
                SLVR.forceApprove(address(VOTE_ESCROW), 0);
                return _fallbackToWallet(user, amount);
            }
        }

        // No usable target. A permanent lock blocks creating TMAX locks in the
        // vote escrow, and silently burning into the permanent lock instead
        // would destroy value the user chose to keep withdrawable — fall back.
        if (VOTE_ESCROW.getPermanentLockTokenId(user) != 0) {
            return _fallbackToWallet(user, amount);
        }

        SLVR.forceApprove(address(VOTE_ESCROW), amount);
        try VOTE_ESCROW.addToMaxLock(user, amount, false) returns (uint256 id) {
            autoLockTokenId[user] = id;
            emit AutoLockTargetSet(user, id);
            emit AutoLocked(user, id, amount, false);
            return id;
        } catch {
            SLVR.forceApprove(address(VOTE_ESCROW), 0);
            return _fallbackToWallet(user, amount);
        }
    }

    /// @dev A target is usable when the token still exists, the user still owns
    ///      it, and it is not permanent (increaseLockFor rejects permanent).
    function _usableAutoTarget(address user, uint256 tokenId) private view returns (bool) {
        try VOTE_ESCROW.ownerOf(tokenId) returns (address o) {
            if (o != user) return false;
        } catch {
            return false; // burned/withdrawn
        }
        return !VOTE_ESCROW.getLock(tokenId).permanent;
    }

    /// @dev Deliver refined SLVR to the user's wallet when locking is impossible.
    function _fallbackToWallet(address user, uint256 amount) private returns (uint256) {
        SLVR.safeTransfer(user, amount);
        emit AutoLockFallback(user, amount);
        return 0;
    }

    // ---------------------------------------------------------------------
    // MANUAL PATH — ported from SlvrClaimLocker (same signatures/semantics),
    // with received SLVR measured as a balance DELTA rather than the whole
    // contract balance, so stray tokens can never be locked into the wrong NFT.
    // ---------------------------------------------------------------------

    /// @notice Claim rewards from a round and lock into a veNFT
    /// @param user The user to claim for (must have approved this contract as delegate)
    /// @param roundId The round ID to claim from
    /// @param permanent If true, create a permanent lock (burn). If false, create a time-based lock.
    /// @param tokenId If > 0, add to existing lock. If 0, create new lock.
    /// @param duration Lock duration in seconds (only used if permanent=false and tokenId=0). Use TMAX for max lock.
    /// @return tokenId_ The token ID of the lock (new or existing)
    function claimAndLock(
        address user,
        uint256 roundId,
        bool permanent,
        uint256 tokenId,
        uint256 duration
    ) external returns (uint256 tokenId_) {
        if (address(VOTE_ESCROW) == address(0)) revert VoteEscrowNotSet();
        // Only the user themselves may route their own rewards into a lock (see
        // contract natspec — permanent locks are non-withdrawable).
        if (msg.sender != user) revert NotUser();

        (uint256 slvrAmount) = _claimToSelf(user, roundId, permanent);

        if (slvrAmount > 0) {
            tokenId_ = _lockSlvr(user, slvrAmount, permanent, tokenId, duration);
        } else {
            tokenId_ = tokenId;
        }

        emit ClaimedAndLocked(roundId, user, tokenId_, permanent, permanent ? 0 : duration);
    }

    /// @notice Batch claim rewards from multiple rounds and lock into a veNFT
    /// @dev See claimAndLock for parameter semantics.
    function batchClaimAndLock(
        address user,
        uint256[] calldata roundIds,
        bool permanent,
        uint256 tokenId,
        uint256 duration
    ) external returns (uint256 tokenId_) {
        if (address(VOTE_ESCROW) == address(0)) revert VoteEscrowNotSet();
        if (msg.sender != user) revert NotUser();

        uint256 currentTokenId = tokenId;

        for (uint256 i = 0; i < roundIds.length; i++) {
            uint256 slvrAmount = _claimToSelf(user, roundIds[i], permanent);
            if (slvrAmount > 0) {
                uint256 resultTokenId = _lockSlvr(user, slvrAmount, permanent, currentTokenId, duration);
                if (resultTokenId > 0) {
                    currentTokenId = resultTokenId;
                }
            }
            emit ClaimedAndLocked(roundIds[i], user, currentTokenId, permanent, permanent ? 0 : duration);
        }

        tokenId_ = currentTokenId;
    }

    /// @dev Claim one round with this contract as both recipients; forward the
    ///      native winnings to the user and return the SLVR received (delta).
    ///      Fee bypass only applies to permanent locks (lottery-enforced).
    function _claimToSelf(address user, uint256 roundId, bool permanent) private returns (uint256 slvrAmount) {
        uint256 slvrBefore = SLVR.balanceOf(address(this));

        ISlvrGridLottery.ClaimParams memory params;
        params.user = user;
        params.roundId = roundId;
        params.recipientNative = address(this);
        params.recipientSlvr = address(this);
        params.bypassFee = permanent;
        params.ethOnly = false;
        LOTTERY.claimAdvanced(params);

        slvrAmount = SLVR.balanceOf(address(this)) - slvrBefore;

        uint256 nativeBalance = address(this).balance;
        if (nativeBalance > 0) {
            (bool ok,) = payable(user).call{value: nativeBalance}("");
            if (!ok) revert TransferFailed();
        }
    }

    /// @dev Lock SLVR into a veNFT — ported unchanged from SlvrClaimLocker.
    function _lockSlvr(
        address user,
        uint256 amount,
        bool permanent,
        uint256 tokenId,
        uint256 duration
    ) internal returns (uint256 tokenId_) {
        uint256 tmax = TMAX;

        if (permanent) {
            uint256 existingPermanentLockId = VOTE_ESCROW.getPermanentLockTokenId(user);
            if (existingPermanentLockId > 0) {
                tokenId = existingPermanentLockId;
                duration = 0;
            }
        } else {
            uint256 existingMaxLockId = VOTE_ESCROW.getMaxLockTokenId(user);
            if (existingMaxLockId > 0) {
                ISlvrVoteEscrow.Lock memory existingLock = VOTE_ESCROW.getLock(existingMaxLockId);
                if (existingLock.permanent) {
                    revert PermanentLockExists();
                }
                if (tokenId == 0 && duration == tmax) {
                    tokenId = existingMaxLockId;
                    duration = 0;
                } else if (tokenId > 0 && tokenId != existingMaxLockId && duration == tmax) {
                    tokenId = existingMaxLockId;
                    duration = 0;
                } else if (tokenId == existingMaxLockId && duration == tmax) {
                    duration = 0;
                }
            }
        }

        SLVR.forceApprove(address(VOTE_ESCROW), amount);

        if (permanent || duration == tmax) {
            tokenId_ = VOTE_ESCROW.addToMaxLock(user, amount, permanent);
        } else if (tokenId > 0) {
            if (VOTE_ESCROW.ownerOf(tokenId) != user) revert NotOwner();
            ISlvrVoteEscrow.Lock memory existingLock = VOTE_ESCROW.getLock(tokenId);
            if (existingLock.permanent) revert CannotAddToPermanentLock();
            VOTE_ESCROW.increaseLockFor(tokenId, amount, 0);
            tokenId_ = tokenId;
        } else {
            if (duration == 0 || duration > tmax) revert BadDuration();
            tokenId_ = VOTE_ESCROW.createLockFor(user, amount, duration);
        }
    }

    /// @notice Recover tokens or ETH stranded here by a failed downstream call.
    ///         No user funds legitimately rest in this contract between
    ///         transactions (both paths settle within one tx), so this can only
    ///         ever touch strays.
    function sweep(address token, address payable to) external onlyOwner {
        if (token == address(0)) {
            (bool ok,) = to.call{value: address(this).balance}("");
            if (!ok) revert TransferFailed();
        } else {
            IERC20(token).safeTransfer(to, IERC20(token).balanceOf(address(this)));
        }
    }

    // Receive native claim proceeds mid-claim.
    receive() external payable {}
}
