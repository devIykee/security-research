# LeverUp — DISPOSITION

**Researcher:** deviykee  
**Date:** 24 Aug 2026  
**Identity:** liquid-royalty-bughunt-iyke (LeverUp fallback)  
**Verdict: DROP.** Two public Zenith audits. Trading architecture is explicitly non-custodial (assets stay in user wallets). `leverup-contracts` GitHub is private. Remaining TVL sits in LVUSD/LVMON reserve vaults without public source this pass.

Do not reopen unless public source for the live vault/issuer impls appears, or a named post-audit deploy is shown outside both Zenith reports.

---

## Gate

| Criterion | Result |
|-----------|--------|
| Chain / RPC | Monad 143. `https://rpc.monad.xyz` PASS (needs long cast timeout). block ~98807222 |
| Live TVL | DefiLlama ~$3.29m. On-chain: LVUSD vault ~897,854 USDC (6dp); LVMON vault ~7.26M WMON; MON staking vault ~214k WMON + ~98k native MON. |
| Funds in contracts | Reserve vaults hold USDC/WMON. **Trading collateral does not** (Zenith report + docs: "Assets Remain in User Wallets" / "No Deposit, No Withdrawal"). |
| Permissionless trade | 1CT / agent wallet / passkey UX. Open pulls collateral from the wallet with Pyth pull-oracle keepers. Not a classic deposit vault for positions. |
| Public bounty | No Immunefi / Cantina / Sherlock / Code4rena / HackerOne program found. |
| Audits | **FAIL 0–1.** Two public Zenith PDFs in `audit/` and `github.com/leverup-xyz/audit`. |
| Contact / team | Named `@LeverUp_xyz`, co-founder mentions in the wild, live fees. |

### Audits

1. **Zenith — Protocol**, 19 Sep–1 Oct 2025 (report 3 Oct 2025). Scope: `TradingOpenFacet`, `TradingCloseFacet`, `TradingPortalFacet`, `TradingCheckerFacet`, `LibTrading` at commit `ebacd4aa…`. Repo `leverup-xyz/leverup-contracts` (private now). 0C / 1H resolved / 5M (4 fixed, **M-5 PnL bankruptcy ACKNOWLEDGED** as design). PDF: `audit/LeverUp-Zenith-Protocol.pdf`.
2. **Zenith — LV Token**, 11–12 Dec 2025. Governance token. 0C/0H/0M/1L. PDF: `audit/LeverUp-Zenith-LV-Token.pdf`.

DefiCare summarizes both. Docs list both under Audits.

### Live addresses (Monad 143)

| Role | Address | Notes |
|------|---------|--------|
| LVUSD Issuer (proxy) | `0x135951057cfcccA7E8ef87ee41318D670f723F68` | `transparency()→0x0Ef8Fd8F…` |
| LVMON Issuer (proxy) | `0xbF52cED429C3901AfA4BBF25849269eF7A4ad105` | `transparency()→0x679d25E4…` |
| LVUSD reserve vault | `0xc69d584B3118e94B3443cc6c67076281242fA704` | ~897.8k USDC. impl `0x90974f16…` |
| LVMON reserve vault | `0x06058fE1FcFAD19181438508600925106309e5fe` | ~7.26M WMON. impl `0xc9a3214b…` |
| MON Staking Vault | `0xf71B390448df37C8379332F372f344A576574d4A` | `stakingState.stakedBalance≈71.6e18*1000?` (71.6M MON units in earlier call). Also listed under LVMON transparency vaults. |
| LVUSD / LVMON / LV tokens | docs CA page | ERC20s with code |

Naive `deposit`/`redeem`/`mint`/`stake` eth_calls on the three vaults reverted (wrong ABI or gated). No public source to continue without a long unverified reverse-engineering pass.

---

## Why drop

1. HARD: **2+ public full audits** of the protocol family.
2. Trading is **non-custodial by design** (Zenith §2.1 + 1CT docs). The interesting dual-ledger / VMMV insolvency path is the acknowledged M-5 design trade-off, not a stranger free win.
3. Core contracts repo is **private**. Reserve vaults hold the DefiLlama TVL but lack Sourcify/public Solidity this session.
4. Timebox. $3m with audited trading facets + private vaults is a poor full-day target after Liquid Royalty already consumed the gate budget.

Next: 20-min gates on **K613**, **HRUSD**, **Magpie Capital** per the Tier-2 prompt.
