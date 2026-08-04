// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title LaunchToken
/// @notice A fixed-supply ERC-20 minted entirely to the launchpad. Deployed ONCE as an
///         implementation; each launched token is a cheap EIP-1167 minimal-proxy CLONE of it,
///         configured via initialize() in the same tx it is created (a clone runs no
///         constructor). The ~45-byte proxy makes a deploy vastly cheaper than a full contract
///         and stops wallets over-estimating the L1 data cost.
contract LaunchToken is ERC20 {
    string private _tName;
    string private _tSymbol;
    address public launchpad;
    bool private _initialized;

    // ---- anti-whale wallet cap ----
    // Max tokens a single wallet may HOLD while the token is on the bonding curve.
    // Enforced on EVERY transfer (not just launchpad buys), so it can't be dodged by
    // buying from many wallets and consolidating. 0 = no cap. Lifted at graduation.
    uint256 public maxWallet;
    bool public graduated;

    /// @dev The implementation is deployed with empty metadata and permanently locked, so it
    ///      can never be initialized directly — only clones of it are.
    constructor() ERC20("", "") {
        _initialized = true;
    }

    /// @notice One-time setup for a clone (no wallet cap). Used by launchpads that don't cap
    ///         holdings; kept as a 3-arg overload for backward compatibility.
    function initialize(string calldata name_, string calldata symbol_, uint256 supply) external {
        _init(name_, symbol_, supply, 0);
    }

    /// @notice One-time setup for a clone WITH a per-wallet holding cap.
    /// @param maxWallet_ per-wallet holding cap during bonding (0 = disabled).
    function initialize(string calldata name_, string calldata symbol_, uint256 supply, uint256 maxWallet_) external {
        _init(name_, symbol_, supply, maxWallet_);
    }

    /// @dev The launchpad calls initialize in the SAME tx that creates the clone, so there is
    ///      no front-run window; re-initialization is blocked.
    function _init(string calldata name_, string calldata symbol_, uint256 supply, uint256 maxWallet_) internal {
        require(!_initialized, "initialized");
        _initialized = true;
        _tName = name_;
        _tSymbol = symbol_;
        launchpad = msg.sender;
        maxWallet = maxWallet_;
        _mint(msg.sender, supply);
    }

    /// @notice The launchpad flips this when the token graduates, permanently lifting the
    ///         per-wallet cap so the graduated token trades as a free market.
    function setGraduated() external {
        require(msg.sender == launchpad, "not launchpad");
        graduated = true;
    }

    /// @dev Enforce the per-wallet holding cap while the token is still on the curve.
    ///      Exemptions: burns (to == 0) and any transfer INTO the launchpad (the initial
    ///      mint-to-launchpad and every sell must never be blocked). Buy payouts and
    ///      wallet-to-wallet transfers land on a normal `to`, so they ARE capped — which
    ///      is what makes the cap a true holding limit, not just a buy-time gate.
    function _update(address from, address to, uint256 value) internal override {
        if (!graduated && maxWallet != 0 && to != launchpad && to != address(0)) {
            require(balanceOf(to) + value <= maxWallet, "exceeds max wallet");
        }
        super._update(from, to, value);
    }

    function name() public view override returns (string memory) {
        return _tName;
    }

    function symbol() public view override returns (string memory) {
        return _tSymbol;
    }
}
