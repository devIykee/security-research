// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title RandomnessLib
/// @notice Library for deriving randomness values from a base randomness value
library RandomnessLib {
    /// @notice Derive randomness ID for a round
    /// @dev Includes roundId for determinism and totalWager for entropy from round state
    function deriveRandomnessId(address contractAddress, uint256 roundId, uint256 totalWager) internal pure returns (bytes32 result) {
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            mstore(ptr, contractAddress)
            mstore(add(ptr, 0x20), roundId)
            mstore(add(ptr, 0x40), totalWager)
            result := keccak256(ptr, 0x60)
        }
    }

    /// @notice Derive jackpot randomness value
    function deriveJackpotRandomness(uint256 baseValue, uint256 roundId) internal pure returns (uint256 result) {
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            mstore(ptr, baseValue)
            mstore(add(ptr, 0x20), roundId)
            // "jackpot" = 7 bytes, stored left-aligned in 32-byte word
            mstore(add(ptr, 0x40), 0x6a61636b706f74000000000000000000000000000000000000000000000000)
            // Hash exactly 71 bytes: 32 (baseValue) + 32 (roundId) + 7 ("jackpot")
            result := keccak256(ptr, 0x47)
        }
    }

    /// @notice Derive single miner randomness value
    function deriveSingleMinerRandomness(uint256 baseValue, uint256 roundId) internal pure returns (uint256 result) {
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            mstore(ptr, baseValue)
            mstore(add(ptr, 0x20), roundId)
            // "singleMiner" = 11 bytes, stored left-aligned in 32-byte word
            mstore(add(ptr, 0x40), 0x73696e676c654d696e65720000000000000000000000000000000000000000)
            // Hash exactly 75 bytes: 32 (baseValue) + 32 (roundId) + 11 ("singleMiner")
            result := keccak256(ptr, 0x4b)
        }
    }

    /// @notice Check if jackpot is hit
    function checkJackpotHit(uint256 randomnessValue, uint256 odds) internal pure returns (bool) {
        return (randomnessValue % odds) == 0;
    }

    /// @notice Check if round is single miner round
    function isSingleMinerRound(uint256 randomnessValue) internal pure returns (bool) {
        return (randomnessValue % 2) == 0;
    }

    /// @notice Calculate winning square from randomness
    function calculateWinningSquare(uint256 randomnessValue, uint8 gridSize) internal pure returns (uint8) {
        return uint8(randomnessValue % gridSize);
    }
}
