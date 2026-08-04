// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title ISlvrVoteEscrow
/// @notice Interface for vote escrow NFT contract
interface ISlvrVoteEscrow {
    struct Lock {
        uint256 amount;
        uint256 lockStart;
        uint256 lockEnd;
        bool permanent;
    }

    function TMAX() external view returns (uint256);
    function getVotingPower(uint256 tokenId) external view returns (uint256);
    function getStakingWeight(uint256 tokenId) external view returns (uint256);
    function getRewardMultiplier(uint256 tokenId) external view returns (uint256);
    function getTotalVotingPower(address user) external view returns (uint256);
    function getUserTokens(address user) external view returns (uint256[] memory);
    function getLock(uint256 tokenId) external view returns (Lock memory);
    function ownerOf(uint256 tokenId) external view returns (address);
    function createLock(uint256 amount, uint256 duration) external returns (uint256 tokenId);
    function createPermanentLock(uint256 amount) external returns (uint256 tokenId);
    function createLockFor(address user, uint256 amount, uint256 duration) external returns (uint256 tokenId);
    function createPermanentLockFor(address user, uint256 amount) external returns (uint256 tokenId);
    function addToMaxLock(address user, uint256 amount, bool permanent) external returns (uint256 tokenId);
    function increaseLock(uint256 tokenId, uint256 amount, uint256 newDuration) external;
    function increaseLockFor(uint256 tokenId, uint256 amount, uint256 newDuration) external;
    function getMaxLockTokenId(address user) external view returns (uint256 tokenId);
    function getPermanentLockTokenId(address user) external view returns (uint256 tokenId);
    function setAuthorizedContract(address contract_) external;

    // Governance voting surface (ERC-5805 / ERC-6372, timestamp clock)
    function clock() external view returns (uint48);
    // solhint-disable-next-line func-name-mixedcase
    function CLOCK_MODE() external view returns (string memory);
    function getVotes(address account) external view returns (uint256);
    function getPastVotes(address account, uint256 timepoint) external view returns (uint256);
    function getPastTotalSupply(uint256 timepoint) external view returns (uint256);
}
