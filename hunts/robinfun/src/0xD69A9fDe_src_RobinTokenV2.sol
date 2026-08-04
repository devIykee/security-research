// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IUniswapV2Router02, IUniswapV2Pair} from "./interfaces/IUniswapV2.sol";

/// @title RobinToken
/// @notice Fixed-supply ERC20 with a 1% fee-on-transfer that, after graduation, is auto-swapped
///         to ETH and split 50/50 creator / treasury.
///
///         BEFORE graduation: the factory is fee-exempt, so all curve trades and the initial
///         liquidity add use exact amounts. The curve trade fee is taken in ETH by the factory.
///
///         AFTER graduation (token live on Uniswap V2): every non-exempt transfer (i.e. swaps)
///         charges 1%, accumulating tokens in THIS contract. When the accumulated tokens are worth
///         at least $5 (valued via the live pool reserves + the factory's ethUsdPrice), the
///         contract sells them for ETH and pays the creator and treasury 50/50 in ETH.
///
///         The auto-swap only runs when `from` is NOT the pair (i.e. on sells / normal transfers),
///         never inside a buy, to avoid reentering the pair mid-swap.
contract RobinTokenV2 {
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;

    uint256 public immutable totalSupply;

    address public immutable factory;
    address public immutable creator;
    /// @notice where the creator's 50% of the post-DEX auto-swap fee is sent. Chosen by the creator
    ///         at launch (defaults to the creator if they didn't pick a different address).
    address public feeRecipient; // mutable ONLY via factory CTO (was immutable)
    address public immutable treasury;

    uint256 public constant FEE_BPS = 100; // 1% total

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    mapping(address => bool) public feeExempt;

    // --- DEX auto-swap config (set by factory at graduation) ---
    IUniswapV2Router02 public router;
    address public pair;
    address public weth;
    bool public dexLive; // true once graduated & pair is set

    /// @notice USD price of ETH with 8 decimals (snapshotted at graduation; mirrors the factory).
    uint256 public ethUsdPrice8;

    /// @notice swap-back threshold in USD (8 decimals). $5 = 5e8.
    uint256 public constant SWAP_THRESHOLD_USD = 5 * 1e8;

    bool private _swapping; // reentrancy guard for the auto-swap

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event FeeSwapped(uint256 tokensSold, uint256 ethToCreator, uint256 ethToTreasury);
    event DexConfigured(address pair, address router);

    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _supply,
        address _creator,
        address _feeRecipient,
        address _treasury
    ) {
        name = _name;
        symbol = _symbol;
        totalSupply = _supply;
        factory = msg.sender;
        creator = _creator;
        // fall back to the creator if no explicit recipient was chosen
        feeRecipient = _feeRecipient == address(0) ? _creator : _feeRecipient;
        treasury = _treasury;

        feeExempt[msg.sender] = true; // factory exempt -> exact curve + liquidity math
        feeExempt[address(this)] = true; // this contract (holds + sells fee tokens) exempt

        balanceOf[msg.sender] = _supply;
        emit Transfer(address(0), msg.sender, _supply);
    }

    modifier onlyFactory() {
        require(msg.sender == factory, "ONLY_FACTORY");
        _;
    }

    function setFeeExempt(address account, bool exempt) external onlyFactory {
        feeExempt[account] = exempt;
    }

    /// @notice Called by the factory at graduation to wire up the DEX auto-swap.
    function configureDex(address _router, address _pair, address _weth, uint256 _ethUsdPrice8)
        external
        onlyFactory
    {
        require(!dexLive, "ALREADY_CONFIGURED"); // graduation is one-time
        router = IUniswapV2Router02(_router);
        pair = _pair;
        weth = _weth;
        ethUsdPrice8 = _ethUsdPrice8;
        dexLive = true;
        // approve router once to sell accumulated fee tokens
        allowance[address(this)][_router] = type(uint256).max;
        emit Approval(address(this), _router, type(uint256).max);
        emit DexConfigured(_pair, _router);
    }

    /// @notice Owner-side (factory) may refresh the ETH/USD price used for the $5 threshold.
    function setEthUsdPrice(uint256 _ethUsdPrice8) external onlyFactory {
        ethUsdPrice8 = _ethUsdPrice8;
    }

    /// @notice CTO: the factory (owner-gated) redirects where the creator's fee half is paid on the
    ///         post-graduation DEX auto-swap. Only the factory can call it.
    function setFeeRecipient(address r) external onlyFactory {
        require(r != address(0), "ZERO");
        feeRecipient = r;
    }

    function approve(address spender, uint256 value) external returns (bool) {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function transfer(address to, uint256 value) external returns (bool) {
        return _transfer(msg.sender, to, value);
    }

    function transferFrom(address from, address to, uint256 value) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            require(allowed >= value, "ERC20: insufficient allowance");
            allowance[from][msg.sender] = allowed - value;
        }
        return _transfer(from, to, value);
    }

    function _transfer(address from, address to, uint256 value) internal returns (bool) {
        require(to != address(0), "ERC20: transfer to zero");
        uint256 bal = balanceOf[from];
        require(bal >= value, "ERC20: insufficient balance");

        // Try the auto-swap BEFORE applying this transfer's fee, but only on sells (to == pair)
        // and never while already swapping or during a buy (from == pair).
        if (dexLive && !_swapping && from != pair && to == pair) {
            _maybeSwapBack();
        }

        unchecked {
            balanceOf[from] = bal - value;
        }

        // Tax ONLY DEX trades: a transfer is taxed when one side is the pair (1% per buy, 1% per
        // sell). Plain wallet-to-wallet transfers are NOT taxed. Exempt addresses are never taxed.
        uint256 fee = 0;
        bool isDexTrade = (from == pair || to == pair);
        if (isDexTrade && !feeExempt[from] && !feeExempt[to] && FEE_BPS > 0) {
            fee = (value * FEE_BPS) / 10_000;
        }

        if (fee > 0) {
            unchecked {
                balanceOf[address(this)] += fee; // accumulate fee tokens in this contract
                balanceOf[to] += value - fee;
            }
            emit Transfer(from, address(this), fee);
            emit Transfer(from, to, value - fee);
        } else {
            unchecked {
                balanceOf[to] += value;
            }
            emit Transfer(from, to, value);
        }
        return true;
    }

    /// @dev If the accumulated fee tokens are worth >= $5, sell them for ETH and pay
    ///      creator/treasury 50/50. Valued via the live pool reserves + ethUsdPrice8.
    function _maybeSwapBack() internal {
        uint256 tokenBal = balanceOf[address(this)];
        if (tokenBal == 0) return;

        // value the accumulated tokens in USD (8 dec) using the pool's ETH/token ratio
        (uint112 r0, uint112 r1,) = IUniswapV2Pair(pair).getReserves();
        address t0 = IUniswapV2Pair(pair).token0();
        uint256 tokenReserve = t0 == address(this) ? uint256(r0) : uint256(r1);
        uint256 wethReserve = t0 == address(this) ? uint256(r1) : uint256(r0);
        if (tokenReserve == 0 || wethReserve == 0) return;

        // ethValue (wei) of tokenBal at spot = tokenBal * wethReserve / tokenReserve
        uint256 ethValueWei = (tokenBal * wethReserve) / tokenReserve;
        // usdValue (8 dec) = ethValueWei * ethUsdPrice8 / 1e18
        uint256 usdValue8 = (ethValueWei * ethUsdPrice8) / 1e18;
        if (usdValue8 < SWAP_THRESHOLD_USD) return;

        // don't dump more than ~1% of the pool's token reserve in one go (limit price impact);
        // a large accumulation clears over several swaps.
        uint256 maxSell = tokenReserve / 100; // 1% of reserve
        uint256 sellAmount = tokenBal > maxSell && maxSell > 0 ? maxSell : tokenBal;

        // slippage floor: expected ETH out via constant product (0.3% pool fee), minus 10%.
        // If the real out would breach this (sandwich / thin liquidity), the swap reverts and the
        // tokens are simply retained for a later attempt — the user's transfer is never bricked.
        uint256 amountInWithFee = sellAmount * 997;
        uint256 expectedOut = (amountInWithFee * wethReserve) / (tokenReserve * 1000 + amountInWithFee);
        uint256 minOut = (expectedOut * 90) / 100; // 10% tolerance

        _swapping = true;

        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = weth;

        // sell tokens for ETH (this token is fee-exempt for its own transfers; router/pair exact).
        try router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            sellAmount, minOut, path, address(this), block.timestamp
        ) {
            // Pay out the ENTIRE ETH balance (sweeps any ETH orphaned by a prior failed payout),
            // split 50/50 between the creator's chosen feeRecipient and the treasury. Best-effort:
            // a failed leg never reverts the user's transfer.
            uint256 ethBal = address(this).balance;
            if (ethBal > 0) {
                uint256 half = ethBal / 2;
                uint256 paidCreator = 0;
                (bool okC,) = feeRecipient.call{value: half}("");
                if (okC) paidCreator = half;
                uint256 toTreasury = ethBal - paidCreator; // creator's failed share folds in
                uint256 paidTreasury = 0;
                if (toTreasury > 0) {
                    (bool okT,) = treasury.call{value: toTreasury}("");
                    if (okT) paidTreasury = toTreasury;
                }
                emit FeeSwapped(sellAmount, paidCreator, paidTreasury);
            }
        } catch {
            // swap failed (e.g. thin liquidity / slippage floor) — keep tokens for a later attempt
        }

        _swapping = false;
    }

    receive() external payable {}
}
