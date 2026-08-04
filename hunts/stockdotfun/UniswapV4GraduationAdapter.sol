// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {V4LiquidityLocker} from "./V4LiquidityLocker.sol";

/// @title UniswapV4GraduationAdapter
/// @notice Turns a graduated pool's principal (WETH + reserved MEME) into a real
///         Uniswap V4 MEME/WETH pool: computes the initial sqrt price to match
///         the supplied amount ratio (the terminal curve price), then hands the
///         funds to the V4LiquidityLocker which adds and permanently locks the
///         full-range position. It holds no funds between calls and cannot be
///         pointed at an arbitrary pool (key derived from the two tokens only).
contract UniswapV4GraduationAdapter is ReentrancyGuard {
    using SafeERC20 for IERC20;
    using PoolIdLibrary for PoolKey;

    V4LiquidityLocker public immutable locker;

    error PriceOverflow();
    error ZeroAmount();

    event Graduated(bytes32 indexed poolId, address indexed meme, uint128 liquidity, uint256 wethIn, uint256 memeIn);

    constructor(address locker_) {
        locker = V4LiquidityLocker(locker_);
    }

    /// @notice Compute the sqrtPriceX96 for price = amount1/amount0 (currency1
    ///         per currency0), i.e. sqrt(amount1/amount0) * 2**96.
    function sqrtPriceX96For(uint256 amount0, uint256 amount1) public pure returns (uint160) {
        if (amount0 == 0 || amount1 == 0) revert ZeroAmount();
        // sqrt(amount1/amount0)*2^96 = sqrt(amount1 * 2^96 / amount0) * 2^48
        uint256 ratioX96 = Math.mulDiv(amount1, 1 << 96, amount0);
        uint256 sp = Math.sqrt(ratioX96) << 48;
        if (sp > type(uint160).max) revert PriceOverflow();
        return uint160(sp);
    }

    /// @notice Build the canonical MEME/WETH pool key (sorted, no hook).
    function poolKeyFor(address meme, address weth, uint24 fee, int24 tickSpacing)
        public
        pure
        returns (PoolKey memory key, bool memeIsCurrency0)
    {
        (address c0, address c1) = meme < weth ? (meme, weth) : (weth, meme);
        key = PoolKey({
            currency0: Currency.wrap(c0),
            currency1: Currency.wrap(c1),
            fee: fee,
            tickSpacing: tickSpacing,
            hooks: IHooks(address(0))
        });
        memeIsCurrency0 = (c0 == meme);
    }

    /// @notice Create the MEME/WETH pool and lock its liquidity. Pulls the
    ///         principal from the caller (GraduationManager). Returns leftovers
    ///         to the caller for burn/policy handling.
    function graduate(address meme, address weth, uint256 wethAmount, uint256 memeAmount, uint24 fee, int24 tickSpacing)
        external
        nonReentrant
        returns (bytes32 poolId, uint128 liquidity)
    {
        if (wethAmount == 0 || memeAmount == 0) revert ZeroAmount();
        (PoolKey memory key, bool memeIsC0) = poolKeyFor(meme, weth, fee, tickSpacing);

        (uint256 amount0, uint256 amount1) = memeIsC0 ? (memeAmount, wethAmount) : (wethAmount, memeAmount);
        uint160 sqrtPriceX96 = sqrtPriceX96For(amount0, amount1);

        // pull principal and approve the locker
        IERC20(meme).safeTransferFrom(msg.sender, address(this), memeAmount);
        IERC20(weth).safeTransferFrom(msg.sender, address(this), wethAmount);
        IERC20(Currency.unwrap(key.currency0)).forceApprove(address(locker), amount0);
        IERC20(Currency.unwrap(key.currency1)).forceApprove(address(locker), amount1);

        (liquidity,,) = locker.lockLiquidity(key, sqrtPriceX96, amount0, amount1, true);
        poolId = PoolId.unwrap(key.toId());

        // return any leftover principal to the caller
        _sweep(meme, msg.sender);
        _sweep(weth, msg.sender);

        emit Graduated(poolId, meme, liquidity, wethAmount, memeAmount);
    }

    function _sweep(address token, address to) internal {
        uint256 bal = IERC20(token).balanceOf(address(this));
        if (bal > 0) IERC20(token).safeTransfer(to, bal);
    }
}
