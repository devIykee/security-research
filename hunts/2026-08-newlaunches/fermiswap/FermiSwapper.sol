// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.25;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./BaseManager.sol";
import "./interfaces/IFermiEngine.sol";
import "./interfaces/IFermiSwapper.sol";
import "./interfaces/IFermiSwapCallback.sol";

using SafeERC20 for IERC20;

contract FermiSwapper is BaseManager, IFermiSwapper {
    uint256 public constant VERSION = 20260421;

    IFermiEngine public fermi;
    address payable public traderVault;

    constructor(
        address payable vaultAddress,
        address payable managerAddress,
        address fermiAddress,
        address payable traderVaultAddress
    ) BaseManager(vaultAddress, managerAddress) {
        require(fermiAddress != address(0), "ZA");
        require(traderVaultAddress != address(0), "ZA");
        require(IFermiEngine(fermiAddress).traderVault() == traderVaultAddress, "TVM");
        fermi = IFermiEngine(fermiAddress);
        traderVault = traderVaultAddress;
    }

    function setFermi(address newFermi) external onlyManager {
        require(newFermi != address(0), "ZA");
        require(IFermiEngine(newFermi).traderVault() == traderVault, "TVM");
        fermi = IFermiEngine(newFermi);
    }

    function setTraderVault(address payable newTraderVault) external onlyManager {
        require(newTraderVault != address(0), "ZA");
        require(fermi.traderVault() == newTraderVault, "TVM");
        traderVault = newTraderVault;
    }

    function quoteAmounts(address tokenIn, address tokenOut, int256 amountSpecified)
        external
        view
        returns (uint256 amountIn, uint256 amountOut)
    {
        return fermi.quote(tokenIn, tokenOut, amountSpecified, msg.sender);
    }

    function isActive(address baseAsset, address quoteAsset) external view returns (bool) {
        return fermi.isActive(baseAsset, quoteAsset);
    }

    function getPairs() external view returns (IFermiEngine.PairInfo[] memory) {
        return fermi.getPairs();
    }

    function fermiSwapWithAllowances(
        address tokenIn,
        address tokenOut,
        int256 amountSpecified,
        uint256 amountCheck,
        address recipient
    ) external nonReentrant returns (uint256 amountIn, uint256 amountOut) {
        require(recipient != address(0), "ZA");

        (amountIn, amountOut) = fermi.swap(tokenIn, tokenOut, amountSpecified, msg.sender);
        require(amountSpecified > 0 ? amountOut >= amountCheck : amountIn <= amountCheck, "ACF");

        IERC20(tokenOut).safeTransferFrom(traderVault, recipient, amountOut);
        IERC20(tokenIn).safeTransferFrom(msg.sender, traderVault, amountIn);

        emit FermiSwap(recipient, tokenIn, tokenOut, amountIn, amountOut);
    }

    function fermiSwapWithCallback(
        address tokenIn,
        address tokenOut,
        int256 amountSpecified,
        uint256 amountCheck,
        address recipient,
        bytes calldata callbackData
    ) external nonReentrant returns (uint256 amountIn, uint256 amountOut) {
        require(recipient != address(0), "ZA");

        (amountIn, amountOut) = fermi.swap(tokenIn, tokenOut, amountSpecified, msg.sender);
        require(amountSpecified > 0 ? amountOut >= amountCheck : amountIn <= amountCheck, "ACF");

        uint256 balanceBefore = IERC20(tokenIn).balanceOf(address(this));
        IERC20(tokenOut).safeTransferFrom(traderVault, recipient, amountOut);
        IFermiSwapCallback(msg.sender).fermiSwapCallback(int256(amountIn), -int256(amountOut), callbackData);
        require(IERC20(tokenIn).balanceOf(address(this)) >= balanceBefore + amountIn, "WTA");
        IERC20(tokenIn).safeTransfer(traderVault, amountIn);

        emit FermiSwap(recipient, tokenIn, tokenOut, amountIn, amountOut);
    }

    receive() external payable {}
    fallback() external payable {}
}

