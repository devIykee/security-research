// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {INonceManager} from "../interfaces/INonceManager.sol";

abstract contract NonceManager is INonceManager {
    mapping(address => uint256) public nonces;

    function incrementNonce() external override {
        updateNonce(1);
    }

    function updateNonce(uint256 val) internal {
        uint256 newNonce = nonces[msg.sender] + val;
        nonces[msg.sender] = newNonce;
        emit NonceIncremented(msg.sender, newNonce);
    }

    function isValidNonce(address usr, uint256 nonce) public view override returns (bool) {
        return nonces[usr] == nonce;
    }
}
