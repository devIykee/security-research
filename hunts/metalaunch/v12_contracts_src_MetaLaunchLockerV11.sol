// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {INonfungiblePositionManager} from "./interfaces/IUniswapV3.sol";

/// @title  MetaLaunchLockerV11
/// @notice Permanent, administratively-owned custody for MetaLaunch V11 launch
///         positions. Holds each launch's Uniswap v3 position NFT forever and
///         distributes its trading fees 90% creator / 10% protocol (snapshotted
///         per token at registration). There is NO liquidity-exit path anywhere
///         in this contract: no transfer, approve, decreaseLiquidity, burn,
///         re-range, arbitrary call, delegatecall, or rescue of a locked NFT.
///         The only NFT operation performed is `collect` (fees only — never
///         moves liquidity).
///
///         Ownership (Ownable2Step) governs ONLY fee infrastructure: the
///         protocol recipient, the DEFAULT protocol-fee share for FUTURE
///         registrations, and the approved-collector set. It can never touch a
///         locked position or a token's already-snapshotted split.
contract MetaLaunchLockerV11 is Ownable2Step, ReentrancyGuard, IERC721Receiver {
    using SafeERC20 for IERC20;

    // ------------------------------------------------------------------
    // Immutable / config
    // ------------------------------------------------------------------

    /// @notice The one factory allowed to deposit + register positions. Bound
    ///         once via {setFactory}, then immutable forever.
    address public factory;
    bool private _factoryBound;

    address public protocolFeeRecipient;
    uint16 public protocolFeeShareBps;
    uint16 public constant MAX_PROTOCOL_FEE_SHARE_BPS = 5_000;
    uint256 public constant BPS = 10_000;

    // ------------------------------------------------------------------
    // Per-token state (all set once, at registration)
    // ------------------------------------------------------------------

    struct Lock {
        address deployer; // immutable original creator (redirect authority)
        address positionManager;
        uint256 positionId;
        uint16 protocolShareBps; // snapshot — immutable for this token
        bool locked;
    }

    mapping(address token => Lock) private _locks;
    /// @notice Current creator fee recipient (initialised to launch feeWallet;
    ///         only the original deployer may change it).
    mapping(address token => address) public creatorFeeRecipient;
    mapping(address collector => bool) public feeCollectors;
    mapping(address deployer => address[]) public deployerTokens;
    mapping(address recipient => address[]) public feeRecipientTokens;

    // ------------------------------------------------------------------
    // Events & errors
    // ------------------------------------------------------------------

    event FactoryBound(address indexed factory);
    event PositionLocked(
        address indexed token,
        address indexed deployer,
        address indexed feeWallet,
        address positionManager,
        uint256 positionId,
        uint16 protocolShareBps
    );
    event FeesClaimed(
        address indexed token,
        address indexed caller,
        address token0,
        address token1,
        uint256 creatorAmount0,
        uint256 creatorAmount1,
        uint256 protocolAmount0,
        uint256 protocolAmount1
    );
    event FeeRedirectUpdated(
        address indexed token, address indexed creator, address indexed previousRecipient, address newRecipient
    );
    event ProtocolFeeRecipientUpdated(address indexed recipient);
    event ProtocolFeeShareUpdated(uint16 shareBps);
    event FeeCollectorUpdated(address indexed collector, bool enabled);

    error NotFactory();
    error FactoryAlreadyBound();
    error ZeroAddress();
    error AlreadyLocked();
    error UnknownToken();
    error NotOwnedByLocker();
    error NotTokenCreator();
    error NotAuthorizedCollector();
    error ShareTooHigh();
    error OnlyPositionManager();

    constructor(address owner_, address protocolFeeRecipient_, uint16 protocolFeeShareBps_) Ownable(owner_) {
        if (protocolFeeRecipient_ == address(0)) revert ZeroAddress();
        if (protocolFeeShareBps_ > MAX_PROTOCOL_FEE_SHARE_BPS) revert ShareTooHigh();
        protocolFeeRecipient = protocolFeeRecipient_;
        protocolFeeShareBps = protocolFeeShareBps_;
    }

    // ------------------------------------------------------------------
    // One-time factory binding
    // ------------------------------------------------------------------

    /// @notice Bind the factory once (deploy locker → deploy factory → bind).
    ///         Owner-only and single-shot: after binding, the factory address
    ///         can never change.
    function setFactory(address factory_) external onlyOwner {
        if (_factoryBound) revert FactoryAlreadyBound();
        if (factory_ == address(0)) revert ZeroAddress();
        factory = factory_;
        _factoryBound = true;
        emit FactoryBound(factory_);
    }

    // ------------------------------------------------------------------
    // Custody — deposit authenticated to the factory as operator
    // ------------------------------------------------------------------

    /// @notice Only accepts NFTs deposited BY the factory (operator == factory).
    ///         No other route can place a position in the locker. Registration
    ///         of the lock's terms happens in {registerLock}, called by the
    ///         factory in the same launch transaction.
    function onERC721Received(address operator, address, uint256, bytes calldata) external view returns (bytes4) {
        if (operator != factory) revert NotFactory();
        return IERC721Receiver.onERC721Received.selector;
    }

    /// @notice Factory-only. Records the locked position and snapshots the
    ///         protocol-fee share + creator fee recipient for `token`. Verifies
    ///         the locker actually owns the position on the given manager.
    function registerLock(
        address token,
        address deployer,
        address feeWallet,
        address positionManager_,
        uint256 positionId,
        uint16 protocolShareBps
    ) external {
        if (msg.sender != factory) revert NotFactory();
        if (_locks[token].locked) revert AlreadyLocked();
        if (token == address(0) || deployer == address(0) || feeWallet == address(0) || positionManager_ == address(0))
        {
            revert ZeroAddress();
        }
        if (protocolShareBps > MAX_PROTOCOL_FEE_SHARE_BPS) revert ShareTooHigh();
        if (INonfungiblePositionManager(positionManager_).ownerOf(positionId) != address(this)) {
            revert NotOwnedByLocker();
        }

        _locks[token] = Lock({
            deployer: deployer,
            positionManager: positionManager_,
            positionId: positionId,
            protocolShareBps: protocolShareBps,
            locked: true
        });
        creatorFeeRecipient[token] = feeWallet;
        deployerTokens[deployer].push(token);
        feeRecipientTokens[feeWallet].push(token);

        emit PositionLocked(token, deployer, feeWallet, positionManager_, positionId, protocolShareBps);
    }

    // ------------------------------------------------------------------
    // Fee collection — snapshotted split, stored recipients only
    // ------------------------------------------------------------------

    /// @notice Collect the locked position's accrued fees for `token` and split
    ///         BOTH assets 90/10 (per the token's snapshot) straight to the
    ///         stored creator + protocol recipients. Callable by the locker
    ///         owner, the original deployer, the current creator recipient, or
    ///         an approved collector. The caller can NEVER choose recipients or
    ///         percentages. WETH is paid as WETH (never unwrapped).
    function collectFees(address token) external nonReentrant {
        Lock memory L = _locks[token];
        if (!L.locked) revert UnknownToken();

        address creatorRecipient = creatorFeeRecipient[token];
        if (
            msg.sender != owner() && msg.sender != L.deployer && msg.sender != creatorRecipient
                && !feeCollectors[msg.sender]
        ) revert NotAuthorizedCollector();

        INonfungiblePositionManager npm = INonfungiblePositionManager(L.positionManager);
        (,, address token0, address token1,,,,,,,,) = npm.positions(L.positionId);

        // Collect all owed fees to the locker (exact returned amounts drive the
        // split — never event values). `collect` never changes liquidity.
        (uint256 amount0, uint256 amount1) = npm.collect(
            INonfungiblePositionManager.CollectParams({
                tokenId: L.positionId,
                recipient: address(this),
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            })
        );

        address protocolRecipient = protocolFeeRecipient;
        uint16 share = L.protocolShareBps;

        (uint256 c0, uint256 p0) = _split(token, token0, amount0, share, creatorRecipient, protocolRecipient);
        (uint256 c1, uint256 p1) = _split(token, token1, amount1, share, creatorRecipient, protocolRecipient);

        emit FeesClaimed(token, msg.sender, token0, token1, c0, c1, p0, p1);
    }

    /// @dev protocol = amount * share / BPS; creator = remainder (creator-favorable).
    function _split(
        address, /*token*/
        address asset,
        uint256 amount,
        uint16 share,
        address creatorRecipient,
        address protocolRecipient
    ) private returns (uint256 creatorAmount, uint256 protocolAmount) {
        if (amount == 0) return (0, 0);
        protocolAmount = (amount * share) / BPS;
        creatorAmount = amount - protocolAmount;
        if (creatorAmount > 0) IERC20(asset).safeTransfer(creatorRecipient, creatorAmount);
        if (protocolAmount > 0) IERC20(asset).safeTransfer(protocolRecipient, protocolAmount);
    }

    // ------------------------------------------------------------------
    // Creator-only fee redirect
    // ------------------------------------------------------------------

    /// @notice Only the ORIGINAL deployer may redirect the creator fee share.
    ///         Does not touch the creator identity, protocol side, the locked
    ///         position, or fees already distributed.
    function setFeeRedirect(address token, address newFeeRecipient) external {
        Lock memory L = _locks[token];
        if (!L.locked) revert UnknownToken();
        if (msg.sender != L.deployer) revert NotTokenCreator();
        if (newFeeRecipient == address(0)) revert ZeroAddress();

        address prev = creatorFeeRecipient[token];
        creatorFeeRecipient[token] = newFeeRecipient;
        feeRecipientTokens[newFeeRecipient].push(token);
        emit FeeRedirectUpdated(token, L.deployer, prev, newFeeRecipient);
    }

    // ------------------------------------------------------------------
    // Owner: fee infrastructure only (affects FUTURE registrations)
    // ------------------------------------------------------------------

    function setProtocolFeeRecipient(address recipient) external onlyOwner {
        if (recipient == address(0)) revert ZeroAddress();
        protocolFeeRecipient = recipient;
        emit ProtocolFeeRecipientUpdated(recipient);
    }

    function setProtocolFeeShareBps(uint16 shareBps) external onlyOwner {
        if (shareBps > MAX_PROTOCOL_FEE_SHARE_BPS) revert ShareTooHigh();
        protocolFeeShareBps = shareBps;
        emit ProtocolFeeShareUpdated(shareBps);
    }

    function setFeeCollector(address collector, bool enabled) external onlyOwner {
        if (collector == address(0)) revert ZeroAddress();
        feeCollectors[collector] = enabled;
        emit FeeCollectorUpdated(collector, enabled);
    }

    // ------------------------------------------------------------------
    // Views
    // ------------------------------------------------------------------

    /// @notice True iff the recorded position for `token` is still owned by this
    ///         locker on its recorded manager. (Custody proof for the frontend.)
    function isPositionPermanentlyLocked(address token) external view returns (bool) {
        Lock memory L = _locks[token];
        if (!L.locked) return false;
        try INonfungiblePositionManager(L.positionManager).ownerOf(L.positionId) returns (address o) {
            return o == address(this);
        } catch {
            return false;
        }
    }

    function isLocked(address token) external view returns (bool) {
        return _locks[token].locked;
    }

    function lockedPositionId(address token) external view returns (uint256) {
        return _locks[token].positionId;
    }

    function positionManagerOfToken(address token) external view returns (address) {
        return _locks[token].positionManager;
    }

    /// @notice Immutable original creator/deployer for `token` (redirect authority).
    function tokenCreator(address token) external view returns (address) {
        return _locks[token].deployer;
    }

    function tokenProtocolFeeShare(address token) external view returns (uint16) {
        return _locks[token].protocolShareBps;
    }

    function getLock(address token)
        external
        view
        returns (
            address deployer,
            address feeRecipient,
            address positionManager_,
            uint256 positionId,
            uint16 shareBps,
            bool locked
        )
    {
        Lock memory L = _locks[token];
        return (L.deployer, creatorFeeRecipient[token], L.positionManager, L.positionId, L.protocolShareBps, L.locked);
    }

    function deployerTokenCount(address deployer) external view returns (uint256) {
        return deployerTokens[deployer].length;
    }
}
