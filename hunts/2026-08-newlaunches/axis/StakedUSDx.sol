// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ERC4626Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {IERC7540Operator, IERC7540Redeem} from "./interfaces/IERC7540Redeem.sol";
import {IRedemptionManager} from "./interfaces/IRedemptionManager.sol";
import {IRewardManager} from "./interfaces/IRewardManager.sol";
import {IStakedUSDx} from "./interfaces/IStakedUSDx.sol";
import {IVaultShareToken} from "./interfaces/IVaultShareToken.sol";

/// @notice ERC-4626 staking vault with vested rewards, async redemptions, and restriction controls.
/// @dev Redemption accounting separates pending and claimable liabilities so servicing and claims cannot spend rewards or principal twice.
contract StakedUSDx is Initializable, ERC4626Upgradeable, AccessControlUpgradeable, IStakedUSDx {
    using Math for uint256;
    using SafeERC20 for IERC20;

    uint256 private constant WAD = 1e18;
    bytes32 private constant STATUS_CLEAR = bytes32("CLEAR");
    bytes32 private constant STATUS_RESTRICTED = bytes32("RESTRICTED");
    bytes32 private constant STATUS_FULL_RESTRICTION = bytes32("FULL_RESTRICTION");
    bytes32 private constant BLOCKED_NONE = bytes32(0);
    bytes32 private constant BLOCKED_NON_EXIT = bytes32("NON_EXIT");
    bytes32 private constant BLOCKED_ALL = bytes32("ALL");
    bytes32 private constant BASIS_AUTHORITY = bytes32("AUTHORITY");
    bytes32 private constant PAUSE_REQUESTS = bytes32("REQUESTS");
    bytes32 private constant PAUSE_CLAIMS = bytes32("CLAIMS");
    bytes32 private constant PAUSE_SERVICING = bytes32("SERVICING");
    bytes32 private constant PAUSE_CANCELLATIONS = bytes32("CANCELLATIONS");
    bytes4 private constant ERC7575_VAULT_INTERFACE_ID = 0x2f0a18c5;
    bytes32 public constant DEFAULT_REDEMPTION_POLICY_ID = bytes32("DEFAULT");
    uint256 public constant MAX_COOLDOWN_DURATION = 90 days;

    bytes32 public constant override REWARD_MANAGER_ROLE = keccak256("REWARD_MANAGER_ROLE");
    bytes32 public constant override PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant override RESTRICTION_ROLE = keccak256("RESTRICTION_ROLE");
    bytes32 public constant override REDEMPTION_SERVICER_ROLE = keccak256("REDEMPTION_SERVICER_ROLE");

    uint256 public override REQUEST_ID = 1;

    uint256 private _accountedAssets;
    uint256 private _pendingRedeemAssets;
    uint256 private _claimableRedeemAssets;

    uint256 private _unvestedRewards;
    uint256 private _rewardRate;
    uint256 private _periodFinish;
    uint256 private _lastUpdated;
    uint256 private _rewardDuration;
    uint256 private _maxRewardRate;
    bool private _rewardPaused;
    address private _rewardAuthority;

    uint256 private _cooldownDuration;
    uint256 private _maxServiceBatchShares;
    bool private _requestPaused;
    bool private _claimPaused;
    bool private _servicePaused;
    bool private _cancelPaused;
    address private _serviceAuthority;
    uint256 private _redemptionControlsUpdatedAt;
    uint256 private _nextServiceRequestId = 1;
    uint256 private _nextServiceId = 1;

    bool private _depositPaused;

    mapping(address controller => mapping(address operator => bool approved)) private _operators;
    mapping(address controller => RedeemRequestState state) private _redeemRequests;
    mapping(uint256 requestId => mapping(address controller => RedemptionState state)) private _redemptions;
    mapping(uint256 requestId => address controller) private _requestController;
    mapping(address controller => uint256[] requestIds) private _controllerRequests;
    mapping(address controller => uint256 claimIndex) private _claimIndex;
    mapping(address account => bool restricted) private _restricted;
    mapping(address account => bool fullRestriction) private _fullRestriction;
    mapping(bytes32 policyId => RedemptionPolicy policy) private _redemptionPolicies;
    mapping(address account => bytes32 policyId) private _accountRedemptionPolicy;

    uint256 private constant MAX_SERVICE_SCAN_REQUESTS = 256;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes share metadata, access roles, reward schedule, and the default redemption policy.
    function initialize(IERC20 asset_, address admin, uint256 rewardDuration_) external initializer {
        if (address(asset_) == address(0) || admin == address(0)) {
            revert InvalidZeroAddress();
        }

        __ERC20_init("Staked USDx", "sUSDx");
        __ERC4626_init(asset_);
        __AccessControl_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(REWARD_MANAGER_ROLE, admin);
        _grantRole(PAUSER_ROLE, admin);
        _grantRole(RESTRICTION_ROLE, admin);
        _grantRole(REDEMPTION_SERVICER_ROLE, admin);

        _rewardAuthority = admin;
        _serviceAuthority = admin;
        _rewardDuration = rewardDuration_;
        _lastUpdated = block.timestamp;
        _redemptionControlsUpdatedAt = block.timestamp;
        _redemptionPolicies[DEFAULT_REDEMPTION_POLICY_ID].enabled = true;
        REQUEST_ID = 1;
        _nextServiceRequestId = 1;
        _nextServiceId = 1;
    }

    function totalAssets() public view override(ERC4626Upgradeable, IERC4626) returns (uint256) {
        return _currentAccountedAssets();
    }

    function accountedAssets() external view override returns (uint256) {
        return _currentAccountedAssets();
    }

    function pendingRedeemAssets() external view override returns (uint256) {
        return _pendingRedeemAssets;
    }

    function claimableRedeemAssets() external view override returns (uint256) {
        return _claimableRedeemAssets;
    }

    function cooldownDuration() external view override returns (uint256) {
        return _cooldownDuration;
    }

    function depositPaused() external view override returns (bool) {
        return _depositPaused;
    }

    function exchangeRate() external view override returns (uint256) {
        uint256 supply = totalSupply();
        if (supply == 0) {
            return WAD;
        }
        return totalAssets().mulDiv(WAD, supply, Math.Rounding.Floor);
    }

    function getVaultState() external view override returns (VaultState memory state) {
        uint256 accounted = _currentAccountedAssets();
        uint256 required = _requiredAssets();
        uint256 balance = _assetBalance();
        uint256 supply = totalSupply();

        state = VaultState({
            totalSupply: supply,
            totalAssets: accounted,
            accountedAssets: accounted,
            pendingRedeemAssets: _pendingRedeemAssets,
            claimableRedeemAssets: _claimableRedeemAssets,
            redeemLiabilities: _pendingRedeemAssets + _claimableRedeemAssets,
            requiredAssets: required,
            assetBalance: balance,
            exchangeRate: supply == 0 ? WAD : accounted.mulDiv(WAD, supply, Math.Rounding.Floor),
            cooldown: _cooldownDuration,
            solvent: balance >= required
        });
    }

    function maxDeposit(address receiver) public view override(ERC4626Upgradeable, IERC4626) returns (uint256) {
        return _depositPaused || _restricted[receiver] ? 0 : type(uint256).max;
    }

    function maxMint(address receiver) public view override(ERC4626Upgradeable, IERC4626) returns (uint256) {
        return _depositPaused || _restricted[receiver] ? 0 : type(uint256).max;
    }

    /// @notice Maximum assets claimable via `withdraw`, i.e. the controller's total claimable assets.
    /// @dev `withdraw(maxWithdraw(controller))` never reverts: consuming every lot in full uses each lot's exact
    /// share count with no rounding. Intermediate asset amounts below the maximum may still revert on per-lot
    /// share rounding (see `withdraw`); use `redeem` for share-exact partial claims.
    function maxWithdraw(address controller) public view override(ERC4626Upgradeable, IERC4626) returns (uint256) {
        if (_claimPaused || _fullRestriction[controller]) {
            return 0;
        }
        return _redeemRequests[controller].claimableAssets;
    }

    function maxRedeem(address controller) public view override(ERC4626Upgradeable, IERC4626) returns (uint256) {
        if (_claimPaused || _fullRestriction[controller]) {
            return 0;
        }
        return _redeemRequests[controller].claimableShares;
    }

    function previewWithdraw(uint256) public pure override(ERC4626Upgradeable, IERC4626) returns (uint256) {
        revert OperationNotAllowed();
    }

    function previewRedeem(uint256) public pure override(ERC4626Upgradeable, IERC4626) returns (uint256) {
        revert OperationNotAllowed();
    }

    /// @notice Claims previously serviced redemption assets by asset amount.
    /// @dev Withdraw is claim-only in this async vault; requests must be serviced before assets become claimable.
    /// Claims draw down per-request lots in order: a fully-consumed lot uses its exact share count, but a lot
    /// consumed only partially converts assets->shares with ceil rounding and reverts if that would round up to
    /// the whole lot. Consequently `withdraw(maxWithdraw(controller))` (all lots consumed in full) always
    /// succeeds, while some intermediate asset amounts below it may revert. Use `redeem` (share-denominated,
    /// floor rounding) for share-exact partial claims.
    function withdraw(uint256 assets, address receiver, address controller)
        public
        override(ERC4626Upgradeable, IERC4626)
        returns (uint256 shares)
    {
        _requireClaimOpen();
        if (assets == 0 || receiver == address(0) || controller == address(0)) {
            revert InvalidAmount();
        }
        if (!_isSelfOrOperator(controller, msg.sender)) {
            revert OperationNotAllowed();
        }
        _requireClaimAllowed(controller, receiver);

        RedeemRequestState storage aggregate = _redeemRequests[controller];
        if (assets > aggregate.claimableAssets) {
            revert InsufficientClaimable();
        }

        shares = _claimRedeemByAssets(controller, receiver, assets);
    }

    /// @notice Claims previously serviced redemption assets by share amount.
    /// @dev Shares were burned when the async request was created, so this only releases reserved assets.
    function redeem(uint256 shares, address receiver, address controller)
        public
        override(ERC4626Upgradeable, IERC4626)
        returns (uint256 assets)
    {
        _requireClaimOpen();
        if (shares == 0 || receiver == address(0) || controller == address(0)) {
            revert InvalidAmount();
        }
        if (!_isSelfOrOperator(controller, msg.sender)) {
            revert OperationNotAllowed();
        }
        _requireClaimAllowed(controller, receiver);

        RedeemRequestState storage aggregate = _redeemRequests[controller];
        if (shares > aggregate.claimableShares) {
            revert InsufficientClaimable();
        }

        assets = _claimRedeemByShares(controller, receiver, shares);
    }

    /// @notice Allows or removes an operator for the caller's redemption actions.
    function setOperator(address operator, bool approved) external override returns (bool success) {
        if (operator == address(0)) {
            revert InvalidZeroAddress();
        }
        _operators[msg.sender][operator] = approved;
        emit OperatorSet(msg.sender, operator, approved);
        return true;
    }

    function isOperator(address controller, address operator) public view override returns (bool status) {
        return _operators[controller][operator];
    }

    /// @notice Burns shares and creates an async redemption request for later servicing.
    /// @dev Full restrictions block new requests; soft restrictions may still exit to their own controller.
    function requestRedeem(uint256 shares, address controller, address owner)
        external
        override
        returns (uint256 requestId)
    {
        if (_requestPaused) {
            revert OperationNotAllowed();
        }
        if (shares == 0 || controller == address(0) || owner == address(0)) {
            revert InvalidAmount();
        }
        if (!_isSelfOrOperator(owner, msg.sender) || !_isSelfOrOperator(controller, msg.sender)) {
            revert OperationNotAllowed();
        }
        // Freeze integrity: shares are burned from `owner` below, so a fully restricted owner (or controller)
        // cannot open a request and move value out from under a freeze. Value already in-flight for a
        // subsequently-restricted account is recoverable by RESTRICTION_ROLE via redistributeRedeemRequest.
        if (_fullRestriction[controller] || _fullRestriction[owner]) {
            revert OperationNotAllowed();
        }
        if (_restricted[owner] && controller != owner) {
            revert OperationNotAllowed();
        }
        if (balanceOf(owner) < shares) {
            revert MinSharesViolation();
        }

        _checkpointRewards();
        (bytes32 policyId, RedemptionPolicy memory policy) = _redemptionPolicyFor(controller);
        if (policy.maxRequestShares != 0 && shares > policy.maxRequestShares) {
            revert InvalidAmount();
        }
        uint256 assets = _convertToAssets(shares, Math.Rounding.Floor);

        _burn(owner, shares);
        _accountedAssets -= assets;
        _pendingRedeemAssets += assets;

        requestId = REQUEST_ID++;
        _requestController[requestId] = controller;
        _controllerRequests[controller].push(requestId);

        _redeemRequests[controller].pendingShares += shares;
        _redeemRequests[controller].pendingAssets += assets;
        _redemptions[requestId][controller] = RedemptionState({
            requestId: requestId,
            controller: controller,
            owner: owner,
            shares: shares,
            assetsReserved: assets,
            requestedAt: block.timestamp,
            eligibleAt: block.timestamp + policy.cooldown,
            policyId: policyId,
            status: RedemptionStatus.PENDING
        });

        emit RedeemRequest(controller, owner, requestId, msg.sender, shares);
    }

    function pendingRedeemRequest(uint256 requestId, address controller)
        external
        view
        override
        returns (uint256 shares)
    {
        RedemptionState storage state = _redemptions[requestId][controller];
        return state.status == RedemptionStatus.PENDING ? state.shares : 0;
    }

    function claimableRedeemRequest(uint256 requestId, address controller)
        external
        view
        override
        returns (uint256 shares)
    {
        RedemptionState storage state = _redemptions[requestId][controller];
        return state.status == RedemptionStatus.CLAIMABLE ? state.shares : 0;
    }

    function getRedeemRequest(address controller) external view override returns (RedeemRequestState memory) {
        return _redeemRequests[controller];
    }

    function redemptionState(uint256 requestId, address controller)
        external
        view
        override
        returns (RedemptionState memory)
    {
        return _redemptions[requestId][controller];
    }

    function redemptionControls() external view override returns (RedemptionControls memory) {
        return RedemptionControls({
            cooldown: _cooldownDuration,
            maxServiceBatchShares: _maxServiceBatchShares,
            requestPaused: _requestPaused,
            claimPaused: _claimPaused,
            servicePaused: _servicePaused,
            cancelPaused: _cancelPaused,
            serviceAuthority: _serviceAuthority,
            updatedAt: _redemptionControlsUpdatedAt
        });
    }

    function redemptionPolicy(bytes32 policyId) external view override returns (RedemptionPolicy memory) {
        return _redemptionPolicies[policyId];
    }

    function accountRedemptionPolicy(address account) external view override returns (bytes32) {
        return _accountRedemptionPolicy[account];
    }

    /// @notice Services eligible redemption requests in request-id order up to scan and share limits.
    /// @dev Ineligible pending requests are skipped until the scan bound is reached, so later eligible requests can advance.
    function serviceRedemptions(uint256 maxShares)
        external
        override
        onlyRole(REDEMPTION_SERVICER_ROLE)
        returns (RedemptionServiceResult memory result)
    {
        if (_servicePaused) {
            revert OperationNotAllowed();
        }
        uint256 serviceLimit = maxShares;
        if (_maxServiceBatchShares != 0 && (serviceLimit == 0 || serviceLimit > _maxServiceBatchShares)) {
            serviceLimit = _maxServiceBatchShares;
        }

        result.serviceId = _nextServiceId++;
        uint256 requestId = _nextServiceRequestId;
        uint256 firstSkippedPendingRequestId;
        uint256 requestsScanned;
        while (
            requestId < REQUEST_ID && requestsScanned < MAX_SERVICE_SCAN_REQUESTS
                && (serviceLimit == 0 || result.sharesMadeClaimable < serviceLimit)
        ) {
            requestsScanned++;
            address controller = _requestController[requestId];
            RedemptionState storage state = _redemptions[requestId][controller];
            if (state.status == RedemptionStatus.PENDING) {
                if (block.timestamp < state.eligibleAt) {
                    if (firstSkippedPendingRequestId == 0) {
                        firstSkippedPendingRequestId = requestId;
                    }
                    requestId++;
                    continue;
                }
                // Forward-progress guarantee: the first eligible request in a batch is always serviced
                // (result.requestsServiced == 0 here), so a request whose size alone exceeds serviceLimit
                // can never permanently stall the queue. serviceLimit is a soft batch cap, not a per-request
                // maximum (per-request size is bounded separately by policy.maxRequestShares).
                if (
                    serviceLimit != 0 && result.requestsServiced != 0
                        && result.sharesMadeClaimable + state.shares > serviceLimit
                ) {
                    break;
                }

                (uint256 sharesMadeClaimable, uint256 assetsReserved) =
                    _servicePendingRedeemRequest(requestId, controller);
                result.requestsServiced += 1;
                result.sharesMadeClaimable += sharesMadeClaimable;
                result.assetsReserved += assetsReserved;
            }
            requestId++;
        }
        _nextServiceRequestId =
            requestId == REQUEST_ID && firstSkippedPendingRequestId != 0 ? firstSkippedPendingRequestId : requestId;

        emit RedemptionsServiced(
            result.serviceId, result.requestsServiced, result.sharesMadeClaimable, result.assetsReserved
        );
    }

    /// @notice Services one eligible redemption request by exact id and controller.
    function serviceRedeemRequest(uint256 requestId, address controller)
        external
        override
        onlyRole(REDEMPTION_SERVICER_ROLE)
        returns (RedemptionServiceResult memory result)
    {
        if (_servicePaused) {
            revert OperationNotAllowed();
        }
        _requireServiceableRedeemRequest(requestId, controller);

        result.serviceId = _nextServiceId++;
        result.requestsServiced = 1;
        (result.sharesMadeClaimable, result.assetsReserved) = _servicePendingRedeemRequest(requestId, controller);

        emit RedemptionsServiced(
            result.serviceId, result.requestsServiced, result.sharesMadeClaimable, result.assetsReserved
        );
    }

    /// @notice Cancels a pending redemption request and restores the burned shares.
    /// @dev Full restrictions cannot cancel because shares would be restored to a blocked account.
    function cancelRedeemRequest(uint256 requestId, address controller)
        external
        override
        returns (uint256 sharesReturned)
    {
        if (_cancelPaused) {
            revert OperationNotAllowed();
        }
        if (!_isSelfOrOperator(controller, msg.sender)) {
            revert OperationNotAllowed();
        }

        RedemptionState storage state = _redemptions[requestId][controller];
        if (state.status != RedemptionStatus.PENDING) {
            revert OperationNotAllowed();
        }
        if (_fullRestriction[controller] || _fullRestriction[state.owner]) {
            revert OperationNotAllowed();
        }

        sharesReturned = state.shares;
        uint256 assetsReleased = state.assetsReserved;
        state.status = RedemptionStatus.CANCELLED;
        state.shares = 0;
        state.assetsReserved = 0;

        RedeemRequestState storage aggregate = _redeemRequests[controller];
        aggregate.pendingShares -= sharesReturned;
        aggregate.pendingAssets -= assetsReleased;

        _pendingRedeemAssets -= assetsReleased;
        _accountedAssets += assetsReleased;
        _restoreCancelledShares(state.owner, sharesReturned);

        emit RedeemRequestCancelled(requestId, controller, state.owner, sharesReturned, assetsReleased);
    }

    /// @notice Adds rewards to the vesting schedule after checkpointing already vested rewards.
    function fundRewards(uint256 assets, bytes32 sourceRef) external override onlyRole(REWARD_MANAGER_ROLE) {
        if (_rewardPaused) {
            revert OperationNotAllowed();
        }
        if (assets == 0 || _rewardDuration == 0) {
            revert InvalidAmount();
        }
        if (totalSupply() == 0) {
            revert OperationNotAllowed();
        }

        _checkpointRewards();
        uint256 vestingDuration = _activeRewardDuration();
        uint256 nextUnvested = _unvestedRewards + assets;
        uint256 nextRewardRate = nextUnvested / vestingDuration;
        if (nextRewardRate == 0) {
            revert InvalidAmount();
        }
        if (_maxRewardRate != 0 && nextRewardRate > _maxRewardRate) {
            revert OperationNotAllowed();
        }

        _assetToken().safeTransferFrom(msg.sender, address(this), assets);

        _unvestedRewards = nextUnvested;
        _rewardRate = nextRewardRate;
        _periodFinish = block.timestamp + vestingDuration;
        _lastUpdated = block.timestamp;

        emit RewardsFunded(msg.sender, assets, sourceRef, _rewardRate, _periodFinish);
    }

    function rewardConfig() external view override returns (RewardConfig memory) {
        return RewardConfig({
            authority: _rewardAuthority, duration: _rewardDuration, maxRate: _maxRewardRate, paused: _rewardPaused
        });
    }

    function rewardState() external view override returns (RewardState memory) {
        uint256 vested = _vestedRewards();
        return RewardState({
            accountedAssets: _accountedAssets + vested,
            unvestedRewards: _unvestedRewards - vested,
            rewardRate: _rewardRate,
            periodFinish: _periodFinish,
            lastUpdated: _currentRewardTimestamp()
        });
    }

    function setRewardConfig(uint256 duration, uint256 maxRate, bool paused) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _checkpointRewards();
        _rewardDuration = duration;
        _maxRewardRate = maxRate;
        _rewardPaused = paused;
        _rewardAuthority = msg.sender;
        _rescheduleActiveRewards(duration, maxRate, paused);

        emit RewardConfigUpdated(_rewardAuthority, duration, maxRate, paused);
    }

    function pauseRewardFunding() external onlyRole(PAUSER_ROLE) {
        _checkpointRewards();
        _rewardPaused = true;
        _rescheduleActiveRewards(_rewardDuration, _maxRewardRate, true);
        emit RewardConfigUpdated(_rewardAuthority, _rewardDuration, _maxRewardRate, true);
    }

    function setDepositPause(bool paused) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        _depositPaused = paused;
        emit DepositPauseUpdated(paused);
    }

    function pauseDeposits() external override onlyRole(PAUSER_ROLE) {
        _depositPaused = true;
        emit DepositPauseUpdated(true);
    }

    /// @notice Updates global redemption cooldown, servicing bounds, pause flags, and service authority metadata.
    function setRedemptionControls(
        uint256 cooldown,
        uint256 maxServiceBatchShares,
        bool requestPaused,
        bool claimPaused,
        bool servicePaused,
        bool cancelPaused,
        address serviceAuthority
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (serviceAuthority == address(0)) {
            revert InvalidZeroAddress();
        }
        _requireValidCooldown(cooldown);
        _cooldownDuration = cooldown;
        _redemptionPolicies[DEFAULT_REDEMPTION_POLICY_ID].cooldown = cooldown;
        _maxServiceBatchShares = maxServiceBatchShares;
        _requestPaused = requestPaused;
        _claimPaused = claimPaused;
        _servicePaused = servicePaused;
        _cancelPaused = cancelPaused;
        _serviceAuthority = serviceAuthority;
        _redemptionControlsUpdatedAt = block.timestamp;
        RedemptionPolicy memory defaultPolicy = _redemptionPolicies[DEFAULT_REDEMPTION_POLICY_ID];
        emit RedemptionControlsUpdated(
            cooldown, maxServiceBatchShares, requestPaused, claimPaused, servicePaused, cancelPaused, serviceAuthority
        );
        emit RedemptionPolicyUpdated(
            DEFAULT_REDEMPTION_POLICY_ID, defaultPolicy.cooldown, defaultPolicy.maxRequestShares, defaultPolicy.enabled
        );
    }

    function pauseRedeemRequests() external onlyRole(PAUSER_ROLE) {
        _requestPaused = true;
        _redemptionControlsUpdatedAt = block.timestamp;
        emit RedemptionPauseUpdated(PAUSE_REQUESTS, true);
    }

    function pauseRedeemClaims() external onlyRole(PAUSER_ROLE) {
        _claimPaused = true;
        _redemptionControlsUpdatedAt = block.timestamp;
        emit RedemptionPauseUpdated(PAUSE_CLAIMS, true);
    }

    function pauseRedemptionServicing() external onlyRole(PAUSER_ROLE) {
        _servicePaused = true;
        _redemptionControlsUpdatedAt = block.timestamp;
        emit RedemptionPauseUpdated(PAUSE_SERVICING, true);
    }

    function pauseRedeemCancellations() external onlyRole(PAUSER_ROLE) {
        _cancelPaused = true;
        _redemptionControlsUpdatedAt = block.timestamp;
        emit RedemptionPauseUpdated(PAUSE_CANCELLATIONS, true);
    }

    /// @notice Updates the default redemption cooldown while preserving other controls.
    function setCooldownDuration(uint256 duration) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        _requireValidCooldown(duration);
        uint256 previous = _cooldownDuration;
        _cooldownDuration = duration;
        _redemptionPolicies[DEFAULT_REDEMPTION_POLICY_ID].cooldown = duration;
        _redemptionControlsUpdatedAt = block.timestamp;
        RedemptionPolicy memory defaultPolicy = _redemptionPolicies[DEFAULT_REDEMPTION_POLICY_ID];
        emit CooldownDurationUpdated(previous, duration);
        emit RedemptionControlsUpdated(
            _cooldownDuration,
            _maxServiceBatchShares,
            _requestPaused,
            _claimPaused,
            _servicePaused,
            _cancelPaused,
            _serviceAuthority
        );
        emit RedemptionPolicyUpdated(
            DEFAULT_REDEMPTION_POLICY_ID, defaultPolicy.cooldown, defaultPolicy.maxRequestShares, defaultPolicy.enabled
        );
    }

    /// @notice Creates or updates a named redemption policy for account-specific limits.
    function setRedemptionPolicy(bytes32 policyId, RedemptionPolicy calldata policy)
        external
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        if (policyId == bytes32(0)) {
            revert OperationNotAllowed();
        }
        if (policyId == DEFAULT_REDEMPTION_POLICY_ID && !policy.enabled) {
            revert OperationNotAllowed();
        }
        _requireValidCooldown(policy.cooldown);
        _redemptionPolicies[policyId] = policy;
        if (policyId == DEFAULT_REDEMPTION_POLICY_ID) {
            uint256 previous = _cooldownDuration;
            _cooldownDuration = policy.cooldown;
            emit CooldownDurationUpdated(previous, policy.cooldown);
        }
        _redemptionControlsUpdatedAt = block.timestamp;
        emit RedemptionPolicyUpdated(policyId, policy.cooldown, policy.maxRequestShares, policy.enabled);
    }

    /// @notice Assigns an enabled redemption policy to an account or clears back to default.
    function setAccountRedemptionPolicy(address account, bytes32 policyId)
        external
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        if (account == address(0)) {
            revert InvalidZeroAddress();
        }
        if (policyId != bytes32(0) && !_redemptionPolicies[policyId].enabled) {
            revert OperationNotAllowed();
        }
        _accountRedemptionPolicy[account] = policyId;
        _redemptionControlsUpdatedAt = block.timestamp;
        emit AccountRedemptionPolicyUpdated(account, policyId);
    }

    /// @notice Applies soft or full restrictions to a vault account.
    function addToBlacklist(address target, bool isFullRestriction) external override onlyRole(RESTRICTION_ROLE) {
        if (target == address(0)) {
            revert InvalidZeroAddress();
        }
        _restricted[target] = true;
        _fullRestriction[target] = isFullRestriction;
        emit RestrictionUpdated(
            target,
            isFullRestriction ? STATUS_FULL_RESTRICTION : STATUS_RESTRICTED,
            BASIS_AUTHORITY,
            _authorityRef(msg.sender)
        );
    }

    /// @notice Clears all restriction flags for a vault account.
    function removeFromBlacklist(address target, bool) external override onlyRole(RESTRICTION_ROLE) {
        if (target == address(0)) {
            revert InvalidZeroAddress();
        }
        _restricted[target] = false;
        _fullRestriction[target] = false;
        emit RestrictionUpdated(target, STATUS_CLEAR, BASIS_AUTHORITY, _authorityRef(msg.sender));
    }

    /// @notice Moves all liquid shares from a fully restricted account to an unrestricted recipient.
    function redistributeLockedAmount(address from, address to) external override onlyRole(RESTRICTION_ROLE) {
        if (from == address(0) || to == address(0)) {
            revert InvalidZeroAddress();
        }
        if (!_fullRestriction[from] || _restricted[to]) {
            revert OperationNotAllowed();
        }
        uint256 shares = balanceOf(from);
        super._update(from, to, shares);
        emit LockedAmountRedistributed(from, to, shares);
    }

    /// @notice Moves a pending or claimable redemption request away from a fully restricted account.
    function redistributeRedeemRequest(uint256 requestId, address controller, address to)
        external
        override
        onlyRole(RESTRICTION_ROLE)
        returns (uint256 shares, uint256 assets)
    {
        if (controller == address(0) || to == address(0)) {
            revert InvalidZeroAddress();
        }
        if (controller == to || _restricted[to]) {
            revert OperationNotAllowed();
        }

        RedemptionState memory moved = _redemptions[requestId][controller];
        if (moved.status != RedemptionStatus.PENDING && moved.status != RedemptionStatus.CLAIMABLE) {
            revert OperationNotAllowed();
        }
        if (!_fullRestriction[controller] && !_fullRestriction[moved.owner]) {
            revert OperationNotAllowed();
        }

        shares = moved.shares;
        assets = moved.assetsReserved;
        _moveRedeemRequestAggregate(controller, to, moved.status, shares, assets);

        // The old controller's request list is append-only; deleting the state makes future scans skip this request.
        delete _redemptions[requestId][controller];
        moved.controller = to;
        moved.owner = to;
        _redemptions[requestId][to] = moved;
        _requestController[requestId] = to;
        _controllerRequests[to].push(requestId);

        emit RedeemRequestRedistributed(requestId, controller, to, shares, assets, uint8(moved.status));
    }

    /// @notice Rescues unrelated tokens and surplus underlying assets without touching reserved vault liabilities.
    function rescueTokens(address token, uint256 amount, address to) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        if (token == address(this)) {
            revert InvalidToken();
        }
        if (to == address(0)) {
            revert InvalidZeroAddress();
        }
        if (token == address(asset()) && amount > _surplusAssets()) {
            revert InvalidAmount();
        }
        IERC20(token).safeTransfer(to, amount);
        emit Rescue(token, to, amount);
    }

    function getAccountState(address account) external view override returns (AccountState memory state) {
        RedeemRequestState storage redeemRequest = _redeemRequests[account];
        state = AccountState({
            shareBalance: balanceOf(account),
            assetsValue: convertToAssets(balanceOf(account)),
            pendingRedeemAssets: redeemRequest.pendingAssets,
            claimableRedeemAssets: redeemRequest.claimableAssets,
            restrictionStatus: _restrictionStatus(account),
            blockedActions: _blockedActions(account),
            restrictionBasis: _restricted[account] ? BASIS_AUTHORITY : bytes32(0)
        });
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(AccessControlUpgradeable, IERC165)
        returns (bool)
    {
        return interfaceId == type(IERC7540Operator).interfaceId || interfaceId == type(IERC7540Redeem).interfaceId
            || interfaceId == ERC7575_VAULT_INTERFACE_ID || interfaceId == type(IRedemptionManager).interfaceId
            || interfaceId == type(IRewardManager).interfaceId || interfaceId == type(IVaultShareToken).interfaceId
            || interfaceId == type(IStakedUSDx).interfaceId || super.supportsInterface(interfaceId);
    }

    function share() external view override returns (address shareTokenAddress) {
        return address(this);
    }

    function _deposit(address caller, address receiver, uint256 assets, uint256 shares)
        internal
        override(ERC4626Upgradeable)
    {
        if (_depositPaused) {
            revert OperationNotAllowed();
        }
        if (assets == 0 || shares == 0) {
            revert InvalidAmount();
        }
        _requireCanInitiateDeposit(caller);
        _requireCanReceiveShares(receiver);
        _checkpointRewards();
        _assetToken().safeTransferFrom(caller, address(this), assets);
        _accountedAssets += assets;
        _mint(receiver, shares);

        emit Deposit(caller, receiver, assets, shares);
    }

    function _convertToShares(uint256 assets, Math.Rounding rounding)
        internal
        view
        override(ERC4626Upgradeable)
        returns (uint256)
    {
        uint256 supply = totalSupply();
        uint256 accounted = _currentAccountedAssets();
        if (supply == 0 || accounted == 0) {
            return assets;
        }
        return assets.mulDiv(supply, accounted, rounding);
    }

    function _convertToAssets(uint256 shares, Math.Rounding rounding)
        internal
        view
        override(ERC4626Upgradeable)
        returns (uint256)
    {
        uint256 supply = totalSupply();
        uint256 accounted = _currentAccountedAssets();
        if (supply == 0) {
            return shares;
        }
        return shares.mulDiv(accounted, supply, rounding);
    }

    /// @dev Central share-transfer restriction guard for mints, burns, transfers, and redistribution.
    function _update(address from, address to, uint256 value) internal override(ERC20Upgradeable) {
        if (to == address(0)) {
            if (from != address(0) && _fullRestriction[from]) {
                revert OperationNotAllowed();
            }
        } else if (from == address(0)) {
            _requireCanReceiveShares(to);
        } else if (_restricted[from] || _restricted[to]) {
            revert OperationNotAllowed();
        }
        super._update(from, to, value);
    }

    /// @dev Confirms a request exists, is still pending, and has reached its cooldown.
    function _requireServiceableRedeemRequest(uint256 requestId, address controller) private view {
        if (controller == address(0) || _requestController[requestId] != controller) {
            revert OperationNotAllowed();
        }

        RedemptionState storage state = _redemptions[requestId][controller];
        if (state.status != RedemptionStatus.PENDING || block.timestamp < state.eligibleAt) {
            revert OperationNotAllowed();
        }
    }

    /// @dev Moves one pending request into claimable accounting.
    function _servicePendingRedeemRequest(uint256 requestId, address controller)
        private
        returns (uint256 sharesMadeClaimable, uint256 assetsReserved)
    {
        RedemptionState storage state = _redemptions[requestId][controller];
        sharesMadeClaimable = state.shares;
        assetsReserved = state.assetsReserved;

        state.status = RedemptionStatus.CLAIMABLE;
        _restoreClaimIndexForServicedRequest(requestId, controller);

        RedeemRequestState storage aggregate = _redeemRequests[controller];
        aggregate.pendingShares -= sharesMadeClaimable;
        aggregate.pendingAssets -= assetsReserved;
        aggregate.claimableShares += sharesMadeClaimable;
        aggregate.claimableAssets += assetsReserved;

        _pendingRedeemAssets -= assetsReserved;
        _claimableRedeemAssets += assetsReserved;
    }

    /// @dev Claims across serviced requests by shares while preserving per-request residual accounting.
    function _claimRedeemByShares(address controller, address receiver, uint256 shares)
        private
        returns (uint256 assets)
    {
        uint256 remainingShares = shares;
        uint256[] storage requestIds = _controllerRequests[controller];
        uint256 index = _claimIndex[controller];

        while (remainingShares != 0 && index < requestIds.length) {
            RedemptionState storage state = _redemptions[requestIds[index]][controller];
            if (state.status != RedemptionStatus.CLAIMABLE || state.shares == 0) {
                index++;
                continue;
            }
            _requireRequestClaimAllowed(state, controller, receiver);

            uint256 sharesToClaim = remainingShares < state.shares ? remainingShares : state.shares;
            uint256 assetsToClaim = sharesToClaim == state.shares
                ? state.assetsReserved
                : sharesToClaim.mulDiv(state.assetsReserved, state.shares, Math.Rounding.Floor);

            state.shares -= sharesToClaim;
            state.assetsReserved -= assetsToClaim;
            remainingShares -= sharesToClaim;
            assets += assetsToClaim;

            if (state.shares == 0) {
                state.status = RedemptionStatus.CLAIMED;
                index++;
            }
        }

        _claimIndex[controller] = index;
        if (remainingShares != 0) {
            revert InsufficientClaimable();
        }

        _recordClaim(controller, shares, assets);
        _assetToken().safeTransfer(receiver, assets);
        emit Withdraw(msg.sender, receiver, controller, assets, shares);
    }

    /// @dev Claims across serviced requests by assets while rounding shares up for partial claims.
    function _claimRedeemByAssets(address controller, address receiver, uint256 assets)
        private
        returns (uint256 shares)
    {
        uint256 remainingAssets = assets;
        uint256[] storage requestIds = _controllerRequests[controller];
        uint256 index = _claimIndex[controller];

        while (remainingAssets != 0 && index < requestIds.length) {
            RedemptionState storage state = _redemptions[requestIds[index]][controller];
            if (state.status != RedemptionStatus.CLAIMABLE || state.assetsReserved == 0) {
                index++;
                continue;
            }
            _requireRequestClaimAllowed(state, controller, receiver);

            uint256 assetsToClaim = remainingAssets < state.assetsReserved ? remainingAssets : state.assetsReserved;
            uint256 sharesToClaim = assetsToClaim == state.assetsReserved
                ? state.shares
                : assetsToClaim.mulDiv(state.shares, state.assetsReserved, Math.Rounding.Ceil);

            if (sharesToClaim == 0 || sharesToClaim >= state.shares && assetsToClaim != state.assetsReserved) {
                revert InsufficientClaimable();
            }

            state.shares -= sharesToClaim;
            state.assetsReserved -= assetsToClaim;
            remainingAssets -= assetsToClaim;
            shares += sharesToClaim;

            if (state.shares == 0) {
                state.status = RedemptionStatus.CLAIMED;
                index++;
            }
        }

        _claimIndex[controller] = index;
        if (remainingAssets != 0) {
            revert InsufficientClaimable();
        }

        _recordClaim(controller, shares, assets);
        _assetToken().safeTransfer(receiver, assets);
        emit Withdraw(msg.sender, receiver, controller, assets, shares);
    }

    function _restoreClaimIndexForServicedRequest(uint256 requestId, address controller) private {
        uint256 index = _claimIndex[controller];
        if (index == 0) {
            return;
        }

        uint256[] storage requestIds = _controllerRequests[controller];
        if (requestIds[index - 1] < requestId) {
            return;
        }

        while (index != 0) {
            index--;
            if (requestIds[index] == requestId) {
                _claimIndex[controller] = index;
                return;
            }
        }
    }

    function _recordClaim(address controller, uint256 shares, uint256 assets) private {
        RedeemRequestState storage aggregate = _redeemRequests[controller];
        aggregate.claimableShares -= shares;
        aggregate.claimableAssets -= assets;
        _claimableRedeemAssets -= assets;
    }

    /// @dev Materializes vested rewards into accounted assets and stops vesting when the schedule is complete.
    function _checkpointRewards() private {
        uint256 vested = _vestedRewards();
        if (vested != 0) {
            _accountedAssets += vested;
            _unvestedRewards -= vested;
        }
        _lastUpdated = _currentRewardTimestamp();
        if (block.timestamp >= _periodFinish || _unvestedRewards == 0) {
            _rewardRate = 0;
        }
    }

    function _rescheduleActiveRewards(uint256 duration, uint256 maxRate, bool paused) private {
        if (_unvestedRewards == 0) {
            _rewardRate = 0;
            _periodFinish = 0;
            _lastUpdated = block.timestamp;
            return;
        }

        // Active rewards keep their funded backing but vest only while an explicit schedule is running.
        if (paused) {
            _rewardRate = 0;
            _periodFinish = block.timestamp;
            _lastUpdated = block.timestamp;
            return;
        }

        if (duration == 0) {
            revert InvalidAmount();
        }

        uint256 nextRewardRate = _unvestedRewards / duration;
        if (nextRewardRate == 0) {
            revert InvalidAmount();
        }
        if (maxRate != 0 && nextRewardRate > maxRate) {
            revert OperationNotAllowed();
        }

        _rewardRate = nextRewardRate;
        _periodFinish = block.timestamp + duration;
        _lastUpdated = block.timestamp;
    }

    function _activeRewardDuration() private view returns (uint256) {
        // Top-ups add rewards to the active window; extending vesting must be explicit configuration.
        if (_unvestedRewards != 0 && _rewardRate != 0 && block.timestamp < _periodFinish) {
            return _periodFinish - block.timestamp;
        }
        return _rewardDuration;
    }

    function _vestedRewards() private view returns (uint256) {
        if (_unvestedRewards == 0 || _rewardRate == 0) {
            return 0;
        }
        if (block.timestamp >= _periodFinish) {
            return _unvestedRewards;
        }
        uint256 elapsed = _currentRewardTimestamp() - _lastUpdated;
        uint256 vested = elapsed * _rewardRate;
        return vested > _unvestedRewards ? _unvestedRewards : vested;
    }

    function _currentAccountedAssets() private view returns (uint256) {
        return _accountedAssets + _vestedRewards();
    }

    function _requiredAssets() private view returns (uint256) {
        return _accountedAssets + _pendingRedeemAssets + _claimableRedeemAssets + _unvestedRewards;
    }

    function _surplusAssets() private view returns (uint256) {
        uint256 balance = _assetBalance();
        uint256 required = _requiredAssets();
        return balance > required ? balance - required : 0;
    }

    function _currentRewardTimestamp() private view returns (uint256) {
        if (_periodFinish != 0 && block.timestamp > _periodFinish) {
            return _periodFinish;
        }
        return block.timestamp;
    }

    function _assetBalance() private view returns (uint256) {
        return _assetToken().balanceOf(address(this));
    }

    function _isSelfOrOperator(address account, address caller) private view returns (bool) {
        return caller == account || _operators[account][caller];
    }

    function _requireCanReceiveShares(address account) private view {
        if (_restricted[account]) {
            revert OperationNotAllowed();
        }
    }

    function _requireCanInitiateDeposit(address account) private view {
        if (_restricted[account]) {
            revert OperationNotAllowed();
        }
    }

    /// @dev Restores cancelled request shares without applying the normal receive restriction.
    function _restoreCancelledShares(address account, uint256 shares) private {
        // Cancellation restores shares burned for the request, so soft-restricted accounts may receive them.
        super._update(address(0), account, shares);
    }

    function _moveRedeemRequestAggregate(
        address from,
        address to,
        RedemptionStatus status,
        uint256 shares,
        uint256 assets
    ) private {
        RedeemRequestState storage fromAggregate = _redeemRequests[from];
        RedeemRequestState storage toAggregate = _redeemRequests[to];
        if (status == RedemptionStatus.PENDING) {
            fromAggregate.pendingShares -= shares;
            fromAggregate.pendingAssets -= assets;
            toAggregate.pendingShares += shares;
            toAggregate.pendingAssets += assets;
            return;
        }

        fromAggregate.claimableShares -= shares;
        fromAggregate.claimableAssets -= assets;
        toAggregate.claimableShares += shares;
        toAggregate.claimableAssets += assets;
    }

    /// @dev Allows soft-restricted owners to exit only to themselves and blocks full restrictions.
    function _requireClaimAllowed(address controller, address receiver) private view {
        if (_fullRestriction[controller] || _fullRestriction[receiver]) {
            revert OperationNotAllowed();
        }
        if (_restricted[controller] && receiver != controller) {
            revert OperationNotAllowed();
        }
        if (_restricted[receiver] && receiver != controller) {
            revert OperationNotAllowed();
        }
    }

    /// @dev Re-checks the stored request owner because restrictions may change after request creation.
    function _requireRequestClaimAllowed(RedemptionState storage state, address controller, address receiver)
        private
        view
    {
        _requireClaimAllowed(controller, receiver);
        // Claim stays gated on the original `state.owner`: freezing an owner also freezes their in-flight
        // redemption even though bookkeeping possession sits with the controller. RESTRICTION_ROLE relocates
        // such value via redistributeRedeemRequest.
        if (_fullRestriction[state.owner]) {
            revert OperationNotAllowed();
        }
        if (_restricted[state.owner] && (controller != state.owner || receiver != state.owner)) {
            revert OperationNotAllowed();
        }
    }

    function _restrictionStatus(address account) private view returns (bytes32) {
        if (_fullRestriction[account]) {
            return STATUS_FULL_RESTRICTION;
        }
        return _restricted[account] ? STATUS_RESTRICTED : STATUS_CLEAR;
    }

    function _blockedActions(address account) private view returns (bytes32) {
        if (_fullRestriction[account]) {
            return BLOCKED_ALL;
        }
        return _restricted[account] ? BLOCKED_NON_EXIT : BLOCKED_NONE;
    }

    function _authorityRef(address account) private pure returns (bytes32) {
        return bytes32(uint256(uint160(account)));
    }

    function _assetToken() private view returns (IERC20) {
        return IERC20(asset());
    }

    function _requireClaimOpen() private view {
        if (_claimPaused) {
            revert OperationNotAllowed();
        }
    }

    /// @dev Resolves an account override or falls back to the default enabled redemption policy.
    function _redemptionPolicyFor(address controller)
        private
        view
        returns (bytes32 policyId, RedemptionPolicy memory policy)
    {
        policyId = _accountRedemptionPolicy[controller];
        if (policyId == bytes32(0)) {
            policyId = DEFAULT_REDEMPTION_POLICY_ID;
        }
        policy = _redemptionPolicies[policyId];
        if (!policy.enabled) {
            revert OperationNotAllowed();
        }
    }

    function _requireValidCooldown(uint256 cooldown) private pure {
        if (cooldown > MAX_COOLDOWN_DURATION) {
            revert InvalidCooldown();
        }
    }

    uint256[45] private __gap;
}

