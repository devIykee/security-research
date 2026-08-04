// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {RobinTokenV2 as RobinToken} from "./RobinTokenV2.sol";
import {
    IUniswapV2Factory,
    IUniswapV2Router02,
    IUniswapV2Pair,
    IWETH
} from "./interfaces/IUniswapV2.sol";

/// @title RobinFunFactory
/// @notice four.meme-style launchpad for Robinhood Chain (chainId 4663).
///         Each token launches on a constant-product (x*y=k) bonding curve with virtual reserves.
///         Targets are denominated in USD and snapshotted to ETH at creation time using an
///         owner/keeper-set ETH/USD price (Robinhood Chain has no canonical oracle yet).
///
///         Economy (per-token, snapshotted at creation):
///           * total supply ............ 1,000,000,000 (1e9 * 1e18)
///           * curve sale allocation ... 700,000,000 (70%)
///           * LP allocation ........... 300,000,000 (30%)
///           * virtual USD reserve ..... $4,006.153846  -> init mcap $4,000
///           * raise to graduate ....... $9,300 (in ETH at snapshot price)
///           * on graduation ........... $9,000 -> LP, $300 -> treasury
///           * LP tokens ............... 100% burned (sent to 0x...dEaD)
///
///         The curve runs purely in ETH after the snapshot; USD only sets the starting point so
///         creators get consistent dollar targets regardless of ETH price.
///
///         SECURITY HARDENING (post-audit):
///           * Graduation is DECOUPLED from buy: hitting the raise sets `readyToGraduate`; a
///             separate, permissionless `graduate(token)` finalizes. A failing LP step can never
///             brick buys or freeze a curve.
///           * Liquidity is added by transferring tokens + WETH directly to the pair and calling
///             pair.mint() — NOT router.addLiquidityETH. Any reserves an attacker pre-donates to
///             the pair are absorbed into the burned LP (they cannot steal the raise, and the
///             router's quote()-revert DoS path is avoided entirely).
///           * Treasury payouts are best-effort (never revert a user trade if treasury rejects ETH);
///             the cut is escrowed for later pull if the push fails.
///           * Per-curve ETH accounting: graduation spends from the curve's own realEth, and any
///             surplus is returned to that curve's treasury cut. An owner sweep recovers only
///             genuinely orphaned ETH (balance minus the sum of live curves' realEth).
contract RobinFunFactoryV2 {
    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 public constant TOTAL_SUPPLY = 1_000_000_000 ether; // 1e9 * 1e18
    uint256 public constant CURVE_SUPPLY = 700_000_000 ether; // 70% sold on the curve
    uint256 public constant LP_SUPPLY = 300_000_000 ether; // 30% paired into the LP

    // USD targets (8 decimals, like a Chainlink USD feed).
    // $4,006.153846 with 8 decimals -> init mcap $4,000.
    uint256 public constant VIRTUAL_USD_RESERVE = 400_615_384_600;
    uint256 public constant RAISE_USD = 9300 * 1e8; // $9,300 graduation trigger
    uint256 public constant LP_USD = 9000 * 1e8; // $9,000 into the LP
    uint256 public constant TREASURY_USD = 300 * 1e8; // $300 to the treasury

    address public constant DEAD = 0x000000000000000000000000000000000000dEaD;

    // A hostile pre-mint of the pair is tolerated at graduation only if BOTH sides of the existing
    // position are below 1/POLLUTION_DUST_FACTOR of what we are about to add. In that regime our LP
    // mint credits us ~100% of the pool and the attacker's share rounds to zero, so the cheap
    // "pre-mint 1001 wei to brick graduation" griefing vector no longer forces the recovery path.
    uint256 public constant POLLUTION_DUST_FACTOR = 1e6;

    uint256 public constant MAX_TRADE_FEE_BPS = 300; // hard cap 3%
    uint256 public constant MAX_KEEPER_MOVE_BPS = 1000; // keeper may move ethUsdPrice at most +/-10% per update
    uint256 public constant MAX_NAME_LEN = 32;
    uint256 public constant MAX_SYMBOL_LEN = 11;

    /// @notice every launched token address must end in these 4 hex nibbles (0x...4663).
    uint16 public constant VANITY_SUFFIX = 0x4663;

    /*//////////////////////////////////////////////////////////////
                                IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    IUniswapV2Router02 public immutable router;
    IUniswapV2Factory public immutable uniFactory;
    address public immutable WETH;

    /*//////////////////////////////////////////////////////////////
                                  STORAGE
    //////////////////////////////////////////////////////////////*/

    address public owner;
    address public treasury;
    address public keeper; // hot key: may ONLY nudge ethUsdPrice within a band (never funds/fees/CTO)

    /// @notice ETH/USD price with 8 decimals (e.g. $3000 => 3000e8). Set by owner/keeper.
    uint256 public ethUsdPrice;

    /// @notice flat creation fee in ETH (wei). 0 by default.
    uint256 public creationFee;

    /// @notice trading fee in basis points charged on each buy/sell (e.g. 100 = 1%).
    uint256 public tradeFeeBps;

    /// @notice sum of all live (non-graduated) curves' realEth — used to scope the owner sweep.
    uint256 public totalLiveRealEth;

    /// @notice escrowed treasury payouts that failed to push (pull-payment fallback).
    uint256 public treasuryEscrow;

    struct Curve {
        uint256 virtualEth; // virtual ETH reserve (USD reserve converted at snapshot)
        uint256 realEth; // real ETH collected so far
        uint256 tokenReserve; // curve token reserve; decreases on buy
        uint256 raiseTarget; // ETH needed to graduate (RAISE_USD at snapshot)
        uint256 lpEth; // ETH put into LP at graduation (LP_USD at snapshot)
        uint256 treasuryEth; // ETH to treasury at graduation (TREASURY_USD at snapshot)
        uint256 k; // invariant = virtualEth * y0
        bool readyToGraduate; // raise reached, awaiting finalize
        bool graduated; // LP created + burned
        address creator; // who launched the token (identity)
        address feeRecipient; // where the creator's half of the trade fee is paid (creator's choice)
    }

    mapping(address => Curve) public curves;
    address[] public allTokens;

    /*//////////////////////////////////////////////////////////////
                                  EVENTS
    //////////////////////////////////////////////////////////////*/

    event TokenCreated(
        address indexed token,
        address indexed creator,
        string name,
        string symbol,
        uint256 ethUsdSnapshot,
        uint256 virtualEth,
        uint256 raiseTarget
    );
    event Buy(
        address indexed token,
        address indexed buyer,
        uint256 ethIn,
        uint256 tokensOut,
        uint256 newRealEth,
        uint256 newPriceWeiPerToken
    );
    event Sell(
        address indexed token,
        address indexed seller,
        uint256 tokensIn,
        uint256 ethOut,
        uint256 newRealEth,
        uint256 newPriceWeiPerToken
    );
    event ReadyToGraduate(address indexed token, uint256 realEth);
    event Graduated(
        address indexed token,
        address indexed pair,
        uint256 lpEth,
        uint256 lpTokens,
        uint256 treasuryEth,
        uint256 liquidityBurned
    );
    event FeeCollected(address indexed token, uint256 amount);
    event TreasuryEscrowed(uint256 amount);
    event PriceUpdated(uint256 ethUsdPrice);
    event OwnerChanged(address indexed newOwner);
    event KeeperChanged(address indexed newKeeper);
    event TreasuryChanged(address indexed newTreasury);
    event ParamsChanged(uint256 creationFee, uint256 tradeFeeBps);
    event FeeRecipientReassigned(address indexed token, address indexed oldRecipient, address indexed newRecipient);

    /*//////////////////////////////////////////////////////////////
                              REENTRANCY GUARD
    //////////////////////////////////////////////////////////////*/

    uint256 private _locked = 1;

    modifier nonReentrant() {
        require(_locked == 1, "REENTRANCY");
        _locked = 2;
        _;
        _locked = 1;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "NOT_OWNER");
        _;
    }

    modifier onlyKeeperOrOwner() {
        require(msg.sender == owner || msg.sender == keeper, "NOT_KEEPER");
        _;
    }

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _router, address _treasury, uint256 _ethUsdPrice) {
        require(_router != address(0) && _treasury != address(0), "ZERO_ADDR");
        require(_ethUsdPrice > 0, "ZERO_PRICE");
        owner = msg.sender;
        treasury = _treasury;
        ethUsdPrice = _ethUsdPrice;
        tradeFeeBps = 100; // 1% default

        router = IUniswapV2Router02(_router);
        WETH = IUniswapV2Router02(_router).WETH();
        uniFactory = IUniswapV2Factory(IUniswapV2Router02(_router).factory());
    }

    /*//////////////////////////////////////////////////////////////
                               ADMIN
    //////////////////////////////////////////////////////////////*/

    /// @notice Set the keeper (hot key). onlyOwner (multisig). Keeper can ONLY nudge the price
    ///         within a band — never touch funds, fees, treasury, or CTO.
    function setKeeper(address _keeper) external onlyOwner {
        keeper = _keeper;
        emit KeeperChanged(_keeper);
    }

    /// @notice Update ETH/USD price. OWNER (multisig) may set any value. KEEPER (hot key) may only
    ///         move it within +/-MAX_KEEPER_MOVE_BPS of the current price per call.
    function setEthUsdPrice(uint256 _price) external {
        require(_price > 0, "ZERO_PRICE");
        if (msg.sender != owner) {
            require(msg.sender == keeper, "NOT_KEEPER");
            uint256 cur = ethUsdPrice;
            uint256 delta = (cur * MAX_KEEPER_MOVE_BPS) / 10_000;
            require(_price <= cur + delta && _price + delta >= cur, "PRICE_OUT_OF_BAND");
        }
        ethUsdPrice = _price;
        emit PriceUpdated(_price);
    }

    /// @notice Push the current ETH/USD price into an already-graduated token so its $5 auto-swap
    ///         trigger doesn't drift as ETH moves (the token's setter is onlyFactory).
    function refreshTokenPrice(address token) external onlyKeeperOrOwner {
        RobinToken(payable(token)).setEthUsdPrice(ethUsdPrice);
    }

    function setOwner(address _owner) external onlyOwner {
        require(_owner != address(0), "ZERO_ADDR");
        owner = _owner;
        emit OwnerChanged(_owner);
    }

    function setTreasury(address _treasury) external onlyOwner {
        require(_treasury != address(0), "ZERO_ADDR");
        treasury = _treasury;
        emit TreasuryChanged(_treasury);
    }

    function setParams(uint256 _creationFee, uint256 _tradeFeeBps) external onlyOwner {
        require(_tradeFeeBps <= MAX_TRADE_FEE_BPS, "FEE_TOO_HIGH");
        creationFee = _creationFee;
        tradeFeeBps = _tradeFeeBps;
        emit ParamsChanged(_creationFee, _tradeFeeBps);
    }

    /// @notice CTO: redirect a token's fee recipient. onlyOwner (multisig). Team reviews off-chain;
    ///         approval calls this. ONLY changes the destination — cannot mint, touch the curve, or
    ///         change the 0.5/0.5 split. Updates BOTH the curve fee and the DEX auto-swap.
    function reassignFeeRecipient(address token, address newRecipient) external onlyOwner {
        Curve storage c = curves[token];
        require(c.creator != address(0), "UNKNOWN_TOKEN");
        require(newRecipient != address(0), "ZERO_ADDR");
        address old = c.feeRecipient;
        c.feeRecipient = newRecipient;
        RobinToken(payable(token)).setFeeRecipient(newRecipient);
        emit FeeRecipientReassigned(token, old, newRecipient);
    }

    /// @notice Recover ETH that is not backing any live curve (dust, stray sends, escrow already
    ///         accounted separately). Cannot touch live curves' realEth or treasury escrow.
    function sweepOrphanedETH(address to) external onlyOwner nonReentrant {
        require(to != address(0), "ZERO_ADDR");
        uint256 reserved = totalLiveRealEth + treasuryEscrow;
        uint256 bal = address(this).balance;
        require(bal > reserved, "NOTHING_TO_SWEEP");
        _safeTransferETH(to, bal - reserved);
    }

    /// @notice Treasury (or owner) pulls escrowed payouts that failed to push.
    function claimTreasuryEscrow() external nonReentrant {
        require(msg.sender == treasury || msg.sender == owner, "NOT_TREASURY");
        uint256 amt = treasuryEscrow;
        require(amt > 0, "NOTHING");
        treasuryEscrow = 0;
        _safeTransferETH(treasury, amt);
    }

    /*//////////////////////////////////////////////////////////////
                              VIEW HELPERS
    //////////////////////////////////////////////////////////////*/

    function allTokensLength() external view returns (uint256) {
        return allTokens.length;
    }

    function _usdToWei(uint256 usd8, uint256 price8) internal pure returns (uint256) {
        return (usd8 * 1e18) / price8;
    }

    function quoteBuy(address token, uint256 ethIn) public view returns (uint256 tokensOut) {
        Curve storage c = curves[token];
        require(!c.graduated && !c.readyToGraduate && c.creator != address(0), "NOT_TRADABLE");
        uint256 fee = (ethIn * tradeFeeBps) / 10_000;
        uint256 netEth = ethIn - fee;
        tokensOut = _getTokensOut(c, netEth);
    }

    function quoteSell(address token, uint256 tokensIn) public view returns (uint256 ethOut) {
        Curve storage c = curves[token];
        require(!c.graduated && !c.readyToGraduate && c.creator != address(0), "NOT_TRADABLE");
        uint256 grossEth = _getEthOut(c, tokensIn);
        uint256 fee = (grossEth * tradeFeeBps) / 10_000;
        ethOut = grossEth - fee;
    }

    function currentPrice(address token) external view returns (uint256) {
        Curve storage c = curves[token];
        if (c.creator == address(0)) return 0;
        uint256 x = c.virtualEth + c.realEth;
        return (x * 1e18) / c.tokenReserve;
    }

    /*//////////////////////////////////////////////////////////////
                              CURVE MATH
    //////////////////////////////////////////////////////////////*/

    function _getTokensOut(Curve storage c, uint256 dEth) internal view returns (uint256) {
        uint256 x = c.virtualEth + c.realEth;
        uint256 newX = x + dEth;
        uint256 newY = c.k / newX;
        return c.tokenReserve - newY;
    }

    function _getEthOut(Curve storage c, uint256 dTok) internal view returns (uint256) {
        uint256 y = c.tokenReserve;
        uint256 newY = y + dTok;
        uint256 x = c.virtualEth + c.realEth;
        uint256 newX = c.k / newY;
        return x - newX;
    }

    /*//////////////////////////////////////////////////////////////
                              CREATE TOKEN
    //////////////////////////////////////////////////////////////*/

    /// @param feeRecipient where the creator's half of the trade fee is paid (on the curve AND on
    ///        the post-graduation DEX auto-swap). Pass address(0) to default it to the caller.
    function createToken(
        string calldata name,
        string calldata symbol,
        uint256 initialBuyEth,
        address feeRecipient,
        bytes32 salt
    )
        external
        payable
        nonReentrant
        returns (address token)
    {
        uint256 nl = bytes(name).length;
        uint256 sl = bytes(symbol).length;
        require(nl > 0 && nl <= MAX_NAME_LEN, "BAD_NAME");
        require(sl > 0 && sl <= MAX_SYMBOL_LEN, "BAD_SYMBOL");
        require(msg.value >= creationFee + initialBuyEth, "INSUFFICIENT_ETH");
        uint256 price8 = ethUsdPrice;

        // default the fee recipient to the caller when not specified
        address recipient = feeRecipient == address(0) ? msg.sender : feeRecipient;

        // token carries a 1% fee-on-transfer (0.5% feeRecipient / 0.5% treasury) that applies on the
        // DEX after graduation; the factory is fee-exempt so curve trades stay exact.
        RobinToken t = new RobinToken{salt: salt}(name, symbol, TOTAL_SUPPLY, msg.sender, recipient, treasury);
        require(uint16(uint160(address(t))) == VANITY_SUFFIX, "BAD_SUFFIX");
        token = address(t);

        uint256 virtualEth = _usdToWei(VIRTUAL_USD_RESERVE, price8);
        uint256 raiseTarget = _usdToWei(RAISE_USD, price8);
        uint256 treasuryEth = _usdToWei(TREASURY_USD, price8);
        // Derive lpEth as the remainder so lpEth + treasuryEth == raiseTarget exactly
        // (eliminates the independent-flooring dust the audit flagged).
        uint256 lpEth = raiseTarget - treasuryEth;

        // y0 = CURVE_SUPPLY * (virtualEth + raiseTarget) / raiseTarget
        uint256 y0 = (CURVE_SUPPLY * (virtualEth + raiseTarget)) / raiseTarget;
        uint256 k = virtualEth * y0;

        curves[token] = Curve({
            virtualEth: virtualEth,
            realEth: 0,
            tokenReserve: y0,
            raiseTarget: raiseTarget,
            lpEth: lpEth,
            treasuryEth: treasuryEth,
            k: k,
            readyToGraduate: false,
            graduated: false,
            creator: msg.sender,
            feeRecipient: recipient
        });
        allTokens.push(token);

        emit TokenCreated(token, msg.sender, name, symbol, price8, virtualEth, raiseTarget);

        if (creationFee > 0) {
            _payTreasury(creationFee);
        }

        if (initialBuyEth > 0) {
            _buy(token, msg.sender, initialBuyEth);
        }

        uint256 spent = creationFee + initialBuyEth;
        if (msg.value > spent) {
            _safeTransferETH(msg.sender, msg.value - spent);
        }
    }

    /*//////////////////////////////////////////////////////////////
                                  BUY
    //////////////////////////////////////////////////////////////*/

    function buy(address token, uint256 minTokensOut)
        external
        payable
        nonReentrant
        returns (uint256 tokensOut)
    {
        require(msg.value > 0, "ZERO_ETH");
        tokensOut = _buy(token, msg.sender, msg.value);
        require(tokensOut >= minTokensOut, "SLIPPAGE");
    }

    function _buy(address token, address buyer, uint256 ethIn) internal returns (uint256 tokensOut) {
        Curve storage c = curves[token];
        require(c.creator != address(0), "NO_TOKEN");
        require(!c.graduated && !c.readyToGraduate, "NOT_TRADABLE");

        // Cap so realEth never overshoots raiseTarget; refund the rest.
        uint256 remaining = c.raiseTarget - c.realEth;
        uint256 grossForFull =
            tradeFeeBps == 0 ? remaining : (remaining * 10_000) / (10_000 - tradeFeeBps);

        uint256 effectiveEth = ethIn;
        uint256 refund = 0;
        if (effectiveEth > grossForFull) {
            refund = effectiveEth - grossForFull;
            effectiveEth = grossForFull;
        }
        require(effectiveEth > 0, "CURVE_FULL");

        uint256 fee = (effectiveEth * tradeFeeBps) / 10_000;
        uint256 netEth = effectiveEth - fee;

        tokensOut = _getTokensOut(c, netEth);
        require(tokensOut > 0, "ZERO_OUT");

        // effects
        c.realEth += netEth;
        c.tokenReserve -= tokensOut;
        totalLiveRealEth += netEth;

        // interactions — curve trade fee split 0.5% feeRecipient / 0.5% treasury (in ETH)
        if (fee > 0) {
            _payTradeFee(c.feeRecipient, fee);
            emit FeeCollected(token, fee);
        }
        require(RobinToken(payable(token)).transfer(buyer, tokensOut), "XFER_FAIL");

        uint256 price = ((c.virtualEth + c.realEth) * 1e18) / c.tokenReserve;
        emit Buy(token, buyer, effectiveEth, tokensOut, c.realEth, price);

        if (refund > 0) {
            _safeTransferETH(buyer, refund);
        }

        // mark ready (does NOT call the DEX — graduation is finalized separately)
        if (c.realEth >= c.raiseTarget) {
            c.readyToGraduate = true;
            emit ReadyToGraduate(token, c.realEth);
        }
    }

    /*//////////////////////////////////////////////////////////////
                                  SELL
    //////////////////////////////////////////////////////////////*/

    function sell(address token, uint256 tokensIn, uint256 minEthOut)
        external
        nonReentrant
        returns (uint256 ethOut)
    {
        Curve storage c = curves[token];
        require(c.creator != address(0), "NO_TOKEN");
        require(!c.graduated && !c.readyToGraduate, "NOT_TRADABLE");
        require(tokensIn > 0, "ZERO_TOKENS");

        require(RobinToken(payable(token)).transferFrom(msg.sender, address(this), tokensIn), "XFER_FAIL");

        uint256 grossEth = _getEthOut(c, tokensIn);
        require(grossEth <= c.realEth, "INSUFFICIENT_LIQUIDITY");

        uint256 fee = (grossEth * tradeFeeBps) / 10_000;
        ethOut = grossEth - fee;
        require(ethOut >= minEthOut, "SLIPPAGE");

        // effects
        c.realEth -= grossEth;
        c.tokenReserve += tokensIn;
        totalLiveRealEth -= grossEth;

        // interactions — curve trade fee split 0.5% feeRecipient / 0.5% treasury (in ETH)
        if (fee > 0) {
            _payTradeFee(c.feeRecipient, fee);
            emit FeeCollected(token, fee);
        }
        _safeTransferETH(msg.sender, ethOut);

        uint256 price = ((c.virtualEth + c.realEth) * 1e18) / c.tokenReserve;
        emit Sell(token, msg.sender, tokensIn, ethOut, c.realEth, price);
    }

    /*//////////////////////////////////////////////////////////////
                               GRADUATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Finalize a token that has reached its raise. Permissionless — anyone (the buyer,
    ///         a keeper, the creator) can call it. Decoupled from buy so a DEX hiccup can never
    ///         brick the curve or block trading.
    function graduate(address token) external nonReentrant {
        Curve storage c = curves[token];
        require(c.readyToGraduate && !c.graduated, "NOT_READY");

        uint256 lpEth = c.lpEth;
        uint256 treasuryEth = c.treasuryEth;
        uint256 curveEth = c.realEth; // this curve's own collected ETH
        require(lpEth + treasuryEth <= curveEth, "ACCOUNTING");

        address pair = uniFactory.getPair(token, WETH);
        if (pair == address(0)) {
            pair = uniFactory.createPair(token, WETH);
        }

        // SECURITY: the normal path mints into a virgin (or dust-only) pair.
        //   * totalSupply()==0  => no one has minted. A pure donation (reserves!=0 but ts==0) is
        //     absorbed into the LP we mint and then burn — attacker just gifts the burned pool.
        //   * totalSupply()>0   => someone PRE-MINTED a position. A NEGLIGIBLE dust pre-mint is
        //     tolerated: sync() folds any donated balances into the reserves, then we require both
        //     sides to be < 1/POLLUTION_DUST_FACTOR of what we add — in that regime our mint credits
        //     us ~100% of the LP and the attacker's share rounds to zero, so the cheap grief no
        //     longer bricks graduation. A MATERIAL pre-mint still reverts and routes to
        //     graduateWithRecovery (owner). Graduation stays decoupled from buy(), so either way a
        //     hostile pre-mint can never freeze trading.
        uint256 pairTs = IUniswapV2Pair(pair).totalSupply();
        if (pairTs != 0) {
            IUniswapV2Pair(pair).sync();
            (uint112 r0, uint112 r1, ) = IUniswapV2Pair(pair).getReserves();
            (uint256 wethRes, uint256 tokRes) = IUniswapV2Pair(pair).token0() == WETH
                ? (uint256(r0), uint256(r1))
                : (uint256(r1), uint256(r0));
            require(
                wethRes * POLLUTION_DUST_FACTOR <= lpEth && tokRes * POLLUTION_DUST_FACTOR <= LP_SUPPLY,
                "PAIR_POLLUTED"
            );
        }

        // commit state (effects before interactions)
        c.graduated = true;
        c.readyToGraduate = false;
        totalLiveRealEth -= curveEth;

        // add liquidity by transferring tokens + WETH straight to the pair, then mint to ourselves.
        require(RobinToken(payable(token)).transfer(pair, LP_SUPPLY), "LP_TOKEN_XFER");
        IWETH(WETH).deposit{value: lpEth}();
        require(IWETH(WETH).transfer(pair, lpEth), "LP_WETH_XFER");
        uint256 liquidity = IUniswapV2Pair(pair).mint(address(this));
        require(liquidity > 0, "NO_LIQUIDITY");

        // BURN 100% of the LP we just minted.
        require(IUniswapV2Pair(pair).transfer(DEAD, liquidity), "LP_BURN_FAIL");

        // Wire the token's post-DEX auto-swap: now the token charges 1% on swaps, accumulates,
        // and auto-sells to ETH (50/50 creator/treasury) once worth >= $5. The pair must NOT be
        // fee-exempt (so swaps are taxed); the factory + token stay exempt.
        RobinToken(payable(token)).configureDex(address(router), pair, WETH, ethUsdPrice);

        // treasury cut: this curve's treasuryEth plus any per-curve ETH surplus (normally 0).
        uint256 treasuryPayout = treasuryEth + (curveEth - lpEth - treasuryEth);
        if (treasuryPayout > 0) {
            _payTreasury(treasuryPayout);
        }

        // burn any unsold curve tokens so they can't dilute the market
        uint256 leftoverTokens = RobinToken(payable(token)).balanceOf(address(this));
        if (leftoverTokens > 0) {
            RobinToken(payable(token)).transfer(DEAD, leftoverTokens);
        }

        emit Graduated(token, pair, lpEth, LP_SUPPLY, treasuryPayout, liquidity);
    }

    /// @notice Recovery finalization for the rare case where an attacker pre-minted a polluted
    ///         pair to block the normal path. Owner-only. Instead of donating the raise into a
    ///         poisoned pool (where a third-party LP would capture it), the full raise is returned
    ///         to the treasury, which can refund buyers or relaunch. The attacker's pre-mint is
    ///         left stranded — they only wasted their own funds. The curve token allocation is
    ///         burned so it can't be dumped. This path is NOT permissionless to avoid griefers
    ///         forcing tokens down it; it exists only as an escape hatch.
    function graduateWithRecovery(address token) external onlyOwner nonReentrant {
        Curve storage c = curves[token];
        require(c.readyToGraduate && !c.graduated, "NOT_READY");

        address pair = uniFactory.getPair(token, WETH);
        // only usable when the normal path is actually blocked by a polluted pair
        require(pair != address(0) && IUniswapV2Pair(pair).totalSupply() > 0, "USE_NORMAL");

        uint256 curveEth = c.realEth;
        c.graduated = true;
        c.readyToGraduate = false;
        totalLiveRealEth -= curveEth;

        // return the entire raise to the treasury (no value handed to the attacker's pool)
        if (curveEth > 0) {
            _payTreasury(curveEth);
        }

        // burn the LP token allocation + any unsold curve tokens
        uint256 bal = RobinToken(payable(token)).balanceOf(address(this));
        if (bal > 0) {
            RobinToken(payable(token)).transfer(DEAD, bal);
        }

        emit Graduated(token, pair, 0, 0, curveEth, 0);
    }

    /*//////////////////////////////////////////////////////////////
                                UTILS
    //////////////////////////////////////////////////////////////*/

    /// @dev Best-effort treasury push. If the treasury rejects ETH, escrow it for a later pull
    ///      instead of reverting the user's trade (prevents a single bad treasury from DoS'ing
    ///      the whole launchpad).
    function _payTreasury(uint256 amount) internal {
        if (amount == 0) return;
        (bool ok,) = treasury.call{value: amount}("");
        if (!ok) {
            treasuryEscrow += amount;
            emit TreasuryEscrowed(amount);
        }
    }

    /// @dev Split the curve trade fee (in ETH) 50/50: half to the creator's chosen feeRecipient,
    ///      half to the treasury (i.e. 0.5%/0.5% at the default 1% tradeFeeBps). Best-effort to the
    ///      recipient (a reverting recipient just forfeits to treasury), and best-effort to the
    ///      treasury (escrow fallback) — never reverts the trade.
    function _payTradeFee(address feeRecipient, uint256 fee) internal {
        if (fee == 0) return;
        uint256 toCreator = fee / 2;
        uint256 toTreasury = fee - toCreator; // remainder -> treasury
        if (toCreator > 0) {
            (bool ok,) = feeRecipient.call{value: toCreator}("");
            if (!ok) {
                // recipient can't receive -> add their share to the treasury cut
                toTreasury += toCreator;
            }
        }
        _payTreasury(toTreasury);
    }

    /// @dev Strict ETH transfer for user-facing payouts/refunds — must succeed.
    function _safeTransferETH(address to, uint256 amount) internal {
        (bool ok,) = to.call{value: amount}("");
        require(ok, "ETH_XFER_FAIL");
    }

    receive() external payable {}
}
