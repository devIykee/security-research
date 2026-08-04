// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface ISlvrGridLottery {
    function currentRoundId() external view returns (uint256);

    function roundEnd(uint256 roundId) external view returns (uint256);

    function roundOpen(uint256 roundId) external view returns (bool);
    
    function latestResolvedRoundId() external view returns (uint256);

    function betFor(uint256 roundId, address beneficiary, uint8[] calldata squares, uint256[] calldata amounts)
        external
        payable;

    function claim(uint256 roundId) external;

    /// @notice Unified claim function covering all claim variants
    /// @dev Handles: user vs delegate, native/SLVR recipients, bypassFee, ethOnly
    /// @param params Claim parameters struct
    function claimAdvanced(ClaimParams calldata params) external;

    struct ClaimParams {
        address user;           // User to claim for (must be msg.sender or delegate)
        uint256 roundId;        // Round to claim from
        address recipientNative; // Address to receive native (0 = user)
        address recipientSlvr;  // Address to receive SLVR (0 = user, or same as recipientNative)
        bool bypassFee;         // Skip refining fee (only if recipientSlvr is authorized permanent lock)
        bool ethOnly;           // If true, only claim ETH, leave SLVR unrefined in state
    }

    /// @notice Approve a delegate to claim rewards on your behalf to a recipient address
    /// @param delegate The address that will be allowed to claim on your behalf
    function approveDelegate(address delegate) external;

    /// @notice Revoke a delegate's approval to claim on your behalf
    /// @param delegate The address to revoke approval from
    function revokeDelegate(address delegate) external;

    /// @notice Check if a delegate is approved for a user
    /// @param user The user address
    /// @param delegate The delegate address
    /// @return Whether the delegate is approved
    function getDelegate(address user, address delegate) external view returns (bool);

    /// @notice Whether `contract_` may receive fee-bypassed (bypassFee=true) claims
    function authorizedPermanentLockContracts(address contract_) external view returns (bool);


    function getUserBet(uint256 roundId, uint8 square, address bettor) external view returns (uint256);

    function getHasClaimed(uint256 roundId, address user) external view returns (bool);

    function getHasAccount(address account) external view returns (bool);
    
    function getRound(uint256 roundId) external view returns (
        uint64 requestedAt,
        bool resolved,
        bytes32 randomnessId,
        uint256 randomnessValue,
        uint8 winningSquare,
        bool jackpotHit,
        bool singleMinerRound,
        address singleMinerWinner,
        uint256 totalWager,
        uint256 fee,
        uint256 winnerTotal,
        uint256 potForWinners,
        uint256 slvrForWinners,
        uint256 payoutMulWad,
        uint256 slvrMulWad,
        uint256 totalUnclaimedSlvr
    );

    /// @notice Donate SLVR tokens directly to jackpot pool
    /// @param amount Amount of SLVR to donate
    function donateSlvrToJackpot(uint256 amount) external;

    /// @notice Add ETH (native) tokens to jackpot pool
    /// @dev Called to deposit ETH to jackpot
    function addEthToJackpot() external payable;
}
