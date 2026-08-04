// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {StateLibrary} from "v4-core/libraries/StateLibrary.sol";
import {FullMath} from "v4-core/libraries/FullMath.sol";
import {FixedPoint96} from "v4-core/libraries/FixedPoint96.sol";
import {BPS, VaultParams} from "./Params.sol";
import {IParamRegistry} from "./interfaces/ILoxley.sol";

/// @notice Clamped-EMA price feed for every token the vault touches, sourced from the token's
/// v4 pool against USDG. Prices are USDG-wei (6 decimals) per whole token (1e18 raw units).
/// Anyone can update; each update moves the EMA at most emaMaxStepBps, so a single-block spot
/// manipulation cannot swing the value the buyback crank triggers on. The feed's pool doubles
/// as the VaultManager's swap route — one timelocked source of truth per token.
///
/// ETH uses the pseudo-token address(0) with the canonical ETH/USDG pool.
contract MarkOracle {
    using PoolIdLibrary for PoolKey;
    using StateLibrary for IPoolManager;

    uint256 public constant TIMELOCK = 48 hours;

    struct Feed {
        PoolKey key;
        bool tokenIsCurrency0;
        bool exists;
        uint128 ema; // USDG-wei per whole token
        uint64 lastUpdate;
    }

    struct PendingFeed {
        PoolKey key;
        bool tokenIsCurrency0;
        uint64 eta;
    }

    IPoolManager public immutable poolManager;
    IParamRegistry public immutable registry;
    bool public feedsLocked;

    mapping(address token => Feed) internal _feeds;
    mapping(address token => PendingFeed) internal _pending;

    event FeedSet(address indexed token, PoolId indexed poolId, bool tokenIsCurrency0);
    event FeedQueued(address indexed token, PoolId indexed poolId, uint64 eta);
    event Updated(address indexed token, uint256 spot, uint256 ema);

    error NotAuthorized();
    error FeedMissing();
    error NothingQueued();
    error TimelockNotElapsed();
    error PoolMismatch();
    error CounterassetMismatch();
    error PoolNotLive();

    constructor(address poolManager_, address registry_) {
        poolManager = IPoolManager(poolManager_);
        registry = IParamRegistry(registry_);
    }

    // ------------------------------------------------------------------
    // feed governance: the ParamRegistry owner (deployer at genesis, the
    // governance multisig once it accepts ownership) sets genesis feeds,
    // then locks; all later changes wait out the 48h timelock
    // ------------------------------------------------------------------

    function setFeed(address token, PoolKey calldata key, bool tokenIsCurrency0) external {
        if (msg.sender != registry.owner() || feedsLocked) revert NotAuthorized();
        _installFeed(token, key, tokenIsCurrency0);
    }

    function lockFeeds() external {
        if (msg.sender != registry.owner()) revert NotAuthorized();
        feedsLocked = true;
    }

    function queueFeed(address token, PoolKey calldata key, bool tokenIsCurrency0) external {
        if (msg.sender != registry.owner()) revert NotAuthorized();
        _validateFeed(token, key, tokenIsCurrency0);
        _pending[token] = PendingFeed(key, tokenIsCurrency0, uint64(block.timestamp + TIMELOCK));
        emit FeedQueued(token, key.toId(), _pending[token].eta);
    }

    function applyFeed(address token) external {
        PendingFeed memory p = _pending[token];
        if (p.eta == 0) revert NothingQueued();
        if (block.timestamp < p.eta) revert TimelockNotElapsed();
        _installFeed(token, p.key, p.tokenIsCurrency0);
        delete _pending[token];
    }

    // ------------------------------------------------------------------
    // pricing
    // ------------------------------------------------------------------

    function hasFeed(address token) external view returns (bool) {
        return _feeds[token].exists;
    }

    function feedOf(address token) external view returns (PoolKey memory key, bool tokenIsCurrency0) {
        Feed storage f = _feeds[token];
        if (!f.exists) revert FeedMissing();
        return (f.key, f.tokenIsCurrency0);
    }

    /// @notice Current pool spot, USDG-wei per whole token.
    function spotOf(address token) public view returns (uint256) {
        Feed storage f = _feeds[token];
        if (!f.exists) revert FeedMissing();
        (uint160 sqrtPriceX96,,,) = poolManager.getSlot0(f.key.toId());
        if (f.tokenIsCurrency0) {
            // price = currency1 per currency0 = USDG per token: (sqrtP^2 / 2^192) * 1e18
            uint256 num = FullMath.mulDiv(sqrtPriceX96, sqrtPriceX96, FixedPoint96.Q96);
            return FullMath.mulDiv(num, 1e18, FixedPoint96.Q96);
        } else {
            // token is currency1: invert
            uint256 num = FullMath.mulDiv(FixedPoint96.Q96, FixedPoint96.Q96, sqrtPriceX96);
            return FullMath.mulDiv(num, 1e18, sqrtPriceX96);
        }
    }

    function emaOf(address token) external view returns (uint256) {
        Feed storage f = _feeds[token];
        if (!f.exists) revert FeedMissing();
        return f.ema == 0 ? spotOf(token) : f.ema;
    }

    /// @notice Fold the current spot into the EMA. Permissionless; the clamp bounds every
    /// update to emaMaxStepBps regardless of how hard spot was pushed this block.
    function update(address token) external returns (uint256) {
        Feed storage f = _feeds[token];
        if (!f.exists) revert FeedMissing();
        uint256 spot = spotOf(token);

        if (f.ema == 0) {
            f.ema = uint128(_min(spot, type(uint128).max));
            f.lastUpdate = uint64(block.timestamp);
            emit Updated(token, spot, f.ema);
            return f.ema;
        }

        uint256 elapsed = block.timestamp - f.lastUpdate;
        if (elapsed == 0) return f.ema;
        VaultParams memory vp = registry.getVaultParams();

        // linear approximation of exponential decay, capped at half-way per update
        uint256 ema = f.ema;
        uint256 window = elapsed >= vp.emaHalfLife ? vp.emaHalfLife : elapsed;
        uint256 move;
        if (spot > ema) {
            move = (spot - ema) * window / (uint256(vp.emaHalfLife) * 2);
            uint256 cap = ema * vp.emaMaxStepBps / BPS;
            if (move > cap) move = cap;
            ema += move;
        } else {
            move = (ema - spot) * window / (uint256(vp.emaHalfLife) * 2);
            uint256 cap = ema * vp.emaMaxStepBps / BPS;
            if (move > cap) move = cap;
            ema -= move;
        }

        f.ema = uint128(_min(ema, type(uint128).max));
        f.lastUpdate = uint64(block.timestamp);
        emit Updated(token, spot, f.ema);
        return f.ema;
    }

    function _min(uint256 a, uint256 b) private pure returns (uint256) {
        return a < b ? a : b;
    }

    function _installFeed(address token, PoolKey memory key, bool tokenIsCurrency0) internal {
        _validateFeed(token, key, tokenIsCurrency0);
        _feeds[token] = Feed(key, tokenIsCurrency0, true, 0, 0);
        emit FeedSet(token, key.toId(), tokenIsCurrency0);

        uint256 spot = spotOf(token);
        if (spot == 0) revert PoolNotLive();
        Feed storage f = _feeds[token];
        f.ema = uint128(_min(spot, type(uint128).max));
        f.lastUpdate = uint64(block.timestamp);
        emit Updated(token, spot, f.ema);
    }

    function _validateFeed(address token, PoolKey memory key, bool tokenIsCurrency0) internal view {
        address c0 = Currency.unwrap(key.currency0);
        address c1 = Currency.unwrap(key.currency1);
        if (tokenIsCurrency0 ? c0 != token : c1 != token) revert PoolMismatch();
        address counter = tokenIsCurrency0 ? c1 : c0;
        address expectedCounter = _expectedCounterasset(token);
        if (expectedCounter != address(0) && counter != expectedCounter) revert CounterassetMismatch();
        (uint160 sqrtPriceX96,,,) = poolManager.getSlot0(key.toId());
        if (sqrtPriceX96 == 0) revert PoolNotLive();
    }

    function _expectedCounterasset(address token) internal view returns (address) {
        Feed storage ethFeed = _feeds[address(0)];
        if (!ethFeed.exists) return address(0);
        address c0 = Currency.unwrap(ethFeed.key.currency0);
        address c1 = Currency.unwrap(ethFeed.key.currency1);
        address ethCounter = ethFeed.tokenIsCurrency0 ? c1 : c0;
        if (token == address(0)) return ethCounter;
        return ethCounter;
    }
}
