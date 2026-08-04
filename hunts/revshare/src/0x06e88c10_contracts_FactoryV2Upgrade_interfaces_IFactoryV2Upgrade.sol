// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

interface IERC20Upgrade {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
}

interface IHolderRewards {
    function rewardAsset() external view returns (address);
    function depositNativeRewards() external payable;
    function depositTokenRewards(uint256 amount) external;
}

/// @notice A chain-specific converter. Production implementations must enforce their own
/// oracle/TWAP floor; minAmountOut supplied by a caller may only make that floor stricter.
interface IFeeConverter {
    function convert(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        bytes calldata routeData
    ) external payable returns (uint256 amountOut);
}

interface ILiquidityFeeReceiver {
    function depositLiquidityNative() external payable;
    function depositLiquidityToken(address token, uint256 amount) external;
}
