// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface ILaunchpadFactoryTransfers {
    function emitTokenTransfer(address from, address to, uint256 amount) external;
}

/// @title MemeToken
/// @notice Immutable ERC-20 for the Robino launchpad.
///         Fixed 1B supply, minted once to the bonding curve at creation.
///         No owner, no mint after deploy, no tax, no blacklist, no pause.
///         The token itself is "clean" — all fees/anti-snipe live in the
///         BondingCurve during the curve phase; once graduated it is an
///         ordinary token on Uniswap.
contract MemeToken {
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;
    uint256 public immutable totalSupply;

    // on-chain metadata (immutable, written once at construction)
    string public description;
    string public image;      // ipfs://... logo
    string public twitter;
    string public telegram;
    string public website;
    address public immutable creator;
    address public immutable curve; // the bonding curve that custodies supply
    address public immutable factory;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    struct Meta {
        string name;
        string symbol;
        string description;
        string image;
        string twitter;
        string telegram;
        string website;
    }

    /// @param m       token metadata
    /// @param supply  full fixed supply (18 decimals)
    /// @param _creator token creator wallet
    /// @dev The full supply is minted to msg.sender (the BondingCurve deployer).
    constructor(Meta memory m, uint256 supply, address _creator, address _factory) {
        name = m.name;
        symbol = m.symbol;
        description = m.description;
        image = m.image;
        twitter = m.twitter;
        telegram = m.telegram;
        website = m.website;
        creator = _creator;
        curve = msg.sender;
        factory = _factory;
        totalSupply = supply;

        balanceOf[msg.sender] = supply;
        emit Transfer(address(0), msg.sender, supply);
    }

    function transfer(address to, uint256 value) external returns (bool) {
        return _transfer(msg.sender, to, value);
    }

    function approve(address spender, uint256 value) external returns (bool) {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            require(allowed >= value, "allowance");
            allowance[from][msg.sender] = allowed - value;
        }
        return _transfer(from, to, value);
    }

    function _transfer(address from, address to, uint256 value) internal returns (bool) {
        require(to != address(0), "zero");
        uint256 bal = balanceOf[from];
        require(bal >= value, "balance");
        unchecked {
            balanceOf[from] = bal - value;
            balanceOf[to] += value;
        }
        emit Transfer(from, to, value);
        ILaunchpadFactoryTransfers(factory).emitTokenTransfer(from, to, value);
        return true;
    }
}
