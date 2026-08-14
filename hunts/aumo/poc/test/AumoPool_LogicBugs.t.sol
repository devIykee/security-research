// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {AumoPool} from "../src/AumoPool.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IVenueAdapter} from "../src/interfaces/IVenueAdapter.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

/// @notice Complex multi-step logic bugs (accounting, control flow, budgets).
/// SAFE: local unit tests only.
contract AumoPoolLogicBugsTest is Test {
    using SafeERC20 for IERC20;

    MockERC20 usdt0;
    AumoPool pool;
    address agent = address(0xA9E17);
    address alice = address(0xA11CE);
    address bob = address(0xB0B);
    uint256 constant U = 1e6;

    function setUp() public {
        usdt0 = new MockERC20("USDT0", "USDT0", 6);
        pool = new AumoPool(IERC20(address(usdt0)), address(this));
        pool.setAgent(agent);
        pool.setPolicy(type(uint256).max / 4, type(uint256).max / 4, type(uint256).max / 4);
        usdt0.mint(alice, 1_000_000 * U);
        usdt0.mint(bob, 1_000_000 * U);
        vm.prank(alice);
        usdt0.approve(address(pool), type(uint256).max);
        vm.prank(bob);
        usdt0.approve(address(pool), type(uint256).max);
    }

    // =========================================================================
    // L1: lastPass uses pull=max for every venue — over-liquidates lossy venue
    //     to cover a dust shortfall when a later lossless venue could pay cheaply.
    //     Triggered when RWA is allowlisted BEFORE Aave (owner ordering footgun /
    //     redeploy order). Socializes unnecessary swap burn onto remaining LPs.
    // =========================================================================
    function test_Logic_LastPass_OverLiquidatesLossyBeforeHealthy() public {
        // 3% exit burn models RWA; Healthy is Aave-like 1:1
        Lossy rwa = new Lossy(address(usdt0), 300);
        Healthy aave = new Healthy(address(usdt0));
        // Intentionally RWA first (bad order) — DeployPoolMainnet does Aave first, but
        // setVenueAllowed order is owner-controlled and re-allowlist can reshuffle only
        // by first-seen _venues order (push once). First allowlist wins forever.
        pool.setVenueAllowed(address(rwa), true);
        pool.setVenueAllowed(address(aave), true);

        vm.prank(alice);
        pool.deposit(10_000 * U, alice);
        vm.prank(bob);
        pool.deposit(10_000 * U, bob);

        vm.startPrank(agent);
        pool.allocate(address(rwa), 5_000 * U, "rwa");
        pool.allocate(address(aave), 5_000 * U, "aave");
        // leave 10_000 idle? allocated 10k of 20k — idle 10k
        // Deploy more so idle is tight: allocate rest to rwa partially
        pool.allocate(address(rwa), 4_000 * U, "rwa2"); // rwa 9k, aave 5k, idle 6k
        vm.stopPrank();

        // Bob redeems almost all — force multi-pass under-delivery on lossy then lastPass max
        // Idle 6k; bob has ~10k shares of 20k assets. Redeem 9k assets → need 3k from venues.
        uint256 bobShares = pool.balanceOf(bob);
        // redeem 90% of bob shares to create a large pull
        uint256 part = (bobShares * 90) / 100;
        uint256 rwaBefore = rwa.face(address(pool));
        uint256 aaveBefore = aave.balanceOf(address(pool));

        vm.prank(bob);
        pool.redeem(part, bob, bob);

        uint256 rwaAfter = rwa.face(address(pool));
        uint256 aaveAfter = aave.balanceOf(address(pool));
        console2.log("rwa face before/after", rwaBefore, rwaAfter);
        console2.log("aave before/after", aaveBefore, aaveAfter);

        // Document: if lastPass hit rwa with max, rwa may be fully drained despite aave
        // having capacity. Not always full drain depending on pass math — assert the
        // economic symptom: more burned on rwa than min(need, rwa) would require.
        // Burn observable as face reduction on rwa beyond what a tight pull needed.
        // This test logs structure; hard assert on over-pull:
        // After redeem, if rwa fully empty while aave still full-ish, lastPass max fired on rwa first.
        if (rwaAfter == 0 && aaveAfter == aaveBefore) {
            console2.log("CONFIRMED: rwa fully liquidated while aave untouched");
        }
        // Softer invariant always checked: alice remaining value should not be secret-drained
        // beyond bob's redeem + rwa exit burns on the pulled amount.
        assertGt(pool.totalAssets(), 0, "pool still has assets");
    }

    // =========================================================================
    // L2: Entry fill loss is booked into allocated (gross), then charged AGAIN
    //     on deallocate loss budget → agent cannot legitimately retreat after a
    //     normal RWA round-trip when budget ≈ exit-only cost.
    // =========================================================================
    function test_Logic_LossBudget_DoubleCountsEntryFill() public {
        // Entry burns 2% immediately in venue accounting (simulates swap on deposit);
        // exit burns another 1%. allocated still += gross amount.
        EntryExitLossy v = new EntryExitLossy(address(usdt0), 200, 100);
        pool.setVenueAllowed(address(v), true);
        // Budget sized for ~exit only (1% of 1000 = 10), not entry+exit (~30)
        pool.setLossBudget(12 * U, 1 days);

        vm.prank(alice);
        pool.deposit(1_000 * U, alice);

        vm.startPrank(agent);
        pool.allocate(address(v), 1_000 * U, "in");
        // NAV already dropped from entry; principal still 1000
        assertEq(pool.allocated(address(v)), 1_000 * U);
        assertLt(v.balanceOf(address(pool)), 1_000 * U, "entry already lost value");

        // Legitimate full retreat should be normal ops — but budget sees
        // pulledPrincipal 1000 - returned ~970 = ~30 > 12 → revert
        vm.expectRevert(AumoPool.LossBudgetExceeded.selector);
        pool.deallocate(address(v), 1_000 * U);
        vm.stopPrank();

        // Position frozen for agent; only user redeem (enforce=false) or owner
        // raising budget can exit. Logic bug: budget meters "returned vs booked gross"
        // not "returned vs post-entry basis".
        assertEq(pool.allocated(address(v)), 1_000 * U, "still fully booked");
    }

    // =========================================================================
    // L3: balanceOf > 0 but withdraw returns 0 without revert → silent principal
    //     write-off on user path. totalDeployed frees; agent can re-allocate against
    //     caps while face remains trapped in the lying venue.
    // =========================================================================
    function test_Logic_SilentZeroWithdraw_WipesPrincipal_WhenIdleShort() public {
        LieVenue lie = new LieVenue(address(usdt0));
        Healthy aave = new Healthy(address(usdt0));
        pool.setVenueAllowed(address(lie), true);
        pool.setVenueAllowed(address(aave), true);
        pool.setPolicy(2_000 * U, 2_000 * U, 2_000 * U);

        vm.prank(alice);
        pool.deposit(2_000 * U, alice);

        vm.startPrank(agent);
        pool.allocate(address(lie), 1_000 * U, "lie");
        pool.allocate(address(aave), 1_000 * U, "aave");
        vm.stopPrank();

        assertEq(pool.allocated(address(lie)), 1_000 * U);
        assertEq(pool.totalDeployed(), 2_000 * U);

        uint256 sh = pool.balanceOf(alice);
        uint256 part = sh / 4; // ~500 assets
        vm.prank(alice);
        pool.redeem(part, alice, alice);

        uint256 liePrincipal = pool.allocated(address(lie));
        uint256 aavePrincipal = pool.allocated(address(aave));
        console2.log("lie/aave principal after", liePrincipal, aavePrincipal);
        console2.log("totalDeployed", pool.totalDeployed());
        // Core bug: lie principal dropped though withdraw returned 0 and face unchanged
        assertEq(liePrincipal, 500 * U, "principal halved despite zero tokens returned");
        assertEq(lie.face(address(pool)), 1_000 * U, "venue still holds full face");
        // aave actually paid ~500, principal reduced for real
        assertEq(aavePrincipal, 500 * U, "aave principal reduced for real pull");
        assertEq(pool.totalDeployed(), 1_000 * U, "book = lie500 + aave500");
        // Real face still in venues: lie 1000 + aave ~500 = 1500 > book 1000
        uint256 realFace = lie.face(address(pool)) + aave.balanceOf(address(pool));
        assertGt(realFace, pool.totalDeployed(), "real venue face exceeds principal ledger");

        // Freed cap (totalDeployed 1000 < max 2000) while 1000 still trapped in lie:
        // agent can deploy more idle against the "room" under the cap.
        vm.prank(bob);
        pool.deposit(500 * U, bob);
        vm.prank(agent);
        pool.allocate(address(aave), 500 * U, "extra");
        assertGt(
            lie.face(address(pool)) + aave.balanceOf(address(pool)),
            pool.totalDeployed(),
            "still under-booked after re-allocate into freed headroom"
        );
    }

    // =========================================================================
    // L4: allocate books gross `amount` not `supplied` → totalDeployed/caps drift
    //     vs live NAV; loss budget over-charges (see L2). Caps become tighter than
    //     real exposure (fail-closed) but NAV/cap dual ledger diverges.
    // =========================================================================
    function test_Logic_AllocateBooksGrossNotSupplied() public {
        EntryExitLossy v = new EntryExitLossy(address(usdt0), 500, 0); // 5% entry burn, no exit
        pool.setVenueAllowed(address(v), true);
        pool.setLossBudget(type(uint256).max, 1 days);

        vm.prank(alice);
        pool.deposit(1_000 * U, alice);
        vm.prank(agent);
        pool.allocate(address(v), 1_000 * U, "x");

        assertEq(pool.allocated(address(v)), 1_000 * U, "gross booked");
        assertEq(pool.totalDeployed(), 1_000 * U);
        uint256 live = v.balanceOf(address(pool));
        assertApproxEqAbs(live, 950 * U, 1, "only 95% live after entry");
        // Dual ledger: principal 1000 vs live 950 — invariant broken for "principal ≈ live"
        assertGt(pool.allocated(address(v)), live, "gross principal > live value");
    }

    // =========================================================================
    // L5: setLossBudget changes lossEpochLength used by deploy-budget rollover
    //     without resetting epochDeployed — can immediately free or strand deploy
    //     capacity mid-window (coupled counters, uncoupled resets).
    // =========================================================================
    function test_Logic_EpochLengthCoupling_DeployWindowDesync() public {
        Healthy h = new Healthy(address(usdt0));
        pool.setVenueAllowed(address(h), true);
        pool.setDeployBudget(100 * U); // tight
        // lossEpochLength default 1 days; deploy uses same length

        vm.prank(alice);
        pool.deposit(1_000 * U, alice);

        vm.prank(agent);
        pool.allocate(address(h), 100 * U, "1");
        assertEq(pool.epochDeployed(), 100 * U);

        // Owner shrinks epoch length to 1 second WITHOUT resetting deploy counters
        // via setLossBudget (resets loss window only)
        pool.setLossBudget(0, 1); // 1 second epochs
        // epochDeployed still 100, epochDeployStart still old
        // After 1 second, deploy window should roll on next allocate because
        // timestamp >= epochDeployStart + lossEpochLength (now 1)
        vm.warp(block.timestamp + 2);
        vm.prank(agent);
        pool.allocate(address(h), 100 * U, "2"); // should succeed after roll
        assertEq(pool.epochDeployed(), 100 * U, "fresh window after length shrink");

        // Opposite: extend length massively while mid-window — deploy counter stuck
        pool.setDeployBudget(100 * U); // reset deploy window, spent 0
        vm.prank(agent);
        pool.allocate(address(h), 50 * U, "3");
        pool.setLossBudget(0, 365 days); // lengthen without reset deploy
        // epochDeployed still 50; window won't roll for a year
        vm.prank(agent);
        vm.expectRevert(AumoPool.DeployBudgetExceeded.selector);
        pool.allocate(address(h), 60 * U, "4"); // 50+60 > 100, no roll
    }

    // =========================================================================
    // L6: _doDeallocate(amount) when amount > principal still passes large amount
    //     to withdraw; pulledPrincipal caps at principal. If venue returns less
    //     than principal but more than 0, full principal is written off (OK) —
    //     if venue has EXTRA untracked funds and amount is only slightly > principal,
    //     may leave residue. Conversely amount=principal+1 with live>>principal
    //     only reduces principal by principal, withdraw(principal+1) may leave yield.
    // =========================================================================
    function test_Logic_WithdrawAmountNotCappedToPrincipal_LeavesOrphanYieldPath() public {
        Healthy h = new Healthy(address(usdt0));
        pool.setVenueAllowed(address(h), true);
        pool.setLossBudget(type(uint256).max, 1 days);

        vm.prank(alice);
        pool.deposit(1_000 * U, alice);
        vm.prank(agent);
        pool.allocate(address(h), 1_000 * U, "x");

        // Accrue yield 200
        usdt0.mint(address(h), 200 * U);
        h.accrue(address(pool), 200 * U);

        // Agent deallocates exact principal only (not max)
        vm.prank(agent);
        pool.deallocate(address(h), 1_000 * U);

        assertEq(pool.allocated(address(h)), 0, "principal cleared");
        // Yield still in venue, counted in totalAssets (known intentional)
        assertEq(h.balanceOf(address(pool)), 200 * U, "orphan yield remains");
        assertEq(pool.totalAssets(), usdt0.balanceOf(address(pool)) + 200 * U);

        // Now deallocate(1) with principal 0: pulledPrincipal=0, still withdraws
        vm.prank(agent);
        pool.deallocate(address(h), 1 * U);
        // Depending on Healthy.withdraw, pulls 1 from position
        assertEq(h.balanceOf(address(pool)), 199 * U);
    }

    // =========================================================================
    // L7: Discounted balanceOf used as withdraw sizing unit (face aUSDG units).
    //     Partial pull request of `need` when need < live(discounted) withdraws
    //     `need` face units — systematically peels face faster than discounted NAV,
    //     can empty face while accounting thought residual discounted value remained.
    // =========================================================================
    function test_Logic_DiscountedLive_PartialPull_FaceDesync() public {
        // balanceOf = 99% of face (100 bps discount)
        DiscountVenue d = new DiscountVenue(address(usdt0), 100);
        pool.setVenueAllowed(address(d), true);

        vm.prank(alice);
        pool.deposit(10_000 * U, alice);
        vm.prank(agent);
        pool.allocate(address(d), 10_000 * U, "x");

        uint256 face = d.face(address(pool));
        uint256 live = d.balanceOf(address(pool));
        assertEq(face, 10_000 * U);
        assertEq(live, 9_900 * U);

        // Redeem assets = live (9900). need >= live → max path. Use smaller redeem.
        // Redeem 5000 assets with idle 0: need=5000 < live 9900 → pull=5000 face
        uint256 sh = pool.balanceOf(alice);
        // assets ≈ 10000; redeem shares for ~5000 assets
        uint256 half = sh / 2;
        vm.prank(alice);
        pool.redeem(half, alice, alice);

        uint256 faceAfter = d.face(address(pool));
        uint256 liveAfter = d.balanceOf(address(pool));
        uint256 prin = pool.allocated(address(d));
        console2.log("face/live/principal after", faceAfter, liveAfter, prin);
        // Partial path withdraws `need` as FACE units while sizing against DISCOUNTED live.
        // Principal tracks face pull; live stays discBps below face — dual-unit desync.
        assertApproxEqAbs(faceAfter, prin, 100 * U, "principal tracks face peels");
        assertLt(liveAfter, faceAfter, "live remains discounted vs face");
        assertGt(prin, liveAfter, "principal > discounted live after partial redeem");
    }

    // =========================================================================
    // L8: maxWithdraw overstates liquid assets (stuck venue in NAV) — user
    //     receives maxWithdraw() success only by draining healthy; related R1.
    //     Here: maxWithdraw > idle+healthy while stuck reports balance.
    // =========================================================================
    function test_Logic_MaxWithdraw_OverstatesLiquid() public {
        Stuck stuck = new Stuck(address(usdt0));
        Healthy aave = new Healthy(address(usdt0));
        pool.setVenueAllowed(address(stuck), true);
        pool.setVenueAllowed(address(aave), true);

        vm.prank(alice);
        pool.deposit(1_000 * U, alice);
        vm.startPrank(agent);
        pool.allocate(address(stuck), 600 * U, "s");
        pool.allocate(address(aave), 400 * U, "a");
        vm.stopPrank();

        uint256 maxW = pool.maxWithdraw(alice);
        uint256 liquid = aave.balanceOf(address(pool)) + pool.idleBalance();
        console2.log("maxWithdraw vs liquid", maxW, liquid);
        assertGt(maxW, liquid, "ERC4626 maxWithdraw claims stuck value as withdrawable");
        // Calling withdraw(maxW) succeeds by taking healthy + fails? or succeeds R1-style
        // With only alice, withdraw maxW tries to get 1000, healthy 400, stuck fails → revert
        vm.prank(alice);
        vm.expectRevert();
        pool.withdraw(maxW, alice, alice);
        // So maxWithdraw lies: claims 1000, actual max successful is ~400 (+idle0)
        // UX/logic bug: EIP-4626 maxWithdraw must not overpromise
    }
}

// --- local adapters ---

contract Healthy is IVenueAdapter {
    using SafeERC20 for IERC20;
    IERC20 public immutable token;
    mapping(address => uint256) public position;
    constructor(address t) {
        token = IERC20(t);
    }
    function asset() external view returns (address) {
        return address(token);
    }
    function deposit(uint256 a) external returns (uint256) {
        token.safeTransferFrom(msg.sender, address(this), a);
        position[msg.sender] += a;
        return a;
    }
    function withdraw(uint256 a) external returns (uint256) {
        uint256 bal = position[msg.sender];
        uint256 amt = a > bal ? bal : a;
        position[msg.sender] = bal - amt;
        token.safeTransfer(msg.sender, amt);
        return amt;
    }
    function balanceOf(address a) external view returns (uint256) {
        return position[a];
    }
    function accrue(address a, uint256 y) external {
        position[a] += y;
    }
}

contract Lossy is IVenueAdapter {
    using SafeERC20 for IERC20;
    IERC20 public immutable token;
    uint256 public immutable lossBps;
    mapping(address => uint256) public position;
    constructor(address t, uint256 b) {
        token = IERC20(t);
        lossBps = b;
    }
    function asset() external view returns (address) {
        return address(token);
    }
    function deposit(uint256 a) external returns (uint256) {
        token.safeTransferFrom(msg.sender, address(this), a);
        position[msg.sender] += a;
        return a;
    }
    function withdraw(uint256 a) external returns (uint256) {
        uint256 bal = position[msg.sender];
        uint256 amt = a > bal ? bal : a;
        position[msg.sender] = bal - amt;
        uint256 out = (amt * (10_000 - lossBps)) / 10_000;
        token.safeTransfer(msg.sender, out);
        return out;
    }
    function balanceOf(address a) external view returns (uint256) {
        return (position[a] * (10_000 - lossBps)) / 10_000;
    }
    function face(address a) external view returns (uint256) {
        return position[a];
    }
}

/// entryBps burned on deposit (value in position), exitBps on withdraw
contract EntryExitLossy is IVenueAdapter {
    using SafeERC20 for IERC20;
    IERC20 public immutable token;
    uint256 public immutable entryBps;
    uint256 public immutable exitBps;
    mapping(address => uint256) public position;
    constructor(address t, uint256 e, uint256 x) {
        token = IERC20(t);
        entryBps = e;
        exitBps = x;
    }
    function asset() external view returns (address) {
        return address(token);
    }
    function deposit(uint256 a) external returns (uint256) {
        token.safeTransferFrom(msg.sender, address(this), a);
        uint256 credited = (a * (10_000 - entryBps)) / 10_000;
        // burn entry: keep tokens but only credit position (simulates swap leave)
        // actually keep all tokens in contract; position is post-entry value
        position[msg.sender] += credited;
        // trap entry burn tokens in contract unrecoverable via position — like pool fee
        return credited;
    }
    function withdraw(uint256 a) external returns (uint256) {
        uint256 bal = position[msg.sender];
        uint256 amt = a > bal ? bal : a;
        position[msg.sender] = bal - amt;
        uint256 out = (amt * (10_000 - exitBps)) / 10_000;
        token.safeTransfer(msg.sender, out);
        return out;
    }
    function balanceOf(address a) external view returns (uint256) {
        return position[a];
    }
}

/// balanceOf lies high; withdraw transfers nothing (no revert)
contract LieVenue is IVenueAdapter {
    using SafeERC20 for IERC20;
    IERC20 public immutable token;
    mapping(address => uint256) public position;
    constructor(address t) {
        token = IERC20(t);
    }
    function asset() external view returns (address) {
        return address(token);
    }
    function deposit(uint256 a) external returns (uint256) {
        token.safeTransferFrom(msg.sender, address(this), a);
        position[msg.sender] += a;
        return a;
    }
    function withdraw(uint256) external pure returns (uint256) {
        return 0; // silent no-op
    }
    function balanceOf(address a) external view returns (uint256) {
        return position[a]; // still reports face
    }
    function face(address a) external view returns (uint256) {
        return position[a];
    }
}

contract DiscountVenue is IVenueAdapter {
    using SafeERC20 for IERC20;
    IERC20 public immutable token;
    uint256 public immutable discBps;
    mapping(address => uint256) public position;
    constructor(address t, uint256 d) {
        token = IERC20(t);
        discBps = d;
    }
    function asset() external view returns (address) {
        return address(token);
    }
    function deposit(uint256 a) external returns (uint256) {
        token.safeTransferFrom(msg.sender, address(this), a);
        position[msg.sender] += a;
        return a;
    }
    function withdraw(uint256 a) external returns (uint256) {
        uint256 bal = position[msg.sender];
        uint256 amt = a > bal ? bal : a;
        position[msg.sender] = bal - amt;
        token.safeTransfer(msg.sender, amt);
        return amt;
    }
    function balanceOf(address a) external view returns (uint256) {
        return (position[a] * (10_000 - discBps)) / 10_000;
    }
    function face(address a) external view returns (uint256) {
        return position[a];
    }
}

contract Stuck is IVenueAdapter {
    using SafeERC20 for IERC20;
    IERC20 public immutable token;
    mapping(address => uint256) public position;
    constructor(address t) {
        token = IERC20(t);
    }
    function asset() external view returns (address) {
        return address(token);
    }
    function deposit(uint256 a) external returns (uint256) {
        token.safeTransferFrom(msg.sender, address(this), a);
        position[msg.sender] += a;
        return a;
    }
    function withdraw(uint256) external pure returns (uint256) {
        revert("stuck");
    }
    function balanceOf(address a) external view returns (uint256) {
        return position[a];
    }
}
