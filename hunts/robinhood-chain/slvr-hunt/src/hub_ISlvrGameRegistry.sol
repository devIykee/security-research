// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title ISlvrGameRegistry
/// @notice Governance-controlled registry of games. Single source of truth for which
///         games exist, their status, tier, and their share of the shared emission stream.
/// @dev Owner registers/retires and tunes weights; a separate guardian may only pause/unpause
///      (fast circuit breaker) without holding full ownership.
interface ISlvrGameRegistry {
    enum Status {
        Pending, // registered but not yet earning/active
        Active, // participating in emissions and shared sinks
        Paused, // temporarily halted (guardian can toggle)
        Retired // permanently removed
    }

    enum Tier {
        Core, // audited first-party games
        Community, // reviewed community games
        Experimental // capped, sandboxed games
    }

    struct GameInfo {
        address game;
        bytes32 gameType;
        Status status;
        Tier tier;
        uint32 emissionWeight; // relative share of the global emission stream
        uint16 maxWeightBps; // guardrail: ceiling on realized fraction of the stream (bps of 10000)
        bool exists;
    }

    event GameRegistered(uint256 indexed gameId, address indexed game, bytes32 gameType, Tier tier);
    event GameStatusChanged(uint256 indexed gameId, Status status);
    event GameWeightChanged(uint256 indexed gameId, uint32 emissionWeight, uint16 maxWeightBps);
    event GuardianChanged(address indexed guardian);

    /// @notice Registry id for a game address (0 if not registered). Ids are 1-based.
    function gameIdOf(address game) external view returns (uint256);

    /// @notice Full record for a game id.
    function gameInfo(uint256 gameId) external view returns (GameInfo memory);

    /// @notice Convenience: is this address a registered, Active game?
    function isActive(address game) external view returns (bool);

    function statusOf(uint256 gameId) external view returns (Status);

    function tierOf(uint256 gameId) external view returns (Tier);

    function weightOf(uint256 gameId) external view returns (uint32);

    function maxWeightBpsOf(uint256 gameId) external view returns (uint16);

    /// @notice Sum of emissionWeight across all Active games (denominator for the split).
    function totalActiveWeight() external view returns (uint256);

    function gameCount() external view returns (uint256);
}
