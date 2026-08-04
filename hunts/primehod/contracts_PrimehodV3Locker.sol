// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./UniV3Interfaces.sol";

/**
 * @title PrimehodV3Locker
 * @notice One per v3-venue launch. Permanently holds the Uniswap v3 LP position
 *         NFT for a launched token, so the pooled liquidity can never be pulled:
 *         there is NO function that moves the NFT or decreases liquidity — not
 *         for the creator, not for the platform, not for anyone.
 *
 *         What it CAN do is collect the swap fees the position earns (the pool's
 *         fixed 1% fee tier) and split them between the token's creator and the
 *         platform, using the same split as the bonding-curve venue (default
 *         55 / 45). `collect()` is permissionless: anyone may trigger a payout,
 *         funds only ever flow to the two immutable recipients.
 */
contract PrimehodV3Locker is ReentrancyGuard {
    INonfungiblePositionManagerMin public immutable npm;
    address public immutable factory; // the Primehod factory that deployed this locker
    address public immutable creator;
    address public immutable platform;
    uint256 public immutable creatorSplitBps; // creator's share of fees, out of 10000

    uint256 public tokenId; // the locked position; set once

    event PositionLocked(uint256 tokenId);
    event FeesCollected(uint256 creatorAmount0, uint256 platformAmount0, uint256 creatorAmount1, uint256 platformAmount1);

    constructor(address _npm, address _creator, address _platform, uint256 _creatorSplitBps) {
        require(_npm != address(0) && _creator != address(0) && _platform != address(0), "zero addr");
        require(_creatorSplitBps <= 10000, "split>100%");
        npm = INonfungiblePositionManagerMin(_npm);
        factory = msg.sender;
        creator = _creator;
        platform = _platform;
        creatorSplitBps = _creatorSplitBps;
    }

    /// @notice Called once by the factory right after it mints the position to
    ///         this locker (the position manager's `mint` does not fire the
    ///         ERC-721 receive hook). The NFT must already be owned here.
    function lock(uint256 _tokenId) external {
        require(msg.sender == factory, "only factory");
        require(tokenId == 0, "already locked");
        require(IERC721Min(address(npm)).ownerOf(_tokenId) == address(this), "position not held");
        tokenId = _tokenId;
        emit PositionLocked(_tokenId);
    }

    /// @dev Accept safe transfers from the position manager (defensive; `mint`
    ///      uses a plain transfer). The NFT can enter but can never leave.
    function onERC721Received(address, address, uint256, bytes calldata) external view returns (bytes4) {
        require(msg.sender == address(npm), "only position manager");
        return this.onERC721Received.selector;
    }

    /// @notice Collect the position's accrued swap fees and split them
    ///         creator / platform. Callable by anyone.
    function collect(address token0, address token1) external nonReentrant {
        require(tokenId != 0, "no position");
        npm.collect(
            INonfungiblePositionManagerMin.CollectParams({
                tokenId: tokenId,
                recipient: address(this),
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            })
        );
        uint256 c0 = _split(token0);
        uint256 c1 = _split(token1);
        emit FeesCollected(c0, 0, c1, 0);
    }

    function _split(address token) private returns (uint256 creatorAmount) {
        uint256 bal = IERC20(token).balanceOf(address(this));
        if (bal == 0) return 0;
        creatorAmount = (bal * creatorSplitBps) / 10000;
        uint256 platformAmount = bal - creatorAmount;
        if (creatorAmount > 0) require(IERC20(token).transfer(creator, creatorAmount), "creator transfer failed");
        if (platformAmount > 0) require(IERC20(token).transfer(platform, platformAmount), "platform transfer failed");
    }
}
