// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.26;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {IVestingToken} from "src/interfaces/IVestingToken.sol";

import {ZooERC20} from "src/erc20/ZooERC20.sol";

contract VestingToken is IVestingToken, ZooERC20 {

    address public immutable vault;

    constructor(
        address _vault, string memory _name, string memory _symbol, uint8 _decimals
    ) ZooERC20(_name, _symbol, _decimals) {
        require(_vault != address(0), "Zero address detected");

        vault = _vault;
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    function mint(address to, uint256 amount) external nonReentrant onlyVault {
        _mint(to, amount);
    }

    function burn(address account, uint256 amount) external nonReentrant onlyVault {
        _burn(account, amount);
    }

    /* ============== MODIFIERS =============== */

    modifier onlyVault() {
        require(vault == _msgSender(), "Caller is not Vault");
        _;
    }
}
