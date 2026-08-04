// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title ISlvrVoteEscrowStaking
/// @notice Interface for vote escrow staking contract
interface ISlvrVoteEscrowStaking {
    function distributeRoundRewards(uint256 roundId, uint256 totalWeightSnapshot) external payable;
    function stake(uint256 tokenId) external;
    function unstake(uint256 tokenId) external;
    function checkpoint(uint256 tokenId) external;
    function claimStakerRewards(uint256 tokenId) external;
    function getStakerRewards(uint256 tokenId) external view returns (uint256);
    function poke(uint256 tokenId) external;
    function pokeMany(uint256[] calldata tokenIds) external;
    function claimOnBurn(uint256 tokenId, address owner) external;
    function getTotalWeight() external view returns (uint256);
}
