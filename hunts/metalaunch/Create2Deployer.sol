// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title  Create2Deployer — minimal, permissionless CREATE2 factory
/// @notice Used once at MetaLaunch V7 deployment so MetaLocker and the
///         launchpad land at ground vanity addresses (suffix 0x…c0de).
///         Stateless, ownerless; it can only create contracts. Neither
///         MetaLocker nor the launchpad depends on the deployer address
///         (both are configured purely by constructor args), so deploying
///         through this factory changes nothing about their behavior or
///         source verification.
contract Create2Deployer {
    error Create2Failed();

    event Deployed(address indexed addr, bytes32 indexed salt);

    function deploy(bytes32 salt, bytes memory initCode) external returns (address addr) {
        assembly {
            addr := create2(0, add(initCode, 0x20), mload(initCode), salt)
        }
        if (addr == address(0)) revert Create2Failed();
        emit Deployed(addr, salt);
    }

    function computeAddress(bytes32 salt, bytes32 initCodeHash) external view returns (address) {
        return address(uint160(uint256(keccak256(abi.encodePacked(hex"ff", address(this), salt, initCodeHash)))));
    }
}
