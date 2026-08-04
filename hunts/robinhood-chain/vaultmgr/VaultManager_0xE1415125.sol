// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {IUnlockCallback} from "v4-core/interfaces/callback/IUnlockCallback.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {SwapParams} from "v4-core/types/PoolOperation.sol";
import {StateLibrary} from "v4-core/libraries/StateLibrary.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {FullMath} from "v4-core/libraries/FullMath.sol";
import {FixedPoint96} from "v4-core/libraries/FixedPoint96.sol";
import {BPS, VaultParams} from "./Params.sol";
import {IStock} from "./interfaces/IStock.sol";
import {ICurve, ILoxleyCoin, IMarkOracle, IParamRegistry} from "./interfaces/ILoxley.sol";
import {MarkOracle} from "./MarkOracle.sol";

/// @notice The vault singleton with per-coin accounting. Every coin's fee flow lands here as
/// native ETH, converts to USDG, and buys the coin's mark in impact-capped, epoch-capped
/// tranches. Stock tokens trade 24/7 in practice (pause flags have never engaged on-chain;
/// verified 2026-07-04), so every vault swap is additionally anchored to the oracle's clamped
/// EMA: execution skips when pool spot deviates beyond execBandBps — the impact cap alone is
/// relative to current spot and cannot see a pool that was shoved before the call. marketOpen
/// stays as belt-and-braces should the issuer ever start pausing. If the mark blocks transfers
/// (issuer blocklist), the coin's vault auto-degrades to USDG-only and keeps accruing.
///
/// The permissionless buyback crank (`poke`) fires only when the coin trades below NAV by the
/// configured margin: it sells one tranche of vault assets, buys the coin on its live venue
/// (curve pre-graduation, canonical pool after), and burns what it bought. A flat USDG reward
/// pays the caller. There is no drain path, no payout path, and no redemption path — vault
/// assets only ever leave through buyback-and-burn plus the crank reward. Never add redemption.
contract VaultManager is ReentrancyGuardTransient, IUnlockCallback {
    using SafeERC20 for IERC20;
    using PoolIdLibrary for PoolKey;
    using StateLibrary for IPoolManager;

    struct Vault {
        address mark;
        bool degraded;
        uint128 ethPending; // ETH received, not yet converted
        uint128 usdgBalance; // USDG held for this coin (6 decimals)
        uint128 markBalance; // mark (Stock token) held for this coin, raw units
        uint64 lastPokeAt;
        uint32 lastEpochId;
        uint128 epochSpentUsdg;
    }

    IERC20 public immutable usdg;
    IPoolManager public immutable poolManager;
    IParamRegistry public immutable registry;
    MarkOracle public immutable oracle;

    address public factory;
    address public graduator;
    address public curve;
    address private immutable _deployer;

    mapping(address coin => Vault) internal _vaults;
    mapping(address coin => PoolKey) internal _canonicalPool;
    mapping(address coin => bool) public hasCanonicalPool;

    event CoinRegistered(address indexed coin, address indexed mark);
    event Deposited(address indexed coin, address indexed from, uint256 amount);
    event EthConverted(address indexed coin, uint256 ethIn, uint256 usdgOut);
    event MarkBought(address indexed coin, address indexed mark, uint256 usdgIn, uint256 markOut);
    event MarkSold(address indexed coin, address indexed mark, uint256 markIn, uint256 usdgOut);
    event VaultDegraded(address indexed coin, address indexed mark, bytes reason);
    event VaultRestored(address indexed coin, address indexed mark);
    event BuybackExecuted(
        address indexed coin, uint256 usdgSpent, uint256 ethSpent, uint256 coinsBurned, uint256 callerReward
    );

    error NotAuthorized();
    error AlreadyWired();
    error UnknownCoin();
    error AlreadyRegistered();
    error MarketClosed();
    error NothingToConvert();
    error NothingToSpend();
    error SlippageExceeded();
    error CrankCooldown();
    error CrankNotTriggered();
    error CrankSpendTooSmall();
    error NoCirculatingSupply();
    error NotPoolManager();
    error ExecOutOfBand();

    constructor(address usdg_, address poolManager_, address registry_, address oracle_) {
        usdg = IERC20(usdg_);
        poolManager = IPoolManager(poolManager_);
        registry = IParamRegistry(registry_);
        oracle = MarkOracle(oracle_);
        _deployer = msg.sender;
    }

    function wire(address factory_, address graduator_, address curve_) external {
        if (msg.sender != _deployer) revert NotAuthorized();
        if (factory != address(0)) revert AlreadyWired();
        factory = factory_;
        graduator = graduator_;
        curve = curve_;
    }

    receive() external payable {
        // ETH only arrives from v4 settlement or curve interactions inside our own calls
        if (msg.sender != address(poolManager) && msg.sender != curve) revert NotAuthorized();
    }

    // ------------------------------------------------------------------
    // registration + deposits
    // ------------------------------------------------------------------

    function registerCoin(address coin, address mark) external {
        if (msg.sender != factory) revert NotAuthorized();
        if (_vaults[coin].mark != address(0)) revert AlreadyRegistered();
        _vaults[coin].mark = mark;
        emit CoinRegistered(coin, mark);
    }

    function setCanonicalPool(address coin, PoolKey calldata key) external {
        if (msg.sender != graduator) revert NotAuthorized();
        _canonicalPool[coin] = key;
        hasCanonicalPool[coin] = true;
    }

    function depositFor(address coin) external payable {
        if (_vaults[coin].mark == address(0)) revert UnknownCoin();
        _vaults[coin].ethPending += uint128(msg.value);
        emit Deposited(coin, msg.sender, msg.value);
    }

    function isEligibleMark(address mark) external view returns (bool) {
        return registry.eligibleMark(mark) && oracle.hasFeed(mark);
    }

    // ------------------------------------------------------------------
    // conversion pipeline (permissionless, keeper-driven)
    // ------------------------------------------------------------------

    /// @notice Convert pending ETH to USDG, one impact-capped tranche at a time. Returns 0
    /// without converting when the ETH/USDG pool sits outside the EMA band (shoved pool).
    function convertEth(address coin, uint256 minUsdgOut) external nonReentrant returns (uint256 usdgOut) {
        Vault storage v = _vaults[coin];
        if (v.mark == address(0)) revert UnknownCoin();
        VaultParams memory p = registry.getVaultParams();

        uint256 amountIn = Math.min(v.ethPending, p.trancheEthCap);
        if (amountIn == 0) revert NothingToConvert();
        if (!_withinBand(address(0), p.execBandBps)) return 0;

        (PoolKey memory key, bool ethIsC0) = oracle.feedOf(address(0));
        (uint256 used, uint256 out) = _swapExactIn(key, ethIsC0, amountIn, p.impactCapBps);
        if (out < FullMath.mulDiv(minUsdgOut, used == 0 ? 1 : used, amountIn)) revert SlippageExceeded();

        v.ethPending -= uint128(used);
        v.usdgBalance += uint128(out);
        emit EthConverted(coin, used, out);
        return out;
    }

    /// @notice Buy the coin's mark with vault USDG. Stock tokens trade 24/7 in practice, so
    /// the real guard is the EMA band: returns 0 without buying when the mark's pool spot
    /// deviates from the clamped EMA beyond execBandBps (a shoved pool passes the impact cap
    /// but not this). marketOpen stays as belt-and-braces should the issuer ever pause. A
    /// transfer-blocked mark (issuer blocklist) degrades the vault to USDG-only instead of
    /// reverting; a later successful buy restores it automatically.
    function buyMark(address coin, uint256 minMarkOut) external nonReentrant returns (uint256 markOut) {
        Vault storage v = _vaults[coin];
        if (v.mark == address(0)) revert UnknownCoin();
        if (!marketOpen(v.mark)) revert MarketClosed();
        VaultParams memory p = registry.getVaultParams();
        if (!_withinBand(v.mark, p.execBandBps)) return 0;

        _rollEpoch(v, p);
        uint256 epochRoom = p.epochSpendCapUsdg > v.epochSpentUsdg ? p.epochSpendCapUsdg - v.epochSpentUsdg : 0;
        uint256 amountIn = Math.min(Math.min(v.usdgBalance, p.trancheUsdgCap), epochRoom);
        if (amountIn == 0) revert NothingToSpend();

        (PoolKey memory key, bool markIsC0) = oracle.feedOf(v.mark);
        // buying the mark means selling USDG: zeroForOne when USDG is currency0
        try this.execSwap(key, !markIsC0, amountIn, p.impactCapBps) returns (uint256 used, uint256 out) {
            if (out < FullMath.mulDiv(minMarkOut, used == 0 ? 1 : used, amountIn)) revert SlippageExceeded();
            v.usdgBalance -= uint128(used);
            v.markBalance += uint128(out);
            v.epochSpentUsdg += uint128(used);
            if (v.degraded) {
                v.degraded = false;
                emit VaultRestored(coin, v.mark);
            }
            emit MarkBought(coin, v.mark, used, out);
            return out;
        } catch (bytes memory reason) {
            v.degraded = true;
            emit VaultDegraded(coin, v.mark, reason);
            return 0;
        }
    }

    /// @dev True when the token's pool spot sits within execBandBps of the clamped EMA. The
    /// impact cap is relative to the current spot, so it cannot see a pool that was shoved
    /// before the call — the EMA (≤emaMaxStepBps per update, ≥1 tx apart) can.
    function _withinBand(address token, uint16 bandBps) internal view returns (bool) {
        uint256 ema = oracle.emaOf(token);
        if (ema == 0) return true; // pool at zero price: nothing meaningful to anchor against
        uint256 spot = oracle.spotOf(token);
        uint256 diff = spot > ema ? spot - ema : ema - spot;
        return diff * BPS <= ema * bandBps;
    }

    /// @notice True when the Stock token is fully unpaused. Any probe revert counts as closed.
    /// In practice the pause flags have never engaged on-chain (verified 2026-07-04, markets
    /// closed): this is belt-and-braces for a future issuer policy change, not the schedule.
    function marketOpen(address mark) public view returns (bool) {
        try IStock(mark).tokenPaused() returns (bool tp) {
            if (tp) return false;
        } catch {
            return false;
        }
        try IStock(mark).oraclePaused() returns (bool op) {
            if (op) return false;
        } catch {
            return false;
        }
        try IStock(mark).paused() returns (bool pp) {
            if (pp) return false;
        } catch {
            return false;
        }
        return true;
    }

    // ------------------------------------------------------------------
    // buyback crank
    // ------------------------------------------------------------------

    /// @notice Permissionless: fires only when the coin trades below NAV by the margin. Sells one
    /// tranche of vault value, buys the coin on its live venue, burns it, pays the caller a flat
    /// USDG reward. Cooldown = one poke per coin per epoch.
    function poke(address coin, uint256 minCoinOut) external nonReentrant returns (uint256 burned) {
        Vault storage v = _vaults[coin];
        if (v.mark == address(0)) revert UnknownCoin();
        VaultParams memory p = registry.getVaultParams();
        if (v.lastPokeAt != 0 && block.timestamp < uint256(v.lastPokeAt) + p.epochLength) revert CrankCooldown();

        (uint256 navUsdg, uint256 markEma) = _requireTriggered(coin, v, p);
        // nothing has moved yet: refuse the whole crank while ETH/USDG is shoved off-anchor
        if (!_withinBand(address(0), p.execBandBps)) revert ExecOutOfBand();
        uint256 tranche = navUsdg * p.crankTrancheBps / BPS;
        _topUpUsdg(coin, v, p, tranche, markEma);

        uint256 spend = Math.min(v.usdgBalance, tranche);
        if (spend < uint256(p.crankRewardUsdg) * 5) revert CrankSpendTooSmall();
        v.usdgBalance -= uint128(spend);
        usdg.safeTransfer(msg.sender, p.crankRewardUsdg);

        uint256 ethOut = _usdgToEth(v, spend - p.crankRewardUsdg, p.impactCapBps);
        burned = _buyAndBurn(coin, v, ethOut, p.impactCapBps);
        if (burned < minCoinOut) revert SlippageExceeded();

        v.lastPokeAt = uint64(block.timestamp);
        emit BuybackExecuted(coin, spend, ethOut, burned, p.crankRewardUsdg);
    }

    function _requireTriggered(address coin, Vault storage v, VaultParams memory p)
        internal
        returns (uint256 navUsdg, uint256 markEma)
    {
        markEma = oracle.update(v.mark);
        uint256 ethEma = oracle.update(address(0));

        uint256 circulating = IERC20(coin).totalSupply() - IERC20(coin).balanceOf(curve);
        if (circulating == 0) revert NoCirculatingSupply();

        navUsdg = FullMath.mulDiv(v.markBalance, markEma, 1e18) + v.usdgBalance
            + FullMath.mulDiv(v.ethPending, ethEma, 1e18);
        uint256 navPerToken = FullMath.mulDiv(navUsdg, 1e18, circulating);
        if (_coinSpotUsdg(coin, ethEma) >= navPerToken * (BPS - p.crankMarginBps) / BPS) {
            revert CrankNotTriggered();
        }
    }

    /// @dev Sell mark for USDG to fund the tranche, when short, transferable, and the mark's
    /// pool sits within the EMA band (never sell into a shoved-down pool).
    function _topUpUsdg(address coin, Vault storage v, VaultParams memory p, uint256 tranche, uint256 markEma)
        internal
    {
        if (v.usdgBalance >= tranche || v.markBalance == 0 || !marketOpen(v.mark)) return;
        if (!_withinBand(v.mark, p.execBandBps)) return;
        uint256 usdgShort = tranche - v.usdgBalance;
        uint256 markToSell = Math.min(FullMath.mulDiv(usdgShort, 1e18, markEma), v.markBalance);
        (PoolKey memory mKey, bool markIsC0) = oracle.feedOf(v.mark);
        try this.execSwap(mKey, markIsC0, markToSell, p.impactCapBps) returns (uint256 used, uint256 out) {
            v.markBalance -= uint128(used);
            v.usdgBalance += uint128(out);
            emit MarkSold(coin, v.mark, used, out);
        } catch (bytes memory reason) {
            v.degraded = true;
            emit VaultDegraded(coin, v.mark, reason);
        }
    }

    function _usdgToEth(Vault storage v, uint256 buyBudget, uint16 impactCapBps) internal returns (uint256 ethOut) {
        (PoolKey memory ethKey, bool ethIsC0) = oracle.feedOf(address(0));
        uint256 usdgUsed;
        (usdgUsed, ethOut) = _swapExactIn(ethKey, !ethIsC0, buyBudget, impactCapBps);
        if (usdgUsed < buyBudget) v.usdgBalance += uint128(buyBudget - usdgUsed);
    }

    /// @dev Buy the coin on its live venue (curve pre-graduation, canonical pool after) and burn it.
    function _buyAndBurn(address coin, Vault storage v, uint256 ethBudget, uint16 impactCapBps)
        internal
        returns (uint256 burned)
    {
        if (ICurve(curve).isGraduated(coin)) {
            (uint256 ethUsed, uint256 coinsOut) = _swapExactIn(_canonicalPool[coin], true, ethBudget, impactCapBps);
            if (ethUsed < ethBudget) v.ethPending += uint128(ethBudget - ethUsed);
            burned = coinsOut;
        } else {
            // quote first: acceptedGross is exact at current state, so a graduation-boundary
            // partial fill's refund is known up front and stays working in the vault
            (,,, uint256 acceptedGross,) = ICurve(curve).quoteBuy(coin, ethBudget);
            burned = ICurve(curve).buy{value: ethBudget}(coin, 0, block.timestamp);
            if (acceptedGross < ethBudget) v.ethPending += uint128(ethBudget - acceptedGross);
        }
        ILoxleyCoin(coin).burn(burned);
    }

    // ------------------------------------------------------------------
    // views
    // ------------------------------------------------------------------

    function vaultOf(address coin) external view returns (Vault memory) {
        return _vaults[coin];
    }

    function canonicalPoolOf(address coin) external view returns (PoolKey memory) {
        return _canonicalPool[coin];
    }

    /// @notice NAV in USDG (6 decimals) using current EMA prices, and per-token against
    /// circulating supply. Frontend/keeper convenience.
    function navOf(address coin) external view returns (uint256 navUsdg, uint256 navPerToken) {
        Vault storage v = _vaults[coin];
        if (v.mark == address(0)) revert UnknownCoin();
        uint256 markEma = oracle.emaOf(v.mark);
        uint256 ethEma = oracle.emaOf(address(0));
        navUsdg = FullMath.mulDiv(v.markBalance, markEma, 1e18) + v.usdgBalance
            + FullMath.mulDiv(v.ethPending, ethEma, 1e18);
        uint256 circulating = IERC20(coin).totalSupply() - IERC20(coin).balanceOf(curve);
        navPerToken = circulating == 0 ? 0 : FullMath.mulDiv(navUsdg, 1e18, circulating);
    }

    function _coinSpotUsdg(address coin, uint256 ethEma) internal view returns (uint256) {
        uint256 weiPerToken;
        if (ICurve(curve).isGraduated(coin)) {
            (uint160 sqrtPriceX96,,,) = poolManager.getSlot0(_canonicalPool[coin].toId());
            uint256 t = FullMath.mulDiv(FixedPoint96.Q96, 1e18, sqrtPriceX96);
            weiPerToken = FullMath.mulDiv(t, FixedPoint96.Q96, sqrtPriceX96);
        } else {
            weiPerToken = ICurve(curve).priceWeiPerToken(coin);
        }
        return FullMath.mulDiv(weiPerToken, ethEma, 1e18);
    }

    // ------------------------------------------------------------------
    // swap plumbing
    // ------------------------------------------------------------------

    /// @dev External wrapper so mark swaps can be try/caught for blocklist degrade. Self-call only.
    function execSwap(PoolKey calldata key, bool zeroForOne, uint256 amountIn, uint16 impactCapBps)
        external
        returns (uint256 used, uint256 out)
    {
        if (msg.sender != address(this)) revert NotAuthorized();
        return _swapExactIn(key, zeroForOne, amountIn, impactCapBps);
    }

    /// @dev Exact-in swap with the impact cap enforced as a sqrt price limit: the swap simply
    /// stops at the cap, leaving the unconverted remainder for the next tranche.
    function _swapExactIn(PoolKey memory key, bool zeroForOne, uint256 amountIn, uint16 impactCapBps)
        internal
        returns (uint256 used, uint256 out)
    {
        (uint160 sqrtPriceX96,,,) = poolManager.getSlot0(key.toId());
        uint160 limit = _impactLimit(sqrtPriceX96, zeroForOne, impactCapBps);
        bytes memory result =
            poolManager.unlock(abi.encode(key, zeroForOne, amountIn, limit));
        (used, out) = abi.decode(result, (uint256, uint256));
    }

    function unlockCallback(bytes calldata data) external returns (bytes memory) {
        if (msg.sender != address(poolManager)) revert NotPoolManager();
        (PoolKey memory key, bool zeroForOne, uint256 amountIn, uint160 limit) =
            abi.decode(data, (PoolKey, bool, uint256, uint160));

        BalanceDelta delta = poolManager.swap(
            key,
            SwapParams({zeroForOne: zeroForOne, amountSpecified: -int256(amountIn), sqrtPriceLimitX96: limit}),
            ""
        );

        (Currency inCur, Currency outCur) =
            zeroForOne ? (key.currency0, key.currency1) : (key.currency1, key.currency0);
        int128 inDelta = zeroForOne ? delta.amount0() : delta.amount1();
        int128 outDelta = zeroForOne ? delta.amount1() : delta.amount0();
        uint256 used = inDelta < 0 ? uint256(uint128(-inDelta)) : 0;
        uint256 out = outDelta > 0 ? uint256(uint128(outDelta)) : 0;

        if (used > 0) {
            if (inCur.isAddressZero()) {
                poolManager.settle{value: used}();
            } else {
                poolManager.sync(inCur);
                IERC20(Currency.unwrap(inCur)).safeTransfer(address(poolManager), used);
                poolManager.settle();
            }
        }
        if (out > 0) poolManager.take(outCur, address(this), out);
        return abi.encode(used, out);
    }

    function _impactLimit(uint160 sqrtPriceX96, bool zeroForOne, uint16 capBps) internal pure returns (uint160) {
        // sqrt(1 +/- cap) scaled by 1e9
        uint256 factor = Math.sqrt((zeroForOne ? BPS - capBps : BPS + capBps) * 1e14 / BPS);
        uint256 limit = uint256(sqrtPriceX96) * factor / 1e7;
        if (limit <= TickMath.MIN_SQRT_PRICE) limit = TickMath.MIN_SQRT_PRICE + 1;
        if (limit >= TickMath.MAX_SQRT_PRICE) limit = TickMath.MAX_SQRT_PRICE - 1;
        return uint160(limit);
    }

    function _rollEpoch(Vault storage v, VaultParams memory p) internal {
        uint32 epochId = uint32(block.timestamp / p.epochLength);
        if (epochId != v.lastEpochId) {
            v.lastEpochId = epochId;
            v.epochSpentUsdg = 0;
        }
    }
}
