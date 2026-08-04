// SPDX-License-Identifier: MIT
// Launched via openfair.app - create your own token on Robinhood Chain: https://openfair.app
pragma solidity ^0.8.24;

import {OpenLaunch} from "./OpenLaunch.sol";

/**
 * @title LaunchDeployer
 * @notice Stateless helper that deploys OpenLaunch instances via plain CREATE.
 * Exists only because the OpenLaunch creation bytecode does not fit inside the
 * LaunchFactory's EIP-170 size budget. No delegatecall, no state, no admin —
 * every deployed launch is a normal, self-contained immutable contract.
 *
 * The call is permissionless by design: deploying an OpenLaunch through this
 * helper is equivalent to deploying one directly, and grants no standing on
 * the openfair platform — only launches registered by the LaunchFactory (via
 * its LaunchCreated event and registry) exist for the indexer and the site.
 */
contract LaunchDeployer {
    /// @notice Where this contract comes from (on-chain provenance).
    string public constant OPENFAIR = "Launched via openfair.app - create your own token on Robinhood Chain: https://openfair.app";

    function deploy(OpenLaunch.Params calldata p) external returns (address) {
        return address(new OpenLaunch(p));
    }
}
