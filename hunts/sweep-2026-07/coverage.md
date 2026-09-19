# Coverage - sweep-jul-aug-2026 (30-protocol triage + deep hunts)

Coverage: multi-project sweep; per-target tables below.

Last updated: recon phase

## Protocol triage (all 30)

| # | Protocol | TVL | Verdict | Reason |
|---|----------|-----|---------|--------|
| 1 | robinhood-chain-bridge | $437M | skip-canonical | canonical L2 bridge, standard stack |
| 2 | valos | $107M | pending | RWA monad, no url yet |
| 3 | niza | $70M | skip-cex | custodial CEX |
| 4 | wise-token | $70M | deep-q | yield ethereum, addr known |
| 5 | axis | $68M | deep-q | basis-trading, 6d old |
| 6 | azverse-perps | $52M | deep-q | derivatives multichain |
| 7 | y10k-capital | $31M | deep-q | risk curators eth |
| 8 | arcus-perps | $19M | deep-q | RH chain perps |
| 9 | afx-lp | $12M | deep-q | AFX L1 derivatives |
| 10 | syntetika | $12M | deep-q | base risk-curators |
| 11 | xgld/unitas | $11M | deep-q | stablecoin wrapper |
| 12 | agua | $9M | deep-q | capital allocator |
| 13 | subfrost | $8.5M | deep-q | decentralized btc |
| 14 | nuva | $6.5M | deep-q | yield eth |
| 15 | vault-street primeUSD | $6.4M | deep-q | rwa eth |
| 16 | fermiswap | $6.2M | deep-q | dexs eth, 2d old |
| 17 | noxa-fun | $5.8M | HUNTING | launchpad RH chain, addrs found, LaunchLocker verified |
| 18 | up-v3 | $5M | HUNTING | Aerodrome-CL fork RH chain, 180 src files pulled |
| 19 | morpho-midnight | $4.5M | quick-pass | audited Morpho vault stack |
| 20 | adi-bridge | $4.5M | skip-canonical | canonical bridge |
| 21 | predictstreet | $4.1M | pending | ADI chain prediction mkt |
| 22 | webot | $3.3M | skip-cex | custodial CEX |
| 23 | uncx-network-v4 | $3.2M | quick-pass | established locker team |
| 24 | sato | $2.8M | pending | dexs eth |
| 25 | katana-perps | $2.2M | quick-pass | katana native perps |
| 26 | sodax | $2.1M | quick-pass | ICON team, established |
| 27 | meridian-perps | $1.9M | deep-q | RH chain perps |
| 28 | coinmerce-capital | $1.7M | quick-pass | HL curator |
| 29 | ammalgam-vaults | $1.6M | quick-pass | audited |
| 30 | byzanlink-rwa | $1.5M | pending | hedera+eth rwa |

## Target: noxa-fun (Robinhood Chain 4663)

| File | Read? | Paths traced | Notes |
|------|-------|--------------|-------|
| src/0x7F03...acD85/contracts_LaunchLocker.sol | partial | reading now | verified via Sourcify |
| 0x0742...133c (launchpad core) | no | selector map done | UNVERIFIED, launch config + dex factory refs |

## Target: up-v3 (Robinhood Chain 4663)

| File | Read? | Paths traced | Notes |
|------|-------|--------------|-------|
| CLFactory/CLPool/NFPM/SwapRouter sources | pulled, not read | - | Aerodrome Slipstream lineage |
| Router.sol (velodrome-style w/ gauges) | pulled, not read | - | exact_match vs existing deploy |
| EmissionDepositRouter.sol | pulled, not read | - | exact_match |
| Vault 0x559771... | no | - | UNVERIFIED 33KB |

## Explicitly excluded

| Path / area | Reason |
|-------------|--------|
| lib/** @openzeppelin/** vendored | stock OZ |
| interfaces/** | typed views of external systems |
