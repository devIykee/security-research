// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IHoodTechFactory {
    /// @notice Minimal launch data the positions locker needs.
    function getLaunchBasics(address token)
        external
        view
        returns (address pool, address beneficiary, bool tokenIsToken0);
}
