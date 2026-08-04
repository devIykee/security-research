// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title SlvrLiquidityStaking
/// @notice LP token staking with multiplier points and ETH rewards
/// @notice Rewards stream linearly over 5 days from each deposit
/// @notice Points accrue over time and increase reward share (multiplier: 1x to 2x)
/// @notice Points are absolute (stake-epochs), multiplier is relative to current stake
contract SlvrLiquidityStaking is ReentrancyGuard, Ownable2Step {
    using SafeERC20 for IERC20;
    
    IERC20 public immutable LP_TOKEN;

    address public growthFund; // Only growth fund can deposit rewards
    address public treasury; // Receives early withdrawal fees

    uint256 public constant EARLY_WITHDRAWAL_PERIOD = 6 hours;
    uint256 public constant EARLY_WITHDRAWAL_FEE_BPS = 200; // 2%
    uint256 public constant TARGET_EPOCHS = 7; // 7 days to reach max multiplier (for points system)
    uint256 public constant EPOCH_DURATION = 1 days; // 1 day per epoch
    uint256 public constant MAX_UNLOCK = 1e18; // 100% unlock (scaled by 1e18)
    uint256 public constant RELEASE_PERIOD = 5 days; // Rewards stream over 5 days from deposit

    // Total LP tokens staked
    uint256 public totalStaked;

    // Streaming rewards system (Synthetix-style)
    uint256 public rewardRate; // ETH per second (streaming rate)
    uint256 public periodFinish; // Timestamp when current reward stream ends
    uint256 public lastUpdateTime; // Last time rewardPerWeightStored was updated
    uint256 public rewardPerWeightStored; // Accumulated rewards per weight unit (scaled by 1e18)
    uint256 public totalWeight; // Sum of all user weights (stake * multiplier)
    uint256 public queuedRewards; // Rewards deposited when totalWeight == 0

    // User staking info
    struct UserInfo {
        uint256 stake; // Staked LP token amount
        uint256 points; // Absolute points (stake-epochs accumulated, claimed)
        uint256 unclaimedPoints; // Unclaimed points (stake-epochs not yet claimed)
        uint64 lastAccrualTime; // Last timestamp when points were checkpointed
        uint64 lastDepositTime; // Last time user deposited (for early withdrawal check)
        uint256 userWeight; // User's weight (stake * multiplier)
        uint256 userRewardPerWeightPaid; // Last rewardPerWeightStored when user was updated
        uint256 rewards; // Accrued but not yet claimed rewards (ETH)
    }

    mapping(address => UserInfo) public userInfo;
    
    // Whitelist for depositFor() to prevent griefing attacks
    mapping(address => bool) public depositForWhitelist;

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount, uint256 fee);
    event RewardDeposited(address indexed depositor, uint256 amount);
    event RewardClaimed(address indexed user, uint256 amount);
    event GrowthFundUpdated(address indexed oldFund, address indexed newFund);
    event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury);
    event DepositForWhitelistUpdated(address indexed account, bool whitelisted);
    event EmergencyRescue(address indexed token, address indexed to, uint256 amount);
    event RewardRateUpdated(uint256 newRate, uint256 periodFinish);

    constructor(address lpToken_, address growthFund_, address treasury_, address owner_) Ownable(owner_) {
        require(lpToken_ != address(0), "lpToken=0");
        require(growthFund_ != address(0), "growthFund=0");
        require(treasury_ != address(0), "treasury=0");
        LP_TOKEN = IERC20(lpToken_);
        growthFund = growthFund_;
        treasury = treasury_;
        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp;
    }

    /// @notice Set growth fund address
    function setGrowthFund(address growthFund_) external onlyOwner {
        require(growthFund_ != address(0), "growthFund=0");
        address oldFund = growthFund;
        growthFund = growthFund_;
        emit GrowthFundUpdated(oldFund, growthFund_);
    }

    /// @notice Set treasury address (receives early withdrawal fees)
    function setTreasury(address treasury_) external onlyOwner {
        require(treasury_ != address(0), "treasury=0");
        address oldTreasury = treasury;
        treasury = treasury_;
        emit TreasuryUpdated(oldTreasury, treasury_);
    }

    /// @notice Add or remove an address from the depositFor whitelist
    /// @dev Only whitelisted addresses can call depositFor() to prevent griefing
    /// @param account Address to whitelist/unwhitelist
    /// @param whitelisted Whether to whitelist (true) or remove (false)
    function setDepositForWhitelist(address account, bool whitelisted) external onlyOwner {
        require(account != address(0), "account=0");
        depositForWhitelist[account] = whitelisted;
        emit DepositForWhitelistUpdated(account, whitelisted);
    }

    /// @notice Get current epoch (days since epoch 0)
    /// @dev Kept for backward compatibility, but not used for point accrual
    function getCurrentEpoch() public view returns (uint256) {
        return block.timestamp / EPOCH_DURATION;
    }

    /// @notice Checkpoint unclaimed points based on elapsed time
    /// @dev Points accrue into unclaimedPoints as stake-epochs based on actual time elapsed
    /// @dev This prevents gaming by staking just before epoch boundaries
    function _checkpointUnclaimedPoints(UserInfo storage u) internal {
        if (u.stake == 0) {
            u.lastAccrualTime = uint64(block.timestamp);
            return;
        }

        uint256 now_ = block.timestamp;
        uint256 lastAccrual = uint256(u.lastAccrualTime);
        
        if (now_ > lastAccrual) {
            uint256 delta = now_ - lastAccrual;
            // Accrue points: stake * delta / EPOCH_DURATION
            // This gives stake-epochs (stake amount in wei * epochs elapsed)
            // No need for 1e18 multiplier since stake is already in wei
            u.unclaimedPoints += (u.stake * delta) / EPOCH_DURATION;
            u.lastAccrualTime = uint64(now_);
        }
    }

    /// @notice Claim unclaimed points (move them to claimed points)
    /// @dev Claimed points drive progress calculation
    function _claimPoints(UserInfo storage u) internal {
        uint256 amt = u.unclaimedPoints;
        if (amt > 0) {
            u.points += amt;        // claimed points drive progress
            u.unclaimedPoints = 0;
        }
    }

    /// @notice Calculate user's progress toward max unlock (0 to 1e18)
    /// @dev progress = min(1, points / (stake * TARGET_EPOCHS) * 1e18)
    /// @dev Uses only claimed points (not unclaimed)
    /// @dev When stake increases, progress naturally dilutes (points stay constant)
    /// @dev Points are stored as stake-epochs: stake * time / EPOCH_DURATION (stake in wei)
    function _getProgress(UserInfo storage u) internal view returns (uint256) {
        if (u.stake == 0) return 0;

        // progress = (points / (stake * TARGET_EPOCHS)) * 1e18, capped at 1e18
        // Points are stored as stake-epochs: stake * time / EPOCH_DURATION
        // Target is: stake * TARGET_EPOCHS
        // Ratio gives epochs / TARGET_EPOCHS, then multiply by 1e18 for precision
        uint256 denom = u.stake * TARGET_EPOCHS;
        if (denom == 0) return 0;
        
        uint256 raw = (u.points * 1e18) / denom;
        return raw > MAX_UNLOCK ? MAX_UNLOCK : raw;
    }

    /// @notice Get user's effective multiplier (1e18 = 1x, 2e18 = 2x)
    /// @dev multiplier = 1x + progress * 1x (linear from 1x to 2x)
    function getUserEffectiveMultiplier(address user) external view returns (uint256) {
        UserInfo storage u = userInfo[user];
        uint256 progress = _getProgress(u);
        // multiplier = 1e18 + progress (gives 1x to 2x)
        return 1e18 + progress;
    }

    /// @notice Get user's claimed points (absolute stake-epochs)
    function getUserPoints(address user) external view returns (uint256) {
        return userInfo[user].points;
    }

    /// @notice Get user's unclaimed points
    function getUserUnclaimedPoints(address user) external view returns (uint256) {
        UserInfo memory u = userInfo[user];
        if (u.stake == 0) return u.unclaimedPoints;

        // Calculate unclaimed points including time since last checkpoint
        uint256 now_ = block.timestamp;
        uint256 lastAccrual = uint256(u.lastAccrualTime);
        if (now_ <= lastAccrual) return u.unclaimedPoints;

        uint256 delta = now_ - lastAccrual;
        // Accrue points: stake * delta / EPOCH_DURATION
        // This gives stake-epochs (stake amount in wei * epochs elapsed)
        return u.unclaimedPoints + ((u.stake * delta) / EPOCH_DURATION);
    }

    /// @notice Get the last time rewards were applicable (capped at periodFinish)
    function lastTimeRewardApplicable() public view returns (uint256) {
        return block.timestamp < periodFinish ? block.timestamp : periodFinish;
    }

    /// @notice Update reward tracking for a user (or globally if account is address(0))
    /// @dev Accrues rewards based on time elapsed and current rewardRate
    function _updateReward(address account) internal {
        uint256 t = lastTimeRewardApplicable();
        if (totalWeight > 0) {
            // CRITICAL: only ever advance lastUpdateTime forward. `t` is min(now, periodFinish), so
            // when periodFinish is in the past (stream ended / not yet (re)started) it would otherwise
            // snap lastUpdateTime backwards, and the next accrual would credit the entire elapsed gap
            // at the full rewardRate — over-distributing far more than was deposited and potentially
            // rendering the contract insolvent so claims revert. Guarding on t > lastUpdateTime keeps
            // accrual bounded to the live streaming window.
            if (t > lastUpdateTime) {
                rewardPerWeightStored += ((t - lastUpdateTime) * rewardRate * 1e18) / totalWeight;
                lastUpdateTime = t;
            }
        }
        // When totalWeight == 0, don't update lastUpdateTime to prevent stale periodFinish values
        // It will be reset properly when the first staker deposits and processes queued rewards

        if (account != address(0)) {
            UserInfo storage u = userInfo[account];
            if (u.userWeight > 0) {
                uint256 earned = (u.userWeight * (rewardPerWeightStored - u.userRewardPerWeightPaid)) / 1e18;
                u.rewards += earned;
            }
            u.userRewardPerWeightPaid = rewardPerWeightStored;
        }
    }

    /// @notice Recompute user's weight based on stake and multiplier
    /// @dev Weight = stake * multiplier, where multiplier = 1e18 + progress (1x to 2x)
    /// @dev Uses defensive math to prevent DoS if invariants drift
    function _recomputeWeight(UserInfo storage u) internal {
        uint256 oldWeight = u.userWeight;
        
        if (u.stake == 0) {
            // Defensive: prevent underflow if oldWeight > totalWeight
            if (totalWeight >= oldWeight) {
                totalWeight -= oldWeight;
            } else {
                totalWeight = 0;
            }
            u.userWeight = 0;
            return;
        }

        uint256 progress = _getProgress(u);
        uint256 multiplier = 1e18 + progress; // 1x to 2x
        uint256 newWeight = (u.stake * multiplier) / 1e18;

        // Defensive: prevent underflow if oldWeight > totalWeight (rounding drift, bugs, etc.)
        if (totalWeight >= oldWeight) {
            totalWeight -= oldWeight;
        } else {
            totalWeight = 0;
        }
        totalWeight += newWeight;
        u.userWeight = newWeight;
    }


    /// @notice Deposit LP tokens to stake
    /// @param amount Amount of LP tokens to deposit
    function deposit(uint256 amount) external nonReentrant {
        _depositFor(msg.sender, amount);
    }

    /// @notice Deposit LP tokens to stake on behalf of another user
    /// @dev Only whitelisted addresses can call this to prevent griefing attacks
    /// @param user Address to credit the stake to
    /// @param amount Amount of LP tokens to deposit
    function depositFor(address user, uint256 amount) external nonReentrant {
        require(user != address(0), "user=0");
        require(depositForWhitelist[msg.sender] || msg.sender == user, "not whitelisted");
        _depositFor(user, amount);
    }

    /// @notice Internal function to handle deposit logic
    /// @param user Address to credit the stake to
    /// @param amount Amount of LP tokens to deposit
    function _depositFor(address user, uint256 amount) internal {
        require(amount > 0, "amount=0");

        UserInfo storage u = userInfo[user];
        bool wasFirstStaker = totalWeight == 0;
        bool isNewUser = u.userWeight == 0;

        _updateReward(address(0));

        if (!isNewUser) {
            _updateReward(user);
        }

        _checkpointUnclaimedPoints(u);

        uint256 before = LP_TOKEN.balanceOf(address(this));
        LP_TOKEN.safeTransferFrom(msg.sender, address(this), amount);
        uint256 after_ = LP_TOKEN.balanceOf(address(this));
        uint256 received = after_ - before;
        require(received > 0, "no tokens received");

        u.stake += received;
        if (u.lastDepositTime == 0) {
            u.lastDepositTime = uint64(block.timestamp);
        } else if (msg.sender == user || depositForWhitelist[msg.sender]) {
            u.lastDepositTime = uint64(block.timestamp);
        }
        totalStaked += received;

        _recomputeWeight(u);

        u.userRewardPerWeightPaid = rewardPerWeightStored;

        if (wasFirstStaker && totalWeight > 0) {
            // Pool is transitioning empty -> non-empty. Before resetting the stream, recover the
            // un-streamed remainder [lastUpdateTime, periodFinish] * rewardRate. While the pool sat
            // empty, rewardPerWeightStored could not advance (the totalWeight==0 guard in
            // _updateReward), so that scheduled ETH — which is already sitting in the contract — was
            // never credited to anyone. lastUpdateTime is pinned at the moment the pool emptied, so
            // this single fold captures both the empty gap [emptied, now] AND the still-active tail
            // [now, periodFinish]; folding only the tail (as before) permanently stranded the gap,
            // and native rewards cannot be rescued.
            if (periodFinish > lastUpdateTime) {
                queuedRewards += (periodFinish - lastUpdateTime) * rewardRate;
            }

            // Reset accrual to start NOW so this staker cannot retroactively harvest the empty
            // interval (an unbounded, stake-independent reward capture). Must run even when there
            // were no pre-existing queued rewards, e.g. a mid-stream pool emptying and refilling.
            lastUpdateTime = block.timestamp;
            _updateReward(address(0));

            if (queuedRewards > 0) {
                uint256 total = queuedRewards;
                queuedRewards = 0;

                // Start a new stream with queued rewards (recovered remainder + anything queued
                // while empty). Carry the sub-period dust remainder forward.
                uint256 rate = total / RELEASE_PERIOD;
                uint256 remainder = total - (rate * RELEASE_PERIOD);

                rewardRate = rate;
                queuedRewards += remainder; // Carry remainder forward
                periodFinish = block.timestamp + RELEASE_PERIOD;
                emit RewardRateUpdated(rewardRate, periodFinish);
            }
        }

        emit Deposit(user, received);
    }

    /// @notice Internal function to handle withdraw logic
    /// @param user Address of the user withdrawing
    /// @param amount Amount of LP tokens to withdraw
    /// @param skipRewards If true, skip claiming rewards
    /// @param rewardRecipient Address to receive rewards (if skipRewards is false). If address(0), uses user
    function _withdrawInternal(address user, uint256 amount, bool skipRewards, address rewardRecipient) internal {
        require(amount > 0, "amount=0");
        require(!skipRewards || rewardRecipient == address(0), "skipRewards requires rewardRecipient=0");
        UserInfo storage u = userInfo[user];
        require(u.stake >= amount, "insufficient staked");

        _updateReward(address(0));
        _updateReward(user);

        _checkpointUnclaimedPoints(u);
        _claimPoints(u);

        uint256 rewardAmount = u.rewards;
        if (rewardAmount > 0) {
            if (!skipRewards) {
                u.rewards = 0;
                address recipient = rewardRecipient != address(0) ? rewardRecipient : user;
                (bool ok,) = payable(recipient).call{value: rewardAmount}("");
                require(ok, "reward xfer failed");
                emit RewardClaimed(user, rewardAmount);
            } else {
                require(rewardAmount == 0, "claim first");
            }
        }

        uint256 fee = 0;
        if (block.timestamp < u.lastDepositTime + EARLY_WITHDRAWAL_PERIOD) {
            fee = (amount * EARLY_WITHDRAWAL_FEE_BPS) / 10000;
        }

        u.stake -= amount;
        totalStaked -= amount;

        u.points = 0;
        u.unclaimedPoints = 0;
        u.lastAccrualTime = uint64(block.timestamp);

        _recomputeWeight(u);

        u.userRewardPerWeightPaid = rewardPerWeightStored;

        // Transfer LP tokens back to user (minus fee)
        uint256 withdrawAmount = amount - fee;
        LP_TOKEN.safeTransfer(user, withdrawAmount);

        // Send fee to treasury (or burn if preferred)
        if (fee > 0) {
            LP_TOKEN.safeTransfer(treasury, fee);
        }

        emit Withdraw(user, amount, fee);
    }

    /// @notice Withdraw LP tokens from staking
    /// @dev IMPORTANT: Claims all claimable rewards before resetting points and forfeiting remaining locked rewards
    /// @dev This ensures users don't lose their pending rewards when withdrawing
    /// @param amount Amount of LP tokens to withdraw
    function withdraw(uint256 amount) external nonReentrant {
        _withdrawInternal(msg.sender, amount, false, address(0));
    }

    /// @notice Withdraw LP tokens from staking with options
    /// @dev IMPORTANT: Claims all claimable rewards before resetting points and forfeiting remaining locked rewards
    /// @dev This ensures users don't lose their pending rewards when withdrawing
    /// @param amount Amount of LP tokens to withdraw
    /// @param skipRewards If true, skip claiming rewards (useful for contract wallets that can't receive native)
    /// @param rewardRecipient Address to receive rewards (if skipRewards is false). If address(0), uses msg.sender
    function withdraw(uint256 amount, bool skipRewards, address rewardRecipient) external nonReentrant {
        _withdrawInternal(msg.sender, amount, skipRewards, rewardRecipient);
    }

    /// @notice Deposit rewards (called by growth fund)
    /// @dev Rewards stream linearly over 5 days from deposit time
    /// @dev Each deposit creates a new 5-day stream (rolls leftover + new into new period)
    /// @dev If totalWeight == 0, rewards are queued until someone stakes
    function depositRewards() external payable nonReentrant {
        require(msg.sender == growthFund, "only growth fund");
        uint256 amount = msg.value;
        require(amount > 0, "amount=0");

        if (totalWeight == 0) {
            queuedRewards += amount;
            emit RewardDeposited(msg.sender, amount);
            return;
        }

        bool isFirstRewardDeposit = (rewardRate == 0);
        
        if (isFirstRewardDeposit) {
            lastUpdateTime = block.timestamp;
        }
        
        _updateReward(address(0));

        uint256 total = amount + queuedRewards;
        queuedRewards = 0;

        // Calculate new reward rate: roll leftover + new into 5-day stream
        uint256 numerator;
        if (block.timestamp >= periodFinish) {
            // No active stream, start fresh
            numerator = total;
        } else {
            // Active stream exists, roll leftover + new into new 5-day period
            uint256 remaining = periodFinish - block.timestamp;
            uint256 leftover = remaining * rewardRate;
            numerator = total + leftover;
        }

        // Calculate rate and remainder to prevent dust accumulation
        uint256 rate = numerator / RELEASE_PERIOD;
        uint256 remainder = numerator - (rate * RELEASE_PERIOD);
        
        rewardRate = rate;
        queuedRewards += remainder;

        // Anchor accrual to now: if the previous stream had already ended, lastUpdateTime is stuck at
        // the old (past) periodFinish, and without this the next _updateReward would credit the whole
        // gap between the old finish and now at the new rate. The preceding _updateReward already
        // settled accrual under the old rate, so it is safe to move the anchor forward here.
        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp + RELEASE_PERIOD;

        emit RewardRateUpdated(rewardRate, periodFinish);
        emit RewardDeposited(msg.sender, amount);
    }

    /// @notice Claim points (move unclaimed to claimed)
    function claimPoints() external nonReentrant {
        UserInfo storage u = userInfo[msg.sender];
        if (u.stake == 0) return;

        _updateReward(address(0));
        _updateReward(msg.sender);

        _checkpointUnclaimedPoints(u);
        _claimPoints(u);

        _recomputeWeight(u);

        u.userRewardPerWeightPaid = rewardPerWeightStored;
    }

    /// @notice Accrue unclaimed points for any user (anyone can call)
    /// @dev Updates unclaimed points to current epoch for the specified user
    /// @dev This allows keepers or other users to help update points for others
    /// @param user Address of the user to accrue points for
    function accruePoints(address user) external nonReentrant {
        UserInfo storage u = userInfo[user];
        if (u.stake > 0) {
            _checkpointUnclaimedPoints(u);
        }
    }

    /// @notice Internal function to claim rewards to a specified address
    /// @param user Address of the user claiming rewards
    /// @param to Address to receive the rewards
    function _claimRewardsToInternal(address user, address to) internal {
        require(to != address(0), "to=0");
        UserInfo storage u = userInfo[user];
        require(u.stake > 0, "not staking");

        _updateReward(address(0));
        _updateReward(user);

        _checkpointUnclaimedPoints(u);
        _claimPoints(u);
        
        _recomputeWeight(u);

        u.userRewardPerWeightPaid = rewardPerWeightStored;

        uint256 rewardAmount = u.rewards;
        if (rewardAmount > 0) {
            u.rewards = 0;
            (bool success,) = payable(to).call{value: rewardAmount}("");
            require(success, "transfer failed");
            emit RewardClaimed(user, rewardAmount);
        }
    }

    /// @notice Claim pending ETH rewards
    /// @dev Auto-claims points before calculating claimable rewards
    function claimRewards() external nonReentrant {
        _claimRewardsToInternal(msg.sender, msg.sender);
    }

    /// @notice Claim pending ETH rewards to a specified address
    /// @dev Auto-claims points before calculating claimable rewards
    /// @dev Allows contract wallets to specify a recipient that can receive native tokens
    /// @param to Address to receive the rewards
    function claimRewardsTo(address to) external nonReentrant {
        _claimRewardsToInternal(msg.sender, to);
    }

    /// @notice Get pending rewards for a user (view function)
    /// @param user Address of the user
    function getPendingRewards(address user) external view returns (uint256) {
        UserInfo memory u = userInfo[user];
        
        if (u.stake == 0) {
            return u.rewards;
        }

        // Calculate user's current weight (stake * multiplier)
        // This ensures we calculate pending rewards even if weight hasn't been checkpointed yet
        uint256 currentWeight = u.userWeight;
        if (currentWeight == 0) {
            // Weight not yet computed, calculate it now (for view purposes)
            // Calculate progress inline (same logic as _getProgress but for memory struct)
            uint256 progress = 0;
            if (u.stake > 0) {
                uint256 denom = u.stake * TARGET_EPOCHS;
                if (denom > 0) {
                    uint256 raw = (u.points * 1e18) / denom;
                    progress = raw > MAX_UNLOCK ? MAX_UNLOCK : raw;
                }
            }
            uint256 multiplier = 1e18 + progress; // 1x to 2x
            currentWeight = (u.stake * multiplier) / 1e18;
        }

        // Calculate current rewardPerWeightStored (view-only)
        uint256 t = lastTimeRewardApplicable();
        uint256 currentRewardPerWeightStored = rewardPerWeightStored;
        
        if (totalWeight > 0) {
            uint256 timeElapsed = t > lastUpdateTime ? t - lastUpdateTime : 0;
            if (timeElapsed > 0) {
                currentRewardPerWeightStored += (timeElapsed * rewardRate * 1e18) / totalWeight;
            }
        }

        // Calculate pending rewards: already accrued + new since last update
        // Use currentWeight (computed above) instead of u.userWeight
        uint256 pending = (currentWeight * (currentRewardPerWeightStored - u.userRewardPerWeightPaid)) / 1e18;
        
        return u.rewards + pending;
    }

    /// @notice Get user's staked LP token amount
    /// @param user Address of the user
    function getUserStaked(address user) external view returns (uint256) {
        return userInfo[user].stake;
    }

    /// @notice Get user's multiplier points (for compatibility, returns claimed points)
    /// @param user Address of the user
    function getUserMultiplierPoints(address user) external view returns (uint256) {
        return userInfo[user].points;
    }


    /// @notice Get available rewards balance in the contract
    /// @dev Returns the native token (ETH) balance of the contract
    /// @dev This can be compared against total claimable rewards to verify accounting invariants
    /// @return The contract's native token balance
    function availableRewards() external view returns (uint256) {
        return address(this).balance;
    }

    /// @notice Get current reward release rate
    /// @dev Returns the current streaming rate per second
    /// @return Current reward rate per second (ETH per second)
    function getCurrentReleaseRate() external view returns (uint256) {
        return rewardRate;
    }

    /// @notice Get estimated rewards per year based on current release rate
    /// @dev Calculates: rewardRate * seconds per year
    /// @return Estimated ETH rewards per year (in wei)
    function getRewardsPerYear() external view returns (uint256) {
        if (rewardRate == 0) return 0;
        uint256 secondsPerYear = 365 days;
        return rewardRate * secondsPerYear;
    }

    /// @notice Get ETH per LP per year (scaled by 10000)
    /// @dev Returns (rewards per year / total staked) * 10000
    /// @dev WARNING: This is NOT a true APR percentage. It divides ETH (rewards) by LP tokens (stake),
    /// @dev which are different units. To get true APR, multiply by ETH/LP price ratio in the UI.
    /// @dev Returns 0 if no stakers or no rewards
    /// @return ETH per LP per year scaled by 10000 (e.g., 500 = 0.05 ETH per LP per year)
    function getMONPerLPPerYearScaled() external view returns (uint256) {
        if (totalStaked == 0) return 0;
        uint256 rewardsPerYear = this.getRewardsPerYear();
        if (rewardsPerYear == 0) return 0;
        // ETH per LP per year (scaled by 10000) = (rewardsPerYear / totalStaked) * 10000
        return (rewardsPerYear * 10000) / totalStaked;
    }

    /// @notice Get comprehensive pool information
    /// @return rewardRate_ Current reward rate per second (ETH per second)
    /// @return periodFinish_ Timestamp when current reward stream ends
    /// @return totalWeight_ Total weight (sum of all user weights)
    /// @return rewardsPerYear Estimated rewards per year (ETH)
    /// @return ethPerLPPerYearScaled ETH per LP per year scaled by 10000 (NOT true APR - requires price conversion)
    /// @return totalStaked_ Total LP tokens staked
    function getPoolInfo() external view returns (
        uint256 rewardRate_,
        uint256 periodFinish_,
        uint256 totalWeight_,
        uint256 rewardsPerYear,
        uint256 ethPerLPPerYearScaled,
        uint256 totalStaked_
    ) {
        rewardRate_ = rewardRate;
        periodFinish_ = periodFinish;
        totalWeight_ = totalWeight;
        rewardsPerYear = this.getRewardsPerYear();
        ethPerLPPerYearScaled = this.getMONPerLPPerYearScaled();
        totalStaked_ = totalStaked;
    }

    /// @notice Receive native tokens (ETH) for rewards
    /// @dev Reverts to prevent funds from being sent without updating reward rate
    receive() external payable {
        revert("use depositRewards");
    }

    /// @notice Emergency rescue function for unrelated ERC20 tokens
    /// @dev Only owner can call. Cannot rescue LP_TOKEN (staked by users) or native tokens
    /// @param token Address of the ERC20 token to rescue
    /// @param to Address to send the rescued tokens to
    /// @param amount Amount of tokens to rescue (0 = full balance)
    function emergencyRescueERC20(address token, address to, uint256 amount) external onlyOwner {
        require(token != address(0), "token=0");
        require(to != address(0), "to=0");
        require(token != address(LP_TOKEN), "cannot rescue LP_TOKEN");
        
        IERC20 tokenContract = IERC20(token);
        uint256 balance = tokenContract.balanceOf(address(this));
        uint256 rescueAmount = amount == 0 ? balance : amount;
        require(rescueAmount > 0, "amount=0");
        require(rescueAmount <= balance, "insufficient balance");
        
        tokenContract.safeTransfer(to, rescueAmount);
        emit EmergencyRescue(token, to, rescueAmount);
    }
}
