// SAFE, LOCAL FORK ONLY. No mainnet state touched.
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";

struct PoolKey {
    address currency0;
    address currency1;
    uint24 fee;
    int24 tickSpacing;
    address hooks;
}

interface IPoolManager {
    function initialize(PoolKey calldata key, uint160 sqrtPriceX96) external returns (int24 tick);
}

interface IPositionManager {
    function initializePool(PoolKey calldata key, uint160 sqrtPriceX96) external payable returns (int24);
}

/// @dev On-fork proof that RH PositionManager soft-fails pre-init (Uniswap v4 pattern).
contract V4SoftInitForkTest is Test {
    address constant POOL_MANAGER = 0x8366a39CC670B4001A1121B8F6A443A643e40951;
    address constant POSITION_MANAGER = 0x58daec3116aae6D93017bAAea7749052E8a04fA7;
    uint24 constant LP_FEE = 10000;
    int24 constant TICK_SPACING = 200;

    function test_softInit_returnsMax_onLiveRH() public {
        // unique phantom token so we do not collide with real pools
        address phantom = address(uint160(uint256(keccak256(abi.encode(block.number, "mm-preinit")))));
        PoolKey memory key = PoolKey(address(0), phantom, LP_FEE, TICK_SPACING, address(0));
        uint160 priceA = 79228162514264337593543950336;
        uint160 priceB = 158456325028528675187087900672;

        IPoolManager(POOL_MANAGER).initialize(key, priceA);
        int24 tick = IPositionManager(POSITION_MANAGER).initializePool(key, priceB);
        assertEq(tick, type(int24).max, "soft-fail sentinel when pool already initialized");
        console.log("soft init returned type(int24).max as expected");
    }
}
