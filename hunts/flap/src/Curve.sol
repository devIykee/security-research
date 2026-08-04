// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";

/// @title constant product bonding curve
/// @author The Flap Team
/// @dev v2
///
/// Spec:
///   - max supply: 1 Billion tokens
///   - The constant product equation is :
///         (1e9 + h  - s) * (eth + r) = k
///      - s is the current circulating supply of the token
///      - eth is the current eth reserve
///      - special case: When h = 0, k = r * 1e9
///   - estimateSupply(estimate s given eth): s = 1e9 + h - k/(r + eth)
///   - estimateReserve(estimate eth given s): eth =  k/(h + 1e9 - s) - r
///   - price estimation:  k/(h + 1e9 - s)**2
library LibCurve {
    /// @notice The curve type is represented by a struct
    /// refer to Uniswap V3 white paper.
    struct Curve {
        uint256 r; // Virtual ETH reserve
        uint256 h; // Virtual token reserve
        uint256 k; // The square of the virtual Liquidity
    }

    // The total supply of the token
    uint256 public constant TOTAL_SUPPLY = 1_000_000_000 ether;

    // custom error type

    /// @notice error if the new supply is greater than the total supply
    error SupplyExceedsTotalSupply(uint256 newSupply);

    /// @notice error if reserve is greater than the max reserve
    error ReserveExceedsMaxReserve(uint256 reserve);

    // @notice Return the estimate supply given the reserve amount
    /// @param reserve  The reserve amount
    /// @dev The resulting supply is rounded down and may even subtract small amount
    ///
    ///      This function is used when a user wants to buy tokens,
    ///      a rounded down value is more favorable to the protocol.
    function estimateSupply(Curve memory curve, uint256 reserve) internal pure returns (uint256 supply) {
        // s = 1e9 + h - k/(r + eth)
        // Round down for protocol safety when buying
        supply = TOTAL_SUPPLY + curve.h - FixedPointMathLib.divWadUp(curve.k, curve.r + reserve);
    }

    /// @notice estimate the reserve given the supply
    /// @dev This function returns a roundup value, because we want the following invariant to hold:
    ///         currReserve >= estimateReserve_without_roudup(currSupply)
    ///
    ///      This function is used when a user wants to sell tokens, a rounded up value
    ///      is more favorable to the protocol.
    function estimateReserve(Curve memory curve, uint256 supply) internal pure returns (uint256 reserve) {
        if (supply > TOTAL_SUPPLY) {
            revert SupplyExceedsTotalSupply(supply);
        }

        // eth = k/(h + 1e9 - s) - r
        // Round up for protocol safety when selling
        reserve = FixedPointMathLib.divWadUp(curve.k, TOTAL_SUPPLY + curve.h - supply) - curve.r;
    }

    /// @notice price (wei) of a token (1e18) if you buy/sell inifinitesimal amount at current supply
    function price(Curve memory curve, uint256 supply) internal pure returns (uint256) {
        // Price: k/(h + 1e9 - s)^2
        uint256 denominator = TOTAL_SUPPLY + curve.h - supply;

        if (denominator < 1e9 + 1) {
            return type(uint256).max;
        }

        // Calculate (h + 1e9 - s)^2 using mulWad for precision
        uint256 denominator_squared = FixedPointMathLib.mulWad(denominator, denominator);
        return FixedPointMathLib.divWad(curve.k, denominator_squared);
    }

    // helper from r to curve
    function fromR(uint256 r) internal pure returns (Curve memory) {
        // legacy curve: h = 0 and k = r * TOTAL_SUPPLY
        return Curve({r: r, h: 0, k: FixedPointMathLib.mulWad(r, TOTAL_SUPPLY)});
    }

    // helper from r,h,k to curve
    function fromRHK(uint256 r, uint256 h, uint256 k) internal pure returns (Curve memory) {
        return Curve({r: r, h: h, k: k});
    }

    /// @notice Return the estimate supply given the reserve amount with support for different reserve token decimals
    /// @param curve The curve parameters
    /// @param reserve The reserve amount
    /// @param reserveDecimals The number of decimals of the reserve token (must be <= 18)
    /// @dev The resulting supply is rounded down, same as estimateSupply
    ///      This function is used when a user wants to buy tokens,
    ///      a rounded down value is more favorable to the protocol.
    function estimateSupplyV2(Curve memory curve, uint256 reserve, uint8 reserveDecimals)
        internal
        pure
        returns (uint256 supply)
    {
        if (reserveDecimals > 18) {
            revert("Reserve decimals must be <= 18");
        }

        if (reserveDecimals == 18) {
            // If reserve token has 18 decimals, use the original estimateSupply function
            return estimateSupply(curve, reserve);
        }

        // Adjust the reserve to 18 decimals
        uint256 scaleFactor = 10 ** (18 - reserveDecimals);
        uint256 scaledReserve = reserve * scaleFactor;

        // Use the adjusted reserve amount
        supply = TOTAL_SUPPLY + curve.h - FixedPointMathLib.divWadUp(curve.k, curve.r + scaledReserve);
    }

    /// @notice Estimate the reserve given the supply with support for different reserve token decimals
    /// @param curve The curve parameters
    /// @param supply The token supply
    /// @param reserveDecimals The number of decimals of the reserve token (must be <= 18)
    /// @dev This function returns a roundup value, same as estimateReserve
    ///      This function is used when a user wants to sell tokens, a rounded up value
    ///      is more favorable to the protocol.
    function estimateReserveV2(Curve memory curve, uint256 supply, uint8 reserveDecimals)
        internal
        pure
        returns (uint256 reserve)
    {
        if (reserveDecimals > 18) {
            revert("Reserve decimals must be <= 18");
        }

        if (supply > TOTAL_SUPPLY) {
            revert SupplyExceedsTotalSupply(supply);
        }

        if (reserveDecimals == 18) {
            // If reserve token has 18 decimals, use the original estimateReserve function
            return estimateReserve(curve, supply);
        }

        // Calculate the reserve in 18 decimals
        uint256 scaledReserve = FixedPointMathLib.divWadUp(curve.k, TOTAL_SUPPLY + curve.h - supply) - curve.r;

        // Convert the reserve from 18 decimals to the actual reserve decimals
        uint256 scaleFactor = 10 ** (18 - reserveDecimals);

        // Divide scaled reserve by scaleFactor (rounding up)
        // For rounding up division: (a + b - 1) / b
        reserve = (scaledReserve + scaleFactor - 1) / scaleFactor;
    }
}
