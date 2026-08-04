// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @notice Per-pool reward conversion lifecycle.
enum RewardConversionState {
    PENDING, // fees accruing in WETH, nothing converted yet
    ACTIVE, // at least one successful conversion; stock rewards available
    PAUSED, // governance halted conversion
    LOW_LIQUIDITY, // route degraded; conversion withheld
    FAILED // last conversion attempt failed; WETH retained, safe retry
}

/// @notice Executes a whitelisted WETH -> USDG -> stock conversion. The route is
///         read from the StockRouteRegistry; the caller CANNOT supply arbitrary
///         tokens, pools, recipients, routers, or calldata.
interface IStockConversionAdapter {
    function convert(address stock, uint256 wethIn, uint256 minStockOut, uint256 deadline, address recipient)
        external
        returns (uint256 stockOut);
}

/// @notice Multi-asset reward vault (holder side). Rewards are stock tokens.
interface IRewardVaultV2 {
    function notifyReward(address asset, uint256 amount) external;
}

/// @notice Creator reward vault. Rewards are stock tokens, credited per creator.
interface ICreatorRewardVaultV2 {
    function notifyReward(address creator, address asset, uint256 amount) external;
}
