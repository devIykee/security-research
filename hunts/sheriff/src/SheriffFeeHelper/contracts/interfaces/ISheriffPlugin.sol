// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// @title Interface for reading Sheriff/Algebra plugin state
/// @notice Provides read access to volatility oracle and dynamic/sliding fee state
interface ISheriffPlugin {
    // ═══════════════════════════════════════════════════════════════════════════
    // VOLATILITY ORACLE
    // ═══════════════════════════════════════════════════════════════════════════

    /// @notice Get cumulative values at a specific time in the past
    /// @param secondsAgo The number of seconds ago to query
    /// @return tickCumulative The cumulative tick value
    /// @return volatilityCumulative The cumulative volatility value
    function getSingleTimepoint(uint32 secondsAgo)
        external
        view
        returns (int56 tickCumulative, uint88 volatilityCumulative);

    /// @notice Get timepoint data at a specific index
    /// @param index The index in the timepoints array
    /// @return initialized Whether the timepoint is initialized
    /// @return blockTimestamp The block timestamp of the timepoint
    /// @return tickCumulative The cumulative tick value
    /// @return volatilityCumulative The cumulative volatility value
    /// @return tick The tick at this timepoint
    /// @return averageTick The average tick at this timepoint
    /// @return windowStartIndex The index of the closest timepoint >= WINDOW seconds ago
    function timepoints(uint256 index)
        external
        view
        returns (
            bool initialized,
            uint32 blockTimestamp,
            int56 tickCumulative,
            uint88 volatilityCumulative,
            int24 tick,
            int24 averageTick,
            uint16 windowStartIndex
        );

    /// @notice Get the current timepoint index
    /// @return The index of the most recent timepoint
    function timepointIndex() external view returns (uint16);

    /// @notice Get the timestamp of the last timepoint
    /// @return The block timestamp of the last timepoint
    function lastTimepointTimestamp() external view returns (uint32);

    /// @notice Check if the oracle is initialized
    /// @return True if initialized
    function isInitialized() external view returns (bool);

    // ═══════════════════════════════════════════════════════════════════════════
    // DYNAMIC FEE
    // ═══════════════════════════════════════════════════════════════════════════

    /// @notice Check if dynamic fee is enabled
    /// @return True if dynamic fee calculation is enabled
    function dynamicFeeEnabled() external view returns (bool);

    /// @notice Get the fee configuration for dynamic fee calculation
    /// @return alpha1 Max value of the first sigmoid
    /// @return alpha2 Max value of the second sigmoid
    /// @return beta1 X-axis shift for the first sigmoid
    /// @return beta2 X-axis shift for the second sigmoid
    /// @return gamma1 Horizontal stretch factor for the first sigmoid
    /// @return gamma2 Horizontal stretch factor for the second sigmoid
    /// @return baseFee The minimum possible fee
    function feeConfig()
        external
        view
        returns (
            uint16 alpha1,
            uint16 alpha2,
            uint32 beta1,
            uint32 beta2,
            uint16 gamma1,
            uint16 gamma2,
            uint16 baseFee
        );

    // ═══════════════════════════════════════════════════════════════════════════
    // SLIDING FEE
    // ═══════════════════════════════════════════════════════════════════════════

    /// @notice Check if sliding fee is enabled
    /// @return True if sliding fee calculation is enabled
    function slidingFeeEnabled() external view returns (bool);

    /// @notice Get the current fee factors for sliding fee
    /// @return zeroToOneFeeFactor The fee factor for zeroToOne swaps
    /// @return oneToZeroFeeFactor The fee factor for oneToZero swaps
    function s_feeFactors()
        external
        view
        returns (uint128 zeroToOneFeeFactor, uint128 oneToZeroFeeFactor);

    /// @notice Get the price change factor for sliding fee calculation
    /// @return The price change factor (default 1000)
    function s_priceChangeFactor() external view returns (uint16);

    /// @notice Get the base fee for sliding fee calculation
    /// @return The base fee in hundredths of a bip
    function s_baseFee() external view returns (uint16);

    // ═══════════════════════════════════════════════════════════════════════════
    // PLUGIN FEE OVERRIDES
    // ═══════════════════════════════════════════════════════════════════════════

    /// @notice Get the base fee from the plugin
    /// @return The base fee in hundredths of a bip
    function getBaseFee() external view returns (uint16);

    /// @notice Get the effective fee after all plugin adjustments (dynamic + sliding)
    /// @return The effective fee (uint24 to support extended fee range)
    function getEffectiveFee() external view returns (uint24);
}
