// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";

interface ILaunchpad {
    function quantiLanci() external view returns (uint256);
    function lancioPerIndice(uint256 index) external view returns (
        address token,
        address pool,
        address lock,
        address creator,
        address pairToken,
        uint256 openingMcap,
        uint256 tokenId,
        int24 tickLower,
        uint256 devBuy,
        bool rewardHolders
    );
    function admin() external view returns (address);
    function guardian() external view returns (address);
    function hook() external view returns (address);
}

interface IUniswapV3Pool {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function fee() external view returns (uint24);
    function tickSpacing() external view returns (int24);
}

contract ReconTest is Test {
    address constant LAUNCHPAD = 0x66bDC0803807f8a62763943Fb2dd584eD9Fb9C16;
    address constant HOOK = 0x143d72d4bD0F0e1a6C6FD4f2f671A45d9e003a88;
    address constant POOL1 = 0x0Abd501F56CD434D346CD5Bf3B67aEF461ebBc2d;
    
    function setUp() public {
        // Fork Arc mainnet
        vm.createSelectFork("https://rpc.mainnet.arc.io");
    }
    
    function test_LaunchpadState() public view {
        console.log("=== Launchpad V6 Reconnaissance ===");
        console.log("Address:", LAUNCHPAD);
        
        ILaunchpad launchpad = ILaunchpad(LAUNCHPAD);
        
        // Get launch count
        uint256 count = launchpad.quantiLanci();
        console.log("Total launches:", count);
        
        // Get admin roles
        address admin = launchpad.admin();
        address guardian = launchpad.guardian();
        address hook = launchpad.hook();
        console.log("Admin:", admin);
        console.log("Guardian:", guardian);
        console.log("Hook:", hook);
        
        // Analyze first launch if exists
        if (count > 0) {
            console.log("\n=== Launch 0 ===");
            (
                address token,
                address pool,
                address lock,
                address creator,
                address pairToken,
                uint256 openingMcap,
                uint256 tokenId,
                int24 tickLower,
                uint256 devBuy,
                bool rewardHolders
            ) = launchpad.lancioPerIndice(0);
            
            console.log("Token:", token);
            console.log("Pool:", pool);
            console.log("Lock:", lock);
            console.log("Creator:", creator);
            console.log("Pair token:", pairToken);
            console.log("Opening mcap:", openingMcap);
            console.log("Dev buy:", devBuy);
            console.log("Reward holders:", rewardHolders);
        }
    }
    
    function test_PoolAnalysis() public view {
        console.log("=== Pool Analysis ===");
        IUniswapV3Pool pool = IUniswapV3Pool(POOL1);
        
        address token0 = pool.token0();
        address token1 = pool.token1();
        uint24 fee = pool.fee();
        int24 tickSpacing = pool.tickSpacing();
        
        console.log("Pool:", POOL1);
        console.log("Token0:", token0);
        console.log("Token1:", token1);
        console.log("Fee (bps):", fee);
        console.log("Tick spacing:", uint256(int256(tickSpacing)));
    }
    
    function test_HookAnalysis() public view {
        console.log("=== Hook Analysis ===");
        console.log("Hook address:", HOOK);
        
        // Check hook code size
        uint256 codeSize;
        assembly {
            codeSize := extcodesize(HOOK)
        }
        console.log("Hook code size:", codeSize);
        
        // Try to call hook functions
        // (will revert if function doesn't exist, but we'll catch it)
    }
}
