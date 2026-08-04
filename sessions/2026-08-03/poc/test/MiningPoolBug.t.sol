// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {Test, console} from "forge-std/Test.sol";
import {MiningPoolLogic} from "../src/MiningPoolBug.sol";

contract MiningPoolBugTest is Test {
    MiningPoolLogic pool;
    address miner = address(0xBEEF);

    function setUp() public {
        pool = new MiningPoolLogic();
        // miner staked at t=1000
        vm.warp(1000);
        pool.stake(1, miner, 1000);
        // only 5 tokens in pool, but after 10s pending = 10
        pool.seedPool(5 ether);
    }

    function test_underfundedClaimBurnsUnpaidPending() public {
        vm.warp(1010); // 10 seconds => pending 10 ether
        assertEq(pool.pending(miner), 10 ether, "pending before claim");

        vm.prank(miner);
        (uint256 accrued, uint256 got) = pool.claim();
        assertEq(accrued, 10 ether);
        assertEq(got, 5 ether, "only pool balance paid");
        assertEq(pool.paid(miner), 5 ether);

        // lastClaim advanced: remaining 5 ether of accrued is GONE forever
        assertEq(pool.pending(miner), 0, "pending wiped despite underpay");

        // even if pool is refilled, lost accrual never returns
        pool.seedPool(100 ether);
        assertEq(pool.pending(miner), 0, "refill does not restore burned pending");
    }
}
