# Slops / Robin the Hood (#6) - hunt notes (no High confirmed yet)

**Researcher:** deviykee  
**Date:** 2026-07-20  
**Status:** Core addresses and selectors mapped. **All custom contracts unverified** on Blockscout / Sourcify. Partial auth triage done. V4 migration surface interesting; **no permissionless High proven** without verified source or a full graduation fork PoC. No mainnet exploit attempted.

---

## What this means in plain language (read this first)

**Robin the Hood** rebranded to **Slops** (`robinthehood.fun` and `slops.lol` share the same product; X: @slopslol).

It is a real bonding-curve launchpad on Robinhood Chain:

- Creators pay a small launch fee and deploy a token  
- Trading happens on a per-token **bonding curve** until about **6 ETH** real reserve  
- Then a **MigrationManager** is supposed to move assets into a **Uniswap v4** pool with a custom **hook**  
- Creators and referrers claim fees from a **FeeDistributor**

Unlike Nock, this design **does** custody raise ETH on the curve until graduation. That is the right shape for High migration bugs.

However every custom contract is **unverified**, so we cannot quote the exact graduation code the way we did for Robinlaunch / Openfair. We mapped bytecode selectors, live storage, and auth via `eth_call` only. That is enough to **rule some attacks in/out** and leave a **strong residual lead**, but not enough to claim High theft with a clean PoC yet.

---

## INTAKE (known only)

```
PROJECT_NAME   : Slops (formerly Robin the Hood)
X_HANDLE       : @slopslol
WEBSITE        : https://www.slops.lol  (legacy https://robinthehood.fun still works)
DOCS           : https://docs.slops.lol
CHAIN          : Robinhood Chain
RPC            : https://rpc.mainnet.chain.robinhood.com
CHAIN_ID       : 4663
EXPLORER       : https://robinhoodchain.blockscout.com
KNOWN_ADDRS    :
  factory=0x248CAaAEff655d189d6d69689d83a5055730aA68
  fee_distributor=0x9911cF38e7011F6977CACcD5379C632a13238122
  migration_manager=0x2fc07C1c1290e8902cc3bDE0D9dc06F62301091C
  hook=0x4589a6e848F73D87496529062fC82669FD538040
  protocol_fee_receiver=0x41200bb2372FEf6899D64a72c0aA0a4c08E48B30
  owner=0x0759caA7DCE17c2f198AE68922ca1B9deD1F48D2
  referral_registry=0xbF3fF955Fbf3E4c84162A54D1540261371611610
  sample_token_JOHN=0x5297a267ff1430c7792788a28c6de2fe70a88baa
  sample_curve=0x8AAe4693A3098CC635C5Cb3F3e0E01634eE42956
  univ4_pool_manager=0x8366a39CC670B4001A1121B8F6A443A643e40951
PRODUCT_TYPE   : launchpad (bonding curve -> Uniswap v4)
BOUNTY/CONTEST : none / discretionary
NOTES          : GraphQL backend https://backend-production-930f5.up.railway.app/graphql ; only 1 indexed token at hunt time
RESEARCHER     : deviykee
```

---

## Architecture (live reads)

```
Creator
  |  launch (selector 0xbe7d29f4, value = launchFee 0.001 ETH)
  v
Factory 0x248CAA…
  |  creates Token + BondingCurve clone
  v
BondingCurve (per token)
  buy / sell until realEthReserve ~ GRADUATION_THRESHOLD (6 ETH)
  migrateAssets only callable by MigrationManager
  v
MigrationManager 0x2fc07C…   [migrate(address) is permissionless when curve is graduating]
  unlockCallback against PoolManager 0x8366a39C…
  hook 0x4589a6… (owner = MigrationManager)
  v
Uniswap v4 pool + fee split via FeeDistributor 0x9911cF…
```

### Live sample (Little John / JOHN)

| Field | Value |
|-------|--------|
| Token | `0x5297a267ff1430c7792788a28c6de2fe70a88baa` |
| Curve | `0x8AAe4693A3098CC635C5Cb3F3e0E01634eE42956` |
| Creator | owner `0x0759caA7…` |
| status | 0 (active bonding) |
| realEthReserve | ~8.7e13 wei (tiny) |
| GRADUATION_THRESHOLD | 6e18 (6 ETH) |
| VIRTUAL_ETH_RESERVE | 1.5e18 |
| VIRTUAL_TOKEN_RESERVE | 8.4e26 |
| TOKENS_FOR_CURVE | 8e26 |
| FEE_PERCENT | 1 |
| launchFee (factory) | 0.001 ETH (max 0.005) |

Frontend claims: creator gets 50% of graduation fee (docs text said 0.075 ETH) and 50% of trading fees forever after Uniswap; referrers earn volume share.

---

## Auth triage (attacker = dead address)

| Call | Result |
|------|--------|
| Factory `setMigrationManager` / `setPause` / `setLaunchFee` / `setProtocolFeeReceiver` | Ownable revert (`0x118cdaa7`) |
| FeeDistributor `setFactory` | Ownable revert |
| Curve `migrateAssets` from attacker | `"Only migration manager"` |
| MigrationManager `migrate(curve)` from attacker while not graduating | `"Curve not graduating"` (**not** onlyOwner) |
| FeeDistributor `claimProtocolFees` | `"No balance to claim"` (permissionless claim path if balance exists) |
| Hook `registerPool` from attacker | Ownable revert |

**Interpretation:** admin config is owner-gated. **Graduation `migrate(address)` is designed to be permissionless** once the curve is in graduating state (good for liveness; migration correctness is the security hinge).

---

## Migration surface (why this is still interesting)

### What bytecode shows

**MigrationManager selectors:**

- `migrate(address)`  
- `unlockCallback(bytes)`  
- `poolManager()` -> Uniswap v4 PoolManager  
- `hook()` -> `0x4589a6…`  
- `feeDistributor()`  
- `collectFees(address)`  
- strings: `"Curve not graduating"`, `"Insufficient ETH for migration f…"`, `"Insufficient assets"`, `"Treasury dust transfer failed"`

**No** embedded `createAndInitializePoolIfNecessary` (V3) or V2 `createPair` / `addLiquidityETH`.

**Hook selectors** include full V4 hook suite **in code**, including `beforeInitialize` with string **`"Only owner can initialize"`**.

### Critical nuance: hook address flags

Uniswap v4 only invokes a hook callback when the corresponding **bit is set in the hook address**.

Decoded flags for `0x4589a6e848F73D87496529062fC82669FD538040`:

| Flag | Enabled? |
|------|----------|
| BEFORE_INITIALIZE | **No** |
| AFTER_INITIALIZE | **No** |
| BEFORE/AFTER ADD/REMOVE LIQUIDITY | **No** |
| BEFORE_SWAP | **No** |
| **AFTER_SWAP** | **Yes** |
| DONATE / returns-delta bits | **No** |

So **`beforeInitialize` is dead for PoolManager purposes**. eth_call confirms a stranger can `PoolManager.initialize(PoolKey with this hook, arbitrary sqrtPrice)` successfully (returns tick without revert) for many fee/tickSpacing pairs.

Also: **MigrationManager bytecode does not contain selector `0x6276cbbe` (`initialize(PoolKey,uint160)`)** at all (string/byte scan). It does contain `unlock`, `take`, `registerPool`, `migrateAssets`, transfers. How the pool is first initialized during migration is **not fully reconstructed** without source or a decompile of `unlockCallback`.

### Residual leads (not claimed High)

1. **V4 pool squat / wrong-price liquidity** if migrate:
   - uses a fixed PoolKey (token, native, fee, tickSpacing, hook), and  
   - does **not** initialize itself (or try/catches init), and  
   - adds liquidity without checking current sqrt price  

   Then pre-init at a fake price is free gas-only setup (same economic class as Robinlaunch/Openfair V3). **Blocked from claim until we finish a fork PoC through a full 6 ETH graduation.**

2. **Permissionless migrate grief** if init fails when pool already exists and migrate does not handle it: graduation DoS per token (closer to Medium grief if true).

3. **FeeDistributor** creator/referrer/protocol claim paths: onlyOwner on config; claims look pull-style. No High from partial reads.

4. **Owner trust**: owner can `setMigrationManager`, pause, set launch fee, set protocol fee receiver. Centralization / rug surface (label as trust, not permissionless High).

---

## Findings (honest)

| ID | Severity | Title | Status |
|----|----------|--------|--------|
| SL-1 | Info | Core factory / curve / migrator / hook / fee contracts **unverified** | Confirmed |
| SL-2 | Info | Architecture is bonding curve -> permissionless `migrate` -> Uniswap v4 + AFTER_SWAP hook | Confirmed via selectors + eth_call |
| SL-3 | Info / Lead | Hook ships `beforeInitialize` + "Only owner can initialize" but address flags **do not enable BEFORE_INITIALIZE**; attacker can init pools with this hook | Confirmed eth_call; **impact depends on migrate price handling** |
| SL-4 | Trust | Owner controls migration manager, pause, fee receiver | By design |
| SL-5 | - | Proven permissionless theft of curve raise | **Not proven** (source missing + no full graduation PoC) |

**No High / Critical claimed in this report.** Prefer re-open when:

1. Team verifies source (Sourcify / Blockscout), or  
2. We finish a local/fork PoC that forces a curve to graduating state, pre-inits the exact PoolKey, runs `migrate`, and shows attacker-extractable value with a stated bound.

---

## Comparison to known High classes

| Known High | Ports to Slops? |
|------------|-----------------|
| V3 createAndInitializePoolIfNecessary + amountMin=0 | **No V3 path** in bytecode |
| V2 pair pollution + readyToGraduate freeze | **No V2 path** |
| V4 pre-init wrong price + migrate adds liq blindly | **Possible lead (SL-3)**; not proven |

---

## GraphQL / product notes

- Backend: `https://backend-production-930f5.up.railway.app/graphql`  
- At hunt time only one token row: JOHN / Little John (creator = protocol owner).  
- UI copy: bonding curve, graduation to Uniswap, creator 50% fee share, referrer program.

---

## Sources on disk

- `reports/Slops-hunt-notes.md` (this file)  
- Frontend chunk harvest under `/tmp/rth/chunks` (session)  
- Live addresses listed in INTAKE (do not invent others)

---

## Next steps (priority)

1. Ask team for verified source of Factory, BondingCurve, MigrationManager, Hook, FeeDistributor.  
2. Decompile `unlockCallback` to recover exact PoolKey (fee, tickSpacing, currency order) and whether price is checked.  
3. Fork PoC: `vm.store` curve reserves/status to graduating, pre-init pool at skewed sqrtPrice, `migrate`, measure ETH extractable via swap.  
4. If PoC nets clear steal with stated bound, promote to **High** report + `reports/dm-slops.md`.

---

deviykee
