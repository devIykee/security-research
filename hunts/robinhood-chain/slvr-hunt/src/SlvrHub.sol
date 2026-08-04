// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {ISlvrHub} from "./interfaces/ISlvrHub.sol";
import {ISlvrGameRegistry} from "./interfaces/ISlvrGameRegistry.sol";
import {ISlvrVoteEscrowStaking} from "./interfaces/ISlvrVoteEscrowStaking.sol";
import {ISlvrJackpot} from "./interfaces/ISlvrJackpot.sol";

/// @dev Minimal view of SlvrToken the hub needs. The hub holds the sole MINTER_ROLE.
interface ISlvrMintable {
    function mint(address to, uint256 amount) external;
    function MAX_SUPPLY() external view returns (uint256);
    function totalSupply() external view returns (uint256);
}

/// @title SlvrHub
/// @notice The protocol core that lets many games plug into shared SLVR tokenomics.
/// @dev Responsibilities:
///      1. Emission governor — holds the sole MINTER_ROLE. SLVR is emitted as one protocol-wide
///         stream (`emissionRatePerSec`) split across Active games by registry weight, so adding
///         a game splits the pie instead of growing it. Per-game token buckets, a max-weight
///         guardrail, and idle-forfeiture keep any one game bounded.
///      2. Circular economy — emission stops at `targetSupply` (a soft cap <= token MAX_SUPPLY);
///         because burns reduce totalSupply(), headroom reopens as SLVR is burned, so emission is
///         perpetual and self-balancing against the burn rate rather than draining to the cap.
///      3. Reward router — fans N games into ONE veNFT staker stream (owning the sequential
///         counter the staking contract requires) and ONE shared jackpot (assigning a global
///         epoch id so per-game round numbers can't collide in the pot).
contract SlvrHub is ISlvrHub, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint16 public constant BPS = 10_000;

    // SLVR inflation allocations applied centrally by the token on every mint (must match
    // SlvrToken: 8% team + 4% growth => a mint of `base` increases totalSupply by base*1.12).
    uint16 public constant TEAM_BPS = 800;
    uint16 public constant GROWTH_BPS = 400;

    ISlvrMintable public immutable SLVR_MINT;
    IERC20 public immutable SLVR;
    ISlvrGameRegistry public immutable REGISTRY;

    // Shared sinks (swappable by governance; their authorized caller is this hub).
    ISlvrVoteEscrowStaking public staking;
    ISlvrJackpot public jackpot;

    // Emission policy (monetary policy — independent of game count).
    uint256 public emissionRatePerSec; // base SLVR/sec across the whole active set
    uint256 public targetSupply; // soft cap; 0 => use token MAX_SUPPLY
    uint256 public maxAccrualSeconds = 1 hours; // idle-forfeiture: cap dt per accrual

    // Per-game emission accounting.
    mapping(uint256 => uint256) public lastAccrual; // gameId => last accrual timestamp
    mapping(uint256 => uint256) public bucket; // gameId => accrued-but-unminted base SLVR

    // Shared staker stream: hub owns the monotonic sequence the staking contract requires.
    uint256 public stakerSeq;
    // Native staker rewards that could not be delivered (staking unset or reverting). Held in the
    // hub, retryable via flushStakers(), so a broken staking sink never bricks round resolution.
    uint256 public pendingStakerRewards;

    // Shared jackpot: hub-assigned global epoch ids prevent cross-game round collisions.
    uint256 public jackpotEpoch;
    mapping(uint256 => uint256) public epochOwner; // globalEpoch => owning gameId

    event EmissionRateChanged(uint256 ratePerSec);
    event TargetSupplyChanged(uint256 targetSupply);
    event MaxAccrualSecondsChanged(uint256 maxAccrualSeconds);
    event StakingChanged(address staking);
    event JackpotChanged(address jackpot);
    event GamePrimed(uint256 indexed gameId, uint256 timestamp);
    event RewardMinted(uint256 indexed gameId, address indexed to, uint256 amount);
    event EmissionSkipped(uint256 indexed gameId, uint256 requested);
    event StakersPaid(uint256 indexed gameId, uint256 seq, uint256 amount);
    event StakersDeferred(uint256 seq, uint256 pendingTotal);
    event Rescued(address indexed token, address indexed to, uint256 amount);
    event JackpotFed(uint256 indexed gameId, uint256 amount);
    event JackpotRolled(uint256 indexed gameId, uint256 indexed globalEpoch, bool hit, uint256 ethBonus, uint256 slvrBonus);

    error NotRegisteredGame();
    error NotActiveGame();
    error NotCoreGame();
    error NoJackpot();
    error NotEpochOwner();
    error BonusTransferFailed();
    error NothingPending();

    constructor(address slvr_, address registry_, address owner_) Ownable(owner_) {
        require(slvr_ != address(0) && registry_ != address(0), "zero addr");
        SLVR_MINT = ISlvrMintable(slvr_);
        SLVR = IERC20(slvr_);
        REGISTRY = ISlvrGameRegistry(registry_);
    }

    /// @dev Accept native bonus routed back from the jackpot on a hit.
    receive() external payable {}

    // ------------------------------------------------------------------
    // Admin
    // ------------------------------------------------------------------

    function setEmissionRate(uint256 ratePerSec) external onlyOwner {
        emissionRatePerSec = ratePerSec;
        emit EmissionRateChanged(ratePerSec);
    }

    /// @notice Set the soft supply cap that makes emission circular. 0 => token MAX_SUPPLY.
    function setTargetSupply(uint256 targetSupply_) external onlyOwner {
        require(targetSupply_ == 0 || targetSupply_ <= SLVR_MINT.MAX_SUPPLY(), "over max");
        targetSupply = targetSupply_;
        emit TargetSupplyChanged(targetSupply_);
    }

    function setMaxAccrualSeconds(uint256 secs) external onlyOwner {
        require(secs > 0, "zero");
        maxAccrualSeconds = secs;
        emit MaxAccrualSecondsChanged(secs);
    }

    function setStaking(address staking_) external onlyOwner {
        staking = ISlvrVoteEscrowStaking(staking_);
        emit StakingChanged(staking_);
    }

    function setJackpot(address jackpot_) external onlyOwner {
        jackpot = ISlvrJackpot(jackpot_);
        emit JackpotChanged(jackpot_);
    }

    /// @notice Start a game's emission clock at now, so its first epoch accrues correctly.
    /// @dev Call at wiring time after activating a game in the registry.
    function primeGame(uint256 gameId) external onlyOwner {
        lastAccrual[gameId] = block.timestamp;
        emit GamePrimed(gameId, block.timestamp);
    }

    // ------------------------------------------------------------------
    // Emission (games call mintReward)
    // ------------------------------------------------------------------

    function mintReward(address to, uint256 requested) external nonReentrant returns (uint256 minted) {
        uint256 gameId = _activeGameId(msg.sender);
        _accrue(gameId);

        uint256 available = bucket[gameId];
        if (available == 0 || requested == 0) {
            emit EmissionSkipped(gameId, requested);
            return 0;
        }

        minted = requested < available ? requested : available;

        // Circular soft cap: only emit while supply (net of burns) is below target.
        uint256 softCap = targetSupply == 0 ? SLVR_MINT.MAX_SUPPLY() : targetSupply;
        uint256 supply = SLVR_MINT.totalSupply();
        if (supply >= softCap) {
            emit EmissionSkipped(gameId, requested);
            return 0;
        }
        // A base mint of `b` raises totalSupply by b*(BPS+TEAM+GROWTH)/BPS. Bound b to the headroom.
        uint256 headroom = softCap - supply;
        uint256 baseThatFits = (headroom * BPS) / (BPS + TEAM_BPS + GROWTH_BPS);
        if (minted > baseThatFits) minted = baseThatFits;
        if (minted == 0) {
            emit EmissionSkipped(gameId, requested);
            return 0;
        }

        bucket[gameId] = available - minted;
        SLVR_MINT.mint(to, minted);
        emit RewardMinted(gameId, to, minted);
    }

    /// @notice Emission a game could mint right now (bucket + pending accrual, bucket-capped),
    ///         before the supply soft-cap is applied.
    function pendingEmission(uint256 gameId) external view returns (uint256) {
        uint256 rate = _effectiveRatePerSec(gameId);
        uint256 last = lastAccrual[gameId];
        uint256 dt = (last == 0 || block.timestamp <= last) ? 0 : block.timestamp - last;
        if (dt > maxAccrualSeconds) dt = maxAccrualSeconds;
        uint256 acc = bucket[gameId] + rate * dt;
        uint256 cap = rate * maxAccrualSeconds; // max the bucket may ever hold
        // rate == 0 is a pause, not a wipe: preserve the already-accrued bucket.
        return (rate != 0 && acc > cap) ? cap : acc;
    }

    /// @dev The game's effective emission rate (SLVR/sec): its weighted share of the global
    ///      stream, never exceeding its maxWeightBps ceiling.
    function _effectiveRatePerSec(uint256 gameId) private view returns (uint256) {
        uint256 totalW = REGISTRY.totalActiveWeight();
        if (totalW == 0) return 0;
        uint256 weight = REGISTRY.weightOf(gameId);
        if (weight == 0) return 0;
        uint256 rate = (emissionRatePerSec * weight) / totalW;
        uint256 capRate = (emissionRatePerSec * REGISTRY.maxWeightBpsOf(gameId)) / BPS;
        return rate > capRate ? capRate : rate;
    }

    /// @dev Accrue streamed emission into the bucket, HARD-CAPPING the bucket at one
    ///      `maxAccrualSeconds` window of the game's rate. This bounds how much can be minted in a
    ///      single round after headroom reopens (no post-burn windfall), keeps the burn-neutral
    ///      steady state smooth, and forfeits emission a game sat on beyond the window.
    function _accrue(uint256 gameId) private {
        uint256 rate = _effectiveRatePerSec(gameId);
        uint256 last = lastAccrual[gameId];
        lastAccrual[gameId] = block.timestamp;

        uint256 cap = rate * maxAccrualSeconds;
        uint256 b = bucket[gameId];
        if (rate != 0 && last != 0 && block.timestamp > last) {
            uint256 dt = block.timestamp - last;
            if (dt > maxAccrualSeconds) dt = maxAccrualSeconds;
            b += rate * dt;
        }
        // Clamp to one window ("capped accrual bucket"). rate == 0 is a pause, not a wipe —
        // preserve the already-accrued bucket rather than clamping it to 0.
        if (rate != 0 && b > cap) b = cap;
        bucket[gameId] = b;
    }

    // ------------------------------------------------------------------
    // Shared staker stream (games call payStakers)
    // ------------------------------------------------------------------

    function payStakers() external payable nonReentrant {
        uint256 gameId = _activeGameId(msg.sender);
        emit StakersPaid(gameId, stakerSeq, msg.value);
        _pushStakers(msg.value);
    }

    /// @notice Retry delivering any deferred staker rewards once the staking sink is healthy again.
    /// @dev Permissionless: it only forwards already-held funds to the configured staking contract.
    function flushStakers() external nonReentrant {
        if (pendingStakerRewards == 0) revert NothingPending();
        _pushStakers(0);
    }

    /// @dev Delivers `newAmount` plus any previously-deferred rewards to staking as one tranche.
    ///      On failure (sink unset or reverting) funds are parked in the hub and the sequence is
    ///      NOT advanced, preserving the staking contract's strict-sequential invariant. This
    ///      isolates a broken staking sink so it can never brick round resolution for any game.
    function _pushStakers(uint256 newAmount) private {
        uint256 amount = pendingStakerRewards + newAmount;
        if (address(staking) == address(0)) {
            pendingStakerRewards = amount; // no sink yet; hold the funds
            return;
        }
        uint256 seq = stakerSeq;
        uint256 snapshot = 0;
        try staking.getTotalWeight() returns (uint256 w) {
            snapshot = w;
        } catch {}
        try staking.distributeRoundRewards{value: amount}(seq, snapshot) {
            stakerSeq = seq + 1;
            pendingStakerRewards = 0;
        } catch {
            // Funds remain in the hub (the reverted call returned the value); retry via flushStakers.
            pendingStakerRewards = amount;
            emit StakersDeferred(seq, amount);
        }
    }

    // ------------------------------------------------------------------
    // Shared jackpot (games call feedJackpot / rollJackpot / distributeBribes*)
    // ------------------------------------------------------------------

    function feedJackpot() external payable nonReentrant {
        uint256 gameId = _activeGameId(msg.sender);
        if (address(jackpot) == address(0)) revert NoJackpot();
        jackpot.addEth{value: msg.value}();
        emit JackpotFed(gameId, msg.value);
    }

    /// @notice Roll the shared jackpot for the caller-game.
    /// @dev SECURITY: the jackpot hit is a pure function of `randomness`, so a caller that can
    ///      choose `randomness` freely could grind a guaranteed hit and drain the shared pool.
    ///      Therefore this is restricted to Core-tier (audited, first-party) games, which are
    ///      trusted to pass ONLY oracle-settled, unbiasable randomness (exactly as the grid lottery
    ///      does with its randomness provider). Community/Experimental games may fund the pot
    ///      (feedJackpot) and earn emissions/staker rewards, but may not trigger it.
    function rollJackpot(uint256 winnerTotal, uint256 randomness)
        external
        nonReentrant
        returns (uint256 globalEpoch, bool hit, uint256 ethBonus, uint256 slvrBonus)
    {
        uint256 gameId = _coreActiveGameId(msg.sender);
        if (address(jackpot) == address(0)) revert NoJackpot();

        globalEpoch = ++jackpotEpoch;
        (hit, ethBonus, slvrBonus) = jackpot.checkAndApply(randomness, globalEpoch, winnerTotal);

        // Only a hit epoch has bribes to distribute; only then does ownership matter.
        if (hit) {
            epochOwner[globalEpoch] = gameId;
            // The jackpot forwards any bonus to its authorized caller (this hub); pass it to the game.
            if (ethBonus > 0) {
                (bool ok,) = msg.sender.call{value: ethBonus}("");
                if (!ok) revert BonusTransferFailed();
            }
            if (slvrBonus > 0) {
                SLVR.safeTransfer(msg.sender, slvrBonus);
            }
        }
        emit JackpotRolled(gameId, globalEpoch, hit, ethBonus, slvrBonus);
    }

    function distributeBribes(uint256 globalEpoch) external nonReentrant {
        _requireCoreEpochOwner(globalEpoch);
        jackpot.distributeBribes(globalEpoch);
    }

    function distributeBribesToWinner(uint256 globalEpoch, address winner, uint256 userBet, uint256 winnerTotal)
        external
        nonReentrant
    {
        _requireCoreEpochOwner(globalEpoch);
        jackpot.distributeBribesToWinner(globalEpoch, winner, userBet, winnerTotal);
    }

    // ------------------------------------------------------------------
    // Rescue (operational safety; owner-only)
    // ------------------------------------------------------------------

    /// @notice Recover stray funds. `token == address(0)` rescues native; otherwise ERC20.
    /// @dev Cannot touch funds owed to stakers: native rescue leaves `pendingStakerRewards` behind.
    function rescue(address token, address to, uint256 amount) external onlyOwner nonReentrant {
        require(to != address(0), "zero recipient");
        if (token == address(0)) {
            uint256 free = address(this).balance;
            require(free >= pendingStakerRewards + amount, "would touch staker funds");
            (bool ok,) = payable(to).call{value: amount}("");
            require(ok, "native rescue failed");
        } else {
            IERC20(token).safeTransfer(to, amount);
        }
        emit Rescued(token, to, amount);
    }

    // ------------------------------------------------------------------
    // Internal auth helpers
    // ------------------------------------------------------------------

    function _activeGameId(address caller) private view returns (uint256 gameId) {
        gameId = REGISTRY.gameIdOf(caller);
        if (gameId == 0) revert NotRegisteredGame();
        if (REGISTRY.statusOf(gameId) != ISlvrGameRegistry.Status.Active) revert NotActiveGame();
    }

    /// @dev Active AND Core-tier: gates the shared-jackpot trigger and bribe distribution to
    ///      trusted first-party games (see rollJackpot for the rationale).
    function _coreActiveGameId(address caller) private view returns (uint256 gameId) {
        gameId = _activeGameId(caller);
        if (REGISTRY.tierOf(gameId) != ISlvrGameRegistry.Tier.Core) revert NotCoreGame();
    }

    function _requireCoreEpochOwner(uint256 globalEpoch) private view {
        if (address(jackpot) == address(0)) revert NoJackpot();
        uint256 gameId = _coreActiveGameId(msg.sender);
        if (epochOwner[globalEpoch] != gameId) revert NotEpochOwner();
    }
}
