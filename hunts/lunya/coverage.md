# Coverage — Lunya

Coverage: 4/Y files (ABI-only, no source).

Last updated: Step 4 analysis

| File | Read? | Paths traced | Notes |
|------|-------|--------------|-------|
| LunyaLaunchFactory.json | yes | ABI only - createLaunch, openPool, admin functions | No source code available |
| LunyaLaunchCP.json | yes | ABI only - buy/sell, graduation event structure | No source code available |
| LunyaLiquidityLocker.json | yes | ABI only - lock, collectFees | No source code available |
| LunyaPublicLister.json | yes | ABI only - listPool with CurveNotOpen error | No source code available |

## Explicitly excluded

| Path / area | Reason |
|-------------|--------|
| DEX contracts | Out of scope - focusing on launchpad |
| lib/** or node_modules/** | vendored |
| test/** or **/*_test* | tests |

## Notes
**Source code unavailable**: Contracts are not verified on Sourcify or block explorer. Only ABIs available from github.com/lunyaio/lunya-abi. Analysis limited to:
- Function signatures and events
- Error definitions
- Documentation at docs.lunya.io
- On-chain state queries (limited by slow RPC)

**Cannot perform**: Deep code review of graduation logic, CEI analysis, full access control audit without source code.
