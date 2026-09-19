// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title ZeroDevWithdrawalHelper
 * @notice This contract helps users to manually transfer USDT out of their ZeroDev smart accounts
 * @author predict.fun protocol team
 */
contract ZeroDevWithdrawalHelper {
    address public constant USDT = 0x55d398326f99059fF775485246999027B3197955;

    /**
     * @notice Encodes an ERC20 transfer calldata
     *
     * @param token The address of the ERC20 token to transfer
     * @param to The address to transfer the ERC20 token to
     * @param amount The amount of ERC20 token to transfer
     *
     * @return userOpCalldata The encoded user operation calldata
     */
    function encodeERC20Transfer(
        address token,
        address to,
        uint256 amount
    ) public pure returns (bytes memory userOpCalldata) {
        bytes memory callData = abi.encode(to, amount);
        userOpCalldata = abi.encodePacked(token, uint256(0), IERC20.transfer.selector, callData);
    }

    /**
     * @notice Encodes a USDT transfer calldata
     *
     * @param to The address to transfer the USDT to
     * @param amount The amount of USDT to transfer
     *
     * @return userOpCalldata The encoded user operation calldata
     */
    function encodeUSDTTransfer(address to, uint256 amount) external pure returns (bytes memory userOpCalldata) {
        userOpCalldata = encodeERC20Transfer(USDT, to, amount);
    }

    /**
     * @notice Encodes an BNB transfer calldata
     *
     * @param to The address to transfer BNB to
     * @param amount The amount of BNB to transfer
     *
     * @return userOpCalldata The encoded user operation calldata
     */
    function encodeBNBTransfer(address to, uint256 amount) external pure returns (bytes memory userOpCalldata) {
        userOpCalldata = abi.encodePacked(to, amount, bytes4(0), "");
    }
}
