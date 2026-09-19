// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

import {ERC1155TokenReceiver} from "solmate/src/tokens/ERC1155.sol";

import {Transfers} from "./mixins/Transfers.sol";

import {IExchange} from "./interfaces/IExchange.sol";
import {IFeeModuleV3} from "./interfaces/IFeeModuleV3.sol";

import {Order, Side} from "../Exchange/libraries/OrderStructs.sol";
import {CalculatorHelperV3} from "./libraries/CalculatorHelperV3.sol";

/**
 * @title CTF Fee Module V3
 * @notice Proxies the CTFExchange contract, refunds orders and distributes maker rebates + referral fees
 * @author predict.fun protocol team
 */
contract FeeModuleV3 is IFeeModuleV3, AccessControl, Transfers, ERC1155TokenReceiver {
    /**
     * @notice Role allowed to match orders
     */
    bytes32 public constant ORDERS_MATCHER_ROLE = keccak256("ORDERS_MATCHER_ROLE");

    /**
     * @notice Role allowed to withdraw fees
     */
    bytes32 public constant FEES_WITHDRAWER_ROLE = keccak256("FEES_WITHDRAWER_ROLE");

    /**
     * @notice The Exchange contract
     */
    IExchange public immutable exchange;

    /**
     * @notice The Collateral token
     */
    address public immutable collateral;

    /**
     * @notice The CTF contract
     */
    address public immutable ctf;

    /**
     * @param _exchange - The Exchange contract
     * @param _admin    - The admin address
     */
    constructor(address _exchange, address _admin) {
        exchange = IExchange(_exchange);
        collateral = exchange.getCollateral();
        ctf = exchange.getCtf();

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
    }

    /**
     * @notice Matches a taker order against a list of maker orders, refunding maker/taker order fees if necessary,
     *         distribute maker rebates and referral fee to the referrer
     * @param takerOrder           - The active order to be matched
     * @param makerOrders          - The array of maker orders to be matched against the active order
     * @param takerFillAmount      - The amount to fill on the taker order, always in terms of the maker amount
     * @param takerReceiveAmount   - The amount to that will be received by the taker order, always in terms of the taker amount
     * @param makerFillAmounts     - The array of amounts to fill on the maker orders, always in terms of the maker amount
     * @param takerFeeAmount       - The fee to be charged to the taker
     * @param makerFeeAmounts      - The fee to be charged to the maker orders
     * @param takerFeeDistribution - The taker fee distribution
     */
    function matchOrders(
        Order calldata takerOrder,
        Order[] calldata makerOrders,
        uint256 takerFillAmount,
        uint256 takerReceiveAmount,
        uint256[] calldata makerFillAmounts,
        uint256 takerFeeAmount,
        uint256[] calldata makerFeeAmounts,
        TakerFeeDistribution calldata takerFeeDistribution
    ) external onlyRole(ORDERS_MATCHER_ROLE) {
        uint256 makerOrdersLength = makerOrders.length;
        if (makerOrdersLength == 0) {
            revert MakerOrdersArrayLengthIsZero();
        }

        if (
            makerOrdersLength != makerFillAmounts.length ||
            makerOrdersLength != makerFeeAmounts.length ||
            makerOrdersLength != takerFeeDistribution.makerRebateAmounts.length
        ) {
            revert MakerArrayLengthsMismatch();
        }

        // Match the orders on the exchange
        exchange.matchOrders(takerOrder, makerOrders, takerFillAmount, makerFillAmounts);

        uint256 takerFeeTokenId = _refundTakerFees(takerOrder, takerFillAmount, takerReceiveAmount, takerFeeAmount);
        _distributeTakerFee(makerOrders, takerFeeDistribution, takerFeeTokenId, takerFeeAmount);

        _refundMakerFees(makerOrders, makerFillAmounts, makerFeeAmounts);
    }

    /**
     * @notice Withdraw collected fees
     * @param id     - The tokenID to be withdrawn. If 0, will be the collateral token.
     * @param amount - The amount to be withdrawn
     */
    function withdrawFees(address to, uint256 id, uint256 amount) external onlyRole(FEES_WITHDRAWER_ROLE) {
        address token = _getToken(id);
        _transfer(token, address(this), to, id, amount);
        emit FeeWithdrawn(token, to, id, amount);
    }

    /**
     * @notice Refund fees for the taker order
     * @param order         - The taker order
     * @param fillAmount    - The fill amount for the taker order
     * @param receiveAmount - The receive amount for the taker order
     * @param feeAmount     - The fee amount for the taker order
     */
    function _refundTakerFees(
        Order calldata order,
        uint256 fillAmount,
        uint256 receiveAmount,
        uint256 feeAmount
    ) internal returns (uint256 tokenId) {
        tokenId = order.side == Side.BUY ? order.tokenId : 0;
        uint256 refund = _calculateTakerRefund(order, fillAmount, receiveAmount, feeAmount);
        _refundFee(exchange.hashOrder(order), tokenId, order.maker, refund, feeAmount);
    }

    /**
     * @notice Distributes maker rebates
     * @param makerOrders          - The array of maker orders
     * @param takerFeeDistribution - The taker fee distribution
     * @param takerFeeTokenId      - The token ID of the taker fee
     * @param takerFeeAmount       - The fee to be charged to the taker
     */
    function _distributeTakerFee(
        Order[] calldata makerOrders,
        TakerFeeDistribution calldata takerFeeDistribution,
        uint256 takerFeeTokenId,
        uint256 takerFeeAmount
    ) internal {
        uint256 totalDistributionAmount;
        uint256 makerOrdersLength = makerOrders.length;

        uint256[] calldata makerRebateAmounts = takerFeeDistribution.makerRebateAmounts;
        for (uint256 i; i < makerOrdersLength; ++i) {
            totalDistributionAmount += makerRebateAmounts[i];
        }

        address referrer = takerFeeDistribution.referrer;
        uint256 referralAmount = takerFeeDistribution.referralAmount;
        if (referralAmount > 0) {
            if (referrer == address(0)) {
                revert ReferrerIsZeroAddress();
            }
            totalDistributionAmount += referralAmount;
        }

        if (totalDistributionAmount > takerFeeAmount) {
            revert TotalDistributionAmountMoreThanTakerFeeAmount();
        }

        for (uint256 i; i < makerOrdersLength; ++i) {
            Order calldata order = makerOrders[i];
            uint256 rebateAmount = makerRebateAmounts[i];
            if (rebateAmount > 0) {
                address maker = order.maker;
                _transfer(_getToken(takerFeeTokenId), address(this), maker, takerFeeTokenId, rebateAmount);
                emit MakerRebateDistributed(maker, takerFeeTokenId, rebateAmount);
            }
        }

        if (referralAmount > 0) {
            _transfer(_getToken(takerFeeTokenId), address(this), referrer, takerFeeTokenId, referralAmount);
            emit ReferralFeeDistributed(referrer, takerFeeTokenId, referralAmount);
        }
    }

    /**
     * @notice Refund fees for a set of maker orders
     * @param orders      - The array of maker orders
     * @param fillAmounts - The array of fill amounts for the maker orders
     * @param feeAmounts  - The array of fee amounts charged to the maker orders
     */
    function _refundMakerFees(
        Order[] calldata orders,
        uint256[] calldata fillAmounts,
        uint256[] calldata feeAmounts
    ) internal {
        for (uint256 i; i < orders.length; ++i) {
            Order calldata order = orders[i];
            _refundFee(
                exchange.hashOrder(order),
                order.side == Side.BUY ? order.tokenId : 0,
                order.maker,
                _calculateMakerRefund(order, fillAmounts[i], feeAmounts[i]),
                feeAmounts[i]
            );
        }
    }

    /**
     * @notice Calculates the refund for a taker order, if any
     * @dev The refund for the taker order is calculated using actual match price
     * @param order         - The order
     * @param fillAmount    - The fill amount for the order
     * @param receiveAmount - The receive amount for the order
     * @param feeAmount     - The fee amount for the order, chosen by the operator
     */
    function _calculateTakerRefund(
        Order calldata order,
        uint256 fillAmount,
        uint256 receiveAmount,
        uint256 feeAmount
    ) internal pure returns (uint256) {
        return
            CalculatorHelperV3.calculateRefund(
                order.feeRateBps,
                feeAmount,
                order.side == Side.BUY ? receiveAmount : fillAmount,
                fillAmount,
                receiveAmount,
                order.side
            );
    }

    /**
     * @notice Calculates the refund for a maker order
     * @param order      - The order
     * @param fillAmount - The fill amount for the order
     * @param feeAmount  - The fee amount for the order, chosen by the operator
     */
    function _calculateMakerRefund(
        Order calldata order,
        uint256 fillAmount,
        uint256 feeAmount
    ) internal pure returns (uint256) {
        // Calculate refund for the maker order, if any
        uint256 takingAmount = CalculatorHelperV3.calculateTakingAmount(
            fillAmount,
            order.makerAmount,
            order.takerAmount
        );
        return
            CalculatorHelperV3.calculateRefund(
                order.feeRateBps,
                feeAmount,
                order.side == Side.BUY ? takingAmount : fillAmount,
                order.makerAmount,
                order.takerAmount,
                order.side
            );
    }

    /**
     * @notice Refund the fee for an order, if necessary
     * @param orderHash - The hash of the order
     * @param id        - The token id of the asset being transferred. 0 if it is the collateral ERC20 asset.
     * @param to        - The destination address for the refund
     * @param refund    - The refund
     * @param feeAmount - The fee amount being charged
     */
    function _refundFee(bytes32 orderHash, uint256 id, address to, uint256 refund, uint256 feeAmount) internal {
        // If the refund is non-zero, transfer it to the order maker
        if (refund > 0) {
            _transfer(_getToken(id), address(this), to, id, refund);
            emit FeeRefunded(orderHash, to, id, refund, feeAmount);
        }
    }

    /**
     * @notice Gets the token address for a given token ID
     * @param id     - The token ID
     * @return token - The token address
     */
    function _getToken(uint256 id) internal view returns (address) {
        return id == 0 ? collateral : ctf;
    }
}
