// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @dev Faithful extraction of USDGBuyerDistributor snapshot + distribute logic
/// (the load-bearing vulnerable surface). Source: verified USDGBuyerDistributor
/// on Robinhood Chain @ 0x2459DedB3012d1E929EdD17DF26620120bDF11bf

interface IIndexToken {
    function holderCount() external view returns (uint256);
    function holderAt(uint256 i) external view returns (address);
    function balanceOf(address a) external view returns (uint256);
}

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
}

/// Simplified stock token for the pot.
contract MockStock {
    string public symbol;
    mapping(address => uint256) public balanceOf;
    uint256 public totalSupply;

    constructor(string memory sym) {
        symbol = sym;
    }

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "bal");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

/// Snapshot + distribute path matching production USDGBuyerDistributor.
contract VulnerableDistributor {
    IIndexToken public immutable indexToken;

    address[] public stocks;

    address[] private _holders;
    uint256[] private _bals;
    address[] private _stock;
    uint256[] private _pot;
    uint256 public eligible;
    uint256 public cursor;
    bool public cycleActive;
    uint256 public nextDistribution;
    uint256 public snapCount;
    bool public snapPending;
    uint256 public interval = 900;

    error TooEarly();
    error CycleInProgress();
    error NoCycle();
    error SnapshotIncomplete();
    error NoDistributionPot();
    error NoEligibleHolders();

    constructor(IIndexToken indexToken_) {
        indexToken = indexToken_;
    }

    function addStock(address token) external {
        stocks.push(token);
    }

    function stocksLength() external view returns (uint256) {
        return stocks.length;
    }

    function stockTokenAt(uint256 i) external view returns (address) {
        return stocks[i];
    }

    function canStart() external view returns (bool) {
        return !cycleActive && block.timestamp >= nextDistribution;
    }

    function snapshotRemaining() external view returns (uint256) {
        uint256 n = indexToken.holderCount();
        uint256 done = snapPending ? snapCount : 0;
        return n > done ? n - done : 0;
    }

    /// @notice IDENTICAL vulnerable logic: live balanceOf at snapshot time, no checkpoint.
    function snapshotHolders(uint256 count) external {
        if (cycleActive) revert CycleInProgress();
        if (block.timestamp < nextDistribution) revert TooEarly();
        if (!snapPending) {
            if (!_hasPot()) revert NoDistributionPot();
            delete _holders;
            delete _bals;
            delete _stock;
            delete _pot;
            eligible = 0;
            snapCount = 0;
            snapPending = true;
        }
        uint256 n = indexToken.holderCount();
        uint256 end = snapCount + count;
        if (end > n) end = n;
        uint256 elig = eligible;
        for (uint256 i = snapCount; i < end; ++i) {
            address h = indexToken.holderAt(i);
            // VULN: live balance — flash-loanable
            uint256 b = indexToken.balanceOf(h);
            _holders.push(h);
            _bals.push(b);
            elig += b;
        }
        eligible = elig;
        snapCount = end;
    }

    function startCycle() external {
        if (cycleActive) revert CycleInProgress();
        if (block.timestamp < nextDistribution) revert TooEarly();

        if (snapPending) {
            if (snapCount < indexToken.holderCount()) revert SnapshotIncomplete();
            snapPending = false;
        } else {
            delete _holders;
            delete _bals;
            delete _stock;
            delete _pot;
            uint256 n = indexToken.holderCount();
            uint256 elig;
            for (uint256 i; i < n; ++i) {
                address h = indexToken.holderAt(i);
                uint256 b = indexToken.balanceOf(h);
                _holders.push(h);
                _bals.push(b);
                elig += b;
            }
            eligible = elig;
        }

        if (eligible == 0) revert NoEligibleHolders();
        uint256 m = stocks.length;
        uint256 totalPot;
        for (uint256 k; k < m; ++k) {
            address tok = stocks[k];
            uint256 p = IERC20(tok).balanceOf(address(this));
            _stock.push(tok);
            _pot.push(p);
            totalPot += p;
        }
        if (totalPot == 0) revert NoDistributionPot();

        nextDistribution = block.timestamp + interval;
        cursor = 0;
        cycleActive = true;
    }

    function distributeBatch(uint256 count) external {
        if (!cycleActive) revert NoCycle();
        uint256 n = _holders.length;
        uint256 end = cursor + count;
        if (end > n) end = n;

        uint256 elig = eligible;
        uint256 m = _stock.length;
        for (uint256 i = cursor; i < end; ++i) {
            uint256 b = _bals[i];
            if (b == 0) continue;
            address h = _holders[i];
            for (uint256 k; k < m; ++k) {
                uint256 amt = (_pot[k] * b) / elig;
                if (amt != 0) {
                    // Production uses non-reverting _trySend; here plain transfer is fine.
                    IERC20(_stock[k]).transfer(h, amt);
                }
            }
        }
        cursor = end;
        if (end == n) {
            cycleActive = false;
        }
    }

    function _hasPot() private view returns (bool) {
        uint256 m = stocks.length;
        for (uint256 k; k < m; ++k) {
            if (IERC20(stocks[k]).balanceOf(address(this)) != 0) return true;
        }
        return false;
    }

    // Test helper: read frozen bal for a snapshotted holder
    function frozenBal(uint256 i) external view returns (uint256) {
        return _bals[i];
    }

    function frozenHolder(uint256 i) external view returns (address) {
        return _holders[i];
    }

    function frozenHolderCount() external view returns (uint256) {
        return _holders.length;
    }
}
