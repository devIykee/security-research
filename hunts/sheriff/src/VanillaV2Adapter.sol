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
pragma solidity 0.8.30;

import {IERC20} from "contracts/interface/IERC20.sol";
import {SafeERC20} from "contracts/lib/SafeERC20.sol";
import {YakAdapter} from "contracts/YakAdapter.sol";

interface IFactory {
    function getPair(address, address) external view returns (address);
}

interface IPair {
    function getAmountOut(uint256, address) external view returns (uint256);
    function getAmountIn(uint256, address) external view returns (uint256);
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data)
        external;
}

contract VanillaV2Adapter is YakAdapter {
    using SafeERC20 for IERC20;

    error InsufficientOutputAmount(uint256 amountOut, uint256 requiredAmount);

    address public immutable FACTORY;

    constructor(string memory _name, address _factory) YakAdapter(_name) {
        FACTORY = _factory;
    }

    function getQuoteAndPair(uint256 _amount, address _tokenIn, address _tokenOut, bool _exactIn)
        internal
        view
        returns (uint256 quoteAmount, address pair)
    {
        if (_exactIn) {
            pair = IFactory(FACTORY).getPair(_tokenIn, _tokenOut);
            if (pair != address(0)) quoteAmount = IPair(pair).getAmountOut(_amount, _tokenIn);
        } else {
            pair = IFactory(FACTORY).getPair(_tokenOut, _tokenIn);
            if (pair != address(0)) quoteAmount = IPair(pair).getAmountIn(_amount, _tokenOut);
        }
    }

    function _query(uint256 _amount, address _tokenIn, address _tokenOut, bool _exactIn)
        internal
        view
        override
        returns (uint256 quoteAmount, address pair)
    {
        if (_tokenIn != _tokenOut && _amount != 0) {
            (quoteAmount, pair) = getQuoteAndPair(_amount, _tokenIn, _tokenOut, _exactIn);
        }
    }

    function _swap(
        uint256 _amountIn,
        uint256 _amountOut,
        address _tokenIn,
        address _tokenOut,
        address to
    ) internal override {
        (uint256 amountOut, address pair) = getQuoteAndPair(_amountIn, _tokenIn, _tokenOut, true);
        if (amountOut < _amountOut) revert InsufficientOutputAmount(amountOut, _amountOut);
        
        // Check balance before swap
        uint256 balanceBefore = IERC20(_tokenOut).balanceOf(to);
        
        (uint256 amount0Out, uint256 amount1Out) =
            (_tokenIn < _tokenOut) ? (uint256(0), amountOut) : (amountOut, uint256(0));
        IPair(pair).swap(amount0Out, amount1Out, to, new bytes(0));
        
        // Verify the recipient received at least the minimum amount
        uint256 balanceAfter = IERC20(_tokenOut).balanceOf(to);
        uint256 actualReceived = balanceAfter - balanceBefore;
        if (actualReceived < _amountOut) {
            revert InsufficientOutputAmount(actualReceived, _amountOut);
        }
    }
}
