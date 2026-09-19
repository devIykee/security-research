# CircleWarp Bug Hunt - Current Status & Next Steps

## What I've Found

### ✅ Verified Information

**Target**: CircleWarp - Bonding curve launchpad on Arc (Circle's USDC-native L1)
- **Chain**: Arc mainnet (Chain ID: 5042, verified)
- **RPC**: https://rpc.mainnet.arc.io
- **Explorer**: https://explorer.arc.io

**Core Contracts** (all unverified):
1. **Factory Proxy**: `0x0dCad158e98bC24455f9e94F46709d8a5F6D1255`
   - 513 tokens created
   - Active factory instance
   
2. **Implementation**: `0x34988939648578a1d90Db742bc1C903fD6F7c1b0` (39KB)
   - Bonding curve logic
   - Key functions: `createToken()`, `buy()`, `sell()`, `migrate()`
   
3. **Uniswap V4 PoolManager**: `0x8366a39cc670b4001a1121b8f6a443a643e40951`
   - **5.2 million USDC balance** (HIGH VALUE)
   - Migration target for graduated tokens

4. **Uniswap V4 Router**: `0x53bf6b0684ec7ef91e1387da3d1a1769bc5a6f77`

**Auth Triage**: ✅ All admin functions properly guarded (no missing access control free win)

### 🎯 Primary Attack Surface

**Migration/Graduation Flow** - The highest risk area for launchpad protocols:

Similar to pump.fun on Solana ([reference](https://github.com/pump-fun/pump-public-docs/blob/main/docs/PUMP_PROGRAM_README.md)), CircleWarp uses a bonding curve → DEX migration model:

1. Token trades on bonding curve
2. At graduation threshold, `migrate()` is called
3. Liquidity migrates to Uniswap V4 pool
4. LP tokens typically burned

**Classic vulnerability pattern**: **Pool squat attack** (seen in many V3 launchpads)

```solidity
// VULNERABLE:
function migrate() external {
    // Create or get pool
    pool = factory.createAndInitializePoolIfNecessary(...);
    
    // Add liquidity WITHOUT verifying pool price
    positionManager.mint(
        amount0Min: 0,  // ❌ No slippage protection
        amount1Min: 0   // ❌ No price verification
    );
}

// Attacker exploits:
// 1. Front-run migrate() tx
// 2. Pre-create pool at manipulated price (V4 allows 0-liquidity init)
// 3. migrate() dumps bonding curve liquidity into attacker's fake pool
// 4. Attacker drains via price manipulation
```

### ⚠️ Blockers

1. **No source code**: Contracts unverified on explorer, no public GitHub
2. **RPC instability**: Some queries timeout or connection reset
3. **Proxy pattern**: Token contracts appear to be minimal proxies, state calls revert
4. **No graduated tokens found yet**: Can't observe real migration transactions

### 🔍 What I Need to Verify the Critical Bug

To prove pool squat vulnerability, I need ONE of:

**Option A**: Source code
- Decompile bytecode OR
- Find verified similar contract OR  
- Contact team for source

**Option B**: Live migration transaction
- Find a graduated token
- Analyze the migration transaction
- Check if `slot0()` price verification exists
- Check `amount0Min`/`amount1Min` values

**Option C**: Fork PoC
- Deploy test token on fork
- Trigger graduation
- Attempt pool squat attack
- **Problem**: Need to understand internal state (virtualTokens, virtualUsdc, threshold)

## Recommended Approach

Given the unverified contracts and lack of public source, I recommend:

### Path 1: Bytecode Analysis (Most Reliable)
```bash
# Disassemble migrate() function
cast disassemble <bytecode> | grep -A 50 "8fd3ab80"  # migrate() selector

# Look for:
# - STATICCALL to pool.slot0()
# - Price comparison logic
# - amount0Min/amount1Min values in mint call
```

### Path 2: Live Transaction Analysis
```bash
# Find graduated tokens via events
cast logs --from-block 0 \
  --address 0x0dCad158e98bC24455f9e94F46709d8a5F6D1255 \
  --event-sig "TokenMigrated(address,address,uint256)" \
  --rpc-url https://rpc.mainnet.arc.io

# Analyze migration tx
cast tx <migration_tx_hash> --rpc-url https://rpc.mainnet.arc.io
cast run <migration_tx_hash> --trace --rpc-url https://rpc.mainnet.arc.io
```

### Path 3: Private Disclosure Inquiry
If we find indicators of vulnerability but can't fully prove without source:
- DM team on X (@circlewarp)
- Request source code for security review
- Offer to sign NDA if needed

## Current Status

**Hunt Progress**: ~30% complete
- [x] Step 1: Ground truth - PASS
- [x] Step 2: Core contracts located
- [x] Step 3: Surface map (66+ selectors)
- [x] Step 4: Auth triage - PASS
- [ ] Step 5: Foundation map (blocked by source)
- [ ] Step 6: Attack questions (migration flow needs verification)
- [ ] Step 7: PoC (blocked)
- [ ] Step 8: Severity assessment
- [ ] Step 9: Report
- [ ] Step 10: Disclosure

**Estimated Severity IF vulnerable**: 
- **Critical** - If pool squat is possible on 5.2M USDC PoolManager
- Unauthenticated, repeatable per token graduation
- Direct fund loss for all bonding curve liquidity

**Next Session Priority**:
1. Disassemble `migrate()` bytecode for pool initialization pattern
2. Search for TokenMigrated events to find real migration txs
3. If indicators found, reach out to team for responsible disclosure

## Resources
- [Arc blockchain docs](https://docs.arc.io/)
- [Pump.fun migration pattern](https://github.com/pump-fun/pump-public-docs/blob/main/docs/PUMP_PROGRAM_README.md)
- [Uniswap V4 documentation](https://docs.uniswap.org/)
