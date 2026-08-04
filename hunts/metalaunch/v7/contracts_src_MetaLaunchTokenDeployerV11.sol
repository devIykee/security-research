// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {MetaLaunchTokenV11} from "./MetaLaunchTokenV11.sol";

/// @title  MetaLaunchTokenDeployerV11
/// @notice Thin, ownerless CREATE2 deployer that holds the MetaLaunchTokenV11
///         creation bytecode so the factory doesn't have to embed it (keeping
///         the factory under EIP-170). Deterministic: the token's CREATE2
///         address is derived from THIS contract's address. Bound one-time to
///         its factory; only the factory may deploy. Holds no funds, no state
///         beyond the immutable-ish factory binding, and exposes the init-code
///         hash so the factory can predict/grind addresses without embedding
///         the 10 KB creation code itself.
contract MetaLaunchTokenDeployerV11 {
    address public factory;
    bool private _bound;

    error AlreadyBound();
    error NotFactory();
    error ZeroAddress();

    /// @notice One-time factory binding (deploy deployer → deploy factory with
    ///         this deployer → bind). After binding, immutable.
    function bindFactory(address factory_) external {
        if (_bound) revert AlreadyBound();
        if (factory_ == address(0)) revert ZeroAddress();
        factory = factory_;
        _bound = true;
    }

    /// @notice Deploy a MetaLaunchTokenV11 via CREATE2. Factory-only.
    function deploy(bytes32 salt, MetaLaunchTokenV11.InitParams calldata ip) external returns (address token) {
        if (msg.sender != factory) revert NotFactory();
        token = address(new MetaLaunchTokenV11{salt: salt}(ip));
    }

    /// @notice keccak256 of the token's full init code for the given params —
    ///         the CREATE2 prediction input. Callers combine with this
    ///         contract's address and a salt.
    function tokenInitCodeHash(MetaLaunchTokenV11.InitParams calldata ip) external pure returns (bytes32) {
        return keccak256(abi.encodePacked(type(MetaLaunchTokenV11).creationCode, abi.encode(ip)));
    }

    /// @notice Predicted CREATE2 address for (salt, init-code hash) from THIS deployer.
    function predict(bytes32 salt, bytes32 initCodeHash) external view returns (address) {
        return address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), address(this), salt, initCodeHash)))));
    }
}
