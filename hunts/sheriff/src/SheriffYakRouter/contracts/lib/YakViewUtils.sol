// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.8.4;

import {Offer, FormattedOffer} from "contracts/interface/IYakRouter.sol";
import {TypeConversion} from "contracts/lib/TypeConversion.sol";

library OfferUtils {
    using TypeConversion for address;
    using TypeConversion for uint256;
    using TypeConversion for bytes;

    uint256 public constant SLOT_LENGTH = 32; // Storage slot length in bytes

    function newOffer(uint256 _amount, address _token) internal pure returns (Offer memory offer) {
        offer.amounts = _amount.toBytes();
        offer.path = _token.toBytes();
    }

    /**
     * Makes a deep copy of Offer struct
     */
    function clone(Offer memory _queries) internal pure returns (Offer memory) {
        return Offer(_queries.amounts, _queries.adapters, _queries.path, _queries.recipients, _queries.deployers);
    }

    /**
     * Appends new elements to the top of Offer struct
     */
    function addToHead(
        Offer memory _queries,
        uint256 _amount,
        address _adapter,
        address _recipient,
        address _token
    ) internal pure {
        _queries.path = bytes.concat(_token.toBytes(), _queries.path);
        _queries.adapters = bytes.concat(_adapter.toBytes(), _queries.adapters);
        _queries.amounts = bytes.concat(_amount.toBytes(), _queries.amounts);
        _queries.recipients = bytes.concat(_recipient.toBytes(), _queries.recipients);
        _queries.deployers = bytes.concat(address(0).toBytes(), _queries.deployers);
    }

    function addToHead(
        Offer memory _queries,
        uint256 _amount,
        address _adapter,
        address _recipient,
        address _token,
        address _deployer
    ) internal pure {
        _queries.path = bytes.concat(_token.toBytes(), _queries.path);
        _queries.adapters = bytes.concat(_adapter.toBytes(), _queries.adapters);
        _queries.amounts = bytes.concat(_amount.toBytes(), _queries.amounts);
        _queries.recipients = bytes.concat(_recipient.toBytes(), _queries.recipients);
        _queries.deployers = bytes.concat(_deployer.toBytes(), _queries.deployers);
    }

    /**
     * Appends new elements to the end of Offer struct
     */
    function addToTail(
        Offer memory _queries,
        uint256 _amount,
        address _adapter,
        address _recipient,
        address _token
    ) internal pure {
        _queries.path = bytes.concat(_queries.path, _token.toBytes());
        _queries.adapters = bytes.concat(_queries.adapters, _adapter.toBytes());
        _queries.amounts = bytes.concat(_queries.amounts, _amount.toBytes());
        _queries.recipients = bytes.concat(_queries.recipients, _recipient.toBytes());
        _queries.deployers = bytes.concat(_queries.deployers, address(0).toBytes());
    }

    function addToTail(
        Offer memory _queries,
        uint256 _amount,
        address _adapter,
        address _recipient,
        address _token,
        address _deployer
    ) internal pure {
        _queries.path = bytes.concat(_queries.path, _token.toBytes());
        _queries.adapters = bytes.concat(_queries.adapters, _adapter.toBytes());
        _queries.amounts = bytes.concat(_queries.amounts, _amount.toBytes());
        _queries.recipients = bytes.concat(_queries.recipients, _recipient.toBytes());
        _queries.deployers = bytes.concat(_queries.deployers, _deployer.toBytes());
    }

    /**
     * Formats elements in the Offer object from byte-arrays to integers and addresses
     */
    function format(Offer memory _queries) internal pure returns (FormattedOffer memory) {
        return FormattedOffer(
            _queries.amounts.toUints(),
            _queries.adapters.toAddresses(),
            _queries.path.toAddresses(),
            _queries.recipients.toAddresses(),
            _queries.deployers.toAddresses()
        );
    }

    function getTokenOut(Offer memory _offer) internal pure returns (address tokenOut) {
        tokenOut = _offer.path.toAddress(_offer.path.length); // Last SLOT_LENGTH bytes
    }

    function getTokenIn(Offer memory _offer) internal pure returns (address tokenIn) {
        tokenIn = _offer.path.toAddress(SLOT_LENGTH); // First SLOT_LENGTH bytes
    }

    function getAmountOut(Offer memory _offer) internal pure returns (uint256 amount) {
        amount = _offer.amounts.toUint(_offer.amounts.length); // Last SLOT_LENGTH bytes
    }

    function getAmountIn(Offer memory _offer) internal pure returns (uint256 amount) {
        amount = _offer.amounts.toUint(SLOT_LENGTH); // First SLOT_LENGTH bytes
    }
}

library FormattedOfferUtils {
    using TypeConversion for address;
    using TypeConversion for uint256;
    using TypeConversion for bytes;

    /**
     * Appends new elements to the end of FormattedOffer
     */
    function addToTail(
        FormattedOffer memory offer,
        uint256 amount,
        address wrapper,
        address token,
        address recipient
    ) internal pure {
        offer.amounts = bytes.concat(abi.encodePacked(offer.amounts), amount.toBytes()).toUints();
        offer.adapters =
            bytes.concat(abi.encodePacked(offer.adapters), wrapper.toBytes()).toAddresses();
        offer.path = bytes.concat(abi.encodePacked(offer.path), token.toBytes()).toAddresses();
        offer.recipients =
            bytes.concat(abi.encodePacked(offer.recipients), recipient.toBytes()).toAddresses();
        offer.deployers =
            bytes.concat(abi.encodePacked(offer.deployers), address(0).toBytes()).toAddresses();
    }

    function addToTail(
        FormattedOffer memory offer,
        uint256 amount,
        address wrapper,
        address token,
        address recipient,
        address deployer
    ) internal pure {
        offer.amounts = bytes.concat(abi.encodePacked(offer.amounts), amount.toBytes()).toUints();
        offer.adapters =
            bytes.concat(abi.encodePacked(offer.adapters), wrapper.toBytes()).toAddresses();
        offer.path = bytes.concat(abi.encodePacked(offer.path), token.toBytes()).toAddresses();
        offer.recipients =
            bytes.concat(abi.encodePacked(offer.recipients), recipient.toBytes()).toAddresses();
        offer.deployers =
            bytes.concat(abi.encodePacked(offer.deployers), deployer.toBytes()).toAddresses();
    }

    /**
     * Appends new elements to the beginning of FormattedOffer
     */
    function addToHead(
        FormattedOffer memory offer,
        uint256 amount,
        address wrapper,
        address token,
        address recipient
    ) internal pure {
        offer.amounts = bytes.concat(amount.toBytes(), abi.encodePacked(offer.amounts)).toUints();
        offer.adapters =
            bytes.concat(wrapper.toBytes(), abi.encodePacked(offer.adapters)).toAddresses();
        offer.path = bytes.concat(token.toBytes(), abi.encodePacked(offer.path)).toAddresses();
        offer.recipients =
            bytes.concat(recipient.toBytes(), abi.encodePacked(offer.recipients)).toAddresses();
        offer.deployers =
            bytes.concat(address(0).toBytes(), abi.encodePacked(offer.deployers)).toAddresses();
    }

    function addToHead(
        FormattedOffer memory offer,
        uint256 amount,
        address wrapper,
        address token,
        address recipient,
        address deployer
    ) internal pure {
        offer.amounts = bytes.concat(amount.toBytes(), abi.encodePacked(offer.amounts)).toUints();
        offer.adapters =
            bytes.concat(wrapper.toBytes(), abi.encodePacked(offer.adapters)).toAddresses();
        offer.path = bytes.concat(token.toBytes(), abi.encodePacked(offer.path)).toAddresses();
        offer.recipients =
            bytes.concat(recipient.toBytes(), abi.encodePacked(offer.recipients)).toAddresses();
        offer.deployers =
            bytes.concat(deployer.toBytes(), abi.encodePacked(offer.deployers)).toAddresses();
    }

    function getAmountOut(FormattedOffer memory offer) internal pure returns (uint256) {
        return offer.amounts[offer.amounts.length - 1];
    }
}
