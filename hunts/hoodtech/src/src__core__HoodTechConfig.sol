// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @notice Protocol-wide constants shared by HoodTechFactory and HoodTechPositions.
library HoodTechConstants {
    /// @notice Fixed supply for every HoodTech token.
    uint256 internal constant TOTAL_SUPPLY = 1_000_000_000 * 1e18;

    /// @notice Starting market cap for every launch: 1 ETH, in all cases.
    uint256 internal constant STARTING_MCAP_ETH = 1 ether;

    /// @notice Flat Uniswap V3 fee tier: 10000 = 1% per swap, paid by traders to LPs.
    ///         The single LP position is owned by the protocol locker, so the whole
    ///         1% is collected there and split 50/50 → 0.5% creator / 0.5% protocol.
    uint24 internal constant POOL_FEE = 10000;

    /// @notice Tick spacing of the 1% fee tier on canonical Uniswap V3 deployments.
    int24 internal constant TICK_SPACING = 200;

    /// @notice Protocol's share of collected LP fees, in bps. Fixed 50/50 split.
    uint256 internal constant PROTOCOL_SHARE_BPS = 5000;
    uint256 internal constant BPS = 10000;
}

/// @notice Mutable protocol settings: treasury wallet, pause switch, launch fee.
///         Trading-fee percentages are intentionally NOT configurable — flat 1%
///         pool fee, fixed 50/50 creator/protocol split, forever.
contract HoodTechConfig is Ownable {
    uint256 public constant MAX_LAUNCH_FEE = 0.01 ether;

    address public treasury;
    bool public paused;
    /// @notice Flat fee (in ETH) charged per launch, sent to the treasury.
    ///         Any msg.value beyond it funds the creator's same-tx dev buy.
    uint256 public launchFee = 0.0005 ether;

    event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury);
    event PausedUpdated(bool paused);
    event LaunchFeeUpdated(uint256 oldFee, uint256 newFee);

    error InvalidAddress();
    error InvalidFee();

    constructor(address _treasury, address _owner) Ownable(_owner) {
        if (_treasury == address(0)) revert InvalidAddress();
        treasury = _treasury;
    }

    function setTreasury(address _treasury) external onlyOwner {
        if (_treasury == address(0)) revert InvalidAddress();
        emit TreasuryUpdated(treasury, _treasury);
        treasury = _treasury;
    }

    function setPaused(bool _paused) external onlyOwner {
        emit PausedUpdated(_paused);
        paused = _paused;
    }

    function setLaunchFee(uint256 _fee) external onlyOwner {
        if (_fee > MAX_LAUNCH_FEE) revert InvalidFee();
        emit LaunchFeeUpdated(launchFee, _fee);
        launchFee = _fee;
    }
}
