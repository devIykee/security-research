# Arclings Bug Hunt - INTAKE

## Project Information

```
PROJECT_NAME   : Arclings
X_HANDLE       : @ArclingsNFT
WEBSITE        : https://arclings.art/
DOCS           : (not found yet)
SECURITY_EMAIL : contact@arclings.art
DISCLOSURE     : discretionary
CHAIN          : Arc Testnet (mainnet scheduled Sep 16, 2026)
RPC            : https://rpc.testnet.arc.io
CHAIN_ID       : 5042002
EXPLORER       : https://explorer.testnet.arc.io
KNOWN_ADDRS    : core=0xEb03AC9cE0DCCbb95c0ecF17C957D979233D97Fd
PRODUCT_TYPE   : NFT collection (ERC-721)
BOUNTY/CONTEST : none / discretionary
NOTES          : 6,283 fully on-chain 1-bit pixel art avatars. Phase 3 includes "Radian Union Engine" - merge mechanism allowing holders to burn two open Arclings to create Closed-Circle pieces (deflationary). All art/metadata stored in contracts (no IPFS). USDC is native gas token (18 decimals on Arc, not 6).
RESEARCHER     : deviykee
```

## Status

- [x] Ground truth verified (RPC alive, chain ID confirmed: 5042002)
- [x] Core contract address located: 0xEb03AC9cE0DCCbb95c0ecF17C957D979233D97Fd
- [x] Source verification status: UNVERIFIED (bytecode only, ~14KB)
- [x] Function signatures extracted (60+ functions via 4byte.directory)
- [x] Attack surface mapped (8 high-priority vectors identified)
- [ ] Auth triage (blocked by RPC timeouts)
- [x] Coverage tracking initialized

## Key Risks to Investigate

Based on product type (NFT with merge/burn mechanics):
1. **Merge/burn logic** - Radian Union Engine mechanics (Phase 3)
2. **Access control** - Minting, merging, admin functions
3. **On-chain storage** - SVG rendering, trait generation
4. **Deflationary mechanics** - Burn validation, supply tracking
5. **Rarity manipulation** - Trait assignment, closed-circle creation

## Sources

- Main site: https://arclings.art/
- X: https://x.com/ArclingsNFT
- Discord: https://discord.gg/w7QCGz6jge
- Arc docs: https://docs.arc.io/
- Arc explorer: https://explorer.testnet.arc.io
