// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title ISlvrVoteEscrowMetadata
/// @notice Interface for vote escrow NFT metadata contract
interface ISlvrVoteEscrowMetadata {
    /// @notice Get the token URI for a given token ID
    /// @param tokenId The token ID
    /// @param veContract The address of the vote escrow contract (for querying lock data)
    /// @return The token URI (JSON metadata)
    function tokenURI(uint256 tokenId, address veContract) external view returns (string memory);
}

