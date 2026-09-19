// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.28;

import {ISpectra} from "./interfaces/ISpectra.sol";
import {AccessManagedUpgradeable} from "@openzeppelin-upgradeable/contracts/access/manager/AccessManagedUpgradeable.sol";
import {ERC20Upgradeable} from "@openzeppelin-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";
import {ERC20PermitUpgradeable} from "@openzeppelin-upgradeable/contracts/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {ERC20BurnableUpgradeable} from "@openzeppelin-upgradeable/contracts/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";

/// @title Spectra Token
/// @author spectra.finance
contract Spectra is ISpectra, ERC20PermitUpgradeable, AccessManagedUpgradeable, ERC20BurnableUpgradeable {
    constructor() {
        _disableInitializers();
    }

    function initialize(address _initialAuthority) public initializer {
        __ERC20_init("Spectra Token", "SPECTRA");
        __ERC20Permit_init("Spectra Token");
        __AccessManaged_init(_initialAuthority);
        __ERC20Burnable_init();
    }

    function mint(address account, uint256 amount) external restricted returns (bool) {
        _mint(account, amount);
        return true;
    }
}
