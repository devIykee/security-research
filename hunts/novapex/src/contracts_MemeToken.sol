// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title MemeToken
/// @notice A minimal fixed-supply ERC-20. The entire supply is minted to the
///         factory (the bonding curve) at deployment; there is no owner, no
///         mint, and no burn — so the curve holds all tradable tokens and the
///         supply can never change. This is deliberately dumb: all pricing and
///         trading logic lives in PumpFactory.
contract MemeToken is ERC20 {
    /// @dev Optional metadata surfaced by the frontend. Immutable after deploy.
    string public description;
    string public imageURI;
    address public immutable creator;

    constructor(
        string memory name_,
        string memory symbol_,
        string memory description_,
        string memory imageURI_,
        address creator_,
        uint256 totalSupply_
    ) ERC20(name_, symbol_) {
        description = description_;
        imageURI = imageURI_;
        creator = creator_;
        // Mint the whole supply to the factory (msg.sender). The curve owns it.
        _mint(msg.sender, totalSupply_);
    }
}
