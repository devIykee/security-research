// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title MathLib
/// @notice Library for fixed-point math operations using WAD (1e18)
library MathLib {
    uint256 internal constant WAD = 1e18;
    uint16 internal constant BPS = 10_000;

    /// @notice Multiply by WAD (fixed-point multiplication)
    function wadMul(uint256 a, uint256 b) internal pure returns (uint256) {
        return (a * b) / WAD;
    }

    /// @notice Divide by WAD (fixed-point division)
    function wadDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        return (a * WAD) / b;
    }

    /// @notice Calculate fee using basis points
    function calculateFee(uint256 amount, uint16 feeBps) internal pure returns (uint256) {
        return (amount * feeBps) / BPS;
    }

    /// @notice Calculate amount after fee
    function amountAfterFee(uint256 amount, uint16 feeBps) internal pure returns (uint256) {
        return amount - calculateFee(amount, feeBps);
    }

    /// @notice Calculate payout multiplier (WAD-scaled)
    function calculatePayoutMultiplier(uint256 totalPayout, uint256 totalBets) internal pure returns (uint256) {
        if (totalBets == 0) return 0;
        return wadDiv(totalPayout, totalBets);
    }

    /// @notice Calculate payout from bet and multiplier
    function calculatePayout(uint256 bet, uint256 multiplierWad) internal pure returns (uint256) {
        return wadMul(bet, multiplierWad);
    }

    /// @notice Calculate index increment for ORE-style checkpointing
    function calculateIndexIncrement(uint256 fee, uint256 totalUnclaimed) internal pure returns (uint256) {
        if (totalUnclaimed == 0) return 0;
        return (fee * WAD) / totalUnclaimed;
    }

    /// @notice Calculate refined rewards delta
    function calculateRefinedDelta(uint256 unclaimed, uint256 indexDelta) internal pure returns (uint256) {
        return (unclaimed * indexDelta) / WAD;
    }
}
