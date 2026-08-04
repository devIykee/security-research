// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title HoodCash MiningPool
 * @notice "Virtual mining" for Robinhood Chain.
 *
 * Robinhood Chain is an L2 (no PoW mining), so HoodCash "mining" works
 * through staking: Genesis Miner NFT holders stake their NFT in this
 * contract and earn HCASH per second. A VPS bot (see vps-miner/) calls
 * claim() periodically so rewards are "mined" automatically 24/7.
 *
 * Default parameters:
 *  - REWARD_PER_NFT_PER_DAY = 60 HCASH
 *  - 400 NFTs x 60 HCASH x 365 days x 4 years = 35.04M HCASH
 *    (below the 40M mining allocation; the remainder is a buffer/bonus events)
 */
contract MiningPool is Ownable, ReentrancyGuard, IERC721Receiver {
    using SafeERC20 for IERC20;

    IERC20 public immutable rewardToken; // HCASH
    IERC721 public immutable minerNFT;   // Genesis Miner

    /// @notice Reward per NFT per second (default: 250e18 / 86400).
    uint256 public rewardPerNFTPerSecond;

    /// @notice Timestamp when emission ends (4 years after deploy).
    uint256 public immutable emissionEnd;

    struct StakeInfo {
        address owner;
        uint64 stakedAt;
        uint64 lastClaim;
    }

    mapping(uint256 => StakeInfo) public stakes;        // tokenId => info
    mapping(address => uint256[]) private _stakedTokens; // owner => tokenIds
    uint256 public totalStaked;

    event Staked(address indexed user, uint256 indexed tokenId);
    event Unstaked(address indexed user, uint256 indexed tokenId);
    event Claimed(address indexed user, uint256 amount);
    event RewardRateUpdated(uint256 newRate);

    constructor(
        address initialOwner,
        address _rewardToken,
        address _minerNFT
    ) Ownable(initialOwner) {
        rewardToken = IERC20(_rewardToken);
        minerNFT = IERC721(_minerNFT);
        rewardPerNFTPerSecond = uint256(60 ether) / 1 days; // 60 HCASH/day
        emissionEnd = block.timestamp + 4 * 365 days;
    }

    // --------------------------------------------------------------- stake --

    function stake(uint256[] calldata tokenIds) external nonReentrant {
        require(tokenIds.length > 0, "No tokens");
        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 id = tokenIds[i];
            minerNFT.transferFrom(msg.sender, address(this), id);
            stakes[id] = StakeInfo({
                owner: msg.sender,
                stakedAt: uint64(block.timestamp),
                lastClaim: uint64(block.timestamp)
            });
            _stakedTokens[msg.sender].push(id);
            emit Staked(msg.sender, id);
        }
        totalStaked += tokenIds.length;
    }

    function unstake(uint256[] calldata tokenIds) external nonReentrant {
        uint256 reward = 0;
        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 id = tokenIds[i];
            StakeInfo memory info = stakes[id];
            require(info.owner == msg.sender, "Not staker");

            reward += _pendingFor(info);
            delete stakes[id];
            _removeFromList(msg.sender, id);
            minerNFT.transferFrom(address(this), msg.sender, id);
            emit Unstaked(msg.sender, id);
        }
        totalStaked -= tokenIds.length;
        if (reward > 0) _payout(msg.sender, reward);
    }

    /// @notice Claim rewards for all staked NFTs (called by the VPS bot).
    function claim() external nonReentrant {
        uint256 reward = 0;
        uint256[] storage ids = _stakedTokens[msg.sender];
        for (uint256 i = 0; i < ids.length; i++) {
            StakeInfo storage info = stakes[ids[i]];
            reward += _pendingFor(info);
            info.lastClaim = uint64(block.timestamp);
        }
        require(reward > 0, "Nothing to claim");
        _payout(msg.sender, reward);
    }

    // --------------------------------------------------------------- views --

    function pendingRewards(address user) external view returns (uint256) {
        uint256 reward = 0;
        uint256[] storage ids = _stakedTokens[user];
        for (uint256 i = 0; i < ids.length; i++) {
            reward += _pendingFor(stakes[ids[i]]);
        }
        return reward;
    }

    function stakedTokensOf(address user)
        external
        view
        returns (uint256[] memory)
    {
        return _stakedTokens[user];
    }

    // --------------------------------------------------------------- admin --

    /// @notice Owner can adjust the emission rate (max 1000 HCASH/day/NFT).
    function setRewardRate(uint256 perNFTPerSecond) external onlyOwner {
        require(perNFTPerSecond <= uint256(1000 ether) / 1 days, "Rate too high");
        rewardPerNFTPerSecond = perNFTPerSecond;
        emit RewardRateUpdated(perNFTPerSecond);
    }

    /// @notice Withdraw any leftover HCASH after emission ends (not user NFTs).
    function sweepUnusedRewards(address to) external onlyOwner {
        require(block.timestamp > emissionEnd, "Emission ongoing");
        rewardToken.safeTransfer(to, rewardToken.balanceOf(address(this)));
    }

    // ------------------------------------------------------------ internal --

    function _pendingFor(StakeInfo memory info)
        internal
        view
        returns (uint256)
    {
        if (info.owner == address(0)) return 0;
        uint256 until = block.timestamp < emissionEnd
            ? block.timestamp
            : emissionEnd;
        if (until <= info.lastClaim) return 0;
        return (until - info.lastClaim) * rewardPerNFTPerSecond;
    }

    function _payout(address to, uint256 amount) internal {
        uint256 balance = rewardToken.balanceOf(address(this));
        uint256 pay = amount > balance ? balance : amount;
        require(pay > 0, "Pool empty");
        rewardToken.safeTransfer(to, pay);
        emit Claimed(to, pay);
    }

    function _removeFromList(address user, uint256 tokenId) internal {
        uint256[] storage ids = _stakedTokens[user];
        for (uint256 i = 0; i < ids.length; i++) {
            if (ids[i] == tokenId) {
                ids[i] = ids[ids.length - 1];
                ids.pop();
                return;
            }
        }
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}
