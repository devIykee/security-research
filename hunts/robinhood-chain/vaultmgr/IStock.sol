// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @notice Robinhood Chain tokenized stock ("Stock" implementation behind BeaconProxy).
/// Verified impl: 0xb35490d6f9163DE4F80d88dc75c3516eb64C5aE2 on robinhoodchain.blockscout.com
/// (all official tokens are BeaconProxies on beacon 0xe10b…1b00). Transfers are blocked when
/// tokenPaused — but NO pause flag has ever engaged on-chain (zero Paused/OraclePaused events
/// through 2026-07-04, incl. closed-market weekends): tokens transfer and trade on DEX pools
/// 24/7. Treat the probes as a guard against future issuer policy, not a market-hours signal.
/// Balances use a uiMultiplier for splits: raw balanceOf is what transfers move, balanceOfUI
/// is display-only.
interface IStock is IERC20 {
    function tokenPaused() external view returns (bool);
    function oraclePaused() external view returns (bool);
    function paused() external view returns (bool);
    function uiMultiplier() external view returns (uint256);
    function balanceOfUI(address account) external view returns (uint256);
}
