# Long Supply Bug Hunt Notes

## Status: Initial Reconnaissance

### INTAKE Summary
- **Project**: long.supply
- **Chain**: Arc (Circle L1) - Chain ID 5042
- **RPC**: https://rpc.mainnet.arc.io (verified live, block 21170155)
- **Product**: Custodial bridge + launchpad for stock tokens (Robinhood Chain → Arc)
- **Launch**: Sept 16, 2026 (Arc mainnet launch day)

### Key Risk Indicators
1. **Custodial, not trustless** - Team-operated wallets control minting/redemptions
2. **Platform-issued tokens** - Stock tokens on Arc are NOT officially issued
3. **Custom bridge** - Built their own cross-chain bridge
4. **Community concerns** - KOLs raised "can rug at any time" warnings
5. **No official audit/bounty program** - Discretionary disclosure

### Discovered Contracts
- **vault**: `0x3943a8a80c85602f255fb8ebde7f213ea2873d8a` (from bundle grep)
- **LONG token**: `0x2164bb17a2d38c1b5170e987b2c0416df1efc752` (meme token)

### Technical Blockers Encountered
- RPC connection issues (connection refused)
- Cloudflare protection on explorer.arc.io API
- Need alternative approach for contract discovery

### Next Steps
1. Use browser-based approach to find more contract addresses
2. Try alternative RPC endpoints or explorers
3. Check if there's a public docs site with contract addresses
4. Manual inspection of the app's network requests
