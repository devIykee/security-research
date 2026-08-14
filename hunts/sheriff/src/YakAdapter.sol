//       ╟╗                                                                      ╔╬
//       ╞╬╬                                                                    ╬╠╬
//      ╔╣╬╬╬                                                                  ╠╠╠╠╦
//     ╬╬╬╬╬╩                                                                  ╘╠╠╠╠╬
//    ║╬╬╬╬╬                                                                    ╘╠╠╠╠╬
//    ╣╬╬╬╬╬╬╬╬╬╬╬╬╬╬╬      ╒╬╬╬╬╬╬╬╜   ╠╠╬╬╬╬╬╬╬         ╠╬╬╬╬╬╬╬    ╬╬╬╬╬╬╬╬╠╠╠╠╠╠╠╠
//    ╙╬╬╬╬╬╬╬╬╬╬╬╬╬╬╬╬╕    ╬╬╬╬╬╬╬╜   ╣╠╠╬╬╬╬╬╬╬╬        ╠╬╬╬╬╬╬╬   ╬╬╬╬╬╬╬╬╬╠╠╠╠╠╠╠╩
//     ╙╣╬╬╬╬╬╬╬╬╬╬╬╬╬╬╬  ╔╬╬╬╬╬╬╬    ╔╠╠╠╬╬╬╬╬╬╬╬        ╠╬╬╬╬╬╬╬ ╣╬╬╬╬╬╬╬╬╬╬╬╠╠╠╠╝╙
//               ╘╣╬╬╬╬╬╬╬╬╬╬╬╬╬╬    ╒╠╠╠╬╠╬╩╬╬╬╬╬╬       ╠╬╬╬╬╬╬╬╣╬╬╬╬╬╬╬╙
//                 ╣╬╬╬╬╬╬╬╬╬╬╠╣     ╣╬╠╠╠╬╩ ╚╬╬╬╬╬╬      ╠╬╬╬╬╬╬╬╬╬╬╬╬╬╬
//                  ╣╬╬╬╬╬╬╬╬╬╣     ╣╬╠╠╠╬╬   ╣╬╬╬╬╬╬     ╠╬╬╬╬╬╬╬╬╬╬╬╬╬╬
//                   ╟╬╬╬╬╬╬╬╩      ╬╬╠╠╠╠╬╬╬╬╬╬╬╬╬╬╬     ╠╬╬╬╬╬╬╬╠╬╬╬╬╬╬╬
//                    ╬╬╬╬╬╬╬     ╒╬╬╠╠╬╠╠╬╬╬╬╬╬╬╬╬╬╬╬    ╠╬╬╬╬╬╬╬ ╣╬╬╬╬╬╬╬
//                    ╬╬╬╬╬╬╬     ╬╬╬╠╠╠╠╝╝╝╝╝╝╝╠╬╬╬╬╬╬   ╠╬╬╬╬╬╬╬  ╚╬╬╬╬╬╬╬╬
//                    ╬╬╬╬╬╬╬    ╣╬╬╬╬╠╠╩       ╘╬╬╬╬╬╬╬  ╠╬╬╬╬╬╬╬   ╙╬╬╬╬╬╬╬╬
//

// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import {IAdapter} from "contracts/interface/IAdapter.sol";
import {IERC20} from "contracts/interface/IERC20.sol";
import {SafeERC20} from "contracts/lib/SafeERC20.sol";
import {Maintainable} from "contracts/lib/Maintainable.sol";

/**
 * @title YakAdapter
 * @notice Abstract base contract for DEX adapters
 * @dev Implements common functionality for all adapters including token recovery and safety checks
 */
abstract contract YakAdapter is IAdapter, Maintainable {
    using SafeERC20 for IERC20;

    /**
     * @notice Thrown when a zero address is provided
     */
    error AddressZero();

    /**
     * @notice Thrown when ETH transfer fails
     */
    error ETHTransferFailed();

    /**
     * @notice Thrown when adapter name is empty
     */
    error InvalidAdapterName();

    /**
     * @notice Thrown when query parameters are invalid
     */
    error InvalidQuery();

    /**
     * @notice Thrown when trying to recover zero amount
     */
    error NothingToRecover();

    /**
     * @notice Thrown when swap output is less than required
     * @param amountOut Actual output amount
     * @param requiredAmount Required minimum output
     */
    error InsufficientAmountOut(uint256 amountOut, uint256 requiredAmount);

    /**
     * @notice Emitted when a swap is executed through the adapter
     * @param _tokenFrom Input token address
     * @param _tokenTo Output token address
     * @param _amountIn Input amount
     * @param _amountOut Output amount
     */
    event YakAdapterSwap(
        address indexed _tokenFrom, address indexed _tokenTo, uint256 _amountIn, uint256 _amountOut
    );

    /**
     * @notice Emitted when tokens are recovered from the adapter
     * @param _asset Token address (address(0) for ETH)
     * @param amount Amount recovered
     */
    event Recovered(address indexed _asset, uint256 amount);

    /// @notice Name of the adapter
    string public name;

    /**
     * @notice Initializes the adapter with a name
     * @param _name Name of the adapter
     * @dev Name cannot be empty
     */
    constructor(string memory _name) {
        if (bytes(_name).length == 0) revert InvalidAdapterName();
        name = _name;
    }

    /**
     * @notice Revokes token approval for a spender
     * @param _token Token address
     * @param _spender Spender address
     * @dev Only callable by maintainer
     */
    function revokeAllowance(address _token, address _spender) external onlyMaintainer {
        IERC20(_token).safeApprove(_spender, 0);
    }

    /**
     * @notice Recovers ERC20 tokens sent to this contract
     * @param _tokenAddress Token to recover
     * @param _tokenAmount Amount to recover
     * @dev Only callable by maintainer
     */
    function recoverERC20(address _tokenAddress, uint256 _tokenAmount) external onlyMaintainer {
        if (_tokenAmount == 0) revert NothingToRecover();
        IERC20(_tokenAddress).safeTransfer(msg.sender, _tokenAmount);
        emit Recovered(_tokenAddress, _tokenAmount);
    }

    /**
     * @notice Recovers ETH sent to this contract
     * @param _amount Amount of ETH to recover
     * @dev Only callable by maintainer
     */
    function recoverETH(uint256 _amount) external onlyMaintainer {
        if (_amount == 0) revert NothingToRecover();
        (bool success,) = msg.sender.call{value: _amount}("");
        if (!success) revert ETHTransferFailed();
        emit Recovered(address(0), _amount);
    }

    /**
     * @notice External query function that delegates to internal implementation
     * @inheritdoc IAdapter
     */
    function query(uint256 _amount, address _tokenIn, address _tokenOut, bool _exactIn)
        external
        view
        returns (uint256, address)
    {
        (uint256 quoteAmount, address recipient) = _query(_amount, _tokenIn, _tokenOut, _exactIn);
        if (quoteAmount == 0 || recipient == address(0)) revert InvalidQuery();
        return (quoteAmount, recipient);
    }

    /**
     * @notice External swap function
     * @inheritdoc IAdapter
     */
    function swap(
        uint256 _amountIn,
        uint256 _amountOut,
        address _fromToken,
        address _toToken,
        address _to
    ) external virtual {
        _swap(_amountIn, _amountOut, _fromToken, _toToken, _to);
        emit YakAdapterSwap(_fromToken, _toToken, _amountIn, _amountOut);
    }

    /**
     * @notice Transfers tokens to recipient if not this contract
     * @param _token Token to transfer
     * @param _amount Amount to transfer
     * @param _to Recipient address
     * @dev Skips transfer if recipient is this contract
     */
    function _returnTo(address _token, uint256 _amount, address _to) internal {
        if (address(this) != _to) IERC20(_token).safeTransfer(_to, _amount);
    }

    /**
     * @notice Internal swap implementation to be overridden by adapters
     * @param _amountIn Amount of input tokens
     * @param _amountOut Minimum output amount expected
     * @param _fromToken Input token address
     * @param _toToken Output token address
     * @param _to Recipient address
     * @dev Must be implemented by concrete adapters
     */
    function _swap(
        uint256 _amountIn,
        uint256 _amountOut,
        address _fromToken,
        address _toToken,
        address _to
    ) internal virtual;

    /**
     * @notice Internal query implementation to be overridden by adapters
     * @param _amount Input or output amount depending on exactIn
     * @param _tokenIn Input token address
     * @param _tokenOut Output token address
     * @param _exactIn True for exact input, false for exact output
     * @return amountOut Output amount or required input
     * @return recipient Address that should receive tokens
     * @dev Must be implemented by concrete adapters
     */
    function _query(uint256 _amount, address _tokenIn, address _tokenOut, bool _exactIn)
        internal
        view
        virtual
        returns (uint256, address);

    /**
     * @notice Fallback function to receive ETH
     */
    receive() external payable {}
}
