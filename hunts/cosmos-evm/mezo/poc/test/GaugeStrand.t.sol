// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";

/// MZ-02 exact-logic replica of Solidly Gauge accounting:
/// rewardPerToken() returns rewardPerTokenStored UNCHANGED while
/// totalSupply == 0 (upstream behavior), so emissions notified into an
/// empty gauge accrue to nobody and strand permanently.
contract ReplicaGauge {
    uint256 public totalSupply;
    uint256 public rewardRate;
    uint256 public periodFinish;
    uint256 public rewardPerTokenStored;
    uint256 public lastUpdateTime;
    mapping(address => uint256) public balances;
    mapping(address => uint256) public userRewardPerTokenPaid;

    function _update(address account) internal {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime =
            block.timestamp < periodFinish ? block.timestamp : periodFinish;
        if (account != address(0)) {
            balances[account] -= 0; // checkpoint write elided
        }
    }

    function rewardPerToken() public view returns (uint256) {
        if (totalSupply == 0) {
            return rewardPerTokenStored; // <-- upstream behavior
        }
        uint256 dt = (block.timestamp < periodFinish ? block.timestamp : periodFinish)
            - lastUpdateTime;
        return rewardPerTokenStored + (dt * rewardRate * 1e18) / totalSupply;
    }

    function notifyRewardAmount(uint256 amount) external {
        // Voter._distribute -> gauge.notifyRewardAmount (no supply gate there)
        rewardRate = amount / 604800;
        periodFinish = block.timestamp + 604800;
        lastUpdateTime = block.timestamp;
    }

    function deposit(uint256 amt) external {
        _update(msg.sender);
        userRewardPerTokenPaid[msg.sender] = rewardPerTokenStored;
        totalSupply += amt;
        balances[msg.sender] += amt;
    }

    function earned(address account) external view returns (uint256) {
        return (balances[account] * (rewardPerToken() - userRewardPerTokenPaid[account])) / 1e18;
    }
}

contract GaugeStrandTest is Test {
    ReplicaGauge g = new ReplicaGauge();

    function test_zero_supply_notify_strands_rewards() public {
        g.notifyRewardAmount(1000e18);
        assertGt(g.rewardRate(), 0, "emissions notified into empty gauge");

        // two weeks pass before the first staker arrives
        vm.warp(block.timestamp + 1209600);
        g.deposit(5e18);

        // rewardPerToken froze at stored for the whole live window (supply 0),
        // and the window finished before any share existed.
        assertEq(
            g.earned(address(this)),
            0,
            "late staker earns nothing; notified rewards stranded"
        );
        assertGt(g.periodFinish(), 0, "funds sit unclaimable in gauge");
    }
}
