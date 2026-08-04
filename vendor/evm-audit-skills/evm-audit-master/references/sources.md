# EVM Audit Skill Suite — Source Tracking

Date fetched: 2026-02-27

## Successfully Fetched Sources

### Dacian Articles (via archive.org — all 8 articles)
| Source | URL | Status |
|--------|-----|--------|
| DeFi Liquidation Vulnerabilities | https://dacian.me/defi-liquidation-vulnerabilities | ✅ via archive.org (50KB, truncated — very dense) |
| CLM Vulnerabilities | https://dacian.me/concentrated-liquidity-manager-vulnerabilities | ✅ via archive.org (20KB, complete) |
| DeFi Slippage Attacks | https://dacian.me/defi-slippage-attacks | ✅ via archive.org (27KB, complete) |
| Precision Loss Errors | https://dacian.me/precision-loss-errors | ✅ via archive.org (30KB, complete) |
| Signature Replay Attacks | https://dacian.me/signature-replay-attacks | ✅ via archive.org (15KB, complete) |
| DAO Governance DeFi Attacks | https://dacian.me/dao-governance-defi-attacks | ✅ via archive.org (50KB, truncated) |
| Inline Assembly Vulnerabilities | https://dacian.me/solidity-inline-assembly-vulnerabilities | ✅ via archive.org (35KB, complete) |
| Lending/Borrowing DeFi Attacks | https://dacian.me/lending-borrowing-defi-attacks | ✅ via archive.org (29KB, complete) |

### Devdacian GitHub
| Source | URL | Status |
|--------|-----|--------|
| AI Auditor Primers — base.primer.md | https://raw.githubusercontent.com/devdacian/ai-auditor-primers/main/primers/base.primer.md | ✅ (33KB) |
| AI Auditor Primers — amy.vault.erc4626.primer.md | https://raw.githubusercontent.com/devdacian/ai-auditor-primers/main/primers/amy.vault.erc4626.primer.md | ✅ listed (299KB — too large to process fully) |
| Primers repo tree | https://api.github.com/repos/devdacian/ai-auditor-primers/git/trees/main?recursive=1 | ✅ (2 primers found) |

### RareSkills
| Source | URL | Status |
|--------|-----|--------|
| Smart Contract Security | https://www.rareskills.io/post/smart-contract-security | ✅ via archive.org (50KB, truncated) |
| UUPS Proxy | https://www.rareskills.io/post/uups-proxy | ✅ via archive.org (21KB, complete) |

### Sigma Prime
| Source | URL | Status |
|--------|-----|--------|
| Governance & DAOs | https://blog.sigmaprime.io/governance-dao.html | ✅ direct (17KB) |
| Oracles & Pricing | https://blog.sigmaprime.io/oracles-and-pricing.html | ✅ direct (20KB) |
| Liquid Restaking | https://blog.sigmaprime.io/liquid-restaking.html | ✅ direct (26KB) |

### Cyfrin / Dacian
| Source | URL | Status |
|--------|-----|--------|
| Chainlink Oracle Security | https://medium.com/cyfrin/chainlink-oracle-defi-attacks-93b6cb6541bf | ✅ direct (22KB) |

### SWC Registry
| Source | URL | Status |
|--------|-----|--------|
| README | https://raw.githubusercontent.com/SmartContractSecurity/SWC-registry/master/README.md | ✅ (registry no longer maintained since 2020, superseded by EEA EthTrust Security Levels) |

## Failed Sources

| Source | URL | Reason |
|--------|-----|--------|
| Dacian direct (all URLs) | https://dacian.me/* | 429 — Vercel Security Checkpoint (bot protection). Resolved via archive.org. |
| ConsenSys Best Practices | https://consensys.github.io/smart-contract-best-practices/attacks/ | 404 — GitHub Pages site no longer at this path |
| MixBytes — Liquid Staking | https://mixbytes.io/blog/liquid | Fetch failed (connection error) |
| MixBytes — Account Abstraction | https://mixbytes.io/blog/account-abstraction | Not attempted (similar expected failure) |
| Solodit Checklist | https://solodit.cyfrin.io/checklist | JS-rendered, requires browser. Archive.org not attempted. |
| Blast Integration Bugs | https://nirlin-blast-bugs.notion.site/... | Notion pages require JS rendering |
| DeFi Llama Hacks | https://defillama.com/hacks | JS-rendered dashboard |
| Rekt News | https://rekt.news | Referenced in articles but not independently fetched |
| OpenZeppelin CHANGELOG | https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/CHANGELOG.md | Not fetched (very large, low signal-to-noise ratio) |

## Notes

- **SWC Registry** has not been updated since 2020 and has been superseded by the [EEA EthTrust Security Levels Specification](https://entethalliance.org/specs/ethtrust-sl/). All SWC weaknesses were incorporated into that spec. Existing checklist items already cover the most critical SWC entries.
- **Devdacian's base.primer.md** (33KB) is an extremely high-quality comprehensive primer covering lending, liquidation, signatures, precision, slippage, oracle, CLM, staking, auction, and reentrancy vulnerability patterns with detailed invariants and checklists. Content from this primer has been cross-referenced and integrated.
- All Dacian articles were successfully fetched via Wayback Machine (archive.org) after direct access was blocked by Vercel bot protection.
- Total extracted content: ~450KB of high-quality audit security content processed into checklist items across 8+ skill files.
