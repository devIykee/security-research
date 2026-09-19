# Master Hunt Plan - 31 EVM protocols (post-Jul-2026 launches)

Researcher: deviykee | Date started: 2026-08-26
Rules: fork/eth_call only, honest severity, kill own findings, coverage tracked per target.

## Triage (priority = TVL x category-risk x newness)

### Tier 1 - hunt first
| # | Target | TVL | Chain | Cat | Age | Why |
|---|--------|-----|-------|-----|-----|-----|
| 1 | Valos | $107M | Monad | RWA | 33d | largest non-bridge TVL, RWA NAV/oracle risk |
| 2 | Wise Token | $70M | ETH | Yield | 8d | brand reuses known 2021 scheme name, fresh |
| 3 | Axis | $68M | ETH | Basis trading | 6d | brand new, big TVL day-one |
| 4 | AZverse Perps | $52M | Arb/BNB/ETH | Perps | 26d | perps oracle/liq risk, multichain |
| 5 | Y10K Capital | $31M | ETH+Sei | Risk curators | 42d | Morpho-vault curator risk |
| 6 | BDEX V3 | $31M | BOT Chain | DEX | 2d | 2 days old, $31M already |
| 7 | Arcus Perps | $19M | Robinhood | Perps | 47d | new-chain perps |
| 8 | Syntetika | $11.6M | Base | Risk curators | 7d | very fresh |
| 9 | XGLD | $11M | BNB/Base/ETH | Stable wrapper | 33d | wrapper peg mechanics |
| 10 | NOXA Fun | $5.8M | Robinhood/Monad | Launchpad | 48d | bug class #1: migration pool squat |

### Tier 2 - next wave
Agua ($8.75M allocator), SUBFROST ($8.5M BTC), NUVA ($6.5M yield), Vault Street primeUSD ($6.4M RWA), FermiSwap ($6.2M, 2d old), Icarus CL ($5.2M RISE), up v3 ($5M +608%), Meridian Perps ($1.9M +89%), Ammalgam Vaults ($1.6M), Surge Credit ($1.2M lending), PredictStreet, Katana Perps, SATO

### Tier 3 - deprioritized (reason)
| Target | Reason |
|--------|--------|
| Robinhood Chain Bridge $437M | canonical bridge = OP-stack std, heavily audited; revisit if time |
| ADI Bridge, SODAX | canonical/third-party bridges w/ audits |
| UNCX V4 | established team, prior audits |
| Morpho Midnight | Morpho Blue core heavily audited; curator-only surface |
| AFX LP, Diamond Finance | battle-tested fork families, check deploy params only |

## Status board
| Target | Step reached | Finding | Status |
|--------|--------------|---------|--------|
| (all) | 0 recon | - | pending |
