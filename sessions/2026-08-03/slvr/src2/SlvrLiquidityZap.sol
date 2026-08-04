// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IUniswapV2Pair} from "@uniswap/v2-core/interfaces/IUniswapV2Pair.sol";

/// @notice Minimal SlvrLiquidityStaking interface
interface ISlvrLiquidityStaking {
    function depositFor(address user, uint256 amount) external;
    function withdraw(uint256 amount) external;
}

/// @notice WETH interface
interface IWETH {
    function deposit() external payable;
    function withdraw(uint256 amount) external;
    function transfer(address to, uint256 value) external returns (bool);
}

/// @notice SlvrToken's permissionless tax-swapback entrypoint
interface ISlvrTokenSwapback {
    function executeSwapback(uint256 amountOutMin, uint256 deadline) external;
    function swapbackMinOut() external view returns (uint256);
}

/// @title SlvrLiquidityZap
/// @notice Direct pair liquidity zap - swaps and mints directly on the pair
/// @dev Works directly with UniswapV2 pair, no router needed
/// @dev Automatically stakes LP tokens to liquidity staking on behalf of users
contract SlvrLiquidityZap is ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable SLVR_TOKEN;
    address public immutable WETH;
    address public immutable PAIR;
    address public immutable LIQUIDITY_STAKING;

    error Expired();
    error ZeroAmount();
    error NoLiquidity();
    error BadSwapAmount();
    error InsufficientOut();
    error Slippage();

    event LiquidityAdded(
        address indexed user,
        uint256 slvrAmount,
        uint256 ethAmount,
        uint256 liquidity
    );

    event LiquidityRemoved(
        address indexed user,
        uint256 liquidity,
        uint256 slvrAmount,
        uint256 ethAmount
    );

    constructor(address slvrToken_, address weth_, address pair_, address liquidityStaking_) {
        require(slvrToken_ != address(0), "slvrToken=0");
        require(weth_ != address(0), "weth=0");
        require(pair_ != address(0), "pair=0");
        require(liquidityStaking_ != address(0), "liquidityStaking=0");
        
        SLVR_TOKEN = IERC20(slvrToken_);
        WETH = weth_;
        PAIR = pair_;
        LIQUIDITY_STAKING = liquidityStaking_;
    }

    /// @notice Zap ETH into SLVR/ETH LP tokens by swapping directly against the pair
    /// @dev 1. Wraps ETH to WETH, 2. Optimal swap WETH->SLVR, 3. Direct mint on pair, 4. Stake LP
    /// @param minLiquidity Minimum LP tokens to receive (slippage protection)
    /// @param deadline Transaction deadline
    /// @return liquidity LP tokens received and staked
    /// @return amountToken Actual SLVR tokens used
    /// @return amountETH Actual WETH used
    function addLiquidityWithEth(
        uint256 minLiquidity,
        uint256 deadline
    ) external payable nonReentrant returns (uint256 liquidity, uint256 amountToken, uint256 amountETH) {
        if (block.timestamp > deadline) revert Expired();
        if (msg.value == 0) revert ZeroAmount();

        // Flush any pending tax swapback BEFORE reading reserves. SLVR fires an automatic
        // swapback inside any transfer TO the pair; if it fired during our SLVR deposit
        // below, its router swap would sync our already-deposited WETH into reserves and
        // pair.mint() would see a zero WETH delta (INSUFFICIENT_LIQUIDITY_MINTED). Flushing
        // here updates lastSwapbackTime so the interval gate blocks a re-fire in this tx;
        // if the flush reverts (below threshold / too soon) the mid-transfer trigger is
        // equally gated. Reserves are read after, so the math sees the post-flush state.
        // Passing swapbackMinOut keeps the flush exactly as strict as the automatic path.
        ISlvrTokenSwapback slvr = ISlvrTokenSwapback(address(SLVR_TOKEN));
        try slvr.executeSwapback(slvr.swapbackMinOut(), block.timestamp) {} catch {}

        IUniswapV2Pair pair = IUniswapV2Pair(PAIR);
        
        // Get pair token addresses
        address token0 = pair.token0();
        address token1 = pair.token1();
        
        // Determine which token is which
        bool slvrIsToken0 = (token0 == address(SLVR_TOKEN));
        
        // Get reserves
        (uint112 r0, uint112 r1,) = pair.getReserves();
        if (r0 == 0 || r1 == 0) revert NoLiquidity();
        
        uint256 reserveIn = slvrIsToken0 ? uint256(r1) : uint256(r0);  // WETH reserve
        uint256 reserveOut = slvrIsToken0 ? uint256(r0) : uint256(r1); // SLVR reserve
        
        // Wrap ETH to WETH
        IWETH weth = IWETH(WETH);
        weth.deposit{value: msg.value}();
        
        // Pull WETH to this contract (already here from deposit, but for clarity)
        uint256 amountIn = msg.value;
        
        // Calculate optimal swap amount
        uint256 swapAmountIn = _calculateOptimalSwapIn(reserveIn, amountIn);
        if (swapAmountIn == 0 || swapAmountIn >= amountIn) revert BadSwapAmount();
        
        // Transfer swap amount to pair
        IERC20(WETH).safeTransfer(PAIR, swapAmountIn);
        
        // Measure actual input (FoT-tolerant)
        uint256 balanceInAfter = IERC20(WETH).balanceOf(PAIR);
        uint256 actualIn = balanceInAfter - reserveIn;
        if (actualIn == 0) revert BadSwapAmount();
        
        // Compute output
        uint256 amountOut = _getAmountOut(actualIn, reserveIn, reserveOut);
        if (amountOut == 0) revert InsufficientOut();
        
        // Perform swap: WETH -> SLVR, output to this contract
        if (slvrIsToken0) {
            // WETH is token1, want SLVR (token0) out
            pair.swap(amountOut, 0, address(this), new bytes(0));
        } else {
            // WETH is token0, want SLVR (token1) out
            pair.swap(0, amountOut, address(this), new bytes(0));
        }
        
        // Read reserves again (post-swap)
        (r0, r1,) = pair.getReserves();
        
        // Get balances of both tokens in this contract
        uint256 bal0 = IERC20(token0).balanceOf(address(this));
        uint256 bal1 = IERC20(token1).balanceOf(address(this));
        
        // Calculate optimal deposit amounts
        (uint256 amount0Used, uint256 amount1Used) = _calcOptimalDepositAmounts(
            bal0,
            bal1,
            uint256(r0),
            uint256(r1)
        );
        
        // Transfer SLVR to the pair BEFORE WETH: the SLVR transfer can trigger the token's
        // automatic swapback (a swap + sync on this pair), which would absorb any balance
        // already parked in the pair but not yet minted. With SLVR first, a mid-transfer
        // swapback runs against a clean pair — our SLVR is credited after the trigger and
        // our WETH is not deposited yet — so mint() still sees both deltas.
        (uint256 slvrUsed, uint256 wethUsed) =
            slvrIsToken0 ? (amount0Used, amount1Used) : (amount1Used, amount0Used);
        if (slvrUsed > 0) SLVR_TOKEN.safeTransfer(PAIR, slvrUsed);
        if (wethUsed > 0) IERC20(WETH).safeTransfer(PAIR, wethUsed);
        
        // Mint LP tokens directly from pair
        liquidity = pair.mint(address(this));
        if (liquidity < minLiquidity) revert Slippage();
        
        // Map amounts to SLVR/WETH for return values
        if (slvrIsToken0) {
            amountToken = amount0Used;
            amountETH = amount1Used;
        } else {
            amountToken = amount1Used;
            amountETH = amount0Used;
        }
        
        // Refund any dust
        uint256 dust0 = IERC20(token0).balanceOf(address(this));
        uint256 dust1 = IERC20(token1).balanceOf(address(this));
        if (dust0 > 0) IERC20(token0).safeTransfer(msg.sender, dust0);
        if (dust1 > 0) IERC20(token1).safeTransfer(msg.sender, dust1);
        
        // Approve and stake LP tokens
        IERC20 lpToken = IERC20(PAIR);
        uint256 currentAllowance = lpToken.allowance(address(this), LIQUIDITY_STAKING);
        if (currentAllowance < liquidity) {
            if (currentAllowance != 0) {
                lpToken.safeDecreaseAllowance(LIQUIDITY_STAKING, currentAllowance);
            }
            lpToken.safeIncreaseAllowance(LIQUIDITY_STAKING, liquidity);
        }
        
        // Deposit LP tokens to liquidity staking on behalf of the user
        ISlvrLiquidityStaking(LIQUIDITY_STAKING).depositFor(msg.sender, liquidity);
        
        emit LiquidityAdded(msg.sender, amountToken, amountETH, liquidity);
    }
    
    /// @dev Optimal swap amount for UniswapV2 0.3% fee (997/1000)
    /// swapIn = (sqrt(r^2 * 3988009 + a * r * 3988000) - r * 1997) / 1994
    function _calculateOptimalSwapIn(
        uint256 reserveIn,
        uint256 amountIn
    ) internal pure returns (uint256) {
        if (reserveIn == 0 || amountIn == 0) return 0;
        
        uint256 r = reserveIn;
        uint256 a = amountIn;
        
        // r^2 * 3988009
        uint256 part1 = r * r * 3988009;
        // a * r * 3988000
        uint256 part2 = a * r * 3988000;
        
        uint256 numerator = _sqrt(part1 + part2) - (r * 1997);
        return numerator / 1994;
    }
    
    /// @dev UniswapV2 getAmountOut with 0.3% fee
    function _getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256) {
        require(amountIn > 0, "INSUFFICIENT_INPUT");
        require(reserveIn > 0 && reserveOut > 0, "INSUFFICIENT_LIQUIDITY");
        
        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn * 1000 + amountInWithFee;
        return numerator / denominator;
    }
    
    /// @dev Calculate optimal deposit amounts matching reserve ratio
    function _calcOptimalDepositAmounts(
        uint256 bal0,
        uint256 bal1,
        uint256 r0,
        uint256 r1
    ) internal pure returns (uint256 amount0, uint256 amount1) {
        if (bal0 == 0 || bal1 == 0 || r0 == 0 || r1 == 0) {
            return (0, 0);
        }
        
        // Compare bal0/bal1 vs r0/r1
        uint256 ideal1 = (bal0 * r1) / r0;
        
        if (ideal1 <= bal1) {
            // token1 is limiting
            amount0 = bal0;
            amount1 = ideal1;
        } else {
            // token0 is limiting
            uint256 ideal0 = (bal1 * r0) / r1;
            amount0 = ideal0;
            amount1 = bal1;
        }
    }
    
    /// @dev Babylonian sqrt
    function _sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y == 0) return 0;
        uint256 x = y / 2 + 1;
        z = y;
        while (x < z) {
            z = x;
            x = (y / x + x) / 2;
        }
    }

    /// @notice Remove liquidity and convert back to ETH + SLVR (direct pair burn)
    /// @dev User must first withdraw LP tokens from staking, then approve this contract
    /// @dev Burns LP directly on pair and returns SLVR + WETH (unwrapped to ETH)
    /// @param liquidity Amount of LP tokens to remove
    /// @param amountTokenMin Minimum SLVR tokens (slippage protection)
    /// @param amountETHMin Minimum ETH (slippage protection)
    /// @param deadline Transaction deadline
    /// @return amountToken Actual SLVR tokens returned
    /// @return amountETH Actual ETH returned
    function removeLiquidityAndZapOut(
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        uint256 deadline
    ) external nonReentrant returns (uint256 amountToken, uint256 amountETH) {
        if (block.timestamp > deadline) revert Expired();
        if (liquidity == 0) revert ZeroAmount();

        // Transfer LP tokens from user to this contract
        IERC20 lpToken = IERC20(PAIR);
        lpToken.safeTransferFrom(msg.sender, address(this), liquidity);

        // Transfer LP tokens to pair for burning
        lpToken.safeTransfer(PAIR, liquidity);

        IUniswapV2Pair pair = IUniswapV2Pair(PAIR);
        
        // Get token addresses
        address token0 = pair.token0();
        bool slvrIsToken0 = (token0 == address(SLVR_TOKEN));
        
        // Burn LP tokens directly on pair - returns tokens to this contract
        (uint256 amount0, uint256 amount1) = pair.burn(address(this));
        
        // Map amounts to SLVR/WETH
        if (slvrIsToken0) {
            amountToken = amount0;
            amountETH = amount1;
        } else {
            amountToken = amount1;
            amountETH = amount0;
        }
        
        // Slippage checks
        if (amountToken < amountTokenMin) revert Slippage();
        if (amountETH < amountETHMin) revert Slippage();
        
        // Unwrap WETH to ETH
        IWETH weth = IWETH(WETH);
        weth.withdraw(amountETH);
        
        // Transfer SLVR tokens to user
        if (amountToken > 0) {
            SLVR_TOKEN.safeTransfer(msg.sender, amountToken);
        }
        
        // Transfer ETH to user
        if (amountETH > 0) {
            (bool success,) = payable(msg.sender).call{value: amountETH}("");
            require(success, "ETH transfer failed");
        }
        
        emit LiquidityRemoved(msg.sender, liquidity, amountToken, amountETH);
    }

    /// @notice Allow contract to receive ETH
    receive() external payable {}
}
