// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {Ownable} from "@openzeppelin/access/Ownable.sol";
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {Initializable} from "@openzeppelin/proxy/utils/Initializable.sol";

import {ICampaignFactory} from "./ICampaignFactory.sol";

contract CampaignFactory is ICampaignFactory, Ownable, Initializable {
    using SafeERC20 for IERC20;

    /// @notice Max fee to be charged by protocol
    int256 private constant MAX_FEE = 500;

    /// @notice Seconds in a day
    uint48 private constant DAY = 1 days;

    /// @notice ID of the next Campaign to be created
    uint256 public nextId;

    /// @notice Campaign creation fee (in BPS)
    int256 public protocolFee;

    /// @inheritdoc ICampaignFactory
    bool public paused;

    /// @notice Address of the contract handling distributions
    address public distributor;

    /// @notice Mapping of campaign ID to campaign information
    mapping(uint256 campaignId => Campaign) public campaigns;

    /// @notice Mapping of token to whether it is allowed or not as an incentive
    mapping(address token => bool allowed) public incentiveTokens;

    /// @notice Mapping of token to the minimum incentive per day
    mapping(address token => uint256 incentive) public minIncentivePerToken;

    /// @notice Mapping of campaign creators to their custom fee
    mapping(address user => int256 fee) public customFee;

    /// @param _owner Owner of the contract
    constructor(address _owner) Ownable(_owner) {}

    /// @inheritdoc ICampaignFactory
    function initialize(
        address _owner,
        address _distributor,
        address[] memory allowedTokens,
        uint256[] memory minAmounts,
        int256 fee
    ) external initializer {
        _transferOwnership(_owner);

        if (_distributor == address(0)) revert InvalidZeroAddress();
        if (allowedTokens.length != minAmounts.length) revert InvalidLengths();

        distributor = _distributor;
        _updateFee(fee);

        for (uint256 i = 0; i < allowedTokens.length; i++) {
            _allowToken(allowedTokens[i], true);
            _updateMinIncentivePerToken(allowedTokens[i], minAmounts[i]);
        }
    }

    /// @inheritdoc ICampaignFactory
    function create(
        address token,
        address pool,
        uint256 incentives,
        uint48 startTime,
        uint48 duration,
        IncentiveType incentiveType,
        address[] calldata addressList,
        bytes calldata rewardsOptions
    ) external {
        _requireNotPaused();

        if (!incentiveTokens[token]) revert TokenNotSupported();
        if (startTime < uint48(block.timestamp) + 2 hours) revert InvalidStartTime();
        if (duration < 1) revert InvalidDuration();
        if (incentives < (minIncentivePerToken[token] * duration)) revert InsufficientIncentives();
        if (incentiveType == IncentiveType.ALLOW_LIST && addressList.length == 0) {
            revert EmptyList();
        }

        uint256 fee = _calcFee(msg.sender, incentives);

        IERC20(token).safeTransferFrom(msg.sender, distributor, incentives - fee);
        IERC20(token).safeTransferFrom(msg.sender, address(this), fee);

        duration = (duration * DAY) + startTime;

        campaigns[nextId] = Campaign({
            incentives: incentives,
            pool: pool,
            token: token,
            canceled: false,
            paused: false,
            incentiveType: incentiveType,
            creator: msg.sender,
            endTime: duration,
            startTime: startTime,
            addressList: addressList,
            rewardsOptions: rewardsOptions
        });

        emit CampaignCreated(
            nextId,
            msg.sender,
            token,
            pool,
            incentives,
            startTime,
            duration,
            incentiveType,
            rewardsOptions
        );

        unchecked {
            ++nextId;
        }
    }

    /// @inheritdoc ICampaignFactory
    function allowToken(address token, bool allowed) external {
        _requireOnlyOwner();
        _allowToken(token, allowed);
    }

    /// @inheritdoc ICampaignFactory
    function updateDistributor(address newDistributor) external {
        _requireOnlyOwner();
        if (newDistributor == address(0)) revert InvalidZeroAddress();

        address previousDistributor = distributor;
        distributor = newDistributor;

        emit DistributorUpdated(previousDistributor, newDistributor);
    }

    /// @inheritdoc ICampaignFactory
    function updateProtocolFee(int256 fee) external {
        _requireOnlyOwner();
        _updateFee(fee);
    }

    /// @inheritdoc ICampaignFactory
    function updateMinIncentivePerToken(address token, uint256 incentive) external {
        _requireOnlyOwner();
        _updateMinIncentivePerToken(token, incentive);
    }

    /// @inheritdoc ICampaignFactory
    function updateCustomFee(address user, int256 fee) external {
        _requireOnlyOwner();

        if (fee > protocolFee) revert InvalidFee();

        customFee[user] = fee;

        emit CustomFeeUpdated(user, fee);
    }

    /// @inheritdoc ICampaignFactory
    function cancel(uint256 campaignId) external {
        Campaign memory campaign = campaigns[campaignId];

        if (uint48(block.timestamp) > campaign.startTime) _requireOnlyOwner();
        else _requireOnlyOwnerOrCreator(campaign.creator);

        campaign.canceled = true;
        campaign.endTime = uint48(block.timestamp);

        campaigns[campaignId] = campaign;

        emit CampaignCanceled(campaignId);
    }

    /// @inheritdoc ICampaignFactory
    function recoverERC20(address to, address token, uint256 amount) external {
        _requireOnlyOwner();

        IERC20(token).safeTransfer(to, amount);
        emit RecoveredERC20(to, token, amount);
    }

    /// @inheritdoc ICampaignFactory
    function pause(uint256 campaignId) external {
        _requireOnlyOwner();

        Campaign memory campaign = campaigns[campaignId];
        if (campaign.endTime < uint48(block.timestamp)) revert CampaignIsExpired();
        if (campaign.paused) revert CampaignAlreadyPaused();

        campaign.paused = true;
        campaigns[campaignId] = campaign;

        emit CampaignPaused(campaignId);
    }

    /// @inheritdoc ICampaignFactory
    function unpause(uint256 campaignId) external {
        _requireOnlyOwner();

        Campaign memory campaign = campaigns[campaignId];
        if (!campaign.paused) revert CampaignNotPaused();

        campaign.paused = false;
        campaigns[campaignId] = campaign;

        emit CampaignUnpaused(campaignId);
    }

    /// @inheritdoc ICampaignFactory
    function pauseProtocol() external {
        _requireOnlyOwner();
        paused = true;
        emit ProtocolPaused();
    }

    /// @inheritdoc ICampaignFactory
    function unpauseProtocol() external {
        _requireOnlyOwner();
        paused = false;
        emit ProtocolUnpaused();
    }

    function getCampaignAddressList(uint256 campaignId) external view returns (address[] memory) {
        Campaign memory camp = campaigns[campaignId];
        return camp.addressList;
    }

    /// @dev Checks if caller has operator rights
    function _requireOnlyOwner() internal view {
        if (msg.sender != owner()) revert Unauthorized();
    }

    /// @dev Checks if caller has campaign rights
    function _requireOnlyOwnerOrCreator(address creator) internal view {
        if (msg.sender != owner() && msg.sender != creator) revert Unauthorized();
    }

    /// @dev Check if protocol is paused
    function _requireNotPaused() internal view {
        if (paused) revert Paused();
    }

    /// @dev Calculates fee for the specified token and amount
    /// @param user Address of the user to calculate the fee for
    /// @param amount Amount of tokens to be used as incentives
    function _calcFee(address user, uint256 amount) internal view returns (uint256) {
        if (customFee[user] < 0) return 0;

        int256 currFee = customFee[user] > 0 ? customFee[user] : protocolFee;
        return (amount * uint256(currFee) / 10_000);
    }

    /// @dev Sets or removes token as a possible incentive
    function _allowToken(address token, bool allowed) internal {
        if (token == address(0)) revert InvalidZeroAddress();
        incentiveTokens[token] = allowed;
        emit TokenAllowedStatusUpdated(token, allowed);
    }

    /// @dev Updates the fee charged by the protocol to start a campaign
    function _updateFee(int256 fee) internal {
        if (fee > MAX_FEE || fee < 0) revert InvalidFee();
        protocolFee = fee;
        emit ProtocolFeeUpdated(fee);
    }

    /// @dev Updates the minimum incentives (per day) for a campaign for a specific token
    function _updateMinIncentivePerToken(address token, uint256 incentive) internal {
        minIncentivePerToken[token] = incentive;
        emit TokenMinIncentiveUpdated(token, incentive);
    }
}
