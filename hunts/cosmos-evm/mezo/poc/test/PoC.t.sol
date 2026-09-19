// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";

interface IPriceFeed {
    function fetchPrice() external view returns (uint256);
}

interface IOracle {
    function latestRoundData()
        external
        view
        returns (uint80, int256, uint256, uint256, uint80);
}

/// MZ-01: MUSD PriceFeed fail-closed 60s staleness gate.
///
/// Differential proof on a Mezo mainnet fork:
///   case A: oracle reports updatedAt == now        -> fetchPrice() returns price
///   case B: oracle reports updatedAt == now - 61   -> fetchPrice() reverts "stale"
///
/// The oracle precompile (0x7b7c..0015) is node-native Go code and does not
/// exist as bytecode on a local anvil fork, so we vm.mockCall it. That is the
/// exact ABI surface PriceFeed.sol reads (verified live on mainnet).
contract PoC is Test {
    address constant PRICE_FEED = 0xc5aC5A8892230E0A3e1c473881A2de7353fFcA88;
    address constant ORACLE_PRECOMPILE = 0x7b7c000000000000000000000000000000000015;

    function _mockOracle(uint256 updatedAt) internal {
        vm.mockCall(
            ORACLE_PRECOMPILE,
            abi.encodeWithSelector(IOracle.latestRoundData.selector),
            abi.encode(
                uint80(1),
                int256(79_254e15), // ~$79k BTC, 18 dec
                updatedAt,
                updatedAt,
                uint80(0)
            )
        );
        vm.mockCall(
            ORACLE_PRECOMPILE,
            abi.encodeWithSignature("decimals()"),
            abi.encode(uint8(18))
        );
    }

    function test_fresh_price_passes() public {
        _mockOracle(block.timestamp);
        uint256 p = IPriceFeed(PRICE_FEED).fetchPrice();
        assertGt(p, 0, "fresh price should return");
    }

    function test_exploit_stale_price_locks_everything() public {
        // 61 seconds of oracle silence: heartbeat blip, sequencer outage,
        // validator vote-extension stall. MAX_PRICE_DELAY = 60.
        _mockOracle(block.timestamp - 61);

        // Every consumer reverts: liquidate(), closeTrove(), openTrove(),
        // adjustTrove... all route through fetchPrice().
        vm.expectRevert("PriceFeed: Oracle is stale.");
        this.fetchPrice();
    }

    /// allow expectRevert on external call
    function fetchPrice() external view {
        IPriceFeed(PRICE_FEED).fetchPrice();
    }
}
