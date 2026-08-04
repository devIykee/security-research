// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Minimal builder-support base (self-contained, no imports).
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

/// @title EquityOracleV2
/// @notice Hardened multi-reporter median price oracle for tokenized equities.
/// @dev Fixes the single-key / quorum=1 arbitrary-price drain of the simple
///      oracle: price is ALWAYS the MEDIAN of independent, FRESH reporters,
///      never owner-settable, guarded by a per-asset deviation circuit breaker,
///      staleness enforcement, sanity bounds, a manipulation-resistant TWAP,
///      and an equity market-hours halt flag. getPrice(address)->uint256 (1e18)
///      is preserved so lending/CDP/perp consumers call it unchanged.
contract EquityOracleV2 is Supportable {
    // ------------------------------------------------------------- constants
    /// Cap on authorized reporters -> bounds the median loop (anti gas-DoS).
    uint256 public constant MAX_REPORTERS = 32;
    /// Hard global floor: a live asset can NEVER run with quorum < 2.
    /// (>= 3 is RECOMMENDED for real independence / fault tolerance.)
    uint256 public constant MIN_QUORUM = 2;
    /// TWAP observation ring size (bounds twap read gas).
    uint256 public constant OBS_SIZE = 64;
    /// Basis-points denominator.
    uint256 private constant BPS = 10_000;

    // ------------------------------------------------------------------ roles
    address public owner;

    // -------------------------------------------------------------- reporters
    address[] public reporters; // enumerable, capped at MAX_REPORTERS
    mapping(address => bool) public isReporter;

    // ---------------------------------------------------------------- structs
    struct AssetConfig {
        bool configured;
        bool requireMarketOpen; // if true, getPrice reverts while halted
        uint64 maxAge; // seconds; older report is not "fresh"
        uint32 minReporters; // quorum, enforced >= MIN_QUORUM
        uint32 maxDeviationBps; // circuit-breaker band vs last accepted median
        uint256 minPrice; // 0 = no floor
        uint256 maxPrice; // 0 = no ceiling
        string symbol;
    }

    struct AssetState {
        bool paused; // circuit breaker tripped
        bool marketOpen; // equity market-hours / halt flag
        bool twapInit; // whether the accumulator has a baseline
        uint64 lastAcceptedAt; // ts of last accepted median
        uint64 cumUpdatedAt; // ts accumulator last advanced
        uint256 lastAccepted; // last accepted median (1e18)
        uint256 cumPriceSeconds; // sum(price * secondsHeld) up to cumUpdatedAt
    }

    struct Report {
        uint256 price; // 1e18
        uint64 at; // timestamp
    }

    // Fixed-size TWAP observation ring (bounded storage & read cost).
    struct ObsRing {
        uint256 head; // next write slot
        uint256 count; // filled entries (<= OBS_SIZE)
        uint64[64] ts;
        uint256[64] cum; // cumulative price-seconds at ts
    }

    // asset => config / state
    mapping(address => AssetConfig) public assetConfig;
    mapping(address => AssetState) private _state;
    mapping(address => ObsRing) private _ring;
    // asset => reporter => latest report
    mapping(address => mapping(address => Report)) public reports;

    // ---------------------------------------------------------------- events
    event OwnerChanged(address indexed prevOwner, address indexed newOwner);
    event ReporterSet(address indexed reporter, bool enabled);
    event AssetSet(
        address indexed asset,
        string symbol,
        uint64 maxAge,
        uint32 minReporters,
        uint32 maxDeviationBps,
        uint256 minPrice,
        uint256 maxPrice
    );
    event Reported(address indexed asset, address indexed reporter, uint256 price, uint64 at);
    event MedianAccepted(address indexed asset, uint256 median, uint256 numFresh, uint64 at);
    event CircuitBreakerTripped(address indexed asset, uint256 lastAccepted, uint256 attempted, uint32 devBps);
    event Resumed(address indexed asset, uint256 reanchored);
    event MarketOpenSet(address indexed asset, bool open);

    // -------------------------------------------------------------- modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    constructor() Supportable() {
        owner = msg.sender;
        emit OwnerChanged(address(0), msg.sender);
    }

    // ============================================================ owner admin
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "zero owner");
        emit OwnerChanged(owner, newOwner);
        owner = newOwner;
    }

    /// @notice Add/remove an authorized reporter. Set is capped at MAX_REPORTERS.
    function setReporter(address reporter, bool enabled) external onlyOwner {
        require(reporter != address(0), "zero reporter");
        if (enabled) {
            if (!isReporter[reporter]) {
                require(reporters.length < MAX_REPORTERS, "too many reporters");
                isReporter[reporter] = true;
                reporters.push(reporter);
            }
        } else {
            if (isReporter[reporter]) {
                isReporter[reporter] = false;
                _removeReporter(reporter);
            }
        }
        emit ReporterSet(reporter, enabled);
    }

    function _removeReporter(address reporter) private {
        uint256 n = reporters.length;
        for (uint256 i = 0; i < n; i++) {
            if (reporters[i] == reporter) {
                reporters[i] = reporters[n - 1];
                reporters.pop();
                return;
            }
        }
    }

    /// @notice Configure asset policy. Owner sets POLICY ONLY, never the price.
    /// @dev minReporters is floored at MIN_QUORUM (>=2) so quorum=1 is impossible.
    function setAsset(
        address asset,
        string calldata symbol,
        uint64 maxAge,
        uint32 minReporters,
        uint32 maxDeviationBps,
        uint256 minPrice,
        uint256 maxPrice
    ) external onlyOwner {
        require(asset != address(0), "zero asset");
        require(maxAge > 0, "maxAge=0");
        require(minReporters >= MIN_QUORUM, "quorum<2");
        require(minReporters <= MAX_REPORTERS, "quorum>cap");
        require(maxDeviationBps > 0 && maxDeviationBps <= BPS, "bad devBps");
        if (minPrice != 0 && maxPrice != 0) {
            require(minPrice < maxPrice, "min>=max");
        }

        AssetConfig storage c = assetConfig[asset];
        bool firstConfig = !c.configured;
        c.configured = true;
        c.symbol = symbol;
        c.maxAge = maxAge;
        c.minReporters = minReporters;
        c.maxDeviationBps = maxDeviationBps;
        c.minPrice = minPrice;
        c.maxPrice = maxPrice;

        if (firstConfig) {
            _state[asset].marketOpen = true; // default equities open; owner can halt
        }

        emit AssetSet(asset, symbol, maxAge, minReporters, maxDeviationBps, minPrice, maxPrice);
    }

    /// @notice Toggle whether getPrice requires the market to be open.
    function setRequireMarketOpen(address asset, bool required) external onlyOwner {
        require(assetConfig[asset].configured, "no asset");
        assetConfig[asset].requireMarketOpen = required;
    }

    /// @notice Set the market-hours / halt flag. Owner or any reporter may call.
    function setMarketOpen(address asset, bool open) external {
        require(msg.sender == owner || isReporter[msg.sender], "not authorized");
        require(assetConfig[asset].configured, "no asset");
        _state[asset].marketOpen = open;
        emit MarketOpenSet(asset, open);
    }

    /// @notice Clear a tripped breaker and re-anchor to the current fresh median.
    /// @dev Re-anchoring records the owner-acknowledged jump as a new baseline so
    ///      the deviation band is measured from here forward.
    function resume(address asset) external onlyOwner {
        AssetState storage s = _state[asset];
        require(s.paused, "not paused");
        AssetConfig storage c = assetConfig[asset];
        (uint256 median, uint256 numFresh, uint64 freshest) = _freshMedian(asset);
        require(numFresh >= c.minReporters, "insufficient quorum");
        require(freshest != 0 && block.timestamp - freshest <= c.maxAge, "stale");
        _checkBounds(c, median);
        s.paused = false;
        _accept(asset, s, median, numFresh);
        emit Resumed(asset, median);
    }

    // ============================================================== reporting
    /// @notice A reporter submits its latest price (1e18 USD) for an asset.
    function report(address asset, uint256 price1e18) external {
        require(isReporter[msg.sender], "not reporter");
        AssetConfig storage c = assetConfig[asset];
        require(c.configured, "no asset");
        require(price1e18 > 0, "zero price");
        if (c.minPrice != 0) require(price1e18 >= c.minPrice, "below min");
        if (c.maxPrice != 0) require(price1e18 <= c.maxPrice, "above max");

        reports[asset][msg.sender] = Report({price: price1e18, at: uint64(block.timestamp)});
        emit Reported(asset, msg.sender, price1e18, uint64(block.timestamp));
    }

    // ================================================================ reading
    /// @notice PRESERVED SIGNATURE. Median of fresh reporters, enforcing quorum,
    ///         staleness, bounds, circuit breaker, and market hours. Advances the
    ///         accepted-median state + TWAP accumulator (hence non-view).
    function getPrice(address asset) external returns (uint256) {
        AssetConfig storage c = assetConfig[asset];
        require(c.configured, "no asset");
        AssetState storage s = _state[asset];
        require(!s.paused, "circuit breaker");
        if (c.requireMarketOpen) require(s.marketOpen, "market closed");

        (uint256 median, uint256 numFresh, uint64 freshest) = _freshMedian(asset);
        require(numFresh >= c.minReporters, "insufficient quorum");
        require(freshest != 0 && block.timestamp - freshest <= c.maxAge, "stale");
        _checkBounds(c, median);

        if (s.lastAcceptedAt != 0 && _deviatesTooMuch(s.lastAccepted, median, c.maxDeviationBps)) {
            s.paused = true;
            emit CircuitBreakerTripped(asset, s.lastAccepted, median, c.maxDeviationBps);
            revert("circuit breaker");
        }

        _accept(asset, s, median, numFresh);
        return median;
    }

    /// @notice Non-mutating monitoring preview that NEVER trips the breaker.
    /// @return price      current fresh median (0 if none)
    /// @return ok         satisfies quorum + freshness + bounds
    /// @return numFresh   count of fresh reporters
    /// @return wouldTrip  whether accepting it would trip the deviation breaker
    /// @return paused     current breaker state
    function peekPrice(address asset)
        external
        view
        returns (uint256 price, bool ok, uint256 numFresh, bool wouldTrip, bool paused)
    {
        AssetConfig storage c = assetConfig[asset];
        if (!c.configured) return (0, false, 0, false, false);
        AssetState storage s = _state[asset];
        paused = s.paused;

        uint64 freshest;
        (price, numFresh, freshest) = _freshMedian(asset);

        ok =
            numFresh >= c.minReporters &&
            freshest != 0 &&
            block.timestamp - freshest <= c.maxAge &&
            _withinBounds(c, price);

        if (ok && s.lastAcceptedAt != 0) {
            wouldTrip = _deviatesTooMuch(s.lastAccepted, price, c.maxDeviationBps);
        }
    }

    /// @notice Structured read for consumers / dashboards.
    /// @return price             last accepted median (1e18)
    /// @return lastUpdate        ts of last accepted median
    /// @return numFreshReporters current count of fresh reporters
    /// @return paused            circuit-breaker state
    function getPriceData(address asset)
        external
        view
        returns (uint256 price, uint256 lastUpdate, uint256 numFreshReporters, bool paused)
    {
        AssetState storage s = _state[asset];
        (, uint256 numFresh, ) = _freshMedian(asset);
        return (s.lastAccepted, s.lastAcceptedAt, numFresh, s.paused);
    }

    /// @notice Manipulation-resistant time-weighted average over the last
    ///         `window` seconds, from the accepted-median observation ring.
    /// @dev Reverts "insufficient history" if the ring does not cover `window`.
    function twapPrice(address asset, uint256 window) external view returns (uint256) {
        require(window > 0, "window=0");
        AssetState storage s = _state[asset];
        ObsRing storage r = _ring[asset];
        require(s.twapInit && r.count > 0, "no twap");

        uint256 nowTs = block.timestamp;
        require(nowTs >= window, "window>now");
        uint256 targetTs = nowTs - window;

        // Oldest observation must be at or before the target.
        uint256 oldestIdx = (r.head + OBS_SIZE - r.count) % OBS_SIZE;
        require(uint256(r.ts[oldestIdx]) <= targetTs, "insufficient history");

        // Cumulative price-seconds extended to now with the currently held price.
        uint256 cumNow = s.cumPriceSeconds + s.lastAccepted * (nowTs - uint256(s.cumUpdatedAt));
        uint256 cumTarget = _cumAt(r, s, targetTs, oldestIdx);
        return (cumNow - cumTarget) / window;
    }

    // ============================================================= internals
    /// @dev Cumulative price-seconds at an arbitrary `targetTs` within history,
    ///      via linear interpolation inside the constant-price segment holding it.
    function _cumAt(
        ObsRing storage r,
        AssetState storage s,
        uint256 targetTs,
        uint256 oldestIdx
    ) private view returns (uint256) {
        // Walk newest -> oldest to find the segment [lo.ts, hi.ts) containing target.
        for (uint256 k = 0; k < r.count; k++) {
            uint256 idx = (r.head + OBS_SIZE - 1 - k) % OBS_SIZE; // newest first
            uint256 loTs = uint256(r.ts[idx]);
            if (loTs <= targetTs) {
                if (idx == (r.head + OBS_SIZE - 1) % OBS_SIZE) {
                    // Newest obs is at/before target: extend with held price.
                    // Held price after the newest obs equals current lastAccepted.
                    return r.cum[idx] + s.lastAccepted * (targetTs - loTs);
                }
                uint256 hiIdx = (idx + 1) % OBS_SIZE;
                uint256 hiTs = uint256(r.ts[hiIdx]);
                // Constant price held over this segment.
                uint256 segPrice = (r.cum[hiIdx] - r.cum[idx]) / (hiTs - loTs);
                return r.cum[idx] + segPrice * (targetTs - loTs);
            }
        }
        // Should be unreachable given the oldest<=target guard.
        return r.cum[oldestIdx];
    }

    /// @dev Median of FRESH reporter prices for an asset.
    function _freshMedian(address asset)
        internal
        view
        returns (uint256 median, uint256 numFresh, uint64 freshest)
    {
        AssetConfig storage c = assetConfig[asset];
        uint256 n = reporters.length;
        uint256[] memory buf = new uint256[](n); // bounded: n <= MAX_REPORTERS
        uint256 cnt;
        uint256 nowTs = block.timestamp;

        for (uint256 i = 0; i < n; i++) {
            address rp = reporters[i];
            if (!isReporter[rp]) continue;
            Report storage rep = reports[asset][rp];
            if (rep.at == 0) continue;
            if (nowTs - rep.at > c.maxAge) continue; // not fresh
            buf[cnt] = rep.price;
            cnt++;
            if (rep.at > freshest) freshest = rep.at;
        }

        numFresh = cnt;
        if (cnt == 0) return (0, 0, 0);

        // Insertion sort (cnt <= 32).
        for (uint256 i = 1; i < cnt; i++) {
            uint256 key = buf[i];
            uint256 j = i;
            while (j > 0 && buf[j - 1] > key) {
                buf[j] = buf[j - 1];
                j--;
            }
            buf[j] = key;
        }

        if (cnt & 1 == 1) {
            median = buf[cnt / 2];
        } else {
            median = (buf[cnt / 2 - 1] + buf[cnt / 2]) / 2;
        }
    }

    /// @dev Accept a median: advance TWAP accumulator, push observation, store.
    function _accept(
        address asset,
        AssetState storage s,
        uint256 median,
        uint256 numFresh
    ) internal {
        uint64 nowTs = uint64(block.timestamp);

        if (!s.twapInit) {
            s.cumPriceSeconds = 0;
            s.cumUpdatedAt = nowTs;
            s.twapInit = true;
        } else {
            // Bake the previously-held price into the accumulator.
            s.cumPriceSeconds += s.lastAccepted * (uint256(nowTs) - uint256(s.cumUpdatedAt));
            s.cumUpdatedAt = nowTs;
        }

        s.lastAccepted = median;
        s.lastAcceptedAt = nowTs;
        _pushObs(asset, nowTs, s.cumPriceSeconds);
        emit MedianAccepted(asset, median, numFresh, nowTs);
    }

    /// @dev Append an observation to the ring (overwrites oldest when full).
    function _pushObs(address asset, uint64 ts, uint256 cum) private {
        ObsRing storage r = _ring[asset];
        uint256 h = r.head;
        // Coalesce same-timestamp writes to keep segments strictly increasing.
        if (r.count > 0) {
            uint256 lastIdx = (h + OBS_SIZE - 1) % OBS_SIZE;
            if (r.ts[lastIdx] == ts) {
                r.cum[lastIdx] = cum;
                return;
            }
        }
        r.ts[h] = ts;
        r.cum[h] = cum;
        r.head = (h + 1) % OBS_SIZE;
        if (r.count < OBS_SIZE) r.count += 1;
    }

    function _deviatesTooMuch(uint256 last, uint256 next, uint32 devBps) internal pure returns (bool) {
        if (last == 0) return false;
        uint256 diff = next > last ? next - last : last - next;
        return diff * BPS > uint256(devBps) * last;
    }

    function _withinBounds(AssetConfig storage c, uint256 price) internal view returns (bool) {
        if (price == 0) return false;
        if (c.minPrice != 0 && price < c.minPrice) return false;
        if (c.maxPrice != 0 && price > c.maxPrice) return false;
        return true;
    }

    function _checkBounds(AssetConfig storage c, uint256 price) internal view {
        require(_withinBounds(c, price), "out of bounds");
    }

    // ---------------------------------------------------------------- getters
    function reporterCount() external view returns (uint256) {
        return reporters.length;
    }

    function assetState(address asset)
        external
        view
        returns (
            uint256 lastAccepted,
            uint64 lastAcceptedAt,
            bool paused,
            bool marketOpen,
            uint256 cumPriceSeconds,
            uint64 cumUpdatedAt
        )
    {
        AssetState storage s = _state[asset];
        return (s.lastAccepted, s.lastAcceptedAt, s.paused, s.marketOpen, s.cumPriceSeconds, s.cumUpdatedAt);
    }
}
