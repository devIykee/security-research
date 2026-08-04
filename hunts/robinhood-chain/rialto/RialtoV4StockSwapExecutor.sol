// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { IPoolManager } from "v4-core/src/interfaces/IPoolManager.sol";
import { IUnlockCallback } from "v4-core/src/interfaces/callback/IUnlockCallback.sol";
import { IHooks } from "v4-core/src/interfaces/IHooks.sol";
import { TickMath } from "v4-core/src/libraries/TickMath.sol";
import { PoolKey } from "v4-core/src/types/PoolKey.sol";
import { Currency } from "v4-core/src/types/Currency.sol";
import { BalanceDelta } from "v4-core/src/types/BalanceDelta.sol";
import { AggregatorV3Interface } from "../external/chainlink/AggregatorV3Interface.sol";
import { IStockSwapExecutor } from "../interfaces/IStockSwapExecutor.sol";
import { IWETH9 } from "../interfaces/IWETH9.sol";

interface IRialtoRouterRegistry {
    function ownerOf(uint256 featureId) external view returns (address);
}

interface IOraclePausableStockTokenV4 {
    function oraclePaused() external view returns (bool);
}

/// @notice Stock Token executor with INDEX-style Rialto routing and native ETH Uniswap v4 fallback.
/// @dev `routeData == ""` uses the stored native ETH v4 PoolKey. Non-empty routeData must be
///      abi.encode(uint8(1), deadline, rialtoRouterCalldata) and is executed only against the
///      live router resolved from the immutable Rialto registry.
contract RialtoV4StockSwapExecutor is IStockSwapExecutor, IUnlockCallback, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint8 public constant ROUTE_KIND_RIALTO = 1;
    uint256 public constant BPS = 10_000;
    uint256 public constant MAX_ROUTE_LIFETIME = 5 minutes;
    uint16 public constant MAX_CONFIGURABLE_ORACLE_SLIPPAGE_BPS = 1_000;

    struct ExecutorConfig {
        address quoteToken;
        address poolManager;
        address rialtoRegistry;
        uint256 rialtoRegistryTokenId;
        address quoteUsdFeed;
        address sequencerUptimeFeed;
        uint32 quoteFeedMaxAge;
        uint32 sequencerGracePeriod;
        uint16 maxOracleSlippageBps;
        address owner;
    }

    struct StockConfig {
        address priceFeed;
        uint32 maxAge;
        uint8 tokenDecimals;
        uint8 feedDecimals;
        uint24 v4Fee;
        int24 v4TickSpacing;
        address v4Hooks;
        bool allowed;
    }

    IERC20 public immutable quoteToken;
    IPoolManager public immutable poolManager;
    address public immutable rialtoRegistry;
    uint256 public immutable rialtoRegistryTokenId;
    AggregatorV3Interface public immutable quoteUsdFeed;
    AggregatorV3Interface public immutable sequencerUptimeFeed;
    uint32 public immutable quoteFeedMaxAge;
    uint32 public immutable sequencerGracePeriod;
    uint16 public immutable maxOracleSlippageBps;
    uint8 public immutable quoteTokenDecimals;
    uint8 public immutable quoteFeedDecimals;

    address public buyer;
    mapping(address stock => StockConfig config) public stockConfig;

    error OnlyBuyer(address caller);
    error OnlyPoolManager();
    error BuyerAlreadySet();
    error InvalidConfiguration();
    error InvalidPair(address quote, address stock);
    error InvalidRoute();
    error RouteExpired(uint256 deadline);
    error RouteLifetimeTooLong(uint256 deadline);
    error SwapCallFailed(bytes reason);
    error InvalidBalanceChange();
    error Slippage(uint256 received, uint256 minimum);
    error OraclePaused(address stock);
    error InvalidOracleAnswer(address feed);
    error StaleOracle(address feed, uint256 updatedAt, uint256 maxAge);
    error SequencerDown();
    error SequencerGracePeriod();
    error UnsafeRouter(address router);

    event BuyerBound(address indexed buyer);
    event SwapExecuted(
        address indexed stock,
        uint256 quoteSpent,
        uint256 stockReceived,
        uint256 oracleMinimum,
        uint8 routeKind
    );

    constructor(
        ExecutorConfig memory config,
        address[6] memory stocks,
        address[6] memory stockUsdFeeds,
        uint32[6] memory stockFeedMaxAges,
        uint24[6] memory v4Fees,
        int24[6] memory v4TickSpacings,
        address[6] memory v4Hooks
    ) Ownable(config.owner) {
        if (
            config.quoteToken.code.length == 0 || config.poolManager.code.length == 0
                || config.rialtoRegistry.code.length == 0 || config.quoteUsdFeed.code.length == 0
                || config.quoteFeedMaxAge == 0 || config.owner == address(0)
                || config.maxOracleSlippageBps == 0
                || config.maxOracleSlippageBps > MAX_CONFIGURABLE_ORACLE_SLIPPAGE_BPS
        ) {
            revert InvalidConfiguration();
        }
        if (
            config.sequencerUptimeFeed != address(0)
                && (config.sequencerUptimeFeed.code.length == 0 || config.sequencerGracePeriod == 0)
        ) {
            revert InvalidConfiguration();
        }

        quoteToken = IERC20(config.quoteToken);
        poolManager = IPoolManager(config.poolManager);
        rialtoRegistry = config.rialtoRegistry;
        rialtoRegistryTokenId = config.rialtoRegistryTokenId;
        quoteUsdFeed = AggregatorV3Interface(config.quoteUsdFeed);
        sequencerUptimeFeed = AggregatorV3Interface(config.sequencerUptimeFeed);
        quoteFeedMaxAge = config.quoteFeedMaxAge;
        sequencerGracePeriod = config.sequencerGracePeriod;
        maxOracleSlippageBps = config.maxOracleSlippageBps;

        uint8 cachedQuoteTokenDecimals = IERC20Metadata(config.quoteToken).decimals();
        uint8 cachedQuoteFeedDecimals = AggregatorV3Interface(config.quoteUsdFeed).decimals();
        if (cachedQuoteTokenDecimals > 18 || cachedQuoteFeedDecimals > 18) revert InvalidConfiguration();
        quoteTokenDecimals = cachedQuoteTokenDecimals;
        quoteFeedDecimals = cachedQuoteFeedDecimals;

        for (uint256 i; i < stocks.length; ++i) {
            address stock = stocks[i];
            address feed = stockUsdFeeds[i];
            address hooks = v4Hooks[i];
            if (
                stock.code.length == 0 || feed.code.length == 0 || stock == config.quoteToken
                    || stockFeedMaxAges[i] == 0 || v4Fees[i] == 0 || v4TickSpacings[i] == 0
                    || (hooks != address(0) && hooks.code.length == 0)
            ) {
                revert InvalidConfiguration();
            }
            for (uint256 j; j < i; ++j) {
                if (stock == stocks[j] || feed == stockUsdFeeds[j]) revert InvalidConfiguration();
            }

            uint8 stockDecimals = IERC20Metadata(stock).decimals();
            uint8 feedDecimals = AggregatorV3Interface(feed).decimals();
            if (stockDecimals > 18 || feedDecimals > 18) revert InvalidConfiguration();
            (bool pauseCallOk, bytes memory pauseData) =
                stock.staticcall(abi.encodeCall(IOraclePausableStockTokenV4.oraclePaused, ()));
            if (!pauseCallOk || pauseData.length < 32) revert InvalidConfiguration();

            stockConfig[stock] = StockConfig({
                priceFeed: feed,
                maxAge: stockFeedMaxAges[i],
                tokenDecimals: stockDecimals,
                feedDecimals: feedDecimals,
                v4Fee: v4Fees[i],
                v4TickSpacing: v4TickSpacings[i],
                v4Hooks: hooks,
                allowed: true
            });
        }
    }

    function setBuyer(address buyer_) external onlyOwner {
        if (buyer != address(0)) revert BuyerAlreadySet();
        if (buyer_.code.length == 0) revert InvalidConfiguration();
        buyer = buyer_;
        emit BuyerBound(buyer_);
    }

    function resolvedRialtoRouterSafe(address stock) public view returns (address router) {
        router = IRialtoRouterRegistry(rialtoRegistry).ownerOf(rialtoRegistryTokenId);
        if (
            router == address(0) || router.code.length == 0 || router == address(this)
                || router == address(quoteToken) || router == address(poolManager) || router == stock
        ) revert UnsafeRouter(router);
    }

    function execute(
        address quote,
        address stock,
        uint256 amountIn,
        uint256 minAmountOut,
        address recipient,
        bytes calldata routeData
    ) external nonReentrant returns (uint256 amountOut) {
        if (msg.sender != buyer) revert OnlyBuyer(msg.sender);
        StockConfig memory selected = stockConfig[stock];
        if (
            quote != address(quoteToken) || !selected.allowed || amountIn == 0 || minAmountOut == 0
                || recipient == address(0)
        ) {
            revert InvalidPair(quote, stock);
        }

        _validateSequencer();
        uint256 quotePrice = _validatedPrice(address(quoteUsdFeed), quoteFeedDecimals, quoteFeedMaxAge);
        if (IOraclePausableStockTokenV4(stock).oraclePaused()) revert OraclePaused(stock);
        uint256 stockPrice = _validatedPrice(selected.priceFeed, selected.feedDecimals, selected.maxAge);
        uint256 maximumSpendOracleMinimum =
            _oracleMinimum(amountIn, quotePrice, stockPrice, selected.tokenDecimals);
        uint256 maximumSpendRequired =
            minAmountOut > maximumSpendOracleMinimum ? minAmountOut : maximumSpendOracleMinimum;

        uint256 quoteStart = quoteToken.balanceOf(address(this));
        uint256 stockStart = IERC20(stock).balanceOf(address(this));
        quoteToken.safeTransferFrom(msg.sender, address(this), amountIn);
        uint256 quoteFunded = quoteToken.balanceOf(address(this));
        if (quoteFunded != quoteStart + amountIn) revert InvalidBalanceChange();

        uint8 routeKind;
        if (routeData.length == 0) {
            amountOut = _executeV4Native(stock, selected, amountIn, maximumSpendRequired);
        } else {
            routeKind = ROUTE_KIND_RIALTO;
            _executeRialto(stock, amountIn, routeData);
            amountOut = IERC20(stock).balanceOf(address(this)) - stockStart;
        }

        uint256 quoteAfter = quoteToken.balanceOf(address(this));
        if (quoteAfter < quoteStart || quoteAfter > quoteFunded) revert InvalidBalanceChange();
        uint256 quoteSpent = quoteFunded - quoteAfter;
        uint256 oracleMinimum = _oracleMinimum(quoteSpent, quotePrice, stockPrice, selected.tokenDecimals);
        uint256 required = minAmountOut > oracleMinimum ? minAmountOut : oracleMinimum;
        if (amountOut == 0 || amountOut < required) revert Slippage(amountOut, required);

        uint256 refund = quoteAfter - quoteStart;
        if (refund != 0) quoteToken.safeTransfer(msg.sender, refund);
        IERC20(stock).safeTransfer(recipient, amountOut);
        emit SwapExecuted(stock, quoteSpent, amountOut, oracleMinimum, routeKind);
    }

    function unlockCallback(bytes calldata data) external returns (bytes memory) {
        if (msg.sender != address(poolManager)) revert OnlyPoolManager();
        (address stock, uint256 amountIn, uint256 minAmountOut) =
            abi.decode(data, (address, uint256, uint256));
        StockConfig memory selected = stockConfig[stock];
        if (!selected.allowed || amountIn == 0 || amountIn > uint256(type(int256).max)) {
            revert InvalidRoute();
        }

        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(address(0)),
            currency1: Currency.wrap(stock),
            fee: selected.v4Fee,
            tickSpacing: selected.v4TickSpacing,
            hooks: IHooks(selected.v4Hooks)
        });
        BalanceDelta delta = poolManager.swap(
            key,
            IPoolManager.SwapParams({
                zeroForOne: true,
                // amountIn is checked against type(int256).max just above.
                // forge-lint: disable-next-line(unsafe-typecast)
                amountSpecified: -int256(amountIn),
                sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
            }),
            ""
        );
        uint256 out = uint256(uint128(delta.amount1()));
        if (out < minAmountOut) revert Slippage(out, minAmountOut);
        poolManager.settle{ value: amountIn }();
        poolManager.take(Currency.wrap(stock), address(this), out);
        return abi.encode(out);
    }

    function previewOracleMinimum(address stock, uint256 quoteAmount) external view returns (uint256) {
        StockConfig memory selected = stockConfig[stock];
        if (!selected.allowed || quoteAmount == 0) {
            revert InvalidPair(address(quoteToken), stock);
        }
        _validateSequencer();
        uint256 quotePrice = _validatedPrice(address(quoteUsdFeed), quoteFeedDecimals, quoteFeedMaxAge);
        if (IOraclePausableStockTokenV4(stock).oraclePaused()) revert OraclePaused(stock);
        uint256 stockPrice = _validatedPrice(selected.priceFeed, selected.feedDecimals, selected.maxAge);
        return _oracleMinimum(quoteAmount, quotePrice, stockPrice, selected.tokenDecimals);
    }

    function _executeRialto(address stock, uint256 amountIn, bytes calldata routeData) private {
        (uint8 routeKind, uint256 deadline, bytes memory callData) =
            abi.decode(routeData, (uint8, uint256, bytes));
        if (routeKind != ROUTE_KIND_RIALTO || callData.length < 4) revert InvalidRoute();
        // This deadline expires an off-chain route only; it is never used as randomness.
        // forge-lint: disable-next-line(block-timestamp)
        if (deadline < block.timestamp) revert RouteExpired(deadline);
        // forge-lint: disable-next-line(block-timestamp)
        if (deadline > block.timestamp + MAX_ROUTE_LIFETIME) revert RouteLifetimeTooLong(deadline);

        address router = resolvedRialtoRouterSafe(stock);
        quoteToken.forceApprove(router, amountIn);
        (bool success, bytes memory result) = router.call{ value: 0 }(callData);
        quoteToken.forceApprove(router, 0);
        if (!success) revert SwapCallFailed(result);
    }

    function _executeV4Native(
        address stock,
        StockConfig memory selected,
        uint256 amountIn,
        uint256 minAmountOut
    ) private returns (uint256 amountOut) {
        if (!selected.allowed || amountIn > uint256(type(int256).max)) {
            revert InvalidRoute();
        }
        uint256 nativeStart = address(this).balance;
        IWETH9(address(quoteToken)).withdraw(amountIn);
        if (address(this).balance != nativeStart + amountIn) revert InvalidBalanceChange();
        bytes memory result = poolManager.unlock(abi.encode(stock, amountIn, minAmountOut));
        if (address(this).balance != nativeStart) revert InvalidBalanceChange();
        amountOut = abi.decode(result, (uint256));
    }

    function _oracleMinimum(uint256 quoteAmount, uint256 quotePrice, uint256 stockPrice, uint8 stockDecimals)
        private
        view
        returns (uint256)
    {
        uint256 usdValue18 = Math.mulDiv(quoteAmount, quotePrice, 10 ** quoteTokenDecimals);
        uint256 fairStockAmount = Math.mulDiv(usdValue18, 10 ** stockDecimals, stockPrice);
        return Math.mulDiv(fairStockAmount, BPS - maxOracleSlippageBps, BPS);
    }

    function _validatedPrice(address feed, uint8 feedDecimals, uint32 maxAge)
        private
        view
        returns (uint256 normalizedPrice)
    {
        (uint80 roundId, int256 answer,, uint256 updatedAt, uint80 answeredInRound) =
            AggregatorV3Interface(feed).latestRoundData();
        // Timestamps enforce oracle freshness only.
        // forge-lint: disable-next-line(block-timestamp)
        if (answer <= 0 || updatedAt == 0 || updatedAt > block.timestamp || answeredInRound < roundId) {
            revert InvalidOracleAnswer(feed);
        }
        // forge-lint: disable-next-line(block-timestamp)
        if (block.timestamp - updatedAt > maxAge) revert StaleOracle(feed, updatedAt, maxAge);
        // answer is proven positive above, so this conversion cannot change its value.
        // forge-lint: disable-next-line(unsafe-typecast)
        normalizedPrice = uint256(answer) * (10 ** (18 - feedDecimals));
    }

    function _validateSequencer() private view {
        address feed = address(sequencerUptimeFeed);
        if (feed == address(0)) return;
        (, int256 answer, uint256 startedAt,,) = sequencerUptimeFeed.latestRoundData();
        if (answer != 0) revert SequencerDown();
        // Timestamps enforce Chainlink's post-recovery grace period only.
        // forge-lint: disable-next-line(block-timestamp)
        if (startedAt == 0 || startedAt > block.timestamp) revert InvalidOracleAnswer(feed);
        // forge-lint: disable-next-line(block-timestamp)
        if (block.timestamp - startedAt <= sequencerGracePeriod) revert SequencerGracePeriod();
    }

    receive() external payable { }
}
