// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BondingCurve} from "./BondingCurve.sol";
import {MemeToken} from "./MemeToken.sol";

contract RobinoCurveDeployer {
    function deploy(MemeToken.Meta calldata meta, BondingCurve.Config calldata cfg) external returns (BondingCurve) {
        return new BondingCurve(meta, cfg);
    }
}
