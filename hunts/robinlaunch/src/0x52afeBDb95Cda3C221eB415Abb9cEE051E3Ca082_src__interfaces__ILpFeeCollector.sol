// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title ILpFeeCollector
/// @notice Minimal interface used by Factory / BondingCurve / DirectFactory to
///         register a freshly-minted Uniswap V3 LP position with the shared
///         LpFeeCollector, without depending on its full implementation.
interface ILpFeeCollector {
    /// @notice Called once by an allow-listed Factory right after it deploys a new
    ///         BondingCurve, granting that curve the right to register its own
    ///         graduation position later on.
    function onboardMinter(address minter) external;

    /// @notice Called once, in the same transaction as the LP `mint()`, by an
    ///         allow-listed minter (a BondingCurve at graduation, or a DirectFactory
    ///         at launch) to record who the position's creator is.
    function registerPosition(uint256 tokenId, address creator) external;
}
