// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {IUnlockCallback} from "@uniswap/v4-core/src/interfaces/callback/IUnlockCallback.sol";
import {ModifyLiquidityParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {BalanceDelta, BalanceDeltaLibrary} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {LiquidityAmounts} from "v4-periphery/src/libraries/LiquidityAmounts.sol";

/// @title V4LiquidityLocker
/// @notice Owns graduated MEME/WETH liquidity DIRECTLY in the Uniswap V4
///         PoolManager. Because this contract has NO code path that calls
///         modifyLiquidity with a negative liquidityDelta, the principal
///         liquidity is provably unrecoverable — a strictly stronger lock than
///         holding a transferable position NFT. Trading fees CAN be collected
///         permissionlessly, but only ever to the immutable `feeRecipient`.
///         The pool cannot be changed and there is no arbitrary-call surface.
contract V4LiquidityLocker is IUnlockCallback, Ownable2Step, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using BalanceDeltaLibrary for BalanceDelta;
    using PoolIdLibrary for PoolKey;

    IPoolManager public immutable poolManager;
    address public immutable feeRecipient; // fees routed here only — immutable
    address public graduator; // authorized to lock (GraduationAdapter)

    struct Locked {
        bool exists;
        PoolKey key;
        int24 tickLower;
        int24 tickUpper;
        uint128 liquidity;
    }

    mapping(bytes32 poolId => Locked) public positions;

    enum Op {
        ADD,
        COLLECT
    }

    error OnlyGraduator();
    error OnlyPoolManager();
    error ZeroAddress();
    error AlreadyLocked();
    error NotLocked();
    error NoLiquidity();

    event GraduatorSet(address graduator);
    event LiquidityLocked(bytes32 indexed poolId, uint128 liquidity, uint256 amount0, uint256 amount1);
    event FeesCollected(bytes32 indexed poolId, uint256 amount0, uint256 amount1, address recipient);

    constructor(address owner_, address poolManager_, address feeRecipient_) Ownable(owner_) {
        if (poolManager_ == address(0) || feeRecipient_ == address(0)) revert ZeroAddress();
        poolManager = IPoolManager(poolManager_);
        feeRecipient = feeRecipient_;
    }

    function setGraduator(address g) external onlyOwner {
        if (g == address(0)) revert ZeroAddress();
        graduator = g;
        emit GraduatorSet(g);
    }

    /// @notice Initialize the MEME/WETH pool at `sqrtPriceX96` and add full-range
    ///         liquidity from the supplied amounts, locked forever. Only the
    ///         graduator (adapter). Leftover tokens are returned to the caller.
    function lockLiquidity(
        PoolKey calldata key,
        uint160 sqrtPriceX96,
        uint256 amount0Desired,
        uint256 amount1Desired,
        bool doInitialize
    ) external nonReentrant returns (uint128 liquidity, uint256 used0, uint256 used1) {
        if (msg.sender != graduator) revert OnlyGraduator();
        bytes32 id = PoolId.unwrap(key.toId());
        if (positions[id].exists) revert AlreadyLocked();

        IERC20(Currency.unwrap(key.currency0)).safeTransferFrom(msg.sender, address(this), amount0Desired);
        IERC20(Currency.unwrap(key.currency1)).safeTransferFrom(msg.sender, address(this), amount1Desired);

        if (doInitialize) poolManager.initialize(key, sqrtPriceX96);

        int24 tickLower = TickMath.minUsableTick(key.tickSpacing);
        int24 tickUpper = TickMath.maxUsableTick(key.tickSpacing);
        liquidity = LiquidityAmounts.getLiquidityForAmounts(
            sqrtPriceX96,
            TickMath.getSqrtPriceAtTick(tickLower),
            TickMath.getSqrtPriceAtTick(tickUpper),
            amount0Desired,
            amount1Desired
        );
        if (liquidity == 0) revert NoLiquidity();

        (uint256 u0, uint256 u1) = abi.decode(
            poolManager.unlock(abi.encode(Op.ADD, key, tickLower, tickUpper, uint256(liquidity))), (uint256, uint256)
        );
        used0 = u0;
        used1 = u1;

        positions[id] =
            Locked({exists: true, key: key, tickLower: tickLower, tickUpper: tickUpper, liquidity: liquidity});

        // return any unused principal to the caller (graduation manager policy)
        _refund(key.currency0, msg.sender);
        _refund(key.currency1, msg.sender);

        emit LiquidityLocked(id, liquidity, used0, used1);
    }

    /// @notice Collect accrued LP fees to the immutable feeRecipient. Anyone may
    ///         call; principal is never touched (liquidityDelta stays 0).
    function collectFees(bytes32 id) external nonReentrant {
        Locked storage pos = positions[id];
        if (!pos.exists) revert NotLocked();
        (uint256 a0, uint256 a1) = abi.decode(
            poolManager.unlock(abi.encode(Op.COLLECT, pos.key, pos.tickLower, pos.tickUpper, uint256(0))),
            (uint256, uint256)
        );
        emit FeesCollected(id, a0, a1, feeRecipient);
    }

    function unlockCallback(bytes calldata data) external returns (bytes memory) {
        if (msg.sender != address(poolManager)) revert OnlyPoolManager();
        (Op op, PoolKey memory key, int24 tickLower, int24 tickUpper, uint256 liq) =
            abi.decode(data, (Op, PoolKey, int24, int24, uint256));

        if (op == Op.ADD) {
            (BalanceDelta delta,) = poolManager.modifyLiquidity(
                key,
                ModifyLiquidityParams({
                    tickLower: tickLower, tickUpper: tickUpper, liquidityDelta: int256(liq), salt: 0
                }),
                ""
            );
            uint256 owed0 = uint256(uint128(-delta.amount0()));
            uint256 owed1 = uint256(uint128(-delta.amount1()));
            _settle(key.currency0, owed0);
            _settle(key.currency1, owed1);
            return abi.encode(owed0, owed1);
        } else {
            // COLLECT: poke with zero delta; positive delta = fees owed to us.
            (BalanceDelta delta,) = poolManager.modifyLiquidity(
                key, ModifyLiquidityParams({tickLower: tickLower, tickUpper: tickUpper, liquidityDelta: 0, salt: 0}), ""
            );
            uint256 fee0 = delta.amount0() > 0 ? uint256(uint128(delta.amount0())) : 0;
            uint256 fee1 = delta.amount1() > 0 ? uint256(uint128(delta.amount1())) : 0;
            if (fee0 > 0) poolManager.take(key.currency0, feeRecipient, fee0);
            if (fee1 > 0) poolManager.take(key.currency1, feeRecipient, fee1);
            return abi.encode(fee0, fee1);
        }
    }

    function _settle(Currency c, uint256 amt) internal {
        if (amt == 0) return;
        poolManager.sync(c);
        IERC20(Currency.unwrap(c)).safeTransfer(address(poolManager), amt);
        poolManager.settle();
    }

    function _refund(Currency c, address to) internal {
        uint256 bal = IERC20(Currency.unwrap(c)).balanceOf(address(this));
        if (bal > 0) IERC20(Currency.unwrap(c)).safeTransfer(to, bal);
    }
}
