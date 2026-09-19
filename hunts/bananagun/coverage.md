# Coverage — Banana Gun

Coverage: 1/Y files (unknown %).

Last updated: Step 4 complete (2026-09-16)

| File | Read? | Paths traced | Notes |
|------|-------|--------------|-------|
| TransparentUpgradeableProxy.sol (proxy) | yes | delegatecall flow, admin checks | OpenZeppelin standard implementation |
| Implementation (0x35fc...b34e) | no | — | **UNVERIFIED SOURCE** - only bytecode analysis |

## Explicitly excluded

| Path / area | Reason |
|-------------|--------|
| lib/** | vendored OpenZeppelin dependencies (standard, audited) |
| test/** | test fixtures (unless hunting test-only bugs) |
| Other chain deployments | Focus on Ethereum mainnet first |

## Notes
- **BLOCKER:** Implementation contract source code is not verified on Sourcify or Etherscan
- Only behavioral analysis and bytecode selector mapping possible
- Proxy contract (0x3328...9c49) uses standard OpenZeppelin TransparentUpgradeableProxy
- Implementation (0x35fc...b34e) balance: ~0.00025 ETH (low funds at risk)
- Admin (0x6e38...c5af) - not yet analyzed
- Multi-chain deployment requires separate analysis per chain

## Assessment Status
**Gate Decision: Reconsidering target value**
- Unverified source limits deep analysis
- Low on-chain balance suggests non-custodial/routing contract
- Standard access controls appear properly implemented
- Would need bytecode decompilation or verified source to continue effectively
