// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IEquityVault} from "./interfaces/IEquityVault.sol";
import {OracleRouter} from "./OracleRouter.sol";
import {PerpMath, Side} from "./libs/PerpMath.sol";
import {SessionLib} from "./libs/SessionLib.sol";
import {VaultMath} from "./libs/VaultMath.sol";
import {MarketConfigLib} from "./libs/MarketConfigLib.sol";
import {AdlLib} from "./libs/AdlLib.sol";

contract PerpEngine is Ownable2Step {
    using SafeERC20 for IERC20;

    error ZeroAddress();
    error Halted();
    error MarketPaused();
    error MarketNotListed();

    error FundingCadenceTooFast();
    error AlreadyListed();
    error BadBps();
    error BadLeverage();
    error BadBreakpoints();

    error BadParam();
    error NotAuthorized();

    error NoLiquidity();
    error ZeroAmount();
    error BelowMinCollateral();

    error LeverageBelowOne();
    error LeverageExceedsTierCap();
    error LeverageExceedsMarketCap();
    error InsufficientInitialMargin();
    error Slippage();
    error FreeLiquidityFloor();
    error OiCapExceeded();
    error NotPositionOwner();
    error BadCloseSize();

    error SurvivorBelowMin();
    error PositionNotFound();

    error PositionHealthy();

    error BadDebtAboveMax();

    error SelfLiquidation();

    error PositionCapReached();

    error NotOrders();

    error AdlDisarmed();

    error AdlNotArmed();

    event FundingUpdated(
        bytes32 indexed marketId,
        int256 fundingIndex,
        int256 savedFundingRate,
        uint256 longCumBorrowFactor,
        uint256 shortCumBorrowFactor,
        uint256 longOi,
        uint256 shortOi
    );

    event PositionOpened(
        bytes32 indexed key,
        address indexed owner,
        bytes32 indexed marketId,
        Side side,
        uint256 size,
        uint256 collateral,
        uint256 entryPrice,
        uint256 fee,
        int256 fundingSnap,
        uint256 borrowSnap
    );

    event PositionClosed(
        bytes32 indexed key,
        address indexed owner,
        bytes32 indexed marketId,
        Side side,
        uint256 closeSize,
        uint256 exitPrice,
        int256 pnl,
        uint256 userPayout,
        uint256 paidDirect,
        uint256 enqueued,
        int256 fundingApplied,
        uint256 borrowFee,
        uint256 fee,
        uint8 closedBy
    );

    event BadDebt(bytes32 indexed marketId, address indexed owner, uint256 amount);
    event Liquidated(
        bytes32 indexed key,
        address indexed owner,
        bytes32 indexed marketId,
        address liquidator,
        uint256 exitPrice,
        uint256 equity,
        uint256 reward,
        uint256 insurance,
        uint256 badDebt
    );
    event MarketListed(bytes32 indexed marketId);
    event MarketConfigUpdated(bytes32 indexed marketId);
    event ProtocolCfgSet();
    event MarketPausedSet(bytes32 indexed marketId, bool paused);
    event TradingHaltSet(HaltMode mode);
    event PauseAuthoritySet(address indexed authority);
    event OrdersSet(address indexed orders);

    event AdlTailUnclearable(bytes32 indexed marketId, uint256 deficit);

    enum HaltMode {
        None,
        ReduceOnly,
        Full
    }

    struct ProtocolCfg {

        uint256[5] tierBreakpoints;
        uint8[5] rthMaxLeverage;
        uint8[5] offHoursMaxLeverage;
        uint16 initialMarginBps;
        uint256 minCollateral;

        uint256 maxOpenPositionsPerWallet;
    }

    struct Market {
        bool listed;
        bool paused;

        uint16 baseFeeBps;

        uint16 favorableFeeBps;
        uint16 mmrBps;
        uint16 liqFeeBps;

        uint16 partialLiqTargetHealth;
        uint256 maxLeverage;
        uint256 maxOiLongRth;
        uint256 maxOiShortRth;
        uint256 maxOiLongOff;
        uint256 maxOiShortOff;

        uint256 longOi;
        uint256 shortOi;
        int256 fundingIndex;
        int256 savedFundingRate;
        uint64 lastFundingTs;
        uint256 longCumBorrowFactor;
        uint256 shortCumBorrowFactor;

        uint256 optimalUsage;
        uint256 borrowingFactor;
        uint256 aboveOptimalFactor;

        uint256 fundingIncrease;
        uint256 fundingDecrease;
        uint256 thresholdStable;
        uint256 thresholdDecrease;
        uint256 minFundingFactor;
        uint256 maxFundingFactor;

        bool adlFrozen;
        uint256 adlTailTriggerRth;
        uint256 adlTailTriggerOff;
        uint32 adlMinAgeRth;
        uint32 adlMinAgeOff;
        uint16 adlHaircutBpsRth;
        uint16 adlHaircutBpsOff;
        uint16 adlMaxHaircutBps;
    }

    struct MarketConfig {
        uint16 baseFeeBps;
        uint16 favorableFeeBps;
        uint16 mmrBps;
        uint16 liqFeeBps;
        uint16 partialLiqTargetHealth;
        uint256 maxLeverage;
        uint256 maxOiLongRth;
        uint256 maxOiShortRth;
        uint256 maxOiLongOff;
        uint256 maxOiShortOff;
        uint256 optimalUsage;
        uint256 borrowingFactor;
        uint256 aboveOptimalFactor;
        uint256 fundingIncrease;
        uint256 fundingDecrease;
        uint256 thresholdStable;
        uint256 thresholdDecrease;
        uint256 minFundingFactor;
        uint256 maxFundingFactor;
        bool adlFrozen;
        uint256 adlTailTriggerRth;
        uint256 adlTailTriggerOff;
        uint32 adlMinAgeRth;
        uint32 adlMinAgeOff;
        uint16 adlHaircutBpsRth;
        uint16 adlHaircutBpsOff;
        uint16 adlMaxHaircutBps;
    }

    IEquityVault public immutable vault;
    OracleRouter public immutable router;
    IERC20 public immutable usdg;

    ProtocolCfg public protocolCfg;
    HaltMode public haltMode;

    address public pauseAuthority;

    mapping(bytes32 => Market) internal markets;

    struct Position {
        address owner;
        bytes32 marketId;
        Side side;
        uint256 size;
        uint256 collateral;
        uint256 entryPrice;
        int256 fundingSnap;
        uint256 borrowSnap;
        uint256 reservedMaxPayout;
        uint64 openedAt;
    }

    mapping(bytes32 => Position) public positions;
    mapping(address => uint256) public positionNonce;

    mapping(address => mapping(bytes32 => uint256)) public walletMarketGross;

    address public orders;

    mapping(address => uint256) public openPositionCount;

    uint256 internal constant FUNDING_CADENCE_FLOOR = 5;

    uint8 public constant CLOSED_BY_OWNER = 0;
    uint8 public constant CLOSED_BY_ORDER = 1;
    uint8 public constant CLOSED_BY_LIQUIDATION = 2;

    constructor(address vault_, address router_, address usdg_) Ownable(msg.sender) {
        if (vault_ == address(0) || router_ == address(0) || usdg_ == address(0)) revert ZeroAddress();
        vault = IEquityVault(vault_);
        router = OracleRouter(router_);
        usdg = IERC20(usdg_);
    }

    modifier onlyOrders() {
        if (msg.sender != orders) revert NotOrders();
        _;
    }

    function getMarket(bytes32 marketId) external view returns (Market memory) {
        return markets[marketId];
    }

    function getProtocolCfg() external view returns (ProtocolCfg memory) {
        return protocolCfg;
    }

    function _isRthRisk() internal view returns (bool) {
        uint16 openM = router.rthOpenMinutesUtc();
        uint16 closeM = router.rthCloseMinutesUtc();
        return SessionLib.isRth(block.timestamp, openM, closeM) && !SessionLib.isBlend(block.timestamp, openM, closeM);
    }

    function updateFunding(bytes32 marketId) external {
        if (haltMode != HaltMode.None) revert Halted();
        Market storage m = markets[marketId];
        if (!m.listed) revert MarketNotListed();
        if (m.paused) revert MarketPaused();
        if (block.timestamp - m.lastFundingTs < FUNDING_CADENCE_FLOOR) revert FundingCadenceTooFast();
        _accrue(m, marketId);
    }

    function _updateFunding(bytes32 marketId) internal {
        _accrue(markets[marketId], marketId);
    }

    function _accrue(Market storage m, bytes32 marketId) private {
        uint64 last = m.lastFundingTs;
        if (last == 0) {

            m.lastFundingTs = uint64(block.timestamp);
            return;
        }
        uint256 elapsed = block.timestamp - last;
        if (elapsed == 0) return;

        m.savedFundingRate = PerpMath.calcAdaptiveFunding(
            m.savedFundingRate,
            m.longOi,
            m.shortOi,
            elapsed,
            m.fundingIncrease,
            m.fundingDecrease,
            m.thresholdStable,
            m.thresholdDecrease,
            m.minFundingFactor,
            m.maxFundingFactor
        );
        m.fundingIndex += m.savedFundingRate * int256(elapsed);

        uint256 total = vault.totalUsdg();
        if (total > 0) {
            (uint256 rLong, uint256 rShort,,) = vault.marketRisk(marketId);
            m.longCumBorrowFactor += PerpMath.calcBorrowingRate(
                PerpMath.calcClampedUtilization(rLong, total), m.optimalUsage, m.borrowingFactor, m.aboveOptimalFactor
            ) * elapsed;
            m.shortCumBorrowFactor += PerpMath.calcBorrowingRate(
                PerpMath.calcClampedUtilization(rShort, total), m.optimalUsage, m.borrowingFactor, m.aboveOptimalFactor
            ) * elapsed;
        }

        m.lastFundingTs = uint64(block.timestamp);
        emit FundingUpdated(
            marketId,
            m.fundingIndex,
            m.savedFundingRate,
            m.longCumBorrowFactor,
            m.shortCumBorrowFactor,
            m.longOi,
            m.shortOi
        );
    }

    function openPosition(bytes32 marketId, Side side, uint256 collateral, uint256 size, uint256 acceptablePrice)
        external
        returns (bytes32 key)
    {
        if (haltMode != HaltMode.None) revert Halted();
        Market storage m = markets[marketId];
        if (!m.listed) revert MarketNotListed();
        if (m.paused) revert MarketPaused();
        if (vault.totalSupply() == 0) revert NoLiquidity();

        return _openKernel(
            OpenReq({
                marketId: marketId,
                owner: msg.sender,
                side: side,
                collateral: collateral,
                size: size,
                acceptablePrice: acceptablePrice,
                preEscrowed: false
            })
        );
    }

    struct OpenReq {
        bytes32 marketId;
        address owner;
        Side side;
        uint256 collateral;
        uint256 size;
        uint256 acceptablePrice;
        bool preEscrowed;
    }

    function _openKernel(OpenReq memory r) internal returns (bytes32 key) {
        _updateFunding(r.marketId);
        Market storage m = markets[r.marketId];

        if (r.collateral == 0 || r.size == 0) revert ZeroAmount();

        uint256 fee = PerpMath.calcFee(
            r.size, PerpMath.selectFeeBps(m.baseFeeBps, m.favorableFeeBps, r.side, m.longOi, m.shortOi, true), 0
        );

        uint256 margin;
        if (r.preEscrowed) {
            if (r.collateral <= fee) revert BelowMinCollateral();
            margin = r.collateral - fee;
        } else {
            margin = r.collateral;
        }
        if (margin < protocolCfg.minCollateral) revert BelowMinCollateral();

        bool rth = _isRthRisk();
        {
            uint256 leverage = r.size / margin;
            if (leverage < 1) revert LeverageBelowOne();

            uint256 gross = walletMarketGross[r.owner][r.marketId] + r.size;
            uint256 tier = PerpMath.tierForNotional(gross, protocolCfg.tierBreakpoints);
            uint256 cap = rth ? protocolCfg.rthMaxLeverage[tier] : protocolCfg.offHoursMaxLeverage[tier];
            if (leverage > cap) revert LeverageExceedsTierCap();
            if (leverage > m.maxLeverage) revert LeverageExceedsMarketCap();
        }

        if (margin < (r.size * protocolCfg.initialMarginBps) / 10_000) revert InsufficientInitialMargin();

        {
            uint256 cap = protocolCfg.maxOpenPositionsPerWallet;
            if (cap != 0 && openPositionCount[r.owner] >= cap) revert PositionCapReached();
        }

        uint256 price = router.readPrice(r.marketId);
        if (r.acceptablePrice != 0) {
            if (r.side == Side.Long ? price > r.acceptablePrice : price < r.acceptablePrice) revert Slippage();
        }

        if (!r.preEscrowed) {
            uint16 floorBps = vault.minFreeLiquidityBps();
            if (floorBps > 0 && vault.freeLiquidity() < (vault.lpPrincipal() * floorBps) / 10_000) {
                revert FreeLiquidityFloor();
            }
        }

        if (r.preEscrowed) {

            vault.chargeEscrowedFee(fee);
        } else {

            usdg.safeTransferFrom(r.owner, address(vault), r.collateral + fee);
            vault.creditCollateral(r.collateral);
            vault.accrueFee(fee, false);
        }

        key = keccak256(abi.encode(address(this), r.owner, r.marketId, positionNonce[r.owner]++));
        positions[key] = Position({
            owner: r.owner,
            marketId: r.marketId,
            side: r.side,
            size: r.size,
            collateral: margin,
            entryPrice: price,
            fundingSnap: m.fundingIndex,
            borrowSnap: r.side == Side.Long ? m.longCumBorrowFactor : m.shortCumBorrowFactor,
            reservedMaxPayout: 2 * r.size,
            openedAt: uint64(block.timestamp)
        });
        walletMarketGross[r.owner][r.marketId] += r.size;
        openPositionCount[r.owner] += 1;

        if (r.side == Side.Long) {
            m.longOi += r.size;
            uint256 oiCap = rth ? m.maxOiLongRth : m.maxOiLongOff;
            if (oiCap != 0 && m.longOi > oiCap) revert OiCapExceeded();
        } else {
            m.shortOi += r.size;
            uint256 oiCap = rth ? m.maxOiShortRth : m.maxOiShortOff;
            if (oiCap != 0 && m.shortOi > oiCap) revert OiCapExceeded();
        }

        vault.updateReserve(r.marketId, uint8(r.side), int256(2 * r.size));

        _emitOpened(key, fee);
    }

    function _emitOpened(bytes32 key, uint256 fee) private {
        Position storage p = positions[key];
        emit PositionOpened(
            key, p.owner, p.marketId, p.side, p.size, p.collateral, p.entryPrice, fee, p.fundingSnap, p.borrowSnap
        );
    }

    struct CloseVars {
        bytes32 marketId;
        address owner;
        Side side;
        uint256 posSize;
        uint256 exitPrice;
        uint256 collateralPortion;
        uint256 reservedSlice;
        uint256 fee;
        int256 fundingApplied;
        uint256 borrowFee;
        int256 pnl;
        uint256 sideCumNow;
        uint256 finalDirect;
        uint256 finalEnqueue;
        bool routeEnqueue;
    }

    function closePosition(bytes32 key, uint256 closeSize, uint256 minOutput) external returns (uint256 userPayout) {
        if (haltMode == HaltMode.Full) revert Halted();
        if (positions[key].owner != msg.sender) revert NotPositionOwner();

        return _closeKernel(key, closeSize, minOutput, CLOSED_BY_OWNER);
    }

    function _closeKernel(bytes32 key, uint256 closeSize, uint256 minOutput, uint8 closedBy)
        internal
        returns (uint256 userPayout)
    {
        Position storage pos = positions[key];
        CloseVars memory v;
        v.owner = pos.owner;
        v.marketId = pos.marketId;
        v.side = pos.side;
        v.posSize = pos.size;
        if (closeSize == 0) closeSize = v.posSize;
        if (closeSize > v.posSize) revert BadCloseSize();

        _updateFunding(v.marketId);
        Market storage m = markets[v.marketId];
        v.exitPrice = router.readPrice(v.marketId);

        bool fullClose = closeSize == v.posSize;
        v.collateralPortion = fullClose ? pos.collateral : (pos.collateral * closeSize) / v.posSize;
        v.reservedSlice = fullClose ? pos.reservedMaxPayout : (pos.reservedMaxPayout * closeSize) / v.posSize;

        v.fee = PerpMath.calcFee(
            closeSize, PerpMath.selectFeeBps(m.baseFeeBps, m.favorableFeeBps, v.side, m.longOi, m.shortOi, false), 0
        );

        {
            int256 charge = PerpMath.calcFunding(m.fundingIndex - pos.fundingSnap, closeSize);
            v.fundingApplied = v.side == Side.Long ? charge : -charge;
        }
        v.sideCumNow = v.side == Side.Long ? m.longCumBorrowFactor : m.shortCumBorrowFactor;
        v.borrowFee = PerpMath.calcBorrowingFee(v.sideCumNow, pos.borrowSnap, closeSize);
        v.pnl = PerpMath.calcPnl(v.side, pos.entryPrice, v.exitPrice, closeSize);

        int256 netReturnSigned =
            int256(v.collateralPortion) + v.pnl - v.fundingApplied - int256(v.borrowFee) - int256(v.fee);
        int256 gross = netReturnSigned - int256(v.collateralPortion);

        VaultMath.CloseSplit memory split = VaultMath.creditCloseSplit(v.collateralPortion, 0, 0, gross);
        if (split.userPayout < minOutput) revert Slippage();

        {
            (uint256 marginDirect, uint256 queueAmount) =
                VaultMath.marginProfitSplit(v.collateralPortion, 0, split.userPayout);
            bool enqueueWinner = queueAmount > 0 && (vault.queueTotalOwed() > 0 || vault.freeLiquidity() < queueAmount);
            (v.finalDirect, v.finalEnqueue, v.routeEnqueue) = VaultMath.cashSplit(
                enqueueWinner, marginDirect, queueAmount, split.userPayout, usdg.balanceOf(address(vault))
            );
        }

        if (fullClose) {
            walletMarketGross[v.owner][v.marketId] -= v.posSize;
            openPositionCount[v.owner] -= 1;
            delete positions[key];
        } else {
            pos.size = v.posSize - closeSize;
            pos.collateral -= v.collateralPortion;
            pos.reservedMaxPayout -= v.reservedSlice;
            pos.fundingSnap = m.fundingIndex;
            pos.borrowSnap = v.sideCumNow;
            if (pos.collateral < protocolCfg.minCollateral) revert SurvivorBelowMin();
            walletMarketGross[v.owner][v.marketId] -= closeSize;
        }

        if (v.side == Side.Long) m.longOi -= closeSize;
        else m.shortOi -= closeSize;

        if (v.routeEnqueue) {
            vault.releaseAndEnqueue(
                v.marketId,
                uint8(v.side),
                v.reservedSlice,
                v.finalDirect,
                v.finalEnqueue,
                split.badDebt,
                split.lpGain,
                v.collateralPortion,
                v.owner
            );
        } else {
            vault.releaseAndSettle(
                v.marketId,
                uint8(v.side),
                v.reservedSlice,
                v.finalDirect,
                split.badDebt,
                split.lpGain,
                v.collateralPortion,
                v.owner
            );
        }

        vault.accrueFee(v.fee, true);

        _emitClosed(key, closeSize, v, split, closedBy);
        return split.userPayout;
    }

    function _emitClosed(
        bytes32 key,
        uint256 closeSize,
        CloseVars memory v,
        VaultMath.CloseSplit memory split,
        uint8 closedBy
    ) private {
        emit PositionClosed(
            key,
            v.owner,
            v.marketId,
            v.side,
            closeSize,
            v.exitPrice,
            v.pnl,
            split.userPayout,
            v.finalDirect,
            v.finalEnqueue,
            v.fundingApplied,
            v.borrowFee,
            v.fee,
            closedBy
        );
    }

    function liquidate(bytes32 key, uint256 maxBadDebt) external returns (uint256 liquidatorPaid) {
        if (haltMode == HaltMode.Full) revert Halted();
        Position storage pos = positions[key];
        if (pos.owner == address(0)) revert PositionNotFound();

        if (msg.sender == pos.owner) revert SelfLiquidation();

        CloseVars memory v;
        v.owner = pos.owner;
        v.marketId = pos.marketId;
        v.side = pos.side;
        v.posSize = pos.size;
        v.collateralPortion = pos.collateral;
        v.reservedSlice = pos.reservedMaxPayout;

        _updateFunding(v.marketId);
        Market storage m = markets[v.marketId];
        v.exitPrice = router.readPrice(v.marketId);

        {
            int256 charge = PerpMath.calcFunding(m.fundingIndex - pos.fundingSnap, v.posSize);
            v.fundingApplied = v.side == Side.Long ? charge : -charge;
        }
        v.borrowFee = PerpMath.calcBorrowingFee(
            v.side == Side.Long ? m.longCumBorrowFactor : m.shortCumBorrowFactor, pos.borrowSnap, v.posSize
        );
        v.pnl = PerpMath.calcPnl(v.side, pos.entryPrice, v.exitPrice, v.posSize);

        uint256 equity;
        {
            int256 effectiveEquity = int256(v.collateralPortion) + v.pnl - v.fundingApplied - int256(v.borrowFee);
            equity = effectiveEquity < 0 ? 0 : uint256(effectiveEquity);
        }
        uint256 health = PerpMath.calcHealth(equity, v.posSize, m.mmrBps);
        if (health >= 1000) revert PositionHealthy();

        if (m.partialLiqTargetHealth > 0 && equity > 0) {
            (bool done, uint256 paid) = _partialLiquidate(key, m, v, equity, health);
            if (done) return paid;
        }

        return _fullLiquidate(key, m, v, equity, maxBadDebt);
    }

    function _fullLiquidate(bytes32 key, Market storage m, CloseVars memory v, uint256 equity, uint256 maxBadDebt)
        private
        returns (uint256 liquidatorPaid)
    {
        (uint256 reward, uint256 insurance) = PerpMath.calcLiquidationFee(equity, m.liqFeeBps);

        VaultMath.CloseSplit memory split;
        {
            int256 gross = v.pnl - v.fundingApplied - int256(v.borrowFee) - int256(reward) - int256(insurance);
            split = VaultMath.creditCloseSplit(v.collateralPortion, 0, 0, gross);
        }
        if (maxBadDebt != 0 && split.badDebt > maxBadDebt) revert BadDebtAboveMax();

        {
            uint256 g = walletMarketGross[v.owner][v.marketId];
            walletMarketGross[v.owner][v.marketId] = g > v.posSize ? g - v.posSize : 0;
            uint256 c = openPositionCount[v.owner];
            openPositionCount[v.owner] = c > 0 ? c - 1 : 0;
        }
        if (v.side == Side.Long) {
            m.longOi = m.longOi > v.posSize ? m.longOi - v.posSize : 0;
        } else {
            m.shortOi = m.shortOi > v.posSize ? m.shortOi - v.posSize : 0;
        }
        delete positions[key];

        return _fullLiqSettle(key, v, split, reward, insurance, equity);
    }

    function _fullLiqSettle(
        bytes32 key,
        CloseVars memory v,
        VaultMath.CloseSplit memory split,
        uint256 reward,
        uint256 insurance,
        uint256 equity
    ) private returns (uint256 liquidatorPaid) {

        v.finalDirect = vault.releaseAndSettle(
            v.marketId,
            uint8(v.side),
            v.reservedSlice,
            split.userPayout,
            split.badDebt,
            split.lpGain,
            v.collateralPortion,
            v.owner
        );

        if (reward > 0) {
            liquidatorPaid = vault.releaseAndSettle(v.marketId, uint8(v.side), 0, reward, 0, 0, 0, msg.sender);
            if (liquidatorPaid < reward) {
                liquidatorPaid += vault.reimburseLiquidator(msg.sender, reward - liquidatorPaid);
            }
        }
        if (insurance > 0) vault.accrueToInsurance(insurance);

        if (split.badDebt > 0) emit BadDebt(v.marketId, v.owner, split.badDebt);
        _emitLiquidated(key, v, equity, reward, insurance, split.badDebt);
        _emitClosed(key, v.posSize, v, split, CLOSED_BY_LIQUIDATION);
    }

    struct PartialVars {
        uint256 closeSize;
        uint256 survivorSize;
        uint256 sliceEquity;
        uint256 sliceFee;
        uint256 reward;
        uint256 insurance;
        uint256 collateralPrime;
        uint256 closedTotal;
        uint256 reservedSlice;
        uint256 sideCumNow;
        int256 slicePnl;
        int256 sliceFunding;
        uint256 sliceBorrow;
    }

    function _partialLiquidate(bytes32 key, Market storage m, CloseVars memory v, uint256 equity, uint256 health)
        private
        returns (bool done, uint256 liquidatorPaid)
    {
        PartialVars memory q;

        {
            (uint256 num, uint256 den, bool ok) =
                PerpMath.calcPartialLiqFraction(health, m.partialLiqTargetHealth, m.liqFeeBps);
            if (!ok) return (false, 0);
            q.closeSize = PerpMath.mulDivCeil(v.posSize, num, den);
        }
        if (q.closeSize >= v.posSize) return (false, 0);
        q.survivorSize = v.posSize - q.closeSize;

        q.sliceEquity = PerpMath.mulDivCeil(equity, q.closeSize, v.posSize);
        (q.reward, q.insurance) = PerpMath.calcLiquidationFee(q.sliceEquity, m.liqFeeBps);
        q.sliceFee = q.reward + q.insurance;
        if (q.sliceFee > equity) return (false, 0);

        Position storage pos = positions[key];
        {
            uint256 survivorEquity = equity - q.sliceFee;
            int256 survivorPnl = PerpMath.calcPnl(v.side, pos.entryPrice, v.exitPrice, q.survivorSize);
            int256 collateralPrimeSigned = int256(survivorEquity) - survivorPnl;
            if (collateralPrimeSigned < 0) return (false, 0);
            q.collateralPrime = uint256(collateralPrimeSigned);
            if (q.collateralPrime > pos.collateral) return (false, 0);
            if (q.collateralPrime < protocolCfg.minCollateral) return (false, 0);

            if (PerpMath.calcHealth(survivorEquity, q.survivorSize, m.mmrBps) < 1000) return (false, 0);
        }

        q.reservedSlice = (pos.reservedMaxPayout * q.closeSize) / v.posSize;
        q.closedTotal = pos.collateral - q.collateralPrime;
        q.sideCumNow = v.side == Side.Long ? m.longCumBorrowFactor : m.shortCumBorrowFactor;

        q.slicePnl = PerpMath.calcPnl(v.side, pos.entryPrice, v.exitPrice, q.closeSize);
        {
            int256 charge = PerpMath.calcFunding(m.fundingIndex - pos.fundingSnap, q.closeSize);
            q.sliceFunding = v.side == Side.Long ? charge : -charge;
        }
        q.sliceBorrow = PerpMath.calcBorrowingFee(q.sideCumNow, pos.borrowSnap, q.closeSize);

        pos.size = q.survivorSize;
        pos.collateral = q.collateralPrime;
        pos.reservedMaxPayout -= q.reservedSlice;
        pos.fundingSnap = m.fundingIndex;
        pos.borrowSnap = q.sideCumNow;
        {
            uint256 g = walletMarketGross[v.owner][v.marketId];
            walletMarketGross[v.owner][v.marketId] = g > q.closeSize ? g - q.closeSize : 0;
        }
        if (v.side == Side.Long) {
            m.longOi = m.longOi > q.closeSize ? m.longOi - q.closeSize : 0;
        } else {
            m.shortOi = m.shortOi > q.closeSize ? m.shortOi - q.closeSize : 0;
        }

        vault.releaseAndSettle(v.marketId, uint8(v.side), q.reservedSlice, 0, 0, q.closedTotal, q.closedTotal, v.owner);

        if (q.reward > 0) {
            liquidatorPaid = vault.releaseAndSettle(v.marketId, uint8(v.side), 0, q.reward, 0, 0, 0, msg.sender);
            if (liquidatorPaid < q.reward) {
                liquidatorPaid += vault.reimburseLiquidator(msg.sender, q.reward - liquidatorPaid);
            }
        }
        if (q.insurance > 0) vault.accrueToInsurance(q.insurance);

        v.finalDirect = 0;
        v.finalEnqueue = 0;
        v.pnl = q.slicePnl;
        v.fundingApplied = q.sliceFunding;
        v.borrowFee = q.sliceBorrow;

        v.fee = 0;
        _emitLiquidated(key, v, q.sliceEquity, q.reward, q.insurance, 0);
        _emitClosed(key, q.closeSize, v, VaultMath.CloseSplit(0, 0, 0, 0, 0), CLOSED_BY_LIQUIDATION);
        done = true;
    }

    function _emitLiquidated(
        bytes32 key,
        CloseVars memory v,
        uint256 equity,
        uint256 reward,
        uint256 insurance,
        uint256 badDebt
    ) private {
        emit Liquidated(key, v.owner, v.marketId, msg.sender, v.exitPrice, equity, reward, insurance, badDebt);
    }

    function listMarket(bytes32 marketId, Market calldata params) external onlyOwner {

        MarketConfigLib.list(markets[marketId], params);
        emit MarketListed(marketId);
    }

    function updateMarketConfig(bytes32 marketId, MarketConfig calldata cfg) external onlyOwner {
        Market storage m = markets[marketId];
        if (!m.listed) revert MarketNotListed();
        MarketConfigLib.applyConfig(m, cfg);
        emit MarketConfigUpdated(marketId);
    }

    function setProtocolCfg(ProtocolCfg calldata cfg) external onlyOwner {
        if (cfg.initialMarginBps > 10_000) revert BadBps();
        for (uint256 i = 1; i < 5; i++) {
            if (cfg.tierBreakpoints[i] <= cfg.tierBreakpoints[i - 1]) revert BadBreakpoints();
        }
        if (cfg.tierBreakpoints[4] != type(uint256).max) revert BadBreakpoints();
        if (cfg.rthMaxLeverage[0] == 0 || cfg.offHoursMaxLeverage[0] == 0) revert BadLeverage();
        protocolCfg = cfg;
        emit ProtocolCfgSet();
    }

    function setMarketPaused(bytes32 marketId, bool paused) external {
        if (msg.sender != owner() && !(msg.sender == pauseAuthority && paused)) revert NotAuthorized();
        Market storage m = markets[marketId];
        if (!m.listed) revert MarketNotListed();
        m.paused = paused;
        emit MarketPausedSet(marketId, paused);
    }

    function setTradingHalt(HaltMode mode) external {
        if (msg.sender != owner() && !(msg.sender == pauseAuthority && mode > haltMode)) revert NotAuthorized();
        haltMode = mode;
        emit TradingHaltSet(mode);
    }

    function setPauseAuthority(address authority) external onlyOwner {
        pauseAuthority = authority;
        emit PauseAuthoritySet(authority);
    }

    function setOrders(address orders_) external onlyOwner {
        orders = orders_;
        emit OrdersSet(orders_);
    }

    function escrowForOrder(address owner_, uint256 collateral) external onlyOrders {
        usdg.safeTransferFrom(owner_, address(vault), collateral);
        vault.creditCollateral(collateral);
    }

    function refundForOrder(address owner_, bytes32 marketId, uint8 side, uint256 collateral) external onlyOrders {
        vault.releaseAndSettle(marketId, side, 0, collateral, 0, 0, collateral, owner_);
    }

    function openFromOrder(
        address owner_,
        bytes32 marketId,
        Side side,
        uint256 collateral,
        uint256 size,
        uint256 acceptablePrice
    ) external onlyOrders returns (bytes32 key) {
        if (haltMode != HaltMode.None) revert Halted();
        Market storage m = markets[marketId];
        if (!m.listed) revert MarketNotListed();
        if (m.paused) revert MarketPaused();
        return _openKernel(
            OpenReq({
                marketId: marketId,
                owner: owner_,
                side: side,
                collateral: collateral,
                size: size,
                acceptablePrice: acceptablePrice,
                preEscrowed: true
            })
        );
    }

    function closeFromOrder(bytes32 positionKey, uint256 size, uint256 minOutput) external onlyOrders {
        if (haltMode == HaltMode.Full) revert Halted();
        Position storage pos = positions[positionKey];
        if (pos.owner == address(0)) revert PositionNotFound();
        uint256 cs = size > pos.size ? pos.size : size;
        _closeKernel(positionKey, cs, minOutput, CLOSED_BY_ORDER);
    }

    function marketStatus(bytes32 marketId) external view returns (bool listed, bool paused) {
        Market storage m = markets[marketId];
        return (m.listed, m.paused);
    }

    function applyQueueHaircut(bytes32 marketId, uint8 maxEntries) external {
        AdlLib.applyQueueHaircut(markets[marketId], vault, _isRthRisk(), marketId, maxEntries);
    }
}
