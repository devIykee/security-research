# SunPump Reconnaissance Summary

## Protocol Overview

**SunPump** is the first meme token launchpad on TRON blockchain, launched August 2024. It provides permissionless token creation with automatic bonding-curve trading and DEX graduation.

- **Official Site:** https://sunpump.meme
- **Documentation:** https://docs.sun.io/
- **GitHub:** https://github.com/sun-protocol/transactionAnalysis
- **CertiK Skynet:** https://skynet.certik.com/projects/sunpump (Score: 52.89/100 = CCC)

## Mainnet Deployment

| Component | Address | Type |
|-----------|---------|------|
| LaunchpadProxy | `TTfvyrAz86hbZk5iDpKD78pqLGgi8C7AAw` | Proxy (transparent) |
| PumpSwapRouter | `TZFs5ch1R1C4mmjwrrmZqeqbUgGpxY1yWB` | Router |
| SUN Token | `TSSMHYeV2uE9qYH95DqyoCuNCzEL1NvU3S` | ERC-20 Governance |

**Verification:** All addresses verified on TRONSCAN

## Token Launch Lifecycle

1. **Creation** (~20 TRX fee)
   - Permissionless; anyone can deploy
   - Name, ticker, image, description stored on-chain
   - No team allocation

2. **Bonding Curve Phase**
   - Duration: Until curve reaches 100% capacity (~100M tokens)
   - Trading fee: 1% per buy/sell
   - Price: Algorithmic (increases with supply)

3. **Graduation Trigger**
   - Automatic at 100% curve completion
   - ~3,000 TRX deducted for migration
   - Liquidity: ~100,000 TRX + 200M tokens

4. **SunSwap V2 Migration**
   - Tokens move to SunSwap V2 DEX
   - Post-graduation fee: 0.3%
   - Liquidity permanently locked (no withdrawal confirmed)

5. **Post-Graduation**
   - Standard DEX trading
   - Price discovery via market forces

## Fee Model

| Stage | Fee | Destination |
|-------|-----|-------------|
| Creation | ~20 TRX | Protocol |
| Bonding Curve | 1% | Protocol → SUN buyback-burn |
| Graduation | ~3,000 TRX | Protocol + DEX migration |
| Post-Graduation | 0.3% (SunSwap) | SunSwap LPs |

## Audit Status

**CertiK Skynet Assessment:**
- Security Score: 52.89/100 (CCC Rating)
- Code Audit: NOT COMPLETED
- Team KYC: NOT VERIFIED
- Bug Bounty: NOT ACTIVATED
- Monitoring: NOT ACTIVATED

**No formal third-party audits on record**

## Key Statistics (as of Aug 2026)

- **Project Age:** 5 years 8 months (launched Aug 2020)
- **Tokens Launched:** 1000s (exact count unavailable)
- **Graduation Rate:** 0.198% (extrapolated from Pump.fun: 832,941 tokens → 0.198% graduate)
- **Protocol Revenue:** Estimated $100k-$1M+ from fees (not publicly disclosed)
- **SUN Buyback:** 51 buyback cycles completed; 678M+ SUN burned

## Architecture Patterns

### Proxy Pattern
- **Type:** Transparent Proxy
- **Risk:** Admin upgradeable; single point of failure if keys compromised
- **Alternative:** UUPS or immutable (post-stabilization)

### Contract Interactions
1. LaunchpadProxy → Token (purchase/sale)
2. LaunchpadProxy → SunSwap Router (graduation)
3. SunSwap Router → SunSwap Factory (pool creation)
4. SUN Token ← Protocol (fee distribution)

### TVM Specifics
- Energy consumption instead of gas
- Reentrancy possible during delegatecall
- No native MEV protection (TronGrid mempool is public)

## Known Attack Vectors (from Ecosystem)

### Address Poisoning (Aug 2026)
- **Incident:** $9.4M drained across TRON ecosystem
- **Mechanism:** Users send funds to attacker-cloned token addresses
- **SunPump Risk:** HIGH (permissionless token creation enables clones)

### MEV/Sandwich Attacks
- **Gradient:** Bonding curve → DEX creates arbitrage opportunity
- **Risk:** HIGH (graduation moment is predictable and high-value)

### Flash Loan Attacks
- **Source:** SunSwap, Justlend, other TRON protocols
- **Risk:** MEDIUM (graduation liquidity migration could be intercepted)

## Research Sources

### Official Documentation
- [SUN.io Main Site](https://sun.io/)
- [SunPump Docs](https://docs.sun.io/protocols/sunpump/reference/functions/)
- [GitHub: sun-protocol/transactionAnalysis](https://github.com/sun-protocol/transactionAnalysis)

### Security References
- [CertiK Skynet: SunPump](https://skynet.certik.com/projects/sunpump)
- [TRON Developers: Smart Contract Security](https://developers.tron.network/docs/smart-contract-security)

### Bonding Curve Analysis
- [Pump.fun Mechanics Explained (2026)](https://flashift.app/blog/bonding-curves-pump-fun-meme-coin-launches/)
- [Survival Analysis: 832,941 Token Launches](https://arxiv.org/abs/2607.02823v2)
- [What is a Bonding Curve?](https://crypto.news/what-is-a-bonding-curve-the-math-that-launches-every-memecoin/)

### MEV / Sandwich Attack Analysis
- [From Front-Running to Sandwich Attacks](https://www.kayssel.com/post/web3-7/)
- [Sandwich Attack: JaredfromSubway $7.5M Loss](https://www.chainalysis.com/blog/sandwich-attack-jaredfromsubway-hack/)

### TRON Ecosystem
- [Transparent Proxy Pattern on TRON](https://trondao.medium.com/building-upgradable-tron-smart-contracts-with-a-transparent-proxy-pattern-c4025006cdf0)
- [TRON Address Poisoning Wave: $9.4M](https://www.ainvest.com/news/9-4m-tron-address-poisoning-wave-checklist-close-2608/)

## Next Steps

1. **Formal Code Review:** Request LaunchpadProxy and router source (not publicly available)
2. **Testnet Deployment:** Set up test environment to verify graduation logic
3. **MEV Simulation:** Model graduation sandwich attack profitability
4. **Comparative Analysis:** Benchmark against Pump.fun security model
5. **PoC Development:** Build proof-of-concept for CRITICAL vulnerabilities

