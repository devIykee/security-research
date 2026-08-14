// SAFE, read-only, LOCAL UNIT PoC. No mainnet state touched.
// Temporary audit-phase AI-generated test — ignore in production review.
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";

/// @dev Mirrors ISecurityRegistry.Status + getPoolStatus used by SheriffBasePlugin.
interface ISecurityRegistry {
    enum Status {
        ENABLED,
        BURN_ONLY,
        DISABLED
    }

    function getPoolStatus(address pool) external view returns (Status);
}

error PoolDisabled();
error BurnOnly();

/// @dev Exact checks from hunts/sheriff/src/SheriffBasePlugin/contracts/plugins/SecurityPlugin.sol
contract SecurityChecks {
    address internal securityRegistry;

    function setRegistry(address r) external {
        securityRegistry = r;
    }

    // _checkStatus — skips call when registry is address(0)
    function checkStatus() external view {
        if (securityRegistry != address(0)) {
            ISecurityRegistry.Status status = ISecurityRegistry(securityRegistry).getPoolStatus(msg.sender);
            if (status != ISecurityRegistry.Status.ENABLED) {
                if (status == ISecurityRegistry.Status.DISABLED) revert PoolDisabled();
                else revert BurnOnly();
            }
        }
    }

    // _checkStatusOnBurn — NO zero-registry guard (the sibling hole)
    function checkStatusOnBurn() external view {
        ISecurityRegistry.Status status = ISecurityRegistry(securityRegistry).getPoolStatus(msg.sender);
        if (status == ISecurityRegistry.Status.DISABLED) {
            revert PoolDisabled();
        }
    }
}

contract PoC is Test {
    SecurityChecks checks;

    function setUp() public {
        checks = new SecurityChecks();
    }

    /// Mint/swap path stays open when registry is unset.
    function test_mintPath_ok_whenRegistryZero() public view {
        checks.checkStatus();
    }

    /// Burn path hits address(0).getPoolStatus and reverts. LP cannot exit.
    function test_burnPath_reverts_whenRegistryZero() public {
        vm.expectRevert();
        checks.checkStatusOnBurn();
    }

    /// Same registry=0: mint works, burn does not. That is the sibling inconsistency.
    function test_exploit() public {
        checks.checkStatus(); // mint/swap would proceed
        vm.expectRevert();
        checks.checkStatusOnBurn(); // burn bricks
        console.log("registry=0: mint/swap PASS, burn REVERTS");
    }
}
