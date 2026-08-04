// SPDX-License-Identifier: MIT
// Launched via openfair.app - create your own token on Robinhood Chain: https://openfair.app
pragma solidity ^0.8.24;

import {OpenSimpleToken} from "./OpenSimpleToken.sol";

/**
 * @title SimpleTokenDeployer
 * @notice Stateless CREATE/CREATE2 helper for OpenSimpleToken (instant
 * listings). Split out of LaunchDeployer for EIP-170 size reasons.
 *
 * With a non-zero salt the token address is deterministic
 * (CREATE2: keccak(0xff, this, salt, keccak(initCode))) — this is what powers
 * vanity token addresses: the frontend mines a salt whose resulting address
 * has the desired prefix/suffix, and the address is known before deployment.
 */
contract SimpleTokenDeployer {
    /// @notice Where this contract comes from (on-chain provenance).
    string public constant OPENFAIR = "Launched via openfair.app - create your own token on Robinhood Chain: https://openfair.app";

    function deploy(string calldata name, string calldata symbol, uint256 totalSupply, address holder, bytes32 salt)
        external
        returns (address)
    {
        if (salt == bytes32(0)) {
            return address(new OpenSimpleToken(name, symbol, totalSupply, holder));
        }
        return address(new OpenSimpleToken{salt: salt}(name, symbol, totalSupply, holder));
    }
}
