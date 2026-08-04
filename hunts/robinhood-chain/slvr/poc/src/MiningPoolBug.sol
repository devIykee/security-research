// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @dev Minimal reproduction of MiningPool claim accounting when pool is underfunded.
/// Mirrors claim() + _payout() + lastClaim update order from the live contract.
contract MiningPoolLogic {
    uint256 public rewardPerNFTPerSecond = 1 ether; // 1 token/sec for simple math
    uint256 public emissionEnd = type(uint256).max;
    uint256 public poolBalance; // simulated rewardToken balance

    struct StakeInfo {
        address owner;
        uint64 lastClaim;
    }
    mapping(uint256 => StakeInfo) public stakes;
    mapping(address => uint256[]) internal _stakedTokens;
    mapping(address => uint256) public paid; // amount actually transferred

    function seedPool(uint256 amount) external {
        poolBalance = amount;
    }

    function stake(uint256 id, address user, uint64 at) external {
        stakes[id] = StakeInfo(user, at);
        _stakedTokens[user].push(id);
    }

    function pending(address user) public view returns (uint256) {
        uint256 reward;
        uint256[] storage ids = _stakedTokens[user];
        for (uint256 i; i < ids.length; i++) {
            StakeInfo memory info = stakes[ids[i]];
            uint256 until = block.timestamp < emissionEnd ? block.timestamp : emissionEnd;
            if (until > info.lastClaim) reward += (until - info.lastClaim) * rewardPerNFTPerSecond;
        }
        return reward;
    }

    /// @notice Exact order from live MiningPool.claim + _payout
    function claim() external returns (uint256 rewardAccrued, uint256 actuallyPaid) {
        rewardAccrued = 0;
        uint256[] storage ids = _stakedTokens[msg.sender];
        for (uint256 i; i < ids.length; i++) {
            StakeInfo storage info = stakes[ids[i]];
            uint256 until = block.timestamp < emissionEnd ? block.timestamp : emissionEnd;
            if (until > info.lastClaim) {
                rewardAccrued += (until - info.lastClaim) * rewardPerNFTPerSecond;
            }
            info.lastClaim = uint64(block.timestamp); // BUG: advanced even if underpaid
        }
        require(rewardAccrued > 0, "Nothing to claim");
        uint256 pay = rewardAccrued > poolBalance ? poolBalance : rewardAccrued;
        require(pay > 0, "Pool empty");
        poolBalance -= pay;
        paid[msg.sender] += pay;
        actuallyPaid = pay;
    }
}
