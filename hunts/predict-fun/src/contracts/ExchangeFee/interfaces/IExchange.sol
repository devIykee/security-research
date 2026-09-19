// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Order} from "../../Exchange/libraries/OrderStructs.sol";

interface IExchange {
    function getCollateral() external view returns (address);

    function getCtf() external view returns (address);

    function hashOrder(Order memory order) external view returns (bytes32);

    function matchOrders(
        Order memory takerOrder,
        Order[] memory makerOrders,
        uint256 takerFillAmount,
        uint256[] memory makerFillAmounts
    ) external;
}
