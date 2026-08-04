// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";

interface IBondingCurvePoolV2Grad {
    function finalizeGraduation() external returns (bytes32 poolId, uint128 liquidity);
    function state() external view returns (uint8);
}

/// @title GraduationManager
/// @notice The single authorized trigger for pool graduation. Each V2 pool
///         trusts exactly one GraduationManager (immutable in the pool), so
///         `finalize` can be permissionless: it carries no manipulable
///         parameters — the migration price and amounts are derived on-chain
///         from the pool's terminal curve state. On failure the pool self-marks
///         MIGRATION_FAILED and can be retried.
contract GraduationManager is Ownable2Step {
    address public factory;
    mapping(address pool => bool) public registered;

    error OnlyFactory();
    error AlreadySet();
    error NotRegistered();
    error ZeroAddress();

    event FactorySet(address factory);
    event PoolRegistered(address indexed pool);
    event Finalized(address indexed pool, bytes32 indexed poolId, uint128 liquidity);
    event FinalizeFailed(address indexed pool);

    constructor(address owner_) Ownable(owner_) {}

    function setFactory(address f) external onlyOwner {
        if (factory != address(0)) revert AlreadySet();
        if (f == address(0)) revert ZeroAddress();
        factory = f;
        emit FactorySet(f);
    }

    function registerPool(address pool) external {
        if (msg.sender != factory) revert OnlyFactory();
        registered[pool] = true;
        emit PoolRegistered(pool);
    }

    /// @notice Finalize a ready (or previously-failed) pool's graduation.
    function finalize(address pool) external returns (bytes32 poolId, uint128 liquidity) {
        if (!registered[pool]) revert NotRegistered();
        (poolId, liquidity) = IBondingCurvePoolV2Grad(pool).finalizeGraduation();
        if (poolId == bytes32(0)) {
            emit FinalizeFailed(pool);
        } else {
            emit Finalized(pool, poolId, liquidity);
        }
    }
}
