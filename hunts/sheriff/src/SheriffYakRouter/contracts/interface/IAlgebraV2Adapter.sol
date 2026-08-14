// SPDX-License-Identifier: GPL-3.0-only

pragma solidity ^0.8.0;

interface IAlgebraV2Adapter {
    /// @dev Output amount is lower than expected amount out
    error InsufficientAmount();

    /// @dev Thrown when the caller is not the pool address
    error NotPoolAddress();

    /// @dev Event emitted when the quoter is set
    event QuoterSet(address quoter);

    /// @dev Event emitted when an invalid quoter gas limit is set
    error InvalidGasLimit();

    /// @dev Event emitted when the quoter gas limit is updated
    event QuoterGasLimitSet(uint256 newGasLimit);

    /// @dev Parameters struct for a quote
    struct QParams {
        address tokenIn;
        address tokenOut;
        int256 amount;
        bool exactIn;
    }

    /// @dev Thrown when adding a deployer that is already whitelisted
    error DeployerAlreadyAdded();

    /// @dev Event emitted when a deployer is added to the global whitelist
    event DeployerAdded(address indexed deployer);

    /// @dev Event emitted when a deployer is removed from the global whitelist
    event DeployerRemoved(address indexed deployer);

    /// @notice Returns a whitelisted deployer address by index
    /// @param index The index of the deployer in the global whitelist
    function deployers(uint256 index) external view returns (address);

    /// @notice Returns all globally whitelisted deployers
    function getDeployers() external view returns (address[] memory);

    /// @notice Returns whether a deployer is whitelisted
    /// @param deployer Address of the deployer
    function isDeployer(address deployer) external view returns (bool);

    /// @notice Adds a deployer to the global whitelist
    /// @param deployer Address of deployer to whitelist
    function addCustomDeployer(address deployer) external;

    /// @notice Removes a deployer from the global whitelist by index
    /// @param index Index in the global deployers array
    function removeCustomDeployer(uint256 index) external;

    /// @notice Swaps tokens using a specific deployer's pool
    /// @param amountIn Amount of input tokens
    /// @param amountOut Minimum amount of output tokens expected
    /// @param tokenIn Address of input token
    /// @param tokenOut Address of output token
    /// @param to Address to receive output tokens
    /// @param deployer Address of the deployer for custom pool (address(0) for factory pool)
    function swap(
        uint256 amountIn,
        uint256 amountOut,
        address tokenIn,
        address tokenOut,
        address to,
        address deployer
    ) external;

    /// @notice Queries the adapter for swap quote and returns the deployer info
    /// @param amount Input amount (if exactIn) or output amount (if !exactIn)
    /// @param tokenIn Address of the input token
    /// @param tokenOut Address of the output token
    /// @param exactIn True for exact input quote, false for exact output quote
    /// @return quoteAmount The output amount (if exactIn) or required input amount (if !exactIn)
    /// @return recipient The address that should receive tokens for this adapter
    /// @return deployer The deployer address for custom pool (address(0) for factory pool)
    function queryWithDeployer(uint256 amount, address tokenIn, address tokenOut, bool exactIn)
        external
        view
        returns (uint256 quoteAmount, address recipient, address deployer);
}
