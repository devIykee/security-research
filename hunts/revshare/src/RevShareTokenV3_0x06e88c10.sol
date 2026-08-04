// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {RevShareGraduationToken} from "./RevShareGraduationToken.sol";

/// @notice RevShare token used by a V3 position launch. Position fees are collected by its launch contract.
contract RevShareTokenV3 is RevShareGraduationToken {
    constructor(
        string memory tokenName,
        string memory tokenSymbol,
        uint8 tokenDecimals,
        uint256 tokenSupply,
        string memory tokenMetadataURI,
        string memory tokenLogo,
        string memory tokenDescription,
        Socials memory tokenSocials,
        address initialHolder,
        address initialOwner,
        address graduationSource,
        uint256 graduationThreshold
    )
        RevShareGraduationToken(
            tokenName,
            tokenSymbol,
            tokenDecimals,
            tokenSupply,
            tokenMetadataURI,
            tokenLogo,
            tokenDescription,
            tokenSocials,
            initialHolder,
            initialOwner,
            graduationSource,
            graduationThreshold
        )
    {}

    function tokenType() external pure returns (bytes32) {
        return keccak256("RevShareTokenV3");
    }
}
