# Leavehood (#24) - hunt notes (no High proven)

**Researcher:** deviykee  
**Date:** 2026-07-20  
**Status:** Site + docs live. Factory and core are **UUPS ERC1967 proxies**; implementations **unverified**. LP lock contract **verified**. Partial surface map only. **No permissionless High claimed.** No mainnet exploit attempted.

---

## What this means in plain language (read this first)

Leavehood markets memecoin launch + trade on Robinhood Chain with long LP locks (docs claim multi-year / up to 100y). On-chain:

- **Factory proxy** and **core proxy** are upgradeable (UUPS). Owner can ship new logic.  
- The **lock** contract is a general time-lock for V3 NFTs or ERC20s: after `unlockTime`, the lock owner can **withdraw** the NFT/tokens. It is **not** a no-exit permanent burn locker like MetaLaunch/Primehod V3 lockers.  
- Factory/core implementations are not verified, so V3 pool-squat / curve-migrate classes cannot be proven end-to-end.

Without verified launchpad logic, severity stays notes-only. Upgradeability is the main standing trust risk.

---

## INTAKE

```
PROJECT_NAME   : Leavehood
WEBSITE        : https://leavehood.com
DOCS           : https://leavehood.com/docs
CHAIN          : Robinhood Chain
RPC            : https://rpc.mainnet.chain.robinhood.com
CHAIN_ID       : 4663
EXPLORER       : https://robinhoodchain.blockscout.com
KNOWN_ADDRS    :
  factory_proxy=0x2C81Cd8acF4886F4abAd332216b4444aE927FDb7
  factory_impl=0xc7c85df578397d7982dcd36b347deea48dbf1050
  core_proxy=0x5090C9cd2228b0C4e6a83Ee44ab77Ce2e4cd89E3
  core_impl=0x7ddf651feb2632d686619ff35b4cc81105924aee
  lock=0x8F1C12050BB6aAA89f8fB5ddcA77c3EdF022CBF4
  owner_via_proxy=0xf64636c338f91ccaab2d9091d42bd383fa79aab3
  npm=0x73991a25C818Bf1f1128dEAaB1492D45638DE0D3
  weth=0x0Bd7D308f8E1639FAb988df18A8011f41EAcAD73
  univ3_factory=0x1f7d7550B1b028f7571E69A784071F0205FD2EfA
PRODUCT_TYPE   : launchpad (UUPS) + LP time-lock
BOUNTY/CONTEST : none / discretionary
NOTES          : Multiple other ERC1967 proxies appear on site (0x01cb…, 0x3a11…, 0xD956…, 0xf92D…, 0x5fc5…)
RESEARCHER     : deviykee
```

---

## Architecture (what is proven)

### Proxies (EIP-1967)

| Role | Proxy | Implementation (storage slot) | Verified |
|------|-------|-------------------------------|----------|
| Factory | `0x2C81Cd8a…FDb7` | `0xc7c85df5…1050` (~16KB) | proxy yes / impl **no** |
| Core | `0x5090C9cd…89E3` | `0x7ddf651f…4aee` (~21KB) | proxy yes / impl **no** |
| Lock | `0x8F1C1205…CBF4` | n/a (not proxy) | **yes** LeavehoodLockLP |

Both proxies report `UPGRADE_INTERFACE_VERSION = "5.0.0"` and `owner() = 0xf64636c3…aab3`.

### LeavehoodLockLP (verified)

```solidity
// unlock after duration (max 100 years); then owner can withdraw NFT or ERC20
function withdraw(uint256 lockId) external nonReentrant {
    ...
    if (block.timestamp < l.unlockTime) revert StillLocked();
    l.withdrawn = true;
    // transfer NFT or ERC20 back to lock owner
}
```

- `collectFees` on V3 NFT locks does not move principal (good while locked).  
- After unlock, full principal is reclaimable by lock owner — marketing "permanent" is **duration-dependent**, not code-permanent.  
- Owner can set `lockFee` / `feeExempt` (launchpad often fee-exempt).

### Factory/core bytecode fingerprints (impl)

| Pattern | Factory impl | Core impl |
|---------|--------------|-----------|
| `createAndInitializePoolIfNecessary` | **0** | **0** |
| V3 `createPool` | **0** | **0** |
| V3 pool `initialize` | **0** | **0** |
| NPM mint selector | **0** | **0** |
| `slot0` | 0 | 2 |
| `upgradeToAndCall` | 1 | 1 |

So this is **not** the classic Uniswap NPM createAndInitialize launchpad fingerprint. Core references `slot0` (likely reads pool price). Full selector map / source needed for deeper audit.

---

## Findings

### 1. Classic V3 raise squat — not proven

No `createAndInitialize` / createPool in factory impl bytecode. Cannot claim Robinlaunch-class High without verified launch path.

### 2. UUPS upgrade risk — trust / centralization

Owner can replace factory and core logic. Any future malicious upgrade can steal or freeze depending on new code. Label **trust**, not permissionless exploit of current bytecode.

### 3. Lock is time-locked, not forever

Honest marketing note: `MAX_DURATION = 100 years`, but `withdraw` after unlock returns the LP NFT. Not a bug if duration is disclosed; mismatch if UI says "never unlockable."

### 4. Lock transferability

`transferLockOwnership` moves the claim on the locked asset. Fine if intentional.

### 5. Residual

Multiple extra proxies on the frontend address list not fully mapped. Re-open when implementations are verified on Blockscout/Sourcify.

---

## Severity summary

| Item | Severity |
|------|----------|
| V3 pool squat / raise dump | **Not proven** (impl unverified; no createAndInitialize fingerprint) |
| UUPS owner upgrade | **Trust / centralization** |
| Lock unlock + withdraw | Design (time-lock); document vs "permanent" claim |
| Permissionless High | **None claimed** |

**Campaign status: HUNTED-NOTES** (map + lock audit; re-open on verified factory/core).

deviykee
