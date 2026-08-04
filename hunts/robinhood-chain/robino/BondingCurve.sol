// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {MemeToken} from "./MemeToken.sol";
import {Math} from "./Math.sol";
import {
    Currency,
    IERC20Minimal,
    IHooks,
    IPermit2,
    IV4PoolManager,
    IV4PositionManager,
    PoolKey,
    V4Actions
} from "./interfaces/IUniswapV4.sol";

interface ILaunchpadFactoryEvents {
    function emitTrade(address token, address trader, bool isBuy, uint256 ethAmount, uint256 tokenAmount, uint256 feeBps) external;
    function emitGraduated(address token, bytes32 poolId, address hook, uint256 ethLiquidity, uint256 tokenLiquidity, uint256 lpTokenId) external;
}

interface IFeeCollectorDeployer {
    function deploy(
        address positionManager,
        address creator,
        address platform,
        PoolKey memory poolKey,
        uint16 creatorShareBps,
        uint256 unlockTime,
        uint128 liquidity
    ) external returns (address collector);
}

/// @title BondingCurve
/// @notice One curve per token. Constant-product (x*y=k) virtual AMM, pump.fun style.
///         - 1B fixed supply; unsold tokens stay locked in the curve after graduation.
///         - Dynamic fee: starts 10%, decays linearly to 1% over the first 180s, then flat 1%.
///         - Fee split: 60% creator / 40% platform (pull-based claims).
///         - Anti-snipe: 2% max-wallet for the first 30 seconds.
///         - Graduates at target ETH collected -> creates a Uniswap v4 pool,
///           adds the configured migration token share plus ETH,
///           leaves unsold curve tokens locked forever, and locks LP principal.
///
/// @dev TESTNET DRAFT — must be audited before mainnet. Deploy to Robinhood testnet (46630) first.
contract BondingCurve {
    // ----------------------------------------------------------------- deploy config
    uint256 public immutable TOTAL_SUPPLY;
    uint256 public immutable SALE_TOKENS;
    uint256 public immutable LP_TOKENS;
    uint256 public immutable VIRTUAL_TOKEN_RESERVES;
    uint256 public immutable VIRTUAL_ETH_RESERVES;
    uint256 public immutable GRADUATION_ETH;
    uint16 public immutable POOL_MIGRATION_BPS;
    uint16 public immutable CURVE_TARGET_SOLD_BPS;

    // dynamic fee (basis points)
    uint16 public immutable START_FEE_BPS;
    uint16 public immutable BASE_FEE_BPS;
    uint256 public immutable FEE_DECAY;

    // fee split
    uint16 public immutable CREATOR_SHARE_BPS;

    // anti-snipe
    uint256 public immutable MAX_WALLET;
    uint256 public immutable LIMIT_WINDOW;
    // the creator's atomic dev-buy (routed via the factory) is exempt from the 2% cap,
    // but hard-capped at 5% of supply — matches bow.fun and the launch UI copy.
    uint256 public immutable MAX_DEV_BUY;

    // Uniswap v4 fee tier. 5000 = 0.5%, passed by the factory at deploy time.
    int24 public immutable TICK_LOWER;
    int24 public immutable TICK_UPPER;
    int24 public immutable TICK_SPACING;
    uint16 public immutable LP_CREATOR_SHARE_BPS;
    uint256 public immutable LP_UNLOCK_DELAY;

    // ----------------------------------------------------------------- immutables
    MemeToken public immutable token;
    address public immutable factory; // the LaunchpadFactory that deployed this curve
    address public immutable creator;
    address public immutable platform;
    address public immutable feeCollectorDeployer;
    IV4PoolManager public immutable poolManager;
    IV4PositionManager public immutable positionManager;
    IPermit2 public immutable permit2;
    address public immutable launchHook;
    uint24 public immutable poolFee;
    uint256 public immutable launchTime;

    // ----------------------------------------------------------------- state
    uint256 public virtualTokenReserves;
    uint256 public virtualEthReserves;
    uint256 public realTokenReserves; // sale tokens still available on the curve
    uint256 public realEthReserves;   // net ETH collected into the curve
    bool    public graduated;
    address public lpFeeCollector;

    uint256 public creatorFeesAccrued;
    uint256 public platformFeesAccrued;

    // ----------------------------------------------------------------- events
    event Buy(address indexed buyer, uint256 ethIn, uint256 tokensOut, uint256 feeBps);
    event Sell(address indexed seller, uint256 tokensIn, uint256 ethOut, uint256 feeBps);
    event Graduated(bytes32 indexed poolId, address indexed hook, uint256 ethLiquidity, uint256 tokenLiquidity, uint256 lpTokenId);

    bool private _locked;
    modifier nonReentrant() {
        require(!_locked, "lock");
        _locked = true;
        _;
        _locked = false;
    }

    struct Config {
        address creator;
        address factory;
        address platform;
        address feeCollectorDeployer;
        address poolManager;
        address positionManager;
        address permit2;
        address launchHook;
        uint24 poolFee;
        uint256 totalSupply;
        uint256 saleTokens;
        uint256 virtualTokenReserves;
        uint256 virtualEthReserves;
        uint256 graduationEth;
        uint16 startFeeBps;
        uint16 baseFeeBps;
        uint256 feeDecay;
        uint16 creatorShareBps;
        uint16 maxWalletBps;
        uint256 limitWindow;
        uint16 maxDevBuyBps;
        int24 tickLower;
        int24 tickUpper;
        int24 tickSpacing;
        uint16 lpCreatorShareBps;
        uint256 lpUnlockDelay;
        uint16 poolMigrationBps;
        uint16 curveTargetSoldBps;
    }

    constructor(MemeToken.Meta memory meta, Config memory c) {
        require(c.creator != address(0), "creator");
        require(c.factory != address(0), "factory");
        require(c.platform != address(0), "platform");
        require(c.feeCollectorDeployer != address(0), "collector deployer");
        require(c.poolManager != address(0), "pm");
        require(c.positionManager != address(0), "pos");
        require(c.permit2 != address(0), "permit2");
        require(c.saleTokens < c.totalSupply, "lp tokens");
        factory = c.factory;
        creator = c.creator;
        platform = c.platform;
        feeCollectorDeployer = c.feeCollectorDeployer;
        poolManager = IV4PoolManager(c.poolManager);
        positionManager = IV4PositionManager(c.positionManager);
        permit2 = IPermit2(c.permit2);
        launchHook = c.launchHook;
        poolFee = c.poolFee;
        launchTime = block.timestamp;
        TOTAL_SUPPLY = c.totalSupply;
        SALE_TOKENS = c.saleTokens;
        LP_TOKENS = c.totalSupply - c.saleTokens;
        VIRTUAL_TOKEN_RESERVES = c.virtualTokenReserves;
        VIRTUAL_ETH_RESERVES = c.virtualEthReserves;
        GRADUATION_ETH = c.graduationEth;
        POOL_MIGRATION_BPS = c.poolMigrationBps;
        CURVE_TARGET_SOLD_BPS = c.curveTargetSoldBps;
        START_FEE_BPS = c.startFeeBps;
        BASE_FEE_BPS = c.baseFeeBps;
        FEE_DECAY = c.feeDecay;
        CREATOR_SHARE_BPS = c.creatorShareBps;
        MAX_WALLET = c.totalSupply * c.maxWalletBps / 10000;
        LIMIT_WINDOW = c.limitWindow;
        MAX_DEV_BUY = c.totalSupply * c.maxDevBuyBps / 10000;
        TICK_LOWER = c.tickLower;
        TICK_UPPER = c.tickUpper;
        TICK_SPACING = c.tickSpacing;
        LP_CREATOR_SHARE_BPS = c.lpCreatorShareBps;
        LP_UNLOCK_DELAY = c.lpUnlockDelay;

        // mint full supply to this curve
        token = new MemeToken(meta, c.totalSupply, c.creator, c.factory);

        virtualTokenReserves = c.virtualTokenReserves;
        virtualEthReserves = c.virtualEthReserves;
        realTokenReserves = c.saleTokens;
        realEthReserves = 0;
    }

    // ----------------------------------------------------------------- views
    /// @notice Current trading fee in basis points (10% -> 1% over 180s).
    function currentFeeBps() public view returns (uint16) {
        uint256 elapsed = block.timestamp - launchTime;
        if (elapsed >= FEE_DECAY) return BASE_FEE_BPS;
        // linear: 1000 - 5*elapsed  (900 bps of decay across 180s)
        return uint16(uint256(START_FEE_BPS) - (uint256(START_FEE_BPS - BASE_FEE_BPS) * elapsed) / FEE_DECAY);
    }

    /// @notice tokens out for a given net ETH in (before applying real-token cap).
    function _tokensOutFor(uint256 netEthIn) internal view returns (uint256) {
        return Math.mulDiv(virtualTokenReserves, netEthIn, virtualEthReserves + netEthIn);
    }

    /// @notice net ETH out for tokens in.
    function _ethOutFor(uint256 tokensIn) internal view returns (uint256) {
        return Math.mulDiv(virtualEthReserves, tokensIn, virtualTokenReserves + tokensIn);
    }

    /// @dev net ETH required to receive exactly `tokensOut` tokens.
    function _ethInForTokens(uint256 tokensOut) internal view returns (uint256) {
        require(tokensOut < virtualTokenReserves, "many");
        return Math.mulDiv(virtualEthReserves, tokensOut, virtualTokenReserves - tokensOut) + 1;
    }

    function _grossForNet(uint256 netEth, uint16 feeBps) internal pure returns (uint256) {
        uint256 denom = 10000 - uint256(feeBps);
        return (netEth * 10000 + denom - 1) / denom;
    }

    // ----------------------------------------------------------------- trading
    function buy(uint256 minTokensOut) external payable nonReentrant returns (uint256 tokensOut) {
        require(!graduated, "grad");
        require(msg.value > 0, "eth");

        uint16 feeBps = currentFeeBps();
        uint256 grossEth = msg.value;
        uint256 feeAmt = (grossEth * feeBps) / 10000;
        uint256 netEth = grossEth - feeAmt;
        uint256 refund;

        if (realEthReserves + netEth > GRADUATION_ETH) {
            uint256 netNeeded = GRADUATION_ETH - realEthReserves;
            uint256 grossNeeded = _grossForNet(netNeeded, feeBps);
            if (grossNeeded < grossEth) {
                grossEth = grossNeeded;
                feeAmt = grossEth - netNeeded;
                netEth = netNeeded;
            }
        }

        tokensOut = _tokensOutFor(netEth);

        // final-buy cap: never sell more than the sale tokens left
        if (tokensOut >= realTokenReserves) {
            tokensOut = realTokenReserves;
            uint256 netNeeded = _ethInForTokens(tokensOut);
            if (netNeeded < netEth) {
                uint256 grossNeeded = _grossForNet(netNeeded, feeBps);
                grossEth = grossNeeded;
                feeAmt = grossEth - netNeeded;
                netEth = netNeeded;
            }
        }

        refund = msg.value - grossEth;

        require(tokensOut >= minTokensOut, "slip");

        // anti-snipe max-wallet during the opening window.
        // The factory-routed dev-buy is exempt (it lands before any public buyer),
        // but is hard-capped at 5% of supply.
        if (msg.sender == factory) {
            require(tokensOut <= MAX_DEV_BUY, "dev buy");
        } else if (block.timestamp < launchTime + LIMIT_WINDOW) {
            require(token.balanceOf(msg.sender) + tokensOut <= MAX_WALLET, "wallet");
        }

        // update reserves
        virtualEthReserves += netEth;
        virtualTokenReserves -= tokensOut;
        realEthReserves += netEth;
        realTokenReserves -= tokensOut;

        _splitFee(feeAmt);
        require(token.transfer(msg.sender, tokensOut), "xfer");
        if (refund > 0) {
            (bool ok, ) = msg.sender.call{value: refund}("");
            require(ok, "ref");
        }

        emit Buy(msg.sender, grossEth, tokensOut, feeBps);
        ILaunchpadFactoryEvents(factory).emitTrade(address(token), msg.sender, true, grossEth, tokensOut, feeBps);

        if (realEthReserves >= GRADUATION_ETH || realTokenReserves == 0) {
            _graduate();
        }
    }

    function sell(uint256 tokensIn, uint256 minEthOut) external nonReentrant returns (uint256 ethOut) {
        require(!graduated, "grad");
        require(tokensIn > 0, "tok");

        uint256 grossEth = _ethOutFor(tokensIn);
        require(grossEth <= realEthReserves, "reserve");

        uint16 feeBps = currentFeeBps();
        uint256 feeAmt = (grossEth * feeBps) / 10000;
        ethOut = grossEth - feeAmt;
        require(ethOut >= minEthOut, "slip");

        // pull tokens in
        require(token.transferFrom(msg.sender, address(this), tokensIn), "xfer");

        virtualTokenReserves += tokensIn;
        virtualEthReserves -= grossEth;
        realTokenReserves += tokensIn;
        realEthReserves -= grossEth;

        _splitFee(feeAmt);
        (bool ok, ) = msg.sender.call{value: ethOut}("");
        require(ok, "eth");

        emit Sell(msg.sender, tokensIn, ethOut, feeBps);
        ILaunchpadFactoryEvents(factory).emitTrade(address(token), msg.sender, false, ethOut, tokensIn, feeBps);
    }

    function _splitFee(uint256 feeAmt) internal {
        if (feeAmt == 0) return;
        uint256 creatorCut = (feeAmt * CREATOR_SHARE_BPS) / 10000;
        creatorFeesAccrued += creatorCut;
        platformFeesAccrued += feeAmt - creatorCut;
    }

    // ----------------------------------------------------------------- claims
    function claimCreatorFees() external nonReentrant {
        require(msg.sender == creator, "creator");
        uint256 amt = creatorFeesAccrued;
        require(amt > 0, "none");
        creatorFeesAccrued = 0;
        (bool ok, ) = creator.call{value: amt}("");
        require(ok, "send");
    }

    function claimPlatformFees() external nonReentrant {
        require(msg.sender == platform, "platform");
        uint256 amt = platformFeesAccrued;
        require(amt > 0, "none");
        platformFeesAccrued = 0;
        (bool ok, ) = platform.call{value: amt}("");
        require(ok, "send");
    }

    // ----------------------------------------------------------------- graduation
    function _graduate() internal {
        graduated = true;

        uint256 ethLiq = realEthReserves;
        uint256 tokenLiq = TOTAL_SUPPLY * uint256(POOL_MIGRATION_BPS) / 10000;
        require(token.balanceOf(address(this)) >= tokenLiq, "lp");

        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(address(0)),
            currency1: Currency.wrap(address(token)),
            fee: poolFee,
            tickSpacing: TICK_SPACING,
            hooks: IHooks(launchHook)
        });

        uint160 sqrtPriceX96 = _sqrtPriceX96(ethLiq, tokenLiq);
        poolManager.initialize(key, sqrtPriceX96);
        bytes32 poolId = _poolId(key);
        uint128 liquidity = uint128(Math.sqrt(ethLiq * tokenLiq));

        lpFeeCollector = IFeeCollectorDeployer(feeCollectorDeployer).deploy(
            address(positionManager),
            creator,
            platform,
            key,
            LP_CREATOR_SHARE_BPS,
            block.timestamp + LP_UNLOCK_DELAY,
            liquidity
        );

        require(IERC20Minimal(address(token)).approve(address(permit2), tokenLiq), "p2");
        require(IERC20Minimal(address(token)).approve(address(positionManager), tokenLiq), "pm");
        permit2.approve(address(token), address(positionManager), uint160(tokenLiq), uint48(block.timestamp + 1 days));

        uint256 lpTokenId = positionManager.nextTokenId();
        bytes memory actions = abi.encodePacked(
            uint8(V4Actions.MINT_POSITION),
            uint8(V4Actions.SETTLE_PAIR),
            uint8(V4Actions.SWEEP)
        );
        bytes[] memory params = new bytes[](3);
        params[0] = abi.encode(
            key,
            TICK_LOWER,
            TICK_UPPER,
            uint256(liquidity),
            uint128(ethLiq),
            uint128(tokenLiq),
            lpFeeCollector,
            abi.encode(address(token), creator)
        );
        params[1] = abi.encode(key.currency0, key.currency1);
        params[2] = abi.encode(key.currency0, address(this));
        positionManager.modifyLiquidities{value: ethLiq}(abi.encode(actions, params), block.timestamp + 300);
        (bool set, ) = lpFeeCollector.call(abi.encodeWithSignature("setTokenId(uint256)", lpTokenId));
        require(set, "collector token");
        realTokenReserves = token.balanceOf(address(this));

        emit Graduated(poolId, launchHook, ethLiq, tokenLiq, lpTokenId);
        ILaunchpadFactoryEvents(factory).emitGraduated(address(token), poolId, launchHook, ethLiq, tokenLiq, lpTokenId);
    }

    /// @dev sqrtPriceX96 = sqrt(amount1/amount0) * 2^96, full precision.
    function _sqrtPriceX96(uint256 amount0, uint256 amount1) internal pure returns (uint160) {
        // ratioX192 = amount1 * 2^192 / amount0 ; sqrt gives sqrtPrice * 2^96
        uint256 ratioX192 = Math.mulDiv(amount1, 1 << 192, amount0);
        uint256 s = Math.sqrt(ratioX192);
        require(s <= type(uint160).max, "price");
        return uint160(s);
    }

    function _poolId(PoolKey memory key) internal pure returns (bytes32) {
        return keccak256(abi.encode(key.currency0, key.currency1, key.fee, key.tickSpacing, address(key.hooks)));
    }

    receive() external payable {}
}
