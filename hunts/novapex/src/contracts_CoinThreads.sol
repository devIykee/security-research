// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @dev Minimal view of PumpFactory used to check a token actually exists,
///      so threads can't be spammed onto arbitrary addresses. Field order must
///      match PumpFactory.Curve exactly (it's the auto-generated getter).
interface IPumpFactoryCurves {
    function curves(address token)
        external
        view
        returns (
            bool exists,
            bool graduated,
            bool migrated,
            address creator,
            uint256 ethReserve,
            uint256 tokensSold
        );
}

/// @title CoinThreads
/// @notice On-chain comment threads for launchpad coins, pump.fun style.
///         Deliberately simple: append-only per-token comment arrays with a
///         paginated reader. No backend, no moderation layer; the frontend can
///         filter client-side if needed.
contract CoinThreads {
    struct Comment {
        address author;
        uint64 timestamp;
        string text;
    }

    /// @notice The launchpad whose tokens can be commented on.
    IPumpFactoryCurves public immutable factory;

    /// @notice Max comment length in bytes (~one tweet).
    uint256 public constant MAX_LENGTH = 280;

    mapping(address => Comment[]) private _threads;

    event CommentPosted(
        address indexed token,
        address indexed author,
        uint256 index,
        string text
    );

    error UnknownToken();
    error EmptyComment();
    error CommentTooLong();

    constructor(address factory_) {
        factory = IPumpFactoryCurves(factory_);
    }

    /// @notice Post a comment on `token`'s thread.
    function post(address token, string calldata text) external {
        (bool exists, , , , , ) = factory.curves(token);
        if (!exists) revert UnknownToken();
        uint256 len = bytes(text).length;
        if (len == 0) revert EmptyComment();
        if (len > MAX_LENGTH) revert CommentTooLong();

        _threads[token].push(
            Comment({author: msg.sender, timestamp: uint64(block.timestamp), text: text})
        );
        emit CommentPosted(token, msg.sender, _threads[token].length - 1, text);
    }

    /// @notice Number of comments on `token`'s thread.
    function count(address token) external view returns (uint256) {
        return _threads[token].length;
    }

    /// @notice Paginated read: comments [start, start+limit) in post order.
    function getComments(address token, uint256 start, uint256 limit)
        external
        view
        returns (Comment[] memory page)
    {
        Comment[] storage all = _threads[token];
        uint256 len = all.length;
        if (start >= len) return new Comment[](0);
        uint256 end = start + limit;
        if (end > len) end = len;
        page = new Comment[](end - start);
        for (uint256 i = start; i < end; i++) {
            page[i - start] = all[i];
        }
    }
}
