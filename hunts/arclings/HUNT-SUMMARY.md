# Arclings Bug Hunt - Session Summary

**Date:** 2026-09-16  
**Researcher:** deviykee  
**Target:** Arclings NFT on Arc Testnet  
**Status:** Initial reconnaissance complete, RPC connectivity issues blocking deeper analysis

---

## What I Found

### ✅ Successfully Identified

1. **Target Contract Located**
   - Address: `0xEb03AC9cE0DCCbb95c0ecF17C957D979233D97Fd`
   - Chain: Arc Testnet (Chain ID: 5042002)
   - Type: ERC-721 NFT
   - Current Supply: 20 tokens (testnet deployment)
   - Code Size: ~14KB bytecode

2. **Project Details**
   - Name: ARCLINGS
   - Symbol: Likely "ARCLINGS" or similar
   - Total Supply Cap: 6,283 (matching tau/2π)
   - Website: https://arclings.art/
   - X/Twitter: @ArclingsNFT
   - Discord: discord.gg/w7QCGz6jge

3. **Key Features Identified**
   - **100% On-chain Storage:** Art, metadata, and generation logic live in contracts
   - **1-bit Pixel Art:** 40×40 monochrome bitmaps (1,600 pixels each)
   - **Dynamic SVG Generation:** On-chain rendering with row-scan RLE compression
   - **Radian Union Engine (Phase 3):** Planned merge/burn mechanism
     - Burn two "open arc" NFTs to create "closed circle" pieces
     - Deflationary mechanics
     - Requires combined radians ≥ 6.283

4. **Technical Architecture**
   - MSB-first binary encoding for pixel data
   - Programmatic trait generation from token ID
   - Traits: form, paper/style, body fill, eyes, mouth, headwear, legs, held items
   - Token #6283 designated as the "closing circle" grail
   - CC0 license (public domain)

5. **Verification Status**
   - **UNVERIFIED** on Arc Testnet Explorer
   - Only bytecode available (~14.6KB)
   - No source code on Sourcify or explorer
   - Analyzed deployment bytecode shows Solidity 0.8.24 compilation

---

## Critical Areas to Investigate (When RPC Access Restored)

### 🔴 HIGH PRIORITY

1. **Merge/Burn Logic (Radian Union Engine)**
   - Validation of "radian" calculation
   - Burn authorization checks
   - Supply tracking integrity
   - Permanent vs temporary burn verification
   - Reentrancy in merge flow

2. **Minting Access Control**
   - Who can mint? (Owner-only, whitelist, public phases)
   - Phase transitions (from contract: enum with 3 states detected)
   - Whitelist validation (Merkle proof detected in bytecode)
   - Per-address mint limits enforcement
   - Mint price validation

3. **On-Chain SVG Generation**
   - Input validation for token IDs
   - Gas exhaustion attacks on complex renders
   - Trait assignment manipulation
   - Rarity calculation integrity

4. **Ownership & Admin Functions**
   - Access control on privileged functions
   - Withdrawal mechanisms
   - Emergency pause functionality
   - Metadata/renderer contract updates

### 🟡 MEDIUM PRIORITY

5. **ERC-721 Standard Compliance**
   - Safe transfer checks
   - Approval mechanisms
   - Transfer restrictions
   - Burn function access

6. **Economic Model**
   - Mint pricing mechanism
   - Fee distribution
   - Refund logic (if any)
   - ETH/USDC handling (Arc uses USDC as gas token!)

7. **Storage Efficiency**
   - On-chain storage costs
   - Bitmap compression
   - Gas optimization

---

## Blockers & Next Steps

### Current Blockers

1. **Arc Testnet RPC Unreliable**
   - Timeouts on `cast call` commands
   - Cannot query contract state
   - Cannot test function calls
   - RPC: https://rpc.testnet.arc.io

2. **No Source Code**
   - Contract unverified on explorer
   - Bytecode-only analysis required
   - Need to decompile or wait for verification

### Recommended Next Steps

1. **Wait for RPC Stability**
   - Monitor Arc Testnet status
   - Try alternative RPC endpoints if available
   - Consider Arc mainnet launch (Sept 16, 2026 scheduled)

2. **Bytecode Analysis**
   - Decompile with Dedaub or Heimdall
   - Extract function selectors systematically
   - Map storage layout
   - Identify privileged functions

3. **Request Source Code**
   - Contact team via security@arclings.art
   - Request verification on explorer
   - Explain responsible disclosure intent

4. **Mainnet Monitoring**
   - Track mainnet deployment (if not yet live)
   - Compare testnet vs mainnet addresses
   - Monitor initial mints for patterns

5. **Deep Dive When Accessible**
   - Run auth triage (Step 4 from skill)
   - Fork-test mint flows
   - Analyze merge/burn mechanics
   - Test access control boundaries

---

## Tools & Resources Used

- **Arc Testnet RPC:** https://rpc.testnet.arc.io (Chain ID: 5042002)
- **Arc Explorer:** https://explorer.testnet.arc.io
- **Arc Docs:** https://docs.arc.io
- **Foundry (cast):** For contract interaction
- **Blockscout API:** For contract metadata

---

## References

- Main site: https://arclings.art/
- X: https://x.com/ArclingsNFT
- Arc Network overview: [Chain ID, RPC & First Steps](https://trustswap.com/arc/mainnet-live)
- KuCoin coverage: [Arclings on Arc](https://www.kucoin.com/news/community/ARC/6a9e4678cc8a20000790f706)

---

## Risk Assessment (Preliminary)

**Overall Risk:** TBD (blocked by RPC access)

**Identified Concerns:**
1. Unverified contract = reduced transparency
2. Complex merge mechanics = potential for logic bugs
3. On-chain generation = gas/DoS vectors
4. Testnet-only analysis = production behavior unknown

**Positive Signals:**
1. Established team with public presence
2. Innovative on-chain approach
3. Phase 3 not yet deployed (merge engine)
4. CC0 license = open collaboration

---

## Next Session Prompt

```
Continue Arclings bug hunt. Contract: 0xEb03AC9cE0DCCbb95c0ecF17C957D979233D97Fd on Arc Testnet (5042002).

Priority:
1. Test RPC connectivity
2. If RPC works: run auth triage (cast call admin functions from 0xdead)
3. Decompile bytecode to extract function list
4. Focus on mint, merge/burn, and admin functions
5. Check for missing access control, reentrancy, supply manipulation

Already completed: ground truth, contract location, intake file.
```

---

**Status:** Reconnaissance complete. Awaiting RPC stability for active testing.
