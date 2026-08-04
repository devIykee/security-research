// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IPlatformControls} from "../interfaces/IPlatformControls.sol";
import {IRewardVaultV2} from "./interfaces/IStockConversion.sol";

/// @title RewardVaultV2
/// @notice Per-meme-token holder reward vault (accumulated-reward-per-share).
///         V2 rewards are the paired STOCK token, deposited by the
///         StockRewardTreasury after a successful conversion. A WETH reward
///         asset is also supported for an explicitly-disclosed governance
///         fallback only; by default only the stock asset is credited.
contract RewardVaultV2 is IRewardVaultV2, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 private constant ACC_PRECISION = 1e18;

    address public immutable memeToken;
    address public immutable factory; // IPlatformControls (claimsPaused)
    address public pool;
    address public notifier; // StockRewardTreasury — the only depositor

    mapping(address asset => uint256) public accPerShare;
    mapping(address asset => uint256) public unallocated;
    mapping(address account => mapping(address asset => uint256)) public accPaid;
    mapping(address account => mapping(address asset => uint256)) public accrued;
    mapping(address account => bool) public excluded;

    address[] public rewardAssets;
    mapping(address asset => bool) public isRewardAsset;
    uint256 public eligibleSupply;

    event RewardNotified(address indexed asset, uint256 amount);
    event RewardClaimed(address indexed account, address indexed asset, uint256 amount);
    event Initialized(address pool, address notifier, address stockAsset);

    error OnlyFactory();
    error OnlyMemeToken();
    error OnlyNotifier();
    error AlreadyInit();
    error NotRewardAsset();
    error ZeroAddress();
    error ClaimsArePaused();

    constructor(address memeToken_, address factory_) {
        if (memeToken_ == address(0) || factory_ == address(0)) revert ZeroAddress();
        memeToken = memeToken_;
        factory = factory_;
        excluded[address(this)] = true;
        excluded[factory_] = true;
    }

    /// @notice One-time wiring by the factory. `stockAsset` is the reward asset.
    function initialize(address pool_, address notifier_, address stockAsset, address wethAsset) external {
        if (msg.sender != factory) revert OnlyFactory();
        if (pool != address(0)) revert AlreadyInit();
        if (pool_ == address(0) || notifier_ == address(0) || stockAsset == address(0)) revert ZeroAddress();
        pool = pool_;
        notifier = notifier_;
        excluded[pool_] = true;
        excluded[notifier_] = true;
        _addRewardAsset(stockAsset);
        if (wethAsset != address(0)) _addRewardAsset(wethAsset);
        emit Initialized(pool_, notifier_, stockAsset);
    }

    function _addRewardAsset(address asset) internal {
        if (!isRewardAsset[asset]) {
            isRewardAsset[asset] = true;
            rewardAssets.push(asset);
        }
    }

    /// @notice Called by the meme token before every balance change.
    function checkpoint(address from, address to, uint256 value) external {
        if (msg.sender != memeToken) revert OnlyMemeToken();
        if (from != address(0)) _settle(from);
        if (to != address(0) && to != from) _settle(to);

        if (from == address(0)) {
            if (!excluded[to]) eligibleSupply += value;
        } else if (to == address(0)) {
            if (!excluded[from]) eligibleSupply -= value;
        } else {
            if (excluded[from] && !excluded[to]) eligibleSupply += value;
            else if (!excluded[from] && excluded[to]) eligibleSupply -= value;
        }
    }

    function _settle(address account) internal {
        uint256 bal = IERC20(memeToken).balanceOf(account);
        uint256 len = rewardAssets.length;
        for (uint256 i; i < len; ++i) {
            address asset = rewardAssets[i];
            uint256 acc = accPerShare[asset];
            uint256 paid = accPaid[account][asset];
            if (!excluded[account] && acc > paid && bal > 0) {
                accrued[account][asset] += (bal * (acc - paid)) / ACC_PRECISION;
            }
            accPaid[account][asset] = acc;
        }
    }

    /// @notice Deposit converted stock rewards. Only the treasury (notifier).
    ///         Caller must have approved `amount`.
    function notifyReward(address asset, uint256 amount) external nonReentrant {
        if (msg.sender != notifier) revert OnlyNotifier();
        if (!isRewardAsset[asset]) revert NotRewardAsset();
        if (amount == 0) return;
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);

        uint256 supply = eligibleSupply;
        if (supply == 0) {
            unallocated[asset] += amount;
        } else {
            uint256 total = amount + unallocated[asset];
            unallocated[asset] = 0;
            accPerShare[asset] += (total * ACC_PRECISION) / supply;
        }
        emit RewardNotified(asset, amount);
    }

    function claimable(address account, address asset) external view returns (uint256) {
        uint256 pending = accrued[account][asset];
        if (!excluded[account]) {
            uint256 bal = IERC20(memeToken).balanceOf(account);
            uint256 acc = accPerShare[asset];
            uint256 paid = accPaid[account][asset];
            if (acc > paid && bal > 0) pending += (bal * (acc - paid)) / ACC_PRECISION;
        }
        return pending;
    }

    function claim(address asset) external nonReentrant returns (uint256 amount) {
        if (IPlatformControls(factory).claimsPaused()) revert ClaimsArePaused();
        _settle(msg.sender);
        amount = accrued[msg.sender][asset];
        if (amount > 0) {
            accrued[msg.sender][asset] = 0;
            IERC20(asset).safeTransfer(msg.sender, amount);
            emit RewardClaimed(msg.sender, asset, amount);
        }
    }

    function rewardAssetsLength() external view returns (uint256) {
        return rewardAssets.length;
    }
}
