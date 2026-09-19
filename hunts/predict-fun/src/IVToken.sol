// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface IVToken {
    function balanceOfUnderlying(address _owner) external returns (uint256);
    function mint(uint256 _amount) external returns (uint256);
    function redeem(uint256 _amount) external returns (uint256);
    function redeemUnderlying(uint256 _amount) external returns (uint256);

    function balanceOf(address _owner) external view returns (uint256);
    function exchangeRateCurrent() external returns (uint256);
    function isVToken() external view returns (bool);
    function underlying() external view returns (address);

    function comptroller() external view returns (address);
}
