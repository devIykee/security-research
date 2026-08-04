// SPDX-License-Identifier: MIT
// Launched via openfair.app - create your own token on Robinhood Chain: https://openfair.app
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title OpenTeamVesting
 * @notice Minimal linear vesting safe for an optional team allocation
 * ("Team locked" badge). Immutable: token, beneficiary, start and duration are
 * fixed at deployment; nobody – not the platform, not the creator – can change
 * the schedule or pull tokens out early.
 *
 * Note: the underlying OpenFairToken blocks transfers until graduation, so even
 * fully-vested tokens only become claimable once the launch has graduated.
 */
contract OpenTeamVesting {
    using SafeERC20 for IERC20;

    error NothingToRelease();
    error ZeroAddress();
    error BadConfig();

    event Released(uint256 amount);

    IERC20 public immutable token;
    address public immutable beneficiary;
    uint64 public immutable start;
    uint64 public immutable duration;

    uint256 public released;

    constructor(address token_, address beneficiary_, uint64 start_, uint64 duration_) {
        if (token_ == address(0) || beneficiary_ == address(0)) revert ZeroAddress();
        if (duration_ == 0) revert BadConfig();
        token = IERC20(token_);
        beneficiary = beneficiary_;
        start = start_;
        duration = duration_;
    }

    /// @notice Total tokens this safe has ever held (still locked + released).
    function totalAllocation() public view returns (uint256) {
        return token.balanceOf(address(this)) + released;
    }

    /// @notice Amount vested at `timestamp` (linear from start over duration).
    function vestedAmount(uint64 timestamp) public view returns (uint256) {
        uint256 total = totalAllocation();
        if (timestamp <= start) return 0;
        if (timestamp >= start + duration) return total;
        return total * (timestamp - start) / duration;
    }

    /// @notice Releasable right now.
    function releasable() public view returns (uint256) {
        return vestedAmount(uint64(block.timestamp)) - released;
    }

    /// @notice Permissionless: transfers everything vested so far to the beneficiary.
    function release() external {
        uint256 amount = releasable();
        if (amount == 0) revert NothingToRelease();
        released += amount;
        token.safeTransfer(beneficiary, amount);
        emit Released(amount);
    }
}
