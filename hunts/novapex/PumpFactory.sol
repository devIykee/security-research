// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MemeToken} from "./MemeToken.sol";
import {IUniswapV2Router02} from "./interfaces/IUniswapV2Router02.sol";
import {IUniswapV2Factory} from "./interfaces/IUniswapV2Factory.sol";

/// @title PumpFactory
/// @notice A pump.fun-style launchpad for Robinhood Chain. Anyone can create an
///         ERC-20 that trades against a constant-product bonding curve with
///         virtual reserves (the same shape pump.fun uses on Solana). Buyers pay
///         ETH into the curve and receive tokens; sellers return tokens for ETH.
///         A flat trade fee is skimmed to a fee recipient. When the curve sells
///         out its allocation the token "graduates" (a milestone event).
///
/// @dev    Pricing uses a constant product k = (vEth) * (vToken):
///           - vEth   = VIRTUAL_ETH + realEthReserve
///           - vToken = VIRTUAL_TOKEN - tokensSold
///         k is constant, so any trade preserves vEth * vToken = k.
///         Virtual reserves give the curve a sane, non-zero starting price.
contract PumpFactory is ReentrancyGuard {
    // ----------------------------------------------------------------------
    // Curve constants (18-decimal fixed point)
    // ----------------------------------------------------------------------

    /// @notice Total supply minted per token.
    uint256 public constant TOTAL_SUPPLY = 1_000_000_000 ether; // 1B
    /// @notice Portion of supply sold through the curve. The remainder stays in
    ///         the factory (reserved for post-graduation DEX liquidity).
    uint256 public constant CURVE_SUPPLY = 800_000_000 ether; // 800M
    /// @notice Supply reserved for the Uniswap pool at graduation. Equals the
    ///         tokens the factory still holds once the curve is fully sold out
    ///         (TOTAL_SUPPLY - CURVE_SUPPLY = 200M).
    uint256 public constant DEX_SUPPLY = TOTAL_SUPPLY - CURVE_SUPPLY; // 200M
    /// @notice Virtual token reserve — must exceed CURVE_SUPPLY so vToken stays
    ///         positive across the whole curve.
    uint256 public constant VIRTUAL_TOKEN = 1_073_000_000 ether; // ~1.073B
    /// @notice Virtual ETH reserve — sets the initial price / total raise
    ///         (raise = VIRTUAL_ETH × CURVE_SUPPLY / (VIRTUAL_TOKEN −
    ///         CURVE_SUPPLY) = VIRTUAL_ETH × 800/273). Chosen so selling out
    ///         the curve raises exactly 3 ETH: 1.02375 × 800/273 = 3.
    uint256 public constant VIRTUAL_ETH = 1.02375 ether;
    /// @notice Product invariant.
    uint256 public constant K = VIRTUAL_ETH * VIRTUAL_TOKEN;

    /// @notice Trade fee in basis points (100 = 1%).
    uint256 public constant TRADE_FEE_BPS = 100;
    /// @notice Migration accepts fills down to this fraction of the desired
    ///         amounts (9500 = 95%), so a mildly pre-seeded/skewed pair can't
    ///         permanently block graduation. Extreme skews still revert; see
    ///         `rescueGraduated` for the owner escape hatch.
    uint256 public constant MIGRATION_TOLERANCE_BPS = 9_500;
    uint256 private constant BPS = 10_000;

    /// @notice Burn sink for LP tokens — sending them here locks liquidity
    ///         permanently (pump.fun style), so it can never be pulled.
    address public constant DEAD = 0x000000000000000000000000000000000000dEaD;

    /// @notice Metadata length caps (bytes). Bounded so a single token can
    ///         never bloat `getTokenInfos` pages past RPC gas limits and break
    ///         enumeration for everyone. The image cap is sized to the
    ///         EIP-7825 per-transaction gas cap (2^24 ≈ 16.7M): creation with a
    ///         20kB data URI measures ~15.7M gas, leaving room for an opening
    ///         buy. The frontend compresses uploads to fit this budget.
    uint256 public constant MAX_NAME_LEN = 64;
    uint256 public constant MAX_SYMBOL_LEN = 32;
    uint256 public constant MAX_DESCRIPTION_LEN = 1_000;
    uint256 public constant MAX_IMAGE_URI_LEN = 20_000;

    // ----------------------------------------------------------------------
    // Storage
    // ----------------------------------------------------------------------

    struct Curve {
        bool exists;
        bool graduated; // curve sold out; trading is closed
        bool migrated; // liquidity moved to Uniswap and LP burned
        address creator;
        uint256 ethReserve; // real ETH held for this token
        uint256 tokensSold; // tokens dispensed from the curve so far
    }

    /// @notice Per-token curve state.
    mapping(address => Curve) public curves;
    /// @notice All tokens ever created, for enumeration by the frontend.
    address[] public allTokens;

    /// @notice Fee configuration. `owner` may update the recipient.
    address public owner;
    /// @notice Ownership handover is two-step: the new owner must accept, so a
    ///         typo can never brick the admin surface (setUniswap, rescue).
    address public pendingOwner;
    address public feeRecipient;
    /// @notice Flat fee (in wei) charged on token creation. Default 0.
    uint256 public creationFee;
    /// @notice Fees that could not be delivered to `feeRecipient` (it rejected
    ///         ETH). Claimable later via `claimFees`. Trading never blocks on a
    ///         misbehaving fee recipient.
    uint256 public accruedFees;

    // ----------------------------------------------------------------------
    // Uniswap migration config (owner-settable; address(0) = disabled)
    // ----------------------------------------------------------------------

    /// @notice Uniswap v2 Router02 used to seed and lock DEX liquidity at
    ///         graduation. On Robinhood Chain (chain id 4663) the canonical
    ///         address is 0x89e5db8b5aa49aa85ac63f691524311aeb649eba. Left as
    ///         address(0) until the owner configures it; while unset, tokens
    ///         graduate but liquidity is not migrated (reserves stay here).
    address public uniswapRouter;
    /// @notice Canonical WETH the router pairs against. On Robinhood Chain:
    ///         0x0Bd7D308f8E1639FAb988df18A8011f41EAcAD73.
    address public weth;

    // ----------------------------------------------------------------------
    // Events
    // ----------------------------------------------------------------------

    event TokenCreated(
        address indexed token,
        address indexed creator,
        string name,
        string symbol
    );
    event Buy(
        address indexed token,
        address indexed buyer,
        uint256 ethIn,
        uint256 tokensOut,
        uint256 newPrice
    );
    event Sell(
        address indexed token,
        address indexed seller,
        uint256 tokensIn,
        uint256 ethOut,
        uint256 newPrice
    );
    event Graduated(address indexed token, uint256 ethReserve);
    event FeesClaimed(address indexed to, uint256 amount);
    event Rescued(
        address indexed token,
        address indexed to,
        uint256 ethAmount,
        uint256 tokenAmount
    );
    event Migrated(
        address indexed token,
        address indexed pair,
        uint256 tokenAmount,
        uint256 ethAmount,
        uint256 liquidity
    );
    event UniswapConfigured(address router, address weth);
    event OwnershipTransferStarted(address indexed from, address indexed to);
    event OwnershipTransferred(address indexed from, address indexed to);

    // ----------------------------------------------------------------------
    // Errors
    // ----------------------------------------------------------------------

    error NotOwner();
    error UnknownToken();
    error ZeroAmount();
    error InsufficientCreationFee();
    error SlippageExceeded();
    error CurveSoldOut();
    error CurveClosed();
    error TransferFailed();
    error NotGraduated();
    error AlreadyMigrated();
    error MigrationNotConfigured();
    error InsufficientBalance();
    error InvalidMetadata();
    error ZeroAddress();

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    constructor(address feeRecipient_) {
        owner = msg.sender;
        feeRecipient = feeRecipient_ == address(0) ? msg.sender : feeRecipient_;
    }

    // ----------------------------------------------------------------------
    // Creation
    // ----------------------------------------------------------------------

    /// @notice Launch a new token with a fresh bonding curve.
    function createToken(
        string calldata name,
        string calldata symbol,
        string calldata description,
        string calldata imageURI
    ) external payable nonReentrant returns (address token) {
        if (msg.value < creationFee) revert InsufficientCreationFee();
        // Bounded metadata: keeps every token enumerable via getTokenInfos.
        if (
            bytes(name).length == 0 ||
            bytes(name).length > MAX_NAME_LEN ||
            bytes(symbol).length == 0 ||
            bytes(symbol).length > MAX_SYMBOL_LEN ||
            bytes(description).length > MAX_DESCRIPTION_LEN ||
            bytes(imageURI).length > MAX_IMAGE_URI_LEN
        ) revert InvalidMetadata();

        MemeToken t = new MemeToken(
            name,
            symbol,
            description,
            imageURI,
            msg.sender,
            TOTAL_SUPPLY
        );
        token = address(t);

        curves[token] = Curve({
            exists: true,
            graduated: false,
            migrated: false,
            creator: msg.sender,
            ethReserve: 0,
            tokensSold: 0
        });
        allTokens.push(token);

        if (creationFee > 0) _payFee(creationFee);

        emit TokenCreated(token, msg.sender, name, symbol);

        // If the creator sent extra ETH beyond the creation fee, treat it as an
        // opening buy so they can grab the first tokens atomically.
        uint256 extra = msg.value - creationFee;
        if (extra > 0) _buy(token, extra, 0, msg.sender);
    }

    // ----------------------------------------------------------------------
    // Trading
    // ----------------------------------------------------------------------

    /// @notice Buy `token` with ETH. `minTokensOut` guards against slippage.
    function buy(address token, uint256 minTokensOut)
        external
        payable
        nonReentrant
        returns (uint256 tokensOut)
    {
        if (msg.value == 0) revert ZeroAmount();
        return _buy(token, msg.value, minTokensOut, msg.sender);
    }

    /// @notice Sell `tokenAmount` of `token` back to the curve for ETH.
    ///         Caller must approve this factory for `tokenAmount` first.
    function sell(
        address token,
        uint256 tokenAmount,
        uint256 minEthOut
    ) external nonReentrant returns (uint256 ethOut) {
        Curve storage c = curves[token];
        if (!c.exists) revert UnknownToken();
        // Once graduated the curve is closed; trading happens on Uniswap.
        if (c.graduated) revert CurveClosed();
        if (tokenAmount == 0) revert ZeroAmount();

        // Gross ETH from the curve for returning `tokenAmount`.
        uint256 grossEth = _ethOutForTokens(c, tokenAmount);
        if (grossEth == 0) revert ZeroAmount(); // dust: rounds to no payout
        uint256 fee = (grossEth * TRADE_FEE_BPS) / BPS;
        ethOut = grossEth - fee;
        if (ethOut < minEthOut) revert SlippageExceeded();

        // Update curve: tokens flow back in, ETH flows out.
        c.tokensSold -= tokenAmount;
        c.ethReserve -= grossEth;

        // Pull tokens from seller into the curve.
        if (!IERC20(token).transferFrom(msg.sender, address(this), tokenAmount)) {
            revert TransferFailed();
        }

        if (fee > 0) _payFee(fee);
        _payout(msg.sender, ethOut);

        emit Sell(token, msg.sender, tokenAmount, ethOut, currentPrice(token));
    }

    /// @dev Shared buy logic used by `buy` and by the opening buy in `createToken`.
    function _buy(
        address token,
        uint256 ethIn,
        uint256 minTokensOut,
        address to
    ) internal returns (uint256 tokensOut) {
        Curve storage c = curves[token];
        if (!c.exists) revert UnknownToken();
        // Closed once graduated (also covers the sold-out state defensively).
        if (c.graduated) revert CurveClosed();

        uint256 remaining = CURVE_SUPPLY - c.tokensSold;
        if (remaining == 0) revert CurveSoldOut();

        uint256 fee = (ethIn * TRADE_FEE_BPS) / BPS;
        uint256 ethForCurve = ethIn - fee;

        tokensOut = _tokensOutForEth(c, ethForCurve);

        // Cap at the curve's remaining supply and refund the ETH overpayment.
        // The curve absorbs *exactly* the ETH needed for the last tokens (so the
        // constant-product invariant holds and the contract stays solvent); the
        // fee is charged on top of that, and everything above is refunded.
        uint256 refund;
        if (tokensOut > remaining) {
            tokensOut = remaining;
            uint256 ethNeededForCurve = _ethInForTokens(c, remaining);
            uint256 cappedFee =
                (ethNeededForCurve * TRADE_FEE_BPS) / (BPS - TRADE_FEE_BPS);
            uint256 grossNeeded = ethNeededForCurve + cappedFee;
            ethForCurve = ethNeededForCurve;
            fee = cappedFee;
            refund = ethIn > grossNeeded ? ethIn - grossNeeded : 0;
        }

        // Dust guard (mirror of sell's): an input so small it rounds to zero
        // tokens would otherwise silently donate the ETH to the curve.
        if (tokensOut == 0) revert ZeroAmount();
        if (tokensOut < minTokensOut) revert SlippageExceeded();

        c.tokensSold += tokensOut;
        c.ethReserve += ethForCurve;

        if (fee > 0) _payFee(fee);
        if (refund > 0) _payout(to, refund);
        if (!IERC20(token).transfer(to, tokensOut)) revert TransferFailed();

        emit Buy(token, to, ethForCurve, tokensOut, currentPrice(token));

        // Graduation milestone: the curve has dispensed its full allocation.
        // We only flip the flag + emit here — we deliberately DO NOT run the
        // Uniswap migration inline (see finalizeGraduation). That keeps this
        // buy cheap and un-brickable: a failing router call can never revert the
        // trade that crosses the threshold, and migration becomes a separate,
        // permissionless, retryable step.
        if (!c.graduated && c.tokensSold >= CURVE_SUPPLY) {
            c.graduated = true;
            emit Graduated(token, c.ethReserve);
        }
    }

    // ----------------------------------------------------------------------
    // Graduation → Uniswap migration
    // ----------------------------------------------------------------------

    /// @notice Whether a token can be migrated right now (graduated, not yet
    ///         migrated, and Uniswap is configured).
    function canFinalize(address token) external view returns (bool) {
        Curve storage c = curves[token];
        return
            c.exists &&
            c.graduated &&
            !c.migrated &&
            uniswapRouter != address(0) &&
            weth != address(0);
    }

    /// @notice Permissionless: seed a Uniswap v2 pool with the reserved DEX
    ///         supply (200M tokens) paired against the ETH collected on the
    ///         curve, then burn the LP so liquidity is locked forever. Anyone may
    ///         call this once a token has graduated (typically the frontend/a bot
    ///         right after the graduating buy).
    ///
    /// @dev    Kept separate from buy() on purpose (see the note in _buy):
    ///         the graduating trade must never depend on an external router call.
    ///         Because this is its own permissionless, retryable entrypoint, a
    ///         transient router failure can't brick the token — anyone can retry.
    ///
    ///         Price continuity: the pool opens at ethReserve / DEX_SUPPLY. At
    ///         graduation ethReserve = 3 ETH, so the pool price is
    ///         3 / 200e6 = 1.50e-8 ETH/token, essentially equal to the
    ///         curve's final marginal price (vEth/vToken ≈ 4.02 / 0.273e9 ≈
    ///         1.47e-8). Price is continuous across the migration (~2%).
    function finalizeGraduation(address token) external nonReentrant {
        Curve storage c = curves[token];
        if (!c.exists) revert UnknownToken();
        if (!c.graduated) revert NotGraduated();
        if (c.migrated) revert AlreadyMigrated();

        address router = uniswapRouter;
        address weth_ = weth;
        if (router == address(0) || weth_ == address(0)) {
            revert MigrationNotConfigured();
        }

        uint256 ethAmount = c.ethReserve;
        uint256 tokenAmount = DEX_SUPPLY;

        // --- EFFECTS (before any external call) ---
        // Flip migrated first so a reentrant finalize reverts (AlreadyMigrated),
        // and clear the reserve since it is leaving the curve for the pool.
        c.migrated = true;
        c.ethReserve = 0;

        // Solvency invariant: the factory must actually hold the ETH it's about
        // to deposit. Real ETH balance = sum of all tokens' ethReserve (fees and
        // refunds are paid out immediately), so this always holds — but assert it.
        if (address(this).balance < ethAmount) revert InsufficientBalance();

        // --- INTERACTIONS ---
        // Approve exactly the tokens the router may pull, then reset to 0.
        IERC20(token).approve(router, tokenAmount);

        // Min-amounts at a 95% tolerance: a fresh pair consumes the desired
        // amounts exactly, and a mildly pre-seeded/skewed pair (a known v2
        // griefing vector) still migrates instead of reverting forever. An
        // attacker skewing the ratio beyond the tolerance only burns their own
        // capital into a pool whose LP we then deepen; extreme skews revert and
        // are recoverable via `rescueGraduated`. Leftovers that the router does
        // not consume are handled below, so no value is stranded.
        (uint256 usedToken, uint256 usedEth, uint256 liquidity) =
            IUniswapV2Router02(router).addLiquidityETH{value: ethAmount}(
                token,
                tokenAmount,
                (tokenAmount * MIGRATION_TOLERANCE_BPS) / BPS, // amountTokenMin
                (ethAmount * MIGRATION_TOLERANCE_BPS) / BPS, // amountETHMin
                DEAD, // LP recipient: burn address → liquidity locked forever
                block.timestamp // deadline: executes this block
            );

        // Reset the allowance (nonzero when the router consumed < tokenAmount).
        IERC20(token).approve(router, 0);

        // Leftovers: unconsumed tokens are burned (they were earmarked for the
        // pool, never for anyone's wallet); unconsumed ETH (refunded to this
        // contract by the router) goes to the fee recipient via the tolerant
        // path so it can never block the migration.
        uint256 leftoverTokens = tokenAmount - usedToken;
        if (leftoverTokens > 0) {
            if (!IERC20(token).transfer(DEAD, leftoverTokens)) {
                revert TransferFailed();
            }
        }
        uint256 leftoverEth = ethAmount - usedEth;
        if (leftoverEth > 0) _payFee(leftoverEth);

        address pair =
            IUniswapV2Factory(IUniswapV2Router02(router).factory()).getPair(
                token,
                weth_
            );
        emit Migrated(token, pair, usedToken, usedEth, liquidity);
    }

    /// @notice Owner escape hatch for a graduated token whose migration is
    ///         permanently stuck (e.g. an attacker skewed the pair beyond the
    ///         tolerance, or no router is configured). Moves the reserved
    ///         DEX_SUPPLY tokens and the collected ETH to `to` so liquidity can
    ///         be set up manually. Only reachable while `graduated && !migrated`
    ///         — it can never touch a live curve's funds.
    function rescueGraduated(address token, address to)
        external
        onlyOwner
        nonReentrant
    {
        Curve storage c = curves[token];
        if (!c.exists) revert UnknownToken();
        if (!c.graduated) revert NotGraduated();
        if (c.migrated) revert AlreadyMigrated();

        c.migrated = true;
        uint256 ethAmount = c.ethReserve;
        c.ethReserve = 0;

        if (!IERC20(token).transfer(to, DEX_SUPPLY)) revert TransferFailed();
        if (ethAmount > 0) _payout(to, ethAmount);
        emit Rescued(token, to, ethAmount, DEX_SUPPLY);
    }

    // ----------------------------------------------------------------------
    // Curve math (pure helpers)
    // ----------------------------------------------------------------------

    /// @dev Tokens received for adding `ethIn` to the curve.
    function _tokensOutForEth(Curve storage c, uint256 ethIn)
        internal
        view
        returns (uint256)
    {
        uint256 vEth = VIRTUAL_ETH + c.ethReserve;
        uint256 vToken = VIRTUAL_TOKEN - c.tokensSold;
        // newVToken = K / (vEth + ethIn); tokensOut = vToken - newVToken.
        uint256 newVToken = K / (vEth + ethIn);
        return vToken - newVToken;
    }

    /// @dev Gross ETH released for returning `tokenAmount` to the curve.
    function _ethOutForTokens(Curve storage c, uint256 tokenAmount)
        internal
        view
        returns (uint256)
    {
        uint256 vEth = VIRTUAL_ETH + c.ethReserve;
        uint256 vToken = VIRTUAL_TOKEN - c.tokensSold;
        // newVEth = K / (vToken + tokenAmount); ethOut = vEth - newVEth.
        uint256 newVEth = K / (vToken + tokenAmount);
        return vEth - newVEth;
    }

    /// @dev ETH that must enter the curve to dispense exactly `tokenAmount`.
    function _ethInForTokens(Curve storage c, uint256 tokenAmount)
        internal
        view
        returns (uint256)
    {
        uint256 vEth = VIRTUAL_ETH + c.ethReserve;
        uint256 vToken = VIRTUAL_TOKEN - c.tokensSold;
        // newVEth = K / (vToken - tokenAmount); ethIn = newVEth - vEth.
        uint256 newVEth = K / (vToken - tokenAmount);
        return newVEth - vEth;
    }

    // ----------------------------------------------------------------------
    // Views
    // ----------------------------------------------------------------------

    /// @notice Instantaneous price: ETH per whole token (18-decimal fixed point).
    function currentPrice(address token) public view returns (uint256) {
        Curve storage c = curves[token];
        if (!c.exists) return 0;
        uint256 vEth = VIRTUAL_ETH + c.ethReserve;
        uint256 vToken = VIRTUAL_TOKEN - c.tokensSold;
        // price = vEth / vToken, scaled by 1e18.
        return (vEth * 1 ether) / vToken;
    }

    /// @notice Quote: tokens out for a given ETH input (net of fee).
    function quoteBuy(address token, uint256 ethIn)
        external
        view
        returns (uint256 tokensOut)
    {
        Curve storage c = curves[token];
        if (!c.exists) revert UnknownToken();
        uint256 ethForCurve = ethIn - (ethIn * TRADE_FEE_BPS) / BPS;
        tokensOut = _tokensOutForEth(c, ethForCurve);
        uint256 remaining = CURVE_SUPPLY - c.tokensSold;
        if (tokensOut > remaining) tokensOut = remaining;
    }

    /// @notice Quote: ETH out for selling a given token amount (net of fee).
    function quoteSell(address token, uint256 tokenAmount)
        external
        view
        returns (uint256 ethOut)
    {
        Curve storage c = curves[token];
        if (!c.exists) revert UnknownToken();
        uint256 grossEth = _ethOutForTokens(c, tokenAmount);
        ethOut = grossEth - (grossEth * TRADE_FEE_BPS) / BPS;
    }

    /// @notice Fraction of the curve sold, in basis points (10000 = graduated).
    function progressBps(address token) external view returns (uint256) {
        Curve storage c = curves[token];
        if (!c.exists) return 0;
        return (c.tokensSold * BPS) / CURVE_SUPPLY;
    }

    function tokenCount() external view returns (uint256) {
        return allTokens.length;
    }

    /// @notice Everything the frontend needs about one coin in a single call.
    struct TokenInfo {
        address token;
        string name;
        string symbol;
        string imageURI;
        string description;
        address creator;
        uint256 price; // ETH per whole token, 1e18 fixed point
        uint256 ethReserve; // real ETH collected in the curve
        uint256 tokensSold; // tokens dispensed from the curve
        uint256 progressBps; // 0..10000 fraction of the curve sold
        bool graduated;
        bool migrated; // liquidity moved to Uniswap and LP burned
    }

    function getTokenInfo(address token)
        public
        view
        returns (TokenInfo memory info)
    {
        Curve storage c = curves[token];
        if (!c.exists) revert UnknownToken();
        MemeToken t = MemeToken(token);
        info = TokenInfo({
            token: token,
            name: t.name(),
            symbol: t.symbol(),
            imageURI: t.imageURI(),
            description: t.description(),
            creator: c.creator,
            price: currentPrice(token),
            ethReserve: c.ethReserve,
            tokensSold: c.tokensSold,
            progressBps: (c.tokensSold * BPS) / CURVE_SUPPLY,
            graduated: c.graduated,
            migrated: c.migrated
        });
    }

    /// @notice Paginated coin feed: newest last in `allTokens`; callers usually
    ///         reverse the page for a newest-first display.
    function getTokenInfos(uint256 start, uint256 count)
        external
        view
        returns (TokenInfo[] memory page)
    {
        uint256 len = allTokens.length;
        if (start >= len) return new TokenInfo[](0);
        uint256 end = start + count;
        if (end > len) end = len;
        page = new TokenInfo[](end - start);
        for (uint256 i = start; i < end; i++) {
            page[i - start] = getTokenInfo(allTokens[i]);
        }
    }

    /// @notice Paginated token list for the frontend (newest-agnostic; index order).
    function getTokens(uint256 start, uint256 count)
        external
        view
        returns (address[] memory page)
    {
        uint256 len = allTokens.length;
        if (start >= len) return new address[](0);
        uint256 end = start + count;
        if (end > len) end = len;
        page = new address[](end - start);
        for (uint256 i = start; i < end; i++) {
            page[i - start] = allTokens[i];
        }
    }

    // ----------------------------------------------------------------------
    // Admin
    // ----------------------------------------------------------------------

    function setFeeRecipient(address r) external onlyOwner {
        // address(0) accepts ETH via low-level call, so fees would burn silently.
        if (r == address(0)) revert ZeroAddress();
        feeRecipient = r;
    }

    function setCreationFee(uint256 fee) external onlyOwner {
        creationFee = fee;
    }

    /// @notice Two-step ownership handover: propose here, new owner accepts.
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        pendingOwner = newOwner;
        emit OwnershipTransferStarted(owner, newOwner);
    }

    function acceptOwnership() external {
        if (msg.sender != pendingOwner) revert NotOwner();
        emit OwnershipTransferred(owner, msg.sender);
        owner = msg.sender;
        pendingOwner = address(0);
    }

    /// @notice Configure the Uniswap v2 router + WETH used for migration. Setting
    ///         either back to address(0) disables migration (graduated tokens
    ///         simply keep their reserves here — the pre-Uniswap fallback).
    /// @dev    Split from the migration path so a bad address can never be set
    ///         mid-migration; only the owner can point at a router.
    function setUniswapRouter(address router) external onlyOwner {
        uniswapRouter = router;
        emit UniswapConfigured(router, weth);
    }

    function setWeth(address weth_) external onlyOwner {
        weth = weth_;
        emit UniswapConfigured(uniswapRouter, weth_);
    }

    /// @notice Convenience: set both router and WETH in one call.
    function setUniswap(address router, address weth_) external onlyOwner {
        uniswapRouter = router;
        weth = weth_;
        emit UniswapConfigured(router, weth_);
    }

    // ----------------------------------------------------------------------
    // Internal
    // ----------------------------------------------------------------------

    function _payout(address to, uint256 amount) internal {
        (bool ok, ) = payable(to).call{value: amount}("");
        if (!ok) revert TransferFailed();
    }

    /// @dev Fee delivery that can never block trading: if `feeRecipient`
    ///      rejects ETH, the fee accrues and can be claimed later. User payouts
    ///      (refunds, sell proceeds) intentionally still hard-revert.
    function _payFee(uint256 amount) internal {
        (bool ok, ) = payable(feeRecipient).call{value: amount}("");
        if (!ok) accruedFees += amount;
    }

    /// @notice Deliver fees that previously failed to send. Callable by anyone;
    ///         funds only ever go to the current `feeRecipient`.
    function claimFees() external nonReentrant {
        uint256 amount = accruedFees;
        if (amount == 0) revert ZeroAmount();
        accruedFees = 0;
        _payout(feeRecipient, amount);
        emit FeesClaimed(feeRecipient, amount);
    }

    /// @dev Accept ETH refunds from the Uniswap router (addLiquidityETH returns
    ///      unused ETH when the pool ratio differs from the desired amounts).
    receive() external payable {}
}
