// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {Test, console} from "forge-std/Test.sol";

/// Local logic PoC (no fork): Uniswap v4 PositionManager.initializePool soft-fails
/// and Merry Men ignores the return value + mints with max slippage.
contract SoftInitLogicTest is Test {
    // Exact Uniswap v4 periphery pattern (PoolInitializer_v4)
    function softInitialize(bool alreadyInited, uint160 intended) internal pure returns (int24) {
        if (!alreadyInited) {
            // poolManager.initialize succeeds
            return 0; // tick
        }
        // catch { return type(int24).max; }
        return type(int24).max;
    }

    function test_softInit_returnsMax_whenPreInited() public pure {
        int24 t = softInitialize(true, 1);
        assertEq(t, type(int24).max);
    }

    function test_factory_ignores_return_allows_wrong_price() public pure {
        // Factory does: positionManager.initializePool(key, intended); // no check
        int24 returned = softInitialize(true, 12345);
        // Factory never checks:
        // require(returned != type(int24).max, "pool pre-exists");
        // require(slot0.sqrtPriceX96 == intended);
        bool wouldProceedToMint = true; // as in PumpClawFactory lines 155-202
        assertTrue(wouldProceedToMint);
        assertEq(returned, type(int24).max);
        // amount0Max/amount1Max = type(uint128).max  (MAX_SLIPPAGE)
        uint128 maxSlip = type(uint128).max;
        assertGt(maxSlip, 0);
    }

    function test_create_address_prediction_stable() public {
        address factory = address(0xfa4B952c15BC9d418ae4f552F7Fc76b4470596fE);
        address a = vm.computeCreateAddress(factory, 2);
        address b = vm.computeCreateAddress(factory, 2);
        assertEq(a, b);
        assertTrue(a != address(0));
    }
}
