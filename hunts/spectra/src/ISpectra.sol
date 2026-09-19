// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ISpectra is IERC20 {
    /// @notice Mint an amount of tokens to an account
    ///         Only callable by MINTER role
    /// @return True if success
    function mint(address account, uint256 amount) external returns (bool);
}
