// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

abstract contract INonceManager {
    event NonceIncremented(address indexed user, uint256 newNonce);

    function incrementNonce() external virtual;

    function isValidNonce(address user, uint256 userNonce) public view virtual returns (bool);
}
