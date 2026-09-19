# RadarDEX Hunt Status

## Current Progress

### Completed Steps
✅ **Step 1 - Ground Truth**: Chain confirmed (Arc Mainnet, Chain ID 5042, Block 21166365)
✅ **Step 2 - Contract Discovery**: Located all core contracts from documentation
✅ **Step 3 - Surface Map**: Mapped contract addresses, bytecode analyzed
✅ **Step 4 - Auth Triage**: No missing access control (all admin functions guarded)

### Key Findings So Far

#### 1. Contract Status
- **LaunchFactory V3**: 0x6b3355aCd2F90BEEeEB7964AA1f83b3F866e53E9 (unverified, 17KB bytecode)
- **FeeSplitLocker V3**: 0x4a893FD3c527eDbAB8F8580fd92B0EDe9C19DC7E
- **Launch Count**: 4 tokens deployed
- **Example Token**: "BTCCOOL" (0x98Ca52aC0DA620D9783FFC2f1135C309C1c79CF2)
  - Supply: 1e27 (1 billion with 18 decimals)
  - No owner() function (as claimed)

#### 2. Initial Observations
- Bytecode does NOT contain `createAndInitializePoolIfNecessary` (0x13ead562)
- Bytecode does NOT contain `slot0()` (0x3850c7bd)
- This suggests a different pool creation mechanism than standard Uniswap V3 factory pattern

#### 3. Blockers
- Source code not verified on Sourcify
- Explorer API protected by Cloudflare
- Need to decompile bytecode or find alternative source

## High-Priority Investigation Vectors

### 1. Pool Initialization Mechanism
**Status**: IN PROGRESS
- How are pools actually created?
- Is there a pre-creation squat risk?
- What's the actual price initialization?

### 2. LP Lock Verification
**Status**: PENDING
- Analyze FeeSplitLocker V3 bytecode
- Confirm "locked forever" claim
- Check for withdrawal/emergency functions

### 3. Fee Split Safety
**Status**: PENDING
- 70/30 distribution correctness
- Rounding/precision issues
- Fee extraction timing

### 4. Reflection Mechanism
**Status**: PENDING
- Dividend snapshot manipulation
- Flash loan attack vectors

## Next Actions
1. Decompile LaunchFactory and FeeSplitLocker bytecode
2. Trace an actual launch transaction to understand the flow
3. Analyze the locker's NFT mechanism
4. Test for common launchpad vulnerabilities

## Sources
- RadarDEX Docs: https://radardex.pro/docs
- Arc Chain Info: https://chainstack.com/what-is-arc/
- Chain ID 5042: https://news.futunn.com/en/post/79344708/
