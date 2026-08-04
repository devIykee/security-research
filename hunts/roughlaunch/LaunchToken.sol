// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @notice Fixed-supply, zero-tax ERC-20 launched directly into a Uniswap V3 pool.
/// @dev Immutable user token (not upgradeable). Intended for public Blockscout source verification.
///      The factory cannot mint, seize balances, alter fees, or modify restrictions after deployment.
contract LaunchToken is ERC20 {
    error OnlyLaunchFactory();
    error PoolAlreadyConfigured();
    error InvalidPool();
    error LaunchBlockBuyBlocked(address recipient);
    error MaxWalletExceeded(address account, uint256 balanceAfter, uint256 maxWalletAmount);

    address public immutable launchFactory;
    address public immutable pairToken;
    uint24 public immutable poolFee;
    uint256 public immutable maxWalletAmount;
    uint256 public immutable launchBlock;
    uint256 public immutable restrictionEndBlock;
    string public metadataURI;

    address public liquidityPool;

    constructor(
        string memory name_,
        string memory symbol_,
        string memory metadataURI_,
        address launchFactory_,
        address pairToken_,
        uint24 poolFee_,
        uint256 totalSupply_,
        uint16 maxWalletBps_,
        uint32 restrictionBlocks_
    ) ERC20(name_, symbol_) {
        if (launchFactory_ == address(0) || pairToken_ == address(0)) revert InvalidPool();
        launchFactory = launchFactory_;
        pairToken = pairToken_;
        poolFee = poolFee_;
        metadataURI = metadataURI_;
        maxWalletAmount = (totalSupply_ * maxWalletBps_) / 10_000;
        launchBlock = block.number;
        restrictionEndBlock = block.number + restrictionBlocks_;
        _mint(launchFactory_, totalSupply_);
    }

    function configureLiquidityPool(address pool) external {
        if (msg.sender != launchFactory) revert OnlyLaunchFactory();
        if (liquidityPool != address(0)) revert PoolAlreadyConfigured();
        if (pool == address(0)) revert InvalidPool();
        liquidityPool = pool;
    }

    function maxWalletLimit() external view returns (uint256) {
        return maxWalletAmount;
    }

    function _update(address from, address to, uint256 value) internal override {
        address pool = liquidityPool;
        if (from == pool && block.number == launchBlock && to != launchFactory) {
            revert LaunchBlockBuyBlocked(to);
        }
        // Max wallet applies to open-market buys during the anti-snipe window.
        // Factory-delivered atomic initial buys (DEV first buy) are exempt so creators
        // can seed any size in the launch transaction; pool→user transfers stay capped.
        if (
            block.number <= restrictionEndBlock && from != address(0) && to != address(0)
                && from != launchFactory && to != launchFactory && to != pool && to != address(0xdead)
        ) {
            uint256 balanceAfter = balanceOf(to) + value;
            if (balanceAfter > maxWalletAmount) {
                revert MaxWalletExceeded(to, balanceAfter, maxWalletAmount);
            }
        }
        super._update(from, to, value);
    }
}