// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

interface IVaultCheckpoint {
    function checkpoint(address from, address to, uint256 value) external;
}

/// @title MemeTokenV2
/// @notice Fixed-supply meme token. The ENTIRE supply is minted once to the
///         factory at launch, which forwards it to the bonding-curve pool.
///         There is NO creator allocation and NO post-launch minting. Supply is
///         later accounted explicitly as:
///           curve-sold  +  DEX-liquidity  +  burned-excess  =  TOTAL_SUPPLY
///         The DEX-liquidity amount is computed at graduation from the terminal
///         price; unsold curve tokens beyond that are burned (documented
///         policy), never routed to the creator or deployer.
contract MemeTokenV2 is ERC20 {
    uint256 public constant TOTAL_SUPPLY = 1_000_000_000e18;

    address public immutable factory;
    address public pool; // set once by factory
    address public rewardVault; // holder vault; set once by factory
    string public metadataURI;

    error OnlyFactory();
    error AlreadySet();
    error ZeroAddress();
    error OnlyPool();

    constructor(string memory name_, string memory symbol_, string memory metadataURI_) ERC20(name_, symbol_) {
        factory = msg.sender;
        metadataURI = metadataURI_;
        _mint(msg.sender, TOTAL_SUPPLY);
    }

    function setPool(address pool_) external {
        if (msg.sender != factory) revert OnlyFactory();
        if (pool != address(0)) revert AlreadySet();
        if (pool_ == address(0)) revert ZeroAddress();
        pool = pool_;
    }

    function setRewardVault(address vault) external {
        if (msg.sender != factory) revert OnlyFactory();
        if (rewardVault != address(0)) revert AlreadySet();
        if (vault == address(0)) revert ZeroAddress();
        rewardVault = vault;
    }

    /// @notice Burn tokens held by the pool (graduation excess). Pool only.
    function burnFromPool(uint256 amount) external {
        if (msg.sender != pool) revert OnlyPool();
        _burn(pool, amount);
    }

    function _update(address from, address to, uint256 value) internal override {
        super._update(from, to, value);
        address v = rewardVault;
        if (v != address(0)) IVaultCheckpoint(v).checkpoint(from, to, value);
    }
}
