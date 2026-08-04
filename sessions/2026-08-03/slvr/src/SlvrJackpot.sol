// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {ISlvrJackpot} from "./interfaces/ISlvrJackpot.sol";
import {SlvrToken} from "./SlvrToken.sol";
import {RandomnessLib} from "./libraries/RandomnessLib.sol";

/// @title SlvrJackpot
/// @notice Separate contract for jackpot functionality with upgradeability support
/// @dev Can be upgraded by pointing lottery to a new implementation
contract SlvrJackpot is ISlvrJackpot, ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    uint256 public constant JACKPOT_ODDS = 625; // 1/625 chance to hit
    uint256 public constant MAX_BRIBE_BATCH_SIZE = 50; // Maximum tokens to process per batch to prevent DoS

    address public lottery; // Only lottery can call checkAndApply
    SlvrToken public immutable SLVR;
    
    uint256 public jackpotPool; // ETH pool
    uint256 public jackpotSlvrPool; // SLVR pool
    uint256 private lastKnownSlvrBalance; // Track actual token balance for verification
    
    // Bribe system
    mapping(address => bool) public whitelistedBribeTokens;
    mapping(address => uint256) public bribePools;
    address[] public whitelistedTokensList;
    mapping(uint256 => mapping(address => uint256)) public bribeDistributions; // roundId => token => amount
    mapping(uint256 => address[]) public distributedTokensPerRound; // roundId => tokens that were distributed
    mapping(uint256 => bool) public bribesDistributed; // roundId => whether bribes have been distributed
    mapping(uint256 => uint256) public bribeDistributionIndex; // roundId => last processed token index
    mapping(uint256 => mapping(address => bool)) public claimed; // roundId => winner => whether claimed
    
    uint256 public jackpotOdds = JACKPOT_ODDS; // Configurable odds

    event JackpotAccrued(uint256 indexed throughRoundId, uint256 added, uint256 newPool);
    event JackpotSlvrDonated(uint256 indexed roundId, uint256 amount, uint256 newSlvrPool);
    event BribeTokenWhitelisted(address indexed token, bool whitelisted);
    event BribeDeposited(address indexed token, uint256 amount, uint256 newPool);
    event BribeDistributed(address indexed token, uint256 indexed roundId, uint256 totalAmount);
    event JackpotHit(uint256 indexed roundId, uint256 ethBonus, uint256 slvrBonus);
    event OddsUpdated(uint256 oldOdds, uint256 newOdds);
    event LotteryUpdated(address oldLottery, address newLottery);
    event PoolCleared(uint256 indexed roundId, uint256 ethAmount, uint256 slvrAmount);

    constructor(address slvr_, address owner_) Ownable(owner_) {
        require(slvr_ != address(0), "slvr=0");
        require(owner_ != address(0), "owner=0");
        SLVR = SlvrToken(payable(slvr_));
    }

    /// @notice Set the lottery contract address (only owner)
    function setLottery(address lottery_) external override onlyOwner {
        require(lottery_ != address(0), "lottery=0");
        address oldLottery = lottery;
        lottery = lottery_;
        emit LotteryUpdated(oldLottery, lottery_);
    }

    /// @notice Set jackpot odds (only owner)
    function setOdds(uint256 newOdds) external override onlyOwner {
        require(newOdds > 0, "odds=0");
        uint256 oldOdds = jackpotOdds;
        jackpotOdds = newOdds;
        emit OddsUpdated(oldOdds, newOdds);
    }

    /// @notice Add ETH to jackpot pool (anyone can call, e.g., from swapback)
    function addEth() external payable override {
        require(msg.value > 0, "no value");
        jackpotPool += msg.value;
        // Use current block timestamp as round ID approximation (lottery will emit proper event)
        emit JackpotAccrued(block.timestamp, msg.value, jackpotPool);
    }

    /// @notice Add SLVR to jackpot pool
    /// @dev Performs the transfer from caller and credits the actual amount received
    /// @dev Handles fee-on-transfer tokens correctly by crediting actual balance delta
    /// @param amount Amount of SLVR to transfer from caller
    function addSlvr(uint256 amount) external override nonReentrant {
        require(amount > 0, "amount=0");
        
        // Get balance before transfer
        uint256 beforeBal = SLVR.balanceOf(address(this));
        
        // Transfer tokens from caller to this contract
        IERC20(address(SLVR)).safeTransferFrom(msg.sender, address(this), amount);
        
        // Calculate actual amount received (handles fee-on-transfer tokens)
        uint256 received = SLVR.balanceOf(address(this)) - beforeBal;
        require(received > 0, "no tokens received");
        
        // Update pool and tracked balance with actual amount received
        jackpotSlvrPool += received;
        lastKnownSlvrBalance = SLVR.balanceOf(address(this));
        
        // Use current block timestamp as round ID approximation
        emit JackpotSlvrDonated(block.timestamp, received, jackpotSlvrPool);
    }

    /// @notice Check if jackpot hits and apply it
    /// @dev Only lottery can call this
    /// @param randomnessValue The randomness value from the round
    /// @param roundId The round ID
    /// @param winnerTotal Total bet amount on winning square (0 if no winners)
    /// @return hit Whether jackpot hit
    /// @return ethBonus ETH amount to add to pot (0 if no hit or no winners)
    /// @return slvrBonus SLVR amount to add to pot (0 if no hit or no winners)
    function checkAndApply(
        uint256 randomnessValue,
        uint256 roundId,
        uint256 winnerTotal
    ) external override nonReentrant returns (bool hit, uint256 ethBonus, uint256 slvrBonus) {
        require(msg.sender == lottery, "only lottery");
        
        if (winnerTotal == 0) {
            return (false, 0, 0);
        }

        uint256 rv1 = RandomnessLib.deriveJackpotRandomness(randomnessValue, roundId);
        hit = RandomnessLib.checkJackpotHit(rv1, jackpotOdds);

        if (hit) {
            ethBonus = jackpotPool;
            slvrBonus = jackpotSlvrPool;
            
            // Transfer funds to lottery contract
            if (ethBonus > 0) {
                jackpotPool = 0; // Reset before transfer
                (bool success,) = payable(lottery).call{value: ethBonus}("");
                require(success, "ETH transfer failed");
            }
            if (slvrBonus > 0) {
                jackpotSlvrPool = 0; // Reset before transfer
                require(SLVR.transfer(lottery, slvrBonus), "SLVR transfer failed");
                // Update tracked balance after transfer
                lastKnownSlvrBalance = SLVR.balanceOf(address(this));
            }
            
            emit JackpotHit(roundId, ethBonus, slvrBonus);
            emit PoolCleared(roundId, ethBonus, slvrBonus);
        }
    }

    /// @notice Distribute bribe tokens when jackpot hits (processes up to MAX_BRIBE_BATCH_SIZE tokens)
    /// @dev Only lottery can call this. May need to call continueDistributeBribes if there are more tokens.
    /// @param roundId The round ID where jackpot hit
    /// @return tokens Array of token addresses that were distributed in this batch
    /// @return amounts Array of amounts distributed (parallel to tokens)
    function distributeBribes(uint256 roundId) 
        external 
        override 
        returns (address[] memory tokens, uint256[] memory amounts) 
    {
        require(msg.sender == lottery, "only lottery");
        require(!bribesDistributed[roundId], "already distributed");
        
        uint256 startIndex = bribeDistributionIndex[roundId];
        uint256 tokenCount = whitelistedTokensList.length;
        uint256 endIndex = startIndex + MAX_BRIBE_BATCH_SIZE;
        if (endIndex > tokenCount) {
            endIndex = tokenCount;
        }
        
        // Pre-allocate arrays for the batch
        uint256 batchSize = endIndex - startIndex;
        tokens = new address[](batchSize);
        amounts = new uint256[](batchSize);
        uint256 actualCount = 0;

        // Process tokens in this batch
        for (uint256 i = startIndex; i < endIndex; i++) {
            address token = whitelistedTokensList[i];
            uint256 bribeAmount = bribePools[token];
            if (bribeAmount > 0) {
                // Record the distribution for this round
                bribeDistributions[roundId][token] = bribeAmount;
                // Track which tokens were distributed (needed for claims even if token is later removed from whitelist)
                distributedTokensPerRound[roundId].push(token);
                // Clear the pool (tokens stay in contract until claimed)
                bribePools[token] = 0;
                emit BribeDistributed(token, roundId, bribeAmount);

                tokens[actualCount] = token;
                amounts[actualCount] = bribeAmount;
                actualCount++;
            }
        }

        // Update the index for next batch
        bribeDistributionIndex[roundId] = endIndex;
        
        // Check if distribution is complete
        if (endIndex >= tokenCount) {
            bribesDistributed[roundId] = true;
        }

        // Resize arrays if needed (some tokens might have 0 balance)
        if (actualCount < batchSize) {
            assembly ("memory-safe") {
                mstore(tokens, actualCount)
                mstore(amounts, actualCount)
            }
        }
    }

    /// @notice Continue distributing bribe tokens for a round (for pagination)
    /// @dev Only lottery can call this. Call this if distributeBribes didn't complete all tokens.
    /// @param roundId The round ID where jackpot hit
    /// @return tokens Array of token addresses that were distributed in this batch
    /// @return amounts Array of amounts distributed (parallel to tokens)
    /// @return completed Whether all tokens have been processed
    function continueDistributeBribes(uint256 roundId) 
        external 
        returns (address[] memory tokens, uint256[] memory amounts, bool completed) 
    {
        require(msg.sender == lottery, "only lottery");
        require(!bribesDistributed[roundId], "already distributed");
        
        uint256 startIndex = bribeDistributionIndex[roundId];
        uint256 tokenCount = whitelistedTokensList.length;
        require(startIndex < tokenCount, "no tokens to process");
        
        uint256 endIndex = startIndex + MAX_BRIBE_BATCH_SIZE;
        if (endIndex > tokenCount) {
            endIndex = tokenCount;
        }
        
        // Pre-allocate arrays for the batch
        uint256 batchSize = endIndex - startIndex;
        tokens = new address[](batchSize);
        amounts = new uint256[](batchSize);
        uint256 actualCount = 0;

        // Process tokens in this batch
        for (uint256 i = startIndex; i < endIndex; i++) {
            address token = whitelistedTokensList[i];
            uint256 bribeAmount = bribePools[token];
            if (bribeAmount > 0) {
                // Record the distribution for this round
                bribeDistributions[roundId][token] = bribeAmount;
                // Track which tokens were distributed (needed for claims even if token is later removed from whitelist)
                distributedTokensPerRound[roundId].push(token);
                // Clear the pool (tokens stay in contract until claimed)
                bribePools[token] = 0;
                emit BribeDistributed(token, roundId, bribeAmount);

                tokens[actualCount] = token;
                amounts[actualCount] = bribeAmount;
                actualCount++;
            }
        }

        // Update the index for next batch
        bribeDistributionIndex[roundId] = endIndex;
        
        // Check if distribution is complete
        completed = (endIndex >= tokenCount);
        if (completed) {
            bribesDistributed[roundId] = true;
        }

        // Resize arrays if needed (some tokens might have 0 balance)
        if (actualCount < batchSize) {
            assembly ("memory-safe") {
                mstore(tokens, actualCount)
                mstore(amounts, actualCount)
            }
        }
    }

    /// @notice Distribute bribes pro-rata to a winner based on their bet amount
    /// @dev Only lottery can call this
    /// @dev Uses the tokens that were actually distributed for this round (stored in distributedTokensPerRound)
    ///      This ensures tokens can be claimed even if they're later removed from the whitelist
    /// @param roundId The round ID where jackpot hit
    /// @param winner The winner address claiming rewards
    /// @param userBet The winner's bet amount on the winning square
    /// @param winnerTotal The total bet amount on the winning square
    function distributeBribesToWinner(
        uint256 roundId,
        address winner,
        uint256 userBet,
        uint256 winnerTotal
    ) external override {
        require(msg.sender == lottery, "only lottery");
        require(winnerTotal > 0, "winnerTotal=0");
        require(userBet <= winnerTotal, "userBet>winnerTotal");
        require(!claimed[roundId][winner], "already claimed");
        
        // Use the tokens that were actually distributed for this round
        // This ensures tokens can be claimed even if they're later removed from whitelist
        address[] memory tokens = distributedTokensPerRound[roundId];
        uint256 tokenCount = tokens.length;
        
        for (uint256 i = 0; i < tokenCount; i++) {
            address token = tokens[i];
            uint256 totalBribe = bribeDistributions[roundId][token];
            if (totalBribe > 0) {
                // Calculate pro-rata share: (userBet / winnerTotal) * totalBribe
                uint256 bribeShare = (userBet * totalBribe) / winnerTotal;
                if (bribeShare > 0) {
                    // Transfer bribe tokens to winner
                    IERC20(token).safeTransfer(winner, bribeShare);
                }
            }
        }
        
        // Mark as claimed after successful distribution
        claimed[roundId][winner] = true;
    }

    /// @notice Whitelist or remove a token from the bribe whitelist
    /// @dev Only owner or lottery contract (if lottery owner matches jackpot owner) can call this
    function setBribeTokenWhitelist(address token, bool whitelisted) external override {
        // Allow lottery contract to call this if lottery owner matches jackpot owner
        if (msg.sender == lottery && lottery != address(0)) {
            // Verify lottery owner matches jackpot owner
            // Use staticcall to check lottery's owner without modifying state
            (bool success, bytes memory data) = lottery.staticcall(abi.encodeWithSignature("owner()"));
            require(success, "owner check failed");
            address lotteryOwner = abi.decode(data, (address));
            require(lotteryOwner == owner(), "lottery owner mismatch");
        } else {
            require(msg.sender == owner(), "not owner");
        }
        require(token != address(0), "token=0");
        require(token != address(SLVR), "cannot whitelist SLVR");
        
        bool wasWhitelisted = whitelistedBribeTokens[token];
        whitelistedBribeTokens[token] = whitelisted;
        
        // Manage the list for iteration
        if (whitelisted && !wasWhitelisted) {
            whitelistedTokensList.push(token);
        } else if (!whitelisted && wasWhitelisted) {
            // Remove from list (swap with last element and pop)
            for (uint256 i = 0; i < whitelistedTokensList.length; i++) {
                if (whitelistedTokensList[i] == token) {
                    whitelistedTokensList[i] = whitelistedTokensList[whitelistedTokensList.length - 1];
                    whitelistedTokensList.pop();
                    break;
                }
            }
        }
        
        emit BribeTokenWhitelisted(token, whitelisted);
    }

    /// @notice Deposit tokens as a bribe to the jackpot pool
    /// @dev Always transfers tokens from caller to prevent double-allocation risk
    /// @dev Performs the transfer from caller and credits the actual amount received
    /// @dev Handles fee-on-transfer tokens correctly by crediting actual balance delta
    /// @dev If lottery needs to deposit on behalf of users, it should hold allowance and call this normally
    function depositBribe(address token, uint256 amount) external override nonReentrant {
        require(token != address(0), "token=0");
        require(whitelistedBribeTokens[token], "token not whitelisted");
        require(amount > 0, "amount=0");

        // Get balance before transfer
        IERC20 tokenContract = IERC20(token);
        uint256 beforeBal = tokenContract.balanceOf(address(this));
        
        // Transfer tokens from caller to this contract
        tokenContract.safeTransferFrom(msg.sender, address(this), amount);
        
        // Calculate actual amount received (handles fee-on-transfer tokens)
        uint256 afterBal = tokenContract.balanceOf(address(this));
        uint256 received = afterBal - beforeBal;
        require(received > 0, "no tokens received");
        
        // Update pool with actual amount received (ensures accounting accuracy)
        bribePools[token] += received;

        emit BribeDeposited(token, received, bribePools[token]);
    }

    /// @notice Get bribe pool for a token (implements interface)
    function bribePool(address token) external view override returns (uint256) {
        return bribePools[token];
    }

    /// @notice Get bribe distribution for a round and token
    function getBribeDistribution(uint256 roundId, address token) external view returns (uint256) {
        return bribeDistributions[roundId][token];
    }

    /// @notice Get all whitelisted tokens
    function getWhitelistedTokens() external view returns (address[] memory) {
        return whitelistedTokensList;
    }

    /// @notice Check if bribe distribution is complete for a round
    /// @param roundId The round ID to check
    /// @return completed Whether all tokens have been distributed
    /// @return processedCount Number of tokens processed so far
    /// @return totalCount Total number of whitelisted tokens
    function getBribeDistributionStatus(uint256 roundId) external view returns (bool completed, uint256 processedCount, uint256 totalCount) {
        completed = bribesDistributed[roundId];
        processedCount = bribeDistributionIndex[roundId];
        totalCount = whitelistedTokensList.length;
    }

    /// @notice Optional: Migrate funds to a new jackpot contract
    /// @dev Only owner can call this
    /// @dev IMPORTANT: Distributed but unclaimed bribe tokens remain in this contract.
    ///      The lottery contract tracks which jackpot was used for each round and will
    ///      call this contract directly for claims on old rounds, so migration is safe.
    /// @param newJackpot The new jackpot contract to migrate to
    function migrateTo(address newJackpot) external override onlyOwner {
        require(newJackpot != address(0), "newJackpot=0");
        require(newJackpot != address(this), "cannot migrate to self");
        
        ISlvrJackpot newContract = ISlvrJackpot(newJackpot);
        
        // Transfer ETH (send directly, new contract will track it)
        uint256 ethAmount = jackpotPool;
        if (ethAmount > 0) {
            jackpotPool = 0; // Clear before transfer
            newContract.addEth{value: ethAmount}();
            emit PoolCleared(0, ethAmount, 0); // Use 0 for roundId during migration
        }
        
        // Transfer SLVR (approve new jackpot, then call addSlvr to pull)
        uint256 slvrAmount = jackpotSlvrPool;
        if (slvrAmount > 0) {
            jackpotSlvrPool = 0; // Clear before transfer
            // Approve new jackpot to pull tokens from this contract
            IERC20(address(SLVR)).forceApprove(newJackpot, slvrAmount);
            // New jackpot will pull tokens and credit actual amount received
            newContract.addSlvr(slvrAmount);
            // Update tracked balance after transfer
            lastKnownSlvrBalance = SLVR.balanceOf(address(this));
            emit PoolCleared(0, 0, slvrAmount); // Use 0 for roundId during migration
        }
        
        uint256 tokenCount = whitelistedTokensList.length;
        for (uint256 i = 0; i < tokenCount; i++) {
            address token = whitelistedTokensList[i];
            uint256 amount = bribePools[token];
            if (amount > 0) {
                bribePools[token] = 0; // Clear before transfer
                IERC20(token).forceApprove(newJackpot, amount);
                newContract.depositBribe(token, amount);
            }
        }
    }
}

