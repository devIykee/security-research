// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// @title Minimal Algebra Pool Interface for fee helper
/// @notice Contains only the functions needed by SheriffFeeHelper
interface IAlgebraPoolMinimal {
    /// @notice Get the plugin address for this pool
    /// @return The address of the plugin contract
    function plugin() external view returns (address);

    /// @notice Get the global state of the pool
    /// @return price The current sqrt price of the pool as a Q64.96
    /// @return tick The current tick of the pool
    /// @return lastFee The last fee value
    /// @return pluginConfig The current plugin config
    /// @return communityFee The community fee percentage
    /// @return unlocked Whether the pool is currently unlocked
    function globalState()
        external
        view
        returns (
            uint160 price,
            int24 tick,
            uint16 lastFee,
            uint8 pluginConfig,
            uint16 communityFee,
            bool unlocked
        );
}
