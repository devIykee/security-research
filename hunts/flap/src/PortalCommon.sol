// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {IPortalCommonTypes, IPortalTypes} from "./interfaces/IPortal.sol";
import {LibCurve} from "./libraries/Curve.sol";

/// @title  The Portal Common contract
/// @notice Stateless contract containing shared functions for curve, dex threshold, and fee calculations
contract PortalCommon is IPortalCommonTypes {
    //
    // Fee Related immutables
    //

    /// @dev Buy fee rate in basis points (bps), where 1% = 100 bps
    uint256 internal immutable FLAP_BUY_FEE;

    /// @dev Sell fee rate in basis points (bps), where 1% = 100 bps
    uint256 internal immutable FLAP_SELL_FEE;

    /// @dev Liquidity fee in basis points (0-10000, where 100 = 1%)
    uint256 internal immutable LIQUIDITY_FEE;

    /// @dev Reserve fee in basis points (0-10000, where 100 = 1%)
    uint256 internal immutable RESERVE_FEE;

    constructor(uint256 buyFeeRate_, uint256 sellFeeRate_, uint256 liquidityFee_, uint256 reserveFee_) {
        FLAP_BUY_FEE = buyFeeRate_;
        FLAP_SELL_FEE = sellFeeRate_;
        LIQUIDITY_FEE = liquidityFee_;
        RESERVE_FEE = reserveFee_;
    }

    /// @dev get curve by type
    function _curveByType(CurveType curveType) internal pure returns (LibCurve.Curve memory) {
        if (curveType == CurveType.CURVE_LEGACY_15) {
            // BSC Legacy
            return LibCurve.fromR(15 ether);
        } else if (curveType == CurveType.CURVE_4) {
            // BSC Legacy
            return LibCurve.fromR(4 ether);
        } else if (curveType == CurveType.CURVE_4M) {
            // New: 4M
            return LibCurve.fromR(4e6 ether);
        } else if (curveType == CurveType.CURVE_0_974) {
            // MONAD TESTNET
            return LibCurve.fromR(0.974 ether);
        } else if (curveType == CurveType.CURVE_0_5) {
            // BASE/MORPH
            return LibCurve.fromR(0.5 ether);
        } else if (curveType == CurveType.CURVE_500) {
            // Custom: r = 500
            return LibCurve.fromR(500 ether);
        } else if (curveType == CurveType.CURVE_2) {
            // BSC Latest
            return LibCurve.fromR(2 ether);
        } else if (curveType == CurveType.CURVE_6) {
            // BSC Tax Token
            return LibCurve.fromR(6 ether);
        } else if (curveType == CurveType.CURVE_28) {
            // Custom: r = 28
            return LibCurve.fromR(28 ether);
        } else if (curveType == CurveType.CURVE_21_25) {
            // Custom: r = 21.25
            return LibCurve.fromR(21.25 ether);
        } else if (curveType == CurveType.CURVE_RH_28D25_108002126) {
            // Custom: r = 28.25, h = 108002126, k = 31301060059.5
            return LibCurve.fromRHK(28.25 ether, 108002126 ether, 31301060059.5 ether);
        } else if (curveType == CurveType.CURVE_RH_14981_108002125) {
            // Custom: r = 14981, h = 108002125, k = 16598979834625
            return LibCurve.fromRHK(14981 ether, 108002125 ether, 16598979834625 ether);
        } else if (curveType == CurveType.CURVE_RH_TOSHI_MORPH_2ETH) {
            // TOSHI/MORPH 2ETH curve: r = 0.7672, h = 107036751, k = 849318595.3672
            return LibCurve.fromRHK(0.7672 ether, 107036751 ether, 849318595.3672 ether);
        } else if (curveType == CurveType.CURVE_RH_TOSHI) {
            // TOSHI Curve: r = 6140351, h = 107036752, k = 6797594227179952
            return LibCurve.fromRHK(6140351 ether, 107036752 ether, 6797594227179952 ether);
        } else if (curveType == CurveType.CURVE_RH_BGB) {
            // BGB curve: r = 767.5, h = 107036752, k = 849650707160
            return LibCurve.fromRHK(767.5 ether, 107036752 ether, 849650707160 ether);
        } else if (curveType == CurveType.CURVE_RH_BNB) {
            // BNB Curve: r = 6.14, h = 107036752, k = 6797205657.28
            return LibCurve.fromRHK(6.14 ether, 107036752 ether, 6797205657.28 ether);
        } else if (curveType == CurveType.CURVE_RH_USD) {
            // USD curve: r = 3837, h = 107036752, k = 4247700017424
            return LibCurve.fromRHK(3837 ether, 107036752 ether, 4247700017424 ether);
        } else if (curveType == CurveType.CURVE_RH_MONAD) {
            // MONAD curve: r = 50000, h = 107036752, k = 55351837600000
            return LibCurve.fromRHK(50000 ether, 107036752 ether, 55351837600000 ether);
        } else if (curveType == CurveType.CURVE_RH_MONAD_V2) {
            // MONAD V2 curve: r = 107400, h = 107036752, k = 118895747164800
            return LibCurve.fromRHK(107400 ether, 107036752 ether, 118895747164800 ether);
        } else if (curveType == CurveType.CURVE_RH_KGST) {
            // KGST curve: r = 380000, h = 107036752, k = 420673965760000
            return LibCurve.fromRHK(380000 ether, 107036752 ether, 420673965760000 ether);
        } else if (curveType == CurveType.CURVE_RH_TOSHI_5ETH) {
            // TOSHI native ETH 5 ETH graduation curve: r = 1.9189797, h = 107036752, k = 2124381054.2419344
            return LibCurve.fromRHK(1.9189797 ether, 107036752 ether, 2124381054.2419344 ether);
        } else if (curveType == CurveType.CURVE_RH_BNB_1X5_32BNB) {
            // BNB 1.5x curve: r = 142.38367176, h = 3359591794, k = 620734687004.48553744 - 1.5x price ratio, 32 BNB net graduation
            return LibCurve.fromRHK(142.38367176 ether, 3359591794 ether, 620734687004.48553744 ether);
        } else {
            revert InvalidCurveType(curveType);
        }
    }

    /// @dev get dex threshold by dex thresh type
    function _dexThresholdByType(DexThreshType dexThreshType) internal pure returns (uint256) {
        if (dexThreshType == DexThreshType.TWO_THIRDS) {
            return 6.67e8 ether;
        } else if (dexThreshType == DexThreshType.FOUR_FIFTHS) {
            return 8e8 ether;
        } else if (dexThreshType == DexThreshType.HALF) {
            return 5e8 ether;
        } else if (dexThreshType == DexThreshType._95_PERCENT) {
            return 9.5e8 ether;
        } else if (dexThreshType == DexThreshType._81_PERCENT) {
            return 8.1e8 ether;
        } else if (dexThreshType == DexThreshType._1_PERCENT) {
            return 0.1e8 ether;
        } else {
            // invalid return 0
            return 0;
        }
    }

    /// @dev Get buy fee based on fee profile
    /// @param profile The fee profile to use
    /// @return The buy fee in basis points (bps), where 1% = 100 bps
    function _buyFeeByProfile(FlapFeeProfile profile) internal view returns (uint256) {
        if (profile == FlapFeeProfile.FEE_GLOBAL_DEFAULT) {
            return FLAP_BUY_FEE;
        } else if (profile == FlapFeeProfile.FEE_FLAPSALE_V0) {
            return 100; // 1%
        } else if (profile == FlapFeeProfile.FEE_ZERO) {
            return 0; // 0% - no protocol fee
        } else {
            // Unknown profile, default to FEE_GLOBAL_DEFAULT
            return FLAP_BUY_FEE;
        }
    }

    /// @dev Get sell fee based on fee profile
    /// @param profile The fee profile to use
    /// @return The sell fee in basis points (bps), where 1% = 100 bps
    function _sellFeeByProfile(FlapFeeProfile profile) internal view returns (uint256) {
        if (profile == FlapFeeProfile.FEE_GLOBAL_DEFAULT) {
            return FLAP_SELL_FEE;
        } else if (profile == FlapFeeProfile.FEE_FLAPSALE_V0) {
            return 100; // 1%
        } else if (profile == FlapFeeProfile.FEE_ZERO) {
            return 0; // 0% - no protocol fee
        } else {
            // Unknown profile, default to FEE_GLOBAL_DEFAULT
            return FLAP_SELL_FEE;
        }
    }

    /// @dev Get liquidity fee based on fee profile
    /// @param profile The fee profile to use
    /// @return The liquidity fee in basis points (bps), where 1% = 100 bps
    function _liquidityFeeByProfile(FlapFeeProfile profile) internal view returns (uint256) {
        if (profile == FlapFeeProfile.FEE_GLOBAL_DEFAULT) {
            return LIQUIDITY_FEE;
        } else if (profile == FlapFeeProfile.FEE_FLAPSALE_V0) {
            return 0; // 0%
        } else if (profile == FlapFeeProfile.FEE_ZERO) {
            return 0; // 0% - no protocol fee
        } else {
            // Unknown profile, default to FEE_GLOBAL_DEFAULT
            return LIQUIDITY_FEE;
        }
    }

    /// @dev Get reserve fee based on fee profile
    /// @param profile The fee profile to use
    /// @return The reserve fee in basis points (bps), where 1% = 100 bps
    function _reserveFeeByProfile(FlapFeeProfile profile) internal view returns (uint256) {
        if (profile == FlapFeeProfile.FEE_GLOBAL_DEFAULT) {
            return RESERVE_FEE;
        } else if (profile == FlapFeeProfile.FEE_FLAPSALE_V0) {
            return 0; // 0%
        } else if (profile == FlapFeeProfile.FEE_ZERO) {
            return 0; // 0% - no protocol fee
        } else {
            // Unknown profile, default to FEE_GLOBAL_DEFAULT
            return RESERVE_FEE;
        }
    }
}
