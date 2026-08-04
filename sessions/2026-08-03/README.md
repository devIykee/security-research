# Robinhood Chain hunt package — 2026-08-03

Researcher: **deviykee** (Iyke skill). Fork / eth_call only. Nothing touched on mainnet.

## Layout

| Path | Contents |
|------|----------|
| `reports/` | Full write-ups + hunt STATUS |
| `dms/` | First private DM drafts (no full exploit runbooks) |
| `poc/` | MiningPool underfund-claim Foundry PoC |
| `sources/` | Verified contract sources used for findings |

## Findings

1. **Medium** — HoodCash MiningPool underfunded claim burns unpaid accrual  
   Report: `reports/hoodcash-miningpool-medium.md`  
   PoC: `cd poc && forge install foundry-rs/forge-std --no-commit && forge test -vv`

2. **Trust/Centralization** — EquityOracle V1 quorum=1 on live CDP  
   Report: `reports/xstocks-oracle-v1-trust.md`

3. **Medium (latent)** — CdpEngine fee debt never minted  
   Report: `reports/xstocks-cdp-fee-debt-latent.md`

## Run PoC

```bash
cd poc
forge install foundry-rs/forge-std --no-commit   # if lib/ missing
forge test -vv
```
