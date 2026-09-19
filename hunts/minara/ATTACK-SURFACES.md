# Minara.fun Attack Surfaces (Priority Order)

## 1. CRITICAL: Pool Creation/Graduation (v4 Pool Squat)
**Pattern**: Migration pool squat from skill Step 6.5 #1
**Risk**: Attacker pre-creates Uniswap v4 pool at fake price before graduation
**Check**: Does graduation check existing pool price? Or blindly mint with minAmounts=0?
**Impact**: If vulnerable, drain raise funds at manipulated price

## 2. HIGH: Fee Hook Centralization
**Facts**: 
- Single shared fee hook for ALL tokens: 0xb6a65950534f061618b4ae102fbcbb8541a8e0cc
- 14,661 USDC collected
- Owner: 0x780af76fca16875bfbeb19864a78acb6f77a5f2b
**Risks**:
- Hook upgrade/replacement without user consent
- Fee parameter changes on live positions
- Compromised hook = all tokens affected
**Severity**: Trust/centralization (not exploitable by stranger, but owner backdoor)

## 3. HIGH: Hook Callback Reentrancy
**Pattern**: Uniswap v4 hooks have multiple callback points
**Check**: beforeSwap/afterSwap CEI ordering, external calls in hooks
**Risk**: Cross-function reentrancy during swap execution

## 4. MEDIUM: First Depositor / Share Inflation (if bonding curve)
**Pattern**: Vault donation attack from skill Step 6.5 #7
**Check**: Do tokens use bonding curve math before graduation?
**Risk**: Share price manipulation on first purchase

## 5. MEDIUM: Creator Fee Claim Mechanics
**Observation**: API shows `"creatorFeeClaim": "hook"` for tokens
**Check**: Can creator claim fees permissionlessly? DoS on claims?
**Risk**: Creator fund extraction or griefing

## 6. LOW: Oracle/Price Freshness (if used)
**Check**: Does platform use any price oracles for graduation thresholds?
**Risk**: Stale oracle manipulation

## Next Actions:
1. Extract function selectors from fee hook bytecode
2. Test graduation flow on a live token
3. Check if pools can be pre-created
4. Analyze hook callback sequences
5. Review creator fee distribution logic
