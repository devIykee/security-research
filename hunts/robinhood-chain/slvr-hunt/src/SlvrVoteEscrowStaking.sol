// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ISlvrVoteEscrow} from "./interfaces/ISlvrVoteEscrow.sol";
import {ISlvrGridLottery} from "./interfaces/ISlvrGridLottery.sol";

/// @title SlvrVoteEscrowStaking
/// @notice Staking contract that distributes rewards to vote escrow NFT holders
/// @dev Uses standard rewardPerWeight pattern with tracked balances to prevent late-joiner exploits
contract SlvrVoteEscrowStaking is ReentrancyGuard, Ownable2Step {
    ISlvrVoteEscrow public immutable VOTE_ESCROW;
    address public immutable LOTTERY; // Only lottery can distribute rewards

    // Standard rewardPerWeight tracking
    uint256 public rewardPerWeightStored; // Accumulated reward per unit of weight (1e18 precision)
    
    // Per-token tracking
    mapping(uint256 => uint256) public rewardPerWeightPaid; // Last rewardPerWeightStored when token was updated
    mapping(uint256 => uint256) public rewards; // Claimable rewards for token
    mapping(uint256 => uint256) public balance; // Tracked weight for token (prevents late-joiner exploit)
    mapping(uint256 => uint256) public stakedAtRound; // Round ID when token was first staked (0 = staked before rounds started)
    
    // Total weight tracking
    uint256 public totalWeight; // Total tracked weight across all staked tokens
    
    // Unallocated rewards (when totalWeight == 0, park funds - can be swept by owner)
    uint256 public unallocated;

    // Distributed-but-unclaimed staker rewards (accounted into rewardPerWeightStored but not yet
    // claimed). Tracked so sweepExcess() cannot mistake owed rewards for "excess" and drain them.
    // Conservative: incremented by the full distributed amount (which is >= the sum ever claimable
    // after per-weight rounding), so it always covers outstanding claims.
    uint256 public totalRewardsOwed;
    
    // Track last distributed round ID to prevent retroactive rewards
    // Initialize to max uint256 to allow round 0 as first distribution
    uint256 public lastDistributedRoundId = type(uint256).max;

    // Rewards that were accrued to a token which is about to be burned (veNFT withdraw / convert).
    // Re-keyed by owner address (pull-based) so they survive the burn — claimStakerRewards can't be
    // used once ownerOf(tokenId) reverts. Drained via claimPendingRewards().
    mapping(address => uint256) public pendingRewardsByAddress;

    event RewardDistributed(uint256 amount);
    event RewardClaimed(uint256 indexed tokenId, address indexed user, uint256 amount);
    event Checkpoint(uint256 indexed tokenId, uint256 oldWeight, uint256 newWeight);
    event Staked(uint256 indexed tokenId, address indexed user, uint256 weight);
    event Unstaked(uint256 indexed tokenId, address indexed user, uint256 weight);
    event RewardsSettledOnBurn(uint256 indexed tokenId, address indexed owner, uint256 amount);
    event PendingRewardsClaimed(address indexed user, uint256 amount);

    constructor(address voteEscrow_, address lottery_, address owner_) Ownable(owner_) {
        require(voteEscrow_ != address(0), "voteEscrow=0");
        require(lottery_ != address(0), "lottery=0");
        VOTE_ESCROW = ISlvrVoteEscrow(voteEscrow_);
        LOTTERY = lottery_;
    }

    /// @notice Internal function to account for received ETH rewards
    /// @dev Updates rewardPerWeightStored, or parks funds in unallocated if no stakers
    /// @param amount Amount of ETH to account for
    /// @param totalWeightSnapshot The totalWeight at distribution time (used for calculation)
    function _accountRewards(uint256 amount, uint256, uint256 totalWeightSnapshot) private {
        require(amount > 0, "bad amount");

        if (totalWeightSnapshot > 0) {
            rewardPerWeightStored += (amount * 1e18) / totalWeightSnapshot;
            totalRewardsOwed += amount;
        } else {
            // No stakers - park funds in unallocated (can be swept by owner)
            unallocated += amount;
        }

        emit RewardDistributed(amount);
    }

    /// @notice Distribute round rewards (called by lottery contract)
    /// @dev Updates rewardPerWeightStored, or parks funds in unallocated if no stakers
    /// @param roundId The round ID these rewards are for
    /// @param totalWeightSnapshot The totalWeight at the time rewards were calculated
    function distributeRoundRewards(uint256 roundId, uint256 totalWeightSnapshot) external payable nonReentrant {
        require(msg.sender == LOTTERY, "unauthorized");
        
        if (lastDistributedRoundId != type(uint256).max) {
            require(roundId == lastDistributedRoundId + 1, "must distribute rounds sequentially");
        }
        
        if (msg.value == 0) {
            lastDistributedRoundId = roundId;
            emit RewardDistributed(0);
            return;
        }
        
        _accountRewards(msg.value, roundId, totalWeightSnapshot);
        
        // Update last distributed round ID
        lastDistributedRoundId = roundId;
    }

    /// @notice Stake a token to enter the reward set (owner-only, or VoteEscrow contract)
    /// @dev Sets balance[tokenId] = currentWeight and adds to totalWeight
    /// @dev Only the owner of the token or the VoteEscrow contract can stake it
    /// @dev VoteEscrow contract can stake on behalf of users for auto-staking during mint
    /// @param tokenId Vote escrow NFT token ID
    function stake(uint256 tokenId) external {
        address owner = VOTE_ESCROW.ownerOf(tokenId);
        require(owner == msg.sender || msg.sender == address(VOTE_ESCROW), "not authorized");
        
        uint256 currentWeight = _getWeight(tokenId);
        require(currentWeight > 0, "weight=0");
        
        uint256 previousWeight = balance[tokenId];
        require(previousWeight == 0, "already staked");
        
        if (lastDistributedRoundId != type(uint256).max) {
            try ISlvrGridLottery(LOTTERY).latestResolvedRoundId() returns (uint256 latestResolved) {
                if (latestResolved != type(uint256).max) {
                    require(latestResolved <= lastDistributedRoundId, "settle resolved rounds first");
                }
            } catch {
            }
        }
        
        uint256 totalWeightBefore = totalWeight;
        
        // Set balance and add to totalWeight
        balance[tokenId] = currentWeight;
        totalWeight += currentWeight;
        
        // Track which round this token was staked in (for informational purposes)
        try ISlvrGridLottery(LOTTERY).currentRoundId() returns (uint256 currentRound) {
            stakedAtRound[tokenId] = currentRound;
        } catch {
            stakedAtRound[tokenId] = 0;
        }
        
        // Initialize rewardPerWeightPaid to current value (no past rewards)
        rewardPerWeightPaid[tokenId] = rewardPerWeightStored;
        
        // Distribute unallocated rewards if transitioning from 0 to > 0
        _distributeUnallocatedOnTransition(tokenId, currentWeight, totalWeightBefore);
        
        emit Staked(tokenId, owner, currentWeight);
        emit Checkpoint(tokenId, 0, currentWeight);
    }

    /// @notice Unstake a token to exit the reward set (owner-only)
    /// @dev Checkpoints the token first to accrue rewards, then sets balance[tokenId] = 0
    /// @dev Removes the token's weight from totalWeight
    /// @dev Rewards remain claimable via claimStakerRewards() after unstaking
    /// @param tokenId Vote escrow NFT token ID
    function unstake(uint256 tokenId) external {
        address owner = VOTE_ESCROW.ownerOf(tokenId);
        require(owner == msg.sender, "not owner");
        
        uint256 previousWeight = balance[tokenId];
        require(previousWeight > 0, "not staked");
        
        _checkpoint(tokenId);
        
        uint256 currentWeight = balance[tokenId];
        if (currentWeight > 0) {
            totalWeight -= currentWeight;
            balance[tokenId] = 0;
            emit Unstaked(tokenId, owner, currentWeight);
            emit Checkpoint(tokenId, currentWeight, 0);
        }
    }

    /// @notice Checkpoint a token (permissionless - but only allows reducing weight)
    /// @dev Accrues rewards using previous tracked weight, then updates balance
    /// @dev Only allows reducing weight or cleaning up (currentWeight <= previousWeight)
    /// @dev Exception: VOTE_ESCROW contract itself can checkpoint with increases (for auto-checkpointing)
    /// @dev This prevents griefing by forcing inactive NFTs to accrue rewards
    /// @param tokenId Vote escrow NFT token ID
    function checkpoint(uint256 tokenId) external {
        uint256 currentWeight = _getWeight(tokenId);
        uint256 previousWeight = balance[tokenId];
        
        // Only allow checkpointing if:
        // 1. Token is already staked (previousWeight > 0), OR
        // 2. Current weight is 0 (cleanup case), OR
        // 3. Caller is VOTE_ESCROW itself (for auto-checkpointing during lock updates)
        // This prevents permissionless force-staking of inactive NFTs
        require(previousWeight > 0 || currentWeight == 0 || msg.sender == address(VOTE_ESCROW), "must stake first");
        
        // Only allow reducing weight or staying the same (no increases) unless caller is VOTE_ESCROW
        // This prevents griefing by checkpointing inactive NFTs to increase their weight
        // Exception: VOTE_ESCROW can checkpoint with increases when locks are extended/increased
        require(currentWeight <= previousWeight || msg.sender == address(VOTE_ESCROW), "can only reduce weight");
        
        _checkpoint(tokenId);
    }

    /// @notice Internal helper to distribute unallocated rewards when totalWeight transitions from 0 to > 0
    /// @param tokenId Token that triggered the transition
    /// @param currentWeight Current weight of the token
    /// @param totalWeightBefore Total weight before the transition
    function _distributeUnallocatedOnTransition(uint256 tokenId, uint256 currentWeight, uint256 totalWeightBefore) private {
    }

    /// @notice Internal checkpoint logic
    /// @dev Uses previous tracked weight to accrue rewards, then updates to current weight
    function _checkpoint(uint256 tokenId) private {
        uint256 currentWeight = _getWeight(tokenId);
        uint256 previousWeight = balance[tokenId];
        uint256 totalWeightBefore = totalWeight;
        
        if (previousWeight > 0) {
            uint256 rewardDelta = rewardPerWeightStored - rewardPerWeightPaid[tokenId];
            rewards[tokenId] += (previousWeight * rewardDelta) / 1e18;
        }
        
        rewardPerWeightPaid[tokenId] = rewardPerWeightStored;
        
        // Update totalWeight with weight transition
        if (previousWeight != currentWeight) {
            if (previousWeight > 0) {
                totalWeight -= previousWeight;
            }
            if (currentWeight > 0) {
                totalWeight += currentWeight;
            }
            balance[tokenId] = currentWeight;
            
            _distributeUnallocatedOnTransition(tokenId, currentWeight, totalWeightBefore);
        }
        
        emit Checkpoint(tokenId, previousWeight, currentWeight);
    }

    /// @notice Poke a token to clean up if it's been burned/withdrawn (permissionless)
    /// @dev Tries to get staking weight, and if token doesn't exist or weight is 0, cleans up tracking
    /// @dev Only allows reducing weight or cleaning up (currentWeight <= previousWeight)
    /// @dev This prevents griefing by forcing inactive NFTs to accrue rewards
    /// @param tokenId Vote escrow NFT token ID
    function poke(uint256 tokenId) external {
        uint256 currentWeight;
        try VOTE_ESCROW.getStakingWeight(tokenId) returns (uint256 weight) {
            currentWeight = weight;
        } catch {
            // Token doesn't exist or getStakingWeight reverts - clean up
            currentWeight = 0;
        }
        
        uint256 previousWeight = balance[tokenId];
        
        // Only allow reducing weight or staying the same (no increases)
        // This prevents griefing by poking inactive NFTs to increase their weight
        require(currentWeight <= previousWeight, "can only reduce weight");
        
        uint256 totalWeightBefore = totalWeight;
        
        // If weight changed (including to 0), checkpoint
        if (previousWeight != currentWeight) {
            // Accrue rewards using previous weight
            if (previousWeight > 0) {
                uint256 rewardDelta = rewardPerWeightStored - rewardPerWeightPaid[tokenId];
                rewards[tokenId] += (previousWeight * rewardDelta) / 1e18;
            }
            
            // Update tracking BEFORE updating totalWeight (so we can check transition)
            rewardPerWeightPaid[tokenId] = rewardPerWeightStored;
            
            // Update totalWeight
            if (previousWeight > 0) {
                totalWeight -= previousWeight;
            }
            if (currentWeight > 0) {
                totalWeight += currentWeight;
            }
            balance[tokenId] = currentWeight;
            
            _distributeUnallocatedOnTransition(tokenId, currentWeight, totalWeightBefore);
            
            emit Checkpoint(tokenId, previousWeight, currentWeight);
        }
    }

    /// @notice Batch poke multiple tokens to clean up if they've been burned/withdrawn (permissionless)
    /// @dev Efficiently cleans up multiple tokens in a single transaction
    /// @dev Only allows reducing weight or cleaning up (currentWeight <= previousWeight)
    /// @dev This prevents griefing by forcing inactive NFTs to accrue rewards
    /// @param tokenIds Array of vote escrow NFT token IDs to poke
    function pokeMany(uint256[] calldata tokenIds) external {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            uint256 currentWeight;
            try VOTE_ESCROW.getStakingWeight(tokenId) returns (uint256 weight) {
                currentWeight = weight;
            } catch {
                // Token doesn't exist or getStakingWeight reverts - clean up
                currentWeight = 0;
            }
            
            uint256 previousWeight = balance[tokenId];
            
            // Only allow reducing weight or staying the same (no increases)
            // This prevents griefing by poking inactive NFTs to increase their weight
            require(currentWeight <= previousWeight, "can only reduce weight");
            
            uint256 totalWeightBefore = totalWeight;
            
            // If weight changed (including to 0), checkpoint
            if (previousWeight != currentWeight) {
                // Accrue rewards using previous weight
                if (previousWeight > 0) {
                    uint256 rewardDelta = rewardPerWeightStored - rewardPerWeightPaid[tokenId];
                    rewards[tokenId] += (previousWeight * rewardDelta) / 1e18;
                }
                
                rewardPerWeightPaid[tokenId] = rewardPerWeightStored;
                
                // Update totalWeight
                if (previousWeight > 0) {
                    totalWeight -= previousWeight;
                }
                if (currentWeight > 0) {
                    totalWeight += currentWeight;
                }
                balance[tokenId] = currentWeight;
                
                _distributeUnallocatedOnTransition(tokenId, currentWeight, totalWeightBefore);
                
                emit Checkpoint(tokenId, previousWeight, currentWeight);
            }
        }
    }

    /// @notice Get current weight for a token (staking weight, non-decaying)
    /// @param tokenId Vote escrow NFT token ID
    /// @return weight Current staking weight
    function _getWeight(uint256 tokenId) private view returns (uint256 weight) {
        return VOTE_ESCROW.getStakingWeight(tokenId);
    }

    /// @notice Claim staker rewards for a specific vote escrow NFT
    /// @param tokenId Vote escrow NFT token ID
    /// @dev Owner-only, checkpoints first, then claims
    /// @dev Automatically stakes if not already staked
    function claimStakerRewards(uint256 tokenId) external nonReentrant {
        require(VOTE_ESCROW.ownerOf(tokenId) == msg.sender, "not owner");

        if (balance[tokenId] == 0) {
            uint256 currentWeight = _getWeight(tokenId);
            if (currentWeight > 0) {
                if (lastDistributedRoundId != type(uint256).max) {
                    try ISlvrGridLottery(LOTTERY).latestResolvedRoundId() returns (uint256 latestResolved) {
                        if (latestResolved != type(uint256).max) {
                            require(latestResolved <= lastDistributedRoundId, "settle resolved rounds first");
                        }
                    } catch {
                    }
                }
                
                uint256 totalWeightBefore = totalWeight;
                balance[tokenId] = currentWeight;
                totalWeight += currentWeight;
                
                // Track which round this token was staked in
                try ISlvrGridLottery(LOTTERY).currentRoundId() returns (uint256 currentRound) {
                    stakedAtRound[tokenId] = currentRound;
                } catch {
                    stakedAtRound[tokenId] = 0;
                }
                
                rewardPerWeightPaid[tokenId] = rewardPerWeightStored;
                _distributeUnallocatedOnTransition(tokenId, currentWeight, totalWeightBefore);
                emit Staked(tokenId, msg.sender, currentWeight);
                emit Checkpoint(tokenId, 0, currentWeight);
            }
        }

        _checkpoint(tokenId);

        uint256 reward = rewards[tokenId];
        require(reward > 0, "no rewards");

        rewards[tokenId] = 0;
        // Reduce the outstanding-rewards liability (guarded against any rounding drift).
        totalRewardsOwed = totalRewardsOwed >= reward ? totalRewardsOwed - reward : 0;

        // Transfer native tokens (ETH/ETH) as rewards
        (bool success,) = payable(msg.sender).call{value: reward}("");
        require(success, "transfer failed");

        emit RewardClaimed(tokenId, msg.sender, reward);
    }

    /// @notice Settle a token's accrued rewards to its owner immediately before the vote escrow burns
    ///         it (withdraw / convert-to-permanent). Only the vote escrow may call this.
    /// @dev Accrues on the tracked weight, removes the weight, and re-keys the rewards to `owner` as
    ///      pull-based `pendingRewardsByAddress` — otherwise the rewards would be stranded forever,
    ///      since claimStakerRewards requires ownerOf(tokenId) which reverts once the NFT is burned.
    ///      No ETH is sent here (pull-based), so a reward-rejecting owner can never brick the burn.
    /// @param tokenId The token being burned
    /// @param owner The address to credit the settled rewards to
    function claimOnBurn(uint256 tokenId, address owner) external {
        require(msg.sender == address(VOTE_ESCROW), "only voteEscrow");
        require(owner != address(0), "owner=0");

        uint256 previousWeight = balance[tokenId];
        if (previousWeight > 0) {
            uint256 rewardDelta = rewardPerWeightStored - rewardPerWeightPaid[tokenId];
            rewards[tokenId] += (previousWeight * rewardDelta) / 1e18;
            rewardPerWeightPaid[tokenId] = rewardPerWeightStored;
            totalWeight -= previousWeight;
            balance[tokenId] = 0;
            emit Checkpoint(tokenId, previousWeight, 0);
        }

        uint256 reward = rewards[tokenId];
        if (reward > 0) {
            rewards[tokenId] = 0;
            // Re-key to the owner; totalRewardsOwed stays unchanged (still owed, just pull-based now).
            pendingRewardsByAddress[owner] += reward;
            emit RewardsSettledOnBurn(tokenId, owner, reward);
        }
    }

    /// @notice Claim rewards that were settled to your address when a veNFT you owned was burned.
    function claimPendingRewards() external nonReentrant {
        uint256 reward = pendingRewardsByAddress[msg.sender];
        require(reward > 0, "no rewards");
        pendingRewardsByAddress[msg.sender] = 0;
        totalRewardsOwed = totalRewardsOwed >= reward ? totalRewardsOwed - reward : 0;
        (bool success,) = payable(msg.sender).call{value: reward}("");
        require(success, "transfer failed");
        emit PendingRewardsClaimed(msg.sender, reward);
    }

    /// @notice Get staker rewards for a specific NFT (view function)
    /// @param tokenId Vote escrow NFT token ID
    /// @return claimableRewards Current claimable rewards
    function getStakerRewards(uint256 tokenId) external view returns (uint256 claimableRewards) {
        uint256 previousWeight = balance[tokenId];

        if (previousWeight > 0) {
            // Use previousWeight (tracked weight) to calculate pending rewards, matching _checkpoint logic
            uint256 rewardDelta = rewardPerWeightStored - rewardPerWeightPaid[tokenId];
            return rewards[tokenId] + (previousWeight * rewardDelta) / 1e18;
        }

        // Not currently staked (previousWeight == 0): no pending accrual. A never-staked token has
        // rewardPerWeightPaid == 0, so multiplying by the full rewardPerWeightStored history here
        // would report a wildly inflated phantom balance; the real claim path stakes first (setting
        // rewardPerWeightPaid = rewardPerWeightStored) and accrues ~0, so pending is simply 0.
        return rewards[tokenId];
    }

    /// @notice Get total weight across all staked tokens
    /// @return Total tracked weight
    function getTotalWeight() external view returns (uint256) {
        return totalWeight;
    }

    /// @notice Get tracked weight for a specific token
    /// @param tokenId Vote escrow NFT token ID
    /// @return Tracked weight for token
    function getTrackedWeight(uint256 tokenId) external view returns (uint256) {
        return balance[tokenId];
    }

    /// @notice Receive native tokens (for reward distribution)
    receive() external payable {
        revert("use distributeRoundRewards");
    }
    
    /// @notice Sweep excess ETH that was forced in via selfdestruct or other mechanisms
    /// @param to Address to send excess ETH to
    function sweepExcess(address to) external onlyOwner {
        require(to != address(0), "to=0");
        // Owed = parked (no-staker) funds + distributed-but-unclaimed staker rewards.
        // Only balance beyond this (e.g. force-fed via selfdestruct) is truly excess.
        uint256 accounted = unallocated + totalRewardsOwed;
        uint256 bal = address(this).balance;
        if (bal > accounted) {
            uint256 excess = bal - accounted;
            (bool success,) = payable(to).call{value: excess}("");
            require(success, "transfer failed");
        }
    }
    
    /// @notice Sweep unallocated rewards to a specified address (owner-only)
    /// @param to Address to send unallocated rewards to
    function sweepUnallocated(address to) external onlyOwner {
        require(to != address(0), "to=0");
        uint256 amount = unallocated;
        if (amount > 0) {
            unallocated = 0;
            (bool success,) = payable(to).call{value: amount}("");
            require(success, "transfer failed");
        }
    }
}
