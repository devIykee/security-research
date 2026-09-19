# Next-session prompt — Liquid Royalty first, then LeverUp

Paste everything below the line into a fresh session.

---

Load the EVM bug-hunting skill from
`/home/iyke/coding/security-research/.agents/skills/iykes-evm-bughunt-skill/SKILL.md`
and run it on the remaining Tier 2 / Tier 3 list below.

Working dir: `/home/iyke/coding/security-research`.
Researcher: **deviykee**. Fork / `eth_call` only. Never touch mainnet funds.
Maintain `coverage.md` incrementally. Honest severity with the bound stated.
Kill your own findings. No public disclosure while live.

Register in `TODO.md` as a new identity (example: `liquid-royalty-bughunt-iyke`).
`TODO.md` is gitignored. Do not duplicate work already claimed there.

**Stay out of these directories; other sessions own them:**
- `hunts/sat-rush/` — parallel Solana session
- `hunts/enhanced/` — closed, dropped (Sherlock May–Jun 2026)
- `hunts/base-dollar/` and `hunts/basedalpha/` — Base Dollar session
- `hunts/predict-fun/` and weaker-audits in-progress
- `hunts/townsquare-lending/` — closed this pass (see disposition below). Do not reopen unless TVL in `TownSqVault` 0x96ed8d9a… returns.

Reuse empty dirs if they exist: `hunts/liquid-royalty/`, `hunts/leverup/`.
Do not create a parallel folder for the same protocol.

## Already gated this week (do not redo)

### TownSquare Lending — DROP
Path-scoped hunt 24 Aug 2026. Write-up: `hunts/townsquare-lending/DISPOSITION.md`.
Folks-style hub/spoke, **two Q3 2025 audits** (Sherlock collaborative + Astrasec).
Live parent TVL ~$0.75m. App ~$46m is inflated. Custom 2026 vaults exist but:
- `TownSqVault` 0x96ed8d9aa65b8d5ed23d732bd6e18ad038dfcfb1 is **$0**
- loop TVL ~$210k sits in **Native-LP** tokens on Native-curated CreditVault 0xcD1D2D60…e5B4
No permissionless Critical. Skip.

### Neverland — DROP as primary
30-min gate 24 Aug 2026. Write-up: `hunts/neverland/INTAKE.md`.
Aave V3 fork + custom veDUST / self-repay. **FAILS 0–1 audit:** Composable Security Aug 2025 (custom tokenomics, 1C/3H fixed), Sherlock lending-pool collaborative Jun 2026, Octane oracles, plus upstream Aave V3. ~$12.4m supplied is real but crowded/reviewed.
Only reopen if you find a **named post-Jun-2026 deploy** whose bytecode is outside those reports. Do not audit Aave-identical code.

### Enhanced — DROP
`hunts/enhanced/DISPOSITION.md`. Sherlock May–Jun 2026. Do not reopen.

## Order of work (do this, in this order)

1. **Liquid Royalty** (Berachain) — full playbook Steps 1–6. This is the hunt.
2. If LR dies at the 30-min gate (2+ audits, live bounty, not permissionless, unreachable), **LeverUp** (Monad) — 30-min gate then Steps 1–6 if it passes.
3. Only if both die: 20-minute gates on **K613**, **HRUSD**, **Magpie Capital**. Timebox hard. Dust TVL is not a full-day target.

HARD excludes still apply: top-100/blue-chip, Immunefi/Cantina/Sherlock/Code4rena/HackerOne live programs, 2+ full audits with no post-audit new custody code, keeper/backend/Privy-gated, announced-not-live TVL, anonymous unfunded teams.

## 30-minute pre-hunt checklist (every target, before deep read)

1. Implementation addresses from the app (not marketing).
2. `cast codesize` + token balances on the explorer. Funds must sit in the contract, not an EOA.
3. Ordinary user can call `deposit`/`withdraw`/`stake`/`borrow`/`redeem` and **contract logic** moves tokens.
4. Grep Immunefi / Cantina / Sherlock / Code4rena / HackerOne for exact name **and** GitHub org.
5. Audit PDFs on docs/GitHub. Redacted “Audits: Yes” is not a pass; a public PDF or contest page is a drop if count ≥2 and no post-audit new code.
6. Named founder / admin on official X or TG **or** a cited `security@` from docs. Plus raise/treasury/fees so they can pay.

If any HARD fail: write a short DISPOSITION.md and move to the next name. Do not sink hours.

---

# Target 1 — Liquid Royalty (deep dive)

```
PROJECT_NAME   : Liquid Royalty
X_HANDLE       : @liquidroyalty
WEBSITE        : https://liquidroyalty.com
CHAIN          : Berachain
RPC            : https://rpc.berachain.com
CHAIN_ID       : 80094
EXPLORER       : https://berascan.com
KNOWN_ADDRS    : vault=0x4272200cC6688F2879ea9F61506aE03EA8ad6415
                 stakingToken=0x7754272c866892CaD4a414C76f060645bDc27203
                 (forum-listed — re-verify on Berascan before treating as core)
PRODUCT_TYPE   : vault / multi-strategy-vault (RWA cashflow + Senior/Junior/ALAR tranches)
BOUNTY/CONTEST : none known; BeraHub audit links redacted — treat as unverified / ≤1 until a PDF is public
NOTES          : User stakes USDe into Senior / Junior / ALAR. Royalty tokens + tranche spillover.
                 TradingStrategy flags vaults Severe. ~$3.9m across 3 vaults
                 (Junior ~$2.1m, ALAR ~$1.58m, Senior ~$199k).
                 Reachable: X @liquidroyalty, TG @repper5354, email alan@pkmt.io (verify from an official page in Step 10A; do not DM the first Google hit).
                 Vaults ~0.5–0.7y old. Live deposits.
RESEARCHER     : deviykee
```

Fill the rest of INTAKE in Step 1/2 (docs URL, other vault addresses, whether USDe is the live staking asset). Workspace: `hunts/liquid-royalty/`.

### Why this is the target

Highest remaining TVL that is not a blue-chip, not on a public bounty platform in prior sweeps, and has **novel custody math**: senior/junior/ALAR spillover, cascading backstop, merchant-settlement cash vs tranche NAV. That is a dual-ledger hunt (playbook Steps 5.6 and 6 for vaults). TradingStrategy “Severe” is a lead, not a finding.

### Gate first (do not skip)

- Berascan: code at the two forum addresses, USDe (or whatever staking token) **balance of the vault**, not an EOA.
- Confirm three separate vaults and map Junior / ALAR / Senior addresses + live balances. DefiLlama ~$3.9m must be re-summed from `balanceOf` / `totalAssets`.
- Permissionless: ordinary user `deposit`/`stake`/`withdraw`/`redeem` moves tokens via contract logic. If a merchant backend, matcher, or admin disburses, **drop** (gated).
- Search “liquid royalty” / “liquidroyalty” / pkmt on Immunefi, Cantina, Sherlock, Code4rena, HackerOne. Any hit → drop.
- Unredact the audit story: if two public full-scope PDFs exist and live bytecode matches, drop. Redacted BeraHub links are **not** a drop by themselves.
- Contact: quote an official page for `alan@pkmt.io` or `security@` before any DM. TG @repper5354 is backup only.

### Hunt shape once the gate passes

Product type is `vault` + tranche spillover, so load after the surface map:
- `evm-audit-general` + `evm-audit-precision-math` (always)
- `evm-audit-erc4626` (if share/asset conversion)
- `evm-audit-defi-lending` (tranche backstop / liquidation-like spillover)
- `evm-audit-oracles` if NAV uses an external price
- `evm-audit-access-control`

Force these dual-ledger questions on **one tranche at a time**:

1. Three notions of value separately: merchant settlement cash, internal tranche principal book, share NAV. Can they desync?
2. Senior protected by Junior + ALAR spillover: on a loss, who is actually burned, and can a Senior exit at par while Junior is already insolvent?
3. First-depositor / share inflation on empty or thin Senior (~$199k).
4. Rounding direction on spillover (always favor the vault?).
5. Can a user donate / flash-inflate a royalty token or staking token to steal from another tranche?
6. Withdraw isolation: if one tranche is stuck, does `totalAssets` still price it so the healthy tranche can be drained (preferential exit)?
7. Owner/admin: can they retarget royalty source, oracle, or spillover after deposits are live? Label Trust, do not call it Critical unless a stranger can trigger it.
8. Pause: does pause block deposits but leave a bank-run redeem open, or freeze exits?

PoC: smallest Foundry test that proves net fund impact. Prefer exact-logic local unit test plus live magnitudes over a slow Berachain full-holder fork. Scaffold with `tools/step7_poc_scaffold.sh` only after a live path is confirmed.

If coverage of in-scope production files is under 50% at the end, say so. Do not imply a complete audit.

---

# Target 2 — LeverUp (only if Liquid Royalty is dropped)

```
PROJECT_NAME   : LeverUp
X_HANDLE       : @LeverUp_xyz
WEBSITE        : https://leverup.xyz   (confirm; DefiLlama slug leverup)
DOCS           : https://docs.leverup.xyz
CHAIN          : Monad
RPC            : https://rpc.monad.xyz
CHAIN_ID       : 143
EXPLORER       : https://monadvision.com
PRODUCT_TYPE   : perps (own engine vs wrapper) + vault (LVUSD / LVMON backing)
NOTES          : LP-free virtual liquidity, advertised 1001x, AnyCollateral, synthetic settlement.
                 ~$2.96m TVL. Fees 30d ~$45k. DefiLlama “Audits: Yes” — verify count and firms.
RESEARCHER     : deviykee
```

Workspace: `hunts/leverup/`.

### 30-min gate (mandatory)

DefiLlama already says audits exist. **If you find ≥2 full audits or a public bounty, drop.** One audit plus post-audit new perps/vault code can still be hunted as a diff.

Confirm:
- User signs `deposit` / `trade` / `redeem` and the **program/contract** moves collateral. Not a keeper-only matching engine.
- LVUSD / LVMON vaults actually hold tokens (balances on explorer).
- Named team on official X @LeverUp_xyz matching the docs URL.

### If it passes, hunt this edge only

This is not “audit GMX.” It is high-leverage accounting:

- Virtual liquidity / synthetic AMM: can a trader move mark without a real LP and extract from the vault?
- ADL / liquidation: self-liquidation profit, dust positions, oracle staleness, one-block manip that does **not** restore.
- Vault backing: `totalAssets` / backing vs actual token balance (dual-ledger again). Can profitable traders drain LVUSD/LVMON while NAV still marks winners whole?
- AnyCollateral: weird ERC20 (fee-on-transfer, rebase) as margin.
- Isolate owner-set leverage params (Trust) from a stranger opening a 1001x and stealing.

Timebox. $3m is meaningful but not unbounded. If the engine is a thin wrapper on someone else’s perps, stop.

---

# Targets 3–5 — only if 1 and 2 are dead (20 min each)

Do **not** start these in parallel with Liquid Royalty.

| Name | Claimed TVL | Gate |
|------|-------------|------|
| K613 | ~$36k Monad lending | Confirm native market not a wrapper. If unaudited and permissionless, one hour max on oracle + isolation. Payout ceiling is tiny. |
| HRUSD | ~$10k basis vault, listed 19 Aug 2026 | Confirm EVM, confirm vault holds stables, user-callable deposit/withdraw. Else vapor. |
| Magpie Capital | ~$3.7k lending | Dust. Skip unless you are already in the explorer and see a novel hole in 10 minutes. |

TownSquare is **not** on this fallback list. It was already hunted.

---

# Playbook mechanics (do not improvise)

Tools: `/home/iyke/coding/security-research/.agents/skills/iykes-evm-bughunt-skill/tools/`
`cast`/`forge` on PATH via `/home/iyke/coding/security-research/bin`.

```
./tools/step1_ground_truth.sh "$RPC" "$CID"
./tools/step2_bundle_grep.sh "<WEBSITE>"
./tools/step3_surface_map.sh "$RPC" "$CID" "0x<core>" "<EXPLORER>/api/v2"
./tools/step4_auth_triage.sh "$RPC" "0x<core>"
```

Berachain explorer is Berascan (Etherscan-style), not Blockscout. If `api/v2` 404s, use `cast` + Sourcify `https://sourcify.dev/server/v2/contract/80094/<addr>?fields=sources` and Berascan API.

Monad: chainId 143, RPC `https://rpc.monad.xyz`, explorer https://monadvision.com (Blockscout API may 403; use `cast`).

After Step 3, set Y in `coverage.md`. Update the table when you open a file or finish a path.

If you confirm a permissionless bug: Step 7 PoC, Step 8 honest severity, Step 9 report skeleton, Step 10A contacts.md with URL + quote **before** any DM. First DM via `step10_dm_skeleton.py`. No exploit steps in the first message.

## User status

Short. What is proven, what is next, what was killed. Cite coverage % if it is low.
When you close a target, write `DISPOSITION.md` even on a drop so the next session does not repeat it.
