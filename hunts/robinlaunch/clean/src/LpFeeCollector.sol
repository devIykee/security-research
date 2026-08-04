// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./interfaces/INonfungiblePositionManager.sol";
import "./interfaces/ILpFeeCollector.sol";

/**
 * @title LpFeeCollector
 * @notice Holds every Uniswap V3 LP position minted by RobinLaunch — both bonding-curve
 *         graduations (Factory/BondingCurve) and instant Direct Pool launches (DirectFactory)
 *         — replacing the previous "burn the LP NFT to 0xdead" pattern. Trading fees that
 *         accrue on these positions after launch are now collectible and split between the
 *         token creator and the protocol, instead of being permanently unreachable.
 *
 * Security model — read this before touching anything:
 *   • This contract can NEVER move the underlying liquidity. There is no `decreaseLiquidity`,
 *     no `burn`, no NFT transfer function of any kind, and it never approves the NFT to anyone.
 *     Liquidity stays exactly as permanently locked as it was when sent to 0xdead — the only
 *     thing that changed is that swap fees are now reachable.
 *   • `registerPosition` can only succeed once per tokenId (enforced by `creatorOf[tokenId] ==
 *     address(0)`), so a position's creator can never be overwritten or hijacked later — not
 *     even by the contract owner.
 *   • Creator and protocol balances are accounted for separately, per token, exactly like
 *     `BondingCurve.pendingCreatorFees` / `Factory.pendingFees` today. The owner can only ever
 *     withdraw the protocol share; it can never touch a creator's pending balance.
 *   • Two independent, owner-controlled allow-lists gate write access:
 *       – `isFactory`: contracts allowed to onboard *new* minters (the bonding-curve Factory —
 *         it self-registers each BondingCurve it deploys, atomically, in the same transaction).
 *       – `isMinter`: contracts allowed to call `registerPosition` directly (every onboarded
 *         BondingCurve, plus the DirectFactory, which registers on its own behalf).
 *
 * Fee split: 50% creator / 50% protocol — the same ratio used during the bonding-curve phase.
 */
contract LpFeeCollector is Ownable, ReentrancyGuard, ILpFeeCollector {
    using SafeERC20 for IERC20;

    // ─── Constants ────────────────────────────────────────────────────────────

    uint256 public constant CREATOR_FEE_BPS = 5_000; // 50 %
    uint256 public constant FEE_DENOM       = 10_000;

    // ─── Immutables ───────────────────────────────────────────────────────────

    INonfungiblePositionManager public immutable positionManager;

    // ─── State ────────────────────────────────────────────────────────────────

    /// Contracts allowed to onboard new minters (i.e. the bonding-curve Factory).
    mapping(address => bool) public isFactory;

    /// Contracts allowed to call registerPosition (onboarded BondingCurves + DirectFactory).
    mapping(address => bool) public isMinter;

    /// tokenId → original creator. Set exactly once at registration, never overwritten.
    mapping(uint256 => address) public creatorOf;

    /// tokenId → payout address for creator fees. Defaults to creator, changeable by creator.
    mapping(uint256 => address) public creatorFeeRecipient;

    /// tokenId → pool tokens, resolved once from the position manager at registration time.
    mapping(uint256 => address) public positionToken0;
    mapping(uint256 => address) public positionToken1;

    /// tokenId → token → creator fees collected but not yet claimed.
    mapping(uint256 => mapping(address => uint256)) public pendingCreatorFees;

    /// token → protocol fees collected but not yet withdrawn (aggregated across all positions).
    mapping(address => uint256) public pendingProtocolFees;

    // ─── Events ───────────────────────────────────────────────────────────────

    event FactoryUpdated(address indexed factory, bool allowed);
    event MinterUpdated(address indexed minter, bool allowed);
    event PositionRegistered(uint256 indexed tokenId, address indexed creator, address token0, address token1);
    event CreatorFeeRecipientSet(uint256 indexed tokenId, address indexed oldRecipient, address indexed newRecipient);
    event FeesCollected(uint256 indexed tokenId, uint256 amount0, uint256 amount1);
    event CreatorFeesClaimed(uint256 indexed tokenId, address indexed recipient, address token, uint256 amount);
    event ProtocolFeesWithdrawn(address indexed token, address indexed to, uint256 amount);

    // ─── Constructor ──────────────────────────────────────────────────────────

    constructor(address _positionManager) Ownable(msg.sender) {
        require(_positionManager != address(0), "LpFeeCollector: zero positionManager");
        positionManager = INonfungiblePositionManager(_positionManager);
    }

    // ─── Owner setup (one-time, right after deployment) ──────────────────────

    /**
     * @notice Allow/revoke a bonding-curve Factory to onboard new minters
     *         (i.e. to vouch for each BondingCurve it deploys).
     */
    function setFactory(address factory, bool allowed) external onlyOwner {
        isFactory[factory] = allowed;
        emit FactoryUpdated(factory, allowed);
    }

    /**
     * @notice Directly allow/revoke a minter (used for DirectFactory, which registers
     *         positions on its own behalf rather than through a per-token sub-contract).
     *         Revoking a minter never affects positions it already registered —
     *         registerPosition is one-time-write per tokenId.
     */
    function setMinter(address minter, bool allowed) external onlyOwner {
        isMinter[minter] = allowed;
        emit MinterUpdated(minter, allowed);
    }

    // ─── Factory-controlled onboarding ────────────────────────────────────────

    /**
     * @notice Called by an allow-listed Factory, in the same transaction as it deploys a
     *         new BondingCurve, so that curve can register its own position when it
     *         eventually graduates — with no per-token owner intervention required.
     */
    function onboardMinter(address minter) external override {
        require(isFactory[msg.sender], "LpFeeCollector: not factory");
        isMinter[minter] = true;
        emit MinterUpdated(minter, true);
    }

    // ─── Registration (called once, right after mint) ────────────────────────

    /**
     * @notice Record the creator of a freshly-minted LP position owned by this contract.
     *         Must be called in the same transaction as the mint, by the minter itself.
     */
    function registerPosition(uint256 tokenId, address creator) external override {
        require(isMinter[msg.sender], "LpFeeCollector: not minter");
        require(creator != address(0), "LpFeeCollector: zero creator");
        require(creatorOf[tokenId] == address(0), "LpFeeCollector: already registered");

        (, , address token0, address token1, , , , , , , ,) = positionManager.positions(tokenId);

        creatorOf[tokenId]           = creator;
        creatorFeeRecipient[tokenId] = creator;
        positionToken0[tokenId]      = token0;
        positionToken1[tokenId]      = token1;

        emit PositionRegistered(tokenId, creator, token0, token1);
    }

    // ─── Creator fee recipient management ─────────────────────────────────────

    /**
     * @notice Change the address that receives this position's creator fee payouts.
     *         Only callable by the original creator recorded at registration.
     */
    function setCreatorFeeRecipient(uint256 tokenId, address newRecipient) external {
        require(msg.sender == creatorOf[tokenId], "LpFeeCollector: not creator");
        require(newRecipient != address(0), "LpFeeCollector: zero address");
        address old = creatorFeeRecipient[tokenId];
        creatorFeeRecipient[tokenId] = newRecipient;
        emit CreatorFeeRecipientSet(tokenId, old, newRecipient);
    }

    // ─── Harvest ───────────────────────────────────────────────────────────────

    /**
     * @notice Pull all Uniswap V3 swap fees accrued on `tokenId` into this contract,
     *         then book the 50/50 creator/protocol split. Permissionless — anyone can
     *         trigger a harvest (the "Claim" button, a keeper, or a curious observer).
     */
    function collectFees(uint256 tokenId) external nonReentrant {
        require(creatorOf[tokenId] != address(0), "LpFeeCollector: not registered");

        (uint256 amount0, uint256 amount1) = positionManager.collect(
            INonfungiblePositionManager.CollectParams({
                tokenId:    tokenId,
                recipient:  address(this),
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            })
        );

        if (amount0 > 0) _bookFees(tokenId, positionToken0[tokenId], amount0);
        if (amount1 > 0) _bookFees(tokenId, positionToken1[tokenId], amount1);

        emit FeesCollected(tokenId, amount0, amount1);
    }

    function _bookFees(uint256 tokenId, address token, uint256 amount) internal {
        uint256 creatorShare  = amount * CREATOR_FEE_BPS / FEE_DENOM;
        uint256 protocolShare = amount - creatorShare;
        pendingCreatorFees[tokenId][token] += creatorShare;
        pendingProtocolFees[token]         += protocolShare;
    }

    // ─── Claim ─────────────────────────────────────────────────────────────────

    /**
     * @notice Claim the creator's pending balance (both pool tokens at once) for `tokenId`.
     *         Callable by anyone — funds always go to creatorFeeRecipient. Call collectFees()
     *         first to make sure the freshest fees are included.
     */
    function claimCreatorFees(uint256 tokenId) external nonReentrant {
        address creator = creatorOf[tokenId];
        require(creator != address(0), "LpFeeCollector: not registered");

        address recipient = creatorFeeRecipient[tokenId];
        address t0 = positionToken0[tokenId];
        address t1 = positionToken1[tokenId];
        uint256 amount0 = pendingCreatorFees[tokenId][t0];
        uint256 amount1 = pendingCreatorFees[tokenId][t1];
        require(amount0 > 0 || amount1 > 0, "LpFeeCollector: nothing to claim");

        if (amount0 > 0) {
            pendingCreatorFees[tokenId][t0] = 0;
            IERC20(t0).safeTransfer(recipient, amount0);
            emit CreatorFeesClaimed(tokenId, recipient, t0, amount0);
        }
        if (amount1 > 0) {
            pendingCreatorFees[tokenId][t1] = 0;
            IERC20(t1).safeTransfer(recipient, amount1);
            emit CreatorFeesClaimed(tokenId, recipient, t1, amount1);
        }
    }

    // ─── Protocol fee management ───────────────────────────────────────────────

    /**
     * @notice Withdraw all accumulated protocol fees of `token` to `to`.
     */
    function withdrawProtocolFees(address token, address to) external onlyOwner nonReentrant {
        require(to != address(0), "LpFeeCollector: zero recipient");
        uint256 amount = pendingProtocolFees[token];
        require(amount > 0, "LpFeeCollector: no fees");
        pendingProtocolFees[token] = 0;
        IERC20(token).safeTransfer(to, amount);
        emit ProtocolFeesWithdrawn(token, to, amount);
    }

    /**
     * @notice Convenience batch withdrawal across several tokens in one call.
     */
    function withdrawProtocolFeesBatch(address[] calldata tokens, address to) external onlyOwner nonReentrant {
        require(to != address(0), "LpFeeCollector: zero recipient");
        for (uint256 i = 0; i < tokens.length; i++) {
            address token = tokens[i];
            uint256 amount = pendingProtocolFees[token];
            if (amount == 0) continue;
            pendingProtocolFees[token] = 0;
            IERC20(token).safeTransfer(to, amount);
            emit ProtocolFeesWithdrawn(token, to, amount);
        }
    }

    // ─── View helpers ──────────────────────────────────────────────────────────

    /**
     * @notice One-call snapshot of a position for the frontend: creator, payout
     *         address, both pool tokens, and both pending creator balances.
     */
    function positionInfo(uint256 tokenId)
        external
        view
        returns (
            address creator,
            address recipient,
            address token0,
            address token1,
            uint256 pendingCreator0,
            uint256 pendingCreator1
        )
    {
        creator         = creatorOf[tokenId];
        recipient       = creatorFeeRecipient[tokenId];
        token0          = positionToken0[tokenId];
        token1          = positionToken1[tokenId];
        pendingCreator0 = pendingCreatorFees[tokenId][token0];
        pendingCreator1 = pendingCreatorFees[tokenId][token1];
    }
}
