# Ranked Bug Hunt Targets — 23 Aug 2026

Ranked by: live on-chain TVL x permissionless custody x new/custom/lightly-reviewed code x funded + reachable.

## Tier 1 — Fresh, Custom, Reachable, No Known Bounty

| # | Name | Chain | TVL | Product | Why |
|---|------|-------|-----|---------|-----|
| 1 | **Sat Rush** | Solana (Anchor-style) | ~$419k (cbBTC Sats Vault) + $508k fees/30d | Vault + lottery (BTC/cbBTC deposit, share math, epoch/prize vaults) | Brand-new custom vault+lottery accounting. No public audit/bounty. Real fees. |
| ~~2~~ | ~~**Enhanced**~~ | ~~Ethereum~~ | ~~$173k~~ | ~~Structured-product vaults~~ | **DROPPED 23 Aug 2026.** Sherlock-audited May-Jun 2026 (1H/7M/26L, all addressed); deployed sources diff identical to post-audit repo; low TVL; no bounty. See `hunts/enhanced/DISPOSITION.md`. |
| 3 | **Base Dollar (BD)** | Base (Solidity) | ~$158-163k | Liquity V2 fork + Aero LP branch | Licensed V2 fork with custom diff (Aero/LP branch + AeroManager fee skim). Open GitHub. |

## Tier 2 — Meaningful TVL, Need 30-min Bounty/Audit/Custody Check

| # | Name | Chain | TVL | Product | Why |
|---|------|-------|-----|---------|-----|
| 4 | **Liquid Royalty** | Berachain (Solidity) | ~$3.9m (3 vaults) | RWA cashflow + senior/junior/ALAR spillover tranches | Novel tranche accounting. TradingStrategy flags "Severe". Audit links redacted. |
| 5 | **Neverland** | Monad (Solidity) | ~$12.44m supplied | Native lending (isolated) | Monad-native money market. Not obviously Aave fork. Need named founder + audit check. |
| 6 | **LeverUp** | Monad (Solidity) | ~$2.96m | LP-free virtual liquidity perps + LVUSD/LVMON vaults | Custom 1001x leverage + synthetic settlement. DefiLlama "Audits: Yes" (verify count). |

## Tier 3 — Small/Tiny, Low Payout Ceiling

| # | Name | Chain | TVL | Product | Why |
|---|------|-------|-----|---------|-----|
| 7 | TownSquare Lending | Monad | ~$543k | Lending | Small native book; unknown audit status |
| 8 | K613 | Monad | ~$36k | Lending | Tiny, likely unaudited |
| 9 | HRUSD | TBD (EVM?) | ~$10k | Basis-trading vault | Listed 19 Aug 2026 |
| 10 | Magpie Capital | TBD | ~$3.7k | Lending | Listed 19 Aug 2026 |

## Watch List (need confirmation before ranking)

- **SquadSwap Thanos** — ~$410k DEX, 2 chains. Need: chain + whether Solidly/Uni fork with own pairs.
- **Icarus CL / V2** — ~$5.17m. RISE chain. Sherlock-audited ve(3,3) Velodrome fork. Weak edge.
- **MortgageFi** — Base lending ~$0.93m. Confirm on-chain loan matching vs admin disbursement.
- **Vicuna Lending / MachFi** — Sonic native, dust TVL ($17k / $3k).

## Pre-Hunt Checklist (before any deep dive)

1. Pull implementation addresses from the app
2. `getCode` + first/last tx on explorer
3. Grep Immunefi / Cantina / Sherlock / C4 / H1 for exact name and GitHub org
4. Confirm: own custody vs wrapper, audit/bounty status, named payor/contact

## Skill Loading

- **Sat Rush** (Solana): use `iykes-solana-bughunt-skill`
- **Enhanced, Base Dollar, Liquid Royalty, Neverland, LeverUp, TownSquare** (EVM): use `iykes-web3-bughunt-skill`
