// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title WhitelistedERC1155
 * @notice ERC1155 extension with optional transfer whitelist control
 */
contract WhitelistedERC1155 is ERC1155, AccessControl {
    /**
     * @notice Enable or disable CTF transfers.
     *         It is enabled by default, but if something breaks, it can be disabled as it
     *         is the default behavior of the original implementation.
     */
    bool public transferControlEnabled = true;

    /// @dev Emitted when the transferControlEnabled flag is toggled.
    event TransferControlEnabled(bool enabled);

    /**
     * @dev Emitted when an address's isTransferAllowed status is updated.
     * @param addr the address we set transfer control on
     * @param isAllowed Whether the address is allowed to transfer CTFs.
     */
    event IsTransferAllowedUpdated(address indexed addr, bool isAllowed);

    /**
     * @notice This error is thrown when transfer control is enabled and neither "from" and "to" are in the whitelist.
     */
    error NotAllowedToTransfer();

    /**
     * @notice isTransferAllowed is a whitelist on addresses that are allowed to transfer CTFs.
     */
    mapping(address addr => bool isAllowed) public isTransferAllowed;

    constructor(string memory uri_, address owner_) ERC1155(uri_) {
        _grantRole(DEFAULT_ADMIN_ROLE, owner_);
    }

    /**
     * @notice Enable or disable transfer control. Only callable by the default admin role.
     * @param enabled True to enable transfer control, false to disable it.
     */
    function setTransferControlEnabled(bool enabled) external onlyRole(DEFAULT_ADMIN_ROLE) {
        transferControlEnabled = enabled;
        emit TransferControlEnabled(enabled);
    }

    /**
     * @notice Whitelist or blacklist an address from being able to transfer CTFs. Only callable by the default admin role.
     * @param addr the address we set transfer control on
     * @param isAllowed Whether the address is allowed to transfer CTFs.
     */
    function updateIsTransferAllowed(address addr, bool isAllowed) external onlyRole(DEFAULT_ADMIN_ROLE) {
        isTransferAllowed[addr] = isAllowed;
        emit IsTransferAllowedUpdated(addr, isAllowed);
    }

    /**
     * @dev It overrides ERC-1155's safeTransferFrom to block transfers between parties if none of them are whitelisted when transfer control is enabled.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 value,
        bytes memory data
    ) public virtual override {
        _isTransferAllowed(from, to);
        return super.safeTransferFrom(from, to, id, value, data);
    }

    /**
     * @dev It overrides ERC-1155's safeBatchTransferFrom to block transfers between parties if none of them are whitelisted when transfer control is enabled.
     */
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values,
        bytes memory data
    ) public virtual override {
        _isTransferAllowed(from, to);
        return super.safeBatchTransferFrom(from, to, ids, values, data);
    }

    function _isTransferAllowed(address from, address to) internal view {
        if (transferControlEnabled) {
            if (!isTransferAllowed[msg.sender]) {
                if (!isTransferAllowed[from]) {
                    if (!isTransferAllowed[to]) {
                        revert NotAllowedToTransfer();
                    }
                }
            }
        }
    }

    /*///////////////////////////////////////////////////////////////////
                            OVERRIDES
    //////////////////////////////////////////////////////////////////*/

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC1155, AccessControl) returns (bool) {
        return
            interfaceId == type(ERC1155).interfaceId ||
            interfaceId == type(AccessControl).interfaceId ||
            super.supportsInterface(interfaceId);
    }
}
