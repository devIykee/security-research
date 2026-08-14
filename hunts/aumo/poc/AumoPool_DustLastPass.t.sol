// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {AumoPool} from "../src/AumoPool.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IVenueAdapter} from "../src/interfaces/IVenueAdapter.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

contract AumoPoolDustLastPassTest is Test {
    using SafeERC20 for IERC20;
    MockERC20 usdt0;
    AumoPool pool;
    address agent = address(0xA9E17);
    address alice = address(0xA11CE);
    uint256 constant U = 1e6;

    function setUp() public {
        usdt0 = new MockERC20("USDT0", "USDT0", 6);
        pool = new AumoPool(IERC20(address(usdt0)), address(this));
        pool.setAgent(agent);
        pool.setPolicy(type(uint256).max / 2, type(uint256).max / 2, type(uint256).max / 2);
        usdt0.mint(alice, 1_000_000 * U);
        vm.prank(alice);
        usdt0.approve(address(pool), type(uint256).max);
    }

    function test_TrueDust_Share1_LastPassBehavior() public {
        Lossy v = new Lossy(address(usdt0), 50); // 0.5% under-delivery per pull
        pool.setVenueAllowed(address(v), true);
        vm.prank(alice);
        pool.deposit(100_000 * U, alice);
        vm.prank(agent);
        pool.allocate(address(v), 100_000 * U, "all");

        uint256 faceBefore = v.face(address(pool));
        // Exactly 1 share
        vm.prank(alice);
        pool.redeem(1, alice, alice);

        uint256 faceAfter = v.face(address(pool));
        uint256 assetsOut = usdt0.balanceOf(alice); // may include leftover from mint
        console2.log("faceBefore", faceBefore);
        console2.log("faceAfter", faceAfter);
        console2.log("facePulled", faceBefore - faceAfter);
        console2.log("preview 1 share assets", pool.convertToAssets(1));
        if (faceAfter == 0) console2.log("FULL LIQ on 1 share");
        else console2.log("partial only");
    }

    function test_DustAssets_1U_LastPass() public {
        Lossy v = new Lossy(address(usdt0), 100); // 1%
        pool.setVenueAllowed(address(v), true);
        vm.prank(alice);
        pool.deposit(100_000 * U, alice);
        uint256 shAll = pool.balanceOf(alice);
        // withdraw exactly 1 USDT0 unit of assets
        vm.prank(agent);
        pool.allocate(address(v), 100_000 * U, "all");

        uint256 faceBefore = v.face(address(pool));
        vm.prank(alice);
        pool.withdraw(1 * U, alice, alice); // 1 USDT0
        uint256 faceAfter = v.face(address(pool));
        console2.log("withdraw 1 USDT0: faceBefore", faceBefore);
        console2.log("faceAfter", faceAfter);
        console2.log("facePulled", faceBefore - faceAfter);
        if (faceAfter == 0) console2.log("FULL LIQ");
    }
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
