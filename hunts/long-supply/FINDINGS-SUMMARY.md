# Long.supply Security Assessment - Summary

**Hunt ID**: long-supply-2026-09-16  
**Researcher**: deviykee  
**Date**: September 16, 2026  
**Status**: ⚠️ BLOCKED - Insufficient contract access

---

## TL;DR

Long.supply is a **custodial bridge** that launched on Arc mainnet today (Sept 16, 2026). It bridges stock tokens from Robinhood Chain to Arc with claimed 1:1 backing. 

**Key Finding**: This is **NOT a decentralized protocol** - it's a custodial service where the team controls all minting and redemptions. Multiple crypto KOLs have raised rug pull concerns. Without verified source code, a traditional security audit cannot be performed.

**Recommendation**: ⛔ **HIGH RISK** - Avoid until contracts are verified and independently audited.

---

## What We Found

### Contracts Discovered
1. **Vault**: `0x3943a8a80c85602f255fb8ebde7f213ea2873d8a` (unverified)
2. **LONG Token**: `0x2164bb17a2d38c1b5170e987b2c0416df1efc752` (meme token)

### Architecture
```
User deposits stock token on Robinhood Chain
         ↓
Team-controlled bridge (proprietary)
         ↓
Team mints equivalent token on Arc
         ↓
Tokens stored in vault: 0x3943...d8a
         ↓
Team holds custody, user holds IOUs
```

### Red Flags Identified

#### 1. Custodial Design (Trust Risk)
- Team admits: "NOT trustless or decentralized"
- "Team-operated wallets for minting, redemptions, and custody"
- No on-chain verification of 1:1 backing mentioned
- Single point of failure: if team disappears, funds are gone

#### 2. Platform-Issued Tokens (Not Official)
From community reports:
> "Stock tokens on Arc are not officially issued but rather issued by the platform itself"

This means:
- Not official Robinhood tokens
- Not official stock certificates
- Platform creates its own representation
- Trust required that platform won't mint more than backing

#### 3. No Code Transparency
- ❌ No GitHub repository
- ❌ No verified contracts on explorer
- ❌ No security audit
- ❌ No bug bounty program
- ❌ No documentation of contract addresses

#### 4. Day-One Launch Timing
- Launched same day as Arc mainnet (Sept 16, 2026)
- Immediate MEXC listing for LONG token
- 270%+ price pump on launch day
- Classic pattern for pump projects

#### 5. Community Warnings
Multiple KOLs flagged concerns:
- "Can rug at any time"
- "Can mint fake USDT"
- "Platform has rug pull permissions"

---

## Technical Assessment

### What We Could NOT Audit

Without source code, we cannot verify:

**Bridge Security**:
- ✗ Signature verification on cross-chain messages
- ✗ Replay attack protection
- ✗ Authorization model for minting
- ✗ Asset accounting accuracy
- ✗ Withdrawal controls

**Vault Security**:
- ✗ Who can withdraw funds
- ✗ Timelock or governance mechanisms
- ✗ Emergency pause capabilities
- ✗ 1:1 backing verification
- ✗ Multi-sig requirements

**Token Launch Mechanics**:
- ✗ Fair launch guarantees
- ✗ LP lock duration
- ✗ Anti-snipe measures
- ✗ Fee structure transparency

### Attempted Steps (Per Bug Hunt Skill)

| Step | Status | Outcome |
|------|--------|---------|
| 1. Ground Truth | ✅ PASS | Arc mainnet verified live (block 21,170,155) |
| 2. Contract Discovery | ⚠️ PARTIAL | Found vault + token, no verification |
| 3. Surface Map | ❌ BLOCKED | No verified source, explorer API protected |
| 4. Auth Triage | ❌ BLOCKED | RPC connection issues |
| 5. Foundation Map | ❌ BLOCKED | No source code |
| 6. Attack Questions | ⚠️ THEORETICAL | Only architecture-level analysis possible |
| 7. Fork PoC | ❌ BLOCKED | Cannot test without ABIs |
| 8. Severity | ⚠️ N/A | Cannot assign without code access |
| 9. Report | ⏸️ ON HOLD | Insufficient findings |
| 10. Disclosure | ⏸️ N/A | Nothing to disclose yet |

---

## Is This a Scam?

**We cannot definitively say**, but consider:

### Scam Indicators Present:
- ✅ Custodial control with no transparency
- ✅ No verified contracts
- ✅ Day-one launch with immediate listing
- ✅ Community rug pull warnings
- ✅ No audit or security program
- ✅ Platform-issued tokens (not official)

### What's Missing for Legitimacy:
- ❌ Open-source contracts
- ❌ Multi-sig on critical functions
- ❌ Independent audit report
- ❌ Timelock on admin functions
- ❌ On-chain proof of reserves
- ❌ Established team reputation

### What We'd Need to See:
1. **Contract Verification**: Publish and verify all contracts on explorer
2. **Security Audit**: Independent audit from reputable firm
3. **Multi-sig**: At least 3-of-5 on vault withdrawals
4. **Timelock**: 24-48hr delay on admin functions
5. **Proof of Reserves**: On-chain verification of 1:1 backing
6. **Insurance**: Some form of user protection

---

## Comparison to Known Rug Pull Patterns

| Pattern | Long.supply | Typical Rug |
|---------|-------------|-------------|
| Custodial control | ✅ Yes | ✅ Yes |
| Unverified contracts | ✅ Yes | ✅ Yes |
| Day-one listing | ✅ Yes | ✅ Yes |
| No audit | ✅ Yes | ✅ Yes |
| Extreme price pump | ✅ 270%+ | ✅ Common |
| Community warnings | ✅ Multiple | ✅ Common |
| Team transparency | ❌ Unknown | ❌ Anon |

**Pattern Match**: 6/7 indicators align with historical rug pulls.

---

## User Recommendations

### If You're Considering Using Long.supply:

**❌ DO NOT** use this protocol if you:
- Value security over speculation
- Cannot afford to lose your entire deposit
- Need decentralization or trustlessness
- Require code transparency

**⚠️ EXTREME CAUTION** if you:
- Understand it's purely custodial (like Coinbase)
- Trust the anonymous team completely
- Are only "aping" with funds you can lose
- Accept zero recourse if team rugs

### Questions to Ask the Team:

1. Why are contracts not verified on the explorer?
2. Where is the GitHub repository?
3. Who controls the vault withdrawal keys?
4. Is there a multi-sig? If so, who are the signers?
5. How can users verify 1:1 backing on-chain?
6. What prevents the team from minting unbacked tokens?
7. Is there a security audit? From whom?
8. What's the team's real identity (KYC)?

### Red Lines:
- If team won't verify contracts → EXIT
- If team won't share code → EXIT
- If team won't reveal signers → EXIT
- If "trust us" is the only answer → EXIT

---

## For Other Security Researchers

### If You Want to Continue This Hunt:

**Option A - Wait for Verification**:
- Monitor explorer for contract verification
- Once verified, resume at Step 3 (surface map)

**Option B - Reverse Engineer Bytecode**:
- Download bytecode from RPC
- Use tools: `heimdall`, `panoramix`, `dedaub`
- Match selectors to standard patterns
- Risky: takes days, may miss custom logic

**Option C - Frontend Analysis**:
- Browser dev tools → Network tab
- Capture all contract calls
- Extract ABIs from transaction data
- Map out function signatures

**Option D - Direct Contact**:
- DM @Longdotsupply on X
- Request source code for security review
- Offer responsible disclosure process
- If they refuse, that's a red flag itself

### High-Value Targets (If Code Becomes Available):

1. **Bridge Minting Logic**: Can team mint without burning on source chain?
2. **Vault Withdrawal Controls**: Who can drain, any timelocks?
3. **Asset Accounting**: Does internal ledger match actual balances?
4. **Admin Privileges**: What can owner/agent do without checks?
5. **Emergency Functions**: Pause, freeze, upgrade powers?

---

## Coverage & Methodology

### Files Examined: 0 (no source available)
### On-Chain Calls: Blocked by RPC issues
### Coverage: 0% (cannot audit without code)

This assessment followed the **iykes-evm-bughunt-skill** methodology but was blocked at Step 3 due to lack of contract verification.

---

## Conclusion

**Long.supply presents extreme trust risks**. The custodial architecture means users must trust:
- The team won't run away with funds
- The team maintains proper 1:1 backing
- The bridge functions correctly
- The team's OpSec prevents hacks

Combined with:
- No code transparency
- No independent verification
- Day-one launch timing
- Community rug warnings

**Risk Assessment: 🔴 CRITICAL**

This does not meet the bar for responsible recommendation. Users should demand contract verification, audit reports, and transparent governance before depositing funds.

---

## Research Blockers

This hunt could not proceed due to:
1. No verified contract source code
2. No public GitHub repository
3. Cloudflare protection on explorer API
4. RPC connection instability
5. Insufficient contract discovery

**Status**: Hunt suspended pending contract verification or code disclosure.

---

**Researcher**: deviykee ([@deviykee](https://x.com/deviykee))  
**Date**: 2026-09-16  
**Chain**: Arc (Chain ID 5042)  
**Methodology**: [iykes-evm-bughunt-skill](https://github.com/devIykee/iykes-evm-bughunt-skill)
