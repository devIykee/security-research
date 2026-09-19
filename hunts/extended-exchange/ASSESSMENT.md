# Extended Exchange - Hunt Assessment

**Date**: 2026-09-19  
**Researcher**: deviykee  
**Target**: https://app.extended.exchange/

---

## CRITICAL ISSUE: Tooling Incompatibility

### The Problem

**Extended Exchange is built on Starknet, NOT EVM.**

The loaded bug hunting skill (`iykes-evm-bughunt-skill`) is specifically designed for **EVM-compatible chains** and cannot be applied to Starknet-based protocols.

### Technical Mismatch

| Aspect | EVM (Skill Designed For) | Starknet (Extended Uses) |
|--------|-------------------------|--------------------------|
| **Smart Contract Language** | Solidity, Vyper | Cairo |
| **Tooling** | Foundry (forge, cast) | Starkli, Scarb, Starknet.js |
| **Account Model** | EOA + Smart Contracts | Native Account Abstraction |
| **Verification** | eth_call, fork testing | Different proving system (zk-STARKs) |
| **Bytecode** | EVM bytecode | Cairo Sierra → CASM |
| **RPC Methods** | Standard eth_* methods | Starknet-specific RPC |

### What Extended Exchange Is

Based on research:
- **Product Type**: Perpetual DEX (perps)
- **Chain**: Starknet (zk-rollup)
- **Markets**: 100+ markets (crypto, equities, FX, commodities, indices)
- **Collateral**: USDC (with plans for wBTC, ETH, EURC, XVS)
- **Leverage**: Up to 100x
- **Team**: Built by ex-Revolut engineers
- **Architecture**: Currently on Starknet with custom app-chain layer in development
- **GitHub**: https://github.com/x10xchange
- **Docs**: https://docs.extended.exchange/

### Skill Step 1 Gate Result

Per the skill's Step 1 gate:
> "RPC/chain don't resolve, or no docs/verifiable contract exist → **STOP. Likely vaporware/scam.** Report that to the user; do not sink hours."

**Verdict**: Extended is **NOT** vaporware/scam — it's a legitimate project. However, the RPC/tooling incompatibility means we **CANNOT execute the EVM-focused playbook**.

---

## Options Moving Forward

### Option 1: Adapt for Starknet (HIGH EFFORT, NEW METHODOLOGY)

**Requirements**:
- Learn Cairo contract analysis
- Set up Starknet tooling (starkli, scarb)
- Understand Starknet-specific attack vectors:
  - Account abstraction vulnerabilities
  - Cairo-specific overflow/underflow patterns
  - Felt252 arithmetic issues
  - Storage patterns unique to Starknet
- Build Starknet PoC framework
- Access Extended's deployed contract addresses

**Resources Available**:
- [Awesome Starknet Security](https://github.com/amanusk/awesome-starknet-security)
- [Starknet Agentic Skills](https://github.com/keep-starknet-strange/starknet-agentic)
- [Code4rena Starknet Perpetual Audit](https://code4rena.com/reports/2025-03-starknet-perpetual)

**Estimated Effort**: Multiple days to weeks for methodology development

### Option 2: Request EVM Target (RECOMMENDED)

Ask the user to provide an **EVM-compatible protocol** instead, so the existing skill can be applied immediately.

### Option 3: High-Level Analysis Only (LIMITED VALUE)

Without Cairo contract auditing capability:
- Review documentation for logic flaws
- Check API security
- Business logic analysis
- No deep smart contract audit possible

---

## Recommendation

**STOP and consult with user.**

While Extended Exchange is a legitimate and interesting target, the current EVM-focused bug hunting skill cannot be effectively applied to a Starknet-based protocol. 

**Suggested next steps**:
1. Ask user if they want to hunt an EVM-based protocol instead
2. Or, invest time in developing Starknet-specific hunting methodology
3. Or, perform limited high-level analysis without smart contract deep dive

---

## Sources

- [Extended Exchange](https://extended.exchange)
- [Extended Documentation](https://docs.extended.exchange/)
- [Extended GitHub](https://github.com/x10xchange)
- [Extended Exchange Review](https://signals.coincodecap.com/extended-exchange-review)
- [Awesome Starknet Security Resources](https://github.com/amanusk/awesome-starknet-security)
- [Code4rena Starknet Perpetual Audit Report](https://code4rena.com/reports/2025-03-starknet-perpetual)

