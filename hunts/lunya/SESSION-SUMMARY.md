# Lunya Launchpad Bug Hunt - Session Summary

**Target**: Lunya.io (Arc Mainnet)  
**Researcher**: deviykee  
**Date**: 2026-09-16  
**Status**: Incomplete - Source code not available

## What Was Accomplished

### ✅ STEP 1 - Ground Truth: PASS
- Chain: Arc Mainnet (Chain ID 5042)
- RPC: https://rpc.mainnet.arc.io
- Block: 21177357
- Contracts verified as deployed and active

### ✅ STEP 2 - Contract Location: COMPLETE
- Launch Factory: 0xfb68a7bdc87b6754b5dd092586b8e2904baad46e
- Liquidity Locker: 0x225375b9e6c26E1c3DE691F3864D1f2eBED1C25a
- Pool Factory: 0x711492df23f320745de6fd7f0ab9564fdbfea016
- Public Lister: 0x82eaca02d46b0663d9af54b643d4e0f01f73c0de
- Terms Lister: 0x3d9c0db2d81188726f5a4b3823ca4fa8ae2fff38

### ⚠️ STEP 3 - Surface Map: BLOCKED
- **GATE: UNVERIFIED** - No source code available on Sourcify
- **GATE: UNVERIFIED** - Block explorer does not show verified source
- Only ABIs available from github.com/lunyaio/lunya-abi
- Cannot perform deep code review without source

### ⚠️ STEP 4 - Auth Triage: PARTIAL
- Default admin functions are guarded (no free win on standard patterns)
- RPC too slow/unreliable for comprehensive function testing
- Custom functions (openPool, depositFees, sweepFees) need source code review

## Key Findings Requiring Source Code Verification

### 🔴 CRITICAL PRIORITY: Pool Squat on Graduation

**Vulnerability Class**: Migration pool manipulation (launchpad graduation)

**The Pattern** (from bug-class playbook):
> Graduation calls pool creation and mints liquidity with NO post-init price check.
> → attacker pre-creates pool at fake price, graduation dumps raise into it.

**Lunya's Claimed Defense**:
- Docs state: "Graduation reverts if the target pool already exists"
- Docs state: "constant-product pools aren't open to public listing"

**What I Need to Verify**:
1. **WHEN** does graduation check pool existence?
   - ✅ Safe: Check BEFORE calling lister → revert if exists
   - ❌ Vulnerable: Check AFTER lister creates → too late

2. **WHERE** is the check?
   - In LunyaLaunchCP graduation logic? (need source)
   - In Terms Lister? (need source)
   - Both?

3. **CAN** Public Lister create CP pools?
   - Public Lister has `CurveNotOpen` error → suggests restriction exists
   - But need to verify poolType 1 (CP) is actually blocked

**Attack Scenario** (IF vulnerable):
```solidity
// 1. Attacker monitors mempool for graduation tx
// 2. Front-runs with pool creation at manipulated price
// 3. Graduation proceeds, adds liquidity at wrong price
// 4. Attacker extracts value through price arbitrage
```

**Impact**: HIGH to CRITICAL
- Affects every token graduation
- Theft of raised funds through price manipulation
- Permanent liquidity locked at wrong price

**To Prove or Kill This Finding**:
- [ ] Get source code of LunyaLaunchCP
- [ ] Find graduation function (not in ABI - must be internal or in different contract)
- [ ] Trace: buy → curve complete → graduation trigger → lister call → pool check
- [ ] Verify Public Lister blocks CP pools for unauthorized callers
- [ ] Test on forked mainnet if possible

### 🟡 MEDIUM PRIORITY: Access Control Questions

**Functions needing verification**:

1. **openPool(uint8 poolType, uint160 sqrtPriceX96)**
   - Who can call this?
   - Could this be used to bypass graduation restrictions?
   - RPC too slow to test reliably

2. **depositFees(address quoteToken, uint256 amount)**
   - Reverts with error 0xa95d7d88 when called by attacker
   - Need to decode error and understand the restriction

3. **sweepFees(address quoteToken)**
   - Reverts with error 0x2ec77d57
   - Sends to feeRecipient (0x1faB30588d773903C14A7a07eD0a6F01682b3bA9)
   - Even if public, should be safe (goes to protocol treasury)

### 🟢 LOW PRIORITY: Owner Centralization

**Findings**:
- Owner: 0x97FB6F29362de98b54Abf8e9167153a52E64A5a7
- Owner can: change implementations, approve/revoke quote tokens, set fees, pause creation
- Uses Ownable2Step (safer than Ownable)
- This is **trust-risk**, not a permissionless exploit

**Not Critical**: Standard admin powers for protocol maintenance

## Technical Limitations

### RPC Issues
- Arc Mainnet RPC is slow and unreliable
- Timeouts on batch queries
- Error responses without clear messages
- Makes comprehensive testing difficult

### No Source Code
- Contracts not verified on Sourcify
- Block explorer doesn't show source
- Only ABIs available
- **Cannot perform**:
  - CEI (Checks-Effects-Interactions) analysis
  - Reentrancy analysis
  - Math/rounding review
  - Complete access control audit
  - Graduation flow verification

### No Graduated Launches Yet
- 10 launches exist, all in "Trading" phase (none graduated)
- Cannot observe real graduation transaction
- Cannot verify actual pool creation behavior

## Recommendations

### For Continuing This Hunt

**Option 1: Get Source Code**
- Contact Lunya team for source code
- Request contract verification on block explorer
- Without source: **cannot complete thorough audit**

**Option 2: Decompile Bytecode**
- Use tools like Heimdall, Dedaub
- Time-intensive, error-prone
- Still inferior to source code review

**Option 3: Wait for Graduation**
- Monitor for first graduation transaction
- Analyze the actual execution trace
- Confirm pool creation and price setting flow

### For Disclosure (if continuing)

Since source code is not available and critical flows cannot be verified:
- **Cannot responsibly disclose unconfirmed findings**
- Pool squat vulnerability is **plausible but unproven**
- Would need to present as: "Areas requiring attention" not "Confirmed vulnerabilities"

## Coverage Assessment

**Files Examined**: 4 ABIs (LaunchFactory, LaunchCP, LiquidityLocker, PublicLister)  
**Source Code Reviewed**: 0 files  
**Value Paths Traced**: 0 complete paths  
**Coverage**: <10% (ABI-only surface review)  

**Honest Assessment**: This is **not a complete audit**. Without source code:
- Cannot verify graduation safety
- Cannot analyze complex math/logic
- Cannot trace complete value flows
- Cannot confirm or kill suspected vulnerabilities

## Next Steps

1. **Attempt to get source code** - contact team or find verified deployment elsewhere
2. **If source unavailable**: Mark hunt as blocked and move to next target
3. **Do NOT** claim "audit complete" or "no vulnerabilities found" with this level of coverage
4. **Do NOT** disclose unverified findings as confirmed bugs

---

**Conclusion**: Hunt blocked at Step 3 (verification gate). The most critical vulnerability pattern for launchpads (pool squat on graduation) is **plausible but cannot be verified** without source code. Resuming this hunt requires either source code access or deployment of analysis on a local fork with full tracing enabled.

**Researcher Note**: Following skill rules - honest coverage, never imply complete audit when blocked. This target needs source code for responsible security review.
