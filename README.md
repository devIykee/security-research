# Security Research Portfolio

<div align="center">

![Security Research](https://img.shields.io/badge/Security-Research-red?style=for-the-badge&logo=security&logoColor=white)
![Smart Contracts](https://img.shields.io/badge/Smart-Contracts-blue?style=for-the-badge&logo=ethereum&logoColor=white)
![Blockchain](https://img.shields.io/badge/Multi-Chain-green?style=for-the-badge&logo=blockchain&logoColor=white)

**Researcher:** [deviykee](https://x.com/deviykee) | Smart contract security audits and vulnerability research

</div>

---

## 📊 Audit Progress

<div align="center">

### 9 / 109 Audits Complete

```
████▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
```

![Complete](https://img.shields.io/badge/Complete-9_audits-success?style=flat-square)
![In Progress](https://img.shields.io/badge/In_Progress-39_audits-yellow?style=flat-square)
![Initial](https://img.shields.io/badge/Initial-61_audits-lightgrey?style=flat-square)

![Progress](https://img.shields.io/badge/Progress-8%25-brightgreen?style=flat-square)
![Vulnerabilities](https://img.shields.io/badge/Vulnerabilities-50+-critical?style=flat-square&logo=target)

**Last Updated:** 2026-09-19 09:51 UTC

</div>

---

## 🎯 Notable Findings

<table>
<tr>
<td width="50%">

### 🔴 Critical Vulnerabilities
- **JustLend DAO** - 6 Critical, 2 High ($100M+ MEV)
- **SunPump** - 3 Critical, 3 High, 5 Medium
- **TronPad** - 3 Critical, multiple High
- **RadarDEX** - Critical pool drain
- **Aumo** - 1 Critical-class, 5 High

</td>
<td width="50%">

### 🟠 High Impact
- **Solana Mobile** - SGT verification bypass
- **TronBid** - 5 High/Critical findings
- **Sheriff.money** - Burn-path DoS
- **Ellipse** - v4 analysis (secure)

</td>
</tr>
</table>

---

## 📁 Repository Structure

```
security-research/
├── hunts/                      # Individual audit reports
│   ├── ellipse/                # ✓ Uniswap v4 (no vulns)
│   ├── aumo/                   # ✓ 1 Critical-class, 5 High
│   ├── sunpump/                # ✓ 3 Critical, 3 High
│   ├── justlend/               # ✓ 6 Critical, 2 High
│   └── [109+ more...]
├── tools/                      # Security research tools
├── iykes-evm-bughunt-skill/    # Bug hunting methodology
└── .github/workflows/          # Auto-update automation
```

---

## 🔍 Coverage by Blockchain

<div align="center">

| Blockchain | Protocols Audited | Key Findings |
|:----------:|:-----------------:|:------------:|
| ![TRON](https://img.shields.io/badge/TRON-FF0013?style=flat-square&logo=tron&logoColor=white) | SunPump, JustLend, TronPad, TronBid, SunSwap | 15+ Critical/High |
| ![Ethereum](https://img.shields.io/badge/Ethereum-3C3C3D?style=flat-square&logo=ethereum&logoColor=white) | Aumo, Sheriff, Convex, Liquity | 10+ High |
| ![Solana](https://img.shields.io/badge/Solana-9945FF?style=flat-square&logo=solana&logoColor=white) | Mobile Wallet Adapters | 1 Critical |
| ![Bitcoin](https://img.shields.io/badge/Bitcoin-F7931A?style=flat-square&logo=bitcoin&logoColor=white) | GOAT Network BitVM3 | zkRollup audit |
| ![Arc](https://img.shields.io/badge/Arc-5042-blue?style=flat-square) | Ellipse Launchpad | Secure (0 vulns) |
| ![Multi](https://img.shields.io/badge/Multi--Chain-000000?style=flat-square&logo=chainlink&logoColor=white) | LayerZero, Synapse, Hop | Bridge security |

</div>

---

## 🛠️ Methodology

<table>
<tr>
<td width="70%">

**Bug Hunting Framework:** [iykes-evm-bughunt-skill v0.3.0](./iykes-evm-bughunt-skill/)

#### Core Features
- ✅ Systematic 10-step audit process
- ✅ **Proactive problem-solving** (auto-overcomes blockers)
- ✅ Step 3.5: Bytecode analysis for unverified contracts
- ✅ Comprehensive fork testing (Foundry)
- ✅ Multi-angle adversarial review
- ✅ Honest severity assessment

#### Innovation
First bug hunting skill with **automatic blocker resolution** - finds and installs tools when encountering unverified contracts or missing dependencies.

</td>
<td width="30%">

#### Tools Used

![Foundry](https://img.shields.io/badge/Foundry-000000?style=flat-square&logo=ethereum)
![Slither](https://img.shields.io/badge/Slither-8B5CF6?style=flat-square)
![Solidity](https://img.shields.io/badge/Solidity-363636?style=flat-square&logo=solidity)

**Custom:**
- Bytecode Analyzer
- Fork Testing Suite
- Coverage Tracker

</td>
</tr>
</table>

---

## 📈 Statistics

<div align="center">

| Metric | Count |
|:-------|------:|
| **Total Audits** | 109 |
| **Complete with Findings** | 9 (8%) |
| **Total Vulnerabilities** | 50+ |
| **Critical Issues** | 15+ |
| **High Severity** | 20+ |
| **Blockchains Covered** | 8+ |
| **PoC Tests Written** | 100+ |

</div>

---

## 📝 Responsible Disclosure

<div align="center">

![Ethical](https://img.shields.io/badge/Ethical-Hacking-success?style=flat-square&logo=hackaday)
![Responsible](https://img.shields.io/badge/Responsible-Disclosure-blue?style=flat-square&logo=security)
![No Exploits](https://img.shields.io/badge/No_Mainnet-Exploits-red?style=flat-square&logo=ethereum)

</div>

All vulnerabilities are disclosed responsibly:
1. 🔒 Private notification to project team
2. ⏰ 90-day fix window (standard)
3. 🛠️ PoC and mitigation assistance provided
4. 📢 Public disclosure only after patch deployed

**Never exploit mainnet. Fork/eth_call verification only.**

---

## 📬 Contact

<div align="center">

[![Twitter](https://img.shields.io/badge/Twitter-@deviykee-1DA1F2?style=for-the-badge&logo=twitter&logoColor=white)](https://x.com/deviykee)
[![GitHub](https://img.shields.io/badge/GitHub-devIykee-181717?style=for-the-badge&logo=github&logoColor=white)](https://github.com/devIykee)

**Available for private audits and security consulting**

</div>

---

## 📜 License

<div align="center">

![License](https://img.shields.io/badge/License-MIT-green?style=flat-square)

Research methodologies and tools: MIT License  
Individual audit reports: All rights reserved

</div>

---

<div align="center">

**⚠️ Disclaimer**

This repository contains security research for educational purposes.  
All findings are disclosed responsibly. No mainnet exploits are performed.

![Security](https://img.shields.io/badge/Stay-Secure-brightgreen?style=flat-square&logo=shieldsdotio)

</div>
