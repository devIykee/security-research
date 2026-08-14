// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

interface ICampaignFactory {
    /// @dev Campaign is already paused
    error CampaignAlreadyPaused();

    /// @dev Campaign cannot be updated as it has already ended
    error CampaignIsExpired();

    /// @dev Campaign is not currently paused
    error CampaignNotPaused();

    /// @dev Allow/deny list cannot be empty
    error EmptyList();

    /// @dev Campaign duration must be at least one week
    error InvalidDuration();

    /// @dev Fee for token is too high
    error InvalidFee();

    /// @dev Array lengths do not match
    error InvalidLengths();

    /// @dev Start time must be at least two hours in the future
    error InvalidStartTime();

    /// @dev Provided address cannot be the zero-address
    error InvalidZeroAddress();

    /// @dev Incentives do not meet the minimum required per week
    error InsufficientIncentives();

    /// @dev CampaignFactory protocol is currently paused
    error Paused();

    /// @dev The provided token is not supported as an incentive reward
    error TokenNotSupported();

    /// @dev msg.sender is not authorized to call this function
    error Unauthorized();

    /// @dev Emitted when a campaign is canceled prior to its start time
    /// @param campaignId The identifier of the campaign that was canceled
    event CampaignCanceled(uint256 campaignId);

    /// @dev Emitted when a new incentives campaign is created
    /// @param creator Address of the creator
    /// @param token Address of the token to be rewarded
    /// @param rewards Amount of token to be distributed in the campaign
    /// @param endTime Timestamp of when the campaign ends
    /// @param incentiveType Type of rewards accrual
    /// @param rewardsOptions Bytes information with rewards options
    event CampaignCreated(
        uint256 campaignId,
        address indexed creator,
        address indexed token,
        address indexed pool,
        uint256 rewards,
        uint48 startTime,
        uint48 endTime,
        IncentiveType incentiveType,
        bytes rewardsOptions
    );

    /// @dev Emitted when a campaign is paused by the protocol
    /// @param campaignId The identifier of the campaign that was paused
    event CampaignPaused(uint256 campaignId);

    /// @dev Emitted when a campaign is unpaused by the protocol
    /// @param campaignId The identifier of the campaign that was unpaused
    event CampaignUnpaused(uint256 campaignId);

    /// @dev Emitted when the protocol updates the fee it charges for a specified user
    /// @param user The address of the user to update the custom fee for
    /// @param fee The fee to be charged on campaign creation (in BPS)
    event CustomFeeUpdated(address user, int256 fee);

    /// @dev Emitted when the protocol updates the distributor address
    /// @param previousDistributor The address of the current distributor
    /// @param newDistributor The address of the new distributor
    event DistributorUpdated(address previousDistributor, address newDistributor);

    /// @dev Emitted when the protocol updates the fee it charges for a new campaign
    /// @param fee The fee to be charged on campaign creation (in BPS)
    event ProtocolFeeUpdated(int256 fee);

    /// @dev Emitted when the protocol is paused as a whole
    event ProtocolPaused();

    /// @dev Emitted when the protocol is unpaused as a whole
    event ProtocolUnpaused();

    /// @dev Emitted when an authorized user recovers an ERC20 token
    /// @param to Address to send the tokens to
    /// @param token Address of the token to recover
    /// @param amount Amount of token to recover
    event RecoveredERC20(address indexed to, address indexed token, uint256 amount);

    /// @dev Emitted when a new token is allowed as a reward
    /// @param token Address of token added
    event TokenAllowedStatusUpdated(address indexed token, bool allowed);

    /// @dev Emitted when the minimum incentive for a token is updated
    /// @param token Address of the token rewarded
    /// @param minIncentive The minimum amount of token that can be given in a campaign
    event TokenMinIncentiveUpdated(address indexed token, uint256 minIncentive);

    /// @dev Different types of incentives campaigns
    enum IncentiveType {
        DENY_LIST,
        ALLOW_LIST
    }

    /// @dev Stores campaign information
    struct Campaign {
        uint256 incentives;
        address pool;
        address token;
        bool canceled;
        bool paused;
        IncentiveType incentiveType;
        address creator;
        uint48 startTime;
        uint48 endTime;
        address[] addressList;
        bytes rewardsOptions;
    }

    /// @dev Initializes contract, can only be done once
    /// @param _owner Owner of the contract
    /// @param _distributor Address of the Distributor instance
    /// @param allowedTokens Array of tokens that are allowed initially
    /// @param minAmounts Array of the respective minimum incentives per token
    /// @param fee The fee charged by the protocol to create a campaign
    function initialize(
        address _owner,
        address _distributor,
        address[] memory allowedTokens,
        uint256[] memory minAmounts,
        int256 fee
    ) external;

    /// @notice Creates a new incentives campaign
    /// @param token Address of the token to reward via the campaign
    /// @param pool Address of the pool to incentivize
    /// @param incentives Total incentives to be awarded
    /// @param duration Total duration of the incentives campaign (in weeks)
    /// @param incentiveType Type of incentives: via allow list or via deny list
    /// @param addressList List of addresses to allow/deny incentives to
    /// @param rewardsOptions Bytes representing rewards options
    function create(
        address token,
        address pool,
        uint256 incentives,
        uint48 startTime,
        uint48 duration,
        IncentiveType incentiveType,
        address[] calldata addressList,
        bytes calldata rewardsOptions
    ) external;

    /// @notice Sets or removes a token as a possible incentive
    /// @dev Only callable by owner
    /// @param token Address of the token to set whether allowed or not for
    /// @param allowed Whether to allow or disallow token
    function allowToken(address token, bool allowed) external;

    /// @notice Update the distributor contract address
    /// @dev Only callable by owner
    /// @param newDistributor Address of the new distributor contract
    function updateDistributor(address newDistributor) external;

    /// @notice Updates the fee charged by the protocol to start a campaign
    /// @dev Only callable by the owner
    /// @param fee Fee to be charged by the protocol (in BPS)
    function updateProtocolFee(int256 fee) external;

    /// @notice Updates the minimum incentives (per week) for a campaign for a specific token
    /// @dev Only callable by the owner
    /// @param token Address of the token to be rewarded
    /// @param incentive The minimum incentives (per week)
    function updateMinIncentivePerToken(address token, uint256 incentive) external;

    /// @notice Updates the custom fee for a specified user
    /// @dev Only callable by the owner
    /// @param user Address of the user to update the custom fee for
    /// @param fee The custom fee for the user (-1 is used for no-fee)
    function updateCustomFee(address user, int256 fee) external;

    /// @notice Cancels a created campaign prior to its start time
    /// @param campaignId Identifier of the campaign to cancel
    function cancel(uint256 campaignId) external;

    /// @notice Recovers ERC20 tokens accidentally sent to the contract
    /// @dev Only callable by the owner
    /// @param to Address receiving the ERC20 tokens
    /// @param token Address of the token to transfer
    /// @param amount Amount of tokens to transfer
    function recoverERC20(address to, address token, uint256 amount) external;

    /// @notice Pauses a campaign and stops rewards accrual while paused
    /// @param campaignId The identifier of the campaign to pause
    function pause(uint256 campaignId) external;

    /// @notice Unpauses a campaign so it can start rewards accrual
    /// @param campaignId The identifier of the campaign to pause
    function unpause(uint256 campaignId) external;

    /// @notice Returns whether protocol is paused entirely
    function paused() external view returns (bool);

    /// @notice Pauses protocol as a whole
    function pauseProtocol() external;

    /// @notice Unpauses protocol as a whole
    function unpauseProtocol() external;
}
