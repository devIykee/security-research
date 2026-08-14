// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {SafeERC20, IERC20} from "contracts/lib/SafeERC20.sol";
import {Maintainable} from "contracts/lib/Maintainable.sol";

abstract contract Recoverable is Maintainable {
    using SafeERC20 for IERC20;

    error ETHTransferFailed();
    error NothingToRecover();

    event Recovered(address indexed _asset, uint256 amount);

    /**
     * @notice Recover ERC20 from contract
     * @param _tokenAddress token address
     * @param _tokenAmount amount to recover
     */
    function recoverERC20(address _tokenAddress, uint256 _tokenAmount) external onlyMaintainer {
        if (_tokenAmount == 0) revert NothingToRecover();
        IERC20(_tokenAddress).safeTransfer(msg.sender, _tokenAmount);
        emit Recovered(_tokenAddress, _tokenAmount);
    }

    /**
     * @notice Recover native asset from contract
     * @param _amount amount
     */
    function recoverNative(uint256 _amount) external onlyMaintainer {
        if (_amount == 0) revert NothingToRecover();
        (bool refunded,) = msg.sender.call{value: _amount}("");
        if (!refunded) revert ETHTransferFailed();
        emit Recovered(address(0), _amount);
    }
}
