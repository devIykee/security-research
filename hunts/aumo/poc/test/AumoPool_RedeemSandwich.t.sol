// SPDX-License-Identifier: MIT
// TEMPORARY audit PoC — redeem-path sandwich on RWA-like swap (permissionless MEV)
pragma solidity 0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {AumoPool} from "../src/AumoPool.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IVenueAdapter} from "../src/interfaces/IVenueAdapter.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

/*
 * ## Proof Explanation
 *
 * Redeem when idle short + RWA venue pulled:
 *   redeem → _ensureIdle → retreatSelf → adapter.withdraw → Uni exactInputSingle
 * minOut = amountIn * (1 - maxSlippageBps); deploy default 200 bps (2%).
 *
 * Permissionless sandwich: front-run price against exit, redeem hits near floor, back-run.
 * Redeemer assets fixed from pre-tx totalAssets; worse swap return is socialized to
 * remaining LPs (or whole redeem reverts if short). Bound ≈ maxSlippageBps of pull.
 */

contract AumoPoolRedeemSandwichTest is Test {
    using SafeERC20 for IERC20;

    MockERC20 usdt0;
    AumoPool pool;
    SandwichableVenue venue;
    address agent = address(0xA9E17);
    address victim = address(0xB0B);
    address remaining = address(0xA11CE);
    uint256 constant U = 1e6;

    function setUp() public {
        usdt0 = new MockERC20("USDT0", "USDT0", 6);
        pool = new AumoPool(IERC20(address(usdt0)), address(this));
        pool.setAgent(agent);
        pool.setPolicy(type(uint256).max / 2, type(uint256).max / 2, type(uint256).max / 2);

        venue = new SandwichableVenue(address(usdt0), 200);
        pool.setVenueAllowed(address(venue), true);

        for (uint256 i; i < 2; ++i) {
            address u = i == 0 ? victim : remaining;
            usdt0.mint(u, 100_000 * U);
            vm.prank(u);
            usdt0.approve(address(pool), type(uint256).max);
        }
    }

    function test_RedeemPath_PermissionlessSandwich_SocializesLossToRemainingLPs() public {
        vm.prank(victim);
        pool.deposit(10_000 * U, victim);
        vm.prank(remaining);
        pool.deposit(10_000 * U, remaining);

        vm.prank(agent);
        pool.allocate(address(venue), 20_000 * U, "rwa");
        assertEq(pool.idleBalance(), 0);

        uint256 navBefore = pool.totalAssets();
        uint256 victimShares = pool.balanceOf(victim);
        uint256 claim = pool.previewRedeem(victimShares);

        venue.setSandwichHaircutBps(200);

        uint256 victimUsdtBefore = usdt0.balanceOf(victim);
        vm.prank(victim);
        uint256 out = pool.redeem(victimShares, victim, victim);
        uint256 victimGain = usdt0.balanceOf(victim) - victimUsdtBefore;

        assertEq(out, victimGain);
        assertApproxEqAbs(victimGain, claim, 2, "redeemer paid pre-tx NAV claim");

        uint256 remainingClaim = pool.previewRedeem(pool.balanceOf(remaining));
        console2.log("navBefore", navBefore);
        console2.log("victimGain", victimGain);
        console2.log("remainingClaimAfter", remainingClaim);
        uint256 destroyed = navBefore - (victimGain + remainingClaim);
        console2.log("value destroyed (socialized)", destroyed);

        assertLt(victimGain + remainingClaim, navBefore, "sandwich destroyed pool value");
        assertGt(destroyed, 100 * U, "material extraction");
        assertLe(destroyed, 400 * U, "bounded by 2% floor on pulled size");
    }

    function test_RedeemPath_SandwichBeyondFloor_RevertsRetreat() public {
        vm.prank(victim);
        pool.deposit(5_000 * U, victim);
        vm.prank(agent);
        pool.allocate(address(venue), 5_000 * U, "rwa");

        venue.setSandwichHaircutBps(500);
        uint256 sh = pool.balanceOf(victim);
        vm.prank(victim);
        vm.expectRevert();
        pool.redeem(sh, victim, victim);
    }

    function test_RedeemPath_NoSandwich_ValueConserved() public {
        vm.prank(victim);
        pool.deposit(10_000 * U, victim);
        vm.prank(remaining);
        pool.deposit(10_000 * U, remaining);
        vm.prank(agent);
        pool.allocate(address(venue), 20_000 * U, "rwa");

        venue.setSandwichHaircutBps(0);
        uint256 navBefore = pool.totalAssets();
        uint256 sh = pool.balanceOf(victim);
        vm.prank(victim);
        uint256 out = pool.redeem(sh, victim, victim);
        uint256 rem = pool.previewRedeem(pool.balanceOf(remaining));
        assertApproxEqAbs(out + rem, navBefore, 5, "no sandwich => nearly conserved");
    }
}

contract SandwichableVenue is IVenueAdapter {
    using SafeERC20 for IERC20;

    IERC20 public immutable token;
    uint256 public immutable maxSlippageBps;
    uint256 public sandwichHaircutBps;
    mapping(address => uint256) public position;

    constructor(address token_, uint256 maxSlippageBps_) {
        token = IERC20(token_);
        maxSlippageBps = maxSlippageBps_;
    }

    function setSandwichHaircutBps(uint256 bps) external {
        sandwichHaircutBps = bps;
    }

    function asset() external view returns (address) {
        return address(token);
    }

    function deposit(uint256 amount) external returns (uint256) {
        token.safeTransferFrom(msg.sender, address(this), amount);
        position[msg.sender] += amount;
        return amount;
    }

    function withdraw(uint256 amount) external returns (uint256) {
        uint256 bal = position[msg.sender];
        uint256 pull = amount > bal ? bal : amount;
        if (pull == 0) return 0;
        if (sandwichHaircutBps > maxSlippageBps) revert("slippage");
        position[msg.sender] = bal - pull;
        uint256 out = (pull * (10_000 - sandwichHaircutBps)) / 10_000;
        token.safeTransfer(msg.sender, out);
        return out;
    }

    function balanceOf(address account) external view returns (uint256) {
        return position[account];
    }
}
