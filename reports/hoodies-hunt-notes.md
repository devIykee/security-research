# HOODIES Marketplace (#36) - hunt notes (incomplete surface)

**Researcher:** deviykee  
**Date:** 2026-07-20  
**Status:** Target added from user paste. Website **https://robinhoodnfts.com** resolves in DNS (`93.188.163.111`) but **HTTP(S) timed out** from this environment (direct IP + Host header also failed). No published custom marketplace factory address found on Blockscout under HOODIES / robinhoodnfts name search. **No permissionless High claimed.** No mainnet exploit attempted.

---

## What this means in plain language (read this first)

HOODIES markets itself as an early Robinhood Chain **NFT marketplace** (0% fee, immutable contract, verified drops, live trading). That is a different product class from bonding-curve launchpads: custody risk is usually **listings / escrow / settlement**, not graduation pool squat.

This pass could not:

1. Load the frontend (site unreachable here) to harvest factory addresses from JS  
2. Find a named "HOODIES" marketplace contract on Blockscout  
3. Verify the "0% fee immutable" claim on a concrete address  

So this is a **surface map + reopen checklist**, not a full audit.

---

## INTAKE

```
PROJECT_NAME   : HOODIES Marketplace
WEBSITE        : https://robinhoodnfts.com
CHAIN          : Robinhood Chain
RPC            : https://rpc.mainnet.chain.robinhood.com
CHAIN_ID       : 4663
EXPLORER       : https://robinhoodchain.blockscout.com
PRODUCT_TYPE   : NFT marketplace
BOUNTY/CONTEST : none / discretionary
NOTES          : Claims 0% fee immutable contract, verified drops, live trading. Site DNS up, HTTP timeout 2026-07-20 from hunt host.
RESEARCHER     : deviykee
```

---

## Related on-chain (RH 4663) — not confirmed as HOODIES

| Address | Name | Notes |
|---------|------|--------|
| `0x0000000000000068F116a894984e2DB1123eB395` | **Seaport** (verified) | Canonical Seaport-style deployment present on RH; may be used by marketplaces, **not** proven as HOODIES-owned |
| `0x000000000000Ad05Ccc4F10045630fb830B95127` | metadata tag only | Seaport-adjacent vanity |
| `0x00000000000000ADc04C56Bf30aC9d3c0aAF14dC` | metadata tag only | Seaport-adjacent vanity |

Blockscout name search for HOODIES / Hoodies / robinhoodnfts returned **meme tokens**, not a marketplace core.

**Do not invent** a HOODIES marketplace address until it appears in:

- site JS / network `eth_call` `to`  
- docs  
- verified Blockscout contract name  
- team-published announcement with checksummed address  

---

## Dedupe vs #35 / #12

| Paste row | Canonical |
|-----------|-----------|
| #35 RobinLaunchpad (NFT marketplace + token launch) | **#12 RobinLaunchpad** — already **HUNTED-NOTES** (`reports/RobinLaunchpad-hunt-notes.md`) |
| #36 HOODIES Marketplace | This file — new NFT marketplace target |

RobinLaunchpad already includes marketplace + inscription + pump paths; do not re-hunt as a separate High campaign unless they ship a **new** factory version.

---

## Attack questions (for reopen when site/addrs live)

1. **Custody:** Does listing transfer NFT to escrow, or approval-based Seaport?  
2. **Fee:** Is protocol fee hard-coded 0, or owner-settable? Immutable claim vs Ownable.  
3. **Settlement:** ETH/WETH push to seller; reentrancy / non-receiver DoS.  
4. **Cancel / expire:** Can listing be griefed or stuck in escrow?  
5. **Upgrade:** Proxy vs non-upgradeable bytecode for "immutable" claim.  
6. **Drops:** Separate minter; free-mint DoS / signature mint bugs.

These need source or at least verified bytecode + live listing flow.

---

## Severity summary

| Item | Severity |
|------|----------|
| Launchpad V3 pool squat class | **N/A** (marketplace product) |
| HOODIES-specific fund bug | **Not proven** (no contract located) |
| Site / address opacity | Operational blocker |

**Campaign status: HUNTED-NOTES** (incomplete; reopen when frontend loads or team publishes addresses).

---

## Reopen checklist

```bash
# when site is reachable
curl -sL https://robinhoodnfts.com -o hoodies.html
# harvest /assets/*.js for 0x addresses
# then:
cast code 0x... --rpc-url https://rpc.mainnet.chain.robinhood.com | wc -c
# Blockscout smart-contracts + Sourcify
```

deviykee
