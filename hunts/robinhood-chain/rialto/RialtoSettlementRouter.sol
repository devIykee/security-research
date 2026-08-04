// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.35;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { IUniswapV3SwapRouter02 } from "../interfaces/external/IUniswapV3SwapRouter02.sol";
import { IRialtoStockPool } from "./IRialtoStockPool.sol";

/// @title Sealed-basket settlement router for Robinhood's Rialto stock venue
/// @notice Presents the exact `SwapRouter02.exactInput` surface the game's typed dispatcher
///         already speaks, but fills the final hop at Rialto's oracle-NAV pools instead of a
///         Uniswap V3 pool: WETH -> USDG through the canonical SwapRouter02, then USDG -> stock
///         through the stock's Rialto pool, delivered straight to the recipient and measured by
///         balance delta (Rialto stock tokens are scaled-UI proxies; balances are the truth).
/// @dev Ownerless and stateless after construction: the four stock -> pool bindings are set
///      once and validated against each pool's actual token pair, mirroring the sealed-box
///      philosophy — a basket rotation deploys a fresh router. The sealed route's second hop
///      carries the sentinel poolFee 1 (route sealing requires nonzero V3 fees; Rialto pools
///      have no fee concept) — this router reads only the first hop's fee from the path.
contract RialtoSettlementRouter is IUniswapV3SwapRouter02 {
    using SafeERC20 for IERC20;

    error ZeroAddress();
    error UnknownStock(address stock);
    error PoolPairMismatch(address pool, address stock);
    error PoolInactiveAtDeploy(address pool);
    error UnsupportedPath();
    error TooLittleReceived(uint256 received, uint256 minimum);
    error SingleHopUnsupported();
    error ResidualBalance();

    struct StockRoute {
        IRialtoStockPool pool;
        bool zeroForOne;
        bool configured;
    }

    IERC20 public immutable weth;
    IERC20 public immutable usdg;
    /// @notice Canonical SwapRouter02 executing the WETH -> USDG hop.
    IUniswapV3SwapRouter02 public immutable canonicalRouter;

    /// @notice Set once at construction; no owner, no setters.
    mapping(address stock => StockRoute route) public stockRoutes;

    constructor(
        address weth_,
        address usdg_,
        address canonicalRouter_,
        address[4] memory stocks,
        address[4] memory pools
    ) {
        if (weth_ == address(0) || usdg_ == address(0) || canonicalRouter_ == address(0)) {
            revert ZeroAddress();
        }
        weth = IERC20(weth_);
        usdg = IERC20(usdg_);
        canonicalRouter = IUniswapV3SwapRouter02(canonicalRouter_);

        for (uint256 index = 0; index < stocks.length; ++index) {
            address stock = stocks[index];
            IRialtoStockPool pool = IRialtoStockPool(pools[index]);
            if (stock == address(0) || address(pool) == address(0)) revert ZeroAddress();

            address token0 = pool.token0();
            address token1 = pool.token1();
            bool zeroForOne;
            if (token0 == usdg_ && token1 == stock) {
                zeroForOne = true; // paying token0 (USDG) for token1 (stock)
            } else if (token1 == usdg_ && token0 == stock) {
                zeroForOne = false; // paying token1 (USDG) for token0 (stock)
            } else {
                revert PoolPairMismatch(address(pool), stock);
            }
            // Best-effort active check. isActive() reads the venue's block-number-based
            // freshness, which can underflow inside a Paris/L2-height local simulation (Orbit
            // reports the L1 number in live execution); tolerate that so deployment scripts
            // simulate, since the guard enforces isActive() on every settlement and the readiness
            // gate checks it live before launch. A clean `false` (e.g. a genuinely paused pool)
            // still reverts.
            try pool.isActive() returns (bool active) {
                if (!active) revert PoolInactiveAtDeploy(address(pool));
            } catch { }
            stockRoutes[stock] =
                StockRoute({ pool: pool, zeroForOne: zeroForOne, configured: true });
        }
    }

    /// @inheritdoc IUniswapV3SwapRouter02
    /// @dev Path MUST be the sealed two-hop WETH -> USDG -> stock form. Output goes directly to
    ///      `params.recipient` and is measured there by balance delta.
    function exactInput(ExactInputParams calldata params)
        external
        payable
        override
        returns (uint256 amountOut)
    {
        // 20 (WETH) + 3 (v3 fee) + 20 (USDG) + 3 (sentinel) + 20 (stock) = 66 bytes.
        if (params.path.length != 66) revert UnsupportedPath();
        address tokenIn = address(bytes20(params.path[0:20]));
        uint24 hopOneFee = uint24(bytes3(params.path[20:23]));
        address midToken = address(bytes20(params.path[23:43]));
        address stock = address(bytes20(params.path[46:66]));
        if (tokenIn != address(weth) || midToken != address(usdg)) revert UnsupportedPath();

        StockRoute memory route = stockRoutes[stock];
        if (!route.configured) revert UnknownStock(stock);

        // Snapshot pre-call balances. The invariant we enforce is that THIS settlement leaves no
        // new residue (balance unchanged), not that the balance is absolutely zero: an ownerless
        // contract can be force-fed 1 wei by anyone, and an absolute-zero check would let that
        // dust brick every future settlement permanently.
        uint256 wethBefore = weth.balanceOf(address(this));
        uint256 usdgBefore = usdg.balanceOf(address(this));

        // Hop 1: pull the exact WETH input from the game and swap it to USDG here.
        weth.safeTransferFrom(msg.sender, address(this), params.amountIn);
        weth.forceApprove(address(canonicalRouter), params.amountIn);
        uint256 usdgOut = canonicalRouter.exactInput(
            ExactInputParams({
                path: abi.encodePacked(address(weth), hopOneFee, address(usdg)),
                recipient: address(this),
                amountIn: params.amountIn,
                amountOutMinimum: 0
            })
        );
        // The canonical router pulls exactly what it needs; zero the allowance so none lingers
        // toward an external contract between calls.
        weth.forceApprove(address(canonicalRouter), 0);

        // Hop 2: fill at Rialto NAV straight to the recipient; the overall floor is enforced on
        // the measured delivery, which is the only number the proxies cannot misreport.
        usdg.forceApprove(address(route.pool), usdgOut);
        uint256 balanceBefore = IERC20(stock).balanceOf(params.recipient);
        route.pool.swapExactIn(route.zeroForOne, usdgOut, 0, params.recipient, block.timestamp);
        amountOut = IERC20(stock).balanceOf(params.recipient) - balanceBefore;
        usdg.forceApprove(address(route.pool), 0);

        if (amountOut < params.amountOutMinimum) {
            revert TooLittleReceived(amountOut, params.amountOutMinimum);
        }
        // The router is a pure pass-through: this settlement must not leave new WETH or USDG
        // behind (a partial fill or unexpected refund would). Compare to the pre-call snapshot so
        // pre-existing dust is tolerated but genuine leakage reverts.
        if (
            weth.balanceOf(address(this)) != wethBefore
                || usdg.balanceOf(address(this)) != usdgBefore
        ) {
            revert ResidualBalance();
        }
    }

    /// @inheritdoc IUniswapV3SwapRouter02
    /// @dev The dispatcher always uses the packed-path form; a single-hop Rialto route cannot
    ///      exist (entries are WETH, Rialto pools price in USDG).
    function exactInputSingle(ExactInputSingleParams calldata)
        external
        payable
        override
        returns (uint256)
    {
        revert SingleHopUnsupported();
    }
}
