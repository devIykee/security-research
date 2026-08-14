// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {AumoPool} from "../src/AumoPool.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IVenueAdapter} from "../src/interfaces/IVenueAdapter.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

/// @notice Residual findings after AUDIT_FIXES: NAV still prices illiquid venues, and
///         _ensureIdle does not isolate balanceOf reverts (unlike totalAssets).
/// SAFE: local unit tests only. No mainnet interaction.
contract AumoPoolResidualTest is Test {
    using SafeERC20 for IERC20;

    MockERC20 usdt0;
    AumoPool pool;

    address owner = address(this);
    address agent = address(0xA9E17);
    address alice = address(0xA11CE);
    address bob = address(0xB0B);

    uint256 constant U = 1e6;

    function setUp() public {
        usdt0 = new MockERC20("USDT0", "USDT0", 6);
        pool = new AumoPool(IERC20(address(usdt0)), owner);
        pool.setAgent(agent);
        pool.setPolicy(10_000 * U, 10_000 * U, 10_000 * U);

        for (uint256 i; i < 2; ++i) {
            address u = [alice, bob][i];
            usdt0.mint(u, 10_000 * U);
            vm.prank(u);
            usdt0.approve(address(pool), type(uint256).max);
        }
    }

    /// HIGH residual: a stuck venue still counted in totalAssets lets the first redeemer
    /// drain healthy-venue liquidity against a claim that includes non-realizable value.
    /// Second redeemer is left with shares backed only by the unexit-able venue.
    function test_Residual_NavIncludesStuckVenue_PreferentialExit() public {
        StuckVenue stuck = new StuckVenue(address(usdt0));
        HealthyVenue healthy = new HealthyVenue(address(usdt0));
        pool.setVenueAllowed(address(stuck), true);
        pool.setVenueAllowed(address(healthy), true);

        vm.prank(alice);
        pool.deposit(200 * U, alice);
        vm.prank(bob);
        pool.deposit(200 * U, bob);
        // totalAssets = 400, equal shares

        vm.startPrank(agent);
        pool.allocate(address(stuck), 200 * U, "illiquid");
        pool.allocate(address(healthy), 200 * U, "liquid");
        vm.stopPrank();

        assertEq(pool.totalAssets(), 400 * U, "NAV still full (stuck reports balance)");
        assertEq(pool.idleBalance(), 0);

        // Alice exits 100% of her pro-rata claim (200). Isolation skips stuck, pulls healthy.
        uint256 aliceBefore = usdt0.balanceOf(alice);
        uint256 aliceShares = pool.balanceOf(alice);
        vm.prank(alice);
        uint256 aliceOut = pool.redeem(aliceShares, alice, alice);
        assertEq(aliceOut, usdt0.balanceOf(alice) - aliceBefore);
        // She is made whole from the healthy venue alone
        assertApproxEqAbs(aliceOut, 200 * U, 2, "alice fully paid from healthy liquidity");

        // Bob still holds half the shares. NAV still includes ~200 stuck + residual healthy dust.
        // But the only liquid capital is gone (or nearly). Bob cannot realize his claimed NAV.
        uint256 bobShares = pool.balanceOf(bob);
        assertGt(bobShares, 0, "bob still has shares");
        uint256 nav = pool.totalAssets();
        assertGt(nav, 150 * U, "NAV still marks stuck value");

        // Bob tries to redeem all: should fail or severely under-deliver relative to pre-run NAV claim.
        // With stuck unwithdrawable and healthy empty, redeem reverts (cannot transfer assets).
        vm.prank(bob);
        vm.expectRevert(); // ERC20 transfer fail or similar once idle can't cover
        pool.redeem(bobShares, bob, bob);

        // Prove the asymmetry: alice extracted ~half the pool's claimed value from liquid venues only.
        assertGe(aliceOut, 199 * U, "first mover drained healthy leg");
        assertEq(healthy.balanceOf(address(pool)), 0, "healthy venue empty");
        assertEq(stuck.balanceOf(address(pool)), 200 * U, "stuck still holds 200, still in NAV path");
    }

    function test_Residual_EnsureIdle_BalanceOfRevert_BricksWhenNeeded() public {
        RevertingBalanceVenue bad = new RevertingBalanceVenue(address(usdt0));
        HealthyVenue healthy = new HealthyVenue(address(usdt0));
        // Insert bad FIRST so the loop hits it before healthy when idle is short.
        pool.setVenueAllowed(address(bad), true);
        pool.setVenueAllowed(address(healthy), true);

        vm.prank(alice);
        pool.deposit(300 * U, alice);

        vm.startPrank(agent);
        pool.allocate(address(bad), 150 * U, "bad"); // deposit works; balanceOf reverts
        pool.allocate(address(healthy), 150 * U, "ok");
        vm.stopPrank();

        // totalAssets: try/catch → bad contributes 0, healthy 150, idle 0 → 150
        // Alice's shares still entitle her to convert using that (understated) NAV.
        // But _ensureIdle on redeem: first venue is bad, balanceOf reverts → brick.
        uint256 sh = pool.balanceOf(alice);
        // Even a small withdraw that needs any venue pull hits bad first if idle=0.
        vm.prank(alice);
        vm.expectRevert(); // balanceOf boom in _ensureIdle
        pool.withdraw(1 * U, alice, alice);

        // Control: pricing itself does not revert
        pool.totalAssets();
    }
}

contract StuckVenue is IVenueAdapter {
    using SafeERC20 for IERC20;
    IERC20 public immutable token;
    mapping(address => uint256) public position;

    constructor(address token_) {
        token = IERC20(token_);
    }

    function asset() external view returns (address) {
        return address(token);
    }

    function deposit(uint256 amount) external returns (uint256) {
        token.safeTransferFrom(msg.sender, address(this), amount);
        position[msg.sender] += amount;
        return amount;
    }

    function withdraw(uint256) external pure returns (uint256) {
        revert("stuck");
    }

    function balanceOf(address account) external view returns (uint256) {
        return position[account];
    }
}

contract HealthyVenue is IVenueAdapter {
    using SafeERC20 for IERC20;
    IERC20 public immutable token;
    mapping(address => uint256) public position;

    constructor(address token_) {
        token = IERC20(token_);
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
        uint256 amt = amount > bal ? bal : amount;
        position[msg.sender] = bal - amt;
        token.safeTransfer(msg.sender, amt);
        return amt;
    }

    function balanceOf(address account) external view returns (uint256) {
        return position[account];
    }
}

/// deposit works; balanceOf always reverts (asymmetric broken adapter).
contract RevertingBalanceVenue is IVenueAdapter {
    using SafeERC20 for IERC20;
    IERC20 public immutable token;
    mapping(address => uint256) public position;

    constructor(address token_) {
        token = IERC20(token_);
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
        uint256 amt = amount > bal ? bal : amount;
        position[msg.sender] = bal - amt;
        token.safeTransfer(msg.sender, amt);
        return amt;
    }

    function balanceOf(address) external pure returns (uint256) {
        revert("balanceOf boom");
    }
}
