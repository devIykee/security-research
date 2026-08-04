// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IUniswapV2Factory (minimal)
/// @notice Canonical Uniswap v2 Factory on Robinhood Chain lives at
///         0x8bceaa40b9acdfaedf85adf4ff01f5ad6517937f. We only need to look up
///         the resulting pair after migration (for the Migrated event); the
///         router creates the pair itself inside addLiquidityETH.
interface IUniswapV2Factory {
    function getPair(address tokenA, address tokenB)
        external
        view
        returns (address pair);

    function createPair(address tokenA, address tokenB)
        external
        returns (address pair);
}
