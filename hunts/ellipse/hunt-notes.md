# Ellipse Launchpad V6 - Bug Hunt Notes

## Product Understanding

**Type:** Launchpad using Uniswap v4 pools with custom launch hook

**Mechanism:**
- Fixed 1B supply tokens launched atomically
- Uniswap v4 pool with 0% built-in fee
- Custom launch hook (0x143d72d4bd0f0e1a6c6fd4f2f671a45d9e003a88) manages fees and liquidity
- Hook "refuses every removal" of liquidity (permanent lock)
- Only launchpad and buyback reserve can add liquidity

**Fee Structure:**
- Anti-sniper: 95% → 70% → 40% → 10% → 1% permanent
- Anti-sniper split: 10% protocol, 10% creator, 80% buyback reserve
- Regular 1% fee: 50/50 or 30/30/40 (creator/protocol/holders)

**Key Contracts:**
- Launchpad V6: 0x66bdc0803807f8a62763943fb2dd584ed9fb9c16 (0 ETH balance)
- Launch Hook V6: 0x143d72d4bd0f0e1a6c6fd4f2f671a45d9e003a88 (0 ETH balance)
- Buyback Reserve: 0xea51ef0975a238cbbbc9edad537ec4be4f6ede7a (0 ETH balance)
- Reward Vault: 0x2941208f4415825c512bdcccd0cb9561a3f093ed (0 ETH balance)

## High-Priority Attack Vectors (based on skill Step 6.5)

### 1. Migration pool squat (v4 variant)
**Pattern:** Pre-initialize pool at wrong price before launch
- Check: Does launch verify pool doesn't exist?
- Check: Is there a price verification after pool creation?
- Impact: If attacker pre-creates pool at manipulated price, launch could dump at wrong ratio

### 2. Hook liquidity lock bypass
**Pattern:** "Hook refuses every removal" - but does it really?
- Check: Can liquidity be removed via Uniswap v4 PoolManager directly?
- Check: Are there re-entrancy paths during swap that allow removal?
- Check: Can hook permissions be bypassed?

### 3. Fee accrual and distribution manipulation
**Pattern:** Fees "accrued as credits in PoolManager, paid via distribuisci"
- Check: Can someone manipulate who receives fees?
- Check: Is there precision loss in fee accounting?
- Check: Can fee distribution be front-run or DOSed?

### 4. Buyback reserve manipulation
**Pattern:** Reserve gets 80% of anti-sniper fees, creates "standing bid"
- Check: How does buyback pricing work? Can it be gamed?
- Check: Can someone drain the buyback reserve?
- Check: Is there slippage protection on buyback execution?

### 5. Anti-sniper bypass
**Pattern:** First ~2 blocks have 95% fee, then phased reduction
- Check: Is block.number used? Can miner manipulation occur?
- Check: Can someone trigger fee phase changes early?
- Check: Are there timing windows to bypass high fees?

### 6. Dev buy manipulation
**Pattern:** "Optional dev buy up to 5%, fee-exempt"
- Check: Is 5% limit enforced?
- Check: Can dev buy happen multiple times?
- Check: Is fee exemption correctly implemented?

### 7. Precision/rounding issues
**Pattern:** Complex fee splits (30/30/40, 10/10/80)
- Check: Do percentages always sum correctly?
- Check: Can rounding be exploited for free tokens?
- Check: Loss on fee-on-transfer tokens?

## Step 4 Results
✅ All admin functions properly guarded (setAdmin, setGuardian, setUpdater)

## Next Steps
1. Get source code or decompile bytecode
2. Trace launch flow: launchpad → hook → pool creation
3. Trace swap flow: user swap → hook fee logic → distribution
4. Check pool initialization and price verification
5. Check liquidity lock implementation in hook
6. Test anti-sniper timing logic
