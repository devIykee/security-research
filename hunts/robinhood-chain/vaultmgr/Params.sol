// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

uint256 constant BPS = 10_000;

// Total fixed supply of every loxley coin. Minted once at creation, only ever decreases via burn.
uint256 constant COIN_SUPPLY = 1_000_000_000 ether;

/// @notice Economic parameters snapshotted per coin at creation. Never retroactive:
/// a queued change in the ParamRegistry only affects coins created after it applies.
struct LaunchParams {
    // bonding curve shape
    uint128 virtualEth0; // initial virtual ETH reserve
    uint128 virtualToken0; // initial virtual token reserve (> COIN_SUPPLY so the curve can't sell out)
    uint128 graduationEth; // real ETH reserves that trigger graduation
    uint96 launchFeeWei; // flat fee to create a coin, sent to treasury
    // curve-phase fee, bps of trade gross; split must sum to curveFeeBps
    uint16 curveFeeBps;
    uint16 curveVaultBps;
    uint16 curveCreatorBps;
    uint16 curveTreasuryBps;
    // graduated-pool hook fee, bps of the ETH leg; split must sum to poolFeeBps
    uint16 poolFeeBps;
    uint16 poolVaultBps;
    uint16 poolCreatorBps;
    uint16 poolTreasuryBps;
    // sniper tax on curve buys: taxStartBps * (1 - t/taxWindow)^2, exactly 0 once t >= taxWindow
    uint32 taxWindow;
    uint16 taxStartBps;
}

/// @notice Operational limits for vault conversion and the buyback crank. Read live
/// (not snapshotted): these bound keeper behavior, never user-facing economics.
struct VaultParams {
    uint128 trancheEthCap; // max ETH converted to USDG per convert() call
    uint128 trancheUsdgCap; // max USDG spent buying the mark per convert() call
    uint32 epochLength; // seconds per spend epoch
    uint128 epochSpendCapUsdg; // max USDG spent per coin per epoch
    uint16 impactCapBps; // max execution price deviation vs pre-swap spot
    uint16 crankMarginBps; // buyback fires when spot < NAV * (1 - margin)
    uint16 crankTrancheBps; // fraction of vault value sold per poke
    uint128 crankRewardUsdg; // flat caller reward per successful poke
    uint32 emaHalfLife; // mark oracle smoothing half-life, seconds
    uint16 emaMaxStepBps; // max EMA move per update
    // vault swaps skip when pool spot deviates from the clamped EMA beyond this band.
    // The impact cap alone is relative to the CURRENT spot, so a pre-shoved pool passes
    // it; stock tokens trade 24/7 (pause flags never engage in practice), so thin
    // weekend pools are cheap to shove — this anchors execution to the EMA instead.
    uint16 execBandBps;
}
