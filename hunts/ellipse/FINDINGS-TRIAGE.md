# Ellipse Launchpad - Findings Triage

## Critical Path Analysis

Based on documentation and contract analysis, the key vulnerability surface is:

### 1. POOL SQUAT ATTACK (HIGH PRIORITY)
**Target:** Uniswap v4 pool initialization during launch
**Issue:** The launchpad creates a new token and initializes a Uniswap v4 pool in one transaction.
**Question:** Can an attacker front-run the launch and pre-initialize the pool at a manipulated price?

**Evidence from docs:**
- "One transaction creates... Uniswap v4 pool with launch hook"
- "V6 range: Starts at first 200-tick step above opening price"
- No mention of pool existence check

**Similar bug from skill:** Step 6.5 #1 - "Migration pool squat (v3)"
- Pattern: "createAndInitializePoolIfNecessary and mints with amount0Min/amount1Min = 0"
- Attack: "anyone pre-creates the pool at a fake price"

**V4 difference:** Uniswap v4 uses PoolManager, not separate pool contracts. Initialization is via `initialize()` on PoolManager.

**Action needed:**
- Verify if launchpad checks pool doesn't exist before initializing
- Test if pool can be pre-initialized at wrong sqrtPriceX96
- Analyze if there's a price verification after initialization

### 2. HOOK LIQUIDITY LOCK BYPASS (MEDIUM PRIORITY)
**Target:** Launch hook liquidity removal protection
**Issue:** Hook "refuses every removal" but implementation unclear

**Question:** Can liquidity be removed through alternative paths?
- Direct PoolManager calls?
- Re-entrancy during callbacks?
- Permission bypass?

**Action needed:**
- Decompile hook contract (0x143d72d4bd0f0e1a6c6fd4f2f671a45d9e003a88)
- Check beforeRemoveLiquidity and afterRemoveLiquidity hooks
- Test removal from different addresses

### 3. FEE DISTRIBUTION MANIPULATION (MEDIUM PRIORITY)
**Target:** distribuisci() function for fee payouts
**Issue:** "Protocol bot triggers payouts every 15 minutes if fees exceed 10x gas cost"

**Questions:**
- Can someone manipulate fee accounting to receive more than owed?
- Is there precision loss in complex splits (30/30/40, 10/10/80)?
- Can distribution be DOSed to lock fees?

**Action needed:**
- Find distribuisci() function signature
- Trace fee accrual logic
- Check rounding in percentage calculations

### 4. ANTI-SNIPER TIMING BYPASS (LOW-MEDIUM PRIORITY)
**Target:** Block-based fee reduction (95% → 70% → 40% → 10% → 1%)
**Issue:** "First ~2 blocks: 95% fee, Next phases: 70%, 40%, 10% fees (2 blocks each)"

**Questions:**
- Is this using block.number or block.timestamp?
- Can timing be manipulated?
- Are there edge cases at phase boundaries?

**Action needed:**
- Check hook's beforeSwap implementation
- Verify block number usage
- Test phase transition timing

## Contract Status
- ❌ Launchpad V6: Unverified, 39KB bytecode
- ❌ Launch Hook V6: Unverified, 15KB bytecode
- ❌ Buyback Reserve: Unverified, 12KB bytecode

## Next Actions
1. Attempt to get source code from team or via decompiler
2. Focus on pool squat attack (highest severity potential)
3. Use Heimdall or similar to decompile contracts
4. Create PoC for most promising finding
