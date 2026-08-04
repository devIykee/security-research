// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {LaunchParams, VaultParams} from "../Params.sol";

interface IParamRegistry {
    function owner() external view returns (address);
    function getLaunchParams() external view returns (LaunchParams memory);
    function getVaultParams() external view returns (VaultParams memory);
    function launchParamsVersion() external view returns (uint64);
    function eligibleMark(address mark) external view returns (bool);
}

interface IVaultManager {
    function registerCoin(address coin, address mark) external;
    function depositFor(address coin) external payable;
    function isEligibleMark(address mark) external view returns (bool);
}

interface ICreatorFees {
    function setCreator(address coin, address creator) external;
    function accrue(address coin) external payable;
}

interface ICurve {
    function register(address coin, address creator, address mark, LaunchParams calldata p) external;
    function buyFor(address coin, address recipient, uint256 minTokensOut, bool taxExempt)
        external
        payable
        returns (uint256 tokensOut);
    function buy(address coin, uint256 minTokensOut, uint256 deadline) external payable returns (uint256 tokensOut);
    function creatorOf(address coin) external view returns (address);
    function markOf(address coin) external view returns (address);
    function isGraduated(address coin) external view returns (bool);
    function priceWeiPerToken(address coin) external view returns (uint256);
    function quoteBuy(address coin, uint256 ethGross)
        external
        view
        returns (uint256 tokensOut, uint256 fee, uint256 tax, uint256 acceptedGross, uint256 refund);
}

interface IMarkOracle {
    function hasFeed(address token) external view returns (bool);
    function update(address token) external returns (uint256 emaPrice);
    function emaOf(address token) external view returns (uint256);
    function spotOf(address token) external view returns (uint256);
}

interface IGraduator {
    function graduate(address coin, uint16 poolVaultBps, uint16 poolCreatorBps, uint16 poolTreasuryBps)
        external
        payable;
}

interface ILoxleyCoin {
    function initialize(string calldata name_, string calldata symbol_, address curve) external;
    function burn(uint256 amount) external;
}
