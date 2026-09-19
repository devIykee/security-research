# SunPump Attack Scenarios & Kill Chains

## Scenario 1: Graduation MEV Arbitrage (CRITICAL)

**Objective:** Extract profit from graduation migration by capturing price delta

**Attacker Profile:** MEV bot operator, 1-10 TRX seed capital

**Timeline:**

```
T-60s: Monitor SunPump LaunchpadProxy via TronGrid API
       - Query curve fill percentage for all active tokens
       - Identify tokens at 95%+ completion

T-30s: Target identified (e.g., "DOGE" token at 96% completion)
       - Estimated graduation in next 50-500 TXs
       - Current curve price: 1 TRX = 10,000 tokens

T-0s:  Attacker submits TX1 (front-run graduation):
       - purchaseToken(amount=1000 TRX, minOut=9,500,000)
       - Executes in slot N (before graduation TX)
       - Receives ~9.5M tokens at favorable curve price
       - Gas/Energy: ~100k energy (typical)

T+1s:  Graduation TX executes (slot N+1):
       - Curve finalized; total supply = 100M tokens
       - Liquidity migration: 100k TRX + 200M tokens → SunSwap V2
       - SunSwap V2 pool: 100k TRX / 300M tokens = 1 TRX = 3k tokens

T+2s:  Attacker submits TX2 (back-run graduation):
       - saleToken(amount=8M tokens, minOut=2500 TRX)
       - Executes against SunSwap V2 pool
       - Receives ~2,667 TRX (8M tokens × 1:3k ratio)
       - Gas/Energy: ~150k energy

T+3s:  Attacker profit calculation:
       - Cost: 1000 TRX (front-run purchase)
       - Revenue: 2667 TRX (back-run sale)
       - Net profit: 1667 TRX (~167% ROI)
       - Less fees: ~167 TRX (1% bonding curve + 0.3% SunSwap)
       - Actual profit: ~1500 TRX (~150% ROI)
```

**Attack Difficulty:** EASY
- Graduation is deterministic (publicly visible)
- TronGrid API provides real-time mempool
- No time-lock or randomness prevents front-running
- Energy costs are low (~250k total)

**Impact:**
- SunPump token gradient captured by attacker
- Early-graduation buyers forced out at worse prices
- Late-curve participants see inflated post-graduation prices
- Repeatable for every graduating token

**Detection:**
- Monitor for >50% single-transaction purchases before graduation
- Flag large sells immediately after graduation
- Alert on TRX transfers to known MEV bot addresses

**Remediation:**
- Implement time-lock (48-72 hours) between graduation trigger and execution
- Use private RPC for graduation TX (Flashbots-style MEV protection)
- Randomize graduation block within a window (e.g., +/- 100 blocks)
- Deploy graduation via batch auction (e.g., MEV-Burn)

---

## Scenario 2: Address Poisoning + Fund Drain (HIGH)

**Objective:** Trick users into sending funds to attacker-controlled token

**Attacker Profile:** Social engineer / content creator, 20 TRX seed capital

**Timeline:**

```
T-2h:  Attacker creates 5 tokens on SunPump:
       - "SUN" (clone of real SUN token TSSMHYeV2uE9qYH95DqyoCuNCzEL1NvU3S)
       - "TRON" (clone of TRX)
       - "USDT_TRON" (clone of USDT)
       - etc.
       - Cost: ~100 TRX total

T-1h:  Posts on social channels:
       - Reddit: r/tronix, r/CryptoCurrency
       - Twitter: #SunPump, #TRON hashtags
       - Discord: SunPump, TRON community servers
       - Message: "NEW SUN token launched on SunPump! 🚀"
       - Links: Direct to attacker's clone token on SunPump

T-0m:  Users click link, see SunPump UI:
       - Token name: "SUN"
       - Ticker: "SUN"
       - (But contract address != real SUN token)
       - Users don't verify address (common mistake)

T+5m:  Users approve/send TRX to attacker's clone:
       - TX1: approve(clone_token, 100 TRX)
       - TX2: send(clone_token, 100 TRX)
       - Attacker receives 100 TRX per user

T+1h:  Attacker collects from 100 users:
       - ~10,000 TRX collected
       - Cost: 100 TRX (creation fees)
       - Profit: 9,900 TRX (~99x ROI)
       - Time: 1 hour

T+1.5h: Attacker abandons clone tokens, repeats with new clones
```

**Attack Difficulty:** VERY EASY
- Permissionless token creation (no whitelist)
- Social engineering only; no technical skill required
- Already proven in TRON ecosystem ($9.4M in Aug 2026 alone)

**Impact:**
- Direct fund loss to users (irreversible)
- Erosion of SunPump brand trust
- Regulatory attention (SEC may classify as enabling fraud)
- User education difficulty (users repeat mistakes)

**Detection:**
- Flag tokens with names identical to known tokens (SUN, TRON, USDT)
- Monitor for multiple token creations by same address
- Alert on high-velocity token approvals to same creator

**Remediation:**
- Implement token name registry + dispute resolution
- Add checksum verification on all UI displays
- Require creator identity for tokens using established names
- Auto-burn creation fee for flagged/disputed tokens
- Display full contract address prominently on UI
- Add "verified" badge for tokens passing verification

---

## Scenario 3: Proxy Upgrade Exploit (CRITICAL)

**Objective:** Gain control of LaunchpadProxy and drain graduation liquidity

**Attacker Profile:** Insider / key thief, 0 TRX seed capital (already has admin key)

**Timeline:**

```
T0:    Attacker obtains admin key via:
       - Insider threat (employee with key access)
       - Phishing (social engineering dev team)
       - Hardware wallet compromise (Ledger/Trezor vulnerability)
       - Key leak from GitHub, Discord, Slack

T+1h:  Attacker deploys malicious implementation contract:
       ```solidity
       // MaliciousImpl.sol
       contract MaliciousImpl {
           address attacker = 0x...;
           
           function graduation(address token, uint liquidity) public {
               // Instead of adding liquidity to SunSwap:
               // 1. Transfer liquidity to attacker
               token.transfer(attacker, liquidity);
           }
       }
       ```

T+2h:  Attacker calls proxy admin function:
       - proxyadmin.upgradeTo(maliciousImpl)
       - LaunchpadProxy now delegates to MaliciousImpl
       - All future calls route to malicious code

T+3h:  Next graduation TX executes:
       - Graduation TX calls LaunchpadProxy.graduation(token, liquidity)
       - Proxy delegates to MaliciousImpl.graduation()
       - Malicious code transfers 100k TRX + 200M tokens to attacker
       - User funds drained; legitimate graduation never occurs

T+4h:  Attacker repeats for next 50 graduating tokens:
       - Total drain: ~5M TRX + 10B tokens
       - Escape via mixer/bridge
```

**Attack Difficulty:** MEDIUM
- Requires admin key or insider access
- Exploit execution is trivial (1 TX)
- Detection delay: Likely >1 hour (before monitoring alerts)

**Impact:**
- All active tokens' graduation liquidity drained (~$1M-$10M)
- Protocol credibility destroyed
- User lawsuits/regulatory action
- SUN token price collapse

**Detection:**
- Monitor for `upgradeTo` TX on LaunchpadProxy
- Verify implementation address in real-time
- Alert on implementation swap (email, Telegram, Discord)
- Audit trail: Log all implementation changes

**Remediation:**
- Use multisig on proxy admin (2-of-3 or 3-of-5)
- Implement time-lock (2-7 day delay) before upgrade executes
- Emit `ProxyUpgraded` event to off-chain monitoring
- Snapshot implementation hash before each upgrade
- Use UUPS pattern instead of transparent proxy
- Remove proxy post-stabilization (immutable code)
- Require governance vote for upgrades (SUN DAO)

---

## Scenario 4: Reentrancy in Graduation (HIGH)

**Objective:** Drain graduation liquidity via reentrancy callback

**Attacker Profile:** Smart contract researcher, 1 TRX seed capital

**Timeline:**

```
T0:    Attacker deploys malicious token contract:
       ```solidity
       contract MaliciousToken {
           address sunpump = 0xTTfvyrAz86hbZk5iDpKD78pqLGgi8C7AAw;
           
           function transfer(address to, uint amount) public {
               // Step 1: Accept transfer from SunPump
               balanceOf[msg.sender] -= amount;
               balanceOf[to] += amount;
               
               // Step 2: Reenter SunPump during transfer
               ISunPump(sunpump).saleToken(this, 1000000);
               // Sells tokens back while graduation is in progress
           }
       }
       ```

T+1h:  Attacker creates token on SunPump using malicious token contract

T+2h:  Token reaches 100% curve completion
       - Graduation TX triggers: LaunchpadProxy.graduation(malicious_token)

T+3h:  Graduation executes:
       - Step 1: LaunchpadProxy transfers 200M tokens to SunSwap router
       - Step 2: Transfer calls MaliciousToken.transfer()
       - Step 3: Malicious token reenters saleToken() on SunPump
       - Step 4: Sells tokens back on bonding curve (before state finalized)
       - Step 5: Receives TRX from curve
       - Step 6: Graduation liquidity reduced; attacker captures TRX

T+4h:  Attack result:
       - SunSwap receives fewer tokens than expected
       - Post-graduation liquidity pool is imbalanced
       - Attacker profit: ~1k-10k TRX depending on curve depth
```

**Attack Difficulty:** MEDIUM
- Requires malicious token contract (non-trivial code)
- Exploit requires understanding bonding curve state management
- Defense: Reentrancy guards (simple fix)

**Impact:**
- Graduation liquidity drained
- Pool imbalance causes slippage for users
- Late-stage curve participants see worse graduation prices

**Detection:**
- Monitor saleToken() calls during graduation() execution
- Alert on reentrancy pattern (call stack depth > 2)
- Audit token contract for fallback/receive functions

**Remediation:**
- Add ReentrancyGuard to graduation() function
- Use checks-effects-interactions pattern
- Validate token contract before graduation (no fallback/receive)
- Use pull-over-push pattern for fee distribution

---

## Scenario 5: Slippage Manipulation via Sandwich (MEDIUM)

**Objective:** Extract profit by sandwiching user trades on bonding curve

**Attacker Profile:** MEV bot operator, 100 TRX seed capital

**Timeline:**

```
T0:    User broadcasts large purchase:
       - purchaseToken(token, amount=500 TRX, minOut=40M tokens)
       - Expected: 500 TRX = 40M tokens at current curve price

T+1s:  Attacker monitors mempool:
       - Detects user's large purchase
       - Curve price will inflate due to user's purchase
       - Opportunity: Front-run with smaller purchase, back-run with sale

T+2s:  Attacker TX1 (front-run):
       - purchaseToken(token, amount=100 TRX)
       - Buys 8M tokens, inflates curve price
       - User's 500 TRX now worth fewer tokens due to higher price

T+3s:  User TX (victim):
       - purchaseToken(token, amount=500 TRX, minOut=40M)
       - Current price: 1 TRX = 70k tokens (inflated by attacker)
       - User receives only 35M tokens (35% slippage)
       - minOut = 40M; TX reverts (user loses gas)

T+4s:  Attacker TX2 (back-run):
       - If user's TX reverted: saleToken(token, 8M, minOut=90 TRX)
       - Sells attacker's tokens, captures profit
       - Profit: ~100 TRX cost - ~95 TRX sale + 1% fees = -6 TRX

T+5s:  Attacker retries with larger position:
       - Front-run: 200 TRX, Back-run: 150 TRX
       - User's 500 TRX TX reverts due to slippage
       - Attacker captures spread over many iterations

T+1m:  Cumulative attacker profit:
       - ~50 sandwich attacks per minute
       - ~20 TRX profit per sandwich
       - ~1000 TRX profit per minute = $10-20/minute (depending on TRX price)
```

**Attack Difficulty:** EASY
- Requires MEV bot (Flashbots-style infrastructure)
- Mempool is public (no private TRX RPC standard)
- High-frequency attack; high success rate

**Impact:**
- User slippage and failed transactions
- Reduced effective yield for traders
- Price manipulation on bonding curve
- Late participants lose to sandwich bots

**Detection:**
- Monitor for buy → large purchase → sell patterns
- Alert on high-variance price swings
- Track MEV extractor addresses

**Remediation:**
- Use batch auctions (CoW Swap-style)
- Implement time-locked orders (commit-reveal)
- Use private RPC relay for user trades
- Add MEV-resistant order aggregation
- Provide off-chain price feeds with tight tolerance bands

---

## Common Kill Chain: Full Graduation Attack

**Combines Scenarios 1 + 4 + 2 for maximum damage:**

```
T0:    Attacker identifies graduating token worth $100k liquidity
T+1h:  Deploys malicious token clone ("REAL_TOKEN") via poisoning
T+2h:  Deploys reentrancy exploit token as backup attack
T+3h:  Monitors token approaching 100% curve completion
T+4h:  Executes graduation MEV:
       - Front-run: Buy 10k TRX worth before graduation
       - Graduation executes (triggers reentrancy drain)
       - Back-run: Sell tokens at inflated DEX price
       - Result: 40-60% profit on MEV + reentrancy drain
T+5h:  Repeats for next 5-10 graduating tokens
T+6h:  Ecosystem reputation damaged; users lose $500k-$1M
```

**Total attack time:** 6 hours  
**Attacker skill:** Advanced (reentrancy + MEV + social engineering)  
**Attacker profit:** $50k-$200k  
**User losses:** $500k-$1M+

---

## Mitigation Hierarchy

### Immediate (Prevent Scenarios 1, 3, 5)
1. Time-lock proxy upgrades (24-48 hours)
2. Private RPC for graduation TX (MEV protection)
3. Multisig on admin functions (2-of-3 minimum)

### Short-term (Prevent Scenarios 2, 4)
1. Token registry with dispute resolution
2. Reentrancy guards on all multi-contract calls
3. Token contract validation before graduation

### Medium-term (Prevent All Scenarios)
1. Formal security audit (CertiK / Trail of Bits)
2. Bug bounty program ($5k-$50k per finding)
3. Liquidity lock post-graduation (burn LP tokens)
4. Governance decentralization (SUN DAO multisig)

