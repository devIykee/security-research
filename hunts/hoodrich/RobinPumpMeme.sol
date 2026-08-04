// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * ███ RobinPumpMeme — Instant Launch: straight-to-DEX token factory ███
 *
 * Second launch mode for RobinPump. Deploys a honeypot-safe token and puts
 * its ENTIRE 1B supply into a single-sided Uniswap V3 position in one atomic
 * transaction, then permanently locks the LP NFT. The token is tradable on
 * Uniswap — and visible to every bot and scanner — the second the launch
 * transaction confirms. No bonding curve, no graduation.
 *
 * SECURITY MODEL (owner powers are deliberately minimal):
 *  - The owner can change the treasury, adjust the creation fee up to a hard
 *    cap, tune the fee split within hard caps, and pause NEW launches. That is all.
 *  - The owner CANNOT touch any launched token's supply or liquidity, cannot
 *    collect LP principal (the lock has no such code path), and cannot modify
 *    already-launched tokens (they have no owner at all).
 *  - Pool creation and liquidity minting happen in the same transaction that
 *    deploys the token, so the pool price cannot be front-run: the token
 *    address does not exist before this transaction.
 *  - One ticker, one token: symbols are uppercase-normalized and can never be
 *    reused through this factory.
 *
 * Fee split on collected LP trading fees (read live by the lock each sweep):
 *  - creatorShareBps  (default 40%, hard cap 50%) → the token's launcher
 *  - keeperBountyBps  (default 1%, hard cap 2%)   → whoever calls collect()
 *  - communityShareBps(default 0%, hard cap 30%)  → future staking vault slot
 *  - remainder (always ≥ 20%)                      → platform treasury
 */

/* ─────────────────────── External interfaces ─────────────────────── */

/// @dev Minimal interface to Uniswap V3's NonfungiblePositionManager —
/// only the functions RobinPumpMeme actually uses.
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

    struct CollectParams {
        uint256 tokenId;
        address recipient;
        uint128 amount0Max;
        uint128 amount1Max;
    }

    function createAndInitializePoolIfNecessary(
        address token0,
        address token1,
        uint24 fee,
        uint160 sqrtPriceX96
    ) external payable returns (address pool);

    function mint(MintParams calldata params)
        external
        payable
        returns (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1);

    function collect(CollectParams calldata params)
        external
        payable
        returns (uint256 amount0, uint256 amount1);

    function ownerOf(uint256 tokenId) external view returns (address);
}

/// @dev Read-side interface the lock uses to resolve fee routing.
interface ITreasuryProvider {
    function treasury() external view returns (address);
    function feeSplits()
        external
        view
        returns (uint16 creatorShareBps, uint16 keeperBountyBps, uint16 communityShareBps, address communityPool);
    function positionAssets(uint256 tokenId) external view returns (address token, address creator);
}

interface IERC20Minimal {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
    function approve(address spender, uint256 value) external returns (bool);
}

/// @dev Read-side slice of the Uniswap V3 pool, used to verify the pool
///      price matches our launch config before minting.
interface IUniswapV3PoolMinimal {
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

/* ───────────────────────── Token template ─────────────────────────── */

/// @title RobinPumpMemeToken
/// @notice The RobinPump honeypot-safe template, Instant Launch edition.
/// @dev Deliberately boring, and that is the point:
///      - Fixed supply, minted once in the constructor. No mint function exists.
///      - No owner. No admin. Nothing to renounce because nothing was kept.
///      - No blacklist, no pause, no transfer tax, no hooks.
///      Anything not in this file cannot happen.
contract RobinPumpMemeToken {
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

/* ───────────────────────── Permanent lock ─────────────────────────── */

/// @title RobinPumpMemeLiquidityLock
/// @notice A one-way vault for Uniswap V3 position NFTs. Positions that enter
///         can NEVER leave — there is no transfer, no withdraw, no
///         decreaseLiquidity, and no owner. The only external action is
///         collecting accrued trading fees, which are split between the token
///         creator ("creator dividends"), the caller (keeper bounty), an
///         optional community pool, and the platform treasury — and never
///         touch principal liquidity.
/// @dev    Security model, stated plainly for auditors and Blockscout readers:
///         this contract holds the NFT and exposes exactly one state-changing
///         function, collect(). The position's liquidity is immovable because
///         no code path here calls decreaseLiquidity or any ERC-721 transfer
///         method. Fee split percentages are read live from the factory,
///         where they are hard-capped (see RobinPumpMeme).
contract RobinPumpMemeLiquidityLock {
    uint256 private constant BPS = 10_000;

    INonfungiblePositionManager public immutable positionManager;
    ITreasuryProvider public immutable factory;
    address public immutable weth;

    uint256 private _lock = 1;

    modifier nonReentrant() {
        require(_lock == 1, "reentrant");
        _lock = 2;
        _;
        _lock = 1;
    }

    event FeesCollected(
        uint256 indexed tokenId,
        uint256 tokenAmount,
        uint256 wethAmount,
        address creator,
        address keeper
    );
    event PositionLocked(uint256 indexed tokenId);

    error NotPositionManager();
    error DirectDepositsNotAllowed();
    error ZeroTreasury();
    error UnknownPosition();

    constructor(INonfungiblePositionManager positionManager_, ITreasuryProvider factory_, address weth_) {
        positionManager = positionManager_;
        factory = factory_;
        weth = weth_;
    }

    /// @notice Collects accrued trading fees on a locked position and splits
    ///         them: creator share to the token's launcher, a small bounty to
    ///         whoever called this (so fee sweeping runs itself), an optional
    ///         community-pool share, and the remainder to the treasury.
    ///         Permissionless by design. Never touches liquidity.
    function collect(uint256 tokenId) external nonReentrant {
        address treasury = factory.treasury();
        if (treasury == address(0)) revert ZeroTreasury();
        (address token, address creator) = factory.positionAssets(tokenId);
        if (token == address(0) || creator == address(0)) revert UnknownPosition();

        // Pull fees into the lock, then split by measured balances.
        positionManager.collect(
            INonfungiblePositionManager.CollectParams({
                tokenId: tokenId,
                recipient: address(this),
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            })
        );

        uint256 tokenBal = IERC20Minimal(token).balanceOf(address(this));
        uint256 wethBal = IERC20Minimal(weth).balanceOf(address(this));

        SplitPlan memory plan;
        plan.creator = creator;
        plan.treasury = treasury;
        (plan.creatorBps, plan.keeperBps, plan.communityBps, plan.communityPool) = factory.feeSplits();
        if (plan.communityPool == address(0)) plan.communityBps = 0;

        _split(token, tokenBal, plan);
        _split(weth, wethBal, plan);

        emit FeesCollected(tokenId, tokenBal, wethBal, creator, msg.sender);
    }

    struct SplitPlan {
        address creator;
        address treasury;
        address communityPool;
        uint16 creatorBps;
        uint16 keeperBps;
        uint16 communityBps;
    }

    function _split(address asset, uint256 amount, SplitPlan memory plan) private {
        if (amount == 0) return;
        uint256 toCreator = (amount * plan.creatorBps) / BPS;
        uint256 toKeeper = (amount * plan.keeperBps) / BPS;
        uint256 toCommunity = (amount * plan.communityBps) / BPS;
        uint256 toTreasury = amount - toCreator - toKeeper - toCommunity; // remainder: no dust stranded

        if (toCreator > 0) _safeTransfer(asset, plan.creator, toCreator);
        if (toKeeper > 0) _safeTransfer(asset, msg.sender, toKeeper);
        if (toCommunity > 0) _safeTransfer(asset, plan.communityPool, toCommunity);
        if (toTreasury > 0) _safeTransfer(asset, plan.treasury, toTreasury);
    }

    /// @dev Tolerates non-standard ERC-20s that return no data (none are
    ///      expected here — only RobinPumpMemeToken and canonical WETH).
    function _safeTransfer(address token, address to, uint256 value) private {
        (bool ok, bytes memory data) = token.call(abi.encodeWithSelector(IERC20Minimal.transfer.selector, to, value));
        require(ok && (data.length == 0 || abi.decode(data, (bool))), "transfer failed");
    }

    /// @notice ERC-721 receiver hook. Only fresh mints from the position
    ///         manager may enter (from == 0). User transfers are rejected so
    ///         nobody can accidentally freeze their own position in here —
    ///         this vault is exclusively for factory-launched liquidity.
    function onERC721Received(address, address from, uint256 tokenId, bytes calldata)
        external
        returns (bytes4)
    {
        if (msg.sender != address(positionManager)) revert NotPositionManager();
        if (from != address(0)) revert DirectDepositsNotAllowed();
        emit PositionLocked(tokenId);
        return this.onERC721Received.selector;
    }
}

/* ──────────────────────────── Factory ─────────────────────────────── */

/// @title RobinPumpMeme
/// @notice The Instant Launch factory: deploys a token, creates + initializes
///         its Uniswap V3 pool, mints the full supply as a single-sided
///         position directly into the permanent lock, and enforces
///         one-ticker-one-token — all in one atomic transaction.
contract RobinPumpMeme {
    // ─── Constants ───────────────────────────────────────────────
    uint256 public constant TOTAL_SUPPLY = 1_000_000_000e18; // matches RobinPump curve launches
    uint256 public constant MAX_CREATION_FEE = 0.01 ether;   // hard cap on owner power
    address public constant DEAD = 0x000000000000000000000000000000000000dEaD;
    /// @dev Allow at most 0.0001% of supply as rounding dust from the V3 mint.
    uint256 public constant MAX_DUST = TOTAL_SUPPLY / 1_000_000;

    // ─── Fee split caps (hard limits on owner power) ─────────────
    uint16 public constant MAX_CREATOR_SHARE_BPS = 5_000;  // 50%
    uint16 public constant MAX_KEEPER_BOUNTY_BPS = 200;    // 2%
    uint16 public constant MAX_COMMUNITY_SHARE_BPS = 3_000; // 30% — staking vault slot, pending legal
    uint16 public constant MAX_TOTAL_SPLIT_BPS = 8_000;    // treasury always receives >= 20%

    // ─── Launch pricing configuration (fixed for every launch) ──
    /// @dev Two orientations because the new token's address may sort before
    ///      or after WETH. Values are precomputed off-chain (see
    ///      script/compute-launch-config.mjs) so no tick math runs on-chain.
    struct LaunchConfig {
        uint24 feeTier;
        uint160 sqrtPriceX96Token0; // pool init price when new token is token0
        int24 tickLower0;
        int24 tickUpper0;
        uint160 sqrtPriceX96Token1; // pool init price when new token is token1
        int24 tickLower1;
        int24 tickUpper1;
    }

    // ─── Immutables ──────────────────────────────────────────────
    INonfungiblePositionManager public immutable positionManager;
    address public immutable weth;
    RobinPumpMemeLiquidityLock public immutable lock;
    LaunchConfig public config;

    // ─── Owner / reentrancy ──────────────────────────────────────
    address public owner;
    uint256 private _lockFlag = 1;

    modifier nonReentrant() {
        require(_lockFlag == 1, "reentrant");
        _lockFlag = 2;
        _;
        _lockFlag = 1;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    // ─── Owner-adjustable (bounded) ─────────────────────────────
    address public treasury;
    uint256 public creationFee;
    bool public launchesPaused;
    uint16 public creatorShareBps;
    uint16 public keeperBountyBps;
    uint16 public communityShareBps;
    address public communityPool;

    // ─── Registry ────────────────────────────────────────────────
    struct Launch {
        address token;
        address pool;
        uint256 positionTokenId;
        address creator;
        uint64 createdAt;
    }

    mapping(bytes32 => bool) public tickerTaken; // keccak256(uppercase symbol)
    mapping(uint256 => Launch) private launchByPosition; // positionTokenId => launch
    mapping(address => Launch) public launchOf;  // token => launch record
    address[] public allTokens;
    uint256 public pendingFees; // accrued creation fees awaiting claim

    // ─── Events / errors ─────────────────────────────────────────
    event InstantLaunch(
        address indexed token,
        address indexed pool,
        uint256 indexed positionTokenId,
        address creator,
        string name,
        string symbol
    );
    event TreasuryChanged(address treasury);
    event CreationFeeChanged(uint256 fee);
    event LaunchesPaused(bool paused);
    event FeesClaimed(uint256 amount, address treasury);
    event FeeSplitsChanged(uint16 creatorShareBps, uint16 keeperBountyBps, uint16 communityShareBps, address communityPool);
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);

    error LaunchesArePaused();
    error InsufficientCreationFee();
    error TickerAlreadyTaken();
    error BadSymbol();
    error BadName();
    error ZeroAddress();
    error FeeAboveCap();
    error MintIncomplete();
    error RefundFailed();
    error ClaimFailed();
    error BadConfig();
    error SplitAboveCap();
    error CommunityPoolUnset();
    error PoolPriceMismatch();
    error AddressNotCafe();

    constructor(
        INonfungiblePositionManager positionManager_,
        address weth_,
        address treasury_,
        uint256 creationFee_,
        LaunchConfig memory config_
    ) {
        if (address(positionManager_) == address(0) || weth_ == address(0) || treasury_ == address(0)) {
            revert ZeroAddress();
        }
        if (creationFee_ > MAX_CREATION_FEE) revert FeeAboveCap();
        if (
            config_.tickLower0 >= config_.tickUpper0 ||
            config_.tickLower1 >= config_.tickUpper1 ||
            config_.sqrtPriceX96Token0 == 0 ||
            config_.sqrtPriceX96Token1 == 0
        ) revert BadConfig();

        owner = msg.sender;
        positionManager = positionManager_;
        weth = weth_;
        treasury = treasury_;
        creationFee = creationFee_;
        config = config_;
        lock = new RobinPumpMemeLiquidityLock(positionManager_, ITreasuryProvider(address(this)), weth_);
        creatorShareBps = 4_000; // 40% creator dividends — the flywheel
        keeperBountyBps = 100;   // 1% to whoever sweeps — self-running
        communityShareBps = 0;   // staking slot stays closed until legal clears it
    }

    // ─────────────────────────────────────────────────────────────
    // LAUNCH
    // ─────────────────────────────────────────────────────────────

    /// @notice Deploys a token and makes it instantly tradable on Uniswap V3.
    ///         The full 1B supply goes into a single-sided position (tokens
    ///         only, priced along a range — economically similar to a bonding
    ///         curve, but living on real Uniswap from block one). The LP NFT
    ///         is minted directly into the permanent lock.
    /// @param vanitySalt Pre-ground off-chain so the token address ends in
    ///        0xcafe. The effective CREATE2 salt mixes in msg.sender, so a
    ///        copied salt yields a different address for anyone else — nobody
    ///        can snipe a ground address (and its 40% creator dividend slot)
    ///        out from under the creator.
    function instantLaunch(string calldata name, string calldata symbol, bytes32 vanitySalt)
        external
        payable
        nonReentrant
        returns (address token, address pool, uint256 positionTokenId)
    {
        // ── Checks ──
        if (launchesPaused) revert LaunchesArePaused();
        if (msg.value < creationFee) revert InsufficientCreationFee();
        bytes memory nameB = bytes(name);
        if (nameB.length == 0 || nameB.length > 48) revert BadName();
        bytes32 tickerKey = _normalizedTickerKey(symbol);
        if (tickerTaken[tickerKey]) revert TickerAlreadyTaken();

        // ── Effects ──
        tickerTaken[tickerKey] = true;
        pendingFees += creationFee;

        // ── Interactions ──
        // CREATE2 with a creator-bound vanity salt (address must end 0xcafe).
        //
        // Pool pre-poisoning note (why a *predictable* address is safe here,
        // unlike plain CREATE): if an attacker sees the predicted address and
        // pre-initializes its V3 pool at a hostile price, the slot0 check
        // below reverts THIS launch only. Unlike the nonce-based CREATE
        // attack — where the same poisoned address stays "next" forever — the
        // creator simply grinds a fresh salt and relaunches at a new address,
        // so the factory can never be wedged. The salt space is unbounded and
        // each poisoning attempt costs the attacker real gas for pool
        // creation, making the grief strictly losing. The chain's FCFS
        // sequencer (no public mempool) leaves no practical front-run window
        // anyway.
        bytes32 salt = keccak256(abi.encode(msg.sender, vanitySalt));
        token = address(new RobinPumpMemeToken{salt: salt}(name, symbol, TOTAL_SUPPLY, address(this)));
        // Brand invariant: every RobinPump token address ends in ...cafe.
        if (uint16(uint160(token)) != 0xCAFE) revert AddressNotCafe();

        bool tokenIsToken0 = token < weth;
        (address token0, address token1) = tokenIsToken0 ? (token, weth) : (weth, token);

        uint160 expectedSqrtPriceX96 = tokenIsToken0 ? config.sqrtPriceX96Token0 : config.sqrtPriceX96Token1;
        pool = positionManager.createAndInitializePoolIfNecessary(
            token0,
            token1,
            config.feeTier,
            expectedSqrtPriceX96
        );

        // Defense in depth: if a pool for this address somehow pre-existed at
        // a different price (createAndInitializePoolIfNecessary never
        // re-initializes), fail loudly and cleanly. The next attempt deploys
        // to a fresh address, so this can never wedge the factory.
        (uint160 poolSqrtPriceX96, , , , , , ) = IUniswapV3PoolMinimal(pool).slot0();
        if (poolSqrtPriceX96 != expectedSqrtPriceX96) revert PoolPriceMismatch();

        require(IERC20Minimal(token).approve(address(positionManager), TOTAL_SUPPLY), "approve failed");

        uint256 amountTokenUsed;
        uint256 amountWethUsed;
        (positionTokenId, , amountTokenUsed, amountWethUsed) = _mintSingleSided(token0, token1, tokenIsToken0);

        // The position must have consumed effectively the entire supply and
        // zero WETH: this is what makes the launch fully fair — no supply is
        // held back anywhere, by anyone, including us.
        if (amountWethUsed != 0) revert MintIncomplete();
        if (amountTokenUsed < TOTAL_SUPPLY - MAX_DUST) revert MintIncomplete();

        // Burn any rounding dust so the factory holds zero supply after launch.
        uint256 leftover = IERC20Minimal(token).balanceOf(address(this));
        if (leftover > 0) require(IERC20Minimal(token).transfer(DEAD, leftover), "burn failed");
        require(IERC20Minimal(token).approve(address(positionManager), 0), "approve reset failed");

        // Record the launch.
        Launch memory rec = Launch({
            token: token,
            pool: pool,
            positionTokenId: positionTokenId,
            creator: msg.sender,
            createdAt: uint64(block.timestamp)
        });
        launchOf[token] = rec;
        launchByPosition[positionTokenId] = rec;
        allTokens.push(token);

        // Refund any ETH sent above the creation fee.
        uint256 refund = msg.value - creationFee;
        if (refund > 0) {
            (bool ok, ) = msg.sender.call{value: refund}("");
            if (!ok) revert RefundFailed();
        }

        emit InstantLaunch(token, pool, positionTokenId, msg.sender, name, symbol);
    }

    function _mintSingleSided(address token0, address token1, bool tokenIsToken0)
        private
        returns (uint256 tokenId, uint128 liquidity, uint256 amountTokenUsed, uint256 amountWethUsed)
    {
        (uint256 amount0Desired, uint256 amount1Desired) =
            tokenIsToken0 ? (TOTAL_SUPPLY, uint256(0)) : (uint256(0), TOTAL_SUPPLY);

        uint256 a0;
        uint256 a1;
        (tokenId, liquidity, a0, a1) = positionManager.mint(
            INonfungiblePositionManager.MintParams({
                token0: token0,
                token1: token1,
                fee: config.feeTier,
                tickLower: tokenIsToken0 ? config.tickLower0 : config.tickLower1,
                tickUpper: tokenIsToken0 ? config.tickUpper0 : config.tickUpper1,
                amount0Desired: amount0Desired,
                amount1Desired: amount1Desired,
                amount0Min: 0, // enforced post-hoc against MAX_DUST below in caller
                amount1Min: 0,
                recipient: address(lock), // born locked: the NFT never exists anywhere else
                deadline: block.timestamp
            })
        );
        (amountTokenUsed, amountWethUsed) = tokenIsToken0 ? (a0, a1) : (a1, a0);
    }

    // ─────────────────────────────────────────────────────────────
    // FEES
    // ─────────────────────────────────────────────────────────────

    /// @notice Sends accrued creation fees to the treasury. Permissionless.
    function claimFees() external nonReentrant {
        uint256 amount = pendingFees;
        pendingFees = 0;
        (bool ok, ) = treasury.call{value: amount}("");
        if (!ok) revert ClaimFailed();
        emit FeesClaimed(amount, treasury);
    }

    // ─────────────────────────────────────────────────────────────
    // OWNER (bounded powers — see security model at top)
    // ─────────────────────────────────────────────────────────────

    function setTreasury(address treasury_) external onlyOwner {
        if (treasury_ == address(0)) revert ZeroAddress();
        treasury = treasury_;
        emit TreasuryChanged(treasury_);
    }

    function setCreationFee(uint256 fee_) external onlyOwner {
        if (fee_ > MAX_CREATION_FEE) revert FeeAboveCap();
        creationFee = fee_;
        emit CreationFeeChanged(fee_);
    }

    function setLaunchesPaused(bool paused_) external onlyOwner {
        launchesPaused = paused_;
        emit LaunchesPaused(paused_);
    }

    /// @notice Adjust the fee split, within hard caps that guarantee the
    ///         treasury always keeps at least 20% and no share can be turned
    ///         into a drain. Setting communityShareBps > 0 requires a real
    ///         pool address (future staking vault — pending legal review).
    function setFeeSplits(
        uint16 creatorShareBps_,
        uint16 keeperBountyBps_,
        uint16 communityShareBps_,
        address communityPool_
    ) external onlyOwner {
        if (
            creatorShareBps_ > MAX_CREATOR_SHARE_BPS ||
            keeperBountyBps_ > MAX_KEEPER_BOUNTY_BPS ||
            communityShareBps_ > MAX_COMMUNITY_SHARE_BPS ||
            uint256(creatorShareBps_) + keeperBountyBps_ + communityShareBps_ > MAX_TOTAL_SPLIT_BPS
        ) revert SplitAboveCap();
        if (communityShareBps_ > 0 && communityPool_ == address(0)) revert CommunityPoolUnset();
        creatorShareBps = creatorShareBps_;
        keeperBountyBps = keeperBountyBps_;
        communityShareBps = communityShareBps_;
        communityPool = communityPool_;
        emit FeeSplitsChanged(creatorShareBps_, keeperBountyBps_, communityShareBps_, communityPool_);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    // ─────────────────────────────────────────────────────────────
    // VIEWS
    // ─────────────────────────────────────────────────────────────

    /// @notice Fee routing, read live by the lock on every collect.
    function feeSplits()
        external
        view
        returns (uint16, uint16, uint16, address)
    {
        return (creatorShareBps, keeperBountyBps, communityShareBps, communityPool);
    }

    /// @notice Resolves a locked position to its token and creator.
    function positionAssets(uint256 tokenId) external view returns (address token, address creator) {
        Launch memory l = launchByPosition[tokenId];
        return (l.token, l.creator);
    }

    function totalLaunches() external view returns (uint256) {
        return allTokens.length;
    }

    function isTickerTaken(string calldata symbol) external view returns (bool) {
        return tickerTaken[_normalizedTickerKey(symbol)];
    }

    /// @dev Uppercases a-z and validates charset: A-Z and 0-9 only, 1–12 chars.
    function _normalizedTickerKey(string calldata symbol) private pure returns (bytes32) {
        bytes memory s = bytes(symbol);
        if (s.length == 0 || s.length > 12) revert BadSymbol();
        for (uint256 i = 0; i < s.length; i++) {
            bytes1 c = s[i];
            if (c >= 0x61 && c <= 0x7A) {
                s[i] = bytes1(uint8(c) - 32); // a-z -> A-Z
            } else if (!((c >= 0x41 && c <= 0x5A) || (c >= 0x30 && c <= 0x39))) {
                revert BadSymbol();
            }
        }
        return keccak256(s);
    }
}
