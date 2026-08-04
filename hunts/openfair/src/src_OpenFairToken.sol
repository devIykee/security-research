// SPDX-License-Identifier: MIT
// Launched via openfair.app - create your own token on Robinhood Chain: https://openfair.app
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

/**
 * @title OpenFairToken
 * @notice ERC-20 token for an openfair.app bonding-curve fair launch.
 *
 * Lifecycle:
 *  1. Deploy: the full fixed supply is minted once to the initial holder
 *     (the LaunchFactory). There is no other mint — the supply can never grow.
 *  2. Setup: the deployer (factory) sets the launch contract address once
 *     (`setLaunchpad`) and distributes the supply (curve + optional vesting)
 *     inside the same transaction.
 *  3. Curve phase (before graduation): tokens can ONLY move to/from the launch
 *     contract — buying from the curve (from == launchpad) and selling back to
 *     it (to == launchpad). Wallet-to-wallet transfers are blocked, so no
 *     "fake market" can form before real liquidity exists.
 *  4. Graduation: the launch contract calls `graduate()`, flipping the token to
 *     a normal, freely transferable ERC-20 forever.
 *
 * Guarantees (verifiable from the code):
 *  - No mint after deployment, no owner/admin, no pause, no blacklist, no
 *    transfer fee, no proxy/delegatecall/selfdestruct.
 *  - The only "privileged" actions are the deployer's one-time `setLaunchpad`
 *    and the launchpad-only `graduate()` switch — after graduation nobody
 *    holds any special power.
 */
contract OpenFairToken is ERC20, ERC20Burnable {
    /// @notice Where this contract comes from (on-chain provenance).
    string public constant OPENFAIR = "Launched via openfair.app - create your own token on Robinhood Chain: https://openfair.app";

    error TradingClosed();
    error NotDeployer();
    error LaunchpadAlreadySet();
    error LaunchpadNotSet();
    error NotLaunchpad();
    error AlreadyGraduated();
    error ZeroAddress();
    error ZeroSupply();

    /// @notice Emitted once when the launch contract address is fixed.
    event LaunchpadSet(address indexed launchpad);
    /// @notice Emitted once when trading is opened (free transfers) at graduation.
    event Graduated();

    /// @notice One-time setup role (the LaunchFactory). No standing power.
    address public immutable deployer;

    /// @notice The bonding-curve launch contract. Set once, then immutable in practice.
    address public launchpad;

    /// @notice false during the curve phase, true forever after graduation.
    bool public graduated;

    constructor(string memory name_, string memory symbol_, uint256 totalSupply_, address initialHolder_)
        ERC20(name_, symbol_)
    {
        if (initialHolder_ == address(0)) revert ZeroAddress();
        if (totalSupply_ == 0) revert ZeroSupply();
        deployer = msg.sender;
        _mint(initialHolder_, totalSupply_);
    }

    /**
     * @notice One-time: fix the launch contract address. Callable only by the
     * deployer (factory), only once.
     */
    function setLaunchpad(address launchpad_) external {
        if (msg.sender != deployer) revert NotDeployer();
        if (launchpad != address(0)) revert LaunchpadAlreadySet();
        if (launchpad_ == address(0)) revert ZeroAddress();
        launchpad = launchpad_;
        emit LaunchpadSet(launchpad_);
    }

    /**
     * @notice Opens free transfers forever. Callable ONLY by the launch contract,
     * exactly once, at graduation (when the curve deploys locked liquidity).
     */
    function graduate() external {
        if (launchpad == address(0)) revert LaunchpadNotSet();
        if (msg.sender != launchpad) revert NotLaunchpad();
        if (graduated) revert AlreadyGraduated();
        graduated = true;
        emit Graduated();
    }

    /**
     * @dev Transfer gating. After graduation: unrestricted. During the curve
     * phase: only mint, factory distribution, and buys/sells with the launch
     * contract are allowed; every other transfer reverts, preventing any
     * secondary market before real liquidity is locked.
     */
    function _update(address from, address to, uint256 value) internal override {
        if (!graduated) {
            bool allowed = from == address(0) // mint in constructor
                || from == deployer // factory distributing supply (curve / vesting)
                || from == launchpad // buys: curve -> buyer, and burns by the launch
                || to == launchpad; // sells: buyer -> curve
            if (!allowed) revert TradingClosed();
        }
        super._update(from, to, value);
    }
}
