// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IPlatformControls} from "../interfaces/IPlatformControls.sol";
import {MemeTokenV2} from "./MemeTokenV2.sol";

interface IStockRewardTreasuryLike {
    function recordFees(address pool, uint256 holderWeth, uint256 creatorWeth, uint256 protocolWeth) external;
}

interface IGraduationAdapterLike {
    function graduate(address meme, address weth, uint256 wethAmount, uint256 memeAmount, uint24 fee, int24 tickSpacing)
        external
        returns (bytes32 poolId, uint128 liquidity);
}

/// @title BondingCurvePoolV2
/// @notice Constant-product bonding curve (virtual reserves) with an explicit
///         graduation lifecycle. Fees are pushed to the StockRewardTreasury
///         (async stock conversion) so the pool holds ONLY principal WETH. When
///         the target is reached the crossing buy is capped (excess refunded),
///         curve trading is permanently disabled, and the net principal migrates
///         to a locked Uniswap V4 position at the terminal price.
contract BondingCurvePoolV2 is ReentrancyGuard {
    using SafeERC20 for IERC20;

    enum PoolLifecycle {
        ACTIVE,
        READY_TO_GRADUATE,
        MIGRATING,
        GRADUATED,
        MIGRATION_FAILED,
        PAUSED
    }

    struct FeeConfig {
        uint16 totalFeeBps;
        uint16 holderShareBps;
        uint16 creatorShareBps;
        uint16 protocolShareBps;
    }

    uint256 public constant BPS = 10_000;
    uint256 public constant MAX_FEE_BPS = 1_000;

    address public immutable factory;
    IERC20 public immutable memeToken;
    IERC20 public immutable weth;
    address public immutable treasury; // StockRewardTreasury
    address public immutable creator;
    address public immutable graduationManager;
    address public immutable graduationAdapter;
    uint24 public immutable gradFee;
    int24 public immutable gradTickSpacing;

    FeeConfig public feeConfig;
    uint256 public immutable virtualQuote;
    uint256 public immutable virtualToken;
    uint256 public immutable graduationTarget;

    uint256 public realQuote;
    PoolLifecycle public state;
    bytes32 public graduatedPoolId;

    event Buy(address indexed buyer, uint256 quoteIn, uint256 tokensOut, uint256 fee, uint256 refund);
    event Sell(address indexed seller, uint256 tokensIn, uint256 quoteOut, uint256 fee);
    event FeeRouted(uint256 holder, uint256 creator, uint256 protocol);
    event GraduationReady(uint256 principal);
    event GraduationStarted(uint256 principal, uint256 memeForLiquidity, uint256 burned);
    event GraduationCompleted(bytes32 indexed poolId, uint128 liquidity);
    event GraduationFailed(bytes reason);

    error ZeroAddress();
    error ZeroAmount();
    error FeeTooHigh();
    error SharesInvalid();
    error InvalidCurveParams();
    error SlippageExceeded();
    error SlippageBoundRequired();
    error ExceedsCurveDepth();
    error NotActive();
    error NotReady();
    error TradingIsPaused();
    error OnlyGraduationManager();

    struct InitParams {
        address memeToken;
        address weth;
        address treasury;
        address creator;
        address graduationManager;
        address graduationAdapter;
        uint24 gradFee;
        int24 gradTickSpacing;
        FeeConfig feeConfig;
        uint256 virtualQuote;
        uint256 virtualToken;
        uint256 graduationTarget;
    }

    constructor(InitParams memory p) {
        if (
            p.memeToken == address(0) || p.weth == address(0) || p.treasury == address(0) || p.creator == address(0)
                || p.graduationManager == address(0) || p.graduationAdapter == address(0)
        ) revert ZeroAddress();
        if (p.virtualQuote == 0 || p.virtualToken == 0 || p.graduationTarget == 0) revert InvalidCurveParams();
        if (p.feeConfig.totalFeeBps > MAX_FEE_BPS) revert FeeTooHigh();
        if (uint256(p.feeConfig.holderShareBps) + p.feeConfig.creatorShareBps + p.feeConfig.protocolShareBps != BPS) {
            revert SharesInvalid();
        }
        factory = msg.sender;
        memeToken = IERC20(p.memeToken);
        weth = IERC20(p.weth);
        treasury = p.treasury;
        creator = p.creator;
        graduationManager = p.graduationManager;
        graduationAdapter = p.graduationAdapter;
        gradFee = p.gradFee;
        gradTickSpacing = p.gradTickSpacing;
        feeConfig = p.feeConfig;
        virtualQuote = p.virtualQuote;
        virtualToken = p.virtualToken;
        graduationTarget = p.graduationTarget;
        state = PoolLifecycle.ACTIVE;
    }

    // ---- views ----

    function tokenReserve() public view returns (uint256) {
        return memeToken.balanceOf(address(this));
    }

    function terminalPrice() public view returns (uint256) {
        return ((virtualQuote + realQuote) * 1e18) / (virtualToken + tokenReserve());
    }

    /// @notice Tokens out for a gross quoteIn (fee-inclusive), for UIs.
    function quoteBuy(uint256 quoteIn) public view returns (uint256 tokensOut, uint256 fee) {
        fee = (quoteIn * feeConfig.totalFeeBps) / BPS;
        tokensOut = _tokensOutForNet(quoteIn - fee);
    }

    function quoteSell(uint256 tokensIn) public view returns (uint256 quoteOut, uint256 fee) {
        uint256 q = virtualQuote + realQuote;
        uint256 t = virtualToken + tokenReserve();
        uint256 k = q * t;
        uint256 denom = t + tokensIn;
        uint256 grossOut = q - (k + denom - 1) / denom;
        fee = (grossOut * feeConfig.totalFeeBps) / BPS;
        quoteOut = grossOut - fee;
    }

    function _tokensOutForNet(uint256 net) internal view returns (uint256) {
        uint256 q = virtualQuote + realQuote;
        uint256 t = virtualToken + tokenReserve();
        uint256 k = q * t;
        uint256 denom = q + net;
        return t - (k + denom - 1) / denom;
    }

    // ---- trading ----

    function buy(uint256 quoteIn, uint256 minTokensOut) external nonReentrant returns (uint256 tokensOut) {
        _requireActive();
        if (quoteIn == 0) revert ZeroAmount();
        if (minTokensOut == 0) revert SlippageBoundRequired();

        weth.safeTransferFrom(msg.sender, address(this), quoteIn);

        uint256 feeBps = feeConfig.totalFeeBps;
        uint256 fee = (quoteIn * feeBps) / BPS;
        uint256 net = quoteIn - fee;
        uint256 refund;

        bool crossing = realQuote + net >= graduationTarget;
        if (crossing) {
            uint256 neededNet = graduationTarget - realQuote;
            // gross required to net exactly `neededNet` (round up)
            uint256 grossNeeded = (neededNet * BPS + (BPS - feeBps) - 1) / (BPS - feeBps);
            if (grossNeeded > quoteIn) grossNeeded = quoteIn;
            refund = quoteIn - grossNeeded;
            fee = (grossNeeded * feeBps) / BPS;
            net = grossNeeded - fee;
            if (refund > 0) weth.safeTransfer(msg.sender, refund);
        }

        tokensOut = _tokensOutForNet(net);
        if (tokensOut < minTokensOut) revert SlippageExceeded();
        if (tokensOut > tokenReserve()) revert ExceedsCurveDepth();

        realQuote += net;
        memeToken.safeTransfer(msg.sender, tokensOut);
        _routeFee(fee);
        emit Buy(msg.sender, quoteIn - refund, tokensOut, fee, refund);

        if (crossing || realQuote >= graduationTarget) {
            state = PoolLifecycle.READY_TO_GRADUATE;
            emit GraduationReady(realQuote);
        }
    }

    function sell(uint256 tokensIn, uint256 minQuoteOut) external nonReentrant returns (uint256 quoteOut) {
        _requireActive();
        if (tokensIn == 0) revert ZeroAmount();
        if (minQuoteOut == 0) revert SlippageBoundRequired();

        uint256 fee;
        (quoteOut, fee) = quoteSell(tokensIn);
        if (quoteOut < minQuoteOut) revert SlippageExceeded();

        memeToken.safeTransferFrom(msg.sender, address(this), tokensIn);
        realQuote -= quoteOut + fee;
        weth.safeTransfer(msg.sender, quoteOut);
        _routeFee(fee);
        emit Sell(msg.sender, tokensIn, quoteOut, fee);
    }

    function _routeFee(uint256 fee) internal {
        if (fee == 0) return;
        uint256 holder = (fee * feeConfig.holderShareBps) / BPS;
        uint256 creatorAmt = (fee * feeConfig.creatorShareBps) / BPS;
        uint256 protocol = fee - holder - creatorAmt;
        weth.forceApprove(treasury, fee);
        IStockRewardTreasuryLike(treasury).recordFees(address(this), holder, creatorAmt, protocol);
        emit FeeRouted(holder, creatorAmt, protocol);
    }

    // ---- graduation ----

    /// @notice Migrate principal to a locked Uniswap V4 position. Only the
    ///         GraduationManager. Atomic try/catch: success -> GRADUATED,
    ///         failure -> MIGRATION_FAILED with principal intact for retry.
    function finalizeGraduation() external nonReentrant returns (bytes32 poolId, uint128 liquidity) {
        if (msg.sender != graduationManager) revert OnlyGraduationManager();
        if (state != PoolLifecycle.READY_TO_GRADUATE && state != PoolLifecycle.MIGRATION_FAILED) revert NotReady();
        state = PoolLifecycle.MIGRATING;

        uint256 principal = realQuote;
        uint256 reserve = tokenReserve();
        // meme amount that prices the DEX pool at the terminal curve price
        uint256 memeForLiq = (principal * (virtualToken + reserve)) / (virtualQuote + realQuote);
        if (memeForLiq > reserve) memeForLiq = reserve;

        weth.forceApprove(graduationAdapter, principal);
        memeToken.forceApprove(graduationAdapter, memeForLiq);
        emit GraduationStarted(principal, memeForLiq, reserve - memeForLiq);

        try IGraduationAdapterLike(graduationAdapter)
            .graduate(address(memeToken), address(weth), principal, memeForLiq, gradFee, gradTickSpacing) returns (
            bytes32 id, uint128 liq
        ) {
            realQuote = 0;
            graduatedPoolId = id;
            state = PoolLifecycle.GRADUATED;
            // burn any unsold curve tokens left after liquidity provisioning
            uint256 leftover = tokenReserve();
            if (leftover > 0) MemeTokenV2(address(memeToken)).burnFromPool(leftover);
            emit GraduationCompleted(id, liq);
            return (id, liq);
        } catch (bytes memory reason) {
            weth.forceApprove(graduationAdapter, 0);
            memeToken.forceApprove(graduationAdapter, 0);
            state = PoolLifecycle.MIGRATION_FAILED;
            emit GraduationFailed(reason);
            return (bytes32(0), 0);
        }
    }

    // ---- internal ----

    function _requireActive() internal view {
        if (IPlatformControls(factory).tradingPaused()) revert TradingIsPaused();
        if (state != PoolLifecycle.ACTIVE) revert NotActive();
    }
}
