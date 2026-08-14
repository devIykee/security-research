// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.20;

import {TickMath} from "@cryptoalgebra/integral-core/contracts/libraries/TickMath.sol";
import {FullMath} from "@cryptoalgebra/integral-core/contracts/libraries/FullMath.sol";

import {AdaptiveFee} from "../libraries/AdaptiveFee.sol";
import {AlgebraFeeConfiguration} from "../base/AlgebraFeeConfiguration.sol";
import {
    AlgebraFeeConfigurationU144,
    AlgebraFeeConfigurationU144Lib
} from "../types/AlgebraFeeConfigurationU144.sol";
import {ISheriffPlugin} from "../interfaces/ISheriffPlugin.sol";
import {IAlgebraPoolMinimal} from "../interfaces/IAlgebraPoolMinimal.sol";

/// @title SheriffFeeHelper
/// @notice External helper to calculate dynamic/sliding fees matching beforeSwap behavior
/// @dev Reads state from existing plugin contracts and simulates fee calculations
contract SheriffFeeHelper {
    using AlgebraFeeConfigurationU144Lib for AlgebraFeeConfiguration;

    /// @dev Matches VolatilityOracle.WINDOW
    uint32 internal constant WINDOW = 1 days;

    /// @dev Matches SlidingFeePlugin.FEE_FACTOR_SHIFT
    uint64 internal constant FEE_FACTOR_SHIFT = 96;

    /// @dev Matches SlidingFeePlugin.FACTOR_DENOMINATOR
    int16 internal constant FACTOR_DENOMINATOR = 1000;

    /// @dev Factor representing 1.0x multiplier (1 << 96)
    uint128 internal constant ONE_FACTOR = uint128(1) << FEE_FACTOR_SHIFT;

    /// @dev Maximum factor (2 << 96)
    uint128 internal constant MAX_FACTOR = uint128(2) << FEE_FACTOR_SHIFT;

    // ═══════════════════════════════════════════════════════════════════════════
    // MAIN ENTRY POINTS
    // ═══════════════════════════════════════════════════════════════════════════

    /// @notice Get the dynamic/sliding fee that would be applied for a swap
    /// @dev Tries the plugin's getEffectiveFee first; falls back to manual calculation.
    /// Returns 0 if no dynamic or sliding fees are enabled (quoter should use pool's base fee)
    /// @param pool The Algebra pool address
    /// @param zeroForOne The direction of the swap
    /// @return fee The calculated fee (uint24), or 0 if dynamic/sliding fees are not applicable
    function quoteSwapFee(address pool, bool zeroForOne) external view returns (uint24 fee) {
        address plugin = IAlgebraPoolMinimal(pool).plugin();

        if (plugin == address(0)) return 0; // No plugin, quoter should use base fee

        // Try plugin's getEffectiveFee first (handles all fee logic internally)
        try ISheriffPlugin(plugin).getEffectiveFee() returns (uint24 effectiveFee) {
            return effectiveFee;
        } catch {
            bool dynamicEnabled = _getDynamicFeeEnabled(plugin);
            bool slidingEnabled = _getSlidingFeeEnabled(plugin);

            // If neither dynamic nor sliding is enabled, return 0
            if (!dynamicEnabled && !slidingEnabled) return 0;

            return _calculateSwapFee(pool, plugin, zeroForOne, dynamicEnabled, slidingEnabled);
        }
    }

    /// @notice Get detailed fee state for analysis
    /// @dev Tries the plugin's getEffectiveFee/getCurrentFee first; falls back to manual calculation
    /// @param pool The Algebra pool address
    /// @param zeroForOne The direction of the swap
    function getDetailedFeeState(address pool, bool zeroForOne)
        external
        view
        returns (
            uint24 fee,
            uint16 baseFee,
            uint128 zeroToOneFeeFactor,
            uint128 oneToZeroFeeFactor,
            bool hasDynamicFee,
            bool hasSlidingFee
        )
    {
        address plugin = IAlgebraPoolMinimal(pool).plugin();

        if (plugin == address(0)) return (0, 0, ONE_FACTOR, ONE_FACTOR, false, false);

        hasDynamicFee = _getDynamicFeeEnabled(plugin);
        hasSlidingFee = _getSlidingFeeEnabled(plugin);

        // Try plugin's direct fee functions first
        try ISheriffPlugin(plugin).getEffectiveFee() returns (uint24 effectiveFee) {
            uint16 pluginBaseFee = ISheriffPlugin(plugin).getBaseFee();
            return (effectiveFee, pluginBaseFee, ONE_FACTOR, ONE_FACTOR, hasDynamicFee, hasSlidingFee);
        } catch {
            if (!hasDynamicFee && !hasSlidingFee) return (0, 0, ONE_FACTOR, ONE_FACTOR, false, false);

            // Get base/dynamic fee
            if (hasDynamicFee) baseFee = _getDynamicFee(plugin);
            else baseFee = _getSlidingBaseFee(plugin);

            // Get sliding fee factors
            if (hasSlidingFee) {
                (, int24 currentTick,,,,) = IAlgebraPoolMinimal(pool).globalState();
                int24 lastTick = _getLastTick(plugin);

                if (currentTick != lastTick) {
                    (zeroToOneFeeFactor, oneToZeroFeeFactor) =
                        _calculateFeeFactors(plugin, currentTick, lastTick);
                } else {
                    (zeroToOneFeeFactor, oneToZeroFeeFactor) = _getStoredFeeFactors(plugin);
                }

                fee = _applyFeeFactor(baseFee, zeroForOne ? zeroToOneFeeFactor : oneToZeroFeeFactor);
            } else {
                zeroToOneFeeFactor = ONE_FACTOR;
                oneToZeroFeeFactor = ONE_FACTOR;
                fee = baseFee;
            }
        }
    }

    /// @notice Batch quote fees for multiple pools
    /// @dev Returns 0 for pools without dynamic/sliding fees
    function batchQuoteSwapFees(address[] calldata pools, bool[] calldata zeroForOnes)
        external
        view
        returns (uint24[] memory fees)
    {
        require(pools.length == zeroForOnes.length, "Length mismatch");
        fees = new uint24[](pools.length);

        for (uint256 i = 0; i < pools.length; i++) {
            fees[i] = this.quoteSwapFee(pools[i], zeroForOnes[i]);
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // INTERNAL: MAIN FEE CALCULATION
    // ═══════════════════════════════════════════════════════════════════════════

    function _calculateSwapFee(
        address pool,
        address plugin,
        bool zeroForOne,
        bool dynamicEnabled,
        bool slidingEnabled
    ) internal view returns (uint16 fee) {
        // Get ticks for sliding fee calculation (matches beforeSwap order)
        (, int24 currentTick,,,,) = IAlgebraPoolMinimal(pool).globalState();
        int24 lastTick = _getLastTick(plugin);

        // Calculate dynamic fee if enabled
        if (dynamicEnabled) fee = _getDynamicFee(plugin);

        // Calculate sliding fee based on dynamic fee if enabled
        if (slidingEnabled) {
            fee = _getFeeWithSlidingAdjustment(
                plugin, zeroForOne, currentTick, lastTick, dynamicEnabled, fee
            );
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // INTERNAL: DYNAMIC FEE (Uses AdaptiveFee library)
    // ═══════════════════════════════════════════════════════════════════════════

    /// @notice Get dynamic fee using AdaptiveFee library
    function _getDynamicFee(address plugin) internal view returns (uint16 fee) {
        // Get fee config from plugin
        (
            uint16 alpha1,
            uint16 alpha2,
            uint32 beta1,
            uint32 beta2,
            uint16 gamma1,
            uint16 gamma2,
            uint16 baseFee
        ) = ISheriffPlugin(plugin).feeConfig();

        // If no alpha values, return base fee (matches _getCurrentFee logic)
        if (alpha1 | alpha2 == 0) return baseFee;

        // Get volatility average from oracle
        uint88 volatilityAverage = _getAverageVolatility(plugin);

        // Pack config using the library
        AlgebraFeeConfiguration memory config = AlgebraFeeConfiguration({
            alpha1: alpha1,
            alpha2: alpha2,
            beta1: beta1,
            beta2: beta2,
            gamma1: gamma1,
            gamma2: gamma2,
            baseFee: baseFee
        });

        AlgebraFeeConfigurationU144 packedConfig = config.pack();

        fee = AdaptiveFee.getFee(volatilityAverage, packedConfig);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // INTERNAL: SLIDING FEE (Matches SlidingFeePlugin exactly)
    // ═══════════════════════════════════════════════════════════════════════════

    /// @notice Mirrors _getFeeAndUpdateFactors but as view function
    function _getFeeWithSlidingAdjustment(
        address plugin,
        bool zeroToOne,
        int24 currentTick,
        int24 lastTick,
        bool overrideFee,
        uint16 fee
    ) internal view returns (uint16) {
        uint128 zeroToOneFeeFactor;
        uint128 oneToZeroFeeFactor;

        uint16 baseFee = overrideFee ? fee : _getSlidingBaseFee(plugin);

        if (currentTick != lastTick) {
            // Calculate new factors based on tick movement
            (zeroToOneFeeFactor, oneToZeroFeeFactor) =
                _calculateFeeFactors(plugin, currentTick, lastTick);
        } else {
            // No tick change, use stored factors
            (zeroToOneFeeFactor, oneToZeroFeeFactor) = _getStoredFeeFactors(plugin);
        }

        return _applyFeeFactor(baseFee, zeroToOne ? zeroToOneFeeFactor : oneToZeroFeeFactor);
    }

    /// @notice Mirrors SlidingFeePlugin._calculateFeeFactors exactly
    function _calculateFeeFactors(address plugin, int24 currentTick, int24 lastTick)
        internal
        view
        returns (uint128 zeroToOneFeeFactor, uint128 oneToZeroFeeFactor)
    {
        int256 tickDelta = int256(currentTick) - int256(lastTick);

        // Bound tick delta to valid range
        if (tickDelta > TickMath.MAX_TICK) tickDelta = TickMath.MAX_TICK;
        else if (tickDelta < TickMath.MIN_TICK) tickDelta = TickMath.MIN_TICK;

        // Calculate sqrt price ratio from tick delta
        uint256 sqrtPriceDelta = uint256(TickMath.getSqrtRatioAtTick(int24(tickDelta)));

        // Calculate price change ratio: (currentPrice - lastPrice) / lastPrice
        int256 priceChangeRatio = int256(FullMath.mulDiv(sqrtPriceDelta, sqrtPriceDelta, 2 ** 96))
            - int256(uint256(ONE_FACTOR));

        // Get price change factor from plugin
        uint16 priceChangeFactor = _getPriceChangeFactor(plugin);

        // Calculate fee factor impact
        int256 feeFactorImpact =
            (priceChangeRatio * int256(uint256(priceChangeFactor))) / FACTOR_DENOMINATOR;

        // Get current stored factors
        (uint128 currentZtoO, uint128 currentOtoZ) = _getStoredFeeFactors(plugin);

        // Calculate new zeroToOne factor
        int256 newZeroToOneFeeFactor = int128(currentZtoO) - feeFactorImpact;

        if (0 < newZeroToOneFeeFactor && newZeroToOneFeeFactor < int256(uint256(MAX_FACTOR))) {
            // Normal case: factors stay within bounds
            zeroToOneFeeFactor = uint128(int128(newZeroToOneFeeFactor));
            oneToZeroFeeFactor = uint128(int128(currentOtoZ) + int128(feeFactorImpact));
        } else if (newZeroToOneFeeFactor <= 0) {
            // Price decreased too much (oneToZero prevalence)
            zeroToOneFeeFactor = 0;
            oneToZeroFeeFactor = MAX_FACTOR;
        } else {
            // Price increased too much (zeroToOne prevalence)
            zeroToOneFeeFactor = MAX_FACTOR;
            oneToZeroFeeFactor = 0;
        }
    }

    /// @notice Apply fee factor to base fee (matches SlidingFeePlugin)
    function _applyFeeFactor(uint16 baseFee, uint128 feeFactor) internal pure returns (uint16) {
        uint256 adjustedFee = (uint256(baseFee) * feeFactor) >> FEE_FACTOR_SHIFT;

        if (adjustedFee > type(uint16).max) return type(uint16).max;
        else if (adjustedFee == 0) return 1;

        return uint16(adjustedFee);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // INTERNAL: VOLATILITY ORACLE
    // ═══════════════════════════════════════════════════════════════════════════

    /// @notice Get average volatility from oracle
    /// @dev Mirrors VolatilityOracle.getAverageVolatility logic
    function _getAverageVolatility(address plugin)
        internal
        view
        returns (uint88 volatilityAverage)
    {
        // Check if initialized
        if (!ISheriffPlugin(plugin).isInitialized()) return 0;

        uint32 currentTime = uint32(block.timestamp);
        uint16 lastIndex = ISheriffPlugin(plugin).timepointIndex();
        uint32 lastTimestamp = ISheriffPlugin(plugin).lastTimepointTimestamp();

        // Get current volatility cumulative
        uint88 lastCumulativeVolatility;
        bool timeAtLastTimepoint = (lastTimestamp == currentTime);

        if (timeAtLastTimepoint) {
            (,,, lastCumulativeVolatility,,,) = ISheriffPlugin(plugin).timepoints(lastIndex);
        } else {
            (, lastCumulativeVolatility) = ISheriffPlugin(plugin).getSingleTimepoint(0);
        }

        // Get oldest index
        uint16 oldestIndex = _getOldestIndex(plugin, lastIndex);

        (bool oldestInitialized, uint32 oldestTimestamp,, uint88 oldestVolatilityCumulative,,,) =
            ISheriffPlugin(plugin).timepoints(oldestIndex);

        if (!oldestInitialized) return 0;

        // Check if we have WINDOW worth of data
        // Use unchecked to allow intentional underflow that _lteConsideringOverflow handles
        uint32 windowStart;
        unchecked {
            windowStart = currentTime - WINDOW;
        }
        if (_lteConsideringOverflow(oldestTimestamp, windowStart, currentTime)) {
            // We have enough history
            // When timeAtLastTimepoint: a swap already happened this block, so the stored
            // windowStartIndex is fresh and correct - use direct interpolation (O(1))
            // When !timeAtLastTimepoint: simulate what the NEW timepoint's calculation would
            // find via getSingleTimepoint search (O(log n))
            uint88 cumulativeVolatilityAtStart = timeAtLastTimepoint
                ? _interpolateVolatilityAtWindowStart(plugin, lastIndex, currentTime)
                : _getVolatilityAtSecondsAgo(plugin, WINDOW);

            volatilityAverage = (lastCumulativeVolatility - cumulativeVolatilityAtStart) / WINDOW;
        } else if (currentTime != oldestTimestamp) {
            // Not enough history - extrapolate
            uint32 unbiasedDenominator = currentTime - oldestTimestamp;
            if (unbiasedDenominator > 1) {
                unchecked {
                    unbiasedDenominator--; // Bessel's correction
                }
            }
            volatilityAverage =
                (lastCumulativeVolatility - oldestVolatilityCumulative) / unbiasedDenominator;
        }
        // else: currentTime == oldestTimestamp, return 0
    }

    /// @notice Interpolate volatility at window start when we're at the last timepoint
    /// @dev Used when timeAtLastTimepoint == true, meaning a swap already happened this block
    /// and the stored windowStartIndex is fresh and correct for interpolation
    function _interpolateVolatilityAtWindowStart(
        address plugin,
        uint16 lastIndex,
        uint32 currentTime
    ) internal view returns (uint88) {
        (,,,,,, uint16 windowStartIndex) = ISheriffPlugin(plugin).timepoints(lastIndex);

        (, uint32 windowStartTimestamp,, uint88 windowStartVolatility,,,) =
            ISheriffPlugin(plugin).timepoints(windowStartIndex);

        (, uint32 nextTimestamp,, uint88 nextVolatility,,,) =
            ISheriffPlugin(plugin).timepoints(windowStartIndex + 1);

        uint32 timeDeltaBetweenPoints = nextTimestamp - windowStartTimestamp;

        if (timeDeltaBetweenPoints > 0) {
            return windowStartVolatility
                + (
                    (nextVolatility - windowStartVolatility)
                        * (currentTime - WINDOW - windowStartTimestamp)
                ) / timeDeltaBetweenPoints;
        } else {
            // Edge case: same timestamp (shouldn't happen in normal operation)
            return windowStartVolatility;
        }
    }

    /// @notice Get volatility cumulative at a specific seconds ago
    function _getVolatilityAtSecondsAgo(address plugin, uint32 secondsAgo)
        internal
        view
        returns (uint88)
    {
        (, uint88 volatilityCumulative) = ISheriffPlugin(plugin).getSingleTimepoint(secondsAgo);
        return volatilityCumulative;
    }

    /// @notice Get oldest timepoint index (matches VolatilityOracle.getOldestIndex)
    function _getOldestIndex(address plugin, uint16 lastIndex)
        internal
        view
        returns (uint16 oldestIndex)
    {
        unchecked {
            uint16 nextIndex = lastIndex + 1;
            (bool initialized,,,,,,) = ISheriffPlugin(plugin).timepoints(nextIndex);
            if (initialized) oldestIndex = nextIndex;
            // else oldestIndex = 0 (default)
        }
    }

    /// @notice Comparator for 32-bit timestamps (matches VolatilityOracle._lteConsideringOverflow)
    /// @dev Safe for 0 or 1 overflows
    function _lteConsideringOverflow(uint32 a, uint32 b, uint32 currentTime)
        internal
        pure
        returns (bool res)
    {
        res = a > currentTime;
        if (res == b > currentTime) res = a <= b;
    }

    /// @notice Get last recorded tick from oracle
    function _getLastTick(address plugin) internal view returns (int24) {
        uint16 lastIndex = ISheriffPlugin(plugin).timepointIndex();

        (,,,, int24 tick,,) = ISheriffPlugin(plugin).timepoints(lastIndex);

        return tick;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // INTERNAL: STATE READERS
    // ═══════════════════════════════════════════════════════════════════════════

    function _getDynamicFeeEnabled(address plugin) internal view returns (bool) {
        return ISheriffPlugin(plugin).dynamicFeeEnabled();
    }

    function _getSlidingFeeEnabled(address plugin) internal view returns (bool) {
        return ISheriffPlugin(plugin).slidingFeeEnabled();
    }

    function _getSlidingBaseFee(address plugin) internal view returns (uint16) {
        return ISheriffPlugin(plugin).s_baseFee();
    }

    function _getPriceChangeFactor(address plugin) internal view returns (uint16) {
        return ISheriffPlugin(plugin).s_priceChangeFactor();
    }

    function _getStoredFeeFactors(address plugin) internal view returns (uint128, uint128) {
        return ISheriffPlugin(plugin).s_feeFactors();
    }
}