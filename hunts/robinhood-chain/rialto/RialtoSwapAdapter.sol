// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {ISwapAdapter} from "../interfaces/ISwapAdapter.sol";

/// @notice Rialto's Router Registry: `ownerOf(featureId)` returns the active
///         router (feature 2 = taker-submitted swaps). Published on
///         Robinhood Chain at 0x71a120CbBf3Ce7cD910a3c50fF77aFc62735687E.
interface IRialtoRouterRegistry {
    function ownerOf(uint256 featureId) external view returns (address);
}

/// @title RialtoSwapAdapter
/// @notice Production adapter executing venue-quoted swaps (Rialto propAMM
///         router in allowance-settlement mode; the same shape serves 0x RFQ /
///         1inch calldata). Security model:
///         - `routeData` = abi.encode(target, callData); `target` MUST be on
///           the owner-curated allowlist (Rialto's registry-published router).
///           Arbitrary pools/targets are rejected — never silently routed.
///         - the settlement target gets an exact, single-use allowance;
///         - output is measured by balance delta, never trusted from returndata;
///         - receiver and minimum output are enforced here, and the calling
///           vault re-verifies its own balance deltas on top.
contract RialtoSwapAdapter is ISwapAdapter, Ownable2Step, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 public constant TAKER_SWAP_FEATURE_ID = 2;

    IRialtoRouterRegistry public immutable registry;
    /// @notice Allowlisted settlement targets (Rialto routers, RFQ settlers).
    mapping(address => bool) public allowedTargets;
    /// @notice Allowlisted tokens (canonical Stock Tokens + USDG).
    mapping(address => bool) public allowedTokens;

    event TargetAllowed(address indexed target, bool allowed);
    event TokenAllowed(address indexed token, bool allowed);
    event Swapped(
        address indexed tokenIn,
        address indexed tokenOut,
        address indexed target,
        uint256 amountIn,
        uint256 amountOut,
        address receiver
    );

    error DeadlineExpired();
    error TargetNotAllowed(address target);
    error TokenNotAllowed(address token);
    error EmptyRoute();
    error SettlementFailed(bytes reason);
    error InsufficientOutput(uint256 got, uint256 want);
    error ZeroAddress();

    constructor(address owner_, address registry_) Ownable(owner_) {
        registry = IRialtoRouterRegistry(registry_);
    }

    // ── Curation ─────────────────────────────────────────────────────────────

    function setTargetAllowed(address target, bool allowed) external onlyOwner {
        if (target == address(0)) revert ZeroAddress();
        allowedTargets[target] = allowed;
        emit TargetAllowed(target, allowed);
    }

    /// @notice Allowlist whatever router the Rialto registry currently
    ///         publishes for taker-submitted swaps. Anyone may sync; only the
    ///         registry (set at construction) is trusted for discovery.
    function syncRialtoRouter() external returns (address router) {
        router = registry.ownerOf(TAKER_SWAP_FEATURE_ID);
        if (router == address(0)) revert ZeroAddress();
        allowedTargets[router] = true;
        emit TargetAllowed(router, true);
    }

    function setTokenAllowed(address token, bool allowed) external onlyOwner {
        if (token == address(0)) revert ZeroAddress();
        allowedTokens[token] = allowed;
        emit TokenAllowed(token, allowed);
    }

    // ── ISwapAdapter ─────────────────────────────────────────────────────────

    /// @inheritdoc ISwapAdapter
    function supportsPair(address tokenIn, address tokenOut) public view returns (bool) {
        return allowedTokens[tokenIn] && allowedTokens[tokenOut] && tokenIn != tokenOut;
    }

    /// @inheritdoc ISwapAdapter
    function swapExactIn(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        address receiver,
        uint256 deadline,
        bytes calldata routeData
    ) external nonReentrant returns (uint256 amountOut) {
        if (block.timestamp > deadline) revert DeadlineExpired();
        if (receiver == address(0)) revert ZeroAddress();
        if (!allowedTokens[tokenIn]) revert TokenNotAllowed(tokenIn);
        if (!allowedTokens[tokenOut]) revert TokenNotAllowed(tokenOut);
        if (routeData.length == 0) revert EmptyRoute();

        (address target, bytes memory callData) = abi.decode(routeData, (address, bytes));
        if (!allowedTargets[target]) revert TargetNotAllowed(target);

        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);
        IERC20(tokenIn).forceApprove(target, amountIn);

        uint256 balBefore = IERC20(tokenOut).balanceOf(address(this));
        (bool ok, bytes memory ret) = target.call(callData);
        if (!ok) revert SettlementFailed(ret);
        IERC20(tokenIn).forceApprove(target, 0);

        amountOut = IERC20(tokenOut).balanceOf(address(this)) - balBefore;
        if (amountOut < minAmountOut) revert InsufficientOutput(amountOut, minAmountOut);
        IERC20(tokenOut).safeTransfer(receiver, amountOut);

        // Return any unspent input (partial-fill safety) to the caller.
        uint256 residual = IERC20(tokenIn).balanceOf(address(this));
        if (residual > 0) IERC20(tokenIn).safeTransfer(msg.sender, residual);

        emit Swapped(tokenIn, tokenOut, target, amountIn, amountOut, receiver);
    }
}
