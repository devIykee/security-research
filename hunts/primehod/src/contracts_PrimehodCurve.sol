// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title PrimehodCurve
 * @notice One per launched token. A self-contained constant-product bonding curve
 *         priced in native ETH, replacing the Uniswap v4 pool + hook that B20 used
 *         on Base (Robinhood Chain has neither). Buyers send ETH and receive tokens;
 *         sellers send tokens and receive ETH; price is set purely by the curve, so
 *         there is no order book to manipulate and no presale.
 *
 *         Trading carries a swap fee that starts at a per-token BASE rate (chosen at
 *         launch) and ramps up toward a MAX rate (default 5%) when the previous trade
 *         moved the price hard, taxing volatility. Fees are collected in ETH and split
 *         creator / platform (default 55 / 45), each claimed via a pull pattern.
 *
 *         When the ETH raised into the curve reaches `graduationCap`, the token is
 *         flagged `graduated` as a milestone. Because Robinhood Chain has no DEX yet,
 *         trading is NOT halted at graduation: the curve stays the permanent market so
 *         holders always keep a live, non-custodial exit. No admin can seize, move, or
 *         lock the pooled liquidity — there is no owner path to the curve's funds.
 * @dev Constant-product output: out = reserveOut * inNet / (reserveIn + inNet), over
 *      virtual reserves seeded at construction. Checks-effects-interactions + a
 *      reentrancy guard on every state-changing entrypoint; ETH is always moved last.
 */
contract PrimehodCurve is ReentrancyGuard {
    // ── Immutable config ────────────────────────────────────────────────────────
    address public immutable token;
    address public immutable creator;
    address public immutable platform;      // platform fee recipient
    address public immutable factory;       // may seed a DEX after graduation

    uint256 public immutable baseFeeBps;    // resting swap fee, [MIN_FEE_BPS, MAX_FEE_BPS]
    uint256 public immutable maxFeeBps;     // dynamic ceiling the fee ramps to
    uint256 public immutable creatorSplitBps; // creator's cut of each fee, out of 10000
    uint256 public immutable graduationCap; // ETH raised into the curve that graduates it

    uint256 public constant MIN_FEE_BPS = 100;  // 1%
    uint256 public constant MAX_FEE_BPS = 500;  // 5% hard cap (never a honeypot)
    uint256 public constant VOL_FULL_BPS = 600; // a 6% price move ramps fee fully to max

    // ── Curve state ─────────────────────────────────────────────────────────────
    uint256 public vEthReserve;             // virtual ETH reserve
    uint256 public vTokenReserve;           // virtual token reserve
    uint256 public immutable vEthReserve0;  // initial virtual ETH (= ETH raised offset)
    uint256 public curveTokenBalance;       // real tokens still held for sale
    uint256 public ethRaised;               // real ETH taken in, net of fees (curve-owned)
    bool public graduated;

    // Dynamic-fee volatility carry: extra bps applied to the NEXT trade.
    uint256 public volBps;
    uint256 public lastPriceX18;            // price after the previous trade, 1e18-scaled

    // Pull-payment fee balances.
    uint256 public creatorFees;
    uint256 public platformFees;

    event Buy(address indexed buyer, uint256 ethIn, uint256 fee, uint256 tokensOut, uint256 feeBps);
    event Sell(address indexed seller, uint256 tokensIn, uint256 fee, uint256 ethOut, uint256 feeBps);
    event Graduated(uint256 ethRaised, uint256 tokensRemaining);
    event FeesClaimed(address indexed to, uint256 amount);

    constructor(
        address _token,
        address _creator,
        address _platform,
        uint256 _curveSupply,
        uint256 _vEthReserve,
        uint256 _vTokenReserve,
        uint256 _baseFeeBps,
        uint256 _maxFeeBps,
        uint256 _creatorSplitBps,
        uint256 _graduationCap
    ) {
        require(_token != address(0) && _creator != address(0) && _platform != address(0), "zero addr");
        require(_curveSupply > 0 && _vEthReserve > 0 && _vTokenReserve > 0, "zero curve");
        require(_baseFeeBps >= MIN_FEE_BPS && _baseFeeBps <= MAX_FEE_BPS, "base out of range");
        require(_maxFeeBps >= _baseFeeBps && _maxFeeBps <= MAX_FEE_BPS, "max out of range");
        require(_creatorSplitBps <= 10000, "split>100%");
        require(_graduationCap > 0, "zero cap");

        token = _token;
        creator = _creator;
        platform = _platform;
        factory = msg.sender;

        curveTokenBalance = _curveSupply;
        vEthReserve = _vEthReserve;
        vEthReserve0 = _vEthReserve;
        vTokenReserve = _vTokenReserve;
        baseFeeBps = _baseFeeBps;
        maxFeeBps = _maxFeeBps;
        creatorSplitBps = _creatorSplitBps;
        graduationCap = _graduationCap;

        lastPriceX18 = (_vEthReserve * 1e18) / _vTokenReserve;
    }

    // ── Views ────────────────────────────────────────────────────────────────────

    /// @notice The fee (bps) that applies to the NEXT trade: base plus the volatility
    ///         carry from the previous trade, capped at maxFeeBps.
    function currentFeeBps() public view returns (uint256) {
        uint256 f = baseFeeBps + volBps;
        return f > maxFeeBps ? maxFeeBps : f;
    }

    /// @notice Spot price of one whole token in ETH, 1e18-scaled.
    function priceX18() external view returns (uint256) {
        return (vEthReserve * 1e18) / vTokenReserve;
    }

    /// @notice Tokens a buyer would receive for `ethIn` at the current fee, before slippage.
    function quoteBuy(uint256 ethIn) external view returns (uint256 tokensOut, uint256 fee) {
        fee = (ethIn * currentFeeBps()) / 10000;
        uint256 net = ethIn - fee;
        tokensOut = (vTokenReserve * net) / (vEthReserve + net);
        if (tokensOut > curveTokenBalance) tokensOut = curveTokenBalance;
    }

    /// @notice ETH a seller would receive for `tokensIn` at the current fee, before slippage.
    function quoteSell(uint256 tokensIn) external view returns (uint256 ethOut, uint256 fee) {
        uint256 gross = (vEthReserve * tokensIn) / (vTokenReserve + tokensIn);
        fee = (gross * currentFeeBps()) / 10000;
        ethOut = gross - fee;
    }

    // ── Trading ──────────────────────────────────────────────────────────────────

    /// @notice Buy tokens with ETH. `minTokensOut` bounds slippage; a buy that would
    ///         exceed the remaining curve supply is rejected (buy exactly up to it).
    function buy(uint256 minTokensOut) external payable nonReentrant returns (uint256 tokensOut) {
        require(msg.value > 0, "no eth");

        uint256 feeBps = currentFeeBps();
        uint256 fee = (msg.value * feeBps) / 10000;
        uint256 net = msg.value - fee;

        tokensOut = (vTokenReserve * net) / (vEthReserve + net);
        require(tokensOut > 0, "dust");
        require(tokensOut < curveTokenBalance, "exceeds curve supply");
        require(tokensOut >= minTokensOut, "slippage");

        // Effects
        vEthReserve += net;
        vTokenReserve -= tokensOut;
        curveTokenBalance -= tokensOut;
        ethRaised += net;
        _accrueFee(fee);
        _updateVol();

        // Interactions
        require(IERC20(token).transfer(msg.sender, tokensOut), "token transfer failed");
        emit Buy(msg.sender, msg.value, fee, tokensOut, feeBps);

        _maybeGraduate();
    }

    /// @notice Sell tokens back to the curve for ETH. Caller must `approve` this
    ///         contract for `tokensIn` first. `minEthOut` bounds slippage.
    function sell(uint256 tokensIn, uint256 minEthOut) external nonReentrant returns (uint256 ethOut) {
        require(tokensIn > 0, "no tokens");

        uint256 gross = (vEthReserve * tokensIn) / (vTokenReserve + tokensIn);
        require(gross > 0 && gross <= ethRaised, "insufficient liquidity");
        uint256 feeBps = currentFeeBps();
        uint256 fee = (gross * feeBps) / 10000;
        ethOut = gross - fee;
        require(ethOut >= minEthOut, "slippage");

        // Effects
        vTokenReserve += tokensIn;
        vEthReserve -= gross;
        curveTokenBalance += tokensIn;
        ethRaised -= gross;
        _accrueFee(fee);
        _updateVol();

        // Interactions: pull tokens in, push ETH out.
        require(IERC20(token).transferFrom(msg.sender, address(this), tokensIn), "token transferFrom failed");
        (bool ok, ) = msg.sender.call{value: ethOut}("");
        require(ok, "eth transfer failed");
        emit Sell(msg.sender, tokensIn, fee, ethOut, feeBps);
    }

    // ── Fees ─────────────────────────────────────────────────────────────────────

    function _accrueFee(uint256 fee) private {
        if (fee == 0) return;
        uint256 toCreator = (fee * creatorSplitBps) / 10000;
        creatorFees += toCreator;
        platformFees += fee - toCreator;
    }

    /// @notice Creator pulls their accrued swap fees (ETH). Permissionless; funds can
    ///         only go to the immutable creator.
    function claimCreatorFees() external nonReentrant {
        uint256 amount = creatorFees;
        require(amount > 0, "nothing");
        creatorFees = 0;
        (bool ok, ) = creator.call{value: amount}("");
        require(ok, "transfer failed");
        emit FeesClaimed(creator, amount);
    }

    /// @notice Platform pulls its accrued swap fees (ETH).
    function claimPlatformFees() external nonReentrant {
        uint256 amount = platformFees;
        require(amount > 0, "nothing");
        platformFees = 0;
        (bool ok, ) = platform.call{value: amount}("");
        require(ok, "transfer failed");
        emit FeesClaimed(platform, amount);
    }

    // ── Volatility / graduation ────────────────────────────────────────────────────

    /// @dev Set the next trade's extra fee from this trade's realized price move,
    ///      ramping linearly to (maxFee - baseFee) at a VOL_FULL_BPS price move.
    function _updateVol() private {
        uint256 price = (vEthReserve * 1e18) / vTokenReserve;
        uint256 last = lastPriceX18;
        uint256 moveBps = last == 0
            ? 0
            : (price > last ? (price - last) : (last - price)) * 10000 / last;
        uint256 span = maxFeeBps - baseFeeBps;
        uint256 extra = span == 0 ? 0 : (moveBps * span) / VOL_FULL_BPS;
        volBps = extra > span ? span : extra;
        lastPriceX18 = price;
    }

    function _maybeGraduate() private {
        if (!graduated && ethRaised >= graduationCap) {
            graduated = true;
            emit Graduated(ethRaised, curveTokenBalance);
        }
    }

}
