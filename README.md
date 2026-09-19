# Security Research Portfolio

**Researcher:** deviykee ([@deviykee](https://x.com/deviykee))

Smart contract security audits and vulnerability research across multiple blockchain ecosystems.

## 📊 Audit Progress

🟩🟩🟩🟩🟩🟩🟩🟩🟩🟩🟩🟩🟩🟩🟩🟩🟩🟩🟩🟩🟩🟩🟩🟩🟩🟩🟩🟩🟩🟩🟩🟩🟨🟨🟨🟨🟨⬜⬜⬜⬜⬜⬜⬜⬜⬜⬜⬜⬜⬜

```
Total Audits:     44
✅ Complete:      29 (65%)
⏳ In Progress:   5 (11%)
📋 Initial:       10
```

**Last Updated:** 2026-09-19 09:44 UTC

**🤖 Auto-updates:** This progress bar automatically updates when new hunts are added!

---

## 🏆 Notable Findings

### Critical Vulnerabilities
- **JustLend DAO** - 6 Critical, 2 High ($100M+ MEV leakage)
- **SunPump** - 3 Critical, 3 High, 5 Medium
- **TronPad** - 3 Critical, multiple High
- **RadarDEX** - Critical pool drain vulnerability
- **Aumo** - 1 Critical-class, 5 High

### High Impact
- **Solana Mobile** - SGT verification bypass
- **TronBid** - 5 High/Critical findings
- **Sheriff.money** - Burn-path DoS
- **Ellipse** - Comprehensive Uniswap v4 hook analysis (no vulnerabilities found)

---

## 📁 Repository Structure

```
security-research/
├── hunts/              # Individual audit reports (44 audits)
│   ├── ellipse/        # ✅ Complete - Uniswap v4 (no vulns)
│   ├── aumo/           # ✅ Complete - 1 Critical-class, 5 High
│   ├── sunpump/        # ✅ Complete - 3 Critical, 3 High
│   ├── justlend/       # ✅ Complete - 6 Critical, 2 High
│   └── ...             # 40+ more audits
├── tools/              # Security research tools
├── iykes-evm-bughunt-skill/  # Bug hunting methodology (submodule)
└── docs/               # Documentation
```

---

## 🔍 Audit Coverage

### By Blockchain
- **TRON:** SunPump, JustLend, TronPad, TronBid, SunSwap
- **Ethereum/L2:** Aumo, Sheriff, Base Dollar, BasedAlpha, Convex
- **Solana:** Solana Mobile wallet adapters
- **Bitcoin:** GOAT Network BitVM3
- **Arc:** Ellipse launchpad
- **Multi-chain:** Long.supply bridge, LayerZero OmniChain

### By Protocol Type
- **DEX/AMM:** RadarDEX, SunSwap, Sheriff, Ellipse
- **Launchpad:** SunPump, TronPad, Argus, BasedAlpha
- **Lending:** JustLend, Aumo, Liquity v1
- **Bridge:** Long.supply, Synapse, LayerZero, Hop
- **NFT/Auction:** TronBid, PinkSale
- **Infrastructure:** Solana Mobile, GOAT BitVM3

---

## 🛠️ Methodology

**Bug Hunting Skill:** [iykes-evm-bughunt-skill v0.3.0](./iykes-evm-bughunt-skill/)

**Key Features:**
- ✅ Systematic 10-step audit process
- ✅ Proactive problem-solving (Step 3.5 bytecode analysis)
- ✅ Comprehensive fork testing (Foundry)
- ✅ Multi-angle adversarial review
- ✅ Honest severity assessment
- ✅ Auto-overcoming blockers (finds tools when blocked)

**Tools:**
- **Foundry** - Fork testing & PoC development
- **Slither** - Static analysis
- **Custom bytecode analyzer** - `analyze-bytecode.sh`
- **Manual code review** - With coverage tracking

**Innovation:** First bug hunting skill with proactive problem-solving - automatically finds/installs tools to overcome blockers like unverified contracts.

---

## 📝 Responsible Disclosure

All vulnerabilities are disclosed responsibly:
1. Private notification to project team
2. 90-day fix window (standard)
3. PoC and mitigation assistance provided
4. Public disclosure only after patch deployed

**Never exploit mainnet. Fork/eth_call verification only.**

---

## 📈 Statistics

- **Total Audits:** 44
- **Complete with Findings:** 29 (66%)
- **Total Vulnerabilities Found:** 50+
- **Critical Issues:** 15+
- **High Severity:** 20+
- **Chains Covered:** 8+ (TRON, Ethereum, Solana, Bitcoin, Arc, etc.)
- **PoC Tests Written:** 100+ (Foundry)

---

## 📬 Contact

- **Twitter/X:** [@deviykee](https://x.com/deviykee)
- **GitHub:** [@devIykee](https://github.com/devIykee)
- **Email:** Available for private audits and security consulting

---

## 📜 License

Research methodologies and tools: MIT License  
Individual audit reports: All rights reserved

---

**⚠️ Disclaimer:** This repository contains security research for educational purposes. All findings are disclosed responsibly. No mainnet exploits are performed.
