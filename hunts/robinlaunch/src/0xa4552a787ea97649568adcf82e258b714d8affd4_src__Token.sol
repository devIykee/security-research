// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title Token
 * @notice Fair-launch ERC20 with a fixed supply of 1,000,000,000 tokens.
 *         The entire supply is minted to the deployer (Factory) at construction;
 *         the Factory immediately transfers it to the associated BondingCurve.
 */
contract Token is ERC20 {
    uint256 public constant MAX_SUPPLY = 1_000_000_000e18;

    /// @notice Metadata URI (IPFS / HTTP) set at creation
    string public metadataURI;

    constructor(
        string memory _name,
        string memory _symbol,
        string memory _metadataURI
    ) ERC20(_name, _symbol) {
        metadataURI = _metadataURI;
        _mint(msg.sender, MAX_SUPPLY);
    }
}
