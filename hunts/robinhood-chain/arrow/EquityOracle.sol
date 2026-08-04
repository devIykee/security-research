// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Minimal "buy the builder a coffee" base. No external deps.
abstract contract Supportable {
    address public immutable builder;

    event Support(address indexed from, uint256 amount, string note);

    constructor() {
        builder = msg.sender;
    }

    function support(string calldata note) external payable {
        require(msg.value > 0, "empty");
        (bool ok, ) = builder.call{value: msg.value}("");
        require(ok, "fwd");
        emit Support(msg.sender, msg.value, note);
    }
}

/// @title EquityOracle
/// @notice Chainlink-style multi-reporter push feed with median aggregation,
///         staleness guard, equity market-hours awareness, and a Uniswap-style
///         cumulative-price accumulator for on-chain TWAP.
/// @dev Consumers read USD price (1e18) via getPrice(address) returns (uint256).
contract EquityOracle is Supportable {
    // --------------------------------------------------------------------- //
    //                               Ownership                               //
    // --------------------------------------------------------------------- //
    address public owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    // --------------------------------------------------------------------- //
    //                                Storage                                //
    // --------------------------------------------------------------------- //
    uint256 public constant OBS_RING = 32;

    struct Report {
        uint256 price; // 1e18 USD
        uint256 timestamp;
        bool exists;
    }

    struct Asset {
        bool registered;
        string symbol;
        uint256 maxAge; // seconds; a report older than this is stale
        // TWAP accumulator
        uint256 priceCumulative; // sum(price * dt) up to lastUpdate
        uint256 lastPrice; // last aggregated median
        uint256 lastUpdate; // timestamp of last aggregation
        uint256 obsCount; // total observations ever recorded
    }

    struct Observation {
        uint256 cumulativePrice;
        uint256 timestamp;
    }

    uint256 public quorum;

    mapping(address => bool) public isReporter;
    mapping(address => Asset) private _assets;
    // asset => reporter => report
    mapping(address => mapping(address => Report)) private _reports;
    // asset => list of reporters that have ever reported (for iteration)
    mapping(address => address[]) private _reporterList;
    // asset => reporter => already in list
    mapping(address => mapping(address => bool)) private _listed;
    // asset => ring buffer of observations
    mapping(address => Observation[OBS_RING]) private _obs;
    // asset => market open/halt flag
    mapping(address => bool) private _marketOpen;

    // --------------------------------------------------------------------- //
    //                                Events                                 //
    // --------------------------------------------------------------------- //
    event OwnerTransferred(address indexed previous, address indexed next);
    event ReporterSet(address indexed reporter, bool allowed);
    event AssetRegistered(address indexed asset, string symbol, uint256 maxAge);
    event QuorumSet(uint256 quorum);
    event MarketStatus(address indexed asset, bool open, address indexed by);
    event Reported(
        address indexed asset,
        address indexed reporter,
        uint256 price,
        uint256 timestamp
    );
    event PriceUpdated(
        address indexed asset,
        uint256 median,
        uint256 cumulativePrice,
        uint256 timestamp
    );

    constructor() {
        owner = msg.sender;
        emit OwnerTransferred(address(0), msg.sender);
    }

    // --------------------------------------------------------------------- //
    //                              Admin (owner)                            //
    // --------------------------------------------------------------------- //
    function transferOwnership(address next) external onlyOwner {
        require(next != address(0), "zero owner");
        emit OwnerTransferred(owner, next);
        owner = next;
    }

    function setReporter(address reporter, bool allowed) external onlyOwner {
        require(reporter != address(0), "zero reporter");
        isReporter[reporter] = allowed;
        emit ReporterSet(reporter, allowed);
    }

    function setAsset(
        address asset,
        string calldata symbol,
        uint256 maxAgeSeconds
    ) external onlyOwner {
        require(asset != address(0), "zero asset");
        require(maxAgeSeconds > 0, "zero maxAge");
        Asset storage a = _assets[asset];
        a.registered = true;
        a.symbol = symbol;
        a.maxAge = maxAgeSeconds;
        emit AssetRegistered(asset, symbol, maxAgeSeconds);
    }

    function setQuorum(uint256 q) external onlyOwner {
        require(q > 0, "zero quorum");
        quorum = q;
        emit QuorumSet(q);
    }

    // --------------------------------------------------------------------- //
    //                        Market hours / halt flag                       //
    // --------------------------------------------------------------------- //
    function setMarketOpen(address asset, bool open) external {
        require(msg.sender == owner || isReporter[msg.sender], "not authorized");
        require(_assets[asset].registered, "unknown asset");
        _marketOpen[asset] = open;
        emit MarketStatus(asset, open, msg.sender);
    }

    function marketOpen(address asset) external view returns (bool) {
        return _marketOpen[asset];
    }

    // --------------------------------------------------------------------- //
    //                             Reporter push                             //
    // --------------------------------------------------------------------- //
    function report(address asset, uint256 price1e18) external {
        require(isReporter[msg.sender], "not reporter");
        Asset storage a = _assets[asset];
        require(a.registered, "unknown asset");
        require(price1e18 > 0, "zero price");

        Report storage r = _reports[asset][msg.sender];
        r.price = price1e18;
        r.timestamp = block.timestamp;
        r.exists = true;

        if (!_listed[asset][msg.sender]) {
            _listed[asset][msg.sender] = true;
            _reporterList[asset].push(msg.sender);
        }

        emit Reported(asset, msg.sender, price1e18, block.timestamp);

        // Recompute aggregate; if enough fresh reports, advance the accumulator.
        (uint256 median, uint256 freshCount) = _computeMedian(asset);
        if (freshCount >= quorum && quorum > 0) {
            _accumulate(asset, a, median);
            emit PriceUpdated(asset, median, a.priceCumulative, block.timestamp);
        }
    }

    // --------------------------------------------------------------------- //
    //                              Consumer read                            //
    // --------------------------------------------------------------------- //
    /// @notice Median of fresh reporter prices, 1e18 USD.
    /// @dev Reverts if fewer than `quorum` fresh reports exist (staleness guard).
    function getPrice(address asset) external view returns (uint256) {
        require(_assets[asset].registered, "unknown asset");
        require(quorum > 0, "quorum unset");
        (uint256 median, uint256 freshCount) = _computeMedian(asset);
        require(freshCount >= quorum, "insufficient fresh reports");
        return median;
    }

    /// @notice Current cumulative price and the block timestamp, Uniswap-style.
    function observe(address asset)
        public
        view
        returns (uint256 cumulativePrice, uint256 blockTimestamp)
    {
        require(_assets[asset].registered, "unknown asset");
        Asset storage a = _assets[asset];
        cumulativePrice = a.priceCumulative;
        if (a.lastUpdate != 0 && a.lastPrice != 0) {
            cumulativePrice += a.lastPrice * (block.timestamp - a.lastUpdate);
        }
        blockTimestamp = block.timestamp;
    }

    /// @notice Time-weighted average price from `sinceTimestamp` to now, 1e18 USD.
    /// @dev Uses the earliest recorded observation with timestamp >= sinceTimestamp.
    function twap(address asset, uint256 sinceTimestamp)
        external
        view
        returns (uint256)
    {
        (uint256 nowCum, uint256 nowTs) = observe(asset);
        Asset storage a = _assets[asset];
        uint256 n = a.obsCount;
        if (n > OBS_RING) {
            n = OBS_RING;
        }
        require(n > 0, "no observations");

        bool found;
        uint256 anchorCum;
        uint256 anchorTs;
        for (uint256 i = 0; i < n; i++) {
            Observation storage o = _obs[asset][i];
            if (o.timestamp == 0) {
                continue;
            }
            if (o.timestamp >= sinceTimestamp) {
                if (!found || o.timestamp < anchorTs) {
                    found = true;
                    anchorTs = o.timestamp;
                    anchorCum = o.cumulativePrice;
                }
            }
        }
        require(found, "no observation in window");
        require(nowTs > anchorTs, "empty window");
        return (nowCum - anchorCum) / (nowTs - anchorTs);
    }

    // --------------------------------------------------------------------- //
    //                                 Views                                 //
    // --------------------------------------------------------------------- //
    function assetInfo(address asset)
        external
        view
        returns (
            bool registered,
            string memory symbol,
            uint256 maxAge,
            uint256 lastPrice,
            uint256 lastUpdate
        )
    {
        Asset storage a = _assets[asset];
        return (a.registered, a.symbol, a.maxAge, a.lastPrice, a.lastUpdate);
    }

    function reporterCount(address asset) external view returns (uint256) {
        return _reporterList[asset].length;
    }

    // --------------------------------------------------------------------- //
    //                               Internals                               //
    // --------------------------------------------------------------------- //
    /// @dev Collects fresh reporter prices, sorts them in memory, returns the median.
    ///      `freshCount == 0` means no usable (fresh) reports.
    function _computeMedian(address asset)
        internal
        view
        returns (uint256 median, uint256 freshCount)
    {
        Asset storage a = _assets[asset];
        address[] storage list = _reporterList[asset];
        uint256 len = list.length;
        if (len == 0) {
            return (0, 0);
        }

        uint256[] memory fresh = new uint256[](len);
        uint256 count;
        uint256 maxAge = a.maxAge;
        for (uint256 i = 0; i < len; i++) {
            Report storage r = _reports[asset][list[i]];
            if (!r.exists) {
                continue;
            }
            // staleness guard: only reports within maxAge count
            if (block.timestamp - r.timestamp <= maxAge) {
                fresh[count] = r.price;
                count++;
            }
        }
        if (count == 0) {
            return (0, 0);
        }

        // insertion sort of the fresh slice [0, count)
        for (uint256 i = 1; i < count; i++) {
            uint256 key = fresh[i];
            uint256 j = i;
            while (j > 0 && fresh[j - 1] > key) {
                fresh[j] = fresh[j - 1];
                j--;
            }
            fresh[j] = key;
        }

        if (count % 2 == 1) {
            median = fresh[count / 2];
        } else {
            // average of the two central elements (safe under 0.8 checked math)
            median = (fresh[count / 2 - 1] + fresh[count / 2]) / 2;
        }
        freshCount = count;
    }

    /// @dev Advances the cumulative-price accumulator and records an observation.
    function _accumulate(address asset, Asset storage a, uint256 median) internal {
        if (a.lastUpdate != 0 && a.lastPrice != 0) {
            a.priceCumulative += a.lastPrice * (block.timestamp - a.lastUpdate);
        }
        a.lastPrice = median;
        a.lastUpdate = block.timestamp;

        uint256 slot = a.obsCount % OBS_RING;
        _obs[asset][slot] = Observation({
            cumulativePrice: a.priceCumulative,
            timestamp: block.timestamp
        });
        a.obsCount++;
    }
}
