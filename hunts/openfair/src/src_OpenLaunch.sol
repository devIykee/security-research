// SPDX-License-Identifier: MIT
// Launched via openfair.app - create your own token on Robinhood Chain: https://openfair.app
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {OpenFairToken} from "./OpenFairToken.sol";

/// @dev Uniswap V3 NonfungiblePositionManager — only the functions graduation needs.
interface INonfungiblePositionManager {
    struct MintParams {
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        address recipient;
        uint256 deadline;
    }

    function createAndInitializePoolIfNecessary(address token0, address token1, uint24 fee, uint160 sqrtPriceX96)
        external
        payable
        returns (address pool);

    function mint(MintParams calldata params)
        external
        payable
        returns (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1);

    function safeTransferFrom(address from, address to, uint256 tokenId) external;
}

/// @dev Uniswap V3 factory — used to validate the fee tier and read its tick spacing.
interface IUniswapV3Factory {
    function feeAmountTickSpacing(uint24 fee) external view returns (int24);
}

/// @dev Pool state getter used by single-sided direct listings.
interface IUniswapV3PoolState {
    function slot0()
        external
        view
        returns (
            uint160 sqrtPriceX96,
            int24 tick,
            uint16 observationIndex,
            uint16 observationCardinality,
            uint16 observationCardinalityNext,
            uint8 feeProtocol,
            bool unlocked
        );
}

/// @dev WETH9: wrap/unwrap.
interface IWETH9 is IERC20 {
    function deposit() external payable;
    function withdraw(uint256 amount) external;
}

/// @dev Harvester getters used only for a constructor sanity check.
interface IHarvester {
    function token() external view returns (address);
    function weth() external view returns (address);
}

/**
 * @title OpenLaunch
 * @notice Configurable bonding-curve fair launch for openfair.app. Every launch
 * is its own immutable, fully-deployed contract: no proxy, no delegatecall, no
 * upgrade, no admin over funds.
 *
 * Curve phase: anyone `buy()`s tokens with ETH along the configured price curve
 * (classic constant-product / linear / exponential) and may `sell()` them back
 * (if the creator enabled sells). The trade fee (set by the creator, 0 allowed)
 * is split between the creator and the platform by an immutable ratio; if a
 * referrer is set, half of the platform share accrues to the referrer. All fee
 * shares use pull-payments (`claimFees`) so no recipient can block trading.
 *
 * Graduation: once the whole sale allocation is sold out, permissionless
 * `graduate()` deploys a Uniswap V3 pool with the collected ETH and a token
 * amount computed so the pool's starting price equals the curve's final price
 * (no arbitrage step), locks the LP NFT forever in the harvester, opens free
 * transfers on the token, and burns every leftover token.
 *
 * Anti-snipe (both layers optional, configured at creation, time-based so the
 * behaviour is identical on any chain regardless of block time):
 *  - Layer 1: a global ramp — the total amount purchasable from t=0 grows at
 *    `globalRampPerSec` tokens/sec.
 *  - Layer 2: a per-wallet cumulative cap — `walletCapFloor` at t=0 growing at
 *    `walletCapPerSec` tokens/sec.
 *
 * SECURITY NOTE: a bonding curve that custodies crowd ETH is a high-risk class
 * of contract. Fork-tested against the live Uniswap V3 deployment; a
 * professional audit is required before promoting this to real-money mainnet.
 */
contract OpenLaunch is ReentrancyGuard {
    /// @notice Where this contract comes from (on-chain provenance).
    string public constant OPENFAIR = "Launched via openfair.app - create your own token on Robinhood Chain: https://openfair.app";

    using SafeERC20 for IERC20;

    // ----------------------------- Errors -----------------------------
    error NotFactory();
    error AlreadyOpened();
    error NotOpened();
    error NotStarted();
    error NotFunded();
    error TradingClosed();
    error SellsDisabled();
    error NotReadyToGraduate();
    error AlreadyGraduated();
    error ZeroValue();
    error Slippage();
    error ExceedsWalletCap(uint256 attempted, uint256 cap);
    error ExceedsGlobalRamp(uint256 attempted, uint256 available);
    error EthSendFailed();
    error ZeroAddress();
    error HarvesterMismatch();
    error BadConfig();
    error NothingToClaim();
    error TooEarly();

    // ----------------------------- Events -----------------------------
    event Opened(uint256 startTime);
    event Buy(address indexed buyer, uint256 ethIn, uint256 fee, uint256 tokensOut);
    event Sell(address indexed seller, uint256 tokensIn, uint256 ethOut, uint256 fee);
    event FeesAccrued(address indexed creator, uint256 creatorFee, uint256 platformFee, uint256 referrerFee);
    event FeesClaimed(address indexed recipient, uint256 amount);
    event StaleReferralSwept(address indexed referrer, uint256 amount);
    event ReadyToGraduate(uint256 ethCollected, uint256 tokensSold);
    event GraduatedToPool(address indexed pool, uint256 tokenId, uint256 ethIntoPool, uint256 tokensIntoPool);
    event RefundClaimed(address indexed buyer, uint256 tokensIn, uint256 ethOut);
    event UnclaimedSwept(uint256 ethToTreasury);

    // ----------------------------- Types ------------------------------

    /// @notice Price curve family. EXPONENTIAL is a power curve (price grows
    /// with the square of tokens sold): slow start, steep finish.
    enum CurveType {
        CLASSIC, // constant product with virtual reserves (pump.fun-style)
        LINEAR, // price grows linearly with tokens sold
        EXPONENTIAL // price grows quadratically with tokens sold
    }

    /// @notice Full launch configuration, fixed forever at deployment.
    struct Params {
        // wiring
        address factory; // the orchestrator allowed to call open()/buyFor() once
        address token;
        address weth;
        address positionManager;
        address uniswapV3Factory;
        address harvester;
        // parties
        address creator;
        address feeRecipient; // creator's fee share accrues here
        address platformTreasury; // platform's fee share accrues here
        address referrer; // address(0) = no referrer
        // curve
        uint8 curveType;
        uint256 saleSupply; // tokens sold on the curve (18 decimals)
        uint256 targetEth; // ETH to collect over the whole sale (net of fees)
        uint256 priceMultiple; // final price / start price, integer >= 2
        // fees
        uint16 buyFeeBps; // 0..1000 (10% max), 0 allowed
        uint16 sellFeeBps; // 0..1000; higher sell fees make curve-phase snipe-flips unprofitable
        uint16 platformShareBps; // share of the trade fee that goes to the platform, 0..10000
        // trading rules
        bool sellsEnabled;
        uint64 startTime; // 0 = trading starts immediately at open()
        // anti-snipe (0 disables the respective layer)
        uint256 walletCapFloor; // per-wallet cumulative cap at t=0, token-wei
        uint256 walletCapPerSec; // cap growth, token-wei / sec
        uint256 globalRampPerSec; // globally purchasable amount growth, token-wei / sec
        // pool
        uint24 poolFeeTier;
        // team
        uint256 teamAllocation; // tokens locked in the team vesting safe (0 = none)
    }

    // --------------------------- Constants ----------------------------
    uint256 private constant BPS_DENOM = 10_000;
    uint256 private constant ONE = 1e18;
    uint256 public constant MAX_TRADE_FEE_BPS = 1_000; // 10% per side (buy / sell)
    /// @notice Fair-launch badge thresholds (see docs §П7): the whole sale must
    /// ramp open within 24h and a single wallet must be capped at <= 0.1% of
    /// total supply during the first minute.
    uint256 public constant FAIR_RAMP_WINDOW = 24 hours;
    uint256 public constant FAIR_WALLET_CAP_WINDOW = 60 seconds;
    uint256 public constant FAIR_WALLET_CAP_PPM = 1_000; // 0.1% = 1000 ppm
    /// @notice The badge also requires leaving the platform at least this share
    /// of the trade fee — fairness includes keeping the platform alive.
    uint16 public constant FAIR_MIN_PLATFORM_SHARE_BPS = 1_000; // 10%
    /// @notice Escape hatch for sells-disabled launches: if the launch has not
    /// graduated ESCAPE_DELAY after trading started, buyers can claim fee-free
    /// refunds for ESCAPE_CLAIM_WINDOW; ETH left unclaimed after the window
    /// goes to the project treasury (feeRecipient).
    uint64 public constant ESCAPE_DELAY = 14 days;
    uint64 public constant ESCAPE_CLAIM_WINDOW = 30 days;

    /// @notice Referral rewards left unclaimed this long may be swept to the
    /// platform treasury by anyone (keeps abandoned balances working).
    uint64 public constant REFERRAL_CLAIM_WINDOW = 90 days;

    // --------------------------- Immutables ---------------------------
    address public immutable factory;
    OpenFairToken public immutable token;
    IWETH9 public immutable weth;
    INonfungiblePositionManager public immutable positionManager;
    address public immutable harvester;

    address public immutable creator;
    address public immutable feeRecipient;
    address public immutable platformTreasury;
    address public immutable referrer;

    CurveType public immutable curveType;
    uint256 public immutable saleSupply;
    uint256 public immutable targetEth;
    uint256 public immutable priceMultiple;

    uint16 public immutable buyFeeBps;
    uint16 public immutable sellFeeBps;
    uint16 public immutable platformShareBps;

    bool public immutable sellsEnabled;

    uint256 public immutable walletCapFloor;
    uint256 public immutable walletCapPerSec;
    uint256 public immutable globalRampPerSec;

    uint24 public immutable poolFeeTier;
    int24 public immutable tickLower;
    int24 public immutable tickUpper;

    uint256 public immutable teamAllocation;

    // Curve constants, derived once in the constructor.
    // CLASSIC: virtual reserves x0 (ETH) and y0 (tokens), invariant K = x0*y0.
    uint256 public immutable virtualEth;
    uint256 public immutable virtualToken;
    uint256 private immutable curveK;
    // LINEAR / EXPONENTIAL: start and final price, in wei per whole token (1e18 units).
    uint256 public immutable startPrice;
    uint256 public immutable finalPrice;

    /// @notice Exact ETH the whole sale collects (net of fees). Equals targetEth
    /// up to integer rounding of the curve constants.
    uint256 public immutable saleProceeds;
    /// @notice Tokens paired with `saleProceeds` in the Uniswap pool so the
    /// pool's starting price equals the curve's final price.
    uint256 public immutable graduationTokens;

    // ----------------------------- State ------------------------------
    uint256 public tokensSold;
    /// @notice Net ETH held for the curve (excludes accrued, unclaimed fees).
    uint256 public ethCollected;
    uint256 public launchStartTime; // trading start (anti-snipe t=0)
    /// @notice Sells-disabled launches only: refunds open at this time unless
    /// graduated (0 when sells are enabled). Set once in open().
    uint256 public escapeStart;
    bool public opened;
    bool public readyToGraduate;
    bool public graduated;
    /// @notice True after the post-escape sweep; the launch is closed for good.
    bool public swept;

    /// @notice ETH the creator paid into the dev-buy at creation (0 = honest launch).
    uint256 public devBuyEth;

    /// @notice Cumulative tokens bought per address (anti-snipe layer 2).
    mapping(address => uint256) public bought;

    /// @notice Pull-payment fee balances: feeRecipient / platformTreasury / referrer.
    mapping(address => uint256) public feesAccrued;
    /// @notice Lifetime referral earnings (for transparency pages).
    uint256 public referralAccruedTotal;
    /// @dev Timestamp of the oldest unclaimed referral accrual (0 = none).
    uint64 public referrerUnclaimedSince;

    // --------------------------- Constructor --------------------------

    constructor(Params memory p) {
        if (
            p.factory == address(0) || p.token == address(0) || p.weth == address(0)
                || p.positionManager == address(0) || p.uniswapV3Factory == address(0) || p.harvester == address(0)
                || p.creator == address(0) || p.feeRecipient == address(0) || p.platformTreasury == address(0)
        ) revert ZeroAddress();
        // Sanity: the harvester must be wired to exactly this token + WETH, else
        // the LP NFT would be rejected at graduation.
        if (IHarvester(p.harvester).token() != p.token || IHarvester(p.harvester).weth() != p.weth) {
            revert HarvesterMismatch();
        }
        if (p.buyFeeBps > MAX_TRADE_FEE_BPS || p.sellFeeBps > MAX_TRADE_FEE_BPS || p.platformShareBps > BPS_DENOM) {
            revert BadConfig();
        }
        if (p.saleSupply == 0 || p.targetEth == 0) revert BadConfig();
        if (p.priceMultiple < 2 || p.priceMultiple > 1_000_000) revert BadConfig();
        if (p.curveType > uint8(CurveType.EXPONENTIAL)) revert BadConfig();
        if (p.referrer == p.creator || p.referrer == p.feeRecipient) revert BadConfig();

        // Fee tier must exist on this Uniswap deployment; full-range ticks are
        // aligned to its tick spacing.
        int24 spacing = IUniswapV3Factory(p.uniswapV3Factory).feeAmountTickSpacing(p.poolFeeTier);
        if (spacing <= 0) revert BadConfig();
        int24 maxTick = (887_272 / spacing) * spacing;
        tickLower = -maxTick;
        tickUpper = maxTick;

        factory = p.factory;
        token = OpenFairToken(p.token);
        weth = IWETH9(p.weth);
        positionManager = INonfungiblePositionManager(p.positionManager);
        harvester = p.harvester;
        creator = p.creator;
        feeRecipient = p.feeRecipient;
        platformTreasury = p.platformTreasury;
        referrer = p.referrer;
        curveType = CurveType(p.curveType);
        saleSupply = p.saleSupply;
        targetEth = p.targetEth;
        priceMultiple = p.priceMultiple;
        buyFeeBps = p.buyFeeBps;
        sellFeeBps = p.sellFeeBps;
        platformShareBps = p.platformShareBps;
        sellsEnabled = p.sellsEnabled;
        walletCapFloor = p.walletCapFloor;
        walletCapPerSec = p.walletCapPerSec;
        globalRampPerSec = p.globalRampPerSec;
        poolFeeTier = p.poolFeeTier;
        teamAllocation = p.teamAllocation;

        // ---- Derive curve constants ----
        // For every family the constants are chosen so that selling the whole
        // saleSupply collects (up to integer rounding) targetEth, and the final
        // marginal price equals the Uniswap pool's starting price.
        uint256 vEth;
        uint256 vToken;
        uint256 k;
        uint256 p0;
        uint256 pf;
        if (CurveType(p.curveType) == CurveType.CLASSIC) {
            // Constant product with virtual reserves. priceMultiple M fixes the
            // virtual token reserve: y0 = S * sqrt(M) / (sqrt(M) - 1),
            // x0 = E * (y0 - S) / S. Then x0*y0 = (x0+E)(y0-S) holds and the
            // price rises exactly M-fold across the sale.
            uint256 sqrtM = Math.sqrt(p.priceMultiple * ONE * ONE); // sqrt(M) * 1e18
            vToken = Math.mulDiv(p.saleSupply, sqrtM, sqrtM - ONE);
            if (vToken <= p.saleSupply) revert BadConfig();
            vEth = Math.mulDiv(p.targetEth, vToken - p.saleSupply, p.saleSupply);
            if (vEth == 0) revert BadConfig();
            k = vEth * vToken; // reverts on overflow (0.8 checked math)
            // Informational (UI/indexer); the classic math uses k/y0/x0 directly.
            p0 = Math.mulDiv(k, ONE, vToken * vToken);
            pf = Math.mulDiv(k, ONE, (vToken - p.saleSupply) * (vToken - p.saleSupply));
        } else if (CurveType(p.curveType) == CurveType.LINEAR) {
            // price(s) = p0 + (pf - p0) * s / S;  E(S) = S * (p0 + pf) / 2e18
            // With pf = M * p0:  pf = 2e18 * E * M / (S * (M + 1)).
            pf = Math.mulDiv(2 * p.targetEth, p.priceMultiple * ONE, p.saleSupply * (p.priceMultiple + 1));
            p0 = pf / p.priceMultiple;
            if (p0 == 0) revert BadConfig();
        } else {
            // price(s) = p0 + (pf - p0) * s^2 / S^2;  E(S) = S * (2*p0 + pf) / 3e18
            // With pf = M * p0:  pf = 3e18 * E * M / (S * (M + 2)).
            pf = Math.mulDiv(3 * p.targetEth, p.priceMultiple * ONE, p.saleSupply * (p.priceMultiple + 2));
            p0 = pf / p.priceMultiple;
            if (p0 == 0) revert BadConfig();
        }
        virtualEth = vEth;
        virtualToken = vToken;
        curveK = k;
        startPrice = p0;
        finalPrice = pf;

        // Exact proceeds of a full sale and the arb-free pool token amount.
        uint256 proceeds = _ethBetween(CurveType(p.curveType), k, vToken, vEth, p0, pf, p.saleSupply, 0, p.saleSupply);
        if (proceeds == 0) revert BadConfig();
        uint256 gradTokens;
        if (CurveType(p.curveType) == CurveType.CLASSIC) {
            gradTokens = Math.mulDiv(p.saleSupply, vToken - p.saleSupply, vToken);
        } else {
            gradTokens = Math.mulDiv(proceeds, ONE, pf);
        }
        if (gradTokens == 0) revert BadConfig();
        saleProceeds = proceeds;
        graduationTokens = gradTokens;
    }

    // ------------------------- Launch control -------------------------

    /**
     * @notice Opens the curve. Callable once by the factory, after the contract
     * has been funded with the sale + graduation supply. `startTime_` in the
     * future lists the token as "upcoming" — buys revert until it passes.
     */
    function open(uint64 startTime_) external {
        if (msg.sender != factory) revert NotFactory();
        if (opened) revert AlreadyOpened();
        if (token.balanceOf(address(this)) < saleSupply + graduationTokens) revert NotFunded();
        opened = true;
        launchStartTime = startTime_ == 0 ? block.timestamp : uint256(startTime_);
        if (launchStartTime < block.timestamp) launchStartTime = block.timestamp;
        if (!sellsEnabled) escapeStart = launchStartTime + ESCAPE_DELAY;
        emit Opened(launchStartTime);
    }

    // ----------------------------- Views ------------------------------

    /// @notice Current per-wallet cumulative buy cap (anti-snipe layer 2).
    function currentWalletCap() public view returns (uint256) {
        if (!opened) return 0;
        if (walletCapFloor == 0 && walletCapPerSec == 0) return saleSupply; // layer disabled
        uint256 elapsed = block.timestamp > launchStartTime ? block.timestamp - launchStartTime : 0;
        uint256 cap = walletCapFloor + elapsed * walletCapPerSec;
        return cap > saleSupply ? saleSupply : cap;
    }

    /// @notice Globally purchasable amount so far (anti-snipe layer 1).
    function currentGlobalAvailable() public view returns (uint256) {
        if (!opened) return 0;
        if (globalRampPerSec == 0) return saleSupply; // layer disabled
        uint256 elapsed = block.timestamp > launchStartTime ? block.timestamp - launchStartTime : 0;
        uint256 avail = elapsed * globalRampPerSec;
        return avail > saleSupply ? saleSupply : avail;
    }

    /// @notice Marginal price right now, in wei per whole token.
    function currentPrice() public view returns (uint256) {
        return _priceAt(tokensSold);
    }

    /// @notice Quote tokens out for a gross ETH input (ignores anti-snipe caps).
    function quoteBuy(uint256 ethAmount) external view returns (uint256 tokensOut) {
        uint256 ethIn = ethAmount - (ethAmount * buyFeeBps / BPS_DENOM);
        tokensOut = _tokensForEth(tokensSold, ethIn);
        uint256 remaining = saleSupply - tokensSold;
        if (tokensOut > remaining) tokensOut = remaining;
    }

    /// @notice Quote gross ETH out for selling `tokensIn` back to the curve.
    function quoteSell(uint256 tokensIn) external view returns (uint256 ethOut) {
        if (tokensIn > tokensSold) return 0;
        uint256 gross = _ethBetween(tokensSold - tokensIn, tokensSold);
        ethOut = gross - (gross * sellFeeBps / BPS_DENOM);
    }

    /**
     * @notice True when this launch qualifies for the machine-readable
     * "Fair Launch" badge: no dev-buy, no team allocation, and both anti-snipe
     * layers configured at least as strict as the platform thresholds.
     */
    function isFairLaunch() public view returns (bool) {
        if (devBuyEth != 0 || teamAllocation != 0) return false;
        if (platformShareBps < FAIR_MIN_PLATFORM_SHARE_BPS) return false;
        if (globalRampPerSec == 0 || globalRampPerSec * FAIR_RAMP_WINDOW < saleSupply) return false;
        if (walletCapFloor == 0 && walletCapPerSec == 0) return false;
        uint256 capAtWindow = walletCapFloor + FAIR_WALLET_CAP_WINDOW * walletCapPerSec;
        return capAtWindow * FAIR_WALLET_CAP_PPM <= token.totalSupply();
    }

    // ------------------------------ Buy -------------------------------

    /// @notice Buy tokens from the curve with ETH.
    function buy(uint256 minTokensOut) external payable nonReentrant {
        _buy(msg.sender, minTokensOut, false);
    }

    /**
     * @notice Factory-only: executes the creator's disclosed dev-buy inside
     * createLaunch. Runs before startTime and outside the anti-snipe caps —
     * both layers start at zero in the creation block, so a capped dev-buy
     * could never execute. The trade-off is disclosed by design: devBuyEth is
     * public on-chain and any dev-buy forfeits the "Fair Launch" badge.
     */
    function buyFor(address recipient, uint256 minTokensOut) external payable nonReentrant {
        if (msg.sender != factory) revert NotFactory();
        devBuyEth += msg.value;
        _buy(recipient, minTokensOut, true);
    }

    function _buy(address buyer, uint256 minTokensOut, bool isDevBuy) internal {
        if (!opened) revert NotOpened();
        if (!isDevBuy && block.timestamp < launchStartTime) revert NotStarted();
        if (readyToGraduate || graduated) revert TradingClosed();
        // Sells-disabled launch that missed its graduation deadline: the launch
        // has failed, no new money may enter — only refunds.
        if (escapeStart != 0 && block.timestamp >= escapeStart) revert TradingClosed();
        if (msg.value == 0) revert ZeroValue();

        uint256 fee = msg.value * buyFeeBps / BPS_DENOM;
        uint256 ethIn = msg.value - fee;
        uint256 tokensOut = _tokensForEth(tokensSold, ethIn);
        uint256 remaining = saleSupply - tokensSold;
        uint256 refundWei = 0;

        if (tokensOut >= remaining) {
            // Final buy: cap to the tokens left, charge the exact ETH the curve
            // still needs, refund the overpayment, recompute the fee on the
            // reduced gross, and mark the sale ready to graduate.
            tokensOut = remaining;
            uint256 ethNeeded = _ethBetween(tokensSold, saleSupply);
            uint256 grossNeeded =
                buyFeeBps == 0 ? ethNeeded : Math.ceilDiv(ethNeeded * BPS_DENOM, BPS_DENOM - buyFeeBps);
            if (grossNeeded > msg.value) grossNeeded = msg.value; // guard vs rounding
            refundWei = msg.value - grossNeeded;
            fee = grossNeeded - ethNeeded;
            ethIn = ethNeeded;
            readyToGraduate = true;
        }
        if (tokensOut == 0) revert ZeroValue();
        if (tokensOut < minTokensOut) revert Slippage();

        uint256 newBought = bought[buyer] + tokensOut;
        if (!isDevBuy) {
            // Anti-snipe layer 1: global ramp.
            uint256 avail = currentGlobalAvailable();
            if (tokensSold + tokensOut > avail) revert ExceedsGlobalRamp(tokensSold + tokensOut, avail);
            // Anti-snipe layer 2: per-wallet cumulative cap.
            uint256 cap = currentWalletCap();
            if (newBought > cap) revert ExceedsWalletCap(newBought, cap);
        }

        // Effects
        tokensSold += tokensOut;
        ethCollected += ethIn;
        bought[buyer] = newBought;
        _accrueFees(fee);

        // Interactions
        if (refundWei > 0) _sendEth(buyer, refundWei);
        IERC20(address(token)).safeTransfer(buyer, tokensOut);

        emit Buy(buyer, ethIn, fee, tokensOut);
        if (readyToGraduate) emit ReadyToGraduate(ethCollected, tokensSold);
    }

    // ------------------------------ Sell ------------------------------

    /**
     * @notice Sell tokens back to the curve for ETH (if the creator enabled
     * sells). Caller must have approved this contract for `tokensIn`.
     */
    function sell(uint256 tokensIn, uint256 minEthOut) external nonReentrant {
        if (!opened) revert NotOpened();
        if (!sellsEnabled) revert SellsDisabled();
        if (readyToGraduate || graduated) revert TradingClosed();
        if (tokensIn == 0 || tokensIn > tokensSold) revert ZeroValue();

        // Pull tokens in first (the token contract allows transfers to the
        // launchpad during the curve phase).
        IERC20(address(token)).safeTransferFrom(msg.sender, address(this), tokensIn);

        uint256 ethOutGross = _ethBetween(tokensSold - tokensIn, tokensSold);
        if (ethOutGross > ethCollected) ethOutGross = ethCollected; // rounding guard
        uint256 fee = ethOutGross * sellFeeBps / BPS_DENOM;
        uint256 ethOut = ethOutGross - fee;
        if (ethOut < minEthOut) revert Slippage();

        // Effects
        tokensSold -= tokensIn;
        ethCollected -= ethOutGross;
        // Reduce the seller's cumulative-bought tally so the anti-snipe cap is
        // not permanently consumed by round-trips.
        uint256 prev = bought[msg.sender];
        bought[msg.sender] = prev > tokensIn ? prev - tokensIn : 0;
        _accrueFees(fee);

        // Interactions
        _sendEth(msg.sender, ethOut);

        emit Sell(msg.sender, tokensIn, ethOut, fee);
    }

    // --------------------------- Escape hatch --------------------------

    /**
     * @notice Sells-disabled launches only: if the launch has not graduated
     * within ESCAPE_DELAY of trading start, buyers can return tokens and get
     * their curve ETH back fee-free during ESCAPE_CLAIM_WINDOW.
     */
    function refund(uint256 tokensIn, uint256 minEthOut) external nonReentrant {
        if (!opened) revert NotOpened();
        if (sellsEnabled) revert SellsDisabled(); // sells-on launches can always sell()
        if (readyToGraduate || graduated || swept) revert TradingClosed();
        if (block.timestamp < escapeStart || block.timestamp >= escapeStart + ESCAPE_CLAIM_WINDOW) {
            revert TradingClosed();
        }
        if (tokensIn == 0 || tokensIn > tokensSold) revert ZeroValue();

        IERC20(address(token)).safeTransferFrom(msg.sender, address(this), tokensIn);

        uint256 ethOut = _ethBetween(tokensSold - tokensIn, tokensSold);
        if (ethOut > ethCollected) ethOut = ethCollected; // rounding guard
        if (ethOut < minEthOut) revert Slippage();

        tokensSold -= tokensIn;
        ethCollected -= ethOut;

        _sendEth(msg.sender, ethOut);
        emit RefundClaimed(msg.sender, tokensIn, ethOut);
    }

    /**
     * @notice Permissionless: after the refund window of a failed sells-disabled
     * launch closes, the unclaimed curve ETH accrues to the openfair platform
     * treasury (pull-payment) and the launch closes for good.
     */
    function sweepUnclaimed() external nonReentrant {
        if (!opened || sellsEnabled) revert SellsDisabled();
        if (readyToGraduate || graduated || swept) revert TradingClosed();
        if (block.timestamp < escapeStart + ESCAPE_CLAIM_WINDOW) revert TradingClosed();
        swept = true;
        uint256 amount = ethCollected;
        ethCollected = 0;
        if (amount > 0) feesAccrued[platformTreasury] += amount;
        // Remaining curve tokens are dead weight — destroy them.
        uint256 bal = IERC20(address(token)).balanceOf(address(this));
        if (bal > 0) ERC20Burnable(address(token)).burn(bal);
        emit UnclaimedSwept(amount);
    }

    // ------------------------------ Fees -------------------------------

    /// @dev Split a trade fee between creator / platform / referrer (pull-pattern).
    function _accrueFees(uint256 fee) internal {
        if (fee == 0) return;
        uint256 platformFee = fee * platformShareBps / BPS_DENOM;
        uint256 referrerFee = 0;
        if (referrer != address(0) && platformFee > 0) {
            referrerFee = platformFee / 2;
            platformFee -= referrerFee;
            feesAccrued[referrer] += referrerFee;
            referralAccruedTotal += referrerFee;
            if (referrerUnclaimedSince == 0) referrerUnclaimedSince = uint64(block.timestamp);
        }
        uint256 creatorFee = fee - platformFee - referrerFee;
        if (platformFee > 0) feesAccrued[platformTreasury] += platformFee;
        if (creatorFee > 0) feesAccrued[feeRecipient] += creatorFee;
        emit FeesAccrued(creator, creatorFee, platformFee, referrerFee);
    }

    /**
     * @notice Permissionless pull-payment: sends the accrued fee balance of
     * `account` to `account`. Funds can only ever move to the fixed
     * feeRecipient / platformTreasury / referrer addresses.
     */
    function claimFees(address account) external nonReentrant {
        uint256 amount = feesAccrued[account];
        if (amount == 0) revert NothingToClaim();
        feesAccrued[account] = 0;
        if (account == referrer) referrerUnclaimedSince = 0;
        _sendEth(account, amount);
        emit FeesClaimed(account, amount);
    }

    /**
     * @notice Permissionless. Referral rewards untouched for
     * REFERRAL_CLAIM_WINDOW move to the platform treasury (still
     * pull-claimed by it). The timer starts at the first unclaimed accrual
     * and resets on every referrer claim.
     */
    function sweepStaleReferral() external nonReentrant {
        uint256 amount = feesAccrued[referrer];
        if (referrer == address(0) || amount == 0) revert NothingToClaim();
        if (referrerUnclaimedSince == 0 || block.timestamp <= referrerUnclaimedSince + REFERRAL_CLAIM_WINDOW) {
            revert TooEarly();
        }
        feesAccrued[referrer] = 0;
        referrerUnclaimedSince = 0;
        feesAccrued[platformTreasury] += amount;
        emit StaleReferralSwept(referrer, amount);
    }

    // --------------------------- Graduation ---------------------------

    /**
     * @notice Permissionless. Once the curve is sold out, deploys a Uniswap V3
     * pool with the collected ETH + the reserved token amount, locks the LP in
     * the harvester forever, opens free token trading, and burns leftovers.
     */
    function graduate() external nonReentrant {
        if (!readyToGraduate) revert NotReadyToGraduate();
        if (graduated) revert AlreadyGraduated();
        graduated = true;

        uint256 ethForPool = ethCollected;
        ethCollected = 0;
        weth.deposit{value: ethForPool}();

        // Reserve graduationTokens for the pool; burn the rest of the balance.
        uint256 bal = IERC20(address(token)).balanceOf(address(this));
        uint256 burnAmount = bal - graduationTokens;
        if (burnAmount > 0) ERC20Burnable(address(token)).burn(burnAmount);

        // Sort tokens as Uniswap requires (token0 < token1) and match amounts.
        address tk = address(token);
        address we = address(weth);
        (address token0, address token1) = tk < we ? (tk, we) : (we, tk);
        (uint256 amount0, uint256 amount1) =
            tk < we ? (graduationTokens, ethForPool) : (ethForPool, graduationTokens);

        uint160 sqrtPriceX96 = _sqrtPriceX96(amount0, amount1);
        address pool = positionManager.createAndInitializePoolIfNecessary(token0, token1, poolFeeTier, sqrtPriceX96);

        IERC20(token0).forceApprove(address(positionManager), amount0);
        IERC20(token1).forceApprove(address(positionManager), amount1);

        (uint256 tokenId,, uint256 used0, uint256 used1) = positionManager.mint(
            INonfungiblePositionManager.MintParams({
                token0: token0,
                token1: token1,
                fee: poolFeeTier,
                tickLower: tickLower,
                tickUpper: tickUpper,
                amount0Desired: amount0,
                amount1Desired: amount1,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(this),
                deadline: block.timestamp
            })
        );

        // Open free trading, then lock the LP position in the harvester forever.
        token.graduate();
        positionManager.safeTransferFrom(address(this), harvester, tokenId);

        // Sweep dust: burn leftover tokens (now transferable); leftover WETH is
        // unwrapped and accrued to the creator's fee balance (pull-payment).
        _sweepDust(amount0, amount1, used0, used1);

        emit GraduatedToPool(pool, tokenId, ethForPool, graduationTokens);
    }

    // ------------------------- Curve internals -------------------------

    /// @dev Marginal price at `s` tokens sold, wei per whole token.
    function _priceAt(uint256 s) internal view returns (uint256) {
        if (curveType == CurveType.CLASSIC) {
            // price = x/y (wei per whole token) = K * 1e18 / y^2
            uint256 y = virtualToken - s;
            return Math.mulDiv(curveK, ONE, y * y);
        } else if (curveType == CurveType.LINEAR) {
            return startPrice + Math.mulDiv(finalPrice - startPrice, s, saleSupply);
        } else {
            uint256 q = Math.mulDiv(s, s, saleSupply);
            return startPrice + Math.mulDiv(finalPrice - startPrice, q, saleSupply);
        }
    }

    /// @dev E(s2) - E(s1): net ETH the curve charges to move from s1 to s2 sold.
    function _ethBetween(uint256 s1, uint256 s2) internal view returns (uint256) {
        return _ethBetween(curveType, curveK, virtualToken, virtualEth, startPrice, finalPrice, saleSupply, s1, s2);
    }

    /// @dev Pure curve integral, parametrized so the constructor can reuse it
    /// before the immutables are readable.
    function _ethBetween(
        CurveType ct,
        uint256 k,
        uint256 y0,
        uint256 x0,
        uint256 p0,
        uint256 pf,
        uint256 S,
        uint256 s1,
        uint256 s2
    ) internal pure returns (uint256) {
        if (s2 <= s1) return 0;
        if (ct == CurveType.CLASSIC) {
            // E(s) = K/(y0-s) - x0, monotone in s.
            uint256 e2 = k / (y0 - s2) - x0;
            uint256 e1 = k / (y0 - s1) - x0;
            return e2 - e1;
        } else if (ct == CurveType.LINEAR) {
            return _linearE(p0, pf, S, s2) - _linearE(p0, pf, S, s1);
        } else {
            return _expE(p0, pf, S, s2) - _expE(p0, pf, S, s1);
        }
    }

    /// @dev Linear curve integral: E(s) = p0*s/1e18 + (pf-p0)*s^2 / (2*S*1e18).
    function _linearE(uint256 p0, uint256 pf, uint256 S, uint256 s) private pure returns (uint256) {
        uint256 base = Math.mulDiv(p0, s, ONE);
        uint256 quad = Math.mulDiv(Math.mulDiv(pf - p0, s, S), s, 2 * ONE);
        return base + quad;
    }

    /// @dev Power curve integral: E(s) = p0*s/1e18 + (pf-p0)*s^3 / (3*S^2*1e18).
    function _expE(uint256 p0, uint256 pf, uint256 S, uint256 s) private pure returns (uint256) {
        uint256 base = Math.mulDiv(p0, s, ONE);
        uint256 cube = Math.mulDiv(Math.mulDiv(s, s, S), s, S); // s^3 / S^2
        uint256 term = Math.mulDiv(pf - p0, cube, 3 * ONE);
        return base + term;
    }

    /**
     * @dev Inverse of the curve integral: the largest token amount whose cost
     * from `s` sold does not exceed `ethIn`. Binary search over the monotone
     * cost function — one implementation for every curve family (gas is cheap
     * on the target chains; correctness and uniformity win).
     */
    function _tokensForEth(uint256 s, uint256 ethIn) internal view returns (uint256) {
        if (ethIn == 0) return 0;
        uint256 lo = 0;
        uint256 hi = saleSupply - s;
        while (lo < hi) {
            uint256 mid = lo + (hi - lo + 1) / 2;
            if (_ethBetween(s, s + mid) <= ethIn) {
                lo = mid;
            } else {
                hi = mid - 1;
            }
        }
        return lo;
    }

    // --------------------------- Internals ----------------------------

    /// @dev sqrtPriceX96 = sqrt(amount1 / amount0) * 2**96, using raw token amounts.
    function _sqrtPriceX96(uint256 amount0, uint256 amount1) internal pure returns (uint160) {
        uint256 ratioX192 = Math.mulDiv(amount1, 1 << 192, amount0);
        return uint160(Math.sqrt(ratioX192));
    }

    /// @dev Return unused token/WETH left after mint: tokens burned, WETH accrued to creator.
    function _sweepDust(uint256 amount0, uint256 amount1, uint256 used0, uint256 used1) internal {
        address tk = address(token);
        (uint256 tokenDesired, uint256 tokenUsed, uint256 wethDesired, uint256 wethUsed) =
            tk < address(weth) ? (amount0, used0, amount1, used1) : (amount1, used1, amount0, used0);

        uint256 tokenLeft = tokenDesired - tokenUsed;
        if (tokenLeft > 0) ERC20Burnable(tk).burn(tokenLeft);

        uint256 wethLeft = wethDesired - wethUsed;
        if (wethLeft > 0) {
            weth.withdraw(wethLeft);
            feesAccrued[feeRecipient] += wethLeft;
        }
    }

    function _sendEth(address to, uint256 amount) internal {
        (bool ok,) = to.call{value: amount}("");
        if (!ok) revert EthSendFailed();
    }

    /// @dev Accept ETH only from WETH (during unwrap dust sweep).
    receive() external payable {
        if (msg.sender != address(weth)) revert TradingClosed();
    }
}
