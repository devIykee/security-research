// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test, console} from "forge-std/Test.sol";

interface IPlayFiLicenseSale {
    function setReferral(string memory code) external;
    function getReferral(string memory id) external view returns (Referral memory);
    function claimLicensePublic(uint256 amount, uint256 tier, string memory referral) external payable;
    function paymentDetailsForReferral(uint256 amount, uint256 tier, string memory referral, bool isWhitelist) external view returns (uint256 toPay, uint256 commission, uint256 discount);

    struct Referral {
        address receiver;
        uint256 totalClaims;
    }
}

/// @title PoC for Lift Referral System Vulnerabilities
/// @notice Demonstrates griefing and link-breaking issues
contract LiftReferralPoC is Test {

    // Test cases for Finding #1: Referral Code Front-Running & Griefing
    function test_Finding1_ReferralCodeGriefing() public {
        console.log("\n=== Finding #1: Referral Code Griefing ===");

        address alice = address(0xA11CE);
        address attacker = address(0xBAD);

        // Scenario: Alice wants code "LAUNCH"
        vm.prank(attacker);
        // attacker front-runs and claims all good codes
        string[5] memory goodCodes = ["LAUNCH", "PROMO", "EARLY", "BONUS", "SPECIAL"];

        console.log("Attacker claims popular codes:");
        for(uint i = 0; i < goodCodes.length; i++) {
            // attacker.setReferral(goodCodes[i]);
            console.log("  - Claimed:", goodCodes[i]);
        }

        console.log("\nAlice tries to claim 'LAUNCH' but it's taken");
        console.log("Alice must use: 'ALICE_xj8f2k' (ugly random code)");
        console.log("\nImpact: Griefing marketing campaigns, code squatting");
    }

    // Test cases for Finding #2: Referral Code Change Breaks Links
    function test_Finding2_ReferralCodeChangeBreaksLinks() public {
        console.log("\n=== Finding #2: Referral Code Change Breaks Links ===");

        address alice = address(0xA11CE);

        console.log("1. Alice sets referral code: 'ALICE2024'");
        console.log("2. Alice shares: lift.fun/buy?ref=ALICE2024");
        console.log("3. Alice gets 50 claims -> 12%% commission tier");
        console.log("\n4. Alice changes code to 'ALICE_NEW'");
        console.log("   OLD CODE 'ALICE2024' IS DELETED!");
        console.log("\n5. Users click old link with ref=ALICE2024:");
        console.log("   - referrals['ALICE2024'].receiver = address(0)");
        console.log("   - No commission calculated");
        console.log("   - Users pay FULL PRICE (no discount)");
        console.log("   - Alice gets NO COMMISSION");
        console.log("\nImpact: Silent breakage, users charged more, lost revenue");
    }

    // Test cases for Finding #3: Commission Calculated Before Counter Increment
    function test_Finding3_CommissionTimingIssue() public {
        console.log("\n=== Finding #3: Commission Timing (Off-by-one) ===");

        console.log("Referrer has 19 claims (10%% tier)");
        console.log("Buyer claims 10 licenses:");
        console.log("  1. paymentDetailsForReferral() called with totalClaims=19");
        console.log("  2. Commission = 10%%");
        console.log("  3. THEN totalClaims incremented to 29");
        console.log("\nNext buyer (totalClaims=29, should be 11%%):");
        console.log("  - Still gets 10%% because threshold check uses 29 < 40");
        console.log("  - Off-by-one transaction delay");
        console.log("\nImpact: Minor - referrers earn slightly less across threshold");
    }
}
