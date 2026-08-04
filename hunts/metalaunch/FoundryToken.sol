// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title FoundryToken
/// @notice Plain, fixed-supply ERC-20 deployed by the MetaLaunch launchpad on
///         Robinhood Chain. The entire supply is minted once at construction.
///         There is NO mint function, NO owner, and NO privileged access of
///         any kind — supply can only ever go down (via burn).
contract FoundryToken {
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    error InsufficientBalance();
    error InsufficientAllowance();

    constructor(string memory name_, string memory symbol_, uint256 supply_) {
        name = name_;
        symbol = symbol_;
        totalSupply = supply_;
        balanceOf[msg.sender] = supply_;
        emit Transfer(address(0), msg.sender, supply_);
    }

    function transfer(address to, uint256 value) external returns (bool) {
        return _transfer(msg.sender, to, value);
    }

    function transferFrom(address from, address to, uint256 value) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            if (allowed < value) revert InsufficientAllowance();
            unchecked { allowance[from][msg.sender] = allowed - value; }
        }
        return _transfer(from, to, value);
    }

    function approve(address spender, uint256 value) external returns (bool) {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    /// @notice Burn tokens from the caller's own balance.
    function burn(uint256 value) external {
        if (balanceOf[msg.sender] < value) revert InsufficientBalance();
        unchecked { balanceOf[msg.sender] -= value; }
        totalSupply -= value;
        emit Transfer(msg.sender, address(0), value);
    }

    function _transfer(address from, address to, uint256 value) internal returns (bool) {
        if (balanceOf[from] < value) revert InsufficientBalance();
        unchecked { balanceOf[from] -= value; }
        balanceOf[to] += value;
        emit Transfer(from, to, value);
        return true;
    }
}
