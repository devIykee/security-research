// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {RecurveCoin} from "./RecurveCoin.sol";
import {IUniswapV3Factory, IUniswapV3Pool, IWETH9, TickMath, LiquidityAmounts, FullMath} from "./lib/UniV3.sol";

/// @title Recurve — fair launches that live inside Uniswap from block one.
///
/// A Uniswap V3 range placed ENTIRELY ABOVE spot holds only the token — no ETH
/// required. As buyers push price up through that range the tokens convert into
/// ETH inside the pool. That is mathematically a bonding curve, except it's a
/// real WETH pair from the first block: instantly chartable, instantly routable,
/// instantly indexed by every terminal. There is no separate curve contract and
/// no migration step to get wrong.
///
/// Consequences that matter:
///   • We never custody user ETH — Uniswap does.
///   • LP is locked by construction: burn() is never called and isn't reachable,
///     so collect() can only ever return accrued fees, never principal.
///
/// "Graduation" is a read-only status, not a mechanic: a coin has graduated once
/// GRADUATION_THRESHOLD of WETH has been bought into its locked position (~$43k
/// mcap at the launch floor). graduationStatus() computes it live from pool
/// state. Nothing happens on-chain when a coin graduates — the liquidity was
/// already locked from block one. It's a signal for traders and terminals.
///
/// Not upgradeable. No admin withdrawal. No mint. No pause on trading.
///
/// There IS an owner, deliberately limited to things that cannot reach a holder
/// or a live coin:
///
///   setTreasury            — where OUR cut lands
///   setLaunchFee           — the ~$1 launch fee, capped at MAX_LAUNCH_FEE
///   setCreatorBps          — the split for FUTURE coins, floored at MIN_CREATOR_BPS
///   setGraduationThreshold — the bar for FUTURE coins, bounded MIN/MAX
///   setLaunchEnabled       — pauses NEW launches; live coins keep trading regardless
///   transferOwnership / renounceOwnership
///
/// Everything that touches an existing coin is SNAPSHOTTED at launch
/// (tokenCreatorBps, feeMode, tokenGraduationThreshold). Once a coin exists its
/// economics are frozen — the owner cannot reach back and change what a creator
/// earns, how its fees behave, or when it graduates.
contract RecurveLaunchpad {
    uint256 public constant TOTAL_SUPPLY = 1_000_000_000e18;

    /// 1% tier / 200 spacing — the chain convention, and wide spacing keeps the
    /// launch range cheap to cross.
    uint24 public constant POOL_FEE = 10_000;
    int24 internal constant TICK_SPACING = 200;

    /// Opening tick, matched to Pons on-chain (verified): −204,200. For a coin
    /// that sorts as token0 the range is [INITIAL_TICK, MAX], mirrored otherwise.
    /// ~$2,550 opening market cap at 1B supply (ETH-denominated; drifts with ETH).
    int24 public constant INITIAL_TICK = -204_200;

    /// The range runs from the opening tick to the far edge of what Uniswap
    /// allows — there is no upper bound on price, so a coin that runs never hits
    /// a wall. Both pads on this chain run to the limit; Pons leaves 72 ticks.
    int24 internal constant MAX_USABLE_TICK = 887_200; // MAX_TICK (887272) floored to spacing
    int24 internal constant MIN_USABLE_TICK = -887_200;

    /// Creator's cut of collected pool fees, in bps. Pons pays 70% (verified);
    /// we pay 90%. Adjustable for FUTURE launches only, and floored: even a
    /// stolen owner key cannot push a creator below MIN_CREATOR_BPS, nor touch a
    /// coin that already exists.
    uint256 public constant MIN_CREATOR_BPS = 5_000; // creators always keep >= 50%
    uint256 public creatorBps = 9_000; // 90%
    uint256 internal constant BPS = 10_000;
    uint256 internal constant Q128 = 1 << 128;

    /// The split each coin launched with. Frozen at create(); read at collect().
    mapping(address => uint256) public tokenCreatorBps;

    /// WETH bought into the locked position at which a coin is "graduated".
    /// Matched to Pons: 4.2 ETH (~$43k mcap). Adjustable for FUTURE launches,
    /// bounded, and snapshotted per coin so a coin graduates at the bar it
    /// launched with.
    uint256 public constant MAX_GRADUATION = 25 ether;
    uint256 public constant MIN_GRADUATION = 0.5 ether;
    uint256 public graduationThreshold = 4.2 ether; // matches Pons
    mapping(address => uint256) public tokenGraduationThreshold;

    /// Flat fee to launch, ~$1 at ~$1.9k ETH. Revenue that doesn't depend on the
    /// token ever trading, and anti-spam. Capped at MAX_LAUNCH_FEE, so
    /// setLaunchFee can only ever LOWER it — "it stays <= ~$1" is enforced by the
    /// bytecode, not promised.
    uint256 public constant MAX_LAUNCH_FEE = 0.0005 ether; // ~$1 — can go to 0, never above
    uint256 public launchFee = 0.0005 ether;

    /// New launches can be paused. Existing coins are unaffected — they live in
    /// Uniswap and never call back into this contract to trade.
    bool public launchEnabled = true;

    address public treasury;
    address public owner;
    address public pendingOwner;
    IUniswapV3Factory public immutable factory;
    IWETH9 public immutable weth;

    /// What happens to the TOKEN side of collected pool fees. Uniswap V3 charges
    /// its fee in each swap's input token, so buys accrue WETH and sells accrue
    /// tokens — roughly half the fees are the coin itself. Chosen by the creator
    /// at launch and frozen. The WETH side always pays creator/treasury per
    /// tokenCreatorBps in both modes.
    enum FeeMode {
        Burn, // token side -> DEAD. Sells shrink supply; creator earns from buys.
        Keep  // token side -> creator/treasury, as tokens.
    }

    address internal constant DEAD = 0x000000000000000000000000000000000000dEaD;

    struct Launch {
        address pool;
        address creator;
        int24 tickLower;
        int24 tickUpper;
        bool exists;
        FeeMode feeMode;
    }

    mapping(address => Launch) public launches;
    address[] public allTokens;

    event TokenCreated(
        address indexed token,
        address indexed creator,
        address indexed pool,
        string name,
        string symbol,
        string metadataURI,
        int24 tickLower,
        int24 tickUpper,
        FeeMode feeMode
    );
    event DevBuy(address indexed token, address indexed creator, uint256 ethIn, uint256 tokensOut);
    event FeesCollected(address indexed token, address indexed creator, uint256 creator0, uint256 creator1, uint256 treasury0, uint256 treasury1);
    event TreasurySet(address treasury);
    event LaunchFeeSet(uint256 fee);
    event CreatorBpsSet(uint256 bps);
    event GraduationThresholdSet(uint256 threshold);
    event LaunchEnabledSet(bool enabled);
    event OwnershipTransferred(address indexed from, address indexed to);
    event CreatorTransferred(address indexed token, address indexed from, address indexed to);
    event CreatorReassigned(address indexed token, address indexed from, address indexed to);

    error ZeroInput();
    error Exists();
    error NotFound();
    error PoolTaken();
    error TransferFailed();
    error Reentrancy();
    error Slippage();
    error FeeTooLow();
    error NotOwner();
    error NotCreator();
    error LaunchesDisabled();
    error BadParam();

    uint256 private _lock = 1;
    modifier nonReentrant() {
        if (_lock != 1) revert Reentrancy();
        _lock = 2;
        _;
        _lock = 1;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    /// @param _owner  Set explicitly rather than defaulting to msg.sender. The
    ///                deploying key is a throwaway holding a few dollars of gas;
    ///                it should never hold the setters, not even briefly.
    constructor(address _owner, address _treasury, address _factory, address _weth) {
        if (_owner == address(0) || _treasury == address(0) || _factory == address(0) || _weth == address(0)) {
            revert ZeroInput();
        }
        treasury = _treasury;
        factory = IUniswapV3Factory(_factory);
        weth = IWETH9(_weth);
        owner = _owner;
        emit OwnershipTransferred(address(0), _owner);
    }

    // ── owner ──────────────────────────────────────────────────────────────
    // Nothing below can touch a live coin, a holder's balance, or the LP.

    /// @notice Where our share of fees lands. Cannot affect creators.
    function setTreasury(address t) external onlyOwner {
        if (t == address(0)) revert ZeroInput();
        treasury = t;
        emit TreasurySet(t);
    }

    /// @notice Launch fee for FUTURE launches. Hard-capped at MAX_LAUNCH_FEE.
    function setLaunchFee(uint256 f) external onlyOwner {
        if (f > MAX_LAUNCH_FEE) revert BadParam();
        launchFee = f;
        emit LaunchFeeSet(f);
    }

    /// @notice Split for FUTURE launches only — coins already created keep the
    ///         bps they launched with. Floored at MIN_CREATOR_BPS.
    function setCreatorBps(uint256 b) external onlyOwner {
        if (b < MIN_CREATOR_BPS || b > BPS) revert BadParam();
        creatorBps = b;
        emit CreatorBpsSet(b);
    }

    /// @notice Graduation bar for FUTURE launches only, bounded MIN/MAX. Coins
    ///         already created keep the threshold they launched with. Purely a
    ///         status parameter — it gates nothing on-chain.
    function setGraduationThreshold(uint256 g) external onlyOwner {
        if (g < MIN_GRADUATION || g > MAX_GRADUATION) revert BadParam();
        graduationThreshold = g;
        emit GraduationThresholdSet(g);
    }

    /// @notice Pauses NEW launches. Live coins trade on Uniswap and are not
    ///         affected — this cannot freeze anyone's token.
    function setLaunchEnabled(bool e) external onlyOwner {
        launchEnabled = e;
        emit LaunchEnabledSet(e);
    }

    /// @dev Two-step: a typo'd address can't strand ownership.
    function transferOwnership(address to) external onlyOwner {
        pendingOwner = to;
    }

    function acceptOwnership() external {
        if (msg.sender != pendingOwner) revert NotOwner();
        emit OwnershipTransferred(owner, pendingOwner);
        owner = pendingOwner;
        pendingOwner = address(0);
    }

    /// @notice Give up the setters permanently, freezing the current fee, split,
    ///         graduation bar and treasury for good.
    function renounceOwnership() external onlyOwner {
        emit OwnershipTransferred(owner, address(0));
        owner = address(0);
        pendingOwner = address(0);
    }

    // ── creator (per coin) ───────────────────────────────────────────────────
    // The creator is where a coin's 90% fee share is paid, and who may change it.
    // Nothing here touches what a holder relies on: not the split (frozen at
    // launch), not the LP, not the treasury's 10%. It only moves who receives the
    // creator's own money.

    /// @notice Hand this coin's creator rights to another wallet — a cold wallet,
    ///         a team multisig, the project you launched it for.
    /// @dev IRREVOCABLE by design. Once you transfer, you are no longer the
    ///      creator and cannot take it back. A re-settable redirect (Pons's) would
    ///      let a deployer hand fees off, wait for the coin to pump, then yank them
    ///      back and rug the project and its holders — this cannot. One-step, so
    ///      there is NO on-chain undo for a mistyped address; the interface
    ///      confirms the destination before sending.
    function transferCreator(address token, address to) external {
        Launch storage L = launches[token];
        if (!L.exists) revert NotFound();
        if (msg.sender != L.creator) revert NotCreator();
        if (to == address(0)) revert ZeroInput();
        address from = L.creator;
        L.creator = to;
        emit CreatorTransferred(token, from, to);
    }

    /// @notice Reassign a coin's creator rights. For Community Take-Overs: when a
    ///         coin is abandoned and a team revives it, its fees can be redirected
    ///         to the people actually working on it.
    /// @dev An owner power and a stated trust assumption. Deliberately narrow: it
    ///      moves ONLY who receives the creator fee stream. It cannot touch the
    ///      LP, the supply, trading, the treasury's share, or any holder's tokens.
    ///      Every use emits CreatorReassigned; renounceOwnership removes it.
    function reassignCreator(address token, address to) external onlyOwner {
        Launch storage L = launches[token];
        if (!L.exists) revert NotFound();
        if (to == address(0)) revert ZeroInput();
        address from = L.creator;
        L.creator = to;
        emit CreatorReassigned(token, from, to);
    }

    // ── launch ─────────────────────────────────────────────────────────────
    /// @param minTokensOut slippage floor for the optional dev buy (0 to skip check).
    /// @param salt CREATE2 salt for the coin's address. The interface grinds it
    ///        off-chain so every Recurve coin ends in the house suffix; pass any
    ///        value (e.g. 0) if you don't care. The coin address is deterministic
    ///        in (this launchpad, salt, the constructor args) — predictable, but
    ///        the LP is locked by construction regardless of address.
    /// @notice Send ETH to buy your own bag in the SAME transaction as the launch.
    ///         Optional, but doing it here rather than as a follow-up tx means
    ///         there is no block for a sniper to get in front of.
    function create(string calldata name, string calldata symbol, string calldata metadataURI, uint256 minTokensOut, FeeMode feeMode, bytes32 salt)
        external
        payable
        nonReentrant
        returns (address token, address pool)
    {
        if (!launchEnabled) revert LaunchesDisabled();

        // CREATE2 so the address is deterministic and the interface can grind a
        // vanity suffix. The salt is caller-supplied; a collision (same salt, same
        // args, already deployed) simply reverts the create, costing only gas.
        token = address(
            new RecurveCoin{salt: salt}(
                name, symbol, metadataURI, msg.sender, TOTAL_SUPPLY,
                address(weth), address(factory), POOL_FEE
            )
        );

        // Freeze this coin's economics right here. Nothing the owner does later
        // can reach back and change them.
        tokenCreatorBps[token] = creatorBps;
        tokenGraduationThreshold[token] = graduationThreshold;

        bool tokenIsToken0 = token < address(weth);
        (address token0, address token1) = tokenIsToken0 ? (token, address(weth)) : (address(weth), token);

        pool = factory.getPool(token0, token1, POOL_FEE);
        if (pool == address(0)) pool = factory.createPool(token0, token1, POOL_FEE);
        (uint160 existing, , , , , , ) = IUniswapV3Pool(pool).slot0();
        if (existing != 0) revert PoolTaken(); // someone pre-created and priced it

        (int24 lower, int24 upper, uint160 startSqrt) = _range(tokenIsToken0);

        IUniswapV3Pool(pool).initialize(startSqrt);

        Launch storage L = launches[token];
        L.pool = pool;
        L.creator = msg.sender;
        L.tickLower = lower;
        L.tickUpper = upper;
        L.exists = true;
        L.feeMode = feeMode; // frozen; nothing can change it later
        allTokens.push(token);

        // Single-sided: spot sits at the edge of the range, so the whole supply
        // goes in as tokens and not one wei of ETH is required.
        uint128 liquidity = tokenIsToken0
            ? LiquidityAmounts.getLiquidityForAmount0(TickMath.getSqrtRatioAtTick(lower), TickMath.getSqrtRatioAtTick(upper), TOTAL_SUPPLY)
            : LiquidityAmounts.getLiquidityForAmount1(TickMath.getSqrtRatioAtTick(lower), TickMath.getSqrtRatioAtTick(upper), TOTAL_SUPPLY);

        _minting = token;
        IUniswapV3Pool(pool).mint(address(this), lower, upper, liquidity, abi.encode(token0, token1));
        _minting = address(0);

        emit TokenCreated(token, msg.sender, pool, name, symbol, metadataURI, lower, upper, feeMode);

        // Fee off the top; whatever's left is the optional dev buy.
        if (msg.value < launchFee) revert FeeTooLow();
        _sendEth(treasury, launchFee);
        uint256 devEth = msg.value - launchFee;
        if (devEth > 0) _devBuy(token, pool, tokenIsToken0, devEth, minTokensOut);
    }

    function _sendEth(address to, uint256 amount) internal {
        (bool ok, ) = to.call{value: amount}("");
        if (!ok) revert TransferFailed();
    }

    /// @dev Swaps ETH straight against the freshly created pool, atomically.
    function _devBuy(address token, address pool, bool tokenIsToken0, uint256 ethIn, uint256 minTokensOut) internal {
        weth.deposit{value: ethIn}();

        bool zeroForOne = !tokenIsToken0; // true when WETH is token0
        uint160 limit = zeroForOne ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1;

        _swapping = token;
        // Buy to OURSELVES, then forward. The coin's guard exempts `to ==
        // launchpad`, which clears the max-wallet cap for the atomic dev buy
        // without giving the creator a standing exemption the way Noxa does.
        (int256 a0, int256 a1) = IUniswapV3Pool(pool).swap(
            address(this),
            zeroForOne,
            int256(ethIn), // exact input
            limit,
            abi.encode(token, true)
        );
        _swapping = address(0);

        int256 out = tokenIsToken0 ? a0 : a1;
        uint256 got = out < 0 ? uint256(-out) : 0;
        if (got < minTokensOut) revert Slippage();

        // Forward to the creator. `from == launchpad` is not a pool buy, so the
        // cap doesn't apply to this hop.
        if (got > 0) _pay(token, msg.sender, got);

        emit DevBuy(token, msg.sender, ethIn, got);
    }

    address private _swapping;

    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external {
        (address token, bool payWeth) = abi.decode(data, (address, bool));
        if (token == address(0) || token != _swapping || msg.sender != launches[token].pool) revert NotFound();
        uint256 owed = amount0Delta > 0 ? uint256(amount0Delta) : uint256(amount1Delta);
        address asset = payWeth ? address(weth) : token;
        if (!RecurveCoin(asset).transfer(msg.sender, owed)) revert TransferFailed();
    }

    // ── mint callback ──────────────────────────────────────────────────────
    address private _minting;

    function uniswapV3MintCallback(uint256 amount0Owed, uint256 amount1Owed, bytes calldata data) external {
        address token = _minting;
        if (token == address(0) || msg.sender != launches[token].pool) revert NotFound();
        (address token0, address token1) = abi.decode(data, (address, address));
        // Single-sided by construction: exactly one side should ever be owed.
        if (amount0Owed > 0) _pay(token0, msg.sender, amount0Owed);
        if (amount1Owed > 0) _pay(token1, msg.sender, amount1Owed);
    }

    /// @dev Ticks for the launch range + the spot price to open at. The range
    ///      always starts at the opening tick and runs to the tick limit in
    ///      whichever direction "the coin gets more expensive" is. That direction
    ///      flips with sort order — a pool prices token1/token0, so when the coin
    ///      sorts SECOND its own price is the inverse and the open bound is the
    ///      UPPER tick. Matches Pons's _positionRange.
    function _range(bool tokenIsToken0) internal pure returns (int24 lower, int24 upper, uint160 startSqrt) {
        if (tokenIsToken0) {
            // price = ETH per token; coin dearer as tick RISES. Open low, run up.
            lower = INITIAL_TICK;
            upper = MAX_USABLE_TICK;
            startSqrt = TickMath.getSqrtRatioAtTick(lower);
        } else {
            // mirrored: coin dearer as tick FALLS. Open high, run down.
            lower = MIN_USABLE_TICK;
            upper = -INITIAL_TICK;
            startSqrt = TickMath.getSqrtRatioAtTick(upper);
        }
    }

    // ── fees ───────────────────────────────────────────────────────────────
    /// @notice Sweep accrued pool fees to the creator + treasury, paid entirely
    ///         in WETH. Permissionless: anyone can trigger it, the split is fixed,
    ///         and it can never move LP principal because burn() is never called.
    function collectFees(address token) external nonReentrant {
        Launch storage L = launches[token];
        if (!L.exists) revert NotFound();

        // Poke first: tokensOwed only updates when the position is touched.
        // burn(0) removes no liquidity — the LP is never withdrawable.
        IUniswapV3Pool(L.pool).burn(L.tickLower, L.tickUpper, 0);

        (uint128 got0, uint128 got1) =
            IUniswapV3Pool(L.pool).collect(address(this), L.tickLower, L.tickUpper, type(uint128).max, type(uint128).max);
        if (got0 == 0 && got1 == 0) return;

        bool tokenIsToken0 = token < address(weth);
        uint256 tokAmt = tokenIsToken0 ? uint256(got0) : uint256(got1);
        uint256 wethAmt = tokenIsToken0 ? uint256(got1) : uint256(got0);

        // The bps this coin launched with — NOT the current setting. Floor the
        // TREASURY side so integer rounding always breaks the creator's way.
        uint256 bps = tokenCreatorBps[token];

        uint256 pW = (wethAmt * (BPS - bps)) / BPS;
        uint256 cW = wethAmt - pW;
        _pay(address(weth), L.creator, cW);
        _pay(address(weth), treasury, pW);

        uint256 cT;
        uint256 pT;
        if (tokAmt > 0) {
            if (L.feeMode == FeeMode.Burn) {
                _pay(token, DEAD, tokAmt);
            } else {
                pT = (tokAmt * (BPS - bps)) / BPS;
                cT = tokAmt - pT;
                _pay(token, L.creator, cT);
                _pay(token, treasury, pT);
            }
        }

        (uint256 c0, uint256 c1) = tokenIsToken0 ? (cT, cW) : (cW, cT);
        (uint256 t0, uint256 t1) = tokenIsToken0 ? (pT, pW) : (pW, pT);
        emit FeesCollected(token, L.creator, c0, c1, t0, t1);
    }

    function _pay(address t, address to, uint256 amount) internal {
        if (amount == 0) return;
        if (!RecurveCoin(t).transfer(to, amount)) revert TransferFailed();
    }

    /// @notice Fees claimable via collectFees(), without changing any state.
    ///         Recomputes feeGrowthInside exactly the way the pool does in
    ///         Position.update(), since position.tokensOwed only updates on poke.
    function pendingFees(address token) external view returns (uint128 owed0, uint128 owed1) {
        Launch storage L = launches[token];
        if (!L.exists) revert NotFound();
        IUniswapV3Pool pool = IUniswapV3Pool(L.pool);

        bytes32 key = keccak256(abi.encodePacked(address(this), L.tickLower, L.tickUpper));
        (uint128 liquidity, uint256 inside0Last, uint256 inside1Last, uint128 owed0Prev, uint128 owed1Prev) =
            pool.positions(key);

        (uint256 inside0, uint256 inside1) = _feeGrowthInside(pool, L.tickLower, L.tickUpper);

        unchecked {
            owed0 = owed0Prev + uint128(FullMath.mulDiv(inside0 - inside0Last, liquidity, Q128));
            owed1 = owed1Prev + uint128(FullMath.mulDiv(inside1 - inside1Last, liquidity, Q128));
        }
    }

    /// @dev Mirrors UniswapV3Pool._getFeeGrowthInside.
    function _feeGrowthInside(IUniswapV3Pool pool, int24 tickLower, int24 tickUpper)
        internal
        view
        returns (uint256 inside0, uint256 inside1)
    {
        (, int24 tickCurrent, , , , , ) = pool.slot0();
        uint256 g0 = pool.feeGrowthGlobal0X128();
        uint256 g1 = pool.feeGrowthGlobal1X128();
        (, , uint256 loOut0, uint256 loOut1, , , , ) = pool.ticks(tickLower);
        (, , uint256 upOut0, uint256 upOut1, , , , ) = pool.ticks(tickUpper);

        unchecked {
            uint256 below0 = tickCurrent >= tickLower ? loOut0 : g0 - loOut0;
            uint256 below1 = tickCurrent >= tickLower ? loOut1 : g1 - loOut1;
            uint256 above0 = tickCurrent < tickUpper ? upOut0 : g0 - upOut0;
            uint256 above1 = tickCurrent < tickUpper ? upOut1 : g1 - upOut1;
            inside0 = g0 - below0 - above0;
            inside1 = g1 - below1 - above1;
        }
    }

    // ── graduation ───────────────────────────────────────────────────────────
    /// @notice How far a coin is through its bonding range, exactly as Pons
    ///         measures it: the amount of paired token (WETH) currently held by
    ///         the locked single-sided position at the live price. A coin has
    ///         graduated once that reaches its threshold (~$43k mcap at 4.2 ETH).
    /// @dev Pure view. Nothing on-chain depends on graduation — the liquidity was
    ///      locked from block one. bonding % = pairedPrincipal / threshold.
    function graduationStatus(address token)
        external
        view
        returns (uint256 pairedPrincipal, uint256 threshold, bool graduated)
    {
        Launch storage L = launches[token];
        if (!L.exists) revert NotFound();
        IUniswapV3Pool pool = IUniswapV3Pool(L.pool);
        (uint160 sqrtP, , , , , , ) = pool.slot0();
        bytes32 key = keccak256(abi.encodePacked(address(this), L.tickLower, L.tickUpper));
        (uint128 liquidity, , , , ) = pool.positions(key);
        (uint256 amount0, uint256 amount1) = LiquidityAmounts.getAmountsForLiquidity(
            sqrtP,
            TickMath.getSqrtRatioAtTick(L.tickLower),
            TickMath.getSqrtRatioAtTick(L.tickUpper),
            liquidity
        );
        pairedPrincipal = token < address(weth) ? amount1 : amount0; // the WETH side
        threshold = tokenGraduationThreshold[token];
        graduated = threshold != 0 && pairedPrincipal >= threshold;
    }

    // ── views ──────────────────────────────────────────────────────────────
    function tokenCount() external view returns (uint256) {
        return allTokens.length;
    }

    /// @notice Current price + market cap, straight from the pool.
    function stats(address token) external view returns (uint256 priceEthPerToken, uint256 marketCapWei, uint160 sqrtPriceX96) {
        Launch storage L = launches[token];
        if (!L.exists) revert NotFound();
        (sqrtPriceX96, , , , , , ) = IUniswapV3Pool(L.pool).slot0();
        uint256 p = FullMath.mulDiv(uint256(sqrtPriceX96) * uint256(sqrtPriceX96), 1e18, 1 << 192);
        priceEthPerToken = token < address(weth) ? p : (p == 0 ? 0 : (1e36 / p));
        marketCapWei = (priceEthPerToken * TOTAL_SUPPLY) / 1e18;
    }
}
