# Long Supply Security Hunt - Initial Assessment

**Date**: 2026-09-16  
**Researcher**: deviykee  
**Target**: https://long.supply/  
**Status**: HIGH RISK - Custodial bridge with rug pull concerns

---

## Executive Summary

Long.supply is a **custodial bridge and launchpad** launched on Arc mainnet (Sept 16, 2026) that claims to bridge stock tokens from Robinhood Chain to Arc with 1:1 backing. The protocol has raised significant red flags in the crypto community regarding potential rug pull risks.

**Critical Risk Factors**:
1. **Custodial, not trustless** - Team controls all minting/redemption wallets
2. **Platform-issued tokens** - Stock tokens are NOT officially issued; created by the platform
3. **Custom unaudited bridge** - Built proprietary cross-chain bridge
4. **No source code** - No public GitHub repository or verified contracts found
5. **Community warnings** - Multiple KOLs flagged "can rug at any time" concerns
6. **Day 1 launch** - Went live same day as Arc mainnet (Sept 16, 2026)

---

## Intelligence Gathered

### Network Details
- **Chain**: Arc (Circle L1)
- **Chain ID**: 5042
- **RPC**: https://rpc.mainnet.arc.io (verified live, block 21170155)
- **Explorer**: https://explorer.arc.io (Cloudflare protected)

### Discovered Contracts
1. **Vault**: `0x3943a8a80c85602f255fb8ebde7f213ea2873d8a`
   - Found via: Bundle grep from long.supply frontend
   - Status: Contract confirmed (from assayhq holder analysis)
   
2. **LONG Token**: `0x2164bb17a2d38c1b5170e987b2c0416df1efc752`
   - Type: Meme token on Arc
   - Listing: MEXC (Sept 16, 2026)
   - Trading: ~$0.011, 270%+ gain on launch, $2.5M volume

### Architecture Overview
```
Robinhood Chain (stock tokens) 
    ↓
Custom Bridge (team-controlled)
    ↓
Arc Chain (platform-issued tokens)
    ↓
Vault: 0x3943...d8a (custody contract)
```

### Product Functions
1. **Bridge**: Transfer stock tokens Robinhood Chain → Arc (custodial)
2. **Launch**: Token launchpad paired with stock tokens
3. **Custody**: Team-operated wallets hold backing assets
4. **Fee Model**: Protocol fees in both directions (rate undisclosed)

---

## Red Flags & Community Concerns

### From Public Sources
**KOL Warnings** (per KuCoin news):
> "Longdotsupply is a platform that can rug at any time and mint fake USDT. The platform has built its own cross-chain bridge connecting Robinhood and the Arc chain; the stock tokens on Arc are not officially issued but rather issued by the platform itself."

**Platform Admissions**:
- Explicitly states: "NOT trustless or decentralized"
- Uses "team-operated wallets" for minting and redemptions
- Independent from Robinhood, Arc, Circle, and stock issuers
- Claims 1:1 backing but no on-chain proof mechanism mentioned

### Technical Gaps
- ❌ No public source code repository
- ❌ No contract verification on explorer
- ❌ No security audit disclosed
- ❌ No bug bounty program
- ❌ Cloudflare blocking automated explorer API access
- ❌ RPC connection issues during testing

---

## Attack Surface Analysis

### PRODUCT_TYPE: Custodial Bridge + Launchpad

**Primary Threats** (by severity potential):

#### 1. **Custodial Rug Pull** (TRUST/CENTRALIZATION - Critical Impact)
- Team controls minting → can mint unlimited fake tokens
- Team controls redemption wallet → can drain backing assets
- No timelock, multisig, or decentralized governance visible
- **This is the design**, not a bug, but catastrophic if team is malicious

#### 2. **Cross-Chain Bridge Vulnerabilities** (Potential CRITICAL)
Without source code, cannot assess:
- Signature verification on bridge messages
- Replay attack protection
- Authorization on mint/burn operations
- Asset accounting (does burned amount on Robinhood match minted on Arc?)
- Oracle manipulation for stock prices

#### 3. **Vault Contract Risks** (Unknown - Need Code)
`0x3943a8a80c85602f255fb8ebde7f213ea2873d8a` functions unknown:
- Who can withdraw from vault?
- Is there any time delay or governance?
- Can users verify 1:1 backing on-chain?
- Emergency pause/freeze mechanisms?

#### 4. **Token Launch Vulnerabilities** (Product Dependency)
Launchpad mechanics unknown:
- Fair launch vs controlled distribution?
- LP lock mechanics?
- Anti-snipe measures?
- Graduation criteria for tokens?

---

## Hunt Status & Blockers

### Completed Steps
- ✅ **Step 1**: Ground truth verified (Arc mainnet live, RPC functional)
- ✅ **Step 2**: Partial contract discovery (vault + LONG token)
- ⚠️ **Step 3**: Blocked - No contract verification, explorer API protected

### Blockers Encountered
1. **No Source Code**: GitHub searches returned no official repository
2. **Unverified Contracts**: Explorer shows no verified source for vault
3. **Cloudflare Protection**: API calls to explorer blocked by CF challenge
4. **RPC Issues**: Connection refused errors during cast operations
5. **Closed System**: No public documentation of contract addresses/ABIs

### Required to Continue Hunt
- [ ] Verified contract source code or bytecode analysis
- [ ] Working RPC endpoint for on-chain calls
- [ ] Contract ABI for vault and bridge contracts
- [ ] Mechanism to bypass Cloudflare on explorer
- [ ] Additional contract addresses (bridge, minter, controller)

---

## Preliminary Assessment

**SEVERITY: Unable to Determine (Insufficient Access)**

This hunt is **blocked by lack of source code access and contract verification**. The protocol presents:

1. **Extreme Trust Requirements**: By design, requires trusting team with all funds
2. **Unverifiable Claims**: Cannot audit 1:1 backing without code/verification
3. **High Exit Scam Risk**: Custodial model + no code + day-1 launch = classic rug setup
4. **Community Red Flags**: Multiple warnings already circulating

### Recommended Action

**For Users**: 
- 🚨 **Avoid** until contracts are verified and audited
- Current design is custodial by admission - not a "decentralized protocol"
- Community concerns about rug pull risk are **valid given the architecture**

**For Continued Hunt**:
- **Option A**: Wait for contract verification on explorer
- **Option B**: Perform bytecode reverse engineering (advanced, time-intensive)
- **Option C**: Use browser dev tools to capture ABIs from frontend calls
- **Option D**: Contact team requesting source code for security review

---

## References

**Sources Analyzed**:
- [MEXC: LONG Token Info](https://www.mexc.com/news/1206568)
- [KuCoin: Rug Pull Concerns](https://www.kucoin.com/news/flash/kol-bonk-guy-promotes-arc-chain-launchpad-platform-faces-rug-pull-concerns)
- [TrustSwap: Arc Mainnet Info](https://trustswap.com/arc/mainnet-live)
- [CompareNodes: Arc RPC Providers](https://www.comparenodes.com/protocols/arc/)
- [Chainbase BuilderMaps: Long Project Data](https://github.com/chainbase-labs/buildermaps.io)
- [AssayHQ: Robinhood Chain Analysis](https://github.com/wraithioner/assayhq)

**Next Session Prompt**: If contracts become verified or source code is released, resume with Step 3 (surface map) focusing on:
- Bridge authorization mechanisms
- Vault withdrawal controls  
- Asset accounting verification
- Minting permission model
- Emergency pause capabilities

---

**Researcher Note**: This is a day-1 launch with custodial architecture and community-flagged rug concerns. The lack of source code makes traditional smart contract auditing impossible. Any "bug bounty" would be discretionary and trust-based given the team's complete control over the system.
