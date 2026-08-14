// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.20;

import "@cryptoalgebra/integral-core/contracts/interfaces/IAlgebraFactory.sol";

import "contracts/interfaces/ISheriffBasePluginFactory.sol";
import "contracts/interfaces/plugins/IDynamicFeeManager.sol";
import "contracts/interfaces/plugins/ISecurityPlugin.sol";
import "contracts/interfaces/plugins/ISlidingFeePlugin.sol";
import "contracts/libraries/AdaptiveFee.sol";

/// @title Shared abstract base for Sheriff plugin factories
/// @notice Holds all state, admin surface, and pool-creation hook routing common to every Sheriff
///         plugin factory variant. Concrete factories supply their typed deployer via the
///         abstract `_deployPlugin` and (optionally) extra post-deploy wiring via `_postDeployWiring`.
abstract contract SheriffPluginFactory is ISheriffBasePluginFactory {
    /// @inheritdoc ISheriffBasePluginFactory
    bytes32 public constant override ALGEBRA_BASE_PLUGIN_FACTORY_ADMINISTRATOR =
        keccak256("ALGEBRA_BASE_PLUGIN_FACTORY_ADMINISTRATOR");

    /// @inheritdoc ISheriffBasePluginFactory
    address public immutable override algebraFactory;

    /// @inheritdoc ISheriffBasePluginFactory
    AlgebraFeeConfiguration public override defaultFeeConfiguration;

    /// @inheritdoc ISheriffBasePluginFactory
    /// @dev Defaults to `true` so every plugin minted from this factory has the dynamic-fee
    ///      pipeline engaged from creation. An administrator may toggle off via
    ///      `setDynamicFeeStatus(false)` if needed.
    bool public override dynamicFeeStatus = true;

    /// @inheritdoc ISheriffBasePluginFactory
    /// @dev Defaults to `true` so every plugin minted from this factory has the sliding-fee
    ///      pipeline engaged from creation. An administrator may toggle off via
    ///      `setSlidingFeeStatus(false)` if needed.
    bool public override slidingFeeStatus = true;

    /// @inheritdoc ISheriffBasePluginFactory
    address public override securityRegistry;

    /// @inheritdoc ISheriffBasePluginFactory
    uint16 public override defaultBaseFee = 3000;

    /// @inheritdoc ISheriffBasePluginFactory
    mapping(address poolAddress => address pluginAddress) public override pluginByPool;

    modifier onlyAdministrator() {
        require(
            IAlgebraFactory(algebraFactory).hasRoleOrOwner(ALGEBRA_BASE_PLUGIN_FACTORY_ADMINISTRATOR, msg.sender),
            "Only administrator"
        );
        _;
    }

    constructor(address _algebraFactory) {
        algebraFactory = _algebraFactory;
        defaultFeeConfiguration = AdaptiveFee.initialFeeConfiguration();
        emit DefaultFeeConfiguration(defaultFeeConfiguration);
        // Emit initial fee-status events so off-chain indexers see the storage defaults.
        emit DynamicFeeStatus(true);
        emit SlidingFeeStatus(true);
    }

    /*//////////////////////////////////////////////////////////////
                  EXTERNAL STATE-CHANGING FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IAlgebraPluginFactory
    function beforeCreatePoolHook(address pool, address, address, address, address, bytes calldata)
        external
        override
        returns (address)
    {
        require(msg.sender == algebraFactory);
        return _createPlugin(pool);
    }

    /// @inheritdoc IAlgebraPluginFactory
    function afterCreatePoolHook(address, address, address) external view override {
        require(msg.sender == algebraFactory);
    }

    /// @inheritdoc ISheriffBasePluginFactory
    function createPluginForExistingPool(address token0, address token1) external override returns (address) {
        IAlgebraFactory factory = IAlgebraFactory(algebraFactory);
        require(factory.hasRoleOrOwner(factory.POOLS_ADMINISTRATOR_ROLE(), msg.sender));

        address pool = factory.poolByPair(token0, token1);
        require(pool != address(0), "Pool not exist");

        return _createPlugin(pool);
    }

    /// @inheritdoc ISheriffBasePluginFactory
    function setDefaultFeeConfiguration(AlgebraFeeConfiguration calldata newConfig)
        external
        override
        onlyAdministrator
    {
        AdaptiveFee.validateFeeConfiguration(newConfig);
        defaultFeeConfiguration = newConfig;
        emit DefaultFeeConfiguration(newConfig);
    }

    /// @inheritdoc ISheriffBasePluginFactory
    function setDynamicFeeStatus(bool status) external override onlyAdministrator {
        require(status != dynamicFeeStatus);
        dynamicFeeStatus = status;
        emit DynamicFeeStatus(status);
    }

    /// @inheritdoc ISheriffBasePluginFactory
    function setSlidingFeeStatus(bool status) external override onlyAdministrator {
        require(status != slidingFeeStatus);
        slidingFeeStatus = status;
        emit SlidingFeeStatus(status);
    }

    /// @inheritdoc ISheriffBasePluginFactory
    function setDefaultBaseFee(uint16 newDefaultBaseFee) external override onlyAdministrator {
        require(defaultBaseFee != newDefaultBaseFee);
        defaultBaseFee = newDefaultBaseFee;
        emit DefaultBaseFee(newDefaultBaseFee);
    }

    /// @inheritdoc ISheriffBasePluginFactory
    function setSecurityRegistry(address _securityRegistry) external override onlyAdministrator {
        require(securityRegistry != _securityRegistry);
        securityRegistry = _securityRegistry;
        emit SecurityRegistry(_securityRegistry);
    }

    /*//////////////////////////////////////////////////////////////
                       INTERNAL STATE-CHANGING FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Per-pool plugin creation driver. Concrete factories supply the deploy call via
    ///      `_deployPlugin`; standard post-deploy wiring runs in `_postDeployWiring`, which
    ///      derived factories may override to layer in plugin-specific setters (call
    ///      `super._postDeployWiring(plugin)` first to keep the standard wiring intact).
    function _createPlugin(address pool) internal returns (address plugin) {
        require(pluginByPool[pool] == address(0), "Already created");
        plugin = _deployPlugin(pool);
        _postDeployWiring(plugin);
        pluginByPool[pool] = plugin;
    }

    /// @dev Concrete factory hook for the typed `pluginDeployer.deploy(...)` call.
    function _deployPlugin(address pool) internal virtual returns (address);

    /// @dev Standard post-deploy wiring shared by every Sheriff plugin variant. Derived factories
    ///      that need extra wiring override this and call `super._postDeployWiring(plugin)` first.
    function _postDeployWiring(address plugin) internal virtual {
        IDynamicFeeManager(plugin).changeDynamicFeeStatus(dynamicFeeStatus);
        ISecurityPlugin(plugin).setSecurityRegistry(securityRegistry);
        ISlidingFeePlugin(plugin).changeSlidingFeeStatus(slidingFeeStatus);
    }
}
