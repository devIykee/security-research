// SPDX-License-Identifier: MIT
// Launched via openfair.app - create your own token on Robinhood Chain: https://openfair.app
pragma solidity ^0.8.24;

import {OpenFairToken} from "./OpenFairToken.sol";

/**
 * @title FairTokenDeployer
 * @notice Stateless CREATE/CREATE2 helper for OpenFairToken (curve launches).
 * Split out of LaunchFactory in v1.9 for EIP-170 size reasons – the factory
 * had outgrown the 24,576-byte limit with the token initcode embedded.
 *
 * With a non-zero salt the token address is deterministic
 * (CREATE2: keccak(0xff, this, salt, keccak(initCode))) – this is what powers
 * vanity token addresses for fair launches: the frontend mines a salt against
 * THIS contract's address.
 */
contract FairTokenDeployer {
    /// @notice Where this contract comes from (on-chain provenance).
    string public constant OPENFAIR = "Launched via openfair.app - create your own token on Robinhood Chain: https://openfair.app";

    /// @notice Only the factory that ordered a token may manage it here.
    error NotTokenDeployer();
    /// @notice The token's own transfer returned false.
    error TransferFailed();

    /// @notice token -> the caller (factory) that ordered its deployment.
    /// OpenFairToken records THIS contract as its `deployer` (that address is
    /// what the pre-graduation transfer gate and setLaunchpad trust), so the
    /// factory's deployer-only actions are forwarded through here, gated to
    /// the ordering factory – exactly the same trust shape as before the split.
    mapping(address => address) public deployedBy;

    /// @notice Deploys an OpenFairToken holding the full supply HERE; the
    /// ordering factory then distributes it via transferFor(). With a non-zero
    /// salt the address is CREATE2-deterministic against THIS contract.
    function deploy(string calldata name, string calldata symbol, uint256 totalSupply, bytes32 salt)
        external
        returns (address token)
    {
        token = salt == bytes32(0)
            ? address(new OpenFairToken(name, symbol, totalSupply, address(this)))
            : address(new OpenFairToken{salt: salt}(name, symbol, totalSupply, address(this)));
        deployedBy[token] = msg.sender;
    }

    /// @notice Supply distribution on the ordering factory's behalf (the
    /// pre-graduation gate only allows transfers FROM the token's deployer).
    function transferFor(address token, address to, uint256 amount) external {
        if (deployedBy[token] != msg.sender) revert NotTokenDeployer();
        if (!OpenFairToken(token).transfer(to, amount)) revert TransferFailed();
    }

    /// @notice Forward the token's one-time launchpad wiring (deployer-gated
    /// in OpenFairToken) to the factory that ordered the token.
    function setLaunchpad(address token, address launchpad) external {
        if (deployedBy[token] != msg.sender) revert NotTokenDeployer();
        OpenFairToken(token).setLaunchpad(launchpad);
    }
}
