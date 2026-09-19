// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "./interface/IUniswapV2Factory.sol";
import "./interface/IUniswapV2Pair.sol";
import "./interface/ITokenLocker.sol";

import "./libs/TransferHelper.sol";
import "./libs/FullMath.sol";
import "./libs/SafeUniswapCall.sol";

contract TokenLocker is ITokenLocker, SafeUniswapCall, Ownable, ReentrancyGuard {
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableSet for EnumerableSet.Bytes32Set;

    // next lockId
    uint256 public nextLockId = 1;

    // lock detail
    mapping(uint256 lockId => LockInfo) public locks;

    // List of normal token lock ids for users
    mapping(address => EnumerableSet.UintSet) private userNormalLocks;
    // List of lp-token lock ids for users
    mapping(address => EnumerableSet.UintSet) private userLpLocks;

    // list of lock ids for token
    mapping(address => EnumerableSet.UintSet) private tokenLocks;

    // Cumulative lock info for token
    mapping(address => CumulativeLockInfo) public cumulativeInfos;

    // 
    uint256 constant DENOMINATOR = 10_000;

    // contains keccak(feeName)
    EnumerableSet.Bytes32Set private feeNameHashSet; 
    EnumerableSet.Bytes32Set private tokenSupportedFeeNames; 
    EnumerableSet.Bytes32Set private lpSupportedFeeNames; 
    // fees
    mapping(bytes32 nameHash => FeeStruct) public fees;
    address public feeReceiver;
    
    modifier validLockOwner(uint256 lockId_) {
        require(lockId_ < nextLockId, "Invalid lockId");
        require(locks[lockId_].owner == _msgSender(), "Not lock owner");
        _;
    }

    constructor(address feeReceiver_) Ownable(_msgSender()) {
        feeReceiver = feeReceiver_;
        addOrUpdateFee("TOKEN", 0, 12 * 10 ** 16, address(0), false);
        addOrUpdateFee("LP_ONLY", 50, 0, address(0), true);
        addOrUpdateFee("LP_AND_ETH", 25, 6 * 10 ** 16, address(0), true);
    }

    function addOrUpdateFee(string memory name_, uint24 lpFee_, uint256 lockFee_, address lockFeeToken_, bool isLp) public onlyOwner {
        bytes32 nameHash = keccak256(abi.encodePacked(name_));
        require(lpFee_ <= DENOMINATOR / 10, "lpFee");

        FeeStruct memory feeObj = FeeStruct(name_,  lockFee_, lockFeeToken_, lpFee_);
        fees[nameHash] = feeObj;
        if(feeNameHashSet.contains(nameHash)) {
            emit OnEditFee(nameHash, name_, lockFee_, lockFeeToken_, lpFee_, isLp);
        } else {
            feeNameHashSet.add(nameHash);
            emit OnAddFee(nameHash, name_, lockFee_, lockFeeToken_, lpFee_, isLp);
        }
        if(isLp) {
            if(!lpSupportedFeeNames.contains(nameHash))
                lpSupportedFeeNames.add(nameHash);
        } else {
            if(!tokenSupportedFeeNames.contains(nameHash))
                tokenSupportedFeeNames.add(nameHash);
        }
    }

    function updateFeeReceiver(address feeReceiver_) external onlyOwner {
        require(feeReceiver_ != address(0), "Zero Address");
        feeReceiver = feeReceiver_;
        emit FeeReceiverUpdated(feeReceiver_);
    }

    function _takeFee(address token_, uint256 amount, bytes32 nameHash) internal returns (bool isLpToken, uint256 newAmount){
        isLpToken = checkIsPair(token_);
        if(isLpToken) {
            require(lpSupportedFeeNames.contains(nameHash), "FeeName not supported for lpToken");
        }else {
            require(tokenSupportedFeeNames.contains(nameHash), "FeeName not supported for Token");
        }
        newAmount = amount;
        FeeStruct memory feeObj = fees[nameHash];
        if(isLpToken && feeObj.lpFee > 0) {
            uint256 lpFeeAmount = amount * feeObj.lpFee / DENOMINATOR;
            newAmount = amount - lpFeeAmount;
            TransferHelper.safeTransfer(token_, token_, lpFeeAmount);
            IUniswapV2Pair(token_).burn(feeReceiver);
        }
        if(feeObj.lockFee > 0) {
            if(feeObj.lockFeeToken == address(0)) {
                require(msg.value == feeObj.lockFee, "Fee");
                TransferHelper.safeTransferETH(feeReceiver, msg.value);
            } else {
                TransferHelper.safeTransferFrom(feeObj.lockFeeToken, _msgSender(), feeReceiver, feeObj.lockFee);
            }
        }
    }

    function _safeTransferFromEnsureAmount(
        address token_,
        address from_,
        uint256 amount_
    ) internal {
        uint256 balanceBefore = IERC20(token_).balanceOf(address(this));
        TransferHelper.safeTransferFrom(token_, from_, address(this), amount_);
        uint256 balanceAfter = IERC20(token_).balanceOf(address(this));
        require(balanceAfter - balanceBefore == amount_, "Received amount not enough");
        
    }

    function _addLock(
        address token_,
        bool isLpToken_,
        address owner_,
        uint256 amount_,
        uint256 endTime_,
        uint256 cycle_,
        uint24 tgeBps_,
        uint24 cycleBps_,
        bytes32 feeNameHash_
    ) internal returns (uint256 lockId) {
        lockId = nextLockId;
        locks[lockId] = LockInfo({
            lockId: lockId,
            token: token_,
            isLpToken: isLpToken_,
            pendingOwner: address(0),
            owner: owner_,
            amount: amount_,
            startTime: block.timestamp,
            endTime: endTime_,
            cycle: cycle_,
            tgeBps: tgeBps_,
            cycleBps: cycleBps_,
            unlockedAmount: 0,
            feeNameHash: feeNameHash_
        });
        nextLockId++;
    }

    /**
     * @dev should called in lock or lockWithPermit method
     */
    function _createLock( 
        address token_,
        string memory feeName_,
        address owner_,
        uint256 amount_,
        uint256 endTime_
    ) internal returns (uint256 lockId) {
        _safeTransferFromEnsureAmount(token_, _msgSender(), amount_);
        bytes32 nameHash = keccak256(abi.encodePacked(feeName_));
        (bool isLpToken_, uint256 newAmount) = _takeFee(token_, amount_, nameHash);
        lockId = _addLock(token_, isLpToken_, owner_, newAmount, endTime_, 0, 0, 0, nameHash);
        if(isLpToken_) {
            userLpLocks[owner_].add(lockId);
        } else {
            userNormalLocks[owner_].add(lockId);
        }
        tokenLocks[token_].add(lockId);
        cumulativeInfos[token_].amount += newAmount;
        emit OnLock(lockId, token_, owner_, newAmount, endTime_);
    }

    function lock(
        address token_,
        string memory feeName_,
        address owner_,
        uint256 amount_,
        uint256 endTime_
    ) external payable override nonReentrant returns (uint256 lockId) {
        require(token_ != address(0), "Invalid token");
        require(endTime_ > block.timestamp, "EndTime");
        require(amount_ > 0, "Amount is 0");
        
        lockId = _createLock(token_, feeName_, owner_, amount_, endTime_);
    }

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
    ) external payable override nonReentrant returns (uint256 lockId) {
        require(token_ != address(0), "Invalid token");
        require(endTime_ > block.timestamp, "EndTime <= currentTime");
        require(amount_ > 0, "Amount is 0");
        IERC20Permit(token_).permit(_msgSender(), address(this), amount_, deadline_, v, r, s);
        lockId = _createLock(token_, feeName_, owner_, amount_, endTime_);
    }

    function _vestingLock(VestingLockParams memory params, string memory feeName_) internal returns (uint256 lockId) {
        require(params.tgeTime > block.timestamp, "tgeTime <= currentTime");
        require(
            params.tgeBps > 0 && params.cycleBps > 0 
                && params.tgeBps + params.cycleBps <= DENOMINATOR, 
            "Invalid bips"
        );
        _safeTransferFromEnsureAmount(params.token, _msgSender(), params.amount);
        bytes32 nameHash = keccak256(abi.encodePacked(feeName_));
        (bool isLpToken, uint256 newAmount) = _takeFee(params.token, params.amount, nameHash);
        lockId = _addLock(
            params.token,
            isLpToken,
            params.owner,
            newAmount,
            params.tgeTime,
            params.cycle,
            params.tgeBps,
            params.cycleBps,
            nameHash
        );
        if(isLpToken) {
            userLpLocks[params.owner].add(lockId);
        } else {
            userNormalLocks[params.owner].add(lockId);
        }
        tokenLocks[params.token].add(lockId);
        cumulativeInfos[params.token].amount += newAmount;
        emit OnLock(lockId, params.token, params.owner, newAmount, params.tgeTime);
    }

    function vestingLock(
        VestingLockParams memory params,
        string memory feeName_
    ) external payable override nonReentrant returns (uint256 lockId) {
        require(params.token != address(0), "Invalid token");
        require(params.amount > 0, "Amount is 0");
        lockId = _vestingLock(params, feeName_);
    }

    function vestingLockWithPermit(
        VestingLockParams memory params,
        string memory feeName_,
        uint256 deadline_,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external payable override nonReentrant returns (uint256 lockId) {
        require(params.token != address(0), "Invalid token");
        require(params.amount > 0, "Amount is 0");
        IERC20Permit(params.token).permit(_msgSender(), address(this), params.amount, deadline_, v, r, s);
        lockId = _vestingLock(params, feeName_);
    }

    function _updateLock(
        uint256 lockId_,
        uint256 moreAmount_,
        uint256 newEndTime_ 
    ) internal {
        LockInfo storage userLock = locks[lockId_];
        require(userLock.unlockedAmount == 0, "Unlocked");
        require(
            newEndTime_ > userLock.endTime && newEndTime_ > block.timestamp,
            "New EndTime not allowed"
        );
        address lockOwner = _msgSender();
        _safeTransferFromEnsureAmount(userLock.token, lockOwner, moreAmount_);
        (, uint256 newAmount) = _takeFee(userLock.token, moreAmount_, userLock.feeNameHash);

        userLock.amount += newAmount;
        userLock.endTime = newEndTime_;
        cumulativeInfos[userLock.token].amount += newAmount;
        emit OnUpdated(
            lockId_,
            userLock.token,
            lockOwner,
            userLock.amount,
            newEndTime_
        );
    }

    /**
     * @param lockId_  lockId in tokenLocks
     * @param moreAmount_  the amount to increase
     * @param newEndTime_  new endtime must gt old
     */
    function updateLock(
        uint256 lockId_,
        uint256 moreAmount_,
        uint256 newEndTime_
    ) external payable override validLockOwner(lockId_) nonReentrant {
        require(moreAmount_ > 0, "MoreAmount is 0");
        _updateLock(lockId_, moreAmount_, newEndTime_);
    }

    function updateLockWitPermit(
        uint256 lockId_,
        uint256 moreAmount_,
        uint256 newEndTime_,
        uint256 deadline_,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external payable override validLockOwner(lockId_) nonReentrant {
        require(moreAmount_ > 0, "MoreAmount is 0");
        IERC20Permit(locks[lockId_].token).permit(_msgSender(), address(this), moreAmount_, deadline_, v, r, s);
        _updateLock(lockId_, moreAmount_, newEndTime_);
    }

    function transferLock(
        uint256 lockId_,
        address newOwner_
    ) external override validLockOwner(lockId_) {
        locks[lockId_].pendingOwner = newOwner_;
        emit OnLockPendingTransfer(lockId_, _msgSender(), newOwner_);
    }

    function acceptLock(uint256 lockId_) external override {
        require(lockId_ < nextLockId, "Invalid lockId");
        address newOwner = _msgSender();
        // check new owner
        require(newOwner == locks[lockId_].pendingOwner, "Not pendingOwner");
        // emit event
        emit OnLockTransferred(lockId_, locks[lockId_].owner, newOwner);

        if(locks[lockId_].isLpToken) {
            userLpLocks[locks[lockId_].owner].remove(lockId_);
            userLpLocks[newOwner].add(lockId_);
        } else {
            // remove lockId from owner
            userNormalLocks[locks[lockId_].owner].remove(lockId_);
            // add lockId to new Owner
            userNormalLocks[newOwner].add(lockId_);
        }
        // set owner
        locks[lockId_].pendingOwner = address(0);
        locks[lockId_].owner = newOwner;
    }

    function unlock(
        uint256 lockId_
    ) external override validLockOwner(lockId_) nonReentrant {
        LockInfo storage lockInfo = locks[lockId_];
        if (lockInfo.tgeBps > 0) {
            _vestingUnlock(lockInfo);
        } else {
            _normalUnlock(lockInfo);
        }
    }

    function _normalUnlock(LockInfo storage lockInfo) internal {
        require(block.timestamp >= lockInfo.endTime, "Before endTime");
        if(lockInfo.isLpToken) {
            userLpLocks[lockInfo.owner].remove(lockInfo.lockId);
        } else {
            userNormalLocks[lockInfo.owner].remove(lockInfo.lockId);
        }
        tokenLocks[lockInfo.token].remove(lockInfo.lockId);
        TransferHelper.safeTransfer(
            lockInfo.token,
            lockInfo.owner,
            lockInfo.amount
        );
        cumulativeInfos[lockInfo.token].amount -= lockInfo.amount;
        emit OnUnlock(
            lockInfo.lockId,
            lockInfo.token,
            lockInfo.owner,
            lockInfo.amount,
            block.timestamp
        );
        lockInfo.unlockedAmount = lockInfo.amount;
        lockInfo.amount = 0;
    }

    function _vestingUnlock(LockInfo storage lockInfo) internal {
        uint256 withdrawable = _withdrawableTokens(lockInfo);
        uint256 newTotalUnlockAmount = lockInfo.unlockedAmount + withdrawable;
        require(
            withdrawable > 0 && newTotalUnlockAmount <= lockInfo.amount,
            "Nothing to unlock"
        );
        uint256 left = lockInfo.amount - newTotalUnlockAmount;
        if (left == 0) {
            lockInfo.amount = 0;
            tokenLocks[lockInfo.token].remove(lockInfo.lockId);
            if(lockInfo.isLpToken) {
                userLpLocks[lockInfo.owner].remove(lockInfo.lockId);
            } else {
                userNormalLocks[lockInfo.owner].remove(lockInfo.lockId);
            }
            emit OnUnlock(
                lockInfo.lockId,
                lockInfo.token,
                msg.sender,
                newTotalUnlockAmount,
                block.timestamp
            );
        }
        lockInfo.unlockedAmount = newTotalUnlockAmount;

        TransferHelper.safeTransfer(
            lockInfo.token,
            lockInfo.owner,
            withdrawable
        );
        cumulativeInfos[lockInfo.token].amount -= withdrawable;
        emit OnLockVested(
            lockInfo.lockId,
            lockInfo.token,
            _msgSender(),
            withdrawable,
            left,
            block.timestamp
        );
    }

    function _withdrawableTokens(
        LockInfo memory userLock
    ) internal view returns (uint256) {
        if (userLock.amount == 0) return 0;
        if (userLock.unlockedAmount >= userLock.amount) return 0;
        if (block.timestamp < userLock.endTime) return 0;
        if (userLock.cycle == 0) return 0;

        uint256 tgeReleaseAmount = FullMath.mulDiv(
            userLock.amount,
            userLock.tgeBps,
            DENOMINATOR
        );
        uint256 cycleReleaseAmount = FullMath.mulDiv(
            userLock.amount,
            userLock.cycleBps,
            DENOMINATOR
        );
        uint256 currentTotal = 0;
        if (block.timestamp >= userLock.endTime) {
            currentTotal =
                (((block.timestamp - userLock.endTime) / userLock.cycle) *
                    cycleReleaseAmount) +
                tgeReleaseAmount;
        }
        uint256 withdrawable = 0;
        if (currentTotal > userLock.amount) {
            withdrawable = userLock.amount - userLock.unlockedAmount;
        } else {
            withdrawable = currentTotal - userLock.unlockedAmount;
        }
        return withdrawable;
    }

    function withdrawableTokens(
        uint256 lockId_
    ) external override view returns (uint256) {
        LockInfo memory userLock = locks[lockId_];
        return _withdrawableTokens(userLock);
    }

    function getUserNormalLocks(
        address user
    ) external view returns (uint256[] memory lockIds) {
        return userNormalLocks[user].values();
    }

    function getUserLpLocks(
        address user
    ) external view returns (uint256[] memory lockIds) {
        return userLpLocks[user].values();
    }

    function getTokenLocks(
        address token
    ) external view returns (uint256[] memory lockIds) {
        return tokenLocks[token].values();
    }

}
