# RadarDEX Security Analysis Notes

## Protocol Overview
- **Type**: Token launchpad on Arc Mainnet (Chain ID 5042)
- **Mechanism**: Creates tokens directly into Uniswap V3 pools
- **Key Claims**: 
  - "LP tokens locked forever" in FeeSplitLocker
  - No owner, no mint, no tax on tokens
  - 70/30 fee split (deployer/protocol)

## High-Priority Attack Surfaces

### 1. LP Lock Mechanism ("locked forever" claim)
**Contract**: FeeSplitLocker V3 (0x4a893FD3c527eDbAB8F8580fd92B0EDe9C19DC7E)
**Questions**:
- Is there truly no withdrawal path for LP tokens?
- Can the owner upgrade/modify the contract?
- Emergency functions or backdoors?
- Can someone front-run the lock?

### 2. Pool Initialization & Squat Attack (Uniswap V3)
**Bug Class**: Migration pool squat (from skill Step 6.5 #1)
**Pattern**: 
- `createAndInitializePoolIfNecessary` with no post-init price check
- Attacker pre-creates pool at fake price before launch
- Launch dumps liquidity at wrong price
**Detection**: 
- Check if launch calls `createAndInitializePoolIfNecessary`
- Check if there's a slot0() price validation
- Verify getPool() == address(0) check before creation

### 3. Fee Split Logic
**Contracts**: LaunchFactory + FeeSplitLocker
**Questions**:
- Can deployer/protocol manipulate fee distribution?
- Rounding errors in 70/30 split?
- Can fees be drained before lock?

### 4. Reflection Mechanism (Dividend Distribution)
**Contract**: ReflectionLocker (0x8Ce980d8357E404bfd86456c464Dd046E7c517F8)
**Questions**:
- Flash loan inflated snapshot for dividends?
- Can someone game the 50/50 holder/creator split?
- Reentrancy in claim paths?

### 5. Token Creation Parameters
**Questions**:
- Are token contracts truly immutable (no owner/mint)?
- Can malicious parameters be injected?
- Supply manipulation (claimed 1B fixed)?

## Step 4 Results
✓ Auth triage: All admin functions properly guarded (no free wins)

## Next Steps
1. Get source code or decompile bytecode
2. Analyze pool initialization sequence
3. Verify LP lock mechanism
4. Check reflection snapshot logic
5. Test fee split math

## References
- Skill Step 6.5: Bug-class detection playbook
- Uniswap V3 pool squat pattern
