// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title ISlvrJackpot
/// @notice Interface for the jackpot contract
interface ISlvrJackpot {
    // Pool queries
    function jackpotPool() external view returns (uint256);
    function jackpotSlvrPool() external view returns (uint256);
    function bribePool(address token) external view returns (uint256);
    function whitelistedBribeTokens(address token) external view returns (bool);
    
    // Deposit functions
    function addEth() external payable;
    function addSlvr(uint256 amount) external;
    function depositBribe(address token, uint256 amount) external;
    
    // Lottery interaction
    function checkAndApply(uint256 randomnessValue, uint256 roundId, uint256 winnerTotal) 
        external returns (bool hit, uint256 ethBonus, uint256 slvrBonus);
    
    // Distribution (called by lottery after jackpot hits)
    function distributeBribes(uint256 roundId) external returns (address[] memory tokens, uint256[] memory amounts);
    
    // Bribe distribution to winner (called by lottery during claim)
    function distributeBribesToWinner(uint256 roundId, address winner, uint256 userBet, uint256 winnerTotal) external;
    
    // Admin
    function setBribeTokenWhitelist(address token, bool whitelisted) external;
    function setOdds(uint256 newOdds) external;
    function setLottery(address lottery) external;
    
    // Optional: Migration function to transfer funds to new contract
    function migrateTo(address newJackpot) external;
    
    // View functions
    function getBribeDistribution(uint256 roundId, address token) external view returns (uint256);
    function getWhitelistedTokens() external view returns (address[] memory);
}

