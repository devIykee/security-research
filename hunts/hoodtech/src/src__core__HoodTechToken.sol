// SPDX-License-Identifier: MIT

/*
//  📟 HOODTECH

   HoodTech | NoTax Token Contract
   📤 telegram:  https://t.me/HoodTech
   🤖 launcher:  https://t.me/HoodTechBot

   This token was launched through the HoodTech Telegram launcher.
   Zero tax, zero owner privileges, fixed 1,000,000,000 supply.
   All supply is placed into locked Uniswap V3 liquidity at launch.
   Trading fee is the flat Uniswap V3 1% tier:
   0.5% to the token creator, 0.5% to the HoodTech protocol.
*/

pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract HoodTechToken is ERC20 {
    uint256 public constant TOTAL_SUPPLY = 1_000_000_000 * 1e18;

    address public immutable controller;
    address public immutable beneficiary;
    uint256 public immutable createdAt;

    constructor(
        string memory _name,
        string memory _symbol,
        address _controller,
        address _beneficiary
    ) ERC20(_name, _symbol) {
        controller = _controller;
        beneficiary = _beneficiary;
        createdAt = block.timestamp;

        _mint(_controller, TOTAL_SUPPLY);
    }
}
