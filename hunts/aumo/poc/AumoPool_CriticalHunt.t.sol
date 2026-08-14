// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {AumoPool} from "../src/AumoPool.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IVenueAdapter} from "../src/interfaces/IVenueAdapter.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

/// @notice Aggressive critical hunt. Goal: permissionless net profit / full drain.
/// SAFE: local unit tests only.
contract AumoPoolCriticalHuntTest is Test {
    using SafeERC20 for IERC20;

    MockERC20 usdt0;
    AumoPool pool;
    address agent = address(0xA9E17);
    address attacker = address(0xA11CE);
    address victim = address(0xB0B);
    uint256 constant U = 1e6;

    function setUp() public {
        usdt0 = new MockERC20("USDT0", "USDT0", 6);
        pool = new AumoPool(IERC20(address(usdt0)), address(this));
        pool.setAgent(agent);
        pool.setPolicy(type(uint256).max / 2, type(uint256).max / 2, type(uint256).max / 2);
        usdt0.mint(attacker, 1_000_000 * U);
        usdt0.mint(victim, 1_000_000 * U);
        vm.prank(attacker);
        usdt0.approve(address(pool), type(uint256).max);
        vm.prank(victim);
        usdt0.approve(address(pool), type(uint256).max);
    }

    // ---------- CANDIDATE: classic inflation → must FAIL (no critical) ----------
    function test_Crit_InflationAttack_StillUnprofitable() public {
        // 1 wei deposit + huge donation
        vm.prank(attacker);
        pool.deposit(1, attacker);
        usdt0.mint(attacker, 500_000 * U);
        vm.prank(attacker);
        usdt0.transfer(address(pool), 500_000 * U);

        vm.prank(victim);
        pool.deposit(100_000 * U, victim);
        assertGt(pool.balanceOf(victim), 0, "victim got shares");

        uint256 aIn = 1 + 500_000 * U;
        uint256 aOut = _redeemAll(attacker);
        assertLe(aOut, aIn, "attacker cannot profit from inflation");
    }

    // ---------- CANDIDATE: deposit/redeem round-trip profit ----------
    function test_Crit_RoundTrip_NoFreeMoney() public {
        Healthy h = new Healthy(address(usdt0));
        pool.setVenueAllowed(address(h), true);
        vm.prank(victim);
        pool.deposit(50_000 * U, victim);
        vm.prank(agent);
        pool.allocate(address(h), 50_000 * U, "x");

        uint256 before = usdt0.balanceOf(attacker);
        vm.prank(attacker);
        pool.deposit(10_000 * U, attacker);
        _redeemAll(attacker);
        uint256 after_ = usdt0.balanceOf(attacker);
        assertLe(after_, before, "round-trip cannot mint free assets");
    }

    // ---------- CANDIDATE: flash-style same-block deposit/redeem cycling dust ----------
    function test_Crit_DustCycle_NoExtraction() public {
        vm.prank(victim);
        pool.deposit(100_000 * U, victim);
        uint256 start = usdt0.balanceOf(attacker);
        vm.startPrank(attacker);
        for (uint256 i; i < 50; ++i) {
            uint256 sh = pool.deposit(1 * U, attacker);
            pool.redeem(sh, attacker, attacker);
        }
        vm.stopPrank();
        assertLe(usdt0.balanceOf(attacker), start, "dust cycle not profitable");
    }

    // ---------- R1 elevated: PERSISTENT impairment (real depeg), not one-block manip ----------
    /// Temporary Uni manip + restore is NOT theft: after restore, remaining LPs still exit whole.
    /// Persistent stuck + face NAV is High (preferential drain of healthy leg), not free Critical:
    /// needs real venue failure and share capital; bound = healthy liquidity.
    function test_High_PersistentStuck_PreferentialDrain_NotFullCrit() public {
        ToggleStuck stuck = new ToggleStuck(address(usdt0));
        Healthy healthy = new Healthy(address(usdt0));
        pool.setVenueAllowed(address(stuck), true);
        pool.setVenueAllowed(address(healthy), true);

        vm.prank(victim);
        pool.deposit(400 * U, victim);
        vm.prank(attacker);
        pool.deposit(100 * U, attacker);

        vm.startPrank(agent);
        pool.allocate(address(stuck), 250 * U, "rwa");
        pool.allocate(address(healthy), 250 * U, "aave");
        vm.stopPrank();

        stuck.setStuck(true); // stays stuck (permanent depeg / floor revert)
        uint256 out = _redeemAll(attacker);
        // Attacker face claim ~100, liquid-fair if stuck marked 0 would be ~50
        assertGe(out, 99 * U, "paid full face claim from healthy");
        assertGt(out, 50 * U, "extracts beyond liquid-only pro-rata");

        // Victim still cannot fully exit while impairment persists
        uint256 vShares = pool.balanceOf(victim);
        vm.prank(victim);
        vm.expectRevert();
        pool.redeem(vShares, victim, victim);

        // Kill Critical inflation: attacker is not profitable vs their own deposit
        // (they put 100, got ~100). Damage is to victim residual, not unbounded protocol drain.
        assertLe(out, 101 * U, "attacker does not multiply capital - High bank-run, not Crit mint");
    }

    /// Temporary stuck then restore: victim recovers — proves one-block manip is not Crit theft.
    function test_Kill_TemporaryStuckSandwich_NoVictimLoss() public {
        ToggleStuck stuck = new ToggleStuck(address(usdt0));
        Healthy healthy = new Healthy(address(usdt0));
        pool.setVenueAllowed(address(stuck), true);
        pool.setVenueAllowed(address(healthy), true);

        vm.prank(victim);
        pool.deposit(400 * U, victim);
        vm.prank(attacker);
        pool.deposit(100 * U, attacker);

        vm.startPrank(agent);
        pool.allocate(address(stuck), 250 * U, "rwa");
        pool.allocate(address(healthy), 250 * U, "aave");
        vm.stopPrank();

        stuck.setStuck(true);
        _redeemAll(attacker);
        stuck.setStuck(false); // restore (manip ended)

        uint256 vBefore = usdt0.balanceOf(victim);
        uint256 vOut = _redeemAll(victim);
        assertApproxEqAbs(vOut, 400 * U, 2, "victim whole after temporary stuck");
        assertApproxEqAbs(usdt0.balanceOf(victim) - vBefore, 400 * U, 2);
    }

    // ---------- CANDIDATE: fee-on-transfer underlying (if USDT0 ever FoT) ----------
    function test_Crit_FeeOnTransfer_ShareInflation() public {
        FeeOnTransferToken fot = new FeeOnTransferToken("FOT", "FOT", 6);
        AumoPool p2 = new AumoPool(IERC20(address(fot)), address(this));
        p2.setAgent(agent);
        p2.setPolicy(type(uint256).max / 2, type(uint256).max / 2, type(uint256).max / 2);
        fot.mint(victim, 100_000 * U);
        fot.mint(attacker, 100_000 * U);
        vm.prank(victim);
        fot.approve(address(p2), type(uint256).max);
        vm.prank(attacker);
        fot.approve(address(p2), type(uint256).max);

        // victim seeds
        vm.prank(victim);
        try p2.deposit(10_000 * U, victim) {} catch {
            // if deposit measures wrong, may still succeed with OZ transferFrom of full amount
        }
        // OZ ERC4626 pulls `assets` via safeTransferFrom — FoT delivers less; shares minted for full.
        // Attacker deposits and checks if share price lets them extract more than deposited.
        uint256 aBefore = fot.balanceOf(attacker);
        vm.prank(attacker);
        try p2.deposit(10_000 * U, attacker) {
            uint256 got = 0;
            uint256 sh = p2.balanceOf(attacker);
            if (sh > 0) {
                vm.prank(attacker);
                got = p2.redeem(sh, attacker, attacker);
            }
            uint256 aAfter = fot.balanceOf(attacker);
            // Profit would be Critical if aAfter > aBefore (ignoring fees paid on transfers)
            console2.log("fot attacker delta", int256(aAfter) - int256(aBefore));
            console2.log("fot got on redeem", got);
            // Document: with 1% FoT, deposit loses fee, redeem loses fee — usually net loss.
            // Share dilution of victim is the issue (Medium/High accounting), not free mint to attacker.
            assertLe(aAfter, aBefore, "FoT does not give attacker free tokens from thin air");
        } catch {
            // some FoT configs revert — fine
        }
    }

    // ---------- CANDIDATE: direct donation to inflate then victim deposit, attacker exits ----------
    function test_Crit_DonationSandwich_NoProfit() public {
        vm.prank(attacker);
        pool.deposit(1_000 * U, attacker);
        // donate
        usdt0.mint(attacker, 50_000 * U);
        vm.prank(attacker);
        usdt0.transfer(address(pool), 50_000 * U);
        vm.prank(victim);
        pool.deposit(50_000 * U, victim);
        uint256 out = _redeemAll(attacker);
        // attacker put 1000 + 50000 donation = 51000, should not get more than that
        assertLe(out, 51_000 * U + 1, "donation sandwich unprofitable");
    }

    // ---------- CANDIDATE: allocated desync — withdraw max after partial lossy alloc ----------
    function test_Crit_AllocatedDesync_NoOverWithdraw() public {
        Lossy lv = new Lossy(address(usdt0), 500); // 5% exit burn
        pool.setVenueAllowed(address(lv), true);
        pool.setLossBudget(type(uint256).max, 1 days);
        vm.prank(victim);
        pool.deposit(10_000 * U, victim);
        vm.prank(agent);
        pool.allocate(address(lv), 10_000 * U, "x");
        // allocated principal 10000 but live ~9500
        assertEq(pool.allocated(address(lv)), 10_000 * U);
        uint256 live = lv.balanceOf(address(pool));
        assertLt(live, 10_000 * U);

        uint256 before = usdt0.balanceOf(victim);
        _redeemAll(victim);
        uint256 got = usdt0.balanceOf(victim) - before;
        assertLe(got, 10_000 * U, "cannot redeem more than deposited through desync");
        assertApproxEqAbs(got, live, 2, "redeems ~live value only");
    }

    // ---------- CANDIDATE: retreatSelf from EOA ----------
    function test_Crit_RetreatSelf_NotCallable() public {
        Healthy h = new Healthy(address(usdt0));
        pool.setVenueAllowed(address(h), true);
        vm.prank(victim);
        pool.deposit(100 * U, victim);
        vm.prank(agent);
        pool.allocate(address(h), 100 * U, "x");
        vm.prank(attacker);
        vm.expectRevert(AumoPool.NotSelf.selector);
        pool.retreatSelf(address(h), 100 * U);
    }

    // ---------- CANDIDATE: stranger allocate/deallocate ----------
    function test_Crit_StrangerCannotMoveFunds() public {
        Healthy h = new Healthy(address(usdt0));
        pool.setVenueAllowed(address(h), true);
        vm.prank(victim);
        pool.deposit(100 * U, victim);
        vm.prank(attacker);
        vm.expectRevert(AumoPool.NotAgent.selector);
        pool.allocate(address(h), 1 * U, "x");
        vm.prank(attacker);
        vm.expectRevert(AumoPool.NotAgent.selector);
        pool.deallocate(address(h), 1 * U);
    }

    function _redeemAll(address who) internal returns (uint256) {
        uint256 sh = pool.balanceOf(who);
        if (sh == 0) return 0;
        vm.prank(who);
        return pool.redeem(sh, who, who);
    }
}

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
}

contract ToggleStuck is IVenueAdapter {
    using SafeERC20 for IERC20;
    IERC20 public immutable token;
    mapping(address => uint256) public position;
    bool public stuck;
    constructor(address t) {
        token = IERC20(t);
    }
    function setStuck(bool s) external {
        stuck = s;
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
        if (stuck) revert("depeg");
        uint256 bal = position[msg.sender];
        uint256 amt = a > bal ? bal : a;
        position[msg.sender] = bal - amt;
        token.safeTransfer(msg.sender, amt);
        return amt;
    }
    function balanceOf(address a) external view returns (uint256) {
        return position[a];
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
}

/// 1% fee on every transfer
contract FeeOnTransferToken is ERC20 {
    uint8 private immutable _dec;
    constructor(string memory n, string memory s, uint8 d) ERC20(n, s) {
        _dec = d;
    }
    function decimals() public view override returns (uint8) {
        return _dec;
    }
    function mint(address to, uint256 a) external {
        _mint(to, a);
    }
    function transfer(address to, uint256 a) public override returns (bool) {
        uint256 fee = a / 100;
        super.transfer(address(0xfee), fee);
        return super.transfer(to, a - fee);
    }
    function transferFrom(address f, address to, uint256 a) public override returns (bool) {
        uint256 fee = a / 100;
        // pull full allowance path via super for amount a, but deliver a-fee — simplified:
        _spendAllowance(f, msg.sender, a);
        _transfer(f, address(0xfee), fee);
        _transfer(f, to, a - fee);
        return true;
    }
}
