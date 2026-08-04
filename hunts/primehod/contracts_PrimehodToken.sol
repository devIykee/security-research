// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title PrimehodToken
 * @notice A plain, fully-minted ERC-20 launched by the Primehod factory on
 *         Robinhood Chain. The entire supply is minted once, to the factory, at
 *         construction. There is NO mint function, no owner, no pause, no
 *         blacklist, no upgrade path: once deployed the token can only ever be
 *         transferred. This is the self-contained replacement for the Base-native
 *         "B20 asset" precompile, which does not exist on Robinhood Chain.
 * @dev The factory receives the full supply and splits it into the bonding-curve
 *      slice, the vesting slice, and any owner-instant distribution slice.
 */
contract PrimehodToken is ERC20 {
    uint8 private immutable _decimals;

    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        uint256 totalSupply_,
        address mintTo_
    ) ERC20(name_, symbol_) {
        require(mintTo_ != address(0), "zero mintTo");
        require(totalSupply_ > 0, "zero supply");
        _decimals = decimals_;
        _mint(mintTo_, totalSupply_);
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }
}
