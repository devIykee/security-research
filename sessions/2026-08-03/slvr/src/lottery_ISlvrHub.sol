// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title ISlvrHub
/// @notice Game-facing surface of the protocol hub. Games route emissions and shared-sink
///         deposits through the hub; the hub authorizes the caller via the registry, enforces
///         per-game emission budgets, and fans many games into one staker stream and one jackpot.
interface ISlvrHub {
    /// @notice Mint the caller-game's accrued SLVR reward (up to `requested`).
    /// @dev Bounded by the game's streamed emission budget and the protocol soft-cap headroom.
    ///      Returns the amount actually minted (may be less than requested).
    function mintReward(address to, uint256 requested) external returns (uint256 minted);

    /// @notice Forward native protocol fees to the shared veNFT staker stream.
    /// @dev The hub owns the sequential counter the staking contract requires, so games need
    ///      no synchronized round numbering. Value may be 0 (keeps the sequence tight).
    function payStakers() external payable;

    /// @notice Deposit native funds into the shared jackpot pool.
    function feedJackpot() external payable;

    /// @notice Roll the shared jackpot for the caller-game.
    /// @dev The hub assigns a protocol-global epoch id to avoid cross-game collisions in the pot.
    ///      Any bonus is forwarded back to the caller-game.
    /// @return globalEpoch The hub-assigned epoch id (store it to distribute bribes later).
    function rollJackpot(uint256 winnerTotal, uint256 randomness)
        external
        returns (uint256 globalEpoch, bool hit, uint256 ethBonus, uint256 slvrBonus);

    /// @notice Distribute bribe tokens for a hit epoch (caller must own the epoch).
    function distributeBribes(uint256 globalEpoch) external;

    /// @notice Distribute a winner's bribe share for a hit epoch (caller must own the epoch).
    function distributeBribesToWinner(uint256 globalEpoch, address winner, uint256 userBet, uint256 winnerTotal)
        external;
}
