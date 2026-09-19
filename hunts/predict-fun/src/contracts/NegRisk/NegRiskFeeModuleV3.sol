// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {FeeModuleV3} from "../ExchangeFee/FeeModuleV3.sol";
import {IConditionalTokens} from "./interfaces/IConditionalTokens.sol";

/// @title NegRiskFeeModuleV3
/// @notice FeeModuleV3 with neg risk support
/// @author predict.fun protocol team
contract NegRiskFeeModuleV3 is FeeModuleV3 {
    constructor(
        address _negRiskCtfExchange,
        address _negRiskAdapter,
        address _ctf,
        address _admin
    ) FeeModuleV3(_negRiskCtfExchange, _admin) {
        IConditionalTokens(_ctf).setApprovalForAll(_negRiskAdapter, true);
        IConditionalTokens(_ctf).setApprovalForAll(address(this), true);
    }
}
