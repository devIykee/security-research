// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Order} from "../../Exchange/libraries/OrderStructs.sol";

interface IFeeModuleV3 {
    /**
     * @notice Passed by operators on order matching for taker fee distribution
     * @param makerRebateAmounts - The array of maker rebate amounts
     * @param referrer           - The referrer address, must not be 0 if referralAmount > 0
     * @param referralAmount     - The amount to be distributed to the referrer
     */
    struct TakerFeeDistribution {
        uint256[] makerRebateAmounts;
        address referrer;
        uint256 referralAmount;
    }

    /**
     * @notice Emitted when fees are withdrawn from the FeeModule
     * @param token  - The token address
     * @param to     - The destination address
     * @param id     - The token ID
     * @param amount - The amount to be withdrawn
     */
    event FeeWithdrawn(address token, address to, uint256 id, uint256 amount);

    /**
     * @notice Emitted when fees are refunded to the order maker
     * @param orderHash    - The hash of the order
     * @param to           - The destination address
     * @param id           - The token ID
     * @param refund       - The refund
     * @param feeCharged   - The fee amount being charged
     */
    event FeeRefunded(bytes32 indexed orderHash, address indexed to, uint256 id, uint256 refund, uint256 feeCharged);

    /**
     * @notice Emitted when the maker rebate is distributed
     * @param maker           - The maker address
     * @param takerFeeTokenId - The token ID of the taker fee
     * @param rebateAmount    - The rebate amount
     */
    event MakerRebateDistributed(address indexed maker, uint256 indexed takerFeeTokenId, uint256 rebateAmount);

    /**
     * @notice Emitted when the referral fee is distributed
     * @param referrer        - The referrer address
     * @param takerFeeTokenId - The token ID of the taker fee
     * @param amount          - The amount to be distributed
     */
    event ReferralFeeDistributed(address indexed referrer, uint256 indexed takerFeeTokenId, uint256 amount);

    /**
     * @notice Error thrown when the total distribution amount is greater than the taker fee amount
     */
    error TotalDistributionAmountMoreThanTakerFeeAmount();

    /**
     * @notice Error thrown when the maker orders array length is zero
     */
    error MakerOrdersArrayLengthIsZero();

    /**
     * @notice Error thrown when the maker array lengths are not equal
     */
    error MakerArrayLengthsMismatch();

    /**
     * @notice Error thrown when the referrer is a zero address
     */
    error ReferrerIsZeroAddress();
}
