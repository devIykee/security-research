// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.25;

import "./IFermiEngine.sol";

interface IFermiSwapper {
    event FermiSwap(
        address indexed recipient,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut
    );

    function fermi() external view returns (IFermiEngine);
    function traderVault() external view returns (address payable);

    function quoteAmounts(address tokenIn, address tokenOut, int256 amountSpecified)
        external
        view
        returns (uint256 amountIn, uint256 amountOut);

    function isActive(address baseAsset, address quoteAsset) external view returns (bool);

    function getPairs() external view returns (IFermiEngine.PairInfo[] memory);

    function fermiSwapWithAllowances(
        address tokenIn,
        address tokenOut,
        int256 amountSpecified,
        uint256 amountCheck,
        address recipient
    ) external returns (uint256 amountIn, uint256 amountOut);

    function fermiSwapWithCallback(
        address tokenIn,
        address tokenOut,
        int256 amountSpecified,
        uint256 amountCheck,
        address recipient,
        bytes calldata callbackData
    ) external returns (uint256 amountIn, uint256 amountOut);
}
