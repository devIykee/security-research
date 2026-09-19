// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";

interface ILaunchpad {
    function quantiLanci() external view returns (uint256);
    function admin() external view returns (address);
    function hook() external view returns (address);
}

interface IUniswapV3Pool {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function factory() external view returns (address);
    function slot0() external view returns (
        uint160 sqrtPriceX96,
        int24 tick,
        uint16 observationIndex,
        uint16 observationCardinality,
        uint16 observationCardinalityNext,
        uint8 feeProtocol,
        bool unlocked
    );
}

interface IUniswapV3Factory {
    function getPool(address tokenA, address tokenB, uint24 fee) external view returns (address pool);
    function createPool(address tokenA, address tokenB, uint24 fee) external returns (address pool);
}

contract PoolSquatAttackTest is Test {
    address constant LAUNCHPAD = 0x66bDC0803807f8a62763943Fb2dd584eD9Fb9C16;
    address constant HOOK = 0x143d72d4bD0F0e1a6C6FD4f2f671A45d9e003a88;
    address constant POOL1 = 0x0Abd501F56CD434D346CD5Bf3B67aEF461ebBc2d;
    address constant ELLIPSE_TOKEN = 0x86F7424C3e1EBb3F42e1E687468e36D5f2A1222E;
    address constant BCRCL_TOKEN = 0x8F2c1979b852043f6fe5ae7Eb4eC6b896aE7E30B;
    address constant UNI_V3_FACTORY = 0xf0db7b58379503491d857dB50AC9ece64c653918;
    
    function setUp() public {
        vm.createSelectFork("https://rpc.mainnet.arc.io");
    }
    
    function test_PoolInitializationAnalysis() public view {
        console.log("=== Pool Initialization Analysis ===");
        
        IUniswapV3Pool pool = IUniswapV3Pool(POOL1);
        
        // Get pool state
        (
            uint160 sqrtPriceX96,
            int24 tick,
            ,,,, bool unlocked
        ) = pool.slot0();
        
        console.log("Pool:", POOL1);
        console.log("SqrtPriceX96:", sqrtPriceX96);
        console.log("Current tick:", uint256(int256(tick)));
        console.log("Unlocked:", unlocked);
        
        // Check factory
        address factory = pool.factory();
        console.log("Factory:", factory);
        
        // Verify this is the correct pool from factory
        IUniswapV3Factory uniFactory = IUniswapV3Factory(factory);
        address poolFromFactory = uniFactory.getPool(ELLIPSE_TOKEN, BCRCL_TOKEN, 10000);
        console.log("Pool from factory:", poolFromFactory);
        console.log("Matches POOL1:", poolFromFactory == POOL1);
    }
    
    function test_LaunchpadFunctionDiscovery() public {
        console.log("=== Function Discovery ===");
        
        // Try to find launch-related functions by calling with different signatures
        // We know quantiLanci works, let's see what else
        
        ILaunchpad launchpad = ILaunchpad(LAUNCHPAD);
        uint256 count = launchpad.quantiLanci();
        console.log("Launch count:", count);
        
        // Check if we can call the launchpad with empty data to trigger fallback
        (bool success, bytes memory data) = LAUNCHPAD.staticcall(hex"");
        console.log("Fallback call success:", success);
        console.log("Fallback data length:", data.length);
    }
    
    function test_AttackScenario_PoolSquat() public {
        console.log("=== Pool Squat Attack Scenario ===");
        console.log("This test demonstrates the THEORETICAL attack if the vulnerability exists");
        console.log("");
        
        // Scenario:
        // 1. Attacker sees launch transaction in mempool
        // 2. Attacker front-runs and pre-creates pool at manipulated price
        // 3. Launch transaction executes but pool already exists
        
        console.log("Step 1: Attacker monitors mempool for new token launches");
        console.log("  - New token address can be predicted (CREATE2 or sequential)");
        console.log("  - Quote token is known (CRCL, GLD, BTC, USDT, or ELLIPSE)");
        console.log("  - Pool parameters are deterministic (fee=10000, tickSpacing=200)");
        
        console.log("");
        console.log("Step 2: Attacker calculates pool address:");
        console.log("  - Uniswap v3: getPool(token, quoteToken, 10000)");
        console.log("  - If pool doesn't exist yet, attacker can create it");
        
        console.log("");
        console.log("Step 3: Attack execution:");
        console.log("  - Attacker calls factory.createPool(token, quoteToken, 10000)");
        console.log("  - Attacker initializes pool at wrong sqrtPriceX96 (e.g., 1000x higher)");
        console.log("  - No tokens needed - just initialization");
        
        console.log("");
        console.log("Step 4: Victim's launch transaction executes:");
        console.log("  - Pool already exists at manipulated price");
        console.log("  - If no price verification, adds liquidity at wrong ratio");
        console.log("  - Entire token supply dumps at inflated price");
        
        console.log("");
        console.log("IMPACT:");
        console.log("  - Attack cost: ~$10 (gas only)");
        console.log("  - Victim loss: 99%+ of token value");
        console.log("  - Frequency: Every launch vulnerable");
        
        console.log("");
        console.log("MITIGATION (what contract should do):");
        console.log("  require(getPool() == address(0), 'Pool exists');");
        console.log("  OR");
        console.log("  require(slot0.sqrtPriceX96 == expectedPrice, 'Price mismatch');");
    }
}
