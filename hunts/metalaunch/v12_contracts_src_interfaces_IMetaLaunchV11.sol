// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @notice The locker interface the factory calls at launch. The locker exposes
///         NO liquidity-exit function — see MetaLaunchLockerV11.
interface IMetaLaunchLockerV11 {
    function positionManager() external view returns (address);
    function protocolFeeRecipient() external view returns (address);
    function protocolFeeShareBps() external view returns (uint16);

    /// @notice Called by the factory in the launch tx, immediately after the
    ///         position NFT is safeTransferFrom'd to the locker, to record the
    ///         locked position and snapshot its protocol-fee share + creator
    ///         fee recipient. Factory-only.
    function registerLock(
        address token,
        address deployer,
        address feeWallet,
        address positionManager_,
        uint256 positionId,
        uint16 protocolShareBps
    ) external;

    function isLocked(address token) external view returns (bool);
    function lockedPositionId(address token) external view returns (uint256);
    function creatorFeeRecipient(address token) external view returns (address);
    function tokenProtocolFeeShare(address token) external view returns (uint16);
}

/// @notice The factory records the locker reads for its authority checks.
interface IMetaLaunchFactoryV11View {
    function tokenCreator(address token) external view returns (address);
    function positionManagerOf(address token) external view returns (address);
    function poolOf(address token) external view returns (address);
    function isLaunchedToken(address token) external view returns (bool);
}
