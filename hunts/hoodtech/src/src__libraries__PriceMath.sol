// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {TickMath} from "./uniswap/TickMath.sol";
import {FullMath} from "./uniswap/FullMath.sol";
import {FixedPoint96} from "./uniswap/FixedPoint96.sol";

/**
 * @title PriceMath
 * @notice MCAP-based pricing for the HoodTech direct-launch flow on Uniswap V3.
 * @dev The launch model (mirroring live Robinhood Chain launchers): initialize the
 *      pool exactly at the starting-mcap tick and mint ONE single-sided, token-only
 *      position spanning from that tick to the end of the usable range in the
 *      direction of rising market cap. No ETH is seeded — the first buy moves the
 *      price into the position.
 *
 *      V3 pools are token/WETH and ordering depends on address sort, so everything
 *      is orientation-aware (`tokenIsToken0`):
 *      - token is token0: pool price = WETH per token → tick RISES as mcap rises.
 *      - token is token1: pool price = token per WETH → tick FALLS as mcap rises.
 */
library PriceMath {
    error SqrtPriceOverflow();

    /// @notice sqrt price the pool is initialized at: exactly the starting-mcap
    ///         tick, i.e. the supply-side edge of the launch position.
    function initialSqrtPrice(
        uint256 startingMcapETH,
        uint256 totalSupply,
        bool tokenIsToken0,
        int24 tickSpacing
    ) internal pure returns (uint160 sqrtPriceX96) {
        int24 startTick = mcapToTick(startingMcapETH, totalSupply, tokenIsToken0, tickSpacing);
        sqrtPriceX96 = TickMath.getSqrtPriceAtTick(startTick);
        if (sqrtPriceX96 == 0) revert SqrtPriceOverflow();
    }

    /// @notice Tick range of the single launch position: from the starting-mcap
    ///         tick to the far end of the usable range in the rising-mcap direction.
    function positionRange(
        uint256 startingMcapETH,
        uint256 totalSupply,
        bool tokenIsToken0,
        int24 tickSpacing
    ) internal pure returns (int24 tickLower, int24 tickUpper) {
        int24 startTick = mcapToTick(startingMcapETH, totalSupply, tokenIsToken0, tickSpacing);
        if (tokenIsToken0) {
            tickLower = startTick;
            tickUpper = (TickMath.MAX_TICK / tickSpacing) * tickSpacing;
        } else {
            tickLower = (TickMath.MIN_TICK / tickSpacing) * tickSpacing;
            tickUpper = startTick;
        }
        require(tickLower < tickUpper, "Degenerate range");
    }

    /// @notice Convert a market cap (in ETH) to the pool tick at that mcap,
    ///         rounded to the nearest tickSpacing multiple.
    function mcapToTick(
        uint256 mcap,
        uint256 totalSupply,
        bool tokenIsToken0,
        int24 tickSpacing
    ) internal pure returns (int24 tick) {
        // price(token1/token0):
        //   token0 = token → price = WETH/token = mcap / supply
        //   token1 = token → price = token/WETH = supply / mcap
        uint256 ratioX96 = tokenIsToken0
            ? FullMath.mulDiv(mcap, FixedPoint96.Q96, totalSupply)
            : FullMath.mulDiv(totalSupply, FixedPoint96.Q96, mcap);

        // sqrt(ratio * 2^96) = sqrt(ratio) * 2^48 → shift back up to X96
        uint160 sqrtPriceX96 = uint160(_sqrt(ratioX96) << 48);
        tick = TickMath.getTickAtSqrtPrice(sqrtPriceX96);

        // Round to nearest spacing multiple (symmetric for negative ticks).
        int24 rem = tick % tickSpacing;
        tick = (tick / tickSpacing) * tickSpacing;
        if (rem > tickSpacing / 2) tick += tickSpacing;
        else if (rem < -(tickSpacing / 2)) tick -= tickSpacing;
    }

    /// @dev Integer square root (Newton-Raphson).
    function _sqrt(uint256 x) private pure returns (uint256 y) {
        if (x == 0) return 0;
        uint256 z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }
}
