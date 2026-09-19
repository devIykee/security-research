// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.26;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

import {ProtocolOwner} from "src/core/ProtocolOwner.sol";

contract FilecoinSPNodes is ERC1155, ProtocolOwner, ReentrancyGuard {

    uint256 public constant FILECOIN_SP_NODE = 1;

    /**
     * @dev Client should repacle with actual token ID in 64 hex format. For token id 1, it will be:
     * 0000000000000000000000000000000000000000000000000000000000000001
     * 
     * See OpenZeppelin ERC1155 documentation for more details:
     * https://docs.openzeppelin.com/contracts/5.x/erc1155
     */
    constructor(address _protocol) 
        ERC1155("https://ipfs.io/ipfs/bafybeifr5l62fffbafzoefb5l6egvkzt2pnygmb3q4blw4hrmun3w2geym/{id}.json")
        ProtocolOwner(_protocol) {
    }

    function setURI(string memory newuri) external nonReentrant onlyOwner {
        _setURI(newuri);
    }

    function mint(address to, uint256 id, uint256 value, bytes memory data) external nonReentrant onlyOwner {
        require(id == FILECOIN_SP_NODE, "Invalid token id");
        _mint(to, id, value, data);
    }
}