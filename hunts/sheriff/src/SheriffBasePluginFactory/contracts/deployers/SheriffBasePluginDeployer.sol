// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.20;

import "contracts/SheriffBasePlugin.sol";
import "contracts/base/AlgebraFeeConfiguration.sol";

/// @title SheriffBasePluginDeployer
/// @notice Externalises the `new SheriffBasePlugin(...)` call so the parent factory's RUNTIME
///         bytecode no longer embeds the plugin's creation code. Factory's runtime drops to its
///         own logic only (~7KB); this deployer carries the plugin creation code (~21KB).
/// @dev Bound to a single factory at deployment time: the factory creates this deployer in its
///      constructor, so `msg.sender` is the factory address. All subsequent `deploy()` calls are
///      gated by that immutable binding — the plugin's `pluginFactory` storage slot is always
///      set to the factory's address, preserving the existing `_authorize()` semantics
///      (admin checks match against the factory, not against this deployer).
contract SheriffBasePluginDeployer {
    error OnlyFactory();

    address public immutable factory;

    constructor() {
        factory = msg.sender;
    }

    /// @notice Deploys a fresh SheriffBasePlugin instance. Only callable by the bound factory.
    /// @param pool The Algebra pool the plugin will be attached to.
    /// @param algebraFactory The Algebra factory address used by `_authorize` for role lookups.
    /// @param config Initial adaptive-fee configuration.
    /// @param baseFee Initial sliding-fee base (hundredths of a bip).
    /// @return plugin The newly deployed plugin's address.
    function deploy(
        address pool,
        address algebraFactory,
        AlgebraFeeConfiguration calldata config,
        uint16 baseFee
    ) external returns (address plugin) {
        if (msg.sender != factory) revert OnlyFactory();
        plugin = address(new SheriffBasePlugin(pool, algebraFactory, factory, config, baseFee));
    }
}
