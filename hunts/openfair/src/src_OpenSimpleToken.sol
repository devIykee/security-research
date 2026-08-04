// SPDX-License-Identifier: MIT
// Launched via openfair.app - create your own token on Robinhood Chain: https://openfair.app
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

/**
 * @title OpenSimpleToken
 * @notice The token behind openfair instant listings. Deliberately the most
 * boring ERC-20 possible: fixed supply minted once at deployment, burnable,
 * and NOTHING else — no owner, no mint, no pause, no blacklist, no transfer
 * hooks, no fees, no proxy.
 *
 * Instant listings never have a bonding-curve phase, so the pre-graduation
 * transfer gate of OpenFairToken is unnecessary here; leaving it out keeps
 * automated token scanners (GoPlus & co) from misreading the gate as a
 * "blacklist" capability.
 */
contract OpenSimpleToken is ERC20, ERC20Burnable {
    /// @notice Where this contract comes from (on-chain provenance).
    string public constant OPENFAIR = "Launched via openfair.app - create your own token on Robinhood Chain: https://openfair.app";

    error ZeroAddress();
    error ZeroSupply();

    constructor(string memory name_, string memory symbol_, uint256 totalSupply_, address initialHolder_)
        ERC20(name_, symbol_)
    {
        if (initialHolder_ == address(0)) revert ZeroAddress();
        if (totalSupply_ == 0) revert ZeroSupply();
        _mint(initialHolder_, totalSupply_);
    }
}
