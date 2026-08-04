// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {FoundryToken} from "./FoundryToken.sol";

/// @notice Uniswap v3 NonfungiblePositionManager.
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

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external;
}

/// @notice MetaLocker — the permanent, ownerless custody contract for launch
///         positions. See MetaLocker.sol.
interface IMetaLocker {
    function positionManager() external view returns (address);
    function collect(uint256 tokenId) external returns (uint256 amount0, uint256 amount1);
    function feeController(uint256 tokenId) external view returns (address);
    function isPermanentlyLocked(uint256 tokenId) external view returns (bool);
}

/// @notice Uniswap SwapRouter02 (exactInputSingle has no deadline field).
interface ISwapRouter02 {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(ExactInputSingleParams calldata params)
        external
        payable
        returns (uint256 amountOut);
}

interface IWETH9 {
    function withdraw(uint256 wad) external;
    function balanceOf(address) external view returns (uint256);
}

/// @notice Minimal Uniswap v3 pool interface (read the current tick).
interface IUniswapV3PoolMin {
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

/// @title  FoundryLaunchpad (MetaLaunch v7 — MetaLocker custody, creator-first economics)
/// @notice Token launchpad for Robinhood Chain. Every launch deploys a plain
///         fixed-supply ERC-20, creates its Uniswap v3 pool, and permanently
///         locks 100% of the initial position in MetaLocker — all in the SAME
///         transaction.
///
///         Custody model (what changed vs v6)
///         ----------------------------------
///         The launchpad no longer holds the position NFT. In the launch
///         transaction it mints the position to itself and immediately
///         deposits it into MetaLocker via the position manager's
///         `safeTransferFrom`, with this launchpad ABI-encoded as the
///         position's permanent fee controller. MetaLocker is ownerless,
///         non-upgradeable, and has no code path that can transfer, approve,
///         decrease, burn, or re-range a position — the initial launch
///         position is locked forever, machine-verifiably, at one canonical
///         custody address. If the deposit or binding fails, the entire
///         launch reverts: a launched-but-unbound position cannot exist.
///
///         Economics (unchanged from v6)
///         -----------------------------
///         * Deploy fee: flat 0.0005 ETH per launch → protocol treasury.
///         * Pool fee tier: 1%. `collectFees` harvests the locked position's
///           fee revenue via MetaLocker and splits it 70% creator /
///           20% protocol / 10% incentives reserve. Rounding remainders go
///           to the incentives reserve so credits always sum exactly to the
///           collected amount.
///         * Optional creator first buy: msg.value above DEPLOY_FEE is
///           swapped to the new token atomically at launch.
contract FoundryLaunchpad {
    // ------------------------------------------------------------------
    // Constants
    // ------------------------------------------------------------------

    uint256 public constant BPS = 10_000;

    /// @notice Launchpad generation (public integration identifier).
    uint16 public constant VERSION = 7;
    bytes32 public constant LAUNCHPAD_ID = keccak256("METALAUNCH");

    /// @notice Flat fee to deploy a token — the ONLY cost of launching.
    uint256 public constant DEPLOY_FEE = 0.0005 ether;

    /// @notice Creator's share of collected pool fees: 70%.
    uint256 public constant CREATOR_FEE_SHARE_BPS = 7_000;
    /// @notice Protocol's share of collected pool fees: 20%.
    uint256 public constant PROTOCOL_FEE_SHARE_BPS = 2_000;
    /// @notice Incentives reserve share of collected pool fees: 10%
    ///         (plus integer-division remainders).
    uint256 public constant INCENTIVES_FEE_SHARE_BPS = 1_000;

    /// @notice Uniswap v3 fee tier for launch pools: 1%.
    uint24 public constant POOL_FEE = 10_000;
    /// @dev Tick spacing for the 1% tier and full-range bounds.
    int24 internal constant TICK_SPACING = 200;
    int24 internal constant MIN_TICK = -887200;
    int24 internal constant MAX_TICK = 887200;

    uint256 public constant MIN_SUPPLY = 1_000_000 ether;          // 1M tokens
    uint256 public constant MAX_SUPPLY = 10_000_000_000 ether;     // 10B tokens

    /// @dev Bounds for the owner-tunable opening market cap.
    uint256 public constant MIN_INITIAL_MCAP = 0.01 ether;
    uint256 public constant MAX_INITIAL_MCAP = 10 ether;

    // ------------------------------------------------------------------
    // Storage
    // ------------------------------------------------------------------

    struct Launch {
        address creator;
        address pool;           // canonical Uniswap v3 pool (token/WETH9, 1%)
        uint256 feePositionId;  // the 100%-locked position, custodied by MetaLocker
        uint256 openingMcapWei; // opening market cap (ETH wei) at launch
        uint64 createdAt;       // block timestamp of the launch
        string metadataURI;     // avatar / description / links
    }

    address public owner;
    address public treasury;
    /// @notice Destination for the incentives reserve (default: treasury;
    ///         owner can point it at a rewards/referral distributor).
    address public incentivesFund;
    INonfungiblePositionManager public immutable positionManager;
    ISwapRouter02 public immutable router;
    address public immutable weth9;
    /// @notice Permanent custody contract for every launch position.
    IMetaLocker public immutable locker;

    /// @notice Opening market cap (in ETH wei) applied to new launches.
    uint256 public initialMcapWei = 1.3 ether;

    mapping(address => Launch) public launches;
    address[] public allTokens;
    mapping(address => address[]) private _creatorTokens;

    /// @notice ETH withdrawable by the protocol treasury.
    uint256 public protocolFeesAccrued;
    /// @notice ETH withdrawable per token creator.
    mapping(address => uint256) public creatorFeesAccrued;
    /// @notice ETH accrued for the incentives reserve (pull-based).
    uint256 public incentivesAccrued;

    uint256 private _locked = 1;

    // ------------------------------------------------------------------
    // Events & errors
    // ------------------------------------------------------------------

    event TokenCreated(
        address indexed token,
        address indexed creator,
        string name,
        string symbol,
        uint256 supply,
        string metadataURI
    );
    event Launched(
        address indexed token,
        address indexed pool,
        uint256 openingMcapWei,
        uint256 burnedPositionId,
        uint256 feePositionId
    );
    /// @notice One-log lineage for indexers: token → pool → position → locker.
    event LaunchLineage(
        address indexed token,
        address indexed creator,
        address indexed pool,
        uint256 positionId,
        address locker,
        address quoteToken,
        uint24 poolFee,
        int24 tickLower,
        int24 tickUpper,
        uint256 supply,
        uint16 version
    );
    event FeesCollected(address indexed token, uint256 ethFees, uint256 tokenFees);
    event FirstBuy(address indexed token, address indexed creator, uint256 ethIn, uint256 tokensOut);
    event IncentivesWithdrawn(address indexed to, uint256 amount);
    event IncentivesFundUpdated(address indexed incentivesFund);
    event ProtocolFeesWithdrawn(address indexed to, uint256 amount);
    event CreatorFeesWithdrawn(address indexed token, address indexed creator, uint256 amount);
    event TreasuryUpdated(address indexed treasury);
    event InitialMcapUpdated(uint256 initialMcapWei);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    error Reentrancy();
    error NotOwner();
    error NotCreator();
    error ZeroAddress();
    error LockerMismatch();
    error UnknownToken();
    error WrongValue();
    error InvalidSupply();
    error InvalidMcap();
    error EmptyNameOrSymbol();
    error SymbolTooLong();
    error MetadataRequired();
    error NothingToWithdraw();
    error EthTransferFailed();

    // ------------------------------------------------------------------
    // Modifiers
    // ------------------------------------------------------------------

    modifier nonReentrant() {
        if (_locked != 1) revert Reentrancy();
        _locked = 2;
        _;
        _locked = 1;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    /// @param owner_ Initial owner — set the multisig here so the contract is
    ///        never EOA-owned, not even for one block.
    constructor(
        address positionManager_,
        address router_,
        address weth9_,
        address treasury_,
        address locker_,
        address owner_
    ) {
        if (
            treasury_ == address(0) || positionManager_ == address(0) || router_ == address(0)
                || weth9_ == address(0) || locker_ == address(0) || owner_ == address(0)
        ) {
            revert ZeroAddress();
        }
        // The locker must custody positions on the same position manager we mint from.
        if (IMetaLocker(locker_).positionManager() != positionManager_) revert LockerMismatch();

        positionManager = INonfungiblePositionManager(positionManager_);
        router = ISwapRouter02(router_);
        weth9 = weth9_;
        treasury = treasury_;
        incentivesFund = treasury_;
        locker = IMetaLocker(locker_);
        owner = owner_;
        emit OwnershipTransferred(address(0), owner_);
    }

    // ------------------------------------------------------------------
    // Launch — token + permanently locked Uniswap v3 pool in one transaction
    // ------------------------------------------------------------------

    /// @notice Deploy a fixed-supply token, create its Uniswap v3 pool, and
    ///         permanently lock 100% of the initial position in MetaLocker.
    ///         Costs DEPLOY_FEE; any msg.value beyond the fee is spent as an
    ///         optional creator FIRST BUY in the same transaction.
    function createToken(
        string calldata name_,
        string calldata symbol_,
        uint256 supply,
        string calldata metadataURI
    ) external payable nonReentrant returns (address token) {
        (uint256 buyEth, uint256 mcap) = _validateLaunch(name_, symbol_, supply, metadataURI);
        token = address(new FoundryToken(name_, symbol_, supply));
        _launch(token, name_, symbol_, supply, metadataURI, buyEth, mcap);
    }

    /// @notice Same as {createToken}, but deploys the token via CREATE2 so
    ///         the frontend can grind `salt` off-chain for a branded vanity
    ///         address suffix (MetaLaunch standard: ...c0de). The salt is
    ///         namespaced to msg.sender, so a ground salt cannot be sniped
    ///         or squatted by another account. Predict the address with
    ///         {computeTokenAddress}. Reverts if the same (creator, salt,
    ///         name, symbol, supply) tuple was already deployed — grind a
    ///         fresh salt in that case.
    function createTokenWithSalt(
        string calldata name_,
        string calldata symbol_,
        uint256 supply,
        string calldata metadataURI,
        bytes32 salt
    ) external payable nonReentrant returns (address token) {
        (uint256 buyEth, uint256 mcap) = _validateLaunch(name_, symbol_, supply, metadataURI);
        token = address(
            new FoundryToken{salt: keccak256(abi.encodePacked(msg.sender, salt))}(name_, symbol_, supply)
        );
        _launch(token, name_, symbol_, supply, metadataURI, buyEth, mcap);
    }

    /// @notice CREATE2 address prediction for {createTokenWithSalt} — the
    ///         frontend grinds `salt` until this ends in the brand suffix.
    function computeTokenAddress(
        string calldata name_,
        string calldata symbol_,
        uint256 supply,
        address creator,
        bytes32 salt
    ) external view returns (address) {
        bytes32 initHash = keccak256(
            abi.encodePacked(type(FoundryToken).creationCode, abi.encode(name_, symbol_, supply))
        );
        return address(uint160(uint256(keccak256(abi.encodePacked(
            hex"ff", address(this), keccak256(abi.encodePacked(creator, salt)), initHash
        )))));
    }

    function _validateLaunch(
        string calldata name_,
        string calldata symbol_,
        uint256 supply,
        string calldata metadataURI
    ) internal returns (uint256 buyEth, uint256 mcap) {
        if (bytes(name_).length == 0 || bytes(symbol_).length == 0) revert EmptyNameOrSymbol();
        if (bytes(symbol_).length > 12) revert SymbolTooLong();
        if (bytes(metadataURI).length == 0) revert MetadataRequired();
        if (supply < MIN_SUPPLY || supply > MAX_SUPPLY) revert InvalidSupply();
        if (msg.value < DEPLOY_FEE) revert WrongValue();
        buyEth = msg.value - DEPLOY_FEE;
        mcap = initialMcapWei;
        protocolFeesAccrued += DEPLOY_FEE;
    }

    function _launch(
        address token,
        string calldata name_,
        string calldata symbol_,
        uint256 supply,
        string calldata metadataURI,
        uint256 buyEth,
        uint256 mcap
    ) internal {
        FoundryToken(token).approve(address(positionManager), supply);

        bool tokenIs0 = token < weth9;
        (address t0, address t1) = tokenIs0 ? (token, weth9) : (weth9, token);

        // Opening price (ETH per token) = mcap / supply. Uniswap prices are
        // token1-per-token0, so the ratio flips with address ordering.
        uint160 sqrtPrice = tokenIs0 ? _sqrtPriceX96(supply, mcap) : _sqrtPriceX96(mcap, supply);

        address pool = positionManager.createAndInitializePoolIfNecessary(t0, t1, POOL_FEE, sqrtPrice);

        // Single-sided (token-only) range flush against the opening price.
        (, int24 tick, , , , , ) = IUniswapV3PoolMin(pool).slot0();
        int24 tickLower;
        int24 tickUpper;
        if (tokenIs0) {
            // token-only for token0 ⇒ range strictly above the current tick
            tickLower = (tick / TICK_SPACING) * TICK_SPACING;
            if (tickLower <= tick) tickLower += TICK_SPACING;
            tickUpper = MAX_TICK;
        } else {
            // token-only for token1 ⇒ range at or below the current tick
            tickUpper = (tick / TICK_SPACING) * TICK_SPACING;
            if (tickUpper > tick) tickUpper -= TICK_SPACING;
            tickLower = MIN_TICK;
        }

        // ONE position — 100% of the supply. Minted to this contract, then
        // deposited into MetaLocker in the SAME transaction, with this
        // launchpad bound as the position's permanent fee controller. The
        // locker's receive hook reverts on any binding failure, which reverts
        // the entire launch — no launched-but-unbound position can exist.
        uint256 feeId = _mintPosition(t0, t1, tokenIs0, supply, tickLower, tickUpper, address(this));
        positionManager.safeTransferFrom(address(this), address(locker), feeId, abi.encode(address(this)));

        // Burn any rounding dust so this contract never holds loose supply.
        uint256 tokDust = FoundryToken(token).balanceOf(address(this));
        if (tokDust > 0) FoundryToken(token).burn(tokDust);

        launches[token] = Launch({
            creator: msg.sender,
            pool: pool,
            feePositionId: feeId,
            openingMcapWei: mcap,
            createdAt: uint64(block.timestamp),
            metadataURI: metadataURI
        });
        allTokens.push(token);
        _creatorTokens[msg.sender].push(token);

        emit TokenCreated(token, msg.sender, name_, symbol_, supply, metadataURI);
        emit Launched(token, pool, mcap, 0, feeId);
        emit LaunchLineage(
            token, msg.sender, pool, feeId, address(locker), weth9,
            POOL_FEE, tickLower, tickUpper, supply, VERSION
        );

        // Optional creator first buy — atomic, deterministic price.
        if (buyEth > 0) {
            uint256 tokensOut = router.exactInputSingle{value: buyEth}(
                ISwapRouter02.ExactInputSingleParams({
                    tokenIn: weth9,
                    tokenOut: token,
                    fee: POOL_FEE,
                    recipient: msg.sender,
                    amountIn: buyEth,
                    amountOutMinimum: 0,
                    sqrtPriceLimitX96: 0
                })
            );
            emit FirstBuy(token, msg.sender, buyEth, tokensOut);
        }
    }

    function _mintPosition(
        address t0,
        address t1,
        bool tokenIs0,
        uint256 tokenAmt,
        int24 tickLower,
        int24 tickUpper,
        address recipient
    ) internal returns (uint256 tokenId) {
        (tokenId, , , ) = positionManager.mint(
            INonfungiblePositionManager.MintParams({
                token0: t0,
                token1: t1,
                fee: POOL_FEE,
                tickLower: tickLower,
                tickUpper: tickUpper,
                amount0Desired: tokenIs0 ? tokenAmt : 0,
                amount1Desired: tokenIs0 ? 0 : tokenAmt,
                amount0Min: 0,
                amount1Min: 0,
                recipient: recipient,
                deadline: block.timestamp
            })
        );
    }

    // ------------------------------------------------------------------
    // Pool-fee harvesting — via MetaLocker; the locked position earns for
    // the life of the pool
    // ------------------------------------------------------------------

    /// @notice Collect the locked position's accrued Uniswap fees for `token`.
    ///         The locker pays fees directly to this contract (its bound fee
    ///         controller); the amounts credited below are the EXACT values
    ///         returned by the collection call. ETH-side fees split
    ///         70% creator / 20% protocol / 10% incentives (pull-based);
    ///         token-side fees are pushed on the same split. Integer-division
    ///         remainders go to the incentives reserve so credits always sum
    ///         exactly to the collected amount. Callable by anyone
    ///         (harvesting is a public good).
    function collectFees(address token) external nonReentrant {
        Launch storage L = launches[token];
        if (L.creator == address(0)) revert UnknownToken();

        (uint256 amt0, uint256 amt1) = locker.collect(L.feePositionId);
        (uint256 tokenFees, uint256 wethFees) = token < weth9 ? (amt0, amt1) : (amt1, amt0);

        if (wethFees > 0) {
            IWETH9(weth9).withdraw(wethFees);
            uint256 creatorCut = (wethFees * CREATOR_FEE_SHARE_BPS) / BPS;
            uint256 protocolCut = (wethFees * PROTOCOL_FEE_SHARE_BPS) / BPS;
            creatorFeesAccrued[token] += creatorCut;
            protocolFeesAccrued += protocolCut;
            incentivesAccrued += wethFees - creatorCut - protocolCut;
        }
        if (tokenFees > 0) {
            uint256 creatorTok = (tokenFees * CREATOR_FEE_SHARE_BPS) / BPS;
            uint256 protocolTok = (tokenFees * PROTOCOL_FEE_SHARE_BPS) / BPS;
            FoundryToken(token).transfer(L.creator, creatorTok);
            FoundryToken(token).transfer(treasury, protocolTok);
            uint256 incentivesTok = tokenFees - creatorTok - protocolTok;
            if (incentivesTok > 0) FoundryToken(token).transfer(incentivesFund, incentivesTok);
        }
        emit FeesCollected(token, wethFees, tokenFees);
    }

    // ------------------------------------------------------------------
    // Fee withdrawals (pull-based, ETH)
    // ------------------------------------------------------------------

    function withdrawProtocolFees() external nonReentrant {
        uint256 amount = protocolFeesAccrued;
        if (amount == 0) revert NothingToWithdraw();
        protocolFeesAccrued = 0;
        (bool ok, ) = treasury.call{value: amount}("");
        if (!ok) revert EthTransferFailed();
        emit ProtocolFeesWithdrawn(treasury, amount);
    }

    function withdrawCreatorFees(address token) external nonReentrant {
        Launch storage L = launches[token];
        if (msg.sender != L.creator) revert NotCreator();
        uint256 amount = creatorFeesAccrued[token];
        if (amount == 0) revert NothingToWithdraw();
        creatorFeesAccrued[token] = 0;
        (bool ok, ) = msg.sender.call{value: amount}("");
        if (!ok) revert EthTransferFailed();
        emit CreatorFeesWithdrawn(token, msg.sender, amount);
    }

    /// @notice Send the accrued incentives reserve to the incentives fund.
    ///         Callable by anyone (destination is fixed by governance).
    function withdrawIncentives() external nonReentrant {
        uint256 amount = incentivesAccrued;
        if (amount == 0) revert NothingToWithdraw();
        incentivesAccrued = 0;
        (bool ok, ) = incentivesFund.call{value: amount}("");
        if (!ok) revert EthTransferFailed();
        emit IncentivesWithdrawn(incentivesFund, amount);
    }

    function withdrawCreatorFeesMany(address[] calldata tokens) external nonReentrant {
        uint256 total;
        for (uint256 i = 0; i < tokens.length; i++) {
            address token = tokens[i];
            if (msg.sender != launches[token].creator) revert NotCreator();
            uint256 amount = creatorFeesAccrued[token];
            if (amount == 0) continue;
            creatorFeesAccrued[token] = 0;
            total += amount;
            emit CreatorFeesWithdrawn(token, msg.sender, amount);
        }
        if (total == 0) revert NothingToWithdraw();
        (bool ok, ) = msg.sender.call{value: total}("");
        if (!ok) revert EthTransferFailed();
    }

    // ------------------------------------------------------------------
    // Views
    // ------------------------------------------------------------------

    function tokenCount() external view returns (uint256) {
        return allTokens.length;
    }

    function tokensByCreator(address creator) external view returns (address[] memory) {
        return _creatorTokens[creator];
    }

    function poolOf(address token) external view returns (address) {
        return launches[token].pool;
    }

    /// @notice The launch position's NFT id for `token` (0 if unknown token).
    function initialPositionId(address token) external view returns (uint256) {
        return launches[token].feePositionId;
    }

    /// @notice Custody address of the launch position for `token`
    ///         (zero address if unknown token).
    function initialPositionLocker(address token) external view returns (address) {
        return launches[token].creator == address(0) ? address(0) : address(locker);
    }

    /// @notice True if `token`'s INITIAL launch position is permanently
    ///         locked in MetaLocker. This is a statement about the launch
    ///         position only — third parties can add their own (withdrawable)
    ///         positions to the same pool, so the locked share of TOTAL pool
    ///         liquidity is for aggregators to compute from custody data.
    function isInitialPositionPermanentlyLocked(address token) external view returns (bool) {
        Launch storage L = launches[token];
        if (L.creator == address(0)) return false;
        return locker.isPermanentlyLocked(L.feePositionId);
    }

    // ------------------------------------------------------------------
    // Admin
    // ------------------------------------------------------------------

    function setTreasury(address treasury_) external onlyOwner {
        if (treasury_ == address(0)) revert ZeroAddress();
        treasury = treasury_;
        emit TreasuryUpdated(treasury_);
    }

    /// @notice Point the incentives reserve at a rewards/referral distributor.
    function setIncentivesFund(address fund_) external onlyOwner {
        if (fund_ == address(0)) revert ZeroAddress();
        incentivesFund = fund_;
        emit IncentivesFundUpdated(fund_);
    }

    /// @notice Tune the opening market cap for FUTURE launches. Bounded.
    function setInitialMcap(uint256 mcapWei) external onlyOwner {
        if (mcapWei < MIN_INITIAL_MCAP || mcapWei > MAX_INITIAL_MCAP) revert InvalidMcap();
        initialMcapWei = mcapWei;
        emit InitialMcapUpdated(mcapWei);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    // ------------------------------------------------------------------
    // Internal math
    // ------------------------------------------------------------------

    /// @dev sqrt(amt1/amt0) in Q64.96 — the pool's initial price.
    function _sqrtPriceX96(uint256 amt0, uint256 amt1) internal pure returns (uint160) {
        return uint160(_sqrt((amt1 << 96) / amt0) << 48);
    }

    function _sqrt(uint256 x) internal pure returns (uint256 y) {
        if (x == 0) return 0;
        uint256 z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }

    /// @dev Accept ETH from WETH9.withdraw.
    receive() external payable {}
}
