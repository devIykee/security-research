// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface IPausableEE {
    error Paused();

    event TradingPaused(address indexed pauser);

    event TradingUnpaused(address indexed pauser);
}

abstract contract IPausable is IPausableEE {
    function _pauseTrading() internal virtual;

    function _unpauseTrading() internal virtual;
}
