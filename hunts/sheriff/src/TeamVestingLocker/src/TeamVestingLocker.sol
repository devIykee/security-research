// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {VestingWallet} from "@openzeppelin/contracts/finance/VestingWallet.sol";

/// @title TeamVestingLocker
/// @notice 50M ROB team vesting: 30-day cliff, then linear over 365 days.
/// @dev Extends OZ VestingWallet. Cliff is enforced by overriding _vestingSchedule.
///      Beneficiary and start are immutable. Release is permissionless — anyone can call.
///      No admin functions, no pause, no recovery.
contract TeamVestingLocker is VestingWallet {
    /// @notice Cliff period — vesting returns 0 before this offset from start.
    uint64 public constant CLIFF = 30 days;

    /// @notice Total vesting window (cliff is included in this period).
    uint64 public constant VEST_DURATION = 365 days;

    /// @param beneficiaryAddress Address that will receive vested tokens.
    /// @param startTimestamp Unix timestamp when vesting begins (should be LP-mint block.timestamp).
    constructor(address beneficiaryAddress, uint64 startTimestamp)
        VestingWallet(beneficiaryAddress, startTimestamp, VEST_DURATION)
    {}

    /// @notice Returns the beneficiary address (immutable; equals the contract owner).
    function beneficiary() external view returns (address) {
        return owner();
    }

    /// @notice Convenience getter for the cliff constant.
    function cliff() external pure returns (uint64) {
        return CLIFF;
    }

    /// @notice Convenience getter for the vest duration constant.
    function vestingDuration() external pure returns (uint64) {
        return VEST_DURATION;
    }

    /// @dev Override: return 0 before cliff; delegate to OZ linear schedule after cliff.
    /// @param totalAllocation Historic total (balance + already released).
    /// @param timestamp       Query timestamp (block.timestamp for current vested amount).
    function _vestingSchedule(uint256 totalAllocation, uint64 timestamp) internal view override returns (uint256) {
        if (timestamp < uint64(start()) + CLIFF) return 0;
        return super._vestingSchedule(totalAllocation, timestamp);
    }
}
