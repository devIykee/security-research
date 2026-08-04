// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {MathLib} from "./MathLib.sol";

/// @title ClaimLib
/// @notice Library for processing claims and calculating rewards
library ClaimLib {
    using MathLib for uint256;

    struct MinerState {
        uint256 rewardsSlvr;
        uint256 indexSnapshot;
        uint256 refinedAccrued;
    }

    /// @notice Calculate refining fee for a claim
    /// @param slvrReward The SLVR reward amount
    /// @param bypassFee Whether to bypass the refining fee
    /// @param totalUnclaimed Total unclaimed SLVR
    /// @param refiningFeeBps Refining fee in basis points
    /// @return refiningFee The refining fee amount
    /// @return indexIncrement The index increment from the fee
    function calculateRefiningFee(
        uint256 slvrReward,
        bool bypassFee,
        uint256 totalUnclaimed,
        uint16 refiningFeeBps
    ) internal pure returns (uint256 refiningFee, uint256 indexIncrement) {
        if (bypassFee || slvrReward == 0 || totalUnclaimed == 0) {
            return (0, 0);
        }
        refiningFee = MathLib.calculateFee(slvrReward, refiningFeeBps);
        if (refiningFee > 0) {
            indexIncrement = MathLib.calculateIndexIncrement(refiningFee, totalUnclaimed);
        }
        return (refiningFee, indexIncrement);
    }

    /// @notice Calculate total payout amount
    /// @param slvrReward The SLVR reward amount
    /// @param refinedAccrued The refined accrued amount
    /// @param refiningFee The refining fee amount
    /// @return totalPayout Total amount to pay out
    function calculateTotalPayout(
        uint256 slvrReward,
        uint256 refinedAccrued,
        uint256 refiningFee
    ) internal pure returns (uint256 totalPayout) {
        return (slvrReward + refinedAccrued) - refiningFee;
    }

    /// @notice Calculate SLVR reward for a user
    /// @param slvrMulWad SLVR multiplier in WAD format
    /// @param userBet User's bet amount
    /// @param singleMinerRound Whether this is a single miner round
    /// @param singleMinerWinner The single miner winner address (if applicable)
    /// @param user The user address
    /// @param slvrForWinners Total SLVR for winners
    /// @return reward The calculated reward amount
    function calculateSlvrReward(
        uint256 slvrMulWad,
        uint256 userBet,
        bool singleMinerRound,
        address singleMinerWinner,
        address user,
        uint256 slvrForWinners
    ) internal pure returns (uint256 reward) {
        if (singleMinerRound) {
            // Single miner round: only winner gets all SLVR
            if (user == singleMinerWinner && singleMinerWinner != address(0)) {
                return slvrForWinners;
            }
            return 0;
        }
        // Normal round: calculate pro-rata reward based on user's bet
        if (userBet > 0) {
            return MathLib.calculatePayout(userBet, slvrMulWad);
        }
        return 0;
    }

    /// @notice Calculate refined rewards delta for a reward
    /// @param reward The reward amount
    /// @param minerIndex Current miner index
    /// @param indexAtResolve Miner index at round resolution
    /// @return refinedDelta The refined rewards delta
    function calculateRefinedDelta(
        uint256 reward,
        uint256 minerIndex,
        uint256 indexAtResolve
    ) internal pure returns (uint256 refinedDelta) {
        if (minerIndex > indexAtResolve) {
            uint256 indexDelta = minerIndex - indexAtResolve;
            return MathLib.calculateRefinedDelta(reward, indexDelta);
        }
        return 0;
    }

    /// @notice Calculate checkpoint refined delta (moved from contract to reduce size)
    /// @param rewardsSlvr User's unclaimed SLVR rewards
    /// @param minerIndex Current global miner index
    /// @param indexSnapshot User's last index snapshot
    /// @return refinedDelta The refined rewards delta
    /// @return newTotalRefined The new total refined amount
    function calculateCheckpointDelta(
        uint256 rewardsSlvr,
        uint256 minerIndex,
        uint256 indexSnapshot
    ) internal pure returns (uint256 refinedDelta, uint256 newTotalRefined) {
        if (rewardsSlvr > 0 && minerIndex > indexSnapshot) {
            uint256 indexDelta = minerIndex - indexSnapshot;
            refinedDelta = MathLib.calculateRefinedDelta(rewardsSlvr, indexDelta);
            newTotalRefined = refinedDelta; // Caller will add to totalRefined
        }
    }
}

