// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Auth} from "./mixins/Auth.sol";
import {BulletinBoard} from "./mixins/BulletinBoard.sol";

import {PayoutHelperLib} from "./libraries/PayoutHelperLib.sol";
import {AncillaryDataLib} from "./libraries/AncillaryDataLib.sol";

import {IConditionalTokens} from "./interfaces/IConditionalTokens.sol";
import {IOptimisticOracleV2} from "./interfaces/IOptimisticOracleV2.sol";

import {QuestionData, IUmaCtfAdapter} from "./interfaces/IUmaCtfAdapter.sol";

/// @title UmaCompatibleCtfAdapter
/// @notice Enables resolution of CTF markets via our own Optimistic Oracle implementation
/// @author predict.fun protocol team
contract UmaCompatibleCtfAdapter is IUmaCtfAdapter, Auth, BulletinBoard {
    /*///////////////////////////////////////////////////////////////////
                            IMMUTABLES
    //////////////////////////////////////////////////////////////////*/

    /// @notice Conditional Tokens Framework
    IConditionalTokens public immutable ctf;

    /// @notice Optimistic Oracle
    IOptimisticOracleV2 public immutable optimisticOracle;

    /// @notice Time period after which an admin can emergency resolve a condition
    uint256 public constant EMERGENCY_SAFETY_PERIOD = 2 days;

    /// @notice Unique query identifier for the Optimistic Oracle
    /// From UMIP-107
    bytes32 public constant YES_OR_NO_IDENTIFIER = "YES_OR_NO_QUERY";

    /// @notice Maximum ancillary data length
    /// From OOV2 function OO_ANCILLARY_DATA_LIMIT
    uint256 public constant MAX_ANCILLARY_DATA = 8139;

    /// @notice Mapping of questionID to QuestionData
    mapping(bytes32 => QuestionData) public questions;

    /**
     * @notice Mapping of requestor to whitelisted status. Only whitelisted requestors can create markets
     */
    mapping(address requestor => bool isWhitelisted) public isRequestorWhitelisted;

    /**
     * @notice Emitted when a requestor is whitelisted or removed from the whitelist
     * @param requestor - The requestor address
     * @param isWhitelisted - The whitelisted status
     */
    event RequestorWhitelisted(address indexed requestor, bool isWhitelisted);

    error UmaCompatibleCtfAdapter__NotWhitelistedRequestor();
    error UmaCompatibleCtfAdapter__LivenessMustBeZero();
    error UmaCompatibleCtfAdapter__NotImplemented();
    error UmaCompatibleCtfAdapter__ProposalBondMustBeZero();
    error UmaCompatibleCtfAdapter__RewardMustBeZero();

    modifier onlyOptimisticOracle() {
        if (msg.sender != address(optimisticOracle)) revert NotOptimisticOracle();
        _;
    }

    modifier onlyWhitelistedRequestor() {
        if (!isRequestorWhitelisted[msg.sender]) revert UmaCompatibleCtfAdapter__NotWhitelistedRequestor();
        _;
    }

    /// @param _ctf     - The Conditional Token Framework Address
    ///                 - When deployed for negative risk markets, this should be the `NegRiskOperator` contract address
    /// @param _optimisticOracle - Our own OptimisticOracleV2 Address
    constructor(address _ctf, address _optimisticOracle) {
        ctf = IConditionalTokens(_ctf);
        optimisticOracle = IOptimisticOracleV2(_optimisticOracle);
    }

    /*///////////////////////////////////////////////////////////////////
                            PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////////*/

    /// @notice Initializes a question
    /// Atomically adds the question to the Adapter, prepares it on the ConditionalTokens Framework and requests a price from the OO.
    /// If a reward is provided, the caller must have approved the Adapter as spender and have enough rewardToken
    /// to pay for the price request.
    /// Prepares the condition using the Adapter as the oracle and a fixed outcome slot count = 2.
    /// @param ancillaryData - Data used to resolve a question
    /// @param rewardToken   - It must be set to 0x000000000000000000000000000000000000dEaD. We only keep it for compatibility with the UmaCtfAdapter.
    /// @param reward        - It must be set to 0. We only keep it for compatibility with UmaCtfAdapter.
    /// @param proposalBond  - It must be set to 0. We only keep it for compatibility with UmaCtfAdapter.
    /// @param liveness      - It must be set to 0. We only keep it for compatibility with UmaCtfAdapter.
    function initialize(
        bytes memory ancillaryData,
        address rewardToken,
        uint256 reward,
        uint256 proposalBond,
        uint256 liveness
    ) external onlyWhitelistedRequestor returns (bytes32 questionID) {
        // NOTE: rewardToken is not used in our custom OptimisticOracleV2, but we are keeping it nonzero to
        // be compatible with the line `if (address(request.currency) == address(0)) return State.Invalid;`
        if (rewardToken != address(0x000000000000000000000000000000000000dEaD)) {
            revert UnsupportedToken();
        }

        if (reward > 0) {
            revert UmaCompatibleCtfAdapter__RewardMustBeZero();
        }

        if (proposalBond > 0) {
            revert UmaCompatibleCtfAdapter__ProposalBondMustBeZero();
        }

        if (liveness > 0) {
            revert UmaCompatibleCtfAdapter__LivenessMustBeZero();
        }

        bytes memory data = AncillaryDataLib._appendAncillaryData(msg.sender, ancillaryData);
        if (ancillaryData.length == 0 || data.length > MAX_ANCILLARY_DATA) revert InvalidAncillaryData();

        questionID = keccak256(data);

        if (_isInitialized(questions[questionID])) revert Initialized();

        uint256 timestamp = block.timestamp;

        // Persist the question parameters in storage
        _saveQuestion(msg.sender, questionID, data, timestamp, rewardToken, reward, proposalBond, liveness);

        // Prepare the question on the CTF
        ctf.prepareCondition(questionID, 2);

        // Request a price for the question from the OO
        _requestPrice(timestamp, data, rewardToken, reward);

        emit QuestionInitialized(questionID, timestamp, msg.sender, data, rewardToken, reward, proposalBond);
    }

    /// @notice Checks whether a questionID is ready to be resolved
    /// @param questionID - The unique questionID
    function ready(bytes32 questionID) public view returns (bool) {
        return _ready(questions[questionID]);
    }

    /// @notice Resolves a question
    /// Pulls price information from the OO and resolves the underlying CTF market.
    /// Reverts if price is not available on the OO
    /// Resets the question if the price returned by the OO is the Ignore price
    /// @param questionID - The unique questionID of the question
    function resolve(bytes32 questionID) external onlyWhitelistedRequestor {
        QuestionData storage questionData = questions[questionID];

        if (!_isInitialized(questionData)) revert NotInitialized();
        if (questionData.resolved) revert Resolved();
        if (!_hasPrice(questionData)) revert NotReadyToResolve();

        // Resolve the underlying market
        return _resolve(questionID, questionData);
    }

    /// @notice Retrieves the expected payout array of the question
    /// @param questionID - The unique questionID of the question
    function getExpectedPayouts(bytes32 questionID) public view returns (uint256[] memory) {
        QuestionData storage questionData = questions[questionID];

        if (!_isInitialized(questionData)) revert NotInitialized();

        if (!_hasPrice(questionData)) revert PriceNotAvailable();

        // Fetches price from OO
        int256 price = optimisticOracle
            .getRequest(address(this), YES_OR_NO_IDENTIFIER, questionData.requestTimestamp, questionData.ancillaryData)
            .resolvedPrice;

        return _constructPayouts(price);
    }

    /// @notice Checks if a question is initialized
    /// @param questionID - The unique questionID
    function isInitialized(bytes32 questionID) public view returns (bool) {
        return _isInitialized(questions[questionID]);
    }

    /**
     * @dev Not implemented. Only maintaining the interface for compatibility.
     */
    function isFlagged(bytes32 /* questionID */) public pure returns (bool) {
        revert UmaCompatibleCtfAdapter__NotImplemented();
    }

    /// @notice Gets the QuestionData for the given questionID
    /// @param questionID - The unique questionID
    function getQuestion(bytes32 questionID) external view returns (QuestionData memory) {
        return questions[questionID];
    }

    /*////////////////////////////////////////////////////////////////////
                            ADMIN ONLY FUNCTIONS
    ///////////////////////////////////////////////////////////////////*/

    /**
     * @dev Not implemented. Only maintaining the interface for compatibility.
     */
    function flag(bytes32 /* questionID */) external pure {
        revert UmaCompatibleCtfAdapter__NotImplemented();
    }

    /**
     * @dev Not implemented. Only maintaining the interface for compatibility.
     */
    function unflag(bytes32 /* questionID */) external pure {
        revert UmaCompatibleCtfAdapter__NotImplemented();
    }

    /// @notice There is no reset functionality in our custom UmaCompatibleCtfAdapter as there are no disputes.
    function reset(bytes32 /* questionID */) external pure {
        revert UmaCompatibleCtfAdapter__NotImplemented();
    }

    /// @notice Allows an admin to resolve a CTF market in an emergency
    /// @param questionID   - The unique questionID of the question
    /// @param payouts      - Array of position payouts for the referenced question
    function emergencyResolve(bytes32 questionID, uint256[] calldata payouts) external onlyAdmin {
        QuestionData storage questionData = questions[questionID];

        if (!_isValidPayoutArray(payouts)) revert InvalidPayouts();
        if (!_isInitialized(questionData)) revert NotInitialized();

        questionData.resolved = true;

        ctf.reportPayouts(questionID, payouts);
        emit QuestionEmergencyResolved(questionID, payouts);
    }
    /**
     * @dev Not implemented. Only maintaining the interface for compatibility.
     */
    function pause(bytes32 /* questionID */) external pure {
        revert UmaCompatibleCtfAdapter__NotImplemented();
    }

    /**
     * @dev Not implemented. Only maintaining the interface for compatibility.
     */
    function unpause(bytes32 /* questionID */) external pure {
        revert UmaCompatibleCtfAdapter__NotImplemented();
    }

    /// @notice Add or remove a requestor from the whitelist. Only the admin can call this function.
    /// @param requestor - The requestor address
    /// @param isWhitelisted - The whitelisted status
    function whitelistRequestor(address requestor, bool isWhitelisted) external onlyAdmin {
        isRequestorWhitelisted[requestor] = isWhitelisted;
        emit RequestorWhitelisted(requestor, isWhitelisted);
    }

    /*///////////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////////*/

    function _ready(QuestionData storage questionData) internal view returns (bool) {
        if (!_isInitialized(questionData)) return false;
        if (questionData.resolved) return false;
        return _hasPrice(questionData);
    }

    function _saveQuestion(
        address creator,
        bytes32 questionID,
        bytes memory ancillaryData,
        uint256 requestTimestamp,
        address rewardToken,
        uint256 reward,
        uint256 proposalBond,
        uint256 liveness
    ) internal {
        questions[questionID] = QuestionData({
            requestTimestamp: requestTimestamp,
            reward: reward,
            proposalBond: proposalBond,
            liveness: liveness,
            emergencyResolutionTimestamp: 0,
            resolved: false,
            paused: false,
            reset: false,
            refund: false,
            rewardToken: rewardToken,
            creator: creator,
            ancillaryData: ancillaryData
        });
    }

    /// @notice Request a price from the Optimistic Oracle
    /// Transfers reward token from the requestor if non-zero reward is specified
    /// @param requestTimestamp - Timestamp used in the OO request
    /// @param ancillaryData    - Data used to resolve a question
    /// @param rewardToken      - Address of the reward token
    /// @param reward           - Reward amount, denominated in rewardToken
    function _requestPrice(
        uint256 requestTimestamp,
        bytes memory ancillaryData,
        address rewardToken,
        uint256 reward
    ) internal {
        // Send a price request to the Optimistic oracle
        optimisticOracle.requestPrice(
            YES_OR_NO_IDENTIFIER,
            requestTimestamp,
            ancillaryData,
            IERC20(rewardToken),
            reward
        );

        // Ensure the price request is event based
        optimisticOracle.setEventBased(YES_OR_NO_IDENTIFIER, requestTimestamp, ancillaryData);
    }

    /// @notice Resolves the underlying CTF market
    /// @param questionID   - The unique questionID of the question
    /// @param questionData - The question data parameters
    function _resolve(bytes32 questionID, QuestionData storage questionData) internal {
        // Get the price from the OO
        int256 price = optimisticOracle.settleAndGetPrice(
            YES_OR_NO_IDENTIFIER,
            questionData.requestTimestamp,
            questionData.ancillaryData
        );

        // Set resolved flag
        questionData.resolved = true;

        // Construct the payout array for the question
        uint256[] memory payouts = _constructPayouts(price);

        // Resolve the underlying CTF market
        ctf.reportPayouts(questionID, payouts);

        emit QuestionResolved(questionID, price, payouts);
    }

    function _hasPrice(QuestionData storage questionData) internal view returns (bool) {
        return
            optimisticOracle.hasPrice(
                address(this),
                YES_OR_NO_IDENTIFIER,
                questionData.requestTimestamp,
                questionData.ancillaryData
            );
    }

    function _isInitialized(QuestionData storage questionData) internal view returns (bool) {
        return questionData.ancillaryData.length > 0;
    }

    /// @notice Construct the payout array given the price
    /// @param price - The price retrieved from the OO
    function _constructPayouts(int256 price) internal pure returns (uint256[] memory) {
        // Payouts: [YES, NO]
        uint256[] memory payouts = new uint256[](2);
        // Valid prices are 0, 0.5 and 1
        if (price != 0 && price != 0.5 ether && price != 1 ether) revert InvalidOOPrice();

        if (price == 0) {
            // NO: Report [Yes, No] as [0, 1]
            payouts[0] = 0;
            payouts[1] = 1;
        } else if (price == 0.5 ether) {
            // UNKNOWN: Report [Yes, No] as [1, 1], 50/50
            // Note that a tie is not a valid outcome when used with the `NegRiskOperator`
            payouts[0] = 1;
            payouts[1] = 1;
        } else {
            // YES: Report [Yes, No] as [1, 0]
            payouts[0] = 1;
            payouts[1] = 0;
        }
        return payouts;
    }

    /// @notice Validates a payout array from the admin
    /// @param payouts - The payout array
    function _isValidPayoutArray(uint256[] calldata payouts) internal pure returns (bool) {
        return PayoutHelperLib.isValidPayoutArray(payouts);
    }
}
