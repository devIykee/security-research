---
name: evm-audit-master
description: Master index for EVM smart contract security audit skills. Load this FIRST for every audit to determine which specialized skills to load. Contains routing table and audit methodology.
---
# EVM Smart Contract Security Audit — Master Index

## How To Use
1. **Always load this skill first** for any EVM smart contract audit
2. Read the contract(s) under audit
3. Use the routing table below to load relevant specialized skills
4. Walk through each loaded skill's checklist systematically

## All 20 Skills — Definitive Index

| # | Skill | Description | Items |
|---|-------|-------------|-------|
| 1 | **evm-audit-master** | This file. Routing table, methodology, source attribution. Load first. | — |
| 2 | **evm-audit-general** | Cross-cutting issues: storage pointers, struct deletion, mixed accounting, merkle proofs, msg.value in loops, try/catch, delegatecall, upgrades, downcasting, rebasing tokens, fee-on-transfer, ERC4626 inflation attack | 46+ |
| 3 | **evm-audit-precision-math** | Division-before-multiplication, rounding to zero, precision scaling mismatches, downcast overflow, rounding direction (protocol vs user), decimal assumption errors | 23+ |
| 4 | **evm-audit-erc20** | Fee-on-transfer, rebasing, ERC777 hooks, approve race conditions, zero-transfer reverts, pausable tokens, deny lists (USDC), deflationary/inflationary tokens, multiple-address tokens | 27+ |
| 5 | **evm-audit-defi-amm** | AMM/DEX slippage attacks, CLM vulnerabilities (TWAP bypass, sandwich via owner functions, stuck tokens, stale approvals, retrospective fees), UniswapV3/V4 hooks, fee tier issues | 30+ |
| 6 | **evm-audit-defi-lending** | Liquidation vulnerabilities (20+ patterns), lending/borrowing attacks, bad debt handling, partial liquidation bypasses, front-run prevention, collateral hiding, insurance fund edge cases, non-18 decimal failures | 33+ |
| 7 | **evm-audit-defi-staking** | Liquid staking, restaking, EigenLayer integration, stakedButUnverified accounting, Beacon Chain proof verification (Deneb), validator front-running, cooldown exploitation, reward calculation precision | 30+ |
| 8 | **evm-audit-erc4626** | Share/asset conversion, inflation attack, virtual shares, deposit/withdraw rounding, first depositor attack, multi-step operations, 85+ patterns from Dacian's ERC4626 primer | 42+ |
| 9 | **evm-audit-erc4337** | Account abstraction, smart wallet security, paymaster attacks, session key exploits, UserOperation validation, bundler trust assumptions, gas griefing | 18+ |
| 10 | **evm-audit-bridges** | Cross-chain bridge security, LayerZero V2, CCIP, Wormhole, Across, message replay, finality assumptions, relayer trust, adapter pattern issues | 32+ |
| 11 | **evm-audit-proxies** | UUPS deep dive (uninitialized implementation, delegatecall to selfdestruct, broken upgrade chain, authorization schema changes), Transparent proxy, Beacon, Diamond, storage collision, immutable variable loss | 18+ |
| 12 | **evm-audit-signatures** | Signature replay (missing nonce, cross-chain, missing parameter, no expiration), ecrecover return check, signature malleability, EIP-712 conformance, ECDSA library version requirements | 19+ |
| 13 | **evm-audit-governance** | DAO attacks (flash-loan + delegation bypass, voting power destruction, totalPower manipulation, snapshot staleness, quorum impossibility, treasury delegation abuse, restriction bypass, token recycling, proposal deadlines, pre-mint exploitation), proposal execution ordering, fake proposals via CREATE2, multi-sig quorum failure | 23+ |
| 14 | **evm-audit-oracles** | Chainlink integration (stale prices, L2 sequencer, per-feed heartbeats, decimal assumptions, wrong addresses, front-running, unhandled reverts, depeg detection, minAnswer/maxAnswer), Sigma Prime patterns (spot price manipulation, homegrown oracle risks, gas congestion, hardcoded pegs, TWAP limitations) | 29+ |
| 15 | **evm-audit-assembly** | Inline assembly memory corruption (external call overwrites, stale FMPA assumptions, insufficient allocation), call to non-existent contracts, overflow/underflow without protection, uint128 overflow evading 256-bit detection | 27+ |
| 16 | **evm-audit-chain-specific** | L2/alt-chain quirks — Arbitrum, Optimism, zkSync, Blast, BSC, Polygon. Sequencer downtime, different opcodes, gas pricing differences, precompile availability, block time assumptions | 29+ |
| 17 | **evm-audit-flashloans** | Flash loan attack patterns, oracle manipulation via flash loans, governance flash loan voting, flash mint issues, composability risks | 15+ |
| 18 | **evm-audit-erc721** | NFT-specific issues: onERC721Received callbacks, enumeration DoS, royalty enforcement, metadata manipulation, batch mint edge cases | 20+ |
| 19 | **evm-audit-dos** | Denial of service patterns: unbounded loops, block gas limit, self-destruct force-send, storage deletion costs, griefing via revert, return data bombs | 18+ |
| 20 | **evm-audit-access-control** | Access control patterns: missing modifiers, 2-step ownership, role-based permissions, emergency pause, time delays, admin overpowers | 15+ |

**Total: 500+ checklist items across 19 specialized skills + 1 master index**

## Routing Table — Which Skills To Load

| If the contract involves... | Load skill |
|---|---|
| **Any EVM contract** (always) | `evm-audit-general` |
| **Any math/pricing/fees** (always) | `evm-audit-precision-math` |
| Accepts ERC20 tokens (deposits, swaps, collateral) | `evm-audit-erc20` |
| AMM, DEX, swap router, Uniswap V3/V4 hooks, liquidity pools, CLMs | `evm-audit-defi-amm` |
| Lending, borrowing, CDP, liquidation, AAVE/Compound fork | `evm-audit-defi-lending` |
| Staking, liquid staking (stETH/rETH/cbETH), restaking, EigenLayer | `evm-audit-defi-staking` |
| ERC4626 vaults, share/asset conversion, yield vaults | `evm-audit-erc4626` |
| Account abstraction, smart wallets, paymasters, session keys | `evm-audit-erc4337` |
| Cross-chain bridges, LayerZero, CCIP, Wormhole, Across | `evm-audit-bridges` |
| Upgradeable contracts, proxies (UUPS/Transparent/Beacon/Diamond) | `evm-audit-proxies` |
| Off-chain signatures, EIP-712, permits, meta-transactions | `evm-audit-signatures` |
| DAO governance, voting, timelocks, multi-sig, proposal execution | `evm-audit-governance` |
| Price oracles (Chainlink, TWAP, Pyth), VRF, external data | `evm-audit-oracles` |
| Inline assembly, Yul, CREATE2, low-level calls, precompiles | `evm-audit-assembly` |
| Non-mainnet (Arbitrum, OP, zkSync, Blast, BSC, Polygon) | `evm-audit-chain-specific` |
| Flash loans, composability attacks | `evm-audit-flashloans` |
| NFTs, ERC721, ERC1155, metadata, royalties | `evm-audit-erc721` |
| DoS vectors, gas griefing, unbounded operations | `evm-audit-dos` |
| Access control, roles, ownership, emergency controls | `evm-audit-access-control` |

## Audit Methodology

### Phase 1: Reconnaissance
1. Fetch all contract files (raw GitHub URL or local path)
2. Identify all contract files, entry points, and external dependencies
3. Map inheritance hierarchy and proxy relationships
4. Identify all external calls and token interactions
5. Note the target deployment chain(s)

### Phase 2: Skill Selection
Load `evm-audit-general` + `evm-audit-precision-math` (always), then add skills based on the routing table above. For a typical DeFi protocol, expect to load 6-8 skills.

### Phase 3: Spawn Parallel Sub-Agents
**Spawn one opus sub-agent per selected skill.** Do not run skills sequentially in the main session — parallel agents produce dramatically better results by keeping each agent's context focused.

Each agent receives:
- The full contract source
- Their one checklist (read from `references/checklist.md`)
- The standard finding format (below)
- Output path: `audits/<repo>-<date>/findings-<skill>.md`

Wait for all agents to complete, then proceed to Phase 4.

### Phase 4: Synthesis
Read all `findings-*.md` files. Deduplicate findings that multiple agents flagged. Check for cross-cutting concerns:
- [ ] Interactions between finding categories (e.g., oracle manipulation + liquidation)
- [ ] State machine consistency across all state transitions
- [ ] Economic attack vectors combining multiple findings
Write final `AUDIT-REPORT.md` with all findings ranked by severity.

### Phase 5: File Issues (if repo provided)
Run `gh issue create --repo <owner/repo>` for every finding **Medium severity and above**.
Skip Info and Low unless explicitly asked. Each issue title should be prefixed: `[Critical]`, `[High]`, or `[Medium]`.

---

## Standard Finding Format

Every sub-agent and the synthesis step MUST use this exact format. No deviations.

~~~
## [X-N] Title
**Severity**: Critical / High / Medium / Low / Info
**Category**: [skill name that caught this]
**Location**: `functionName()` or file:line
**Description**: What the issue is and why it matters. Be specific — name the variable, line, or pattern.
**Proof of Concept**: Exact steps to trigger or exploit. If not exploitable, explain the failure mode.
**Recommendation**: Concrete fix with code snippet where possible.
~~~

**Severity definitions** (use these, not your own judgment):
- **Critical**: Direct loss of funds by a third party, no preconditions
- **High**: Loss of funds requiring specific conditions, or permanent DoS
- **Medium**: Degraded behavior, trust model violation, incorrect accounting, or owner-only fund loss
- **Low**: Best practice violation, latent bug, or confusing behavior without direct fund risk
- **Info**: Informational, no security impact

## Source Attribution Key
- `[beirao]` — beirao.xyz audit checklist
- `[Dacian]` — dacian.me security articles (8 deep-dive articles covering liquidation, CLM, slippage, precision, signatures, governance, assembly, lending)
- `[Devdacian Primer]` — devdacian/ai-auditor-primers GitHub (base.primer.md — comprehensive 33KB primer)
- `[Decurity AMM/CDP/LSD]` — Decurity protocol-specific checklists
- `[weird-erc20]` — d-xo/weird-erc20 repository
- `[multichain-auditor]` — 0xJuancito multichain auditor
- `[SigmaPrime]` — Sigma Prime security blog (governance, oracles, liquid restaking articles)
- `[RareSkills]` — RareSkills security articles (smart contract security, UUPS proxy)
- `[Cyfrin]` — Cyfrin/Dacian Chainlink oracle security article
- `[ERC4626 checklist]` — ERC4626 security checklist
- `[ERC4626 primer]` — ERC4626 vulnerability primer (85+ patterns)
- `[ERC4337 checklist]` — Account abstraction security checklist
- `[Hacken UniV4]` — Hacken Uniswap V4 hooks audit guide
- `[LayerZeroV2 checklist]` — LayerZero V2 security checklist
- `[CCIP checklist]` — Chainlink CCIP best practices
- `[Wormhole checklist]` — Wormhole integration security
- `[Across checklist]` — Across Protocol integration guide
- `[Spearbit bridge]` — Spearbit bridge security checklist
- `[mixbytes CREATE2]` — MixBytes CREATE2 security analysis
- `[SWC-XXX]` — Smart Contract Weakness Classification registry (superseded by EEA EthTrust)
- `[Arbitrum docs]` — Arbitrum official documentation
- `[Blast docs]` — Blast L2 documentation
