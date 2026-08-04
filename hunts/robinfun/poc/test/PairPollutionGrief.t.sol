// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {Test, console} from "forge-std/Test.sol";

/// Mirrors RobinFunFactoryV2.graduate pollution check. LOCAL ONLY.
contract PairPollutionGriefTest is Test {
    uint256 constant POLLUTION_DUST_FACTOR = 1e6;
    uint256 constant LP_SUPPLY = 300_000_000 ether;

    function _polluted(uint256 wethRes, uint256 tokRes, uint256 lpEth) internal pure returns (bool) {
        bool ok = wethRes * POLLUTION_DUST_FACTOR <= lpEth && tokRes * POLLUTION_DUST_FACTOR <= LP_SUPPLY;
        return !ok;
    }

    function test_dustWethBlocksGraduation_cheap() public pure {
        uint256 lpEth = 3 ether;
        uint256 minPolluteWeth = lpEth / POLLUTION_DUST_FACTOR + 1;
        assertTrue(minPolluteWeth < 0.00001 ether, "pollution should cost tiny WETH");
        assertTrue(_polluted(minPolluteWeth, 0, lpEth), "tiny WETH pre-reserve must block graduate");
        assertTrue(!_polluted(0, 0, lpEth), "virgin pair allowed");
        console.log("min WETH wei to block graduation for 3 ETH lpEth:");
        console.logUint(minPolluteWeth);
    }

    function test_readyToGraduateFreezesTrading() public pure {
        bool readyToGraduate = true;
        bool graduated = false;
        bool tradable = !graduated && !readyToGraduate;
        assertTrue(!tradable, "curve freezes while graduate is blocked");
    }
}
