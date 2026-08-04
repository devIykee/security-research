// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {INonfungiblePositionManager} from "./interfaces/INonfungiblePositionManager.sol";

/// @title LeavehoodLockLP
/// @notice Time-locks Uniswap V3 position NFTs (ERC721) or ERC20 amounts.
contract LeavehoodLockLP is Ownable, ReentrancyGuard, IERC721Receiver {
    using SafeERC20 for IERC20;

    struct Lock {
        address owner;
        address asset;      // ERC20 token, or the NonfungiblePositionManager (V3)
        uint256 amountOrId; // ERC20 amount, or the V3 tokenId
        uint64 unlockTime;
        bool isNFT;
        bool withdrawn;
    }

    uint64 public constant MAX_DURATION = 100 * 365 days;

    mapping(uint256 => Lock) public locks;
    uint256 public nextLockId;
    uint256 public lockFee;

    /// @notice Accounts exempt from lockFee. The Leavehood launchpad is exempted
    ///         so its automatic per-launch locks are free, while normal users
    ///         locking their own LP still pay lockFee. Owner-managed.
    mapping(address => bool) public feeExempt;

    event Locked(
        uint256 indexed lockId,
        address indexed owner,
        address indexed asset,
        bool isNFT,
        uint256 amountOrId,
        uint64 unlockTime
    );
    event Withdrawn(uint256 indexed lockId, address indexed owner);
    event Extended(uint256 indexed lockId, uint64 newUnlockTime);
    event LockOwnershipTransferred(uint256 indexed lockId, address indexed oldOwner, address indexed newOwner);
    event FeesCollected(uint256 indexed lockId, address indexed recipient, uint256 amount0, uint256 amount1);
    event LockFeeUpdated(uint256 newFee);
    event FeeExemptSet(address indexed account, bool exempt);
    event FeesWithdrawn(address indexed to, uint256 amount);

    error InvalidDuration();
    error ZeroAmount();
    error NotLockOwner();
    error StillLocked();
    error AlreadyWithdrawn();
    error CannotShorten();
    error ZeroAddress();
    error NotAnNFTLock();
    error InsufficientFee();
    error FeeTransferFailed();

    constructor() Ownable(msg.sender) {}

    // --------------------------------------------------------------- admin

    function setLockFee(uint256 newFee) external onlyOwner {
        lockFee = newFee;
        emit LockFeeUpdated(newFee);
    }

    /// @notice Exempt (or un-exempt) an account from lockFee. Set this for the
    ///         Leavehood launchpad so its per-launch locks cost nothing.
    function setFeeExempt(address account, bool exempt) external onlyOwner {
        feeExempt[account] = exempt;
        emit FeeExemptSet(account, exempt);
    }

    /// @notice The lockFee actually charged to `account`: 0 if exempt, else the
    ///         global lockFee. Callers should send exactly this as msg.value.
    function lockFeeFor(address account) public view returns (uint256) {
        return feeExempt[account] ? 0 : lockFee;
    }

    function withdrawFees(address payable to) external onlyOwner {
        if (to == address(0)) revert ZeroAddress();
        uint256 amount = address(this).balance;
        (bool ok, ) = to.call{value: amount}("");
        if (!ok) revert FeeTransferFailed();
        emit FeesWithdrawn(to, amount);
    }

    // ------------------------------------------------------------ internals

    function _computeUnlock(uint64 duration) internal view returns (uint64) {
        if (duration == 0 || duration > MAX_DURATION) revert InvalidDuration();
        return uint64(block.timestamp) + duration;
    }

    // ---------------------------------------------------------------- locks

    function lockToken(address token, uint256 amount, uint64 duration)
        external
        payable
        nonReentrant
        returns (uint256 lockId)
    {
        if (msg.value < lockFeeFor(msg.sender)) revert InsufficientFee();
        if (amount == 0) revert ZeroAmount();
        uint64 unlockTime = _computeUnlock(duration);

        uint256 balBefore = IERC20(token).balanceOf(address(this));
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        uint256 received = IERC20(token).balanceOf(address(this)) - balBefore;
        if (received == 0) revert ZeroAmount();

        lockId = nextLockId++;
        locks[lockId] = Lock({
            owner: msg.sender,
            asset: token,
            amountOrId: received,
            unlockTime: unlockTime,
            isNFT: false,
            withdrawn: false
        });

        emit Locked(lockId, msg.sender, token, false, received, unlockTime);
    }

    function lockPosition(address nftManager, uint256 tokenId, uint64 duration)
        external
        payable
        nonReentrant
        returns (uint256 lockId)
    {
        if (msg.value < lockFeeFor(msg.sender)) revert InsufficientFee();
        uint64 unlockTime = _computeUnlock(duration);

        lockId = nextLockId++;
        locks[lockId] = Lock({
            owner: msg.sender,
            asset: nftManager,
            amountOrId: tokenId,
            unlockTime: unlockTime,
            isNFT: true,
            withdrawn: false
        });

        IERC721(nftManager).safeTransferFrom(msg.sender, address(this), tokenId);
        emit Locked(lockId, msg.sender, nftManager, true, tokenId, unlockTime);
    }

    // -------------------------------------------------------------- manage

    function extendLock(uint256 lockId, uint64 newUnlockTime) external {
        Lock storage l = locks[lockId];
        if (l.owner != msg.sender) revert NotLockOwner();
        if (l.withdrawn) revert AlreadyWithdrawn();
        if (newUnlockTime <= l.unlockTime) revert CannotShorten();
        l.unlockTime = newUnlockTime;
        emit Extended(lockId, newUnlockTime);
    }

    function transferLockOwnership(uint256 lockId, address newOwner) external {
        Lock storage l = locks[lockId];
        if (l.owner != msg.sender) revert NotLockOwner();
        if (l.withdrawn) revert AlreadyWithdrawn();
        if (newOwner == address(0)) revert ZeroAddress();
        address old = l.owner;
        l.owner = newOwner;
        emit LockOwnershipTransferred(lockId, old, newOwner);
    }

    // ------------------------------------------------------------- withdraw

    function withdraw(uint256 lockId) external nonReentrant {
        Lock storage l = locks[lockId];
        if (l.owner != msg.sender) revert NotLockOwner();
        if (l.withdrawn) revert AlreadyWithdrawn();
        if (block.timestamp < l.unlockTime) revert StillLocked();

        l.withdrawn = true;

        if (l.isNFT) {
            IERC721(l.asset).safeTransferFrom(address(this), msg.sender, l.amountOrId);
        } else {
            IERC20(l.asset).safeTransfer(msg.sender, l.amountOrId);
        }
        emit Withdrawn(lockId, msg.sender);
    }

    // --------------------------------------------------- V3 fee collection

    /// @notice Collect accrued Uniswap V3 trading fees on a locked position.
    ///         Calls only `collect` — the locked principal cannot be moved.
    function collectFees(uint256 lockId, address recipient)
        external
        nonReentrant
        returns (uint256 amount0, uint256 amount1)
    {
        Lock storage l = locks[lockId];
        if (l.owner != msg.sender) revert NotLockOwner();
        if (l.withdrawn) revert AlreadyWithdrawn();
        if (!l.isNFT) revert NotAnNFTLock();
        if (recipient == address(0)) revert ZeroAddress();

        (amount0, amount1) = INonfungiblePositionManager(l.asset).collect(
            INonfungiblePositionManager.CollectParams({
                tokenId: l.amountOrId,
                recipient: recipient,
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            })
        );
        emit FeesCollected(lockId, recipient, amount0, amount1);
    }

    // ------------------------------------------------------------- receiver

    function onERC721Received(address, address, uint256, bytes calldata)
        external
        pure
        returns (bytes4)
    {
        return IERC721Receiver.onERC721Received.selector;
    }

    receive() external payable {}
}
