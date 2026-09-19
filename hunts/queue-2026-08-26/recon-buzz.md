# Recon: Buzz Farming (B² / BSquared Network) — 2026-08-26

## DefiLlama
- Slug `buzz-farming` (200). Live TVL: **$254.2M**, single chain BSquared. Listed 2024-07-11.
- Category: Farm. URL: buzz.bsquared.network/farming. Twitter = **BSquaredNetwork (the chain's own)** → in-house product.
- github: null, audit_links: null, audits: **0**. Methodology: aggregates Babylon/Lombard/Bedrock BTCFi strategies.
- Adapter NOT public: module `buzz-farming/index.js` absent from DefiLlama/DefiLlama-Adapters + dimension-adapters trees (private repo) → TVL methodology unverifiable.

## RPC
- Working: `https://rpc.bsquared.network` and `https://bsquared.drpc.org`. publicnode 404s.
- chainId **223 (0xdf)**, block ~37,286,700. NOTE: legacy docs say 60808; explorer's own NEXT_PUBLIC_NETWORK_ID=223 confirms migration.

## On-chain footprint (explorer backend-blockscout.bsquared.network; etherscan-style API works at /api?module=contract&action=getsourcecode)
| role | addr | codesize(B) | owner() | verified | proxy/name |
|---|---|---|---|---|---|
| BUZZ token | 0xc22e8835EF229fb155e0B5B16DE88cfAD53aA48B | ~ | 0xdab968D147A9589Eb86E974da117Cd1D8D51205b | NO | supply 10B |
| UniV2-fork factory | 0x02eAFbE9dE030f69aF02B7D3F2f69B28016f3C83 | ~ | - | NO | - |
| Pair WBTC/BUZZ | 0xd0AF89305d5B4755aE66A8Aea39b9Fa387D48C5E | 22,678 | reverts | NO | **getReserves() reverts — non-standard pair** |
| Pair WBTC/uBTC | 0xdc4224Cea3AfdddBFc6aA23fFeAA1C50A59a6493 | 22,678 (identical code) | reverts | NO | same anomaly |
| Top uBTC vault | 0x5b1399B8b97fBC3601D8B60Cc0F535844C411Bd5 | 3,343 | 0xcFb1b1fB039D2361a8638657487241e1796f60b0 | NO | holds 971 uBTC (~$100M) |
| Reward distributor | 0xFb767623703bed4e61A47F01a7b71341876BFB97 | EOA | - | - | sends BUZZ to users |
| Deployer EOA | 0xe3413dF8BcB8f263fBb2fF442469FC2EB8194F3E | EOA | - | - | created BUZZ master contract |

- BTC assets on B²: WBTC(bridged) 0x4200..0006 (~299), uBTC 0x796e4D53... (~2,400 across holders), uniBTC 0x9391...≈0, lBTC(Lombard)≈0.5. Total ≈ 2,300–2,400 BTC ≈ the whole $254M TVL.
- No MasterChef-style farm contract found on-chain: user deposits appear custodial/off-chain managed (gitbook claims Cobo + Fireboxes custody); only LP pairs + distributor visible.

## Fork family guess
Not a MasterChef clone. UniV2-style AMM fork (pairs/factory) with modified pair logic (getReserves reverts on both pairs). Farming layer is off-chain/custodial — attack surface includes ops wallets + custody integrations, not just EVM code.

## Audit / bounty
- DeFiLlama: 0 audits. Gitbook CLAIMS Scalebit audit — no public report found.
- No bounty program found. Third-party risk graders: Hindenrank C (43/100), ZARQ C+ (59/100).

## Red flags
1. $254M TVL, zero verifiable audits, no open TVL adapter (TVL can't be reproduced).
2. TVL ≈ entire B² chain BTC supply → likely double-count vs underlying Lombard/Bedrock/Babylon exposure.
3. 100% of core contracts unverified on explorer.
4. Non-standard AMM pairs (getReserves reverts) holding protocol liquidity.
5. In-house chain product; rewards in own unverified BUZZ token owned by one EOA.
6. Custodial dependency (Cobo/Fireblocks) + L2 bridge as systemic risk (Hindenrank top collapse scenario).
7. ChainId drift (60808→223) confuses tooling/integrations.
