// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IRandomnessProvider
/// @notice Generic interface for randomness providers to enable provider upgrades
interface IRandomnessProvider {
    /// @notice Request randomness for a given randomness ID
    /// @param randomnessId The unique identifier for this randomness request
    /// @param authority The address authorized to use this randomness (typically the lottery contract)
    /// @param providerData Additional provider-specific data (e.g., queue ID, delay, etc.)
    function requestRandomness(bytes32 randomnessId, address authority, bytes calldata providerData) external;

    /// @notice Settle randomness using provider-specific update data
    /// @param randomnessId The unique identifier for this randomness request
    /// @param updateData Provider-specific data needed to settle randomness (e.g., Switchboard updates)
    function settleRandomness(bytes32 randomnessId, bytes calldata updateData) external;

    /// @notice Get the settled randomness value
    /// @param randomnessId The unique identifier for this randomness request
    /// @return value The randomness value (0 if not yet settled)
    /// @return settledAt The timestamp when randomness was settled (0 if not yet settled)
    function getRandomness(bytes32 randomnessId) external view returns (uint256 value, uint256 settledAt);

    /// @notice Check if randomness is ready to be settled
    /// @param randomnessId The unique identifier for this randomness request
    /// @return ready True if randomness can be settled
    function isReadyToSettle(bytes32 randomnessId) external view returns (bool ready);
}
