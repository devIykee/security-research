// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {MathLib} from "./MathLib.sol";
import {ClaimLib} from "./ClaimLib.sol";
import {RoundLib} from "./RoundLib.sol";

/// @title RewardStateLib
/// @notice Library for managing reward state updates to reduce contract size
library RewardStateLib {
    using MathLib for uint256;

    struct RewardStateParams {
        uint256 reward;
        uint256 minerIndex;
        uint256 indexAtResolve;
        uint256 totalRefined;
    }

    struct RewardStateResult {
        uint256 refinedFromReward;
        uint256 newTotalRefined;
    }

    /// @notice Calculate reward amount for a user based on round type
    /// @param round The round data
    /// @param userBet User's bet amount
    /// @param user User address
    /// @return reward The calculated reward
    function calculateReward(
        RoundLib.Round storage round,
        uint256 userBet,
        address user
    ) internal view returns (uint256 reward) {
        if (round.singleMinerRound) {
            if (user == round.singleMinerWinner && round.singleMinerWinner != address(0)) {
                return round.slvrForWinners;
            }
            return 0;
        }
        if (userBet > 0) {
            return MathLib.calculatePayout(userBet, round.slvrMulWad);
        }
        return 0;
    }

    /// @notice Calculate and apply refined rewards for a new reward
    /// @param params Reward state parameters
    /// @return result Reward state result with refined amount and new total
    function applyRefinedRewards(RewardStateParams memory params)
        internal
        pure
        returns (RewardStateResult memory result)
    {
        if (params.reward == 0) {
            return result; // Returns zero values
        }

        result.refinedFromReward = ClaimLib.calculateRefinedDelta(
            params.reward,
            params.minerIndex,
            params.indexAtResolve
        );
        result.newTotalRefined = params.totalRefined + result.refinedFromReward;
    }
}

