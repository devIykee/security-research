// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.20;

import "contracts/base/SheriffPluginFactory.sol";
import "contracts/deployers/SheriffBasePluginDeployer.sol";

/// @title Algebra Integral 1.2.2 plugin factory
/// @notice This contract creates Sheriff base plugins for Algebra liquidity pools
/// @dev This plugin factory can only be used for Algebra base pools
contract SheriffBasePluginFactory is SheriffPluginFactory {
    /// @notice External deployer that holds the plugin's creation bytecode. Created in the
    ///         factory's constructor and bound to this factory address; only the factory may
    ///         invoke its `deploy()` entry point.
    SheriffBasePluginDeployer public immutable pluginDeployer;

    constructor(address _algebraFactory) SheriffPluginFactory(_algebraFactory) {
        pluginDeployer = new SheriffBasePluginDeployer();
    }

    /*//////////////////////////////////////////////////////////////
                       INTERNAL STATE-CHANGING FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _deployPlugin(address pool) internal override returns (address) {
        return pluginDeployer.deploy(pool, algebraFactory, defaultFeeConfiguration, defaultBaseFee);
    }
}
