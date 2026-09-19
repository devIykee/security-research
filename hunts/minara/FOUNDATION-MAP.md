# Foundation Map - Minara.fun

## 5A. State Who-Writes

### Fee Hook Contract (0xb6a65950534f061618b4ae102fbcbb8541a8e0cc)
| Variable | Who Can Write | Notes |
|----------|---------------|-------|
| owner | owner (via transferOwnership) | Ownable2Step pattern |
| feeRate | owner (via setFeeRate) | Guarded ✅ |
| accumulated fees | internal (swap callbacks) | Auto-accumulates from swaps |
| creator allocations | likely owner or internal | Need to check claimFees logic |

## 5B. External Call Order (CEI Analysis)

**Cannot verify without source code** - bytecode analysis limited.
Need to:
- Reverse engineer hook callbacks (beforeSwap, afterSwap, etc.)
- Check if external calls happen before state updates
- Look for reentrancy guards

## 5C. Token Paths (Entry → Exit)

### Launch Flow:
1. User → [Create Token] → Token Contract deployed
2. User → [Buy on bonding curve?] → Funds accumulate
3. [Graduation trigger] → Uniswap v4 pool created → Liquidity migrated
4. Post-graduation: User ↔ Uniswap v4 Pool ↔ Fee Hook

### Fee Flow:
Swap → Fee Hook collects → Owner withdraws OR Creator claims

**CRITICAL QUESTION**: Who seeds the graduation pool? Single-sided or raise-held?

## 5D. Access Control Gates

| Function | Modifier | Pausable? |
|----------|----------|-----------|
| setFeeRate | onlyOwner | Unknown |
| withdraw | onlyOwner | Unknown |
| claimFees | onlyOwner or creator? | Unknown |
| transferOwnership | onlyOwner | Yes (Ownable2Step) |
| Hook callbacks | poolManager only | N/A |

## 5E. Structured First-Pass Checklist

- [✅] **Access control on privileged functions** - PASS (all tested functions guarded)
- [🔍] **Reentrancy / CEI on fund paths** - UNCLEAR (need source or deeper analysis)
- [⚠️] **Pool creation/initialization safety** - CRITICAL TO CHECK (pool squat risk)
- [⚠️] **Upgrade/ownership risks** - MEDIUM (centralized owner on shared hook)
- [🔍] **Slippage on graduation** - UNKNOWN (need graduation logic)
- [N/A] **Oracle/pricing** - No evidence of oracle usage
- [N/A] **Pause semantics** - No pause mechanism detected
- [❓] **Events on policy changes** - Cannot verify without source

Legend: ✅ Pass | ⚠️ Risk Identified | 🔍 Need Investigation | ❓ Unknown | N/A Not Applicable
