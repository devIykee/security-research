# Coverage — Ellipse

Coverage: 0/TBD files (0%).

Last updated: intake

| File | Read? | Paths traced | Notes |
|------|-------|--------------|-------|

## Explicitly excluded

| Path / area | Reason |
|-------------|--------|
| lib/** or node_modules/** | vendored dependencies |
| test/** or **/*_test* | tests (exclude unless in scope) |

## Update: Initial Investigation Complete

Coverage: 0/4 contracts (0% source code access).

**Contracts identified but unverified:**
| Contract | Address | Size | Read? | Paths traced | Notes |
|----------|---------|------|-------|--------------|-------|
| Launchpad V6 | 0x66bdc...c16 | 39KB | bytecode only | admin roles verified | Unverified on explorers |
| Hook V6 | 0x143d7...a88 | 15KB | bytecode only | none | Unverified on explorers |
| Buyback Reserve | 0xea51e...e7a | 12KB | bytecode only | none | Unverified on explorers |
| Reward Vault | 0x29412...3ed | 12KB | bytecode only | none | Unverified on explorers |

**Documentation reviewed:**
- ellipse.fun/docs (launch mechanism, fees, architecture)
- ellipse.fun/docs?s=contracts (addresses)
- ellipse.fun/docs?s=integration (reading functions)
- ellipse.fun/docs?s=launch (technical flow)

**On-chain analysis performed:**
- ✅ RPC verification (Step 1)
- ✅ Contract discovery (Step 2)
- ✅ Auth triage (Step 4) - all admin functions guarded
- ✅ Role verification via RPC calls
- ✅ Pool structure analysis
- ✅ Bytecode function selector extraction

## Coverage Assessment

**0% source code coverage.** All findings are based on:
1. Documentation analysis
2. Known vulnerability patterns
3. Bytecode reverse engineering (limited)
4. Auth testing via RPC

This is NOT a complete audit. Cannot verify internal logic without source code.

**Blocker:** Source code required to:
- Verify pool initialization checks
- Analyze hook liquidity lock implementation
- Check fee distribution precision
- Confirm or rule out pool squat vulnerability

Last updated: 2026-09-19 (Step 4 complete, blocked on Step 5)
