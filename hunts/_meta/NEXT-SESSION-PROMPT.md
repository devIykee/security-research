# Next-session prompt — Base Dollar (BD)

Paste everything below the line into a fresh session.

---

Load the EVM bug-hunting skill from `~/.claude/skills/iykes-web3-bughunt-skill`
(already installed) and run a hunt on **Base Dollar (BD)**.

Working dir: `/home/iyke/coding/security-research`. Put everything under
`hunts/basedalpha/` or a new `hunts/base-dollar/` — check which of those two
already has recon in it first and reuse it rather than starting a parallel dir.

**Stay out of these directories, other sessions own them:**
- `hunts/sat-rush/` — parallel Solana session
- `hunts/enhanced/` — closed, dropped

## Why this target

Rank #3 on `hunts/RANKED-TARGETS-2026-08-23.md`. Rank #2 (Enhanced) was dropped
after intake: it turned out to be Sherlock-audited May-Jun 2026 with deployed
bytecode diffing identical to the post-audit repo, ~$173k TVL, no bounty program.
Full reasoning and the leads left behind are in `hunts/enhanced/DISPOSITION.md`.
Do not reopen Enhanced.

## Target

```
PROJECT_NAME   : Base Dollar (BD)
CHAIN          : Base (chainId 8453)
PRODUCT_TYPE   : lending/CDP — Liquity V2 fork with a custom Aerodrome LP branch
TVL            : ~$158-163k
RESEARCHER     : deviykee
```

Fill the rest of the INTAKE block yourself in Step 1/2 (site, X handle, docs, RPC,
core addresses, bounty status). Verify the GitHub org rather than assuming it.

## The edge, and it is a specific one

This is a **licensed Liquity V2 fork**, so the base CDP code is heavily audited
upstream and is not where the bug is. The value is entirely in the **diff**:

- a custom **Aerodrome LP collateral branch** (Liquity V2 branches are normally
  plain LSTs, not LP tokens)
- an **`AeroManager` fee skim**

Both are original code bolted onto reviewed foundations. So structure the hunt as
a diff hunt, not a fresh audit:

1. Get the fork's source (open GitHub per the target list) and get real Liquity V2
   at the corresponding version.
2. Diff them. Everything identical to upstream is out of scope. Write the diff
   file list into `coverage.md` as your denominator Y.
3. Then read only the diff, plus every upstream call site the diff touches.

Angles worth forcing on an LP-collateral CDP branch, once you have the diff:

- LP token pricing. A Liquity V2 branch prices collateral for redemptions,
  liquidations, and interest-rate ordering. An Aerodrome LP token's value is a
  function of two reserves, so ask whether the price source is manipulable within
  a block and whether it is used anywhere a single tx can profit from moving it.
- Whether the LP branch respects Liquity V2's shutdown / branch-isolation
  invariants, or whether a bad LP branch can socialize losses into the others.
- `AeroManager` fee skim: who can call it, whether it can be pointed at trove
  collateral rather than only at accrued fees, whether it is metered.
- Aerodrome gauge/emission interactions if the LP is staked while serving as
  collateral: does a claim or an unstake path let collateral leave a trove?
- Redemption and liquidation ordering with an illiquid collateral (LP tokens can
  be far thinner than an LST).

Standard playbook rules apply: fork/`eth_call` verification only, never touch
mainnet funds, maintain `coverage.md` incrementally with a real denominator,
kill your own findings before writing them up, honest severity with the bound
stated, and bear in mind the payout ceiling is low at this TVL — so timebox it
and bail early if the diff turns out to be thin or already audited.

Before going deep, run the 30-minute pre-hunt checklist from the target list:
implementation addresses from the app, `getCode` plus first/last tx on Basescan,
and grep Immunefi / Cantina / Sherlock / Code4rena / HackerOne for both the
project name and the GitHub org. If BD already has a live bounty or a recent
audit covering the Aero branch specifically, say so and stop, then move to
Tier 2: **Liquid Royalty** (Berachain, ~$3.9m, novel senior/junior/ALAR tranche
accounting, audit links redacted) is the highest-TVL unclaimed target on the list
and is the better use of hours if BD closes out.
