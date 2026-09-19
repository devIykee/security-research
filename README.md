# Iyke

blockchain security researcher, solana and evm

[@deviykee](https://github.com/devIykee) · [@deviykee](https://x.com/deviykee) · [@deviykee](https://t.me/deviykee)

---

## 📊 audit progress

<div align="center">

### 9 / 109 Audits Complete

```
🟩🟩🟩🟩🟩🟩🟩🟩🟩🟩🟩🟩🟩🟩🟩🟩🟩🟩🟩🟩🟩🟩🟩🟩🟩🟩🟩🟩🟩🟩🟩🟩🟨🟨🟨🟨🟨⬜⬜⬜⬜⬜⬜⬜⬜⬜⬜⬜⬜⬜
```

![Complete](https://img.shields.io/badge/Complete-9_audits-success?style=flat-square)
![In Progress](https://img.shields.io/badge/In_Progress-39_audits-yellow?style=flat-square)
![Initial](https://img.shields.io/badge/Initial-61_audits-lightgrey?style=flat-square)

![Progress](https://img.shields.io/badge/Progress-8%25-brightgreen?style=flat-square)
![Vulnerabilities](https://img.shields.io/badge/Vulnerabilities-50+-critical?style=flat-square&logo=target)

**Last Updated:** 2026-09-19

</div>

---

## summary

i find vulnerabilities in smart contracts and DeFi protocols across Solana and EVM chains. my work covers initialization races, front-running, MEV, custody bugs, and access control flaws. i have shipped open-source security tooling for address poisoning detection, trade validation, and multi-chain key management.

---

## focus areas

- initialization and migration race conditions
- front-running and MEV exploitation paths
- address poisoning and signature validation
- custody and key management
- access control and privilege escalation
- bonding curves and AMM design flaws

---

## selected findings

| target | chain | vulnerability class | severity | status | date | report |
|--------|-------|---------------------|----------|--------|------|--------|
| TollyPad | Arc | pool initialization race (TOCTOU) | critical | under review | aug 2026 | [report](hunts/tollylabs/CRITICAL-FINDING-pool-init-race.md) |
| Solana Mobile | Solana | SGT zero-balance ATA bypass | critical | bounty submitted | aug 2026 | [report](hunts/solana-mobile/REPORT.md) |
| Aumo | EVM | dust redeem full liquidation (O(TVL) loss) | high (critical-class) | disclosed, private | aug 2026 | [report](hunts/aumo/reports/FINDINGS-MASTER.md) |
| Aumo | EVM | unrealizable NAV allows preferential drain | high | disclosed, private | aug 2026 | [report](hunts/aumo/reports/FINDINGS-MASTER.md) |
| SunPump | TRON | graduation migration MEV/flash arbitrage | critical | research | aug 2026 | [report](hunts/sunpump/FINDINGS.md) |
| JustLend | TRON | multiple critical MEV paths (\$100M+ exposure) | critical | research | aug 2026 | [report](hunts/justlend/FINDINGS.md) |
| RadarDEX | EVM | pool squat attack | critical | research | 2026 | [report](hunts/radardex/REPORT-Critical-Pool-Squat.md) |
| Sheriff | Robinhood Chain | burn-path DoS when registry zero | medium | disclosed, private | aug 2026 | [report](hunts/sheriff/reports/FINDINGS-MASTER.md) |
| Ellipse | Arc | comprehensive Uniswap v4 hook analysis | none found | complete | sep 2026 | [report](hunts/ellipse/FINAL-COMPREHENSIVE-REPORT.md) |

---

## security tooling

**AddressGuard**  
address poisoning and ENS typosquat detector. scans transaction history for zero-value transfers and look-alike addresses.

**TradeGuard**  
pre-flight trade validator for AI trading agents. ships as an MCP proxy and hook. validates slippage, liquidity depth, and counterparty risk before execution.

**MCW** ([@deviykee/mcw](https://npmjs.com/package/@deviykee/mcw))  
multi-chain CLI wallet and MCP server. manages BTC, ETH, SOL, and TRON from one BIP-39 seed with AES-256-GCM encryption. human-in-the-loop approval flow for agent transactions.

---

## research experience

- **aug 2026:** disclosed critical pool initialization race in TollyPad on Arc.
- **aug 2026:** submitted Solana Mobile SGT verification bypass to official bug bounty program.
- **aug 2026:** disclosed 1 critical-class and 5 high-severity findings in Aumo DeFi vault (private audit, pre-mainnet).
- **aug 2026:** disclosed burn-path DoS in Sheriff.money AMM on Robinhood Chain.
- background in wallet custody and key management from the builder side.

---

## skills

**languages:** rust, solidity, typescript, javascript  
**chains:** solana (anchor, token-2022), ethereum, arbitrum, base, TRON, arc, robinhood chain  
**security:** smart contract auditing, race condition analysis, MEV research, threat modeling, key management, fork testing (foundry)  
**tools:** foundry, slither, anchor, web3.js, solana-web3.js, ethers.js

---

## disclosure approach

i disclose responsibly to project teams without preconditions. i provide PoC code, reproduction steps, and mitigation guidance. i discuss compensation after the vulnerability is understood and validated. i never exploit mainnet. all verification is fork-based or read-only.

---

## contact

github: [@deviykee](https://github.com/devIykee)  
twitter: [@deviykee](https://x.com/deviykee)  
telegram: [@deviykee](https://t.me/deviykee)

---

bug hunting methodology: [iykes-evm-bughunt-skill](./iykes-evm-bughunt-skill/)  
full findings archive: [hunts/](./hunts/)  
previous portfolio README: [docs/README-old.md](./docs/README-old.md)
