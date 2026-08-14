// SPDX-License-Identifier: MIT
// TEMPORARY audit PoC — hunt for Critical-class paths
pragma solidity 0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {AumoPool} from "../src/AumoPool.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IVenueAdapter} from "../src/interfaces/IVenueAdapter.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

contract AumoPoolCriticalPushTest is Test {
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
        pool.setPolicy(type(uint256).max / 2, type(uint256).max / 2, type(uint256).max / 2);
        usdt0.mint(alice, 1_000_000 * U);
        usdt0.mint(bob, 1_000_000 * U);
        vm.prank(alice);
        usdt0.approve(address(pool), type(uint256).max);
        vm.prank(bob);
        usdt0.approve(address(pool), type(uint256).max);
    }

    /// Dust redeem when fully deployed in lossy venue: does lastPass max-liquidate entire position?
    function test_CritPush_DustRedeem_LastPassFullLiquidation() public {
        Lossy v = new Lossy(address(usdt0), 100); // 1% exit burn each pull
        pool.setVenueAllowed(address(v), true);

        vm.prank(alice);
        pool.deposit(100_000 * U, alice);
        vm.prank(agent);
        pool.allocate(address(v), 100_000 * U, "all");
        assertEq(pool.idleBalance(), 0);

        uint256 faceBefore = v.face(address(pool));
        // Redeem tiny amount of shares (~1 USDT of assets)
        uint256 sh = pool.balanceOf(alice);
        uint256 dustShares = sh / 100_000; // ~1 unit of assets if 100k deposit
        if (dustShares == 0) dustShares = 1;

        vm.prank(alice);
        pool.redeem(dustShares, alice, alice);

        uint256 faceAfter = v.face(address(pool));
        uint256 idle = pool.idleBalance();
        console2.log("faceBefore", faceBefore);
        console2.log("faceAfter", faceAfter);
        console2.log("idle after dust redeem", idle);
        console2.log("dustShares", dustShares);

        // If lastPass max fired, face drops massively relative to dust claim
        uint256 facePulled = faceBefore - faceAfter;
        console2.log("facePulled", facePulled);
        // Document ratio: face pulled vs assets needed (~1e6)
        // Critical-class if dust forces full liquidate
        if (faceAfter == 0) {
            console2.log("FULL LIQUIDATION on dust redeem");
        }
    }

    /// Can attacker profit net of capital via H-1 style race with majority liquid?
    /// Attacker deposits after equal split, stuck hits, attacker exits — profit?
    function test_CritPush_H1_NetProfitAsStranger() public {
        Stuck stuck = new Stuck(address(usdt0));
        Healthy aave = new Healthy(address(usdt0));
        pool.setVenueAllowed(address(stuck), true);
        pool.setVenueAllowed(address(aave), true);

        // Victims seed 10k
        vm.prank(alice);
        pool.deposit(10_000 * U, alice);
        vm.startPrank(agent);
        pool.allocate(address(stuck), 5_000 * U, "s");
        pool.allocate(address(aave), 5_000 * U, "a");
        vm.stopPrank();

        // Stuck already "live" (withdraw always reverts). Attacker deposits 10k at full NAV
        // including stuck — overpays for liquid. Then redeems immediately.
        uint256 attBefore = usdt0.balanceOf(bob);
        vm.prank(bob);
        pool.deposit(10_000 * U, bob);
        uint256 sh = pool.balanceOf(bob);
        vm.prank(bob);
        uint256 out = pool.redeem(sh, bob, bob);
        uint256 attAfter = usdt0.balanceOf(bob);
        console2.log("attacker spent 10000, got", out);
        console2.log("net", int256(attAfter) - int256(attBefore));
        // Should NOT profit: deposited into inflated NAV
        assertLe(out, 10_000 * U + 1, "late depositor cannot mint free money via H1");
    }

    /// Inflation with offset still?
    function test_CritPush_InflationStillDead() public {
        usdt0.mint(bob, 1_000_000 * U);
        vm.startPrank(bob);
        usdt0.approve(address(pool), type(uint256).max);
        pool.deposit(1, bob);
        usdt0.transfer(address(pool), 500_000 * U);
        vm.stopPrank();
        vm.prank(alice);
        pool.deposit(50_000 * U, alice);
        uint256 out = 0;
        uint256 sh = pool.balanceOf(bob);
        vm.prank(bob);
        out = pool.redeem(sh, bob, bob);
        assertLe(out, 1 + 500_000 * U, "no inflation profit");
    }

    /// Unmetered redeem path + maxEpochDeploy=0: can compromised agent who is depositor
    /// destroy ALL value? That's agent role not permissionless Critical.
    function test_CritPush_AgentDepositorChurn_NeedsRole() public {
        Lossy v = new Lossy(address(usdt0), 500); // 5% per RT
        pool.setVenueAllowed(address(v), true);
        // maxEpochDeploy default 0 = off; maxEpochLoss default 0 = agent dealloc blocked
        // User redeem path unmetered: agent deposit→allocate→redeem as user
        pool.setAgent(bob);
        vm.prank(alice);
        pool.deposit(10_000 * U, alice);

        // Bob as agent allocates, then as user... bob has no shares. Mint bob shares:
        usdt0.mint(bob, 10_000 * U);
        vm.startPrank(bob);
        usdt0.approve(address(pool), type(uint256).max);
        pool.deposit(1_000 * U, bob);
        pool.allocate(address(v), 5_000 * U, "x"); // uses pool idle from alice too
        // redeem bob shares - causes unmetered retreat of lossy venue for his exit
        uint256 sh = pool.balanceOf(bob);
        pool.redeem(sh, bob, bob);
        vm.stopPrank();

        // Alice remaining value
        uint256 aliceLeft = pool.previewRedeem(pool.balanceOf(alice));
        console2.log("alice remaining after agent-depositor cycle", aliceLeft);
        // Value destroyed but agent ROLE required — not permissionless Critical
        assertLt(aliceLeft, 10_000 * U);
    }
}

contract Healthy is IVenueAdapter {
    using SafeERC20 for IERC20;
    IERC20 public immutable token;
    mapping(address => uint256) public position;
    constructor(address t) { token = IERC20(t); }
    function asset() external view returns (address) { return address(token); }
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
    function balanceOf(address a) external view returns (uint256) { return position[a]; }
}

contract Stuck is IVenueAdapter {
    using SafeERC20 for IERC20;
    IERC20 public immutable token;
    mapping(address => uint256) public position;
    constructor(address t) { token = IERC20(t); }
    function asset() external view returns (address) { return address(token); }
    function deposit(uint256 a) external returns (uint256) {
        token.safeTransferFrom(msg.sender, address(this), a);
        position[msg.sender] += a;
        return a;
    }
    function withdraw(uint256) external pure returns (uint256) { revert("stuck"); }
    function balanceOf(address a) external view returns (uint256) { return position[a]; }
}

contract Lossy is IVenueAdapter {
    using SafeERC20 for IERC20;
    IERC20 public immutable token;
    uint256 public immutable lossBps;
    mapping(address => uint256) public position;
    constructor(address t, uint256 b) { token = IERC20(t); lossBps = b; }
    function asset() external view returns (address) { return address(token); }
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
    function face(address a) external view returns (uint256) { return position[a]; }
}
