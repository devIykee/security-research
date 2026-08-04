// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {MathLib} from "./MathLib.sol";
import {RandomnessLib} from "./RandomnessLib.sol";

/// @title RoundLib
/// @notice Library for round resolution calculations
library RoundLib {
    using MathLib for uint256;

    struct Round {
        uint64 requestedAt;
        bool resolved;
        bytes32 randomnessId;
        uint256 randomnessValue; // Store the randomness value to avoid stack issues
        uint8 winningSquare;
        bool jackpotHit;
        bool singleMinerRound; // If true, full SLVR goes to one miner
        address singleMinerWinner; // Winner for single miner rounds (weighted selection)
        uint256 totalWager;
        uint256 fee;
        uint256 winnerTotal;
        uint256 potForWinners;
        uint256 slvrForWinners;
        uint256 payoutMulWad;
        uint256 slvrMulWad;
        uint256 totalUnclaimedSlvr; // Total unclaimed SLVR for refining redistribution
    }

    struct RoundData {
        uint256 totalWager;
        uint256 fee;
        uint256 winnerTotal;
        uint256 distributableNative;
        uint256 distributableSlvr;
        uint256 randomnessValue;
        uint8 winningSquare;
        bool jackpotHit;
        bool singleMinerRound;
        uint256 rv2; // Single miner randomness value
    }

    /// @notice Calculate round fee
    function calculateFee(uint256 totalWager, uint16 protocolFeeBps) internal pure returns (uint256) {
        return MathLib.calculateFee(totalWager, protocolFeeBps);
    }

    /// @notice Calculate fee split between jackpot and stakers
    /// @param totalWager Total wager amount
    /// @param protocolFeeBps Protocol fee in basis points
    /// @param jackpotFeeBps Jackpot fee in basis points (of total wager)
    /// @return fee Total protocol fee
    /// @return jackpotAmount Amount for jackpot
    /// @return stakerAmount Amount for stakers
    function calculateFeeSplit(
        uint256 totalWager,
        uint16 protocolFeeBps,
        uint16 jackpotFeeBps
    ) internal pure returns (uint256 fee, uint256 jackpotAmount, uint256 stakerAmount) {
        fee = MathLib.calculateFee(totalWager, protocolFeeBps);
        jackpotAmount = MathLib.calculateFee(totalWager, jackpotFeeBps);
        // The jackpot + staker split must come out of the protocol fee. If a misconfiguration ever
        // leaves jackpotFeeBps > protocolFeeBps, cap the jackpot at the fee (instead of underflowing
        // `fee - jackpotAmount`, which would revert and brick resolveRound for every wagered round,
        // trapping player funds). Conserves value: jackpotAmount + stakerAmount == fee.
        if (jackpotAmount > fee) jackpotAmount = fee;
        stakerAmount = fee - jackpotAmount; // Remainder goes to stakers
    }

    /// @notice Calculate actual SLVR amount for round (checking max supply)
    /// @param slvrPerRound Base SLVR per round
    /// @param currentSupply Current total supply
    /// @param maxSupply Maximum supply
    /// @param teamAllocationBps Team allocation in basis points
    /// @param growthFundAllocationBps Growth fund allocation in basis points
    /// @return actualSlvrForRound Actual SLVR that can be minted (0 if would exceed max)
    /// @return wouldExceedMax Whether minting would exceed max supply
    function calculateActualSlvrForRound(
        uint256 slvrPerRound,
        uint256 currentSupply,
        uint256 maxSupply,
        uint16 teamAllocationBps,
        uint16 growthFundAllocationBps
    ) external pure returns (uint256 actualSlvrForRound, bool wouldExceedMax) {
        uint256 teamAmount = MathLib.calculateFee(slvrPerRound, teamAllocationBps);
        uint256 growthAmount = MathLib.calculateFee(slvrPerRound, growthFundAllocationBps);
        uint256 totalMint = slvrPerRound + teamAmount + growthAmount;
        
        if (currentSupply + totalMint > maxSupply) {
            return (0, true);
        }
        return (slvrPerRound, false);
    }

    /// @notice Calculate distributable amounts
    function calculateDistributables(
        uint256 totalWager,
        uint256 fee,
        uint256 carryNativePool,
        uint256 slvrPerRound,
        uint256 carrySlvrPool
    ) external pure returns (uint256 distributableNative, uint256 distributableSlvr) {
        distributableNative = (totalWager - fee) + carryNativePool;
        distributableSlvr = slvrPerRound + carrySlvrPool;
    }

    /// @notice Process jackpot
    /// @dev Returns ETH amount to add to potForWinners (not SLVR)
    function processJackpot(
        uint256 randomnessValue,
        uint256 roundId,
        uint256 jackpotOdds,
        uint256 currentJackpotPool,
        uint256 winnerTotal
    ) external pure returns (bool hit, uint256 ethForWinners, uint256 remainingPool) {
        if (winnerTotal == 0) {
            return (false, 0, currentJackpotPool);
        }

        uint256 rv1 = RandomnessLib.deriveJackpotRandomness(randomnessValue, roundId);
        hit = RandomnessLib.checkJackpotHit(rv1, jackpotOdds);

        if (hit && currentJackpotPool > 0) {
            ethForWinners = currentJackpotPool;
            remainingPool = 0;
        } else {
            ethForWinners = 0;
            remainingPool = currentJackpotPool;
        }
    }

    /// @notice Process single miner round determination
    function processSingleMiner(uint256 randomnessValue, uint256 roundId)
        external
        pure
        returns (bool isSingleMiner, uint256 rv2)
    {
        rv2 = RandomnessLib.deriveSingleMinerRandomness(randomnessValue, roundId);
        isSingleMiner = RandomnessLib.isSingleMinerRound(rv2);
    }

    /// @notice Calculate single miner target value
    /// @param rv2 Single miner randomness value
    /// @param winnerTotal Total bets on winning square
    /// @return target Target value for winner selection
    function calculateSingleMinerTarget(uint256 rv2, uint256 winnerTotal) external pure returns (uint256 target) {
        return rv2 % winnerTotal;
    }

    /// @notice Calculate payout multipliers
    function calculatePayoutMultipliers(
        uint256 distributableNative,
        uint256 distributableSlvr,
        uint256 winnerTotal,
        bool singleMinerRound,
        uint256 rv2
    ) external pure returns (uint256 payoutMulWad, uint256 slvrMulWad) {
        if (winnerTotal == 0) {
            return (0, 0);
        }

        payoutMulWad = MathLib.calculatePayoutMultiplier(distributableNative, winnerTotal);

        if (singleMinerRound) {
            slvrMulWad = rv2 % winnerTotal; // Target value for weighted selection
        } else {
            slvrMulWad = MathLib.calculatePayoutMultiplier(distributableSlvr, winnerTotal);
        }
    }
}
