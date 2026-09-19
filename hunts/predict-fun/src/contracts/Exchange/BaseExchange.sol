// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ERC1155Holder} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import {ReentrancyGuard} from "./ReentrancyGuard.sol";

abstract contract BaseExchange is ERC1155Holder, ReentrancyGuard {}
