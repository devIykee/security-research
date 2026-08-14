// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

/// @title SheriffToken
/// @notice SHERIFF ERC-20 token. Fixed 1B supply minted atomically to recipients at construction.
/// @dev Byte-for-byte structural clone of RobToken: identical supply, launch-guard, and immutability
///      surface. Separate contract so ROB and Sheriff can be deployed independently on the same chain
///      without sharing symbol/name metadata. Any behavioral change here must also be applied to
///      RobToken to keep the two in parity.
///
///      Launch guard (self-expiring):
///      For 30 minutes after construction, no EOA may receive tokens if that
///      would push its balance above 2 percent of TOTAL_SUPPLY. Contract
///      recipients are exempt (to.code.length > 0). Constructor mints bypass
///      the guard because from == address(0). After 30 minutes the guard
///      self-expires with no toggle, admin, or extension surface.
contract SheriffToken is ERC20, ERC20Burnable {
    /// @notice The total fixed supply: 1,000,000,000 tokens with 18 decimals.
    uint256 public constant TOTAL_SUPPLY = 1_000_000_000 ether;

    /// @notice Per-wallet cap during the launch guard, in basis points of TOTAL_SUPPLY.
    /// @dev 200 bps = 2 percent = 20,000,000 SHERIFF.
    uint256 public constant LAUNCH_GUARD_MAX_WALLET_BPS = 200;

    /// @notice How long the launch guard stays active after construction.
    uint256 public constant LAUNCH_GUARD_DURATION = 30 minutes;

    /// @notice Timestamp captured at construction; guard expires at launchTime + LAUNCH_GUARD_DURATION.
    uint256 public immutable launchTime;

    /// @notice Deploy and distribute the entire supply atomically.
    /// @dev Reverts if arrays differ in length, any recipient is address(0),
    ///      or amounts do not sum exactly to TOTAL_SUPPLY.
    /// @param recipients Array of addresses to receive tokens.
    /// @param amounts    Corresponding token amounts (wei). Must sum to TOTAL_SUPPLY.
    constructor(address[] memory recipients, uint256[] memory amounts) ERC20("Sheriff", "SHERIFF") {
        require(recipients.length == amounts.length, "SheriffToken: length mismatch");
        uint256 total;
        for (uint256 i; i < recipients.length; ++i) {
            require(recipients[i] != address(0), "SheriffToken: zero recipient");
            total += amounts[i];
            _mint(recipients[i], amounts[i]);
        }
        require(total == TOTAL_SUPPLY, "SheriffToken: sum != TOTAL_SUPPLY");
        launchTime = block.timestamp;
    }

    /// @notice Convenience view returning the absolute wallet cap during the guard window.
    function launchGuardMaxWallet() public pure returns (uint256) {
        return (TOTAL_SUPPLY * LAUNCH_GUARD_MAX_WALLET_BPS) / 10000;
    }

    /// @notice True while the 30-minute post-deploy guard is still active.
    function launchGuardActive() public view returns (bool) {
        return block.timestamp < launchTime + LAUNCH_GUARD_DURATION;
    }

    /// @dev Enforces the 2%-per-wallet cap on EOA recipients during the first
    ///      30 minutes after deploy. Mints (from == address(0)) and contract
    ///      recipients (to.code.length > 0) are exempt. Self-expiring; no
    ///      toggle, admin, or block.number dependency (Orbit-safe).
    function _update(address from, address to, uint256 value) internal override {
        if (from != address(0) && block.timestamp < launchTime + LAUNCH_GUARD_DURATION && to.code.length == 0) {
            uint256 maxWallet = (TOTAL_SUPPLY * LAUNCH_GUARD_MAX_WALLET_BPS) / 10000;
            require(balanceOf(to) + value <= maxWallet, "SheriffToken: launch guard max wallet");
        }
        super._update(from, to, value);
    }
}
