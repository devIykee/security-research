// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title BettorLib
/// @notice Library for managing bettors using Fenwick tree (Binary Indexed Tree) for O(log N) operations
/// @dev Uses append-only bettors array with Fenwick tree for prefix sums
library BettorLib {
    // ============ Errors ============
    
    error FenwickEmpty();
    error IndexOutOfBounds(uint256 index, uint256 length);
    error NoBettors();
    error TargetOutOfBounds(uint256 target, uint256 total);
    error BetAmountZero();
    error TooManyBettors(uint256 index);
    error FenwickNotInitialized();
    error IndexOutOfBoundsForBettors(uint256 idx, uint256 bettorsLength);

    // ============ Fenwick Tree Core Functions ============

    /// @notice Get the least significant bit (LSB) of a number
    /// @dev Returns x & -x using unsigned-safe form: x & (~x + 1)
    /// @param x The number to get the LSB of
    /// @return The LSB value
    function _lsb(uint256 x) private pure returns (uint256) {
        return x & (~x + 1);
    }

    /// @notice Update Fenwick tree at index with delta value
    /// @dev Complexity: O(log N) - updates all ancestors in the tree
    /// @param fenwick Storage array representing the Fenwick tree (1-indexed internally, 0-indexed in array)
    /// @param index 0-based index in the bettors array (will be converted to 1-based for Fenwick)
    /// @param numBettors Actual number of bettors (to bounds-check against)
    /// @param delta Change in value (must be positive)
    function fenwickUpdate(uint256[] storage fenwick, uint256 index, uint256 numBettors, uint256 delta) internal {
        uint256 n = fenwick.length;
        if (n <= 1) revert FenwickEmpty();
        if (n < numBettors + 1) revert FenwickNotInitialized();
        if (index >= numBettors) revert IndexOutOfBoundsForBettors(index, numBettors);
        
        // Fenwick tree is 1-indexed, but we store it in a 0-indexed array
        // So fenwick[0] is unused, fenwick[1] corresponds to index 0, etc.
        uint256 i = index + 1;
        if (i >= n) revert IndexOutOfBounds(i, n);
        
        // Update all ancestors: i, i+lsb(i), i+lsb(i)+lsb(i+lsb(i)), ...
        // Loop naturally ends when i >= n (no need for explicit bounds check)
        while (i < n) {
            fenwick[i] += delta;
            i += _lsb(i);
        }
    }

    /// @notice Get prefix sum up to and including index
    /// @dev Complexity: O(log N)
    /// @param fenwick Storage array representing the Fenwick tree
    /// @param index 0-based index in the bettors array
    /// @param numBettors Actual number of bettors (to bounds-check against)
    /// @return sum Prefix sum from index 0 to index (inclusive)
    function fenwickPrefixSum(uint256[] storage fenwick, uint256 index, uint256 numBettors) internal view returns (uint256 sum) {
        if (fenwick.length <= 1) revert FenwickEmpty();
        if (fenwick.length < numBettors + 1) revert FenwickNotInitialized();
        if (index >= numBettors) revert IndexOutOfBounds(index, numBettors);
        
        // Convert 0-based index to 1-based for Fenwick tree
        uint256 i = index + 1;
        sum = 0;
        
        // Traverse up the tree: add current node, then move to parent
        // Standard Fenwick tree prefix sum: sum nodes along the path to root
        while (i > 0) {
            sum += fenwick[i];
            i -= _lsb(i);
        }
    }

    /// @notice Find the smallest index where prefix sum > target
    /// @dev Complexity: O(log² N) - binary search with prefixSum calls
    ///      Finds smallest idx such that prefixSum(idx) > target (for target in [0, total-1])
    ///      Returns 0-based index of the bettor whose range contains target
    /// @param fenwick Storage array representing the Fenwick tree
    /// @param numBettors Actual number of bettors (length of bettors array)
    /// @param target Target prefix sum value (should be in [0, total-1])
    /// @return idx0 0-based index of the bettor whose range contains target
    function fenwickFindByPrefix(
        uint256[] storage fenwick,
        uint256 numBettors,
        uint256 target
    ) internal view returns (uint256 idx0) {
        if (fenwick.length <= 1) revert FenwickEmpty();
        if (fenwick.length < numBettors + 1) revert FenwickNotInitialized();
        if (numBettors == 0) revert NoBettors();
        
        // Binary search for the first index where prefixSum > target
        // We want the smallest index where prefixSum(index) > target
        // For lottery: target in [0, total-1], we want the bettor whose range contains target
        // Ranges: bettor[0]: [0, prefixSum(0)), bettor[1]: [prefixSum(0), prefixSum(1)), etc.
        uint256 left = 0;
        uint256 right = numBettors;
        
        while (left < right) {
            uint256 mid = left + (right - left) / 2; // Avoid overflow
            uint256 prefix = fenwickPrefixSum(fenwick, mid, numBettors);
            
            // If prefix <= target, the answer is in (mid, right]
            // If prefix > target, the answer is in [left, mid]
            if (prefix <= target) {
                left = mid + 1;
            } else {
                right = mid;
            }
        }
        
        // After loop: left == right, and it's the smallest index where prefixSum > target
        // Caller must ensure target < total, so left should always be < numBettors
        // This check is defensive - if it triggers, there's a bug in the caller
        if (left >= numBettors) revert IndexOutOfBoundsForBettors(left, numBettors);
        return left;
    }

    // ============ Public API ============

    /// @notice Ensure Fenwick tree is properly sized and rebuilt if it grew
    /// @param fenwick Storage array representing the Fenwick tree
    /// @param bet Array of bet amounts per index (size N, aligned with bettors array)
    /// @param numBettors Current number of bettors (length of bettors array)
    /// @param desiredCapacityPlusOne Desired capacity including fenwick[0] unused slot
    function ensureFenwickSizeAndRebuild(
        uint256[] storage fenwick,
        uint256[] storage bet,
        uint256 numBettors,
        uint256 desiredCapacityPlusOne
    ) internal {
        if (fenwick.length == 0) {
            fenwick.push(0); // Initialize index 0 (unused)
        }
        
        uint256 oldLen = fenwick.length;
        uint256 requiredSize = numBettors + 1;
        uint256 newLen = desiredCapacityPlusOne > requiredSize ? desiredCapacityPlusOne : requiredSize;
        
        // If tree is already large enough, no resize needed
        if (newLen <= oldLen) {
            return;
        }
        
        // Grow tree to newLen (for future capacity)
        while (fenwick.length < newLen) {
            fenwick.push(0);
        }
        
        // Step 1: Set base values from bet array for existing bettors, zero for future nodes
        // fenwick[i] (1-indexed) corresponds to bet[i-1] (0-indexed) for i <= numBettors
        for (uint256 i = 1; i < newLen; i++) {
            if (i <= numBettors) {
                fenwick[i] = bet[i - 1]; // Set from bet array
            } else {
                fenwick[i] = 0; // Future nodes start at zero
            }
        }
        
        // Step 2: Build Fenwick tree structure in O(n)
        // For each node i, add its value to its parent j = i + lsb(i)
        // Must iterate to newLen to properly initialize all nodes
        for (uint256 i = 1; i < newLen; i++) {
            uint256 j = i + _lsb(i);
            if (j < newLen) {
                fenwick[j] += fenwick[i];
            }
        }
    }

    /// @notice Add or update a bettor's bet using Fenwick tree
    /// @dev Complexity: O(log N) for updates, O(N) if tree needs to be rebuilt
    /// @param bettors Append-only array of bettor addresses
    /// @param fenwick Fenwick tree for prefix sums (size N+1, index 0 unused)
    /// @param bet Array of bet amounts per index (size N)
    /// @param idxOf Mapping from bettor address to index+1 (0 means not found, stored as uint32)
    /// @param bettor Address of the bettor
    /// @param betAmount The bet amount to add (must be > 0)
    /// @return index The index of the bettor (0-based)
    function addOrUpdateBet(
        address[] storage bettors,
        uint256[] storage fenwick,
        uint256[] storage bet,
        mapping(address => uint32) storage idxOf,
        address bettor,
        uint256 betAmount
    ) internal returns (uint256 index) {
        if (betAmount == 0) revert BetAmountZero();
        
        uint32 idxPlusOne = idxOf[bettor];
        
        if (idxPlusOne == 0) {
            // New bettor: append to array
            index = bettors.length;
            if (index >= type(uint32).max) revert TooManyBettors(index); // Ensure idxPlusOne fits in uint32
            
            // Calculate desired capacity: use next power of 2 for efficient growth
            // Fenwick tree only needs capacity for indices 1..capacity-1, no extra slack needed
            // Using nextPow2 keeps growth infrequent without permanently maintaining oversized array
            uint256 requiredSize = index + 2; // +1 for 1-indexing, +1 for new bettor
            
            // Find next power of 2 >= requiredSize
            uint256 safeSize = 1;
            while (safeSize < requiredSize && safeSize > 0) {
                safeSize <<= 1;
            }
            if (safeSize == 0 || safeSize < requiredSize) {
                safeSize = requiredSize; // Fallback if overflow or edge case
            }
            
            // Ensure tree is sized and rebuilt if it grew
            // Pass current numBettors (before adding new one) and desired capacity
            ensureFenwickSizeAndRebuild(fenwick, bet, index, safeSize);
            
            // Now add the new bettor
            bettors.push(bettor);
            bet.push(betAmount);
            idxOf[bettor] = uint32(index + 1); // Store index+1 (1-indexed)
            
            // Update Fenwick tree with new bet
            // This will update all ancestors in the tree
            fenwickUpdate(fenwick, index, bettors.length, betAmount);
        } else {
            // Existing bettor: add to existing bet amount
            index = uint256(idxPlusOne) - 1; // Convert back to 0-indexed
            
            uint256 oldBet = bet[index];
            uint256 newBet = oldBet + betAmount;
            uint256 delta = betAmount; // Always positive when adding
            
            // Update bet array
            bet[index] = newBet;
            
            // Update Fenwick tree with delta
            fenwickUpdate(fenwick, index, bettors.length, delta);
        }
    }

    /// @notice Get total sum of all bets
    /// @dev Returns the prefix sum of the last bettor (which equals total)
    /// @param fenwick Fenwick tree for prefix sums
    /// @param numBettors Actual number of bettors (length of bettors array)
    /// @return totalSum Total sum of all bets
    function total(uint256[] storage fenwick, uint256 numBettors) internal view returns (uint256 totalSum) {
        if (numBettors == 0) return 0;
        if (fenwick.length <= 1) revert FenwickEmpty();
        if (fenwick.length < numBettors + 1) revert FenwickNotInitialized();
        uint256 lastBettorIndex = numBettors - 1;
        return fenwickPrefixSum(fenwick, lastBettorIndex, numBettors);
    }

    /// @notice Pick winner using Fenwick tree (requires target < total)
    /// @dev Complexity: O(log N) - uses Fenwick tree bit-walk
    ///      target should be in [0, total-1] where total is the sum of all bets
    /// @param bettors Append-only array of bettor addresses
    /// @param fenwick Fenwick tree for prefix sums
    /// @param target Target value in [0, total-1] to find winner for
    /// @return winner The address of the winning bettor
    function pickWinner(
        address[] storage bettors,
        uint256[] storage fenwick,
        uint256 target
    ) internal view returns (address winner) {
        if (bettors.length == 0) revert NoBettors();
        if (fenwick.length <= 1) revert FenwickNotInitialized();
        if (fenwick.length < bettors.length + 1) revert FenwickNotInitialized();
        
        // Require target < total to avoid biased outcomes
        uint256 t = total(fenwick, bettors.length);
        if (target >= t) revert TargetOutOfBounds(target, t);
        
        // Find the 0-based index where prefix sum > target
        uint256 idx = fenwickFindByPrefix(fenwick, bettors.length, target);
        
        if (idx >= bettors.length) revert IndexOutOfBoundsForBettors(idx, bettors.length);
        return bettors[idx];
    }
}
