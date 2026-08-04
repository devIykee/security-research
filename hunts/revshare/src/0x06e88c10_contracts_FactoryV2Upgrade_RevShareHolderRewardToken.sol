// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "./interfaces/IFactoryV2Upgrade.sol";

interface IWrappedNativeReward is IERC20Upgrade {
    function withdraw(uint256 amount) external;
}

/// @notice ERC-20 with bounded multi-asset O(1)-per-asset holder reward accounting.
/// @dev New reward assets are capped so transfers remain bounded and cannot be griefed by registering unlimited assets.
contract RevShareHolderRewardToken is IHolderRewards {
    uint256 private constant ACCURACY = 1e36;
    uint256 public constant MAX_REWARD_ASSETS = 16;
    uint256 public constant HOLDER_REWARD_STREAM_DURATION = 7 days;

    struct RewardState {
        uint256 rewardPerEligibleToken;
        uint256 undistributedRemainder;
        uint256 rewardRate;
        uint256 streamRemainder;
        uint64 periodFinish;
        uint64 lastUpdateTime;
        bool unwrapOnClaim;
        bool registered;
    }

    string public name;
    string public symbol;
    uint8 public immutable decimals;
    uint256 public totalSupply;
    string public metadataURI;
    string public logo;
    string public description;
    struct Socials {
        string website;
        string twitter;
        string telegram;
        string discord;
        string other;
    }
    Socials public socials;
    address public owner;
    address public rewardDepositor;
    /// @notice Initial/default reward asset retained for backwards-compatible integrations.
    address public override rewardAsset;
    uint256 public eligibleSupply;
    bool public rewardsInitialized;
    bool public rewardExclusionsLocked;
    bool private locked;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    mapping(address => bool) public excludedFromRewards;
    mapping(address => mapping(address => uint256)) public userRewardIndex;
    mapping(address => mapping(address => uint256)) public storedRewards;
    /// @notice Lifetime rewards successfully claimed, tracked separately for every reward asset.
    mapping(address => uint256) public totalHolderClaimed;
    mapping(address => RewardState) private rewardStates;
    address[] private holderRewardAssets;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event RewardsInitialized(address indexed depositor, address indexed rewardAsset);
    event RewardAssetRegistered(address indexed asset, bool unwrapOnClaim);
    event RewardsDeposited(address indexed asset, uint256 amount, uint256 rewardPerEligibleToken);
    event RewardStreamUpdated(address indexed asset, uint256 rewardRate, uint256 periodFinish, uint256 carriedRewards);
    event RewardsClaimed(address indexed holder, address indexed asset, uint256 amount);
    event RewardExclusionUpdated(address indexed account, bool excluded);
    event RewardExclusionsLocked();
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event TokensBurned(address indexed account, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier nonReentrant() {
        require(!locked, "Reentrant");
        locked = true;
        _;
        locked = false;
    }

    constructor(
        string memory tokenName,
        string memory tokenSymbol,
        uint8 tokenDecimals,
        uint256 tokenSupply,
        string memory tokenMetadataURI,
        string memory tokenLogo,
        string memory tokenDescription,
        Socials memory tokenSocials,
        address initialHolder,
        address initialOwner
    ) {
        require(initialHolder != address(0) && initialOwner != address(0), "Address zero");
        require(tokenSupply > 0, "Supply zero");
        name = tokenName;
        symbol = tokenSymbol;
        decimals = tokenDecimals;
        totalSupply = tokenSupply;
        metadataURI = tokenMetadataURI;
        logo = tokenLogo;
        description = tokenDescription;
        socials = tokenSocials;
        owner = initialOwner;
        balanceOf[initialHolder] = tokenSupply;
        eligibleSupply = tokenSupply;
        emit Transfer(address(0), initialHolder, tokenSupply);
    }

    /// @dev Must stay below the 2,300-gas stipend used by canonical WETH withdraw().
    /// Native rewards must use depositNativeRewards(); arbitrary direct transfers are donations.
    receive() external payable {}

    function contractURI() external view returns (string memory) { return metadataURI; }

    function getTokenInfo()
        external
        view
        returns (address deployer, string memory tokenLogo, string memory tokenDescription, Socials memory tokenSocials)
    {
        return (owner, logo, description, socials);
    }

    function initializeRewards(address depositor, address asset, address[] calldata excludedAccounts) external onlyOwner {
        require(!rewardsInitialized, "Already initialized");
        require(depositor != address(0), "Depositor zero");
        rewardsInitialized = true;
        rewardDepositor = depositor;
        rewardAsset = asset;
        _registerRewardAsset(asset, false);
        _setExcluded(address(this), true);
        for (uint256 i; i < excludedAccounts.length; ++i) _setExcluded(excludedAccounts[i], true);
        emit RewardsInitialized(depositor, asset);
    }

    function getHolderRewardAssets() external view returns (address[] memory) { return holderRewardAssets; }

    function rewardAssetConfig(address asset) external view returns (bool registered, bool unwrapOnClaim, uint256 rewardPerEligibleToken) {
        RewardState storage state = rewardStates[asset];
        return (state.registered, state.unwrapOnClaim, state.rewardPerEligibleToken);
    }

    function rewardStream(address asset)
        external
        view
        returns (uint256 rewardRate, uint256 periodFinish, uint256 lastUpdateTime, uint256 streamRemainder)
    {
        RewardState storage state = rewardStates[asset];
        return (state.rewardRate, state.periodFinish, state.lastUpdateTime, state.streamRemainder);
    }

    function transfer(address to, uint256 amount) external returns (bool) { _transfer(msg.sender, to, amount); return true; }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        require(allowed >= amount, "Allowance low");
        if (allowed != type(uint256).max) {
            allowance[from][msg.sender] = allowed - amount;
            emit Approval(from, msg.sender, allowance[from][msg.sender]);
        }
        _transfer(from, to, amount);
        return true;
    }

    function burn(uint256 amount) external {
        require(amount > 0 && balanceOf[msg.sender] >= amount, "Balance low");
        _checkpointAll(msg.sender);
        balanceOf[msg.sender] -= amount;
        totalSupply -= amount;
        if (!excludedFromRewards[msg.sender]) eligibleSupply -= amount;
        emit Transfer(msg.sender, address(0), amount);
        emit TokensBurned(msg.sender, amount);
    }

    function setExcludedFromRewards(address account, bool excluded) external onlyOwner {
        require(!rewardExclusionsLocked, "Exclusions locked");
        _setExcluded(account, excluded);
    }

    function lockRewardExclusions() external onlyOwner {
        require(rewardsInitialized && !rewardExclusionsLocked, "Exclusions locked");
        rewardExclusionsLocked = true;
        emit RewardExclusionsLocked();
    }

    /// @notice Registers a future ERC-20 holder reward. The immutable depositor controls deposits, not the owner.
    function registerHolderRewardAsset(address asset, bool unwrapOnClaim) external onlyOwner {
        require(rewardsInitialized && !rewardExclusionsLocked, "Registration locked");
        require(asset != address(0), "Use native deposit");
        _registerRewardAsset(asset, unwrapOnClaim);
    }

    /// @notice Enables automatic native payout for a registered wrapped-native reward asset.
    function enableWrappedNativeRewardUnwrap() external onlyOwner {
        require(rewardsInitialized && !rewardExclusionsLocked, "Registration locked");
        require(rewardAsset != address(0), "Native rewards");
        rewardStates[rewardAsset].unwrapOnClaim = true;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Owner zero");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function depositNativeRewards() external payable override {
        require(msg.sender == rewardDepositor, "Only depositor");
        _recordDeposit(address(0), msg.value);
    }

    function depositTokenRewards(uint256 amount) external override { _depositTokenRewards(rewardAsset, amount); }

    function depositTokenRewardsForAsset(address asset, uint256 amount) external { _depositTokenRewards(asset, amount); }

    /// @notice Depositor-only path for a newly selected reward asset after launch.
    function depositTokenRewardsForAsset(address asset, uint256 amount, bool unwrapOnClaim) external {
        require(msg.sender == rewardDepositor, "Only depositor");
        _registerRewardAsset(asset, unwrapOnClaim);
        _depositTokenRewards(asset, amount);
    }

    function claimableRewards(address account) public view returns (uint256) { return claimableRewards(account, rewardAsset); }

    function claimableRewards(address account, address asset) public view returns (uint256) {
        RewardState storage state = rewardStates[asset];
        if (!state.registered) return 0;
        uint256 rewardPerToken = _currentRewardPerEligibleToken(state);
        uint256 pending;
        if (!excludedFromRewards[account]) {
            pending = (balanceOf[account] * (rewardPerToken - userRewardIndex[account][asset])) / ACCURACY;
        }
        return storedRewards[account][asset] + pending;
    }

    function claimableRewardsFor(address account, address[] calldata assets) external view returns (uint256[] memory amounts) {
        amounts = new uint256[](assets.length);
        for (uint256 i; i < assets.length; ++i) amounts[i] = claimableRewards(account, assets[i]);
    }

    function claimRewards() external nonReentrant returns (uint256 amount) { return _claimReward(msg.sender, rewardAsset); }

    function claimRewards(address asset) external nonReentrant returns (uint256 amount) { return _claimReward(msg.sender, asset); }

    function claimAllRewards(address[] calldata assets) external nonReentrant returns (uint256[] memory amounts) {
        amounts = new uint256[](assets.length);
        for (uint256 i; i < assets.length; ++i) amounts[i] = _claimReward(msg.sender, assets[i]);
    }

    function _depositTokenRewards(address asset, uint256 amount) private nonReentrant {
        require(msg.sender == rewardDepositor, "Only depositor");
        require(asset != address(0) && rewardStates[asset].registered, "Reward asset unknown");
        uint256 beforeBalance = IERC20Upgrade(asset).balanceOf(address(this));
        require(IERC20Upgrade(asset).transferFrom(msg.sender, address(this), amount), "Reward transfer failed");
        _recordDeposit(asset, IERC20Upgrade(asset).balanceOf(address(this)) - beforeBalance);
    }

    function _claimReward(address holder, address asset) private returns (uint256 amount) {
        require(rewardStates[asset].registered, "Reward asset unknown");
        _checkpoint(holder, asset);
        amount = storedRewards[holder][asset];
        require(amount > 0, "Nothing to claim");
        storedRewards[holder][asset] = 0;
        if (asset == address(0)) {
            (bool paid,) = payable(holder).call{value: amount}("");
            require(paid, "Native claim failed");
        } else if (rewardStates[asset].unwrapOnClaim) {
            IWrappedNativeReward(asset).withdraw(amount);
            (bool paid,) = payable(holder).call{value: amount}("");
            require(paid, "Native claim failed");
        } else {
            require(IERC20Upgrade(asset).transfer(holder, amount), "Token claim failed");
        }
        totalHolderClaimed[asset] += amount;
        emit RewardsClaimed(holder, asset, amount);
    }

    function _recordDeposit(address asset, uint256 amount) private {
        require(rewardsInitialized && amount > 0 && eligibleSupply > 0, "Invalid reward deposit");
        RewardState storage state = rewardStates[asset];
        require(state.registered, "Reward asset unknown");
        _updateRewardState(state);
        uint256 carriedRewards = state.streamRemainder;
        if (block.timestamp < state.periodFinish) {
            carriedRewards += (uint256(state.periodFinish) - block.timestamp) * state.rewardRate;
        }
        uint256 streamAmount = amount + carriedRewards;
        state.rewardRate = streamAmount / HOLDER_REWARD_STREAM_DURATION;
        state.streamRemainder = streamAmount % HOLDER_REWARD_STREAM_DURATION;
        state.lastUpdateTime = uint64(block.timestamp);
        state.periodFinish = uint64(block.timestamp + HOLDER_REWARD_STREAM_DURATION);
        emit RewardsDeposited(asset, amount, state.rewardPerEligibleToken);
        emit RewardStreamUpdated(asset, state.rewardRate, state.periodFinish, carriedRewards);
    }

    function _registerRewardAsset(address asset, bool unwrapOnClaim) private {
        RewardState storage state = rewardStates[asset];
        if (state.registered) {
            if (unwrapOnClaim) state.unwrapOnClaim = true;
            return;
        }
        require(holderRewardAssets.length < MAX_REWARD_ASSETS, "Too many reward assets");
        state.registered = true;
        state.unwrapOnClaim = unwrapOnClaim;
        holderRewardAssets.push(asset);
        emit RewardAssetRegistered(asset, unwrapOnClaim);
    }

    function _transfer(address from, address to, uint256 amount) internal virtual {
        require(to != address(0) && balanceOf[from] >= amount, "Balance low");
        _checkpointAll(from);
        if (to != from) _checkpointAll(to);
        if (!excludedFromRewards[from] && excludedFromRewards[to]) eligibleSupply -= amount;
        if (excludedFromRewards[from] && !excludedFromRewards[to]) eligibleSupply += amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
    }

    function _checkpointAll(address account) private {
        for (uint256 i; i < holderRewardAssets.length; ++i) _checkpoint(account, holderRewardAssets[i]);
    }

    function _checkpoint(address account, address asset) private {
        RewardState storage state = rewardStates[asset];
        _updateRewardState(state);
        if (!excludedFromRewards[account]) {
            storedRewards[account][asset] +=
                (balanceOf[account] * (state.rewardPerEligibleToken - userRewardIndex[account][asset])) / ACCURACY;
        }
        userRewardIndex[account][asset] = state.rewardPerEligibleToken;
    }

    function _updateRewardState(RewardState storage state) private {
        uint256 applicable = block.timestamp < state.periodFinish ? block.timestamp : state.periodFinish;
        if (applicable <= state.lastUpdateTime) return;
        uint256 elapsed = applicable - state.lastUpdateTime;
        if (eligibleSupply == 0) {
            uint256 remainingDuration = uint256(state.periodFinish) - state.lastUpdateTime;
            state.lastUpdateTime = uint64(block.timestamp);
            state.periodFinish = uint64(block.timestamp + remainingDuration);
            return;
        }
        uint256 finalRemainder = applicable == state.periodFinish ? state.streamRemainder : 0;
        uint256 scaled = ((elapsed * state.rewardRate + finalRemainder) * ACCURACY) + state.undistributedRemainder;
        if (finalRemainder > 0) state.streamRemainder = 0;
        state.rewardPerEligibleToken += scaled / eligibleSupply;
        state.undistributedRemainder = scaled % eligibleSupply;
        state.lastUpdateTime = uint64(applicable);
    }

    function _currentRewardPerEligibleToken(RewardState storage state) private view returns (uint256) {
        if (eligibleSupply == 0) return state.rewardPerEligibleToken;
        uint256 applicable = block.timestamp < state.periodFinish ? block.timestamp : state.periodFinish;
        if (applicable <= state.lastUpdateTime) return state.rewardPerEligibleToken;
        uint256 finalRemainder = applicable == state.periodFinish ? state.streamRemainder : 0;
        uint256 scaled = (((applicable - state.lastUpdateTime) * state.rewardRate + finalRemainder) * ACCURACY)
            + state.undistributedRemainder;
        return state.rewardPerEligibleToken + (scaled / eligibleSupply);
    }

    function _setExcluded(address account, bool excluded) private {
        require(account != address(0), "Exclude zero");
        if (excludedFromRewards[account] == excluded) return;
        _checkpointAll(account);
        excludedFromRewards[account] = excluded;
        if (excluded) eligibleSupply -= balanceOf[account]; else eligibleSupply += balanceOf[account];
        emit RewardExclusionUpdated(account, excluded);
    }
}
