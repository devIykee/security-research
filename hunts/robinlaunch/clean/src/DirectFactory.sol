// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "./Token.sol";
import "./interfaces/INonfungiblePositionManager.sol";
import "./interfaces/IWETH.sol";
import "./interfaces/ILpFeeCollector.sol";

/**
 * @title DirectFactory
 * @notice Instant Uniswap V3 pool launch — no bonding curve, no graduation.
 *
 * How it works:
 *   1. Creator calls createToken() with msg.value = createFee + liquidityEth.
 *   2. A new ERC20 Token is deployed (1,000,000,000 tokens minted to this factory).
 *   3. liquidityEth is wrapped to WETH.
 *   4. A Uniswap V3 pool (1% fee tier) is created at the initial price:
 *        price = liquidityEth / 1,000,000,000 tokens
 *      → the creator's ETH directly determines the launch market cap.
 *   5. ALL 1B tokens + ALL liquidityEth (as WETH) are minted into a full-range LP position.
 *   6. The LP NFT is sent to `lpFeeCollector` (if configured) — liquidity is locked forever,
 *      rug-proof, exactly like the previous 0xdead behaviour — but swap fees stay collectible.
 *      Falls back to 0xdead if no collector was configured at deployment.
 *   7. Any rounding dust is returned to the creator.
 *
 * Revenue:
 *   • createFee (0.002 ETH) per launch → protocol (collected via withdrawFees).
 *   • Ongoing: Uniswap V3 1% LP fees, split 50/50 creator/protocol via LpFeeCollector
 *     (or accumulate unreachable at 0xdead if this factory has no collector configured).
 *
 * Market cap formula (at launch):
 *   mcap (ETH) = liquidityEth
 *   mcap (USD) = liquidityEth × ETH/USD price
 */
contract DirectFactory is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ─── Constants ────────────────────────────────────────────────────────────

    uint256 public constant TOTAL_SUPPLY = 1_000_000_000e18;

    /// Uniswap V3 1% fee tier
    uint24  public constant UNISWAP_FEE  = 10_000;

    /// Full-range tick bounds for the 1% fee tier (tick spacing = 200)
    int24   public constant TICK_LOWER   = -887_200;
    int24   public constant TICK_UPPER   =  887_200;

    /// LP NFT destination when no lpFeeCollector is configured — locked forever
    address public constant LOCK_ADDRESS = 0x000000000000000000000000000000000000dEaD;

    // ─── Immutables ───────────────────────────────────────────────────────────

    address public immutable positionManager;
    address public immutable weth;
    /// address(0) preserves the legacy behaviour (LP NFT burned to 0xdead).
    address public immutable lpFeeCollector;

    // ─── State ────────────────────────────────────────────────────────────────

    /// Fee required to call createToken() (default 0.002 ETH, same as bonding-curve factory)
    uint256 public createFee = 0.002 ether;

    /// Accumulated protocol fees waiting to be withdrawn
    uint256 public pendingFees;

    /// All deployed token addresses (ordered by creation index)
    address[] public allTokens;

    /// token address → Uniswap V3 pool address
    mapping(address => address) public getPool;

    /// token address → creator wallet
    mapping(address => address) public getCreator;

    /// @dev Set while unwrapping WETH dust inside _returnDust() so that the ETH
    ///      bounced back by WETH.withdraw() into receive() is NOT double-counted
    ///      as a protocol fee (see receive() below). Without this guard, pendingFees
    ///      would grow faster than the contract's real ETH balance on every launch
    ///      that leaves rounding dust, eventually making withdrawFees() revert.
    bool private _returningDust;

    // ─── Events ───────────────────────────────────────────────────────────────

    event TokenLaunched(
        address indexed creator,
        address indexed token,
        address indexed pool,
        string  name,
        string  symbol,
        string  metadataURI,
        uint256 index,
        uint256 initialEth,
        uint256 tokenId
    );
    event FeesWithdrawn(address indexed to, uint256 amount);
    event CreateFeeUpdated(uint256 oldFee, uint256 newFee);

    // ─── Constructor ──────────────────────────────────────────────────────────

    /**
     * @param _positionManager Uniswap V3 NonfungiblePositionManager address
     * @param _weth            WETH9 address on this chain
     * @param _lpFeeCollector  Shared LpFeeCollector address, or address(0) to keep the
     *                         legacy "burn LP NFT to 0xdead" behaviour. This factory must
     *                         be allow-listed via `LpFeeCollector.setMinter(address(this), true)`
     *                         for registerPosition() calls in createToken() to succeed.
     */
    constructor(address _positionManager, address _weth, address _lpFeeCollector) Ownable(msg.sender) {
        require(_positionManager != address(0), "DirectFactory: zero positionManager");
        require(_weth            != address(0), "DirectFactory: zero weth");
        positionManager = _positionManager;
        weth            = _weth;
        lpFeeCollector  = _lpFeeCollector;
    }

    // ─── Owner controls ───────────────────────────────────────────────────────

    function setCreateFee(uint256 newFee) external onlyOwner {
        emit CreateFeeUpdated(createFee, newFee);
        createFee = newFee;
    }

    // ─── Launch ───────────────────────────────────────────────────────────────

    /**
     * @notice Deploy a token and immediately create a permanent Uniswap V3 pool.
     * @dev msg.value must be strictly greater than createFee so that at least
     *      1 wei of real liquidity enters the pool.
     *      The initial price is set by:  liquidityEth / TOTAL_SUPPLY
     *      Sending 1 ETH gives a launch market cap of 1 ETH.
     *
     * @param name        ERC20 token name
     * @param symbol      ERC20 ticker symbol
     * @param metadataURI IPFS or HTTPS URI for the token logo / description JSON
     * @return tokenAddr  Address of the newly deployed Token contract
     * @return pool       Address of the Uniswap V3 pool
     */
    function createToken(
        string calldata name,
        string calldata symbol,
        string calldata metadataURI
    ) external payable nonReentrant returns (address tokenAddr, address pool) {
        require(
            msg.value > createFee,
            "DirectFactory: msg.value must exceed createFee (surplus = initial liquidity)"
        );

        pendingFees += createFee;
        uint256 liquidityEth = msg.value - createFee;

        // 1. Deploy Token — mints 1 B tokens to this factory
        tokenAddr = address(new Token(name, symbol, metadataURI));

        // 2-7. Create pool, mint locked LP, return dust — extracted to avoid stack-too-deep
        uint256 tokenId;
        (pool, tokenId) = _deployPool(tokenAddr, liquidityEth, msg.sender);

        // 8. Register
        getPool[tokenAddr]    = pool;
        getCreator[tokenAddr] = msg.sender;
        allTokens.push(tokenAddr);

        emit TokenLaunched(
            msg.sender,
            tokenAddr,
            pool,
            name,
            symbol,
            metadataURI,
            allTokens.length - 1,
            liquidityEth,
            tokenId
        );
    }

    /**
     * @dev Wraps ETH, creates the Uniswap V3 pool, mints a full-range LP to the
     *      dead address, and returns any rounding dust to the creator.
     *      Extracted into its own frame to avoid stack-too-deep in createToken.
     */
    function _deployPool(
        address tokenAddr,
        uint256 liquidityEth,
        address creator
    ) internal returns (address pool, uint256 tokenId) {
        IWETH(weth).deposit{value: liquidityEth}();

        // Determine Uniswap ordering and create pool
        bool t0isToken = tokenAddr < weth;
        pool = _createPool(tokenAddr, liquidityEth, t0isToken);

        // Mint LP and return dust
        tokenId = _mintAndReturn(tokenAddr, liquidityEth, t0isToken, creator);
    }

    function _createPool(
        address tokenAddr,
        uint256 liquidityEth,
        bool t0isToken
    ) internal returns (address pool) {
        (address token0, address token1) = t0isToken
            ? (tokenAddr, weth)
            : (weth,      tokenAddr);
        uint256 amount0 = t0isToken ? TOTAL_SUPPLY : liquidityEth;
        uint256 amount1 = t0isToken ? liquidityEth : TOTAL_SUPPLY;

        pool = INonfungiblePositionManager(positionManager).createAndInitializePoolIfNecessary(
            token0, token1, UNISWAP_FEE, _computeSqrtPriceX96(amount0, amount1)
        );
    }

    function _mintAndReturn(
        address tokenAddr,
        uint256 liquidityEth,
        bool t0isToken,
        address creator
    ) internal returns (uint256 tokenId) {
        (address token0, address token1) = t0isToken
            ? (tokenAddr, weth)
            : (weth,      tokenAddr);
        uint256 amount0 = t0isToken ? TOTAL_SUPPLY : liquidityEth;
        uint256 amount1 = t0isToken ? liquidityEth : TOTAL_SUPPLY;

        IERC20(token0).forceApprove(positionManager, amount0);
        IERC20(token1).forceApprove(positionManager, amount1);

        // Recipient is the LpFeeCollector (if configured) so post-launch swap fees stay
        // collectible; otherwise falls back to the burn address as before.
        address mintRecipient = lpFeeCollector != address(0) ? lpFeeCollector : LOCK_ADDRESS;

        uint256 used0;
        uint256 used1;
        (tokenId, , used0, used1) = INonfungiblePositionManager(positionManager).mint(
            INonfungiblePositionManager.MintParams({
                token0:         token0,
                token1:         token1,
                fee:            UNISWAP_FEE,
                tickLower:      TICK_LOWER,
                tickUpper:      TICK_UPPER,
                amount0Desired: amount0,
                amount1Desired: amount1,
                amount0Min:     0,
                amount1Min:     0,
                recipient:      mintRecipient,
                deadline:       block.timestamp
            })
        );

        // Register the creator in the same transaction as the mint, so there is never
        // a window where the NFT exists without a registered creator.
        if (lpFeeCollector != address(0)) {
            ILpFeeCollector(lpFeeCollector).registerPosition(tokenId, creator);
        }

        // Return any rounding dust to the creator
        if (amount0 > used0) _returnDust(token0, amount0 - used0, creator);
        if (amount1 > used1) _returnDust(token1, amount1 - used1, creator);
    }

    function _returnDust(address token, uint256 dust, address creator) internal {
        if (token == weth) {
            // Guard receive() for the duration of the unwrap so the dust ETH bouncing
            // back into this contract isn't mistaken for an incoming protocol fee.
            _returningDust = true;
            IWETH(weth).withdraw(dust);
            _returningDust = false;
            _sendEth(creator, dust);
        } else {
            IERC20(token).safeTransfer(creator, dust);
        }
    }

    // ─── Fee management ───────────────────────────────────────────────────────

    /**
     * @notice Withdraw all accumulated protocol fees to `to`.
     */
    function withdrawFees(address payable to) external onlyOwner nonReentrant {
        require(to != address(0), "DirectFactory: zero recipient");
        uint256 amount = pendingFees;
        require(amount > 0, "DirectFactory: no fees");
        pendingFees = 0;
        (bool ok,) = to.call{value: amount}("");
        require(ok, "DirectFactory: ETH transfer failed");
        emit FeesWithdrawn(to, amount);
    }

    // ─── View ─────────────────────────────────────────────────────────────────

    function totalTokens() external view returns (uint256) {
        return allTokens.length;
    }

    // ─── Internal helpers ─────────────────────────────────────────────────────

    /**
     * @dev sqrtPriceX96 = sqrt(amount1 / amount0) × 2^96
     *      Computed as sqrt(amount1) × 2^96 / sqrt(amount0) to avoid overflow.
     */
    function _computeSqrtPriceX96(uint256 amount0, uint256 amount1)
        internal
        pure
        returns (uint160)
    {
        require(amount0 > 0, "DirectFactory: zero amount0");
        uint256 sqrtA1 = Math.sqrt(amount1);
        uint256 sqrtA0 = Math.sqrt(amount0);
        uint256 result = (sqrtA1 * (1 << 96)) / sqrtA0;
        require(result <= type(uint160).max, "DirectFactory: sqrtPriceX96 overflow");
        // forge-lint: disable-next-line(unsafe-typecast)
        return uint160(result);
    }

    function _sendEth(address to, uint256 amount) internal {
        if (amount == 0) return;
        (bool ok,) = to.call{value: amount}("");
        require(ok, "DirectFactory: ETH transfer failed");
    }

    /// Required to receive ETH from IWETH.withdraw(). Only counts as a protocol fee
    /// when it's a genuine external transfer — not the WETH unwrap performed by
    /// _returnDust() while returning rounding dust to the creator (see _returningDust).
    receive() external payable {
        if (!_returningDust) {
            pendingFees += msg.value;
        }
    }
}
