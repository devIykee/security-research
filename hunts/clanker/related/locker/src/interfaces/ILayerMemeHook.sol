// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ILayerMeme} from "./ILayerMeme.sol";

import {PoolId} from "@uniswap/v4-core/src/types/PoolId.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";

interface ILayerMemeHook {
    error ETHPoolNotAllowed();
    error OnlyFactory();
    error UnsupportedInitializePath();
    error PastCreationTimestamp();
    error MevModuleEnabled();
    error WethCannotBeLayerMeme();

    event PoolCreatedOpen(
        address indexed pairedToken,
        address indexed layerMeme,
        PoolId poolId,
        int24 tickIfToken0IsLayerMeme,
        int24 tickSpacing
    );

    event PoolCreatedFactory(
        address indexed pairedToken,
        address indexed layerMeme,
        PoolId poolId,
        int24 tickIfToken0IsLayerMeme,
        int24 tickSpacing,
        address locker,
        address mevModule
    );

    // note: is not emitted when a mev module expires
    event MevModuleDisabled(PoolId);
    event ClaimProtocolFees(address indexed token, uint256 amount);

    // initialize a pool on the hook for a token
    function initializePool(
        address layerMeme,
        address pairedToken,
        int24 tickIfToken0IsLayerMeme,
        int24 tickSpacing,
        address locker,
        address mevModule,
        bytes calldata poolData
    ) external returns (PoolKey memory);

    // initialize a pool not via the factory
    function initializePoolOpen(
        address layerMeme,
        address pairedToken,
        int24 tickIfToken0IsLayerMeme,
        int24 tickSpacing,
        bytes calldata poolData
    ) external returns (PoolKey memory);

    // turn a pool's mev module on if it exists
    function initializeMevModule(PoolKey calldata poolKey, bytes calldata mevModuleData) external;

    // note: original base ILayerMemeHook deployment is missing these functions but
    // the ILayerMemeLpFeeConversion locker needs them
    function mevModuleEnabled(PoolId poolId) external view returns (bool);
    function poolCreationTimestamp(PoolId poolId) external view returns (uint256);
    function MAX_MEV_MODULE_DELAY() external view returns (uint256);

    function supportsInterface(bytes4 interfaceId) external pure returns (bool);
}
