// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Minimal Uniswap v3 NonfungiblePositionManager surface the locker needs.
interface INonfungiblePositionManager {
    struct CollectParams {
        uint256 tokenId;
        address recipient;
        uint128 amount0Max;
        uint128 amount1Max;
    }

    function collect(CollectParams calldata params)
        external
        payable
        returns (uint256 amount0, uint256 amount1);

    function ownerOf(uint256 tokenId) external view returns (address);

    function positions(uint256 tokenId)
        external
        view
        returns (
            uint96 nonce,
            address operator,
            address token0,
            address token1,
            uint24 fee,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        );
}

interface IERC165 {
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

interface IERC721Receiver {
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data)
        external
        returns (bytes4);
}

/// @notice Scanner/indexer-facing interface for the permanent locker.
///         Implemented by MetaLocker and advertised via ERC-165.
interface IMetaLockerPermanent {
    function positionManager() external view returns (INonfungiblePositionManager);
    function feeController(uint256 tokenId) external view returns (address);
    function collect(uint256 tokenId) external returns (uint256 amount0, uint256 amount1);
    function isPermanentlyLocked(uint256 tokenId) external view returns (bool);
    function isFeeControllerBound(uint256 tokenId) external view returns (bool);
    function isManagedPosition(uint256 tokenId) external view returns (bool);
    function lockedPositionCount() external view returns (uint256);
    function lockedPositionAt(uint256 index) external view returns (uint256);
}

/// @title  MetaLocker — permanent Uniswap v3 LP lock (evergreen, version-independent)
/// @notice Positions deposited here can NEVER leave. This contract has no
///         owner, no admin role, no upgrade path, and no function that can
///         transfer, approve, decrease, burn, or re-range a position, nor any
///         arbitrary-call or delegatecall capability. The ONLY state-changing
///         operations are (a) receiving a position via the canonical
///         NonfungiblePositionManager's `safeTransferFrom` — which immutably
///         binds the position to a depositor-authorized fee controller — and
///         (b) collecting swap fees, callable only by that controller, with
///         proceeds sent directly to it. The locker never holds ERC-20 or ETH
///         balances.
///
///         The permanence guarantee is the verified runtime code's LACK of
///         any exit path — the convenience views below are discoverability
///         hints for integrators, not the proof.
///
///         Deposit protocol
///         ----------------
///         The sole entry is the four-argument `safeTransferFrom` on the
///         canonical position manager with `data = abi.encode(feeController)`
///         (exactly 32 bytes, nonzero address). Any other data reverts, so no
///         position can enter the safe path unbound. A raw `transferFrom`
///         bypasses this callback (per ERC-721) and permanently strands the
///         position: still locked, but with no fee controller — its fees are
///         unclaimable forever. Do not send positions here without the
///         binding data.
contract MetaLocker is IERC165, IERC721Receiver, IMetaLockerPermanent {
    // ------------------------------------------------------------------
    // Errors
    // ------------------------------------------------------------------

    error InvalidPositionManager();
    error OnlyPositionManager();
    error PositionAlreadyBound();
    error InvalidBindingData();
    error InvalidController();
    error NotFeeController();

    // ------------------------------------------------------------------
    // Storage & constants
    // ------------------------------------------------------------------

    /// @notice The canonical Uniswap v3 NonfungiblePositionManager. The only
    ///         address this contract can ever call.
    INonfungiblePositionManager public immutable positionManager;

    /// @notice tokenId => permanently bound fee controller. Set exactly once,
    ///         at deposit, from depositor-authorized transfer data. There is
    ///         no code path that can modify an existing binding.
    mapping(uint256 => address) public feeController;

    /// @dev Append-only enumeration of positions bound via the safe path.
    uint256[] private _lockedIds;

    /// @notice Positions can never be withdrawn. Corroborating signal for
    ///         integrators that model lockers with expiries.
    uint256 public constant UNLOCK_TIME = type(uint256).max;
    bytes32 public constant LOCK_TYPE = keccak256("PERMANENT_NO_EXIT");
    uint16 public constant LOCK_VERSION = 1;

    // ------------------------------------------------------------------
    // Events
    // ------------------------------------------------------------------

    event PositionLocked(
        uint256 indexed tokenId,
        address indexed feeController,
        address indexed depositor,
        address token0,
        address token1,
        uint24 fee
    );

    event FeesCollected(
        uint256 indexed tokenId,
        address indexed feeController,
        uint256 amount0,
        uint256 amount1
    );

    // ------------------------------------------------------------------
    // Construction
    // ------------------------------------------------------------------

    constructor(address npm) {
        if (npm == address(0) || npm.code.length == 0) revert InvalidPositionManager();
        positionManager = INonfungiblePositionManager(npm);
    }

    // ------------------------------------------------------------------
    // Deposit — the ONLY way in; binds the fee controller immutably
    // ------------------------------------------------------------------

    /// @notice ERC-721 receive hook. Reverting here reverts the entire
    ///         transfer (and the caller's whole transaction), so a launch can
    ///         never complete with an unbound position.
    function onERC721Received(address, address from, uint256 tokenId, bytes calldata data)
        external
        override
        returns (bytes4)
    {
        if (msg.sender != address(positionManager)) revert OnlyPositionManager();
        if (feeController[tokenId] != address(0)) revert PositionAlreadyBound();
        if (data.length != 32) revert InvalidBindingData();
        address controller = abi.decode(data, (address));
        if (controller == address(0)) revert InvalidController();

        feeController[tokenId] = controller;
        _lockedIds.push(tokenId);

        (, , address t0, address t1, uint24 f, , , , , , , ) = positionManager.positions(tokenId);
        emit PositionLocked(tokenId, controller, from, t0, t1, f);
        return this.onERC721Received.selector;
    }

    // ------------------------------------------------------------------
    // Fee collection — controller-only; proceeds bypass the locker
    // ------------------------------------------------------------------

    /// @notice Collect a locked position's accrued swap fees. Callable only
    ///         by the position's immutably bound fee controller; the position
    ///         manager pays fees directly to that controller. Returns the
    ///         EXACT transferred amounts (use these for accounting, not the
    ///         position manager's Collect event, whose values may differ by
    ///         rounding). Collection never changes position liquidity.
    function collect(uint256 tokenId)
        external
        override
        returns (uint256 amount0, uint256 amount1)
    {
        address controller = feeController[tokenId];
        if (msg.sender != controller) revert NotFeeController();

        (amount0, amount1) = positionManager.collect(
            INonfungiblePositionManager.CollectParams({
                tokenId: tokenId,
                recipient: controller,
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            })
        );
        emit FeesCollected(tokenId, controller, amount0, amount1);
    }

    // ------------------------------------------------------------------
    // Views — discoverability hints (the proof is the absent code paths)
    // ------------------------------------------------------------------

    /// @notice True if this locker owns the position NFT. Independent of fee
    ///         binding: a position stranded via raw `transferFrom` is still
    ///         permanently locked. Never reverts (nonexistent ids → false).
    function isPermanentlyLocked(uint256 tokenId) public view override returns (bool) {
        try positionManager.ownerOf(tokenId) returns (address positionOwner) {
            return positionOwner == address(this);
        } catch {
            return false;
        }
    }

    /// @notice True if the position has a bound fee controller.
    function isFeeControllerBound(uint256 tokenId) public view override returns (bool) {
        return feeController[tokenId] != address(0);
    }

    /// @notice True if the position is both locked here and fee-bound (the
    ///         normal state for every position deposited via the safe path).
    function isManagedPosition(uint256 tokenId) external view override returns (bool) {
        return isPermanentlyLocked(tokenId) && isFeeControllerBound(tokenId);
    }

    function lockedPositionCount() external view override returns (uint256) {
        return _lockedIds.length;
    }

    function lockedPositionAt(uint256 index) external view override returns (uint256) {
        return _lockedIds[index];
    }

    /// @notice Discoverability hints. NOT the security proof — that is the
    ///         verified runtime code's lack of any transfer, approval,
    ///         liquidity-decrease, burn, upgrade, arbitrary-call, or
    ///         delegatecall path.
    function canDecreaseLiquidity() external pure returns (bool) {
        return false;
    }

    function canTransferPosition() external pure returns (bool) {
        return false;
    }

    // ------------------------------------------------------------------
    // ERC-165
    // ------------------------------------------------------------------

    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return interfaceId == type(IERC165).interfaceId
            || interfaceId == type(IERC721Receiver).interfaceId
            || interfaceId == type(IMetaLockerPermanent).interfaceId;
    }
}
