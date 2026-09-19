// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface ITokenLocker{

    struct VestingLockParams {
        address token;
        uint24 tgeBps;
        uint24 cycleBps;
        address owner;
        uint256 amount;
        uint256 tgeTime;
        uint256 cycle;
    }

    struct LockInfo {
        uint256 lockId;
        address token;
        bool isLpToken;
        address pendingOwner;
        address owner;
        uint24 tgeBps; // In bips. Is 0 for normal locks
        uint24 cycleBps; // In bips. Is 0 for normal locks
        uint256 amount;
        uint256 startTime;
        uint256 endTime; // unlock time for normal locks, and TGE time for vesting locks
        uint256 cycle; // 0: normal locks
        uint256 unlockedAmount;
        bytes32 feeNameHash;
    }

    struct CumulativeLockInfo {
        address factory;
        uint256 amount;
    }

    struct FeeStruct {
        string name;
        uint256 lockFee;
        address lockFeeToken;
        uint24 lpFee;
    }

    event OnLock(
        uint256 indexed lockId,
        address token,
        address owner,
        uint256 amount,
        uint256 endTime
    );
    event OnUpdated(
        uint256 indexed lockId,
        address token,
        address owner,
        uint256 newAmount,
        uint256 newEndTime
    );
    event OnUnlock(
        uint256 indexed lockId,
        address token,
        address owner,
        uint256 amount,
        uint256 unlockedTime
    );
    event OnLockVested(
        uint256 indexed lockId,
        address token,
        address owner,
        uint256 unlockAmount,
        uint256 left,
        uint256 vestTime
    );
    event OnLockPendingTransfer(
        uint256 indexed lockId,
        address previousOwner,
        address newOwner
    );
    event OnLockTransferred(
        uint256 indexed lockId,
        address previousOwner,
        address newOwner
    );
    event FeeReceiverUpdated(address feeReceiver);
    event OnAddFee(bytes32 nameHash, string name, uint256 lockFee, address lockFeeToken, uint24 lpFee, bool isLp);
    event OnEditFee(bytes32 nameHash, string name, uint256 lockFee, address lockFeeToken, uint24 lpFee, bool isLp);

    function lock(
        address token_,
        string memory feeName_,
        address owner_,
        uint256 amount_,
        uint256 endTime_
    ) external payable returns (uint256 lockId);

    function lockWithPermit(
        address token_,
        string memory feeName_,
        address owner_,
        uint256 amount_,
        uint256 endTime_,
        uint256 deadline_,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external payable returns (uint256 lockId);

    function vestingLock(
        VestingLockParams memory params,
        string memory feeName_
    ) external payable returns (uint256 lockId);

    function vestingLockWithPermit(
        VestingLockParams memory params,
        string memory feeName_,
        uint256 deadline_,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external payable returns (uint256 lockId);

    function updateLock(
        uint256 lockId_,
        uint256 moreAmount_,
        uint256 newEndTime_
    ) external payable;

    function updateLockWitPermit(
        uint256 lockId_,
        uint256 moreAmount_,
        uint256 newEndTime_,
        uint256 deadline_,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external payable;

    function transferLock(
        uint256 lockId_,
        address newOwner_
    ) external;

    function acceptLock(uint256 lockId_) external;

    function unlock(
        uint256 lockId_
    ) external;

    function withdrawableTokens(
        uint256 lockId_
    ) external view returns (uint256);
}