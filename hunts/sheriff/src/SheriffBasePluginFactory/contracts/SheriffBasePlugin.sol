// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.20;

import "@cryptoalgebra/integral-core/contracts/libraries/Plugins.sol";
import "@cryptoalgebra/integral-core/contracts/interfaces/plugin/IAlgebraPlugin.sol";

import "./plugins/DynamicFeePlugin.sol";
import "./plugins/VolatilityOraclePlugin.sol";
import "./plugins/SlidingFeePlugin.sol";
import "./plugins/SecurityPlugin.sol";


/// @title Algebra Integral 1.2.2 plugin. Contains adaptive + sliding fee, safety switch and twap oracle
contract SheriffBasePlugin is DynamicFeePlugin, VolatilityOraclePlugin, SlidingFeePlugin, SecurityPlugin {
    using Plugins for uint8;

    /// @inheritdoc IAlgebraPlugin
    /// @dev Virtual so subclasses can declare a different hook-flag bitmap (e.g. enable
    ///      `AFTER_FLASH_FLAG` or `AFTER_POSITION_MODIFY_FLAG`, or strip `DYNAMIC_FEE` for a
    ///      pure surcharge plugin). The self-healing sentinels in `afterSwap` /
    ///      `afterModifyPosition` / `afterFlash` route through the override, so a subclass that
    ///      changes this value also gets its own value re-pinned by the sentinels.
    function defaultPluginConfig() public view virtual override returns (uint8) {
        return uint8(
            Plugins.BEFORE_POSITION_MODIFY_FLAG | Plugins.AFTER_INIT_FLAG | Plugins.BEFORE_SWAP_FLAG
                | Plugins.AFTER_SWAP_FLAG | Plugins.DYNAMIC_FEE | Plugins.BEFORE_FLASH_FLAG
        );
    }

    constructor(
        address _pool,
        address _factory,
        address _pluginFactory,
        AlgebraFeeConfiguration memory _config,
        uint16 _baseFee
    ) AlgebraBasePlugin(_pool, _factory, _pluginFactory) DynamicFeePlugin(_config) SlidingFeePlugin(_baseFee) {}

    // ###### HOOKS ######

    /// @dev Pool's first lifecycle call. Pushes `defaultPluginConfig` into the pool so the pool
    ///      starts routing subsequent hooks to this plugin. Subclass override MUST:
    ///        - preserve the `onlyPool` modifier (Solidity does not propagate modifiers through overrides)
    ///        - call `super.beforeInitialize(...)` OR replicate
    ///          `_updatePluginConfigInPool(defaultPluginConfig())` — without it the pool never routes
    ///          another hook here
    ///        - return `IAlgebraPlugin.beforeInitialize.selector` (super returns it for you)
    function beforeInitialize(address, uint160) public virtual override onlyPool returns (bytes4) {
        _updatePluginConfigInPool(defaultPluginConfig());
        return IAlgebraPlugin.beforeInitialize.selector;
    }

    /// @dev Pool's second lifecycle call. Bootstraps the TWAP oracle from the opening tick.
    ///      Subclass override MUST:
    ///        - preserve the `onlyPool` modifier
    ///        - call `super.afterInitialize(...)` BEFORE any post-init logic, OR replicate
    ///          `_initialize_TWAP(tick)` — without the oracle being initialized, every subsequent
    ///          `beforeSwap` reverts in `_writeTimepoint()` with "Not initialized"
    ///        - return `IAlgebraPlugin.afterInitialize.selector`
    function afterInitialize(address, uint160, int24 tick) public virtual override onlyPool returns (bytes4) {
        _initialize_TWAP(tick);
        return IAlgebraPlugin.afterInitialize.selector;
    }

    /// @dev Gates LP mint/burn behind the security registry. Full check on mint, burn-only check
    ///      on burn so users can always exit during a `BURN_ONLY` halt. Subclass override MUST:
    ///        - preserve the `onlyPool` modifier
    ///        - preserve the mint/burn-aware security branch via `super.beforeModifyPosition(...)`
    ///          OR mirror the `liquidity < 0 ? _checkStatusOnBurn() : _checkStatus()` split —
    ///          collapsing to a single `_checkStatus()` breaks the burn-only safety property
    ///        - return `(IAlgebraPlugin.beforeModifyPosition.selector, feeOverride)`. `super`
    ///          returns `feeOverride = 0`; overrides may substitute a per-event LP fee
    function beforeModifyPosition(address, address, int24, int24, int128 liquidity, bytes calldata)
        public
        virtual
        override
        onlyPool
        returns (bytes4, uint24)
    {
        if (liquidity < 0) {
            _checkStatusOnBurn();
        } else {
            _checkStatus();
        }
        return (IAlgebraPlugin.beforeModifyPosition.selector, 0);
    }

    /// @dev Sentinel — `AFTER_POSITION_MODIFY_FLAG` is NOT in `defaultPluginConfig`, so the pool
    ///      should never call this. The body re-pins the pool's config to `defaultPluginConfig`
    ///      as defense-in-depth against the flag being toggled externally. Subclass override MUST:
    ///        - preserve the `onlyPool` modifier
    ///        - call `super.afterModifyPosition(...)` OR replicate the config-reset; dropping it
    ///          silently removes the self-healing guard
    ///        - return `IAlgebraPlugin.afterModifyPosition.selector`
    ///      A subclass that legitimately wants after-position callbacks should override
    ///      `defaultPluginConfig()` to include `AFTER_POSITION_MODIFY_FLAG` — the sentinel here
    ///      will then route through the override and pin the pool to the subclass's value
    ///      instead of the parent's.
    function afterModifyPosition(address, address, int24, int24, int128, uint256, uint256, bytes calldata)
        public
        virtual
        override
        onlyPool
        returns (bytes4)
    {
        _updatePluginConfigInPool(defaultPluginConfig()); // should not be called, reset config
        return IAlgebraPlugin.afterModifyPosition.selector;
    }

    /// @dev Core swap hook. Executes in fixed order: security gate → snapshot pool/oracle state →
    ///      write oracle timepoint → compute dynamic + sliding fee. Subclass override MUST:
    ///        - preserve the `onlyPool` modifier
    ///        - keep `_checkStatus()` before any further work — skipping it makes the security
    ///          registry's pool-halt mechanism non-enforcing
    ///        - keep `_writeTimepoint()` on every swap — skipping it desynchronizes the TWAP,
    ///          which poisons `_getAverageVolatilityLast()` on future swaps and breaks any
    ///          external TWAP consumer (e.g. `AlgebraOracleV1TWAP`)
    ///        - ensure the returned `(feeOverride, pluginFee)` satisfies the Algebra pool's
    ///          `cache.fee = lastFee + pluginFee < 1e6` invariant — see
    ///          `SheriffFeeDecayPlugin._MAX_TOTAL_FEE` for the clamp pattern
    ///        - return `IAlgebraPlugin.beforeSwap.selector`
    ///      Wrapping subclasses (TradingLock, FeeDiscount) call `super` and either prepend a
    ///      gate or post-process the returned fee. Replacing subclasses (FeeDecay) MUST mirror
    ///      the security check + oracle write inline — those invariants are NOT optional.
    function beforeSwap(address, address, bool zeroToOne, int256, uint160, bool, bytes calldata)
        public
        virtual
        override
        onlyPool
        returns (bytes4, uint24, uint24)
    {
        uint16 newFee;
        bool _dynamicFeeEnabled = dynamicFeeEnabled;
        /// security plugin check
        _checkStatus();
        /// get ticks for slidiing fee calculation
        (, int24 currentTick,,) = _getPoolState();
        int24 lastTick = _getLastTick();
        /// write timepoint to oracle
        _writeTimepoint();
        /// calculate volatility and dynamic fee if enabled
        if (_dynamicFeeEnabled) {
            uint88 volatilityAverage = _getAverageVolatilityLast();
            newFee = _getCurrentFee(volatilityAverage);
        }
        /// calcucalate sliding fee based on dynamic fee if enabled
        if (slidingFeeEnabled) {
            newFee = _getFeeAndUpdateFactors(zeroToOne, currentTick, lastTick, _dynamicFeeEnabled, newFee);
        }

        return (IAlgebraPlugin.beforeSwap.selector, newFee, 0);
    }

    /// @dev Called by the pool after every swap — `AFTER_SWAP_FLAG` IS in `defaultPluginConfig`,
    ///      so unlike `afterModifyPosition` / `afterFlash` this is part of the normal swap path.
    ///      Body re-pins the pool's plugin config to default as defense-in-depth against runtime
    ///      config drift. Subclass override MUST:
    ///        - preserve the `onlyPool` modifier
    ///        - call `super.afterSwap(...)` OR replicate
    ///          `_updatePluginConfigInPool(defaultPluginConfig())`; dropping it silently removes
    ///          the self-healing guard
    ///        - return `IAlgebraPlugin.afterSwap.selector`
    ///      This is the natural extension point for post-swap accounting (fee routing, reward
    ///      accrual) — it runs after every swap and has the post-swap pool state available via
    ///      `_getPoolState()`.
    function afterSwap(address, address, bool, int256, uint160, int256, int256, bytes calldata)
        public
        virtual
        override
        onlyPool
        returns (bytes4)
    {
        _updatePluginConfigInPool(defaultPluginConfig());
        return IAlgebraPlugin.afterSwap.selector;
    }

    /// @dev Gates flash loans behind the security registry. Subclass override MUST:
    ///        - preserve the `onlyPool` modifier
    ///        - keep `_checkStatus()` (via `super` or replicate) — same enforcement rationale as
    ///          `beforeSwap`
    ///        - return `IAlgebraPlugin.beforeFlash.selector`
    function beforeFlash(address, address, uint256, uint256, bytes calldata)
        public
        virtual
        override
        onlyPool
        returns (bytes4)
    {
        _checkStatus();
        return IAlgebraPlugin.beforeFlash.selector;
    }

    /// @dev Sentinel — `AFTER_FLASH_FLAG` is NOT in the base `defaultPluginConfig`, so the pool
    ///      should never call this on the base. Body re-pins the pool's config to default if
    ///      the flag is ever toggled externally. Sealed (`override` only, no `virtual`) — if a
    ///      future plugin needs to react to flash completion, relax this annotation to `virtual`
    ///      and have that subclass also include `AFTER_FLASH_FLAG` in its `defaultPluginConfig()`
    ///      override; document the same `super`-or-replicate-the-reset contract as the other
    ///      sentinel hooks.
    function afterFlash(address, address, uint256, uint256, uint256, uint256, bytes calldata)
        external
        override
        onlyPool
        returns (bytes4)
    {
        _updatePluginConfigInPool(defaultPluginConfig()); // should not be called, reset config
        return IAlgebraPlugin.afterFlash.selector;
    }

    /// @dev `IAlgebraDynamicFeePlugin` getter: reports the current dynamic fee derived from
    ///      oracle volatility. Sealed (non-virtual) — subclass cannot override. Off-chain
    ///      quoters needing the true effective swap fee (sliding-fee adjustment + any
    ///      plugin-specific surcharge such as FeeDecay's launch tax) MUST go through
    ///      `SheriffFeeHelper.quoteSwapFee`, not this getter.
    function getCurrentFee() external view override returns (uint16 fee) {
        uint88 volatilityAverage = _getAverageVolatilityLast();
        fee = _getCurrentFee(volatilityAverage);
    }

    /// @dev Returns the dynamic-fee config's `baseFee` (uint16, hundredths of a bip). Distinct
    ///      from `SlidingFeePlugin.s_baseFee` (the sliding-fee base) — the two are independent
    ///      knobs and a plugin's quoter must pick the right one for the fee path it cares about.
    ///      Sealed (non-virtual) — subclass cannot override.
    function getBaseFee() external view returns (uint16) {
        return _feeConfig.baseFee();
    }
}
