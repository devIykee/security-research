# Tolly Labs Bug Hunt - Status Report

## Progress Summary

**Chain**: Arc (mainnet, chain ID 5042) ✓ Verified live  
**Contracts**: 14 deployed, source verified ✓  
**Repository**: https://github.com/TollyLabs/v3-contracts ✓ Cloned

**Coverage**: 3/10 files (30%)
- Core launchpad (TollyPad.sol) - Full read ✓
- Token template (TollyToken.sol) - Full read ✓  
- Fee locker (TollyFeeLocker.sol) - Full read ✓

## Foundation Map Complete

- State ownership analysis ✓
- External call order (CEI analysis) ✓
- Token flow paths ✓
- Access control matrix ✓
- Initial checklist completed ✓

## Adversarial Analysis Complete

Completed 5 angles:
1. ✓ Malicious actor (drain/payout paths)
2. ✓ Economic and math (rounding, flash loans)
3. ✓ State and access (reentrancy, modifiers)
4. ✓ Edges (arrays, timestamp, overflow)
5. ✓ External integrations (Uniswap, weird tokens)

## Critical Findings Under Investigation

### Finding 1: Pool Initialization Front-Running (CRITICAL - Under Verification)

**Component**: TollyPad.createToken pool initialization (lines 305-312)

**Root Cause**: TOCTOU race condition between:
- CREATE2 token deployment
- Pool creation (permissionless)
- Pool initialization (permissionless, skipped if already initialized)

**Attack Vector**:
1. Attacker monitors mempool for createToken transaction
2. Computes predicted token address from transaction parameters
3. Front-runs with pool.initialize(maliciousPrice) before victim tx executes
4. Victim's initialization is skipped (line 312: `if (existing == 0)`)
5. Single-sided LP mint proceeds at attacker's malicious price

**Impact**:
- If malicious price < intended startFdv: Position mints as inactive, attacker buys tokens for pennies
- If malicious price > intended topFdv: Transaction reverts (DoS only)

**Severity**: CRITICAL if confirmed (complete launch theft)

**Status**: Building PoC to verify Uniswap V3 behavior

**Verification needed**:
- [ ] Can Uniswap V3 pool.initialize() be called before token exists?
- [ ] Does inactive position (below range) allow theft scenario?
- [ ] Are there any protections in the transaction flow I missed?

### Finding 2: External Revert DoS in Fee Collection (HIGH - Needs Verification)

**Component**: TollyFeeLocker._distribute (lines 275-311)

**Root Cause**: Multiple non-guarded external calls that can revert:
- Line 277: furnace.depositToll (TOLLY burn)
- Line 286: treasury transfer (protocol fee)
- Line 311: burner transfer (project burn)

**Impact**: If any recipient reverts (blacklist, contract bug, selfdestruct):
- ALL fee collection for ALL tokens permanently bricked
- No fallback or try/catch on critical transfer paths
- Fees accumulate in positions but cannot be harvested

**Severity**: HIGH (protocol-wide DoS, funds not lost but frozen)

**Status**: Need to check if furnace/treasury/burner can realistically revert

## Next Steps

1. Complete PoC for Finding 1 (pool initialization race)
2. Verify Uniswap V3 pool creation/initialization behavior
3. If Finding 1 confirmed: Test on local fork with actual contracts
4. Analyze Finding 2 scope (is furnace global or per-token?)
5. Check remaining contracts (HolderVault, Treasury, Forge, Routers)
6. Run slither for additional static analysis
7. Write formal reports for confirmed findings

## Time Estimate

- PoC development: 30-60 min
- Remaining contract review: 60-90 min  
- Report writing: 30-45 min per finding
- Total: 3-4 hours to completion

## Sources

### Protocol Documentation
- [What Is TOLLY Coin?](https://www.bitrue.com/blog/what-is-tolly-crypto)
- [Arc RPC Endpoints](https://docs.arc.io/arc/tools/node-providers)
- [GitHub Contracts](https://github.com/TollyLabs/v3-contracts)

### Research Context
- [Arc Mainnet Launch](https://news.futunn.com/en/post/79344708/arc-the-public-blockchain-under-circle-has-launched-its-mainnet)
- [TOLLY on MEXC](https://www.mexc.com/news/1206569)
