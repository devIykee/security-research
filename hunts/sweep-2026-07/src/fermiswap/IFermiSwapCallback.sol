// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.25;

interface IFermiSwapCallback {
    function fermiSwapCallback(int256 amountIn, int256 amountOut, bytes calldata data) external;
}
