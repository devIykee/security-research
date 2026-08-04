// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";

/// @title StockRouteRegistry
/// @notice On-chain source of truth for which Robinhood stock tokens are
///         eligible for reward conversion, and the EXACT whitelisted Uniswap V4
///         route to reach each one from WETH via the USDG hub.
///
/// Security model: the conversion adapter/keeper reads a route from here and may
/// ONLY execute that pre-approved route. It cannot choose arbitrary token
/// addresses, pools, fee tiers, hooks, recipients, or calldata. Enabling an
/// asset requires an explicit owner action backed by the off-chain liquidity
/// verification (scripts/discover-stock-liquidity.mjs, Part 2). A stock existing
/// on-chain, or a pool existing, is NOT sufficient — only VERIFIED routes are
/// usable for production launches.
contract StockRouteRegistry is Ownable2Step {
    // ---- Canonical Robinhood Chain addresses (verified Part 1) ----
    address public constant WETH = 0x0Bd7D308f8E1639FAb988df18A8011f41EAcAD73;
    address public constant USDG = 0x5fc5360D0400a0Fd4f2af552ADD042D716F1d168;
    address public constant NATIVE = address(0);

    enum StockRouteStatus {
        DISABLED, // never usable
        DISCOVERED, // a pool was found but liquidity not yet validated
        VERIFIED, // validated live: usable for production
        LOW_LIQUIDITY, // known but too thin — not usable
        PAUSED // temporarily halted by governance
    }

    /// @dev A Uniswap V4 pool identity. Plain fields (no v4-core types) so this
    ///      registry stays dependency-light; the adapter converts to PoolKey.
    struct V4Pool {
        address currency0;
        address currency1;
        uint24 fee;
        int24 tickSpacing;
        address hooks;
    }

    /// @dev WETH -> USDG -> stock, both hops single V4 pools.
    struct StockRoute {
        StockRouteStatus status;
        bool baseInputIsNative; // base hop trades native ETH (needs WETH.withdraw) vs WETH ERC20
        V4Pool baseHop; // (ETH|WETH)/USDG
        V4Pool stockHop; // USDG/stock
        uint128 maxWethPerConversion; // size cap per conversion (from Part-2 clean size)
        uint16 maxSlippageBps; // per-conversion slippage bound
        uint64 maxRouteAge; // seconds before a route must be re-validated
        uint64 lastValidatedAt; // timestamp of last live validation
    }

    /// @dev Global policy thresholds (informational + used by off-chain validator;
    ///      enforced values that matter on-chain live per-route).
    struct Thresholds {
        uint128 minPoolLiquidity;
        uint16 maxPriceImpactBps;
        uint16 maxSlippageBps;
        uint16 maxOracleDeviationBps;
        uint128 minSuccessfulQuoteSize;
        uint64 maxRouteAge;
    }

    Thresholds public thresholds;

    mapping(address stock => StockRoute) private _routes;
    address[] public routedStocks;
    mapping(address stock => bool) private _known;

    error InvalidBaseHop();
    error InvalidStockHop();
    error StockIsBaseAsset();
    error SlippageTooHigh();
    error ZeroStock();
    error UnknownStock();

    event ThresholdsUpdated(Thresholds thresholds);
    event RouteSet(address indexed stock, StockRouteStatus status, uint128 maxWethPerConversion);
    event StatusChanged(address indexed stock, StockRouteStatus status);
    event RouteValidated(address indexed stock, uint64 at);

    constructor(address initialOwner) Ownable(initialOwner) {
        thresholds = Thresholds({
            minPoolLiquidity: 1,
            maxPriceImpactBps: 300, // 3%
            maxSlippageBps: 300,
            maxOracleDeviationBps: 500,
            minSuccessfulQuoteSize: 0.05 ether,
            maxRouteAge: 7 days
        });
    }

    // ---------------------------------------------------------------- admin

    function setThresholds(Thresholds calldata t) external onlyOwner {
        thresholds = t;
        emit ThresholdsUpdated(t);
    }

    /// @notice Create or replace a stock's whitelisted route. Structural
    ///         validation guarantees the route is shaped WETH/ETH -> USDG -> stock.
    function setRoute(address stock, StockRoute calldata r) external onlyOwner {
        if (stock == address(0)) revert ZeroStock();
        if (stock == WETH || stock == USDG) revert StockIsBaseAsset();
        if (r.maxSlippageBps > 2000) revert SlippageTooHigh();

        // base hop must be (WETH or ETH) <-> USDG
        address baseTok = r.baseInputIsNative ? NATIVE : WETH;
        if (!_isPair(r.baseHop, baseTok, USDG)) revert InvalidBaseHop();
        // stock hop must be USDG <-> stock
        if (!_isPair(r.stockHop, USDG, stock)) revert InvalidStockHop();

        if (!_known[stock]) {
            _known[stock] = true;
            routedStocks.push(stock);
        }
        _routes[stock] = r;
        emit RouteSet(stock, r.status, r.maxWethPerConversion);
    }

    function setStatus(address stock, StockRouteStatus status) external onlyOwner {
        if (!_known[stock]) revert UnknownStock();
        _routes[stock].status = status;
        emit StatusChanged(stock, status);
    }

    /// @notice Record that a route was re-validated live (off-chain validator).
    function markValidated(address stock) external onlyOwner {
        if (!_known[stock]) revert UnknownStock();
        _routes[stock].lastValidatedAt = uint64(block.timestamp);
        emit RouteValidated(stock, uint64(block.timestamp));
    }

    // ---------------------------------------------------------------- views

    function getRoute(address stock) external view returns (StockRoute memory) {
        if (!_known[stock]) revert UnknownStock();
        return _routes[stock];
    }

    /// @notice True only if the route is VERIFIED and not stale.
    function isConvertible(address stock) external view returns (bool) {
        StockRoute storage r = _routes[stock];
        if (r.status != StockRouteStatus.VERIFIED) return false;
        if (r.maxRouteAge != 0 && block.timestamp > uint256(r.lastValidatedAt) + r.maxRouteAge) return false;
        return true;
    }

    function routedStocksLength() external view returns (uint256) {
        return routedStocks.length;
    }

    function isKnown(address stock) external view returns (bool) {
        return _known[stock];
    }

    // -------------------------------------------------------------- internal

    function _isPair(V4Pool calldata p, address a, address b) private pure returns (bool) {
        return (p.currency0 == a && p.currency1 == b) || (p.currency0 == b && p.currency1 == a);
    }
}
