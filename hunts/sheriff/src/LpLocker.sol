// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {INonfungiblePositionManager} from "./interfaces/INonfungiblePositionManager.sol";

interface IERC721Receiver {
    function onERC721Received(address, address, uint256, bytes calldata) external returns (bytes4);
}

/// @title LpLocker
/// @notice Holds a Uniswap v3 LP NFT forever.
///         Only allows fees to be collected to an immutable recipient.
///         The position can NEVER be unwound: there is no path to
///         decreaseLiquidity, transferFrom, or burn.
///         From a withdrawal standpoint this is equivalent to burning the LP,
///         while still allowing trading fees to be claimed.
contract LpLocker is IERC721Receiver {
    INonfungiblePositionManager public immutable positionManager;
    address public immutable feeRecipient;
    uint256 public tokenId;

    event Locked(uint256 indexed tokenId);
    event FeesCollected(uint256 amount0, uint256 amount1);

    constructor(address _positionManager, address _feeRecipient) {
        require(_positionManager != address(0), "pm=0");
        require(_feeRecipient != address(0), "recipient=0");
        positionManager = INonfungiblePositionManager(_positionManager);
        feeRecipient = _feeRecipient;
    }

    /// @notice Receives the LP NFT exactly once.
    function onERC721Received(address, address, uint256 _id, bytes calldata) external returns (bytes4) {
        require(msg.sender == address(positionManager), "not v3 NFT");
        require(tokenId == 0, "already locked");
        tokenId = _id;
        emit Locked(_id);
        return IERC721Receiver.onERC721Received.selector;
    }

    /// @notice Anyone may call. Fees always go to the immutable recipient.
    function collectFees() external returns (uint256 amount0, uint256 amount1) {
        (amount0, amount1) = positionManager.collect(
            INonfungiblePositionManager.CollectParams({
                tokenId: tokenId, recipient: feeRecipient, amount0Max: type(uint128).max, amount1Max: type(uint128).max
            })
        );
        emit FeesCollected(amount0, amount1);
    }
}
