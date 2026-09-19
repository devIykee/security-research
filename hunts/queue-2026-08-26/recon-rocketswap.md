# RECON — RocketSwap (Anubis chain) · 2026-08-26

## DefiLlama
- Slug `rocketswap-anubis` (id 8114). Live TVL **$187.79M** (`currentChainTvls.Anubis`), chain key `anubi`, tags AMM, **audits: 0**.
- Methodology: sums reserves of all pairs from UniV2-style factory via shared registry `registries/uniswapV2.js` (no dedicated adapter dir).
- Note: unrelated dead `rocketswap` slug = Lamden DEX ($0). Twitter @Rocket_Swap_, no github listed. Listed URL also appears as `swap.deepsea.monster/swap` (DefiLlama PR #19716) while site is rocketswap.org.

## Anubis chain
- **Chain ID 6714**, RPC `https://rpc.anubispace.org` ✅ works (geth v1.0.1, head ~12.2M, 1s blocks). Explorer: **https://browser.anubispace.org** (Blockscout, api/v2 OK). Site anubischain.ai, docs anubis-network.gitbook.io, bridge app.anubisbridge.com. Gas = DAI-pegged gasDAI. **Mainnet age ≈ 36 days** per own site.

## Core contracts (all UNVERIFIED on explorer)
| Role | Address | Codesize* | Verified | Proxy | Owner/admin |
|---|---|---|---|---|---|
| Factory | 0xaf6F4e641C86A25518509BC840051A8652Af598A | 20,615 | n | none | feeToSetter **EOA** 0xc512…887a; feeTo **EOA** 0x8835…149a |
| Router02 | 0x3E412E02B6157fBE80b6C6697f3Ce1142E629019 | 33,567 | n | none | no owner() |
| WETH-like | 0x8C6CB6539CD70111F38487eB4a7278842F5CB3C6 | – | n | – | – |
| Pair[0] TKNA/DAI | 0xb6b2CCDa77c2476ae1aF5A44bE1C278ACD99BcF3 | 16,433 | n | none | – |
| MasterChef/Farm/Vault | none found (frontend bundle has none; pure swap UI) | – | – | – | – |

*chars incl. 0x. Factory: 683 pairs. Canonical UniV2 mainnet sizes: factory 27,721 / pair 22,589 → RocketSwap bytecode differs materially (recompiled/modified).

## Audit / bounty
- **No audit anywhere**: DefiLlama audits=0, adapter PR audit-links field empty, rocketswap.org HTML+JS bundle contain 0 hits for "audit"/"bounty". No bounty program found. X bio unreachable (blocked) — treat as unaudited/unbountied.

## Fork-family guess
UniV2 fork with **MiniSwap lineage** — pair symbol/name is `MINI-LP` / "RocketSwap LP Token" (MiniSwap's LP branding), not `UNI-V2`. Sizes differ from both canonicals → custom-modified fork. Router→Factory/WETH wiring matches Router02 ABI.

## Red flags (ranked)
1. **Self-referential TVL pricing**: DefiLlama PR #19716 (author staff002-web) adds a *custom coins adapter* (own fork `defillama-server`, `coins/src/adapters/other/anubis.ts`) that prices LGNS/gLGNS/VST/AOS/GD/RM/AUG **from RocketSwap's own pool reserves**, which then back the $187M TVL. Anchor DAI/LGNS pool alone ≈ $163M ("AWAKE genesis project"). No external markets for these tokens → TVL largely mint-price fiction.
2. Pool book is mythology-token vs stable pairs (TKNA/TKNB/MERITT/OSIRIS/HORUS vs DAI/USDS) with trillion-unit supplies.
3. **Zero verified contracts** for router/factory/pairs despite marketing claims of auditable code.
4. Single-key control: feeToSetter and feeTo are EOAs; no timeloveck/multisig observed.
5. Factory counters show only **37 lifetime txs for 683 pairs** → pairs bulk-created internally/state-imported, not organic.
6. Chain is 36 days old with claimed $4.57B gasDAI mcap + 80M txs; "threshold-encrypted mempool / shielded LP" claims unverifiable.
7. Sketchy URL hygiene: official listing mixes rocketswap.org and swap.deepsea.monster; bridge uses single custody address 0x8932fe7726C1EE743F662f485C3e5a5D1D595F71.
