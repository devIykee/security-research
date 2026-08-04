// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title ISlvrTaxHandler
/// @notice Pluggable sink for SLVR trading tax. SlvrToken collects tax on trades (across any number
///         of registered pools/venues) and hands it off to the configured handler for processing.
///         This decouples WHAT happens to the tax (which DEX it's swapped on, where the proceeds go,
///         whether some is burned/split) from the token itself — so new venues (V3, V4, …) or new
///         destinations are added by deploying a new handler and pointing the token at it, with NO
///         token redeploy. Implementations can route to multiple places and be swapped freely.
interface ISlvrTaxHandler {
    /// @notice Process `amount` of SLVR tax.
    /// @dev PULL model: SlvrToken grants this handler an allowance of exactly `amount` immediately
    ///      before calling. The handler MUST pull it via `transferFrom(slvr, address(this), amount)`
    ///      and then convert/route it however it likes. If the handler reverts, the pull is rolled
    ///      back, so the token safely retains the tax and can retry later — never a silent loss.
    /// @param amount The SLVR amount the handler is authorized to pull and process.
    function handleTax(uint256 amount) external;
}
