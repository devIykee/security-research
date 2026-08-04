// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IUniswapV2Router02 (minimal)
/// @notice Only the surface PumpFactory needs to migrate liquidity: reading the
///         paired factory/WETH and adding single-sided-ETH liquidity. Matches the
///         canonical Uniswap v2 Router02 ABI so it binds to the real deployment
///         on Robinhood Chain (0x89e5db8b5aa49aa85ac63f691524311aeb649eba).
interface IUniswapV2Router02 {
    function factory() external view returns (address);

    function WETH() external view returns (address);

    /// @dev Wraps `msg.value` into WETH and pairs it with `amountTokenDesired`
    ///      of `token`. For a fresh pair (empty reserves) the router consumes the
    ///      desired amounts exactly and mints LP to `to`. `amountTokenMin` /
    ///      `amountETHMin` bound slippage against a pre-seeded pool.
    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    )
        external
        payable
        returns (uint256 amountToken, uint256 amountETH, uint256 liquidity);
}
