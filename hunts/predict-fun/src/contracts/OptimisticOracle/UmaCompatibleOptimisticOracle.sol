// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

// NOTE: Our own logic
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";

/// forge-lint: disable-next-line(unaliased-plain-import)
import "./data-verification-mechanism/implementation/Constants.sol";

import {OptimisticOracleV2Interface} from "./interfaces/OptimisticOracleV2Interface.sol";

import {Lockable} from "./common/implementation/Lockable.sol";

// NOTE: Our own SafeMath library just for compatibility
library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        return a + b;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return a - b;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        return a * b;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return a / b;
    }
}

/**
 * @title UMA compatible Optimistic Oracle.
 * @author predict.fun protocol team
 */
contract UmaCompatibleOptimisticOracle is OptimisticOracleV2Interface, Lockable, Ownable2Step {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using Address for address;

    // Default liveness value for all price requests.
    uint256 public override defaultLiveness;

    // This is effectively the extra ancillary data to add ",ooRequester:0000000000000000000000000000000000000000".
    uint256 private constant MAX_ADDED_ANCILLARY_DATA = 53;
    uint256 public constant OO_ANCILLARY_DATA_LIMIT = ancillaryBytesLimit - MAX_ADDED_ANCILLARY_DATA;
    int256 public constant TOO_EARLY_RESPONSE = type(int256).min;

    // NOTE: Our custom logic
    // @dev Only whitelisted proposers can propose prices and they are not required to pay any bond
    mapping(address proposer => bool isWhitelisted) public isProposerWhitelisted;

    event UmaCompatibleOptimisticOracle__DefaultLivenessUpdated(uint256 liveness);
    event UmaCompatibleOptimisticOracle__ProposerWhitelisted(address indexed proposer, bool isWhitelisted);

    error UmaCompatibleOptimisticOracle__InvalidProposedPrice();
    error UmaCompatibleOptimisticOracle__NotImplemented();
    error UmaCompatibleOptimisticOracle__ProposerNotWhitelisted();
    error UmaCompatibleOptimisticOracle__RewardMustBeZero();

    /**
     * @notice Constructor.
     * @param _liveness default liveness applied to each price request.
     * @param _owner address of the owner of the contract.
     */
    constructor(uint256 _liveness, address _owner) Ownable(_owner) {
        _validateLiveness(_liveness);
        defaultLiveness = _liveness;
    }

    // NOTE: Our custom logic
    modifier onlyWhitelistedProposer() {
        if (!isProposerWhitelisted[msg.sender]) {
            revert UmaCompatibleOptimisticOracle__ProposerNotWhitelisted();
        }
        _;
    }

    // NOTE: Our custom logic
    /**
     * @notice Set the whitelist status of a proposer. Only the owner can call this function.
     * @param proposer address of the proposer to whitelist.
     * @param isWhitelisted true if the proposer should be whitelisted, false otherwise.
     */
    function whitelistProposer(address proposer, bool isWhitelisted) external onlyOwner {
        isProposerWhitelisted[proposer] = isWhitelisted;
        emit UmaCompatibleOptimisticOracle__ProposerWhitelisted(proposer, isWhitelisted);
    }

    // NOTE: Our custom logic
    /**
     * @notice Update the default liveness value for all price requests. Only the owner can call this function.
     * @param _liveness new default liveness value.
     */
    function updateDefaultLiveness(uint256 _liveness) external onlyOwner {
        _validateLiveness(_liveness);
        defaultLiveness = _liveness;
        emit UmaCompatibleOptimisticOracle__DefaultLivenessUpdated(_liveness);
    }

    /**
     * @notice Requests a new price.
     * @param identifier price identifier being requested.
     * @param timestamp timestamp of the price being requested.
     * @param ancillaryData ancillary data representing additional args being passed with the price request.
     * @param currency ERC20 token used for payment of rewards and fees. Must be approved for use with the DVM.
     * @param reward reward offered to a successful proposer. Will be pulled from the caller. Note: this can be 0,
     *               which could make sense if the contract requests and proposes the value in the same call or
     *               provides its own reward system.
     * @return totalBond default bond (final fee) + final fee that the proposer and disputer will be required to pay.
     * This can be changed with a subsequent call to setBond().
     */
    function requestPrice(
        bytes32 identifier,
        uint256 timestamp,
        bytes memory ancillaryData,
        IERC20 currency,
        uint256 reward
    ) external override nonReentrant returns (uint256 totalBond) {
        require(_getState(msg.sender, identifier, timestamp, ancillaryData) == State.Invalid, "requestPrice: Invalid");
        require(identifier == "YES_OR_NO_QUERY", "Unsupported identifier");
        require(timestamp <= getCurrentTime(), "Timestamp in future");

        // This ensures that the ancillary data is <= the OO limit, which is lower than the DVM limit because the
        // OO adds some data before sending to the DVM.
        require(ancillaryData.length <= OO_ANCILLARY_DATA_LIMIT, "Ancillary Data too long");

        uint256 finalFee = 0;

        requests[_getId(msg.sender, identifier, timestamp, ancillaryData)] = Request({
            proposer: address(0),
            disputer: address(0),
            currency: currency,
            settled: false,
            requestSettings: RequestSettings({
                eventBased: false,
                refundOnDispute: false,
                callbackOnPriceProposed: false,
                callbackOnPriceDisputed: false,
                callbackOnPriceSettled: false,
                bond: finalFee,
                customLiveness: 0
            }),
            proposedPrice: 0,
            resolvedPrice: 0,
            expirationTime: 0,
            reward: reward,
            finalFee: finalFee
        });

        if (reward > 0) {
            revert UmaCompatibleOptimisticOracle__RewardMustBeZero();
        }

        emit RequestPrice(msg.sender, identifier, timestamp, ancillaryData, address(currency), reward, finalFee);

        return 0;
    }

    /**
     * @dev Not implemented. Only maintaining the interface for compatibility. UmaCtfAdapter should never call this function as long as the proposal bond is 0.
     */
    function setBond(bytes32, uint256, bytes memory, uint256) external override nonReentrant returns (uint256) {
        revert UmaCompatibleOptimisticOracle__NotImplemented();
    }

    /**
     * @dev Not implemented. Only maintaining the interface for compatibility.
     */
    function setRefundOnDispute(bytes32, uint256, bytes memory) external override nonReentrant {
        revert UmaCompatibleOptimisticOracle__NotImplemented();
    }

    /**
     * @dev Not implemented. Only maintaining the interface for compatibility.
     */
    function setCustomLiveness(bytes32, uint256, bytes memory, uint256) external override nonReentrant {
        revert UmaCompatibleOptimisticOracle__NotImplemented();
    }

    /**
     * @notice Sets the request to be an "event-based" request.
     * @dev Calling this method has a few impacts on the request:
     *
     * 1. The timestamp at which the request is evaluated is the time of the proposal, not the timestamp associated
     *    with the request.
     *
     * 2. The proposer cannot propose the "too early" value (TOO_EARLY_RESPONSE). This is to ensure that a proposer who
     *    prematurely proposes a response loses their bond.
     *
     * 3. RefundoOnDispute is automatically set, meaning disputes trigger the reward to be automatically refunded to
     *    the requesting contract.
     *
     * @param identifier price identifier to identify the existing request.
     * @param timestamp timestamp to identify the existing request.
     * @param ancillaryData ancillary data of the price being requested.
     */
    function setEventBased(
        bytes32 identifier,
        uint256 timestamp,
        bytes memory ancillaryData
    ) external override nonReentrant {
        require(
            _getState(msg.sender, identifier, timestamp, ancillaryData) == State.Requested,
            "setEventBased: Requested"
        );
        Request storage request = _getRequest(msg.sender, identifier, timestamp, ancillaryData);
        request.requestSettings.eventBased = true;
        request.requestSettings.refundOnDispute = true;
    }

    /**
     * @dev Not implemented. Only maintaining the interface for compatibility.
     */
    function setCallbacks(
        bytes32 /* identifier */,
        uint256 /* timestamp */,
        bytes memory /* ancillaryData */,
        bool /* callbackOnPriceProposed */,
        bool /* callbackOnPriceDisputed */,
        bool /* callbackOnPriceSettled */
    ) external override nonReentrant {
        revert UmaCompatibleOptimisticOracle__NotImplemented();
    }

    /**
     * @dev Only whitelisted proposers can propose prices.
     * @notice Proposes a price value on another address' behalf. Note: this address will receive any rewards that come
     * from this proposal. However, any bonds are pulled from the caller.
     * @param proposer address to set as the proposer.
     * @param requester sender of the initial price request.
     * @param identifier price identifier to identify the existing request.
     * @param timestamp timestamp to identify the existing request.
     * @param ancillaryData ancillary data of the price being requested.
     * @param proposedPrice price being proposed.
     * @return This is supposed to return the total bond, but we hard code it to 0 because we don't support bonds.
     */
    function proposePriceFor(
        address proposer,
        address requester,
        bytes32 identifier,
        uint256 timestamp,
        bytes memory ancillaryData,
        int256 proposedPrice
    ) public override nonReentrant onlyWhitelistedProposer returns (uint256) {
        // NOTE: We only allow 0, 0.5 and 1 as proposed prices
        if (proposedPrice != 0 && proposedPrice != 0.5 ether && proposedPrice != 1 ether) {
            revert UmaCompatibleOptimisticOracle__InvalidProposedPrice();
        }

        require(proposer != address(0), "proposer address must be non 0");
        require(
            _getState(requester, identifier, timestamp, ancillaryData) == State.Requested,
            "proposePriceFor: Requested"
        );
        Request storage request = _getRequest(requester, identifier, timestamp, ancillaryData);
        if (request.requestSettings.eventBased) {
            require(proposedPrice != TOO_EARLY_RESPONSE, "Cannot propose 'too early'");
        }
        request.proposer = proposer;
        request.proposedPrice = proposedPrice;

        // If a custom liveness has been set, use it instead of the default.
        request.expirationTime = getCurrentTime().add(
            request.requestSettings.customLiveness != 0 ? request.requestSettings.customLiveness : defaultLiveness
        );

        emit ProposePrice(
            requester,
            proposer,
            identifier,
            timestamp,
            ancillaryData,
            proposedPrice,
            request.expirationTime,
            address(request.currency)
        );

        return 0;
    }

    /**
     * @dev Only whitelisted proposers can propose prices, checked in proposePriceFor.
     * @notice Proposes a price value for an existing price request.
     * @param requester sender of the initial price request.
     * @param identifier price identifier to identify the existing request.
     * @param timestamp timestamp to identify the existing request.
     * @param ancillaryData ancillary data of the price being requested.
     * @param proposedPrice price being proposed.
     * @return totalBond the amount that's pulled from the proposer's wallet as a bond. The bond will be returned to
     * the proposer once settled if the proposal is correct.
     */
    function proposePrice(
        address requester,
        bytes32 identifier,
        uint256 timestamp,
        bytes memory ancillaryData,
        int256 proposedPrice
    ) external override returns (uint256 totalBond) {
        // Note: re-entrancy guard is done in the inner call.
        return proposePriceFor(msg.sender, requester, identifier, timestamp, ancillaryData, proposedPrice);
    }

    /**
     * @dev Not implemented. Only maintaining the interface for compatibility.
     */
    function disputePriceFor(
        address,
        address,
        bytes32,
        uint256,
        bytes memory
    ) public override nonReentrant returns (uint256) {
        revert UmaCompatibleOptimisticOracle__NotImplemented();
    }

    /**
     * @dev Not implemented. Only maintaining the interface for compatibility.
     */
    function disputePrice(address, bytes32, uint256, bytes memory) external pure override returns (uint256) {
        revert UmaCompatibleOptimisticOracle__NotImplemented();
    }

    /**
     * @notice Retrieves a price that was previously requested by a caller. Reverts if the request is not settled
     * or settleable. Note: this method is not view so that this call may actually settle the price request if it
     * hasn't been settled.
     * @param identifier price identifier to identify the existing request.
     * @param timestamp timestamp to identify the existing request.
     * @param ancillaryData ancillary data of the price being requested.
     * @return resolved price.
     */
    function settleAndGetPrice(
        bytes32 identifier,
        uint256 timestamp,
        bytes memory ancillaryData
    ) external override nonReentrant returns (int256) {
        if (_getState(msg.sender, identifier, timestamp, ancillaryData) != State.Settled) {
            _settle(msg.sender, identifier, timestamp, ancillaryData);
        }

        return _getRequest(msg.sender, identifier, timestamp, ancillaryData).resolvedPrice;
    }

    /**
     * @notice Attempts to settle an outstanding price request. Will revert if it isn't settleable.
     * @param requester sender of the initial price request.
     * @param identifier price identifier to identify the existing request.
     * @param timestamp timestamp to identify the existing request.
     * @param ancillaryData ancillary data of the price being requested.
     * @return payout the amount that the "winner" (proposer or disputer) receives on settlement. This amount includes
     * the returned bonds as well as additional rewards.
     */
    function settle(
        address requester,
        bytes32 identifier,
        uint256 timestamp,
        bytes memory ancillaryData
    ) external override nonReentrant returns (uint256 payout) {
        return _settle(requester, identifier, timestamp, ancillaryData);
    }

    /**
     * @notice Gets the current data structure containing all information about a price request.
     * @param requester sender of the initial price request.
     * @param identifier price identifier to identify the existing request.
     * @param timestamp timestamp to identify the existing request.
     * @param ancillaryData ancillary data of the price being requested.
     * @return the Request data structure.
     */
    function getRequest(
        address requester,
        bytes32 identifier,
        uint256 timestamp,
        bytes memory ancillaryData
    ) public view override nonReentrantView returns (Request memory) {
        return _getRequest(requester, identifier, timestamp, ancillaryData);
    }

    /**
     * @notice Computes the current state of a price request. See the State enum for more details.
     * @param requester sender of the initial price request.
     * @param identifier price identifier to identify the existing request.
     * @param timestamp timestamp to identify the existing request.
     * @param ancillaryData ancillary data of the price being requested.
     * @return the State.
     */
    function getState(
        address requester,
        bytes32 identifier,
        uint256 timestamp,
        bytes memory ancillaryData
    ) public view override nonReentrantView returns (State) {
        return _getState(requester, identifier, timestamp, ancillaryData);
    }

    /**
     * @notice Checks if a given request has resolved, expired or been settled (i.e the optimistic oracle has a price).
     * @param requester sender of the initial price request.
     * @param identifier price identifier to identify the existing request.
     * @param timestamp timestamp to identify the existing request.
     * @param ancillaryData ancillary data of the price being requested.
     * @return boolean indicating true if price exists and false if not.
     */
    function hasPrice(
        address requester,
        bytes32 identifier,
        uint256 timestamp,
        bytes memory ancillaryData
    ) public view override nonReentrantView returns (bool) {
        State state = _getState(requester, identifier, timestamp, ancillaryData);
        return state == State.Settled || state == State.Resolved || state == State.Expired;
    }

    /**
     * @dev Not implemented. Only maintaining the interface for compatibility.
     */
    function stampAncillaryData(bytes memory, address) public pure override returns (bytes memory) {
        revert UmaCompatibleOptimisticOracle__NotImplemented();
    }

    function _getId(
        address requester,
        bytes32 identifier,
        uint256 timestamp,
        bytes memory ancillaryData
    ) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(requester, identifier, timestamp, ancillaryData));
    }

    function _settle(
        address requester,
        bytes32 identifier,
        uint256 timestamp,
        bytes memory ancillaryData
    ) private returns (uint256 payout) {
        State state = _getState(requester, identifier, timestamp, ancillaryData);

        // Set it to settled so this function can never be entered again.
        Request storage request = _getRequest(requester, identifier, timestamp, ancillaryData);
        request.settled = true;

        if (state == State.Expired) {
            // In the expiry case, just pay back the proposer's bond and final fee along with the reward.
            request.resolvedPrice = request.proposedPrice;
        } else {
            revert("_settle: not settleable");
        }

        emit Settle(
            requester,
            request.proposer,
            request.disputer,
            identifier,
            timestamp,
            ancillaryData,
            request.resolvedPrice,
            payout
        );
    }

    function _getRequest(
        address requester,
        bytes32 identifier,
        uint256 timestamp,
        bytes memory ancillaryData
    ) private view returns (Request storage) {
        return requests[_getId(requester, identifier, timestamp, ancillaryData)];
    }

    function _validateLiveness(uint256 _liveness) private pure {
        require(_liveness < 5200 weeks, "Liveness too large");
    }

    function _getState(
        address requester,
        bytes32 identifier,
        uint256 timestamp,
        bytes memory ancillaryData
    ) internal view returns (State) {
        Request storage request = _getRequest(requester, identifier, timestamp, ancillaryData);

        if (address(request.currency) == address(0)) return State.Invalid;

        if (request.proposer == address(0)) return State.Requested;

        if (request.settled) return State.Settled;

        // NOTE: We don't support disputes, so we don't need to check if the request's disputer is 0
        return request.expirationTime <= getCurrentTime() ? State.Expired : State.Proposed;
    }

    function getCurrentTime() public view override(OptimisticOracleV2Interface) returns (uint256) {
        return block.timestamp;
    }
}
