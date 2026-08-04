// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

/// @title Helper to predict uniswap v3/v2 pool address
/// @author The Flap Team
library PoolAddress {
    /// @notice Get the address of Uniswap V3 pool
    /// @param factory The address of the Uniswap V3 factory
    /// @param initCodeHash The init code hash of the Uniswap V3 pool
    /// @param token0 The address of token0
    /// @param token1 The address of token1
    /// @param fee The fee of the pool
    function computeV3Address(address factory, bytes32 initCodeHash, address token0, address token1, uint24 fee)
        internal
        pure
        returns (address)
    {
        // https://github.com/Uniswap/v3-periphery/blob/main/contracts/libraries/PoolAddress.sol

        (token0, token1) = token0 < token1 ? (token0, token1) : (token1, token0);
        return address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(hex"ff", factory, keccak256(abi.encode(token0, token1, fee)), initCodeHash)
                    )
                )
            )
        );
    }

    /// @notice Get the address of Uniswap V2 pool
    /// @param factory The address of the Uniswap V2 factory
    /// @param initCodeHash The init code hash of the Uniswap V2 pool
    /// @param token0 The address of token0
    /// @param token1 The address of token1
    function computeV2Address(address factory, bytes32 initCodeHash, address token0, address token1)
        internal
        pure
        returns (address)
    {
        // https://github.com/Uniswap/v2-core/blob/ee547b17853e71ed4e0101ccfd52e70d5acded58/contracts/UniswapV2Factory.sol#L31

        (token0, token1) = token0 < token1 ? (token0, token1) : (token1, token0);

        return address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(hex"ff", factory, keccak256(abi.encodePacked(token0, token1)), initCodeHash)
                    )
                )
            )
        );
    }

    /// @notice Get the address of a Camelot V3 (Algebra 1.9) Pool address
    /// @param deployer The address of the deployer
    /// @param initCodeHash The init code hash of the Camelot V3 pool
    /// @param token0 The address of token0
    /// @param token1 The address of token1
    /// @dev for Algebra 1.9, the fee tier and tickSpacing is constant
    function computeAlgebraV3Address(address deployer, bytes32 initCodeHash, address token0, address token1)
        internal
        pure
        returns (address)
    {
        (token0, token1) = token0 < token1 ? (token0, token1) : (token1, token0);
        // this is not the same as the Uniswap V3 pool address
        // algebra 1.9 is using abi.encode rather than abi.encodePacked
        return address(
            uint160(
                uint256(
                    keccak256(abi.encodePacked(hex"ff", deployer, keccak256(abi.encode(token0, token1)), initCodeHash))
                )
            )
        );
    }
}
