# RobinPad (#8) - hunt notes (no deployable core / no High)

**Researcher:** deviykee  
**Date:** 2026-07-20  
**Status:** Docs + sites reviewed. **Published factory/locker/fee contracts have no bytecode on chain 4663.** Live `robinpad.meme` frontend did not expose a working RH factory address in harvested chunks. No High. No mainnet exploit attempted.

---

## What this means in plain language (read this first)

RobinPad markets itself as a Robinhood Chain meme launchpad (docs on robinpad.fi, app messaging on robinpad.meme, X @RobinPAD_MEME, public beta announced).

Their own documentation lists:

```
RobinPadFactory:  0x5C1C1dE6950F9DCfE31BE99D457Fa7732B2Ce93B
LPLocker:         0xf26b957a2fEde96137f773daD10139443AF66BEc
FeeRouter:        0xb0528AD7b14F28F729c66c90214484b8AFAf7BB0
```

On RPC `https://rpc.mainnet.chain.robinhood.com` (chain id 4663), **all three return empty code**. There is nothing to audit for a permissionless on-chain bug in those addresses. Nock Terminal's public launchpad registry made the same observation earlier.

Docs also **mislable** Uniswap infra (`0x8bceaa…` is the V2 factory on RH, not V3) and contradict themselves on graduation (one section: "$69k is UI only"; FAQ: "curve fills then migrates"). Treat documentation as untrusted until live code matches.

Without a real factory with code, this hunt **stops at the verification gate**. Claiming High would invent a surface that does not exist on-chain yet.

---

## INTAKE (known only)

```
PROJECT_NAME   : RobinPad
X_HANDLE       : @RobinPAD_MEME
WEBSITE        : https://www.robinpad.fi  (also https://robinpad.meme)
DOCS           : https://www.robinpad.fi/docs
CHAIN          : Robinhood Chain
RPC            : https://rpc.mainnet.chain.robinhood.com
CHAIN_ID       : 4663
EXPLORER       : https://robinhoodchain.blockscout.com
KNOWN_ADDRS    :
  docs_factory_empty=0x5C1C1dE6950F9DCfE31BE99D457Fa7732B2Ce93B
  docs_lplocker_empty=0xf26b957a2fEde96137f773daD10139443AF66BEc
  docs_feerouter_empty=0xb0528AD7b14F28F729c66c90214484b8AFAf7BB0
  weth=0x0Bd7D308f8E1639FAb988df18A8011f41EAcAD73
  univ2_factory=0x8bceaa40b9acdfaedf85adf4ff01f5ad6517937f
  univ3_factory=0x1f7d7550B1b028f7571E69A784071F0205FD2EfA
PRODUCT_TYPE   : launchpad (claimed; core undeployed as of hunt)
BOUNTY/CONTEST : none / discretionary
RESEARCHER     : deviykee
```

---

## Checks performed

| Check | Result |
|-------|--------|
| `cast code` on docs Factory / LPLocker / FeeRouter | empty (`0x`) |
| `cast code` on listed SwapRouter / WETH / Uni factories | present (shared infra) |
| robinpad.fi/docs narrative | Instant V3 single-sided + lock claims; internal contradictions |
| robinpad.meme JS harvest | Multi-chain payment/bridge token lists; **no RH factory address** in sampled chunks |
| Sourcify for docs factory | no match |

---

## Findings

| ID | Severity | Title |
|----|----------|--------|
| RP-1 | Info / Trust | First-party factory addresses have **no deployed bytecode** |
| RP-2 | Info | Docs confuse V2 vs V3 factory addresses and graduation semantics |
| RP-3 | - | Permissionless High on RobinPad custom contracts | **N/A until deploy** |

**No High / Critical.** Re-open when:

1. `eth_getCode` is non-empty at a first-party factory, and  
2. Source is verified or selectors map to a graduation/lock path worth forking.

If their intended design is the same class as NOXA / HoodFUN (instant V3 single-sided + locker), audit priorities once live:

- `createAndInitializePoolIfNecessary` + zero mins + no slot0 check  
- vs HoodTech-style `getPool == 0` abort  
- LP locker withdraw / owner escape  
- Fee router claim auth  

---

## Optional DM

Ask team which factory is live for public beta and to fix the empty-address docs. No exploit report until code exists.

---

deviykee
