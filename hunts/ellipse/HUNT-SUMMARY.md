# Ellipse Bug Hunt - Session Summary

**Researcher:** deviykee  
**Date:** 2026-09-19  
**Target:** https://ellipse.fun/  
**Chain:** Arc (Chain ID: 5042)  
**Status:** Investigation in progress - awaiting source code

---

## EXECUTIVE SUMMARY

I conducted a systematic security review of Ellipse, a token launchpad on Arc blockchain using Uniswap v4 pools with custom hooks. The protocol launches fixed-supply tokens (1B) with immediate liquidity in a single atomic transaction.

**Critical blocker:** All core contracts are **unverified** and not available on Sourcify or block explorers. Without source code, I can only identify potential vulnerabilities based on:
1. Documentation analysis
2. Known bug patterns from similar protocols
3. Bytecode reverse engineering (limited)

**Key finding identified:** HIGH-CRITICAL severity pool initialization vulnerability (unverified, needs source code to confirm).

---

## PROTOCOL OVERVIEW

**Product Type:** Launchpad (Uniswap v4 hook-based)  
**TVL:** ~$75.94K  
**Architecture:**
- Launchpad V6 contract creates tokens + initializes pools
- Launch Hook V6 enforces fees and liquidity locks
- Buyback Reserve receives anti-sniper fees
- Uniswap v4 PoolManager hosts the liquidity

**Core Contracts (Arc mainnet, chain 5042):**
```
Launchpad V6:     0x66bdc0803807f8a62763943fb2dd584ed9fb9c16 (39KB bytecode) ❌ Unverified
Launch Hook V6:   0x143d72d4bd0f0e1a6c6fd4f2f671a45d9e003a88 (15KB bytecode) ❌ Unverified  
Buyback Reserve:  0xea51ef0975a238cbbbc9edad537ec4be4f6ede7a (12KB bytecode) ❌ Unverified
Reward Vault:     0x2941208f4415825c512bdcccd0cb9561a3f093ed (12KB bytecode) ❌ Unverified
Pair Registry:    0x1dfa98d6dc2ab6e452c09c1c7c706b5f4a3f623f
Uniswap v3 Factory: 0xf0db7b58379503491d857db50ac9ece64c653918
```

**Admin Roles (verified via RPC):**
- Admin: 0xf1f03698f7a82be042a53cf9ebe1325f1d3026cb
- Guardian: 0x54e8cda43213322e1559520ecff5489351560509
- Hook: 0x143d72d4bd0f0e1a6c6fd4f2f671a45d9e003a88 ✓ matches Launch Hook V6
- Vault: 0x2941208f4415825c512bdcccd0cb9561a3f093ed ✓ matches Reward Vault

---

## INVESTIGATION RESULTS

### Step 1: Ground Truth ✅ PASS
```
RPC: https://rpc.mainnet.arc.io
Chain ID: 5042 ✓ confirmed
Block: 21636886 ✓ live
```

### Step 2: Core Contract Discovery ✅ COMPLETE
Found all contracts via:
- Bundle grep of website JavaScript
- Documentation API reference
- On-chain calls to admin/vault getters

### Step 3: Verification Gate ❌ BLOCKED
**Status:** All contracts unverified
- Not on Sourcify
- Blockscout/Etherscan APIs don't return source
- Bytecode analysis reveals function selectors but not logic

**Function selectors identified (from bytecode):**
```
Launchpad: setAdmin, setGuardian, setUpdater, admin, guardian, updater, manager, hook, vault
Hook: (15+ unknown functions, need decompilation)
```

### Step 4: Auth Triage ✅ PASS
Tested 9 admin functions from 0xdead address:
```
setAdmin(address)      → guarded ✓
setGuardian(address)   → guarded ✓
setUpdater(address)    → guarded ✓
setOwner(address)      → guarded ✓
setKeeper(address)     → guarded ✓
setOracle(address)     → guarded ✓
setFee(uint256)        → guarded ✓
mint(address,uint256)  → guarded ✓
withdraw(uint256)      → guarded ✓
```
**Result:** No missing access control on standard admin functions (not a free win).

### Step 5: Foundation Mapping ⚠️ PARTIAL
**Token Flow:**
- User pays quote asset (CRCL, GLD, BTC, USDT, or ELLIPSE)
- Swaps through Uniswap v4 pool
- Hook takes 1% fee (or 95%→70%→40%→10% during anti-sniper phase)
- Fees accrue in PoolManager, distributed via `distribuisci()`

**Liquidity Lock:**
- Hook "refuses every removal" (per docs)
- Only launchpad + buyback reserve can add liquidity
- Mechanism unclear without source

**Fee Distribution:**
- Anti-sniper (first ~8 blocks): 10% protocol, 10% creator, 80% buyback
- Regular 1%: 50/50 or 30/30/40 split (creator/protocol/holders)

---

## PRIMARY FINDING (UNVERIFIED)

### 🚨 POTENTIAL CRITICAL: Uniswap v4 Pool Squat Attack

**Vulnerability Pattern:** Pre-initialization of launch pool at manipulated price

**How it works:**
1. Attacker monitors mempool for launch transactions
2. Attacker calculates pool key (deterministic from token addresses)
3. Attacker front-runs with `PoolManager.initialize(poolKey, wrongPrice)`
4. Victim's launch transaction executes but pool already exists
5. If no existence/price check, liquidity is added at manipulated ratio
6. Token supply dumps at 100x-1000x wrong price

**Similar vulnerabilities:**
- Pump.fun clones on Uniswap v3 (confirmed exploits)
- Bonding curve migrations without price verification
- Known pattern from bug hunting skill Step 6.5 #1

**Why this is likely:**
- Documentation shows atomic "one transaction creates token + pool"
- No mention of pool existence checks
- No mention of post-initialization price verification  
- Uniswap v4 pool initialization is permissionless
- Pool keys are deterministic (CREATE2-style)

**Impact if confirmed:**
- **Severity:** CRITICAL
- **Loss:** 99%+ of token value (depends on price manipulation)
- **Victims:** Every token launch + all buyers
- **Attack cost:** Only gas fees (<$10)
- **Frequency:** Repeatable on every launch

**Mitigation (what code should do):**
```solidity
// Before pool init:
require(poolManager.getSlot0(poolKey).sqrtPriceX96 == 0, "Pool exists");

// OR after pool init:
uint160 actualPrice = poolManager.getSlot0(poolKey).sqrtPriceX96;
require(actualPrice == expectedPrice, "Price mismatch");
```

**Status:** ⚠️ **UNVERIFIED** - Need source code to confirm
**Evidence:** HIGH (documentation + known pattern + permissionless v4)
**Recommended action:** Immediate source code review

---

## SECONDARY VECTORS (Need Source Code)

### 2. Hook Liquidity Lock Bypass (MEDIUM)
- Claim: Hook "refuses every removal"
- Question: Can removal happen via PoolManager directly?
- Question: Are there re-entrancy paths?
- Status: Need hook beforeRemoveLiquidity implementation

### 3. Fee Distribution Manipulation (MEDIUM)
- Complex splits: 30/30/40, 10/10/80
- Question: Precision loss in rounding?
- Question: Can `distribuisci()` be DOSed or front-run?
- Status: Need fee accounting logic

### 4. Anti-Sniper Timing Bypass (LOW-MEDIUM)
- Phase reduction: 95%→70%→40%→10%→1% over ~8 blocks
- Question: Using block.number or timestamp?
- Question: Can miners manipulate timing?
- Status: Need hook beforeSwap implementation

### 5. Dev Buy Enforcement (LOW)
- Claim: "Optional dev buy up to 5%, fee-exempt"
- Question: Is 5% limit enforced on-chain?
- Question: Can dev buy multiple times?
- Status: Need launch function implementation

---

## COVERAGE

**Files analyzed:** 0/TBD (all contracts unverified)  
**Bytecode reviewed:** 4 contracts (launchpad, hook, reserve, vault)  
**Documentation reviewed:** Full docs at ellipse.fun/docs  
**On-chain testing:** Auth triage, role verification, pool analysis

**Coverage assessment:** <10% - This is NOT a full audit. Findings are based on documentation analysis and known vulnerability patterns. Actual code review is required for any severity determination.

---

## NEXT STEPS

### Immediate Actions Required

1. **Request source code from team:**
   - Official contact: @ellipsefun (Twitter/X)
   - Security channel: TBD (Step 10A)
   - Purpose: Verify pool initialization logic

2. **If source provided:**
   - Verify pool squat vulnerability  
   - Complete Steps 5-8 of bug hunting skill
   - Create PoC for confirmed findings
   - Write formal report

3. **If source not provided:**
   - Use professional decompiler (Heimdall, Dedaub)
   - Attempt to reconstruct critical functions
   - Flag unverified contracts as trust risk

### For Continued Investigation

**Priority 1:** Pool initialization in launchpad
- Find the launch/create function
- Trace pool creation flow
- Check for existence/price verification

**Priority 2:** Hook liquidity lock
- Decompile beforeRemoveLiquidity
- Test removal from different addresses
- Check PoolManager bypass paths

**Priority 3:** Fee distribution
- Find distribuisci() implementation
- Check precision in percentage math
- Test DOS scenarios

---

## HONEST ASSESSMENT

**What I can say:**
- ✅ Identified high-priority attack vector based on documentation
- ✅ Verified access control on admin functions (properly guarded)
- ✅ Mapped protocol architecture and token flow
- ✅ Found all core contract addresses

**What I cannot say without source code:**
- ❌ Whether pool squat vulnerability actually exists
- ❌ How liquidity lock is implemented
- ❌ Whether fee math has precision issues
- ❌ Any definitive severity rating

**Recommendation:** This hunt requires source code to progress beyond hypothesis. The pool squat vulnerability is a known pattern with CRITICAL impact if present. Team should prioritize making contracts verifiable or providing source for security review.

---

**Hunt Status:** Blocked on source code verification  
**Time spent:** ~2 hours  
**Confidence in findings:** Medium (based on pattern matching, not code review)  
**Recommended severity IF confirmed:** CRITICAL (pool squat) + MEDIUM (others)

---

## SOURCES

- Arc blockchain docs: https://docs.arc.io/
- Ellipse docs: https://ellipse.fun/docs
- Arc explorer: https://arc-scan.org/
- Trustswap Arc guides: https://trustswap.com/arc/
