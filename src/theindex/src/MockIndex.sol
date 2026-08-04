// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @dev Minimal mirror of ReflectionToken holder registry used by the distributor.
/// Same eligibility rule: balance >= minShareBalance, not rewardsExcluded.
contract MockIndex {
    string public name = "The Index";
    string public symbol = "INDEX";
    uint8 public decimals = 18;
    uint256 public totalSupply;
    uint256 public minShareBalance = 10_000e18;

    mapping(address => uint256) public balanceOf;
    mapping(address => bool) public rewardsExcluded;
    address[] private _holders;
    mapping(address => uint256) private _holderIdx; // 1-based

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
        _refreshHolder(to);
    }

    function setRewardsExcluded(address a, bool on) external {
        rewardsExcluded[a] = on;
        uint256 idx = _holderIdx[a];
        if (on && idx != 0) _removeHolder(a, idx);
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "bal");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        _refreshHolder(msg.sender);
        _refreshHolder(to);
        return true;
    }

    function holderCount() external view returns (uint256) {
        return _holders.length;
    }

    function holderAt(uint256 i) external view returns (address) {
        return _holders[i];
    }

    function _refreshHolder(address a) private {
        if (rewardsExcluded[a]) return;
        uint256 idx = _holderIdx[a];
        if (balanceOf[a] >= minShareBalance) {
            if (idx == 0) {
                _holders.push(a);
                _holderIdx[a] = _holders.length;
            }
        } else if (idx != 0) {
            _removeHolder(a, idx);
        }
    }

    function _removeHolder(address a, uint256 idx) private {
        address last = _holders[_holders.length - 1];
        _holders[idx - 1] = last;
        _holderIdx[last] = idx;
        _holders.pop();
        _holderIdx[a] = 0;
    }
}
