// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {
    IERC20MetadataUpgradeable
} from "@openzeppelin-contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";

import {
    IERC20PermitUpgradeable
} from "@openzeppelin-contracts-upgradeable/token/ERC20/extensions/IERC20PermitUpgradeable.sol";

/// @notice Mirrors FlapTaxTokenV3.PoolState.
enum PoolState {
    BondingCurve, // state0: Token is trading on the bonding curve, no tax, no transfers to pools
    Migrating, // state1: Token is in the process of migration
    EnforcedAntiFarmer, // state2: Token listed on DEX, tax applied for transfers involving any pool
    Free // state3: Token is free
}

/// @notice Gas-optimised state + anti-farmer expiry (mirrors FlapTaxTokenV3.PackedPoolState).
///         V4 vs V2/V3 behaviour is inferred from `flapV4Hook != address(0)` — no explicit poolType needed.
struct PackedPoolState {
    PoolState state;
    uint48 antiFarmerExpirationTime; // set by finalizeMigration() — uint48 matches FlapTaxTokenV3 (valid until year 9999)
}

interface ITokenV3 is IERC20MetadataUpgradeable, IERC20PermitUpgradeable {
    /// @notice Packed initialization parameters for initialize().
    ///         Using a struct reduces EVM stack pressure at call sites.
    struct InitParams {
        /// @dev All known pool addresses.
        ///      MUST include `mainPool`.
        ///      Blocked during BondingCurve phase and during anti-farmer.
        address[] pools;
        /// @dev The primary trading pool (UniV4 PoolManager / PCS Infinity Vault).
        ///      Must be non-zero and present in `pools`.
        address mainPool;
        /// @dev The token name.
        string name;
        /// @dev The token symbol.
        string symbol;
        /// @dev The token metadata URI.
        string meta;
        /// @dev The maximum supply of the token.
        uint256 maxSupply;
        /// @dev Anti-farmer period in seconds (stored; converted to absolute expiry
        ///      by finalizeMigration() at graduation time).
        uint256 antiFarmerDuration;
        /// @dev Optional dividend contract for tracking holder shares.
        ///      Pass address(0) to disable dividend tracking.
        ///      Mirrors FlapTaxTokenV2.dividendContract.
        address dividendContract;
        /// @dev Required TaxProcessorV2 for LP-fee distribution.
        ///      Mirrors FlapTaxTokenV2.taxProcessor.
        address taxProcessor;
        /// @dev Required address of the FlapV4Hook / FlapInfinityCLHook.
        address flapV4Hook;
    }

    /// @notice Initialize the token.
    function initialize(InitParams memory params) external;

    function poolState() external view returns (PackedPoolState memory);

    /// @notice Starts the migration process (used by the Portal Contract)
    function startMigration() external;

    /// @notice Finalizes the migration process (used by the Portal Contract)
    function finalizeMigration() external;

    /// @notice Timestamp when the anti-farmer period ends.
    ///         Returns 0 before finalizeMigration() is called.
    function antiFarmerExpirationTime() external view returns (uint256);

    function metaURI() external view returns (string memory);

    /// @notice the max supply of the token
    function maxSupply() external view returns (uint256);

    /// @notice Check if an address is a known pool for this token (mirrors FlapTaxTokenV2.pools)
    function pools(address pool) external view returns (bool);

    /// @notice The optional dividend contract for tracking holder shares.
    ///         address(0) when dividends are disabled.
    ///         Mirrors FlapTaxTokenV2.dividendContract.
    function dividendContract() external view returns (address);

    /// @notice The TaxProcessorV2 for LP-fee distribution.
    ///         Mirrors FlapTaxTokenV2.taxProcessor.
    function taxProcessor() external view returns (address);

    function openSwapGate() external;

    function isAntiFarmerActive() external view returns (bool);

    //
    // Customized Events to ease the indexer
    //

    // custom transfer event

    /// @notice the same as the ERC20 Transfer event, we intentionally duplicate it here
    /// This would make the indexer easier to index our transfer event only.
    /// To save gas, we remove indexed from the from and to
    event TransferFlapToken(address from, address to, uint256 value);

    /// @notice Emitted (via revert) when a dividend setShare call fails.
    ///         Mirrors FlapTaxTokenV2.DividendShareUpdateFailed.
    error DividendShareUpdateFailed(address account, bytes reason);

    /// @notice Emitted when the pool state changes
    event PoolStateChanged(uint8 fromState, uint8 toState);
}
