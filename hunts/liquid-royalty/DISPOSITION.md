# Liquid Royalty — DISPOSITION

**Researcher:** deviykee  
**Date:** 24 Aug 2026  
**Identity:** liquid-royalty-bughunt-iyke  
**Verdict: DROP as a full-day primary.** Two public AstraSec full-scope PDFs cover the live custody. No permissionless Critical on the traced deposit / withdraw / spillover / backstop paths. Residual risk is owner / price-feed Trust, already acknowledged in those reports.

Do not reopen unless a *named post-Jan-2026 implementation* is shown to be outside both PDFs (new custody bytecode, not another proxy of the same impl).

---

## Gate (30 min, then path-scoped Steps 1–6)

| Criterion | Result |
|-----------|--------|
| Chain / RPC | Berachain 80094. `https://rpc.berachain.com` PASS. block ~25286837 |
| Live TVL | Re-summed from `totalAssets` / `vaultValue`, not DefiLlama. See table below. ~$3.9M ERC-4626 slice matches TradingStrategy. Tranche Senior `vaultValue` is a further ~$2.1M book (not ERC-4626; TradingStrategy missed it). |
| Funds in contracts | Proxies hold the book. Idle USDe in Junior is dust (~0.068). Value is in Kodiak Island LP via hooks, not an EOA. |
| Permissionless | `maxDeposit(dead) = type(uint256).max` on Junior / snrUSD / ALAR. Ordinary `deposit` / `withdraw` exist. Docs call Junior "private"; that is UI/marketing. The contract is open. |
| Public bounty | No Immunefi / Cantina / Sherlock / Code4rena / HackerOne hit on "liquid royalty" / "liquidroyalty" / pkmt. |
| Audits | **FAIL 0–1 / trip 2+.** Two public PDFs. |
| Contact | Forum RFRV posts by `thfalan54` / `thfalan9254` quote `alan@pkmt.io`, X `x.com/liquidroyaltyX`, TG `@repper5354`. Official enough to cite; do not DM unless a live permissionless bug exists. |
| Named team / can pay | Yes. Live fees / TVL / named proposer email. |

### Audits (public PDFs in `audit/`)

1. **AstraSec — Liquid Royalty**, 11 Dec 2025. Scope: `BaseVault.sol`, `JuniorVault.sol`, `ReserveVault.sol`, `UnifiedSeniorVault.sol`. Repo `stratosphere-network/LiquidRoyaltyContracts` (public). 2C addressed, 1H centralization acknowledged, 2M + 1L addressed. Fix commit cited `07b5f14` (not in the shallow clone; HEAD `fb4d9d7`).
2. **AstraSec — ProtocolVault**, 24 Jan 2026 (rev 19 Jan). Scope: `ProtocolVault.sol` ERC-4626 USDe vault. Repo `stratosphere-network/ProtocolVault` (not public). 2H: TWAP `updateTokenAPrice` mitigated, centralization acknowledged. Docs say this was "in collaboration with Hyacinth"; that is the same report, not a third firm.

Hyacinth listing `AuditReport-LiquidRoyalty-ProtocolVault.pdf` is the AstraSec ProtocolVault PDF.

### Live addresses (Berachain 80094)

USDe `0x5d3a1Ff2b6BAb83b63cd9AD0787074081a52ef34`. SAIL.r `0x59a61b8d3064a51a95a5d6393c03e2152b1a2770`.

| Role | Proxy | Impl | Book / notes |
|------|-------|------|----------------|
| Junior Tranche (live $2.10M) | `0x3a0a97dca5e6cacc258490d5ece453412f8e1883` | `0x6Db72eD03EfeA49D00c601Fd4738c06a250Fe0Dd` | ERC-4626 `jnr`. `asset=USDe`. Idle USDe ~0.068. **Wired `seniorVault=0x49298F43…`.** Impl is the README Junior address. |
| Senior Tranche (book ~$2.10M) | `0x49298F4314eb127041b814A2616c25687Db6b650` | `0x6baD25B18d4c63f9e0023C64Ed02A18E7c861d1d` | Name "Senior Tranche". **Not ERC-4626.** Wired `juniorVault=0x3a0a97dc…`, `reserveVault=0x7754272c…`. `backingRatio≈104.9%`. **`paused=true`.** Idle USDe dust. TradingStrategy missed it. |
| Reserve / ALAR forum token | `0x7754272c866892CaD4a414C76f060645bDc27203` | `0x13baAB17dB247d0c837e1DD341f05C21ecD55E67` | `alar`. `totalAssets` ~851k. Idle USDe 0. README Reserve. |
| snrUSD "Senior Vault Master" | `0xC38421E5577250EBa177Bc5bC832E747bea13Ee0` | `0xa4e99ae599E2F656917335a5b09A06C420954768` | ERC-4626 ~200.5k USDe book, ~19k idle USDe. `juniorVault()` / `kodiakHook()` **FAIL** — not the tranche senior. ProtocolVault-shaped. |
| ALAR SailOut (TS) | `0x09cea16a2563c2d7d807c86f5b8da760389b5915` | `0xC046dd6A435D30E716616ef399460ca81eAA35Bb` | ERC-4626 ~1.586M book, ~2.5k USDe + ~108.6k SAIL.r. No `seniorVault()`. ProtocolVault-shaped. |
| Junior Vault Master (forum JNR) | `0x268D71B488C584579E7179b8294187Fdd4F450B3` | `0xfFc5D8F1F7D0e06aea62b34090C4328b4643AF96` | ~235k book. Older/smaller sibling. |
| BeraHub reward vaults | ALAR `0x4272200cC6…6415`, Senior `0x18e310dD4A…2A071`, Junior `0xaDe4Ff3041…1d75` | n/a | PoL wrappers. Staking tokens are the vault shares above. Not core custody. |

Forum-listed `vault=0x4272200cC6…` is a **BeraHub reward vault**, not the protocol vault.

Admin on live Junior: `0x5Fc7Ab7417e82C681a021C82bec4aD04541cc13A`. LM `0x23FD5F6e2B07970c9B00D1da8E85c201711B7b74`. Price feed `0xE90986e67A9cbEbcF67084cbBF8E24FAa0a43Bcb`.

---

## Path-scoped read (not a full audit)

Source: public `stratosphere-network/LiquidRoyaltyContracts` cloned to `repo/LiquidRoyaltyContracts`. ProtocolVault repo is private.

Coverage: see `coverage.md`. Core impl files 8/13 traced (~62%). ProtocolVault live impls unverified this pass. Findings apply to examined paths only.

### Dual-ledger (forced questions)

1. **Three ledgers.** `_vaultValue` (internal USD book) is `totalAssets()` for Junior/Reserve. Actual USDe/LP sit in the vault and/or `KodiakVaultHook`. Price-feed `executeVaultValueAction` can set the book. Merchant settlement cash is off-chain. They can desync by design. Stranger cannot set the book.
2. **Spillover / backstop.** `rebase(lpPrice)` is `onlyAdmin`. Profit spillover sets Senior `_vaultValue` to 110% then `_transferToJunior` / `_transferToReserve`. If hook/LP is missing, those helpers **return silently** after the book already dropped: excess stays as unbooked LP in Senior (hidden surplus), Junior is not credited. Not a stranger drain. Backstop uses actual LP pulled. Admin-supplied `lpPrice` can mis-size LP vs USD. **Trust.**
3. **First-depositor.** `__BaseVault_init` sets `_vaultValue = initialValue_` with zero shares. Empty-vault inflation is real in the abstract, **not live**: Junior supply ~2.00e24. No virtual shares / `_decimalsOffset`.
4. **Rounding.** 80/20 spillover can leave 1 wei of excess in the 110% target vs `toJunior+toReserve`. Immaterial.
5. **Donation / flash inflate.** `totalAssets` ignores raw `balanceOf`. Donating USDe does not mint shares. Royalty-token donate does not move `_vaultValue` without seeder/price-feed. Seeder `seedVault` takes caller-supplied `lpPrice` (`onlySeeder`). **Trust.**
6. **Preferential exit.** Junior idle USDe is dust. If Island LP cannot burn, `_ensureLiquidityAvailable` reverts `InsufficientLiquidity` (fail closed) except ~$0.07 idle. snrUSD has ~$19k idle vs ~$200k book; bounded and needs LP stuck. Not a live Critical bank-run.
7. **Owner retarget.** UUPS `onlyContractUpdater`, `setRole`, `setRewardVault`, `kodiakHook`, whitelist, `adminBurn` (burns shares, does **not** cut `_vaultValue`). AstraSec H-1 acknowledged. **Trust.**
8. **Pause.** Senior `deposit` is `whenNotPaused`. Junior `BaseVault.deposit` has **no pause check**. Pause-on-Senior / open-Junior is ops. Emergency withdraw on Senior requires pause + admin, sends to treasury.

### Killed permissionless Criticals

| Path | Result |
|------|--------|
| Missing auth on deposit/withdraw | Open by design. Share math + 7d cooldown + fees. |
| `receiveSpillover` / `provideBackstop` | `onlySeniorVault`. Live Junior senior is `0x49298F43…`. Rebase is `onlyAdmin`. |
| ERC-4626 donation inflation | Book is `_vaultValue`, not token balance. |
| Hook `liquidateLPForAmount` | `onlyVault`. Assumes island `token1` is the stable. Config risk, not a stranger call. |
| Aggregator `.call` in hook | Admin / `onlyVault` invest path (`onlyLiquidityManager`). Malicious calldata is Trust. |
| V4 `migrateToNonRebasing` yield to `admin()` | `onlyAdmin`. After migration, rebase mints yield to admin. Trust / centralization. |
| Junior 20% early-withdraw penalty unbooked | Penalty USDe stays in the vault while `_vaultValue` only drops the net. Surplus, not theft. |
| Silent spillover with no LP | Senior book down, assets stay. Hidden surplus. |

AstraSec already published C-1 (auth-less `_withdraw`, addressed), C-2 (`depositLP` island mismatch, addressed; pending-LP path is deprecated in current Junior). Do not re-report those.

---

## Why this is not the hunt

HARD exclude: **2+ public full-scope audits**, live bytecode of the $2.1M Junior and Reserve matches the audited `LiquidRoyaltyContracts` impls in that repo's README, and snrUSD / ALAR-TS match the ProtocolVault product that has its own public PDF. Post-audit V3 cooldown / V4 migration are owner-gated. No Immunefi-style program, but the review density is the drop.

Next session: **LeverUp** (Monad), 30-min gate first.
