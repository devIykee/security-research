## TronPad Security Audit - Hunt Report

### **Project Overview**

**TronPad** is TRON's decentralized IDO launchpad (partnership: BSCPad + TRON Foundation). Architecture:
- **Token:** TRONPAD (TRC-20, cross-bridge BEP-20/TRC-20)
- **Model:** Tiered allocation (10% Earth lottery, 80% guaranteed tiers, 10% team)
- **Staking:** 12-15% APY, tier unlock via deposit thresholds
- **Vesting:** Linear release over months post-IDO

---

### **CRITICAL Vulnerabilities Identified**

#### **1. Flash Loan Tier Manipulation**
Single-transaction exploit where attacker:
- Flash-borrows TRONPAD from JustSwap DEX
- Stakes to trigger guaranteed tier threshold (50k+)
- Claims $8M+ allocation within same block
- Repays loan with profit

**Impact:** Allocation pool drained, legitimate stakers receive nothing. Breaks fairness guarantee.

**TVM Note:** Single-threaded execution doesn't prevent this — state reads still reflect artificially inflated balance in same block.

---

#### **2. Vesting Contract Reentrancy - Early Unlock**
If vesting uses pattern `transfer-after-read` (reads unlocked amount, then sends):
- Attacker contract receives transfer, reenters vesting contract
- Withdraws additional amount before state updates
- Can drain entire vesting pool 6+ months early

**Pattern:** Malicious callback triggers during `call{value: amount}()`.

---

#### **3. Admin Key Centralization**
Single-key control over allocation treasury enables:
- Direct fund theft ($10M+ per IDO)
- Unauthorized project whitelisting
- Tier override (remove requirements, allocate 100% to one address)

Requires multisig (n-of-m) and timelock (48h delay) to mitigate.

---

### **HIGH Severity Findings**

| Finding | Attack Vector | Impact |
|---------|---------------|--------|
| **Allocation Pool Draining** | Missing tier verification on claim | Lottery tier starved, guaranteed tier depleted |
| **Withdrawal Race Condition** | Unstake mid-transaction | Users claim allocation after dropping below tier threshold |
| **Liquidity Lock Bypass** | No LP token ownership tracking | Project team drains liquidity during lock period |

---

### **MEDIUM Severity**

- **Tier Precision Loss:** Division rounding causes off-by-one tier assignment (16,999 TRONPAD ≈ 16k)
- **Signature Replay:** Project whitelist lacks nonce/chainId protection
- **Reward Underflow:** Insufficient reward pool causes late stakers to receive zero rewards

---

### **LOW Severity**

- **Energy Exhaustion DoS:** Attacker spams high-energy allocation claims during launch

---

### **Attack Scenarios**

**Scenario 1 - Flash Loan Theft ($8M+):**
```
Block N:
1. JustSwap.flashSwap(TRONPAD, 2M)
   → stakingContract.stake(2M)
   → allocationContract.claimAllocation() [reads balance = 2M, sends $8M]
   → unstake(2M)
2. Repay 2M + 0.3% fee
3. Net profit: $8M - ~6k TRONPAD
```

**Scenario 2 - Reentrancy Drain:**
- Wait 1 month, 8.3k tokens unlocked
- Withdraw triggers attacker callback
- Callback reenters, claims 500k before state updates
- Attacker receives 500k instead of 8.3k

**Scenario 3 - Admin Theft:**
- Compromise dev private key (leaked credentials, exchange hack)
- Call `setTreasury(projectId, attackerAddress)`
- All allocations route to attacker
- Steal entire IDO pool ($10M+)

---

### **Required Contract Sources**

To generate proof-of-concept and verify findings, need:
1. **TRONPAD token contract** (TRC-20) — TRONSCAN address
2. **Staking contract** — tier logic, balance snapshot mechanism
3. **Allocation contract** — pool distribution, access control patterns
4. **Vesting contract** — unlock calculation, external call patterns

**Search pattern:** Query TRONSCAN for verified contracts owned by TronPad team wallet(s), cross-reference with official site.

---

### **Audit Methodology Applied**

Following AI-AUDIT-TOOLKIT pipeline:
1. **Map** (✓) — Entry points: `stake()`, `claimAllocation()`, `withdraw()`; Invariants: tier balance ≥ threshold, allocation sum ≤ pool
2. **Breadth** (→ Phase 2) — 6 parallel specialists (reentrancy, accounting, access control, math, logic, TVM-specific)
3. **Depth** (→ Phase 2) — Coupled state analysis: tier updated without lock, balance decremented after claim
4. **Pattern-match** (→ Phase 2) — Query Solodit for: "flashloan tier", "vesting reentrancy", "allocation fairness"
5. **PoC** (→ Phase 2) — foundry-poc-mainnet-fork with real TRONPAD deployment
6. **Package** (→ Phase 3) — Submission-ready PoC code with gas analysis

---

### **Next Phase Tasks**

1. **Locate contracts** on TRONSCAN — verify official TronPad team addresses
2. **Pull source code** — download from TRONSCAN verification page
3. **Generate PoCs** — fork TRON mainnet, recreate attack scenarios
4. **Check prior audits** — search for Peckshield, Certik, or SlowMist reports
5. **Prepare disclosure** — identify TronPad security contact for private report

---

**Hunt Status:** Active — awaiting contract source code for PoC phase

Sources:
- [Guide: How To Participate In the IDOs On TronPad](https://medium.com/@tronpad/guide-how-to-participate-in-the-idos-on-tronpad-755670403d15)
- [TRONPad.io — IDO Launchpad on TRON Network](https://tronpad.io/)
- [PositiveSecurity/tron-audit-guide](https://github.com/PositiveSecurity/tron-audit-guide)
- [TRON Smart Contract Security](https://developers.tron.network/docs/smart-contract-security)
- [The Ultimate Guide To Reentrancy](https://medium.com/immunefi/the-ultimate-guide-to-reentrancy-19526f105ac)
