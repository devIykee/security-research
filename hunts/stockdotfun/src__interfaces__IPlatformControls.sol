// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title IPlatformControls
/// @notice Pause switches exposed by StockDotFunFactory and consulted by
///         pools (trading) and vaults (claims). Separate switches so an
///         emergency can halt trading while still letting holders claim,
///         or vice versa.
interface IPlatformControls {
    function tradingPaused() external view returns (bool);
    function claimsPaused() external view returns (bool);
}
