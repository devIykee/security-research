// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title IAdapter
 * @author Yak Exchange
 * @notice Interface for DEX adapter contracts that integrate various AMMs
 * @dev Each adapter implements swap functionality for a specific DEX protocol
 */
interface IAdapter {
    /**
     * @notice Returns the name of the adapter
     * @return name The adapter's descriptive name (e.g., "UniswapV2Adapter")
     */
    function name() external view returns (string memory);

    /**
     * @notice Executes a token swap through the adapter's underlying DEX
     * @param _amountIn Amount of input tokens to swap
     * @param _amountOut Minimum amount of output tokens expected
     * @param _fromToken Address of the input token
     * @param _toToken Address of the output token
     * @param _to Address that will receive the output tokens
     * @dev Adapter must ensure _to receives at least _amountOut tokens
     */
    function swap(uint256 _amountIn, uint256 _amountOut, address _fromToken, address _toToken, address _to) external;

    /**
     * @notice Queries the adapter for expected swap output/input amount
     * @param _amount Input amount (if exactIn) or output amount (if !exactIn)
     * @param _tokenIn Address of the input token
     * @param _tokenOut Address of the output token
     * @param _exactIn True for exact input quote, false for exact output quote
     * @return amountOut The output amount (if exactIn) or required input amount (if !exactIn)
     * @return recipient The address that should receive tokens for this adapter
     * @dev Should return (0, address(0)) if swap is not available
     */
    function query(uint256 _amount, address _tokenIn, address _tokenOut, bool _exactIn) 
        external 
        view 
        returns (uint256 amountOut, address recipient);
}
