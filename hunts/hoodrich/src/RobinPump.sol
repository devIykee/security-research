// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * ███ RobinPump — a RobinPump launchpad ███
 *
 * Pump.fun-style bonding-curve launchpad for Robinhood Chain (ID 4663 / testnet 46630).
 *
 * Mechanics
 *  - Every token: 1,000,000,000 supply. 800M sellable on the curve, 200M reserved for the LP.
 *  - Constant-product curve with virtual reserves (pump.fun style). Price rises as people buy.
 *  - Creators pick a graduation tier at launch (e.g. 1.5 / 3.5 / 6 ETH). Each tier scales the
 *    virtual ETH reserve proportionally so the curve shape (price multiple) is identical.
 *  - When the tier's `graduationEth` is raised, trading moves to Uniswap V2: the 200M + raised
 *    ETH become a pool and the LP tokens are burned (sent to 0xdead). Nobody can rug the pool.
 *  - 1% fee on curve trades + a flat creation fee -> feeRecipient (RobinPump treasury).
 *  - The owner can NEVER withdraw curve ETH. Only fees. This is by design.
 *
 * Router note: Uniswap's router address on Robinhood Chain may not be published yet.
 * Deploy with router = address(0); tokens launch and trade on the curve normally.
 * Graduated tokens queue as "pending" until the owner calls setRouter() once, then
 * finalizeGraduation(token) for each pending token.
 *
 * ⚠ UNAUDITED. Test on Robinhood Chain testnet (46630, faucet available) before mainnet.
 */

interface IUniswapV2Router02 {
    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external payable returns (uint256 amountToken, uint256 amountETH, uint256 liquidity);
}

/* ─────────────────────────── Minimal ERC-20 ─────────────────────────── */

contract RobinPumpToken {
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor(string memory _name, string memory _symbol, uint256 _supply, address _to) {
        name = _name;
        symbol = _symbol;
        totalSupply = _supply;
        balanceOf[_to] = _supply;
        emit Transfer(address(0), _to, _supply);
    }

    function transfer(address to, uint256 value) external returns (bool) {
        return _transfer(msg.sender, to, value);
    }

    function transferFrom(address from, address to, uint256 value) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            require(allowed >= value, "allowance");
            allowance[from][msg.sender] = allowed - value;
        }
        return _transfer(from, to, value);
    }

    function approve(address spender, uint256 value) external returns (bool) {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function _transfer(address from, address to, uint256 value) internal returns (bool) {
        require(balanceOf[from] >= value, "balance");
        unchecked {
            balanceOf[from] -= value;
            balanceOf[to] += value;
        }
        emit Transfer(from, to, value);
        return true;
    }
}

/* ─────────────────────────── Launchpad ─────────────────────────── */

contract RobinPump {
    /* ── Token economics (fixed) ── */
    uint256 public constant TOTAL_SUPPLY = 1_000_000_000e18;
    uint256 public constant CURVE_SUPPLY = 800_000_000e18;   // sellable on the curve
    uint256 public constant LP_SUPPLY    = 200_000_000e18;   // paired with raised ETH at graduation
    uint256 public constant VIRTUAL_TOKEN_START = 1_073_000_000e18; // virtual token reserve
    uint256 public constant FEE_BPS = 100;                    // 1% on curve trades
    address public constant DEAD = 0x000000000000000000000000000000000000dEaD;

    /* ── Deployment config ── */
    address public owner;
    address public feeRecipient;      // RobinPump treasury
    address public router;            // Uniswap V2 router (settable once known)
    uint256 public creationFee;                 // e.g. 0.0005 ether
    uint256 public immutable gradFeeBps;        // e.g. 200 = 2% of raise at graduation

    /* ── Graduation tiers (picked per token at creation) ── */
    struct Tier {
        uint128 virtualEthStart;  // virtual ETH reserve the curve starts with
        uint128 graduationEth;    // real ETH raised -> graduate
    }
    Tier[] public tiers;

    struct Curve {
        address creator;
        uint128 ethReserve;     // virtual ETH + real ETH in curve
        uint128 tokenReserve;   // virtual token reserve
        uint128 realEth;        // actual ETH held for this token
        bool graduated;         // curve trading closed
        bool lpCreated;         // Uniswap pool live, LP burned
        string metadataURI;     // image / description JSON (IPFS or https)
        uint128 graduationEth;  // this token's graduation target (from its tier)
    }

    mapping(address => Curve) public curves;
    address[] public allTokens;

    uint256 private _lock = 1;
    modifier nonReentrant() {
        require(_lock == 1, "reentrancy");
        _lock = 2;
        _;
        _lock = 1;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    event TokenCreated(address indexed token, address indexed creator, string name, string symbol, string metadataURI, uint256 graduationEth);
    event TierAdded(uint256 indexed tierId, uint256 virtualEthStart, uint256 graduationEth);
    event Trade(address indexed token, address indexed trader, bool isBuy, uint256 ethAmount, uint256 tokenAmount, uint256 newPriceX18);
    event Graduated(address indexed token, uint256 ethRaised);
    event PoolCreated(address indexed token, uint256 ethToLp, uint256 tokensToLp);

    constructor(
        address _feeRecipient,
        uint256 _creationFee,           // suggested: 0.0005 ether (500000000000000)
        uint256 _gradFeeBps,            // suggested: 200 (2%)
        uint256[] memory _tierVirtualEth,   // e.g. [0.515e18, 1.2e18, 2.06e18]
        uint256[] memory _tierGraduationEth // e.g. [1.5e18, 3.5e18, 6e18]
    ) {
        require(_feeRecipient != address(0), "fee recipient");
        require(_gradFeeBps <= 500, "grad fee too high");
        require(_tierVirtualEth.length > 0, "no tiers");
        require(_tierVirtualEth.length == _tierGraduationEth.length, "tier length");
        owner = msg.sender;
        feeRecipient = _feeRecipient;
        creationFee = _creationFee;
        gradFeeBps = _gradFeeBps;
        for (uint256 i = 0; i < _tierVirtualEth.length; i++) {
            _addTier(_tierVirtualEth[i], _tierGraduationEth[i]);
        }
    }

    function _addTier(uint256 _virtualEth, uint256 _graduationEth) internal {
        require(_virtualEth > 0 && _graduationEth > 0, "tier zero");
        require(_virtualEth <= type(uint128).max && _graduationEth <= type(uint128).max, "tier overflow");
        // The curve must be able to actually raise the target before selling out:
        // maxRaise = virtualEth * CURVE_SUPPLY / (VIRTUAL_TOKEN_START - CURVE_SUPPLY)
        uint256 maxRaise = (_virtualEth * CURVE_SUPPLY) / (VIRTUAL_TOKEN_START - CURVE_SUPPLY);
        require(_graduationEth <= maxRaise, "target unreachable");
        tiers.push(Tier({ virtualEthStart: uint128(_virtualEth), graduationEth: uint128(_graduationEth) }));
        emit TierAdded(tiers.length - 1, _virtualEth, _graduationEth);
    }

    /* ─────────────── Create ─────────────── */

    /// Create a token. Any ETH sent beyond the creation fee becomes the creator's first buy.
    function createToken(
        string calldata name_,
        string calldata symbol_,
        string calldata metadataURI_,
        uint256 minTokensOut,         // slippage guard for the optional initial buy (0 if none)
        uint256 tierId                // graduation tier index (see tiers())
    ) external payable nonReentrant returns (address token) {
        require(msg.value >= creationFee, "creation fee");
        require(tierId < tiers.length, "bad tier");
        Tier memory tier = tiers[tierId];

        token = address(new RobinPumpToken(name_, symbol_, TOTAL_SUPPLY, address(this)));

        curves[token] = Curve({
            creator: msg.sender,
            ethReserve: tier.virtualEthStart,
            tokenReserve: uint128(VIRTUAL_TOKEN_START),
            realEth: 0,
            graduated: false,
            lpCreated: false,
            metadataURI: metadataURI_,
            graduationEth: tier.graduationEth
        });
        allTokens.push(token);

        _pay(feeRecipient, creationFee);
        emit TokenCreated(token, msg.sender, name_, symbol_, metadataURI_, tier.graduationEth);

        uint256 buyAmount = msg.value - creationFee;
        if (buyAmount > 0) {
            _buy(token, msg.sender, buyAmount, minTokensOut);
        }
    }

    /* ─────────────── Trade ─────────────── */

    function buy(address token, uint256 minTokensOut) external payable nonReentrant {
        require(msg.value > 0, "no eth");
        _buy(token, msg.sender, msg.value, minTokensOut);
    }

    function _buy(address token, address buyer, uint256 ethIn, uint256 minTokensOut) internal {
        Curve storage c = curves[token];
        require(c.creator != address(0), "unknown token");
        require(!c.graduated, "graduated - trade on DEX");

        uint256 net = ethIn - (ethIn * FEE_BPS) / 10_000;
        uint256 tokensOut;
        uint256 refund;
        {
            // scoped to keep the stack shallow
            uint256 er = c.ethReserve;
            uint256 tr = c.tokenReserve;
            uint256 k = er * tr;
            tokensOut = tr - (k / (er + net));

            // Cap at remaining curve supply; refund unused ETH on the final fill.
            uint256 remaining = CURVE_SUPPLY - (VIRTUAL_TOKEN_START - tr);
            if (tokensOut > remaining) {
                tokensOut = remaining;
                uint256 needed = (k / (tr - tokensOut)) - er; // net ETH for exact fill
                refund = ethIn - needed - (needed * FEE_BPS) / 10_000;
                net = needed;
            }
        }

        require(tokensOut >= minTokensOut, "slippage");
        require(tokensOut > 0, "dust");

        c.ethReserve += uint128(net);
        c.tokenReserve -= uint128(tokensOut);
        c.realEth += uint128(net);

        RobinPumpToken(token).transfer(buyer, tokensOut);
        _pay(feeRecipient, ethIn - net - refund); // the fee, by construction
        if (refund > 0) _pay(buyer, refund);

        emit Trade(token, buyer, true, net, tokensOut, _priceX18(c));

        uint256 nowSold = VIRTUAL_TOKEN_START - c.tokenReserve;
        if (nowSold >= CURVE_SUPPLY || c.realEth >= c.graduationEth) {
            _graduate(token, c);
        }
    }

    function sell(address token, uint256 tokenAmount, uint256 minEthOut) external nonReentrant {
        Curve storage c = curves[token];
        require(c.creator != address(0), "unknown token");
        require(!c.graduated, "graduated - trade on DEX");
        require(tokenAmount > 0, "no tokens");

        RobinPumpToken(token).transferFrom(msg.sender, address(this), tokenAmount);

        uint256 ethReserve = c.ethReserve;
        uint256 tokenReserve = c.tokenReserve;
        uint256 k = ethReserve * tokenReserve;

        uint256 grossOut = ethReserve - (k / (tokenReserve + tokenAmount));
        require(grossOut <= c.realEth, "curve drained");

        uint256 fee = (grossOut * FEE_BPS) / 10_000;
        uint256 net = grossOut - fee;
        require(net >= minEthOut, "slippage");

        c.ethReserve = uint128(ethReserve - grossOut);
        c.tokenReserve = uint128(tokenReserve + tokenAmount);
        c.realEth -= uint128(grossOut);

        _pay(msg.sender, net);
        _pay(feeRecipient, fee);

        emit Trade(token, msg.sender, false, net, tokenAmount, _priceX18(c));
    }

    /* ─────────────── Graduation ─────────────── */

    function _graduate(address token, Curve storage c) internal {
        c.graduated = true;
        emit Graduated(token, c.realEth);
        if (router != address(0)) {
            _createPool(token, c);
        }
        // else: pending — owner sets router then calls finalizeGraduation(token)
    }

    /// Finalize any token that graduated before the router was configured.
    function finalizeGraduation(address token) external nonReentrant {
        Curve storage c = curves[token];
        require(c.graduated && !c.lpCreated, "not pending");
        require(router != address(0), "router unset");
        _createPool(token, c);
    }

    function _createPool(address token, Curve storage c) internal {
        c.lpCreated = true;

        uint256 raise = c.realEth;
        uint256 gradFee = (raise * gradFeeBps) / 10_000;
        uint256 ethForLp = raise - gradFee;
        c.realEth = 0;

        // Burn any unsold curve tokens so circulating supply math stays honest.
        uint256 sold = VIRTUAL_TOKEN_START - c.tokenReserve;
        uint256 unsold = CURVE_SUPPLY > sold ? CURVE_SUPPLY - sold : 0;
        if (unsold > 0) RobinPumpToken(token).transfer(DEAD, unsold);

        RobinPumpToken(token).approve(router, LP_SUPPLY);
        IUniswapV2Router02(router).addLiquidityETH{value: ethForLp}(
            token, LP_SUPPLY, 0, 0, DEAD, block.timestamp
        );

        _pay(feeRecipient, gradFee);
        emit PoolCreated(token, ethForLp, LP_SUPPLY);
    }

    /* ─────────────── Views (frontend helpers) ─────────────── */

    function tokenCount() external view returns (uint256) { return allTokens.length; }

    function getTokens(uint256 start, uint256 count) external view returns (address[] memory out) {
        uint256 n = allTokens.length;
        if (start >= n) return new address[](0);
        uint256 end = start + count > n ? n : start + count;
        out = new address[](end - start);
        for (uint256 i = start; i < end; i++) out[i - start] = allTokens[i];
    }

    function quoteBuy(address token, uint256 ethIn) external view returns (uint256 tokensOut) {
        Curve storage c = curves[token];
        uint256 net = ethIn - (ethIn * FEE_BPS) / 10_000;
        uint256 k = uint256(c.ethReserve) * c.tokenReserve;
        tokensOut = c.tokenReserve - (k / (c.ethReserve + net));
        uint256 remaining = CURVE_SUPPLY - (VIRTUAL_TOKEN_START - c.tokenReserve);
        if (tokensOut > remaining) tokensOut = remaining;
    }

    function quoteSell(address token, uint256 tokenAmount) external view returns (uint256 ethOut) {
        Curve storage c = curves[token];
        uint256 k = uint256(c.ethReserve) * c.tokenReserve;
        uint256 gross = c.ethReserve - (k / (c.tokenReserve + tokenAmount));
        ethOut = gross - (gross * FEE_BPS) / 10_000;
    }

    /// Price in ETH per token, scaled by 1e18.
    function price(address token) external view returns (uint256) {
        return _priceX18(curves[token]);
    }

    /// 0–10000 basis points of progress toward graduation.
    function progressBps(address token) external view returns (uint256) {
        Curve storage c = curves[token];
        if (c.graduated) return 10_000;
        if (c.graduationEth == 0) return 0;
        uint256 p = (uint256(c.realEth) * 10_000) / c.graduationEth;
        return p > 10_000 ? 10_000 : p;
    }

    function tierCount() external view returns (uint256) { return tiers.length; }

    function getTiers() external view returns (Tier[] memory) { return tiers; }

    function _priceX18(Curve storage c) internal view returns (uint256) {
        return (uint256(c.ethReserve) * 1e18) / c.tokenReserve;
    }

    /* ─────────────── Admin (no curve-fund access, ever) ─────────────── */

    function setRouter(address _router) external onlyOwner {
        require(_router != address(0), "zero");
        router = _router;
    }

    /// Add a new graduation tier (existing tiers can never be changed or removed).
    function addTier(uint256 _virtualEth, uint256 _graduationEth) external onlyOwner {
        _addTier(_virtualEth, _graduationEth);
    }

    function setFeeRecipient(address _r) external onlyOwner {
        require(_r != address(0), "zero");
        feeRecipient = _r;
    }

    function setCreationFee(uint256 _fee) external onlyOwner {
        require(_fee <= 0.01 ether, "too high");
        creationFee = _fee;
    }

    function transferOwnership(address _o) external onlyOwner {
        require(_o != address(0), "zero");
        owner = _o;
    }

    function _pay(address to, uint256 amount) internal {
        if (amount == 0) return;
        (bool ok, ) = to.call{value: amount}("");
        require(ok, "eth transfer failed");
    }

    receive() external payable {
        revert("use buy()");
    }
}
