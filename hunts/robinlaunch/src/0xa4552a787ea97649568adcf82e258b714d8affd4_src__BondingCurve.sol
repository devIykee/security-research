// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "./interfaces/INonfungiblePositionManager.sol";
import "./interfaces/IUniswapV3Pool.sol";
import "./interfaces/IWETH.sol";

/**
 * @title BondingCurve
 * @notice Virtual-AMM bonding curve (constant-product x·y = k) for fair-launch tokens.
 *
 * Mechanism (mirrors Pump.fun):
 *   • 1,000,000,000 tokens total supply, held here from inception.
 *   • 800,000,000 tokens (80 %) are available for purchase on the curve.
 *   • 200,000,000 tokens (20 %) are reserved for the Uniswap V3 liquidity pool.
 *   • Virtual reserves are calibrated so that selling all 800 M tokens costs ~2.5 ETH net.
 *   • 1 % total fee on every buy and sell, split evenly:
 *       – 0.5 % → protocol (Factory)
 *       – 0.5 % → creator (claimable via claimCreatorFees)
 *   • The creator can redirect their rewards to any address via setCreatorFeeRecipient.
 *   • Graduation triggers when realEthCollected >= 2.5 ETH (or token balance ≤ TOKENS_FOR_LP):
 *       – Wraps all collected ETH → WETH  (pendingCreatorFees excluded)
 *       – Creates/initialises the Uniswap V3 WETH/Token pool at 1 % fee tier
 *       – Mints a full-range LP position with 100 % of WETH + remaining tokens
 *       – Sends the LP NFT to the burn address  →  liquidity locked forever
 *       – Marks itself as graduated  →  buy/sell disabled
 *       – pendingCreatorFees remain claimable after graduation.
 *
 * Virtual-reserve calibration (v6 — 2.5 ETH graduation):
 *   k  = VIRTUAL_ETH_0 × VIRTUAL_TOKEN_0
 *      = 1e18 × 1_120_000_000e18
 *
 *   When 800 M tokens are sold:
 *     newVirtualTokens = 1_120_000_000e18 − 800_000_000e18 = 320_000_000e18
 *     newVirtualEth    = k / newVirtualTokens               = 3.5 ETH (virtual, exact)
 *     realEthCollected = newVirtualEth − VIRTUAL_ETH_0      = 2.5 ETH (net, exact)
 *     gross ETH paid   ≈ 2.525 ETH (before the 1 % fee is deducted)
 *
 *   Price multiple from initial to graduation: ~12.25×
 *     initial price = 1e18 / 1_120_000_000e18 ≈ 8.93e-10 ETH/token
 *     final   price = 3.5e18 / 320_000_000e18 ≈ 1.09e-8  ETH/token
 */
contract BondingCurve is ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ─── Constants ────────────────────────────────────────────────────────────

    uint256 public constant TOTAL_SUPPLY    = 1_000_000_000e18;
    uint256 public constant TOKENS_FOR_SALE =   800_000_000e18;
    uint256 public constant TOKENS_FOR_LP   =   200_000_000e18;

    /// Initial virtual ETH reserve (not real ETH — sets the starting price)
    uint256 public constant VIRTUAL_ETH_0   = 1e18;
    /// Initial virtual token reserve — calibrated so selling 800M tokens costs exactly 2.5 ETH net
    uint256 public constant VIRTUAL_TOKEN_0 = 1_120_000_000e18;

    /// Graduation threshold: net ETH collected on the bonding curve
    uint256 public constant GRADUATION_ETH  = 2.5 ether;
    uint256 public constant FEE_BPS         = 100;   // 1 % total fee
    uint256 public constant FEE_DENOM       = 10_000;

    /// Half of FEE_BPS goes to the creator (0.5 %)
    uint256 public constant CREATOR_FEE_BPS  = 50;
    /// Half of FEE_BPS goes to the protocol/factory (0.5 %)
    uint256 public constant PROTOCOL_FEE_BPS = 50;

    uint24  public constant UNISWAP_FEE     = 10_000; // 1 % fee tier
    int24   public constant TICK_LOWER      = -887_200;
    int24   public constant TICK_UPPER      =  887_200;

    /// LP NFT is sent here — effectively locked forever
    address public constant LOCK_ADDRESS    = 0x000000000000000000000000000000000000dEaD;

    // ─── Immutables ───────────────────────────────────────────────────────────

    IERC20  public immutable token;
    /// Original deployer — the wallet that called Factory.createToken()
    address public immutable creator;
    address public immutable factory;
    INonfungiblePositionManager public immutable positionManager;
    IWETH   public immutable weth;

    // ─── State ────────────────────────────────────────────────────────────────

    /// Current virtual ETH reserve (starts at VIRTUAL_ETH_0, grows with buys)
    uint256 public virtualEthReserve;
    /// Current virtual token reserve (starts at VIRTUAL_TOKEN_0, shrinks with buys)
    uint256 public virtualTokenReserve;

    /// Cumulative real ETH that entered the curve (net of sells, before fees)
    uint256 public realEthCollected;

    bool public graduated;

    /// ETH owed to the creator (0.5 % per trade), held here until claimed.
    uint256 public pendingCreatorFees;

    /// Where creator fees are sent when claimed. Defaults to `creator`.
    /// The creator can change this at any time via setCreatorFeeRecipient().
    address public creatorFeeRecipient;

    // ─── Events ───────────────────────────────────────────────────────────────

    event Buy(
        address indexed buyer,
        uint256 ethIn,
        uint256 tokensOut,
        uint256 virtualEthReserve,
        uint256 virtualTokenReserve
    );
    event Sell(
        address indexed seller,
        uint256 tokensIn,
        uint256 ethOut,
        uint256 virtualEthReserve,
        uint256 virtualTokenReserve
    );
    event Graduated(address indexed pool, uint256 tokenId, uint128 liquidity);

    event CreatorFeeRecipientSet(
        address indexed oldRecipient,
        address indexed newRecipient
    );
    event CreatorFeesClaimed(address indexed recipient, uint256 amount);

    // ─── Constructor ──────────────────────────────────────────────────────────

    constructor(
        address _token,
        address _creator,
        address _positionManager,
        address _weth
    ) {
        token           = IERC20(_token);
        creator         = _creator;
        factory         = msg.sender;
        positionManager = INonfungiblePositionManager(_positionManager);
        weth            = IWETH(_weth);

        // Creator fee recipient defaults to the creator wallet
        creatorFeeRecipient = _creator;

        virtualEthReserve   = VIRTUAL_ETH_0;
        virtualTokenReserve = VIRTUAL_TOKEN_0;
    }

    // ─── Creator fee management ───────────────────────────────────────────────

    /**
     * @notice Change the address that receives creator fee payouts.
     *         Only callable by the original `creator`.
     * @param newRecipient The new payout address (must be non-zero).
     */
    function setCreatorFeeRecipient(address newRecipient) external {
        require(msg.sender == creator, "BondingCurve: not creator");
        require(newRecipient != address(0), "BondingCurve: zero address");
        address old = creatorFeeRecipient;
        creatorFeeRecipient = newRecipient;
        emit CreatorFeeRecipientSet(old, newRecipient);
    }

    /**
     * @notice Claim all accumulated creator fees.
     *         Sends pendingCreatorFees to creatorFeeRecipient.
     *         Callable by anyone — but funds always go to creatorFeeRecipient.
     */
    function claimCreatorFees() external nonReentrant {
        uint256 amount = pendingCreatorFees;
        require(amount > 0, "BondingCurve: no creator fees");
        pendingCreatorFees = 0;
        address recipient = creatorFeeRecipient;
        _sendEth(recipient, amount);
        emit CreatorFeesClaimed(recipient, amount);
    }

    // ─── View helpers ─────────────────────────────────────────────────────────

    /**
     * @notice Spot price in ETH per token (scaled × 1e18).
     */
    function currentPrice() external view returns (uint256) {
        return Math.mulDiv(virtualEthReserve, 1e18, virtualTokenReserve);
    }

    /**
     * @notice How many tokens a buyer would receive for `ethIn` (including fee).
     */
    function getTokensOut(uint256 ethIn) public view returns (uint256 tokensOut) {
        if (ethIn == 0) return 0;
        uint256 ethAfterFee   = ethIn * (FEE_DENOM - FEE_BPS) / FEE_DENOM;
        uint256 newVirtualEth = virtualEthReserve + ethAfterFee;
        uint256 newVirtualTok = Math.mulDiv(virtualEthReserve, virtualTokenReserve, newVirtualEth);
        tokensOut = virtualTokenReserve - newVirtualTok;
    }

    /**
     * @notice How much ETH a seller would receive for `tokensIn` (including fee).
     */
    function getEthOut(uint256 tokensIn) public view returns (uint256 ethOut) {
        if (tokensIn == 0) return 0;
        uint256 newVirtualTok   = virtualTokenReserve + tokensIn;
        uint256 newVirtualEth   = Math.mulDiv(virtualEthReserve, virtualTokenReserve, newVirtualTok);
        uint256 ethBeforeFee    = virtualEthReserve - newVirtualEth;
        ethOut = ethBeforeFee * (FEE_DENOM - FEE_BPS) / FEE_DENOM;
    }

    /**
     * @notice How much ETH is needed (gross, before any refund) to buy exactly `tokensOut`.
     */
    function getEthIn(uint256 tokensOut) public view returns (uint256 ethIn) {
        if (tokensOut == 0) return 0;
        uint256 newVirtualTok   = virtualTokenReserve - tokensOut;
        uint256 newVirtualEth   = Math.mulDiv(virtualEthReserve, virtualTokenReserve, newVirtualTok);
        uint256 ethAfterFee     = newVirtualEth - virtualEthReserve;
        // Gross ETH = ethAfterFee / (1 - fee)
        ethIn = Math.mulDiv(ethAfterFee, FEE_DENOM, FEE_DENOM - FEE_BPS) + 1; // +1 rounding up
    }

    // ─── Buy ──────────────────────────────────────────────────────────────────

    /**
     * @notice Buy tokens with ETH.
     * @param minTokensOut Minimum tokens to receive (slippage guard).
     */
    function buy(uint256 minTokensOut) external payable nonReentrant {
        require(!graduated,     "BondingCurve: graduated");
        require(msg.value > 0,  "BondingCurve: zero ETH");

        uint256 availableTokens = _availableForSale();
        require(availableTokens > 0, "BondingCurve: sold out");

        uint256 ethIn      = msg.value;
        uint256 feeAmount  = ethIn * FEE_BPS / FEE_DENOM;
        uint256 ethNet     = ethIn - feeAmount;

        uint256 newVirtualEth = virtualEthReserve + ethNet;
        uint256 newVirtualTok = Math.mulDiv(virtualEthReserve, virtualTokenReserve, newVirtualEth);
        uint256 tokensOut     = virtualTokenReserve - newVirtualTok;

        // If this purchase would exhaust the sale supply, cap it and refund the remainder
        uint256 ethRefund;
        if (tokensOut > availableTokens) {
            tokensOut = availableTokens;
            newVirtualTok = virtualTokenReserve - tokensOut;
            // Recompute exact ETH needed: newVirtualEth = k / newVirtualTok
            newVirtualEth  = Math.mulDiv(virtualEthReserve, virtualTokenReserve, newVirtualTok);
            uint256 ethNetNeeded  = newVirtualEth - virtualEthReserve;
            uint256 ethGrossNeeded = Math.mulDiv(ethNetNeeded, FEE_DENOM, FEE_DENOM - FEE_BPS) + 1;
            feeAmount  = ethGrossNeeded * FEE_BPS / FEE_DENOM;
            ethRefund  = ethIn > ethGrossNeeded ? ethIn - ethGrossNeeded : 0;
        }

        require(tokensOut >= minTokensOut, "BondingCurve: slippage");

        // Update state
        virtualEthReserve   = newVirtualEth;
        virtualTokenReserve = newVirtualTok;
        realEthCollected   += (ethIn - ethRefund - feeAmount);

        // Split fee: 0.5 % to creator (held here), 0.5 % to protocol (factory)
        uint256 creatorFee   = feeAmount * CREATOR_FEE_BPS / FEE_BPS;
        uint256 protocolFee  = feeAmount - creatorFee;
        pendingCreatorFees  += creatorFee;
        _sendEth(factory, protocolFee);

        // Refund excess ETH
        if (ethRefund > 0) {
            _sendEth(msg.sender, ethRefund);
        }

        // Transfer tokens to buyer
        token.safeTransfer(msg.sender, tokensOut);

        emit Buy(msg.sender, ethIn - ethRefund, tokensOut, virtualEthReserve, virtualTokenReserve);

        // Trigger graduation at 2.5 ETH collected (equivalent to all 800M tokens sold).
        // Both conditions checked as safety net — they are mathematically equivalent
        // with the calibrated curve constants.
        if (realEthCollected >= GRADUATION_ETH || token.balanceOf(address(this)) <= TOKENS_FOR_LP) {
            _graduate();
        }
    }

    // ─── Sell ─────────────────────────────────────────────────────────────────

    /**
     * @notice Sell tokens back for ETH.
     * @param tokensIn  Amount of tokens to sell.
     * @param minEthOut Minimum ETH to receive (slippage guard).
     */
    function sell(uint256 tokensIn, uint256 minEthOut) external nonReentrant {
        require(!graduated,    "BondingCurve: graduated");
        require(tokensIn > 0,  "BondingCurve: zero tokens");

        uint256 newVirtualTok = virtualTokenReserve + tokensIn;
        uint256 newVirtualEth = Math.mulDiv(virtualEthReserve, virtualTokenReserve, newVirtualTok);
        uint256 ethBeforeFee  = virtualEthReserve - newVirtualEth;
        uint256 feeAmount     = ethBeforeFee * FEE_BPS / FEE_DENOM;
        uint256 ethOut        = ethBeforeFee - feeAmount;

        require(ethOut >= minEthOut, "BondingCurve: slippage");
        require(ethOut <= address(this).balance - pendingCreatorFees, "BondingCurve: insufficient ETH");

        // Pull tokens from seller
        token.safeTransferFrom(msg.sender, address(this), tokensIn);

        // Update state
        virtualTokenReserve = newVirtualTok;
        virtualEthReserve   = newVirtualEth;
        if (ethBeforeFee <= realEthCollected) {
            realEthCollected -= ethBeforeFee;
        } else {
            realEthCollected = 0;
        }

        // Split fee: 0.5 % to creator (held here), 0.5 % to protocol (factory)
        uint256 creatorFee   = feeAmount * CREATOR_FEE_BPS / FEE_BPS;
        uint256 protocolFee  = feeAmount - creatorFee;
        pendingCreatorFees  += creatorFee;
        _sendEth(factory, protocolFee);

        // Cap ethOut to the remaining tradeable balance (absorb 1-wei rounding dust)
        uint256 tradeable = address(this).balance - pendingCreatorFees;
        if (ethOut > tradeable) ethOut = tradeable;

        // Pay seller
        _sendEth(msg.sender, ethOut);

        emit Sell(msg.sender, tokensIn, ethOut, virtualEthReserve, virtualTokenReserve);
    }

    // ─── Graduation ───────────────────────────────────────────────────────────

    /**
     * @dev Wraps all *tradeable* ETH (excluding pendingCreatorFees), creates the
     *      Uniswap V3 pool, mints a full-range position, and burns the LP NFT.
     *      Creator fees accumulated so far remain claimable after graduation.
     */
    function _graduate() internal {
        graduated = true;

        // Exclude creator fees that haven't been claimed yet.
        uint256 ethBalance   = address(this).balance - pendingCreatorFees;
        uint256 tokenBalance = token.balanceOf(address(this));

        require(ethBalance > 0 && tokenBalance > 0, "BondingCurve: nothing to graduate");

        // 1. Wrap ETH → WETH
        weth.deposit{value: ethBalance}();

        address tokenAddr = address(token);
        address wethAddr  = address(weth);

        // 2. Determine Uniswap token ordering (token0 < token1 by address)
        (address token0, address token1, uint256 amount0, uint256 amount1) =
            tokenAddr < wethAddr
                ? (tokenAddr, wethAddr, tokenBalance, ethBalance)
                : (wethAddr, tokenAddr, ethBalance,   tokenBalance);

        // 3. Compute initial sqrtPriceX96 = sqrt(amount1 / amount0) × 2^96
        uint160 sqrtPriceX96 = _computeSqrtPriceX96(amount0, amount1);

        // 4. Create pool (or reuse existing) and set initial price
        address pool = positionManager.createAndInitializePoolIfNecessary(
            token0,
            token1,
            UNISWAP_FEE,
            sqrtPriceX96
        );

        // 5. Approve position manager for both tokens
        IERC20(token0).forceApprove(address(positionManager), amount0);
        IERC20(token1).forceApprove(address(positionManager), amount1);

        // 6. Mint full-range LP position — recipient is the burn address
        (uint256 tokenId, uint128 liquidity,,) = positionManager.mint(
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
                recipient:      LOCK_ADDRESS,
                deadline:       block.timestamp
            })
        );

        emit Graduated(pool, tokenId, liquidity);
    }

    /**
     * @dev sqrtPriceX96 = sqrt(amount1 / amount0) × 2^96
     *      Computed as: sqrt(amount1) × 2^96 / sqrt(amount0)
     *      Both operands have 18 decimals so integer sqrt gives enough precision.
     */
    function _computeSqrtPriceX96(uint256 amount0, uint256 amount1)
        internal
        pure
        returns (uint160)
    {
        require(amount0 > 0, "BondingCurve: zero amount0");
        uint256 sqrtA1 = Math.sqrt(amount1);
        uint256 sqrtA0 = Math.sqrt(amount0);
        // sqrtA1 ≤ sqrt(200_000_000e18) ≈ 1.41e13, 2^96 ≈ 7.92e28 → product ≈ 1.12e42 < 2^256
        uint256 result = (sqrtA1 * (1 << 96)) / sqrtA0;
        // sqrtPriceX96 must fit in uint160 (Uniswap V3 invariant)
        require(result <= type(uint160).max, "BondingCurve: sqrtPriceX96 overflow");
        // forge-lint: disable-next-line(unsafe-typecast)
        return uint160(result);
    }

    // ─── Internal helpers ─────────────────────────────────────────────────────

    function _availableForSale() internal view returns (uint256) {
        uint256 bal = token.balanceOf(address(this));
        return bal > TOKENS_FOR_LP ? bal - TOKENS_FOR_LP : 0;
    }

    function _sendEth(address to, uint256 amount) internal {
        if (amount == 0) return;
        (bool ok,) = to.call{value: amount}("");
        require(ok, "BondingCurve: ETH transfer failed");
    }

    receive() external payable {}
}
