// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

/// @title VoteCheckpointLib
/// @notice Bias/slope checkpoint history for linearly-decaying voting power (ve-style),
///         supporting exact historical reads for governance (getPastVotes / getPastTotalSupply).
/// @dev Each aggregate (one per account, plus one global) is a piecewise-linear function of
///      time: `bias` decreases by `slope` per second, and scheduled slope reductions fire when
///      locks reach their bucket-aligned governance end. Because ends are rounded DOWN to a
///      BUCKET boundary, a walk between two times only needs to visit bucket boundaries, and
///      because every lock's end lies within MAX_LOCK of the point that recorded it, walks are
///      bounded to MAX_LOCK / BUCKET (+1) iterations regardless of dormancy.
///
///      Historical consistency: scheduled changes are only ever written at bucket keys strictly
///      in the future, so any key at or before `block.timestamp` is frozen forever — reads that
///      walk past buckets always see the schedule exactly as it stood when those buckets were
///      still upcoming.
library VoteCheckpointLib {
    /// @dev Granularity of scheduled decay stops. Lock ends are rounded down to this.
    uint256 internal constant BUCKET = 1 days;
    /// @dev Must be >= the ve contract's max lock duration (SlvrVoteEscrow.TMAX = 120 days).
    ///      Every scheduled change after a point at time T falls in (T, T + MAX_LOCK], so a
    ///      walk past T + MAX_LOCK + BUCKET extrapolates linearly (slope has decayed to 0).
    uint256 internal constant MAX_LOCK = 120 days;

    struct Point {
        int128 bias; // aggregate voting power at `ts`
        int128 slope; // decay per second at `ts`
        uint64 ts;
    }

    struct History {
        Point[] points;
        mapping(uint256 => int256) slopeChanges; // bucket-aligned ts => net slope delta applied at that ts
    }

    /// @notice Record a contribution change (old removed, new added) at block.timestamp.
    /// @param oldBias/oldSlope/oldEnd The removed contribution (bias measured at now; end is the
    ///        bucket-aligned governance end, 0 or past for none/permanent).
    /// @param newBias/newSlope/newEnd The added contribution, same convention.
    function checkpoint(
        History storage self,
        int256 oldBias,
        int256 oldSlope,
        uint256 oldEnd,
        int256 newBias,
        int256 newSlope,
        uint256 newEnd
    ) internal {
        Point memory p;
        uint256 nPoints = self.points.length;
        if (nPoints > 0) {
            p = _advance(self.points[nPoints - 1], self.slopeChanges, block.timestamp);
        } else {
            // Fresh history: nothing can be scheduled yet, so skip the bucket walk entirely
            // (walking from ts 0 would read ~MAX_LOCK/BUCKET cold storage slots for nothing).
            p.ts = SafeCast.toUint64(block.timestamp);
        }

        int256 bias = int256(p.bias) + (newBias - oldBias);
        int256 slope = int256(p.slope) + (newSlope - oldSlope);
        // Aggregates cannot go negative when bookkeeping is consistent; clamp defensively so a
        // rounding edge can never brick lock mutations via an int128 cast revert.
        if (bias < 0) bias = 0;
        if (slope < 0) slope = 0;
        p.bias = SafeCast.toInt128(bias);
        p.slope = SafeCast.toInt128(slope);

        uint256 len = self.points.length;
        if (len > 0 && self.points[len - 1].ts == block.timestamp) {
            self.points[len - 1] = p;
        } else {
            self.points.push(p);
        }

        // Un-schedule the old contribution's decay stop; schedule the new one. Only future
        // buckets are ever touched, which is what freezes history (see @dev above).
        if (oldEnd > block.timestamp) self.slopeChanges[oldEnd] += oldSlope;
        if (newEnd > block.timestamp) self.slopeChanges[newEnd] -= newSlope;
    }

    /// @notice Aggregate voting power at `timepoint`. Caller must ensure timepoint <= block.timestamp.
    function valueAt(History storage self, uint256 timepoint) internal view returns (uint256) {
        uint256 n = _countAtOrBefore(self.points, timepoint);
        if (n == 0) return 0;
        Point memory p = _advance(self.points[n - 1], self.slopeChanges, timepoint);
        return uint256(int256(p.bias));
    }

    /// @dev Evolve `p` forward to `target`, applying scheduled slope changes at bucket
    ///      boundaries. Iteration is capped at the horizon past which no schedule can exist.
    function _advance(Point memory p, mapping(uint256 => int256) storage slopeChanges, uint256 target)
        private
        view
        returns (Point memory)
    {
        if (target <= p.ts) return p; // same-timestamp update; ts never moves backwards
        int256 bias = p.bias;
        int256 slope = p.slope;
        uint256 t = p.ts;
        uint256 horizon = t + MAX_LOCK + BUCKET;
        uint256 b = ((t / BUCKET) + 1) * BUCKET;
        while (b <= target && b <= horizon) {
            bias -= slope * int256(b - t);
            if (bias < 0) bias = 0;
            slope += slopeChanges[b];
            if (slope < 0) slope = 0;
            t = b;
            unchecked {
                b += BUCKET;
            }
        }
        bias -= slope * int256(target - t);
        if (bias < 0) bias = 0;
        return Point({bias: SafeCast.toInt128(bias), slope: SafeCast.toInt128(slope), ts: SafeCast.toUint64(target)});
    }

    /// @dev Number of points with ts <= timepoint (binary search; points are ts-ascending).
    function _countAtOrBefore(Point[] storage points, uint256 timepoint) private view returns (uint256) {
        uint256 lo = 0;
        uint256 hi = points.length;
        while (lo < hi) {
            uint256 mid = (lo + hi) / 2;
            if (points[mid].ts <= timepoint) {
                lo = mid + 1;
            } else {
                hi = mid;
            }
        }
        return lo;
    }
}
