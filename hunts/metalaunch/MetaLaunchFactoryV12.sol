// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {MetaLaunchTokenV12} from "./MetaLaunchTokenV12.sol";
import {MetaLaunchTokenDeployerV12} from "./MetaLaunchTokenDeployerV12.sol";
import {IMetaLaunchLockerV11} from "./interfaces/IMetaLaunchV11.sol";
import {
    IUniswapV3Factory,
    IUniswapV3Pool,
    INonfungiblePositionManager,
    ISwapRouter02,
    ISwapRouterV3
} from "./interfaces/IUniswapV3.sol";
import {TickMath} from "./libraries/TickMath.sol";
import {LiquidityAmounts} from "./libraries/LiquidityAmounts.sol";

interface IOwnable2StepView {
    function owner() external view returns (address);
    function pendingOwner() external view returns (address);
}

/// @title  MetaLaunchFactoryV12
/// @notice V12 launchpad for Robinhood Chain. Identical launch architecture to
///         V11 (owner-managed DEX registry + launch templates; CREATE2 deploy
///         to a `…c0de` address; one-sided concentrated liquidity permanently
///         locked in a MetaLaunchLocker; optional slippage-protected,
///         allocation-capped creator initial buy; read-only reversible
///         graduation) with ONE deliberate difference:
///
///         LAUNCH PROTECTIONS ARE REMOVED. MetaLaunchTokenV12 has no transfer
///         hook at all: no max-wallet cap, no cumulative-buy cap, no
///         restriction window, no launch-block gate, and no factory exemption
///         flag. Tokens are plain OpenZeppelin ERC-20s from their first block.
///         Consequence, stated plainly: same-block snipes at launch are
///         possible; the creator's own first buy still executes atomically
///         inside the launch transaction (before any external order can),
///         and remains capped by maxInitialBuyBps.
///
///         This factory NEVER alters V11 or earlier tokens or positions.
contract MetaLaunchFactoryV12 is Ownable2Step, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ------------------------------------------------------------------
    // Constants
    // ------------------------------------------------------------------

    uint16 public constant VERSION = 12;
    bytes32 public constant LAUNCHPAD_ID = keccak256("METALAUNCH");
    uint256 public constant BPS = 10_000;
    uint16 public constant MAX_INITIAL_BUY_HARD_CAP_BPS = 500; // 5%
    uint16 public constant MAX_PROTOCOL_FEE_SHARE_BPS = 5_000; // 50%
    uint256 public constant MIN_SUPPLY = 1 ether; // >= 1 token (18 decimals)
    uint256 public constant MAX_SALT_ITERATIONS = 300_000; // bounded c0de search
    address internal constant DEAD = 0x000000000000000000000000000000000000dEaD;
    uint16 internal constant VANITY_SUFFIX = 0xc0de;

    // ------------------------------------------------------------------
    // DEX registry
    // ------------------------------------------------------------------

    struct DexConfig {
        string name;
        address factory;
        address positionManager;
        address swapRouter;
        uint24 poolFee;
        int24 tickSpacing;
        bool enabled;
    }

    DexConfig[] private _dexConfigs;

    // ------------------------------------------------------------------
    // Launch templates
    // ------------------------------------------------------------------

    struct LaunchConfig {
        address pairToken;
        uint256 graduationThreshold;
        int24 initialTick;
        uint256 supply;
        uint16 maxInitialBuyBps;
        uint16 protocolFeeShareBps;
        bool enabled;
        bool routerRequiresDeadline;
    }

    LaunchConfig[] private _launchConfigs;

    // ------------------------------------------------------------------
    // Token launch parameters
    // ------------------------------------------------------------------

    struct TokenParams {
        string name;
        string symbol;
        string metadataURI;
        string logo;
        string description;
        MetaLaunchTokenV12.Socials socials;
        address feeWallet;
    }

    // ------------------------------------------------------------------
    // Launch record (immutable snapshot per token)
    // ------------------------------------------------------------------

    struct LaunchedToken {
        address token;
        address deployer;
        address feeWallet;
        address pairedToken;
        address dexFactory;
        address positionManager;
        address swapRouter;
        address pool;
        uint256 positionId;
        uint256 dexId;
        uint256 launchConfigId;
        uint256 supply;
        uint256 graduationThreshold;
        int24 initialTick;
        int24 tickLower;
        int24 tickUpper;
        bool isToken0;
        uint24 poolFee;
        uint16 protocolFeeShareBps;
        uint16 maxInitialBuyBps;
        uint256 initialBuyAmount;
        uint64 createdAt;
        bytes32 resolvedSalt;
        bool exists;
    }

    // ------------------------------------------------------------------
    // Storage
    // ------------------------------------------------------------------

    IMetaLaunchLockerV11 public immutable locker;
    MetaLaunchTokenDeployerV12 public immutable tokenDeployer;
    address public protocolFeeRecipient; // receives launch fees
    uint256 public launchFee = 0.0005 ether;
    bool public launchEnabled;

    mapping(address launcher => bool) public whitelistedLaunchers;
    mapping(address token => LaunchedToken) private _launched;
    mapping(address token => address) public tokenCreator;
    mapping(address token => uint256) private _graduationThresholds;
    address[] private _allTokens;
    mapping(address deployer => address[]) private _creatorTokens;

    // ------------------------------------------------------------------
    // Events
    // ------------------------------------------------------------------

    event TokenDeployed(address indexed token, address indexed deployer, bytes32 resolvedSalt);
    event TokenLaunched(
        address indexed token,
        address indexed deployer,
        address indexed pool,
        uint256 supply,
        uint256 launchConfigId,
        uint256 dexId
    );
    event LaunchLineage(
        address indexed token,
        address indexed creator,
        address feeWallet,
        address indexed pool,
        address pairToken,
        address dexFactory,
        address positionManager,
        uint256 positionId,
        address locker,
        uint24 poolFee,
        int24 initialTick,
        int24 tickLower,
        int24 tickUpper,
        uint256 supply,
        uint256 graduationThreshold,
        uint256 launchConfigId,
        uint256 dexId,
        uint16 version,
        bytes32 resolvedSalt
    );
    event InitialBuyExecuted(
        address indexed token,
        address indexed purchaser,
        address indexed recipient,
        uint256 pairedAssetIn,
        uint256 tokensOut
    );
    event DexConfigAdded(uint256 indexed dexId, string name, address factory, address positionManager);
    event DexStatusUpdated(uint256 indexed dexId, bool enabled);
    event LaunchConfigAdded(uint256 indexed configId, address pairToken, uint256 supply);
    event LaunchConfigUpdated(uint256 indexed configId);
    event LaunchConfigStatusUpdated(uint256 indexed configId, bool enabled);
    event LaunchFeeUpdated(uint256 launchFee);
    event LaunchEnabledUpdated(bool enabled);
    event WhitelistedLauncherUpdated(address indexed launcher, bool enabled);
    event ProtocolFeeRecipientUpdated(address indexed recipient);

    // ------------------------------------------------------------------
    // Errors
    // ------------------------------------------------------------------

    error ZeroAddress();
    error NotWhitelisted();
    error DeadlineExpired();
    error UnknownDex();
    error DexDisabled();
    error UnknownConfig();
    error ConfigDisabled();
    error WrongLaunchFee();
    error LockerMismatch();
    error InvalidDexConfig();
    error InvalidSupply();
    error InvalidInitialBuyCap();
    error InvalidProtocolShare();
    error InvalidTick();
    error TickMisaligned();
    error SaltSearchExhausted();
    error VanityAddressUnavailable();
    error InitialBuyTooLarge(uint256 out, uint256 max);
    error EthTransferFailed();
    error EmptyNameOrSymbol();
    error SymbolTooLong();
    error MetadataRequired();
    error TokenMetaTooLong();

    // ------------------------------------------------------------------
    // Constructor
    // ------------------------------------------------------------------

    /// @param owner_ initial owner (the deployer, transferred to platformOwner
    ///        via Ownable2Step after configuration by the deploy script).
    constructor(address owner_, address locker_, address tokenDeployer_, address protocolFeeRecipient_)
        Ownable(owner_)
    {
        if (locker_ == address(0) || tokenDeployer_ == address(0) || protocolFeeRecipient_ == address(0)) {
            revert ZeroAddress();
        }
        locker = IMetaLaunchLockerV11(locker_);
        tokenDeployer = MetaLaunchTokenDeployerV12(tokenDeployer_);
        protocolFeeRecipient = protocolFeeRecipient_;
    }

    // ==================================================================
    // DEX configuration (owner)
    // ==================================================================

    function addDexConfig(DexConfig calldata config) external onlyOwner returns (uint256 dexId) {
        if (
            config.factory == address(0) || config.positionManager == address(0) || config.swapRouter == address(0)
        ) revert InvalidDexConfig();
        if (config.poolFee == 0 || config.poolFee > 1_000_000) revert InvalidDexConfig();
        if (config.tickSpacing <= 0 || config.tickSpacing > 16_384) revert InvalidDexConfig();
        dexId = _dexConfigs.length;
        _dexConfigs.push(config);
        emit DexConfigAdded(dexId, config.name, config.factory, config.positionManager);
        emit DexStatusUpdated(dexId, config.enabled);
    }

    function setDexStatus(uint256 dexId, bool enabled) external onlyOwner {
        if (dexId >= _dexConfigs.length) revert UnknownDex();
        _dexConfigs[dexId].enabled = enabled;
        emit DexStatusUpdated(dexId, enabled);
    }

    function getDexConfig(uint256 dexId) external view returns (DexConfig memory) {
        if (dexId >= _dexConfigs.length) revert UnknownDex();
        return _dexConfigs[dexId];
    }

    function dexConfigCount() external view returns (uint256) {
        return _dexConfigs.length;
    }

    // ==================================================================
    // Launch templates (owner) — changes affect FUTURE launches only
    // ==================================================================

    function addLaunchConfig(LaunchConfig calldata config) external onlyOwner returns (uint256 configId) {
        _validateLaunchConfig(config);
        configId = _launchConfigs.length;
        _launchConfigs.push(config);
        emit LaunchConfigAdded(configId, config.pairToken, config.supply);
        emit LaunchConfigStatusUpdated(configId, config.enabled);
    }

    function updateLaunchConfig(uint256 configId, LaunchConfig calldata config) external onlyOwner {
        if (configId >= _launchConfigs.length) revert UnknownConfig();
        _validateLaunchConfig(config);
        _launchConfigs[configId] = config;
        emit LaunchConfigUpdated(configId);
        emit LaunchConfigStatusUpdated(configId, config.enabled);
    }

    function setLaunchConfigStatus(uint256 configId, bool enabled) external onlyOwner {
        if (configId >= _launchConfigs.length) revert UnknownConfig();
        _launchConfigs[configId].enabled = enabled;
        emit LaunchConfigStatusUpdated(configId, enabled);
    }

    function getLaunchConfig(uint256 configId) external view returns (LaunchConfig memory) {
        if (configId >= _launchConfigs.length) revert UnknownConfig();
        return _launchConfigs[configId];
    }

    function launchConfigCount() external view returns (uint256) {
        return _launchConfigs.length;
    }

    /// @dev tick-spacing-independent validation (bounds, bps, supply). Exact
    ///      alignment to a dex tickSpacing is re-checked at launch time.
    function _validateLaunchConfig(LaunchConfig calldata c) internal pure {
        if (c.pairToken == address(0)) revert ZeroAddress();
        if (c.supply < MIN_SUPPLY) revert InvalidSupply();
        if (c.maxInitialBuyBps == 0 || c.maxInitialBuyBps > MAX_INITIAL_BUY_HARD_CAP_BPS) revert InvalidInitialBuyCap();
        if (c.protocolFeeShareBps > MAX_PROTOCOL_FEE_SHARE_BPS) revert InvalidProtocolShare();
        if (c.initialTick <= TickMath.MIN_TICK || c.initialTick >= TickMath.MAX_TICK) revert InvalidTick();
        // graduationThreshold may be 0 (disables progress tracking).
    }

    // ==================================================================
    // Launch controls (owner)
    // ==================================================================

    function setLaunchFee(uint256 newLaunchFee) external onlyOwner {
        launchFee = newLaunchFee;
        emit LaunchFeeUpdated(newLaunchFee);
    }

    function setLaunchEnabled(bool enabled) external onlyOwner {
        launchEnabled = enabled;
        emit LaunchEnabledUpdated(enabled);
    }

    function setWhitelistedLauncher(address launcher, bool enabled) external onlyOwner {
        if (launcher == address(0)) revert ZeroAddress();
        whitelistedLaunchers[launcher] = enabled;
        emit WhitelistedLauncherUpdated(launcher, enabled);
    }

    function setProtocolFeeRecipient(address recipient) external onlyOwner {
        if (recipient == address(0)) revert ZeroAddress();
        protocolFeeRecipient = recipient;
        emit ProtocolFeeRecipientUpdated(recipient);
    }

    // ==================================================================
    // Launch
    // ==================================================================

    /// @dev transient working set to keep launchToken() under the stack limit.
    struct LaunchCtx {
        DexConfig dex;
        LaunchConfig cfg;
        address token;
        bytes32 salt;
        bool isToken0;
        int24 poolTick;
        int24 tickLower;
        int24 tickUpper;
        address pool;
        uint256 positionId;
        uint256 initialBuyAmount;
        address recipient;
    }

    function launchToken(
        TokenParams calldata params,
        uint256 launchConfigId,
        uint256 dexId,
        bytes32 userSalt,
        uint256 minInitialBuyOut,
        uint256 deadline
    ) external payable nonReentrant returns (address token) {
        // 1. authorization
        if (!launchEnabled && !whitelistedLaunchers[msg.sender]) revert NotWhitelisted();
        // 2. deadline
        if (block.timestamp > deadline) revert DeadlineExpired();

        LaunchCtx memory x;
        // 3. dex
        if (dexId >= _dexConfigs.length) revert UnknownDex();
        x.dex = _dexConfigs[dexId];
        if (!x.dex.enabled) revert DexDisabled();
        // 4. launch config
        if (launchConfigId >= _launchConfigs.length) revert UnknownConfig();
        x.cfg = _launchConfigs[launchConfigId];
        if (!x.cfg.enabled) revert ConfigDisabled();
        _validateMeta(params);

        // 5. launch fee → protocol recipient (checks-effects-interactions)
        if (msg.value < launchFee) revert WrongLaunchFee();
        x.initialBuyAmount = msg.value - launchFee;
        if (launchFee > 0) {
            (bool ok,) = protocolFeeRecipient.call{value: launchFee}("");
            if (!ok) revert EthTransferFailed();
        }

        // 6-7. resolve …c0de salt + deploy token
        (x.token, x.salt) = _deployVanityToken(params, x.cfg, x.dex, userSalt);
        token = x.token;
        tokenCreator[token] = msg.sender;
        emit TokenDeployed(token, msg.sender, x.salt);

        // 8-14. pool + one-sided liquidity + lock
        _openPoolAndLock(x, params, dexId, launchConfigId);

        // 20-23. optional creator initial buy (slippage + allocation capped)
        if (x.initialBuyAmount > 0) {
            _initialBuy(x, params, minInitialBuyOut, deadline);
        }

        // 24. indexing events (read from the stored record to spare stack)
        emit TokenLaunched(token, msg.sender, x.pool, x.cfg.supply, launchConfigId, dexId);
        _emitLineage(token);
    }

    /// @dev Emit the full lineage log from the stored record (keeps launchToken
    ///      under the Yul stack limit — 20 topics/args from storage, not stack).
    function _emitLineage(address token) internal {
        LaunchedToken storage r = _launched[token];
        emit LaunchLineage(
            token,
            r.deployer,
            r.feeWallet,
            r.pool,
            r.pairedToken,
            r.dexFactory,
            r.positionManager,
            r.positionId,
            address(locker),
            r.poolFee,
            r.initialTick,
            r.tickLower,
            r.tickUpper,
            r.supply,
            r.graduationThreshold,
            r.launchConfigId,
            r.dexId,
            VERSION,
            r.resolvedSalt
        );
    }

    /// @dev Bounded CREATE2 search for a `…c0de` address, then CREATE2 deploy via
    ///      the token deployer. Frontend pre-grinds `userSalt` so the loop exits
    ///      at i=0 (O(1)); the bound is a safety net for on-chain resolution.
    ///      Rejects deployed + existing-pool collisions.
    function _deployVanityToken(
        TokenParams calldata params,
        LaunchConfig memory cfg,
        DexConfig memory dex,
        bytes32 userSalt
    ) internal returns (address token, bytes32 salt) {
        MetaLaunchTokenV12.InitParams memory ip = _initParams(params, cfg, dex);
        bytes32 initCodeHash = tokenDeployer.tokenInitCodeHash(ip);

        salt = _resolveSalt(initCodeHash, cfg, dex, userSalt);
        token = tokenDeployer.deploy(salt, ip);
        if (token == address(0) || (uint160(token) & 0xffff) != VANITY_SUFFIX) revert VanityAddressUnavailable();
    }

    function _resolveSalt(bytes32 initCodeHash, LaunchConfig memory cfg, DexConfig memory dex, bytes32 userSalt)
        internal
        view
        returns (bytes32)
    {
        address deployerAddr = address(tokenDeployer);
        for (uint256 i = 0; i < MAX_SALT_ITERATIONS; ++i) {
            bytes32 salt = keccak256(abi.encodePacked(msg.sender, userSalt, i));
            address predicted = _create2Address(deployerAddr, salt, initCodeHash);
            if (
                (uint160(predicted) & 0xffff) == VANITY_SUFFIX && predicted.code.length == 0
                    && IUniswapV3Factory(dex.factory).getPool(predicted, cfg.pairToken, dex.poolFee) == address(0)
            ) {
                return salt;
            }
        }
        revert SaltSearchExhausted();
    }

    function _create2Address(address deployerAddr, bytes32 salt, bytes32 initCodeHash)
        internal
        pure
        returns (address)
    {
        return address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), deployerAddr, salt, initCodeHash)))));
    }

    function _initParams(TokenParams calldata params, LaunchConfig memory cfg, DexConfig memory dex)
        internal
        view
        returns (MetaLaunchTokenV12.InitParams memory ip)
    {
        ip = MetaLaunchTokenV12.InitParams({
            name: params.name,
            symbol: params.symbol,
            metadataURI: params.metadataURI,
            logo: params.logo,
            description: params.description,
            socials: params.socials,
            creator: msg.sender,
            factory: address(this),
            dexFactory: dex.factory,
            positionManager: dex.positionManager,
            pairToken: cfg.pairToken,
            poolFee: dex.poolFee,
            supply: cfg.supply
        });
    }

    /// @notice Public address prediction — identical inputs to the on-chain path.
    ///         NOTE: `creator` is msg.sender-bound in InitParams, so predict for
    ///         the exact wallet that will launch (pass { from } on the eth_call).
    function predictTokenAddress(
        TokenParams calldata params,
        uint256 launchConfigId,
        uint256 dexId,
        bytes32 salt
    ) external view returns (address) {
        if (dexId >= _dexConfigs.length) revert UnknownDex();
        if (launchConfigId >= _launchConfigs.length) revert UnknownConfig();
        bytes32 initCodeHash =
            tokenDeployer.tokenInitCodeHash(_initParams(params, _launchConfigs[launchConfigId], _dexConfigs[dexId]));
        return _create2Address(address(tokenDeployer), salt, initCodeHash);
    }

    /// @notice View helper: resolve a working effective salt on-chain.
    function resolveLaunchSalt(
        TokenParams calldata params,
        uint256 launchConfigId,
        uint256 dexId,
        bytes32 userSalt
    ) external view returns (bytes32 salt, address predicted) {
        if (dexId >= _dexConfigs.length) revert UnknownDex();
        if (launchConfigId >= _launchConfigs.length) revert UnknownConfig();
        DexConfig memory dex = _dexConfigs[dexId];
        LaunchConfig memory cfg = _launchConfigs[launchConfigId];
        bytes32 initCodeHash = tokenDeployer.tokenInitCodeHash(_initParams(params, cfg, dex));
        salt = _resolveSalt(initCodeHash, cfg, dex, userSalt);
        predicted = _create2Address(address(tokenDeployer), salt, initCodeHash);
    }

    /// @dev pool creation + one-sided mint + burn dust + lock + record.
    function _openPoolAndLock(
        LaunchCtx memory x,
        TokenParams calldata params,
        uint256 dexId,
        uint256 launchConfigId
    ) internal {
        address pairToken = x.cfg.pairToken;
        x.isToken0 = x.token < pairToken;
        x.poolTick = _alignedPoolTick(x.cfg.initialTick, x.isToken0, x.dex.tickSpacing);
        (x.tickLower, x.tickUpper) = _oneSidedRange(x.cfg.initialTick, x.isToken0, x.dex.tickSpacing);

        (address t0, address t1) = x.isToken0 ? (x.token, pairToken) : (pairToken, x.token);
        uint160 sqrtP = TickMath.getSqrtRatioAtTick(x.poolTick);

        INonfungiblePositionManager npm = INonfungiblePositionManager(x.dex.positionManager);
        x.pool = npm.createAndInitializePoolIfNecessary(t0, t1, x.dex.poolFee, sqrtP);

        // opening pool tick must equal the range boundary exactly
        (, int24 tickNow,,,,,) = IUniswapV3Pool(x.pool).slot0();
        if (tickNow != x.poolTick) revert TickMisaligned();

        // approve + mint ONE one-sided position (launch token only)
        IERC20(x.token).forceApprove(address(npm), x.cfg.supply);
        (uint256 positionId,,,) = npm.mint(
            INonfungiblePositionManager.MintParams({
                token0: t0,
                token1: t1,
                fee: x.dex.poolFee,
                tickLower: x.tickLower,
                tickUpper: x.tickUpper,
                amount0Desired: x.isToken0 ? x.cfg.supply : 0,
                amount1Desired: x.isToken0 ? 0 : x.cfg.supply,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(this),
                deadline: block.timestamp
            })
        );
        x.positionId = positionId;

        // 13. clear allowance; 14. burn unavoidable dust
        IERC20(x.token).forceApprove(address(npm), 0);
        uint256 dust = IERC20(x.token).balanceOf(address(this));
        if (dust > 0) IERC20(x.token).safeTransfer(DEAD, dust);

        // 15. store immutable launch record (snapshot everything)
        address feeWallet = params.feeWallet == address(0) ? msg.sender : params.feeWallet;
        _graduationThresholds[x.token] = x.cfg.graduationThreshold;
        _launched[x.token] = LaunchedToken({
            token: x.token,
            deployer: msg.sender,
            feeWallet: feeWallet,
            pairedToken: pairToken,
            dexFactory: x.dex.factory,
            positionManager: x.dex.positionManager,
            swapRouter: x.dex.swapRouter,
            pool: x.pool,
            positionId: positionId,
            dexId: dexId,
            launchConfigId: launchConfigId,
            supply: x.cfg.supply,
            graduationThreshold: x.cfg.graduationThreshold,
            initialTick: x.cfg.initialTick,
            tickLower: x.tickLower,
            tickUpper: x.tickUpper,
            isToken0: x.isToken0,
            poolFee: x.dex.poolFee,
            protocolFeeShareBps: x.cfg.protocolFeeShareBps,
            maxInitialBuyBps: x.cfg.maxInitialBuyBps,
            initialBuyAmount: x.initialBuyAmount,
            createdAt: uint64(block.timestamp),
            resolvedSalt: x.salt,
            exists: true
        });
        _allTokens.push(x.token);
        _creatorTokens[msg.sender].push(x.token);

        // 16-19. transfer NFT to locker + register (snapshots protocol share + fee wallet)
        npm.safeTransferFrom(address(this), address(locker), positionId, "");
        locker.registerLock(
            x.token, msg.sender, feeWallet, x.dex.positionManager, positionId, x.cfg.protocolFeeShareBps
        );
    }

    /// @dev poolTick is the exact boundary the pool opens at.
    function _alignedPoolTick(int24 initialTick, bool isToken0, int24 tickSpacing) internal pure returns (int24) {
        if (initialTick % tickSpacing != 0) revert TickMisaligned();
        int24 pt = isToken0 ? initialTick : -initialTick;
        return pt;
    }

    /// @dev one-sided range flush to the opening tick.
    function _oneSidedRange(int24 initialTick, bool isToken0, int24 tickSpacing)
        internal
        pure
        returns (int24 tickLower, int24 tickUpper)
    {
        int24 maxUsable = (TickMath.MAX_TICK / tickSpacing) * tickSpacing;
        int24 minUsable = -maxUsable;
        if (isToken0) {
            tickLower = initialTick;
            tickUpper = maxUsable;
        } else {
            tickLower = minUsable;
            tickUpper = -initialTick;
        }
        if (tickLower >= tickUpper) revert InvalidTick();
    }

    /// @dev optional creator initial buy: swap pair→token via the configured
    ///      router, delivered to the fee wallet, with slippage + allocation
    ///      caps. V12: no token-side exemption exists or is needed — the token
    ///      has no transfer gate.
    function _initialBuy(
        LaunchCtx memory x,
        TokenParams calldata params,
        uint256 minInitialBuyOut,
        uint256 deadline
    ) internal {
        address recipient = params.feeWallet == address(0) ? msg.sender : params.feeWallet;
        x.recipient = recipient;

        uint256 tokensOut;
        if (x.cfg.routerRequiresDeadline) {
            tokensOut = ISwapRouterV3(x.dex.swapRouter).exactInputSingle{value: x.initialBuyAmount}(
                ISwapRouterV3.ExactInputSingleParams({
                    tokenIn: x.cfg.pairToken,
                    tokenOut: x.token,
                    fee: x.dex.poolFee,
                    recipient: recipient,
                    deadline: deadline,
                    amountIn: x.initialBuyAmount,
                    amountOutMinimum: minInitialBuyOut,
                    sqrtPriceLimitX96: 0
                })
            );
        } else {
            tokensOut = ISwapRouter02(x.dex.swapRouter).exactInputSingle{value: x.initialBuyAmount}(
                ISwapRouter02.ExactInputSingleParams({
                    tokenIn: x.cfg.pairToken,
                    tokenOut: x.token,
                    fee: x.dex.poolFee,
                    recipient: recipient,
                    amountIn: x.initialBuyAmount,
                    amountOutMinimum: minInitialBuyOut,
                    sqrtPriceLimitX96: 0
                })
            );
        }

        // 22. allocation cap (5% hard max enforced by config validation)
        uint256 maxOut = (x.cfg.supply * x.cfg.maxInitialBuyBps) / BPS;
        if (tokensOut > maxOut) revert InitialBuyTooLarge(tokensOut, maxOut);

        emit InitialBuyExecuted(x.token, msg.sender, recipient, x.initialBuyAmount, tokensOut);
    }

    function _validateMeta(TokenParams calldata p) internal pure {
        if (bytes(p.name).length == 0 || bytes(p.symbol).length == 0) revert EmptyNameOrSymbol();
        if (bytes(p.symbol).length > 12) revert SymbolTooLong();
        if (bytes(p.metadataURI).length == 0) revert MetadataRequired();
        if (
            bytes(p.logo).length > 256 || bytes(p.description).length > 512
                || bytes(p.socials.twitter).length > 256 || bytes(p.socials.telegram).length > 256
                || bytes(p.socials.discord).length > 256 || bytes(p.socials.website).length > 256
                || bytes(p.socials.farcaster).length > 256
        ) revert TokenMetaTooLong();
    }

    // ==================================================================
    // Graduation (read-only, live, reversible)
    // ==================================================================

    /// @notice Paired-token principal represented by the LOCKED position (from
    ///         V3 liquidity math — NOT pool balance, NOT uncollected fees), the
    ///         snapshot threshold, progress in bps (capped 10000), and whether
    ///         the milestone is currently reached. Reversible: selling that
    ///         reduces principal below the threshold flips `graduated` back to
    ///         false. Graduation moves nothing on-chain.
    function graduationStatus(address token)
        external
        view
        returns (uint256 pairedPrincipal, uint256 threshold, uint256 progressBps, bool graduated)
    {
        LaunchedToken memory r = _launched[token];
        threshold = _graduationThresholds[token];
        if (!r.exists) return (0, threshold, 0, false);

        pairedPrincipal = _pairedPrincipal(r);

        if (threshold == 0) {
            return (pairedPrincipal, 0, 0, false);
        }
        graduated = pairedPrincipal >= threshold;
        uint256 p = (pairedPrincipal * BPS) / threshold;
        progressBps = p > BPS ? BPS : p;
    }

    function _pairedPrincipal(LaunchedToken memory r) internal view returns (uint256) {
        (uint160 sqrtP,,,,,,) = IUniswapV3Pool(r.pool).slot0();
        (,,,,,,, uint128 liquidity,,,,) = INonfungiblePositionManager(r.positionManager).positions(r.positionId);
        if (liquidity == 0) return 0;
        (uint256 amount0, uint256 amount1) = LiquidityAmounts.getAmountsForLiquidity(
            sqrtP,
            TickMath.getSqrtRatioAtTick(r.tickLower),
            TickMath.getSqrtRatioAtTick(r.tickUpper),
            liquidity
        );
        // paired principal = the NON-launch-token side
        return r.isToken0 ? amount1 : amount0;
    }

    // ==================================================================
    // Views / records
    // ==================================================================

    function getLaunchedToken(address token) external view returns (LaunchedToken memory) {
        return _launched[token];
    }

    function isLaunchedToken(address token) external view returns (bool) {
        return _launched[token].exists;
    }

    function poolOf(address token) external view returns (address) {
        return _launched[token].pool;
    }

    function positionIdOf(address token) external view returns (uint256) {
        return _launched[token].positionId;
    }

    function positionManagerOf(address token) external view returns (address) {
        return _launched[token].positionManager;
    }

    function tokensByCreator(address creator) external view returns (address[] memory) {
        return _creatorTokens[creator];
    }

    function tokenCount() external view returns (uint256) {
        return _allTokens.length;
    }

    function allTokens(uint256 index) external view returns (address) {
        return _allTokens[index];
    }

    /// @notice Current creator fee recipient (lives in the locker; may differ
    ///         from the immutable creator after a creator redirect).
    function creatorFeeRecipient(address token) external view returns (address) {
        return locker.creatorFeeRecipient(token);
    }

    /// @notice Snapshotted protocol fee share for `token` (from the locker).
    function tokenProtocolFeeShare(address token) external view returns (uint16) {
        return locker.tokenProtocolFeeShare(token);
    }

    /// @notice Ownership status across both platform contracts.
    function platformOwnershipStatus()
        external
        view
        returns (address factoryOwner, address factoryPendingOwner, address lockerOwner, address lockerPendingOwner)
    {
        factoryOwner = owner();
        factoryPendingOwner = pendingOwner();
        lockerOwner = IOwnable2StepView(address(locker)).owner();
        lockerPendingOwner = IOwnable2StepView(address(locker)).pendingOwner();
    }

    /// @dev accept ETH refunds from routers (e.g. unused ETH on a swap).
    receive() external payable {}
}
