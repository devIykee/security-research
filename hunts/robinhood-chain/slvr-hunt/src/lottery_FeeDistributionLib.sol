// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ISlvrVoteEscrowStaking} from "../interfaces/ISlvrVoteEscrowStaking.sol";
import {ISlvrJackpot} from "../interfaces/ISlvrJackpot.sol";

/// @title FeeDistributionLib
/// @notice Library for distributing fees to stakers, jackpot, and team
library FeeDistributionLib {
    using SafeERC20 for IERC20;

    /// @notice Distribute staker rewards
    /// @param amount Amount to distribute (can be 0 - still calls distributeRoundRewards to advance sequencing)
    /// @param stakingContract Staking contract address
    /// @param roundId The round ID these rewards are for (used to prevent retroactive rewards)
    /// @param totalWeightSnapshot The totalWeight snapshot at reward calculation time
    /// @return success Whether distribution succeeded
    /// @return shouldCarry Whether amount should be added to carry pool
    function distributeStakerRewards(
        uint256 amount,
        address stakingContract,
        uint256 roundId,
        uint256 totalWeightSnapshot
    ) internal returns (bool success, bool shouldCarry) {
        if (stakingContract == address(0)) {
            return (false, amount > 0);
        }

        try ISlvrVoteEscrowStaking(stakingContract).distributeRoundRewards{value: amount}(roundId, totalWeightSnapshot) {
            return (true, false);
        } catch {
            return (false, true);
        }
    }

    /// @notice Add funds to jackpot
    /// @param amount Amount to add
    /// @param jackpot Jackpot contract interface
    /// @return success Whether addition succeeded
    /// @return shouldCarry Whether amount should be added to carry pool
    function addToJackpot(
        uint256 amount,
        ISlvrJackpot jackpot
    ) internal returns (bool success, bool shouldCarry) {
        if (amount == 0 || address(jackpot) == address(0)) {
            return (false, amount > 0);
        }

        try jackpot.addEth{value: amount}() {
            return (true, false);
        } catch {
            return (false, true);
        }
    }

    /// @notice Send funds to team wallet
    /// @param amount Amount to send
    /// @param teamWallet Team wallet address
    /// @return success Whether transfer succeeded
    function sendToTeam(
        uint256 amount,
        address teamWallet
    ) internal returns (bool success) {
        if (amount == 0 || teamWallet == address(0)) {
            return false;
        }

        (success,) = payable(teamWallet).call{value: amount}("");
        return success;
    }

    /// @notice Transfer native tokens
    /// @param to Recipient address
    /// @param amount Amount to transfer
    /// @return success Whether transfer succeeded
    function transferNative(address payable to, uint256 amount) internal returns (bool success) {
        if (amount == 0) {
            return true;
        }
        (success,) = to.call{value: amount}("");
        return success;
    }

    /// @notice Transfer ERC20 tokens
    /// @param token Token contract
    /// @param to Recipient address
    /// @param amount Amount to transfer
    /// @return success Whether transfer succeeded
    function transferERC20(IERC20 token, address to, uint256 amount) internal returns (bool success) {
        if (amount == 0) {
            return true;
        }
        try token.transfer(to, amount) returns (bool result) {
            return result;
        } catch {
            return false;
        }
    }
}

