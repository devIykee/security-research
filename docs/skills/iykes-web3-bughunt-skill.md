---
name: iykes-web3-bughunt-skill
description: >-
  End-to-end smart-contract bug-hunting playbook (researcher: deviykee). Invoke to
  hunt vulnerabilities in an EVM smart contract / DeFi protocol and turn a finding
  into a responsible, paid disclosure. Fill the INTAKE block, then run the steps in
  order. Mechanical probes live in tools/; each step has decision gates and
  fill-in templates for the PoC, report, and disclosure message. Verification is
  fork / eth_call ONLY. Never exploit mainnet. Be token-conservative; use smaller
  models for capable subtasks.
  Use when the user names a target (project, handle, or website) and wants it
  audited for bounties, or says "hunt", "audit this", "find bugs".
---

# Iyke's Web3 Bughunt Skill

By **deviykee**. Fill the INTAKE, then execute the steps top to bottom. Mechanical
probes are scripts under `tools/`; decision gates tell you exactly what to do next.
You should not have to invent the repeatable parts — run the tool, read the gate.

### Pair with EVM audit skills

After Step 3 has source (or a solid surface map), also load **`evm-audit-master`**
and follow its routing table. Always pull `evm-audit-general` +
`evm-audit-precision-math`. For launchpads also load `evm-audit-defi-amm`,
`evm-audit-erc20`, `evm-audit-access-control`, `evm-audit-dos`, and usually
`evm-audit-flashloans` + `evm-audit-chain-specific` (Robinhood Chain is an L2).
Use audit checklists to find bugs; use this playbook for intake, fork PoC, severity
bound, report (researcher deviykee / Iyke), and private disclosure DM.

### Token budget and model routing (apply on every hunt)

Be **token-conservative** for the whole hunt. Prefer cheap, narrow work over
reloading giant contexts. Employ **smaller / faster models** (or lightweight
subagents) wherever they are capable; reserve the primary high-capability model
for judgment-heavy steps only.

| Prefer small / cheap model or subagent | Keep on primary (high-capability) model |
|---|---|
| `cast` / RPC probes, address greps, bundle scrapes | Severity call and kill-your-own-finding |
| Listing holders, pots, codesize, auth-triage loops | Root-cause reading of value-moving paths |
| File search, log tails, compiling forge, running tests | Novel attack design and exploit sequencing |
| Drafting report/DM from a filled template | Final report accuracy and bound honesty |
| Parallel explore lanes with narrow prompts | Disclosure strategy if ambiguous |

Rules:
1. **Do not re-read entire skills** every turn. Load this playbook once per hunt;
   load only the one EVM checklist section you need for the product type.
   For mechanical steps, run the matching script in the **Tools** table below —
   do not re-derive the bash/python by hand.
2. **Shell first for facts.** Prefer `cast`/`curl`/`rg` (or `tools/*.sh`) over long
   model reasoning when the answer is an on-chain number or a string in a file.
3. **Narrow tool output.** Cap logs, `head` greps, avoid dumping megabyte bundles
   into context; write to files and read slices.
4. **One finding path at a time** until confirmed or killed. No shotgun of five
   parallel deep dives unless each is a small explore subagent with a tight prompt.
5. **Subagents:** use `explore` (read-only) or a small model for map/grep/auth
   triage; bring results back as short bullets. Parent model decides go/no-go.
6. **PoC:** smallest test that proves the bound. Prefer exact-logic local PoC +
   on-chain magnitude over multi-hour full-holder forks when RPC is slow.
7. **User updates:** short status (what proven, what next). No essay recaps of
   tool logs.

---

## INTAKE - fill this in before running

Fill only fields you actually know. In the written report, **omit any key whose value is
unknown** (do not print `KEY : unknown` or empty placeholders). Drop the whole line.
`none` is fine when that is a real answer (e.g. no bounty program). Prefer leaving a
field out over guessing.

```
PROJECT_NAME   : <e.g. hood.fun>
X_HANDLE       : <e.g. @hooddotfun>          # only if known; used for private disclosure channel
WEBSITE        : <https://...>               # app URL (where tokens/positions render)
DOCS           : <https://docs...>           # only if known
CHAIN          : <e.g. Robinhood Chain>
RPC            : <https://...>               # confirm in Step 1
CHAIN_ID       : <e.g. 4663>
EXPLORER       : <Blockscout base>
KNOWN_ADDRS    : <role=0x... pairs; omit line if none known>
PRODUCT_TYPE   : <launchpad | lending/CDP | vault | perps | distribution/index | other>
BOUNTY/CONTEST : <live program? amount? or "none / discretionary">
NOTES          : <optional extras; omit if empty>
RESEARCHER     : deviykee
```

Set shell vars from the intake and reuse them:
```bash
RPC="<RPC>"; CID="<CHAIN_ID>"; BS="<EXPLORER>/api/v2"
# TOOLS=path/to/tools  # if not already on PATH / cwd-relative
```

---

## Operating rules (non-negotiable read once, apply always)

1. **Fork / `eth_call` verification only. Never move real funds on mainnet.** A
   passing fork test is the proof. This does not bend for revenge, "I'll give it
   back", or "just to prove it".
2. **Honest severity.** State the bound. A Medium is a Medium.
3. **Ask, never threaten.** No "pay or I release/exploit". That's extortion.
4. **Kill your own finding if it doesn't hold up.** Disproving yourself is the job.
5. **Never publish a live, unpatched bug.** Private channel + private repo until fixed.
6. **Audit contracts, not narratives.** Day-one hype with no verifiable contract =
   scam trap. Sketchy TLDs (`.online`, `.cash`, brand-impersonation) = assume
   phishing until proven; never connect a wallet to them.
7. **Token-conservative; smaller models when capable.** Every hunt. See
   "Token budget and model routing" above. Do not burn context on bulk RPC spam,
   full-file dumps, or re-loading every skill for mechanical steps.

---

## Tools

Mechanical scripts next to this playbook (`tools/`). Prerequisites and full docs:
`tools/README.md`. Run from the hunt workspace; scripts fail non-zero on RPC errors
instead of hanging. Smoke-check: `./tools/selftest.sh`.

| Script | Step | Inputs | Outputs / gates | Why this exists |
|---|---|---|---|---|
| `tools/step1_ground_truth.sh` | 1 | `<RPC> <CHAIN_ID>` | chain-id + block-number; **PASS** or **STOP** | Avoid hours on dead/scam RPCs |
| `tools/step2_creator_trace.sh` | 2A | `<BS> <TOKEN_ADDR>` | creator address (factory/core candidate) | Reliable factory/core discovery |
| `tools/step2_bundle_grep.sh` | 2B | `<WEBSITE>` | role-labeled `0x` hits from JS bundles | Find hidden frontend config addrs |
| `tools/step3_surface_map.sh` | 3 | `<RPC> <CID> <CONTRACT> [BS]` | balance, code size, Sourcify / selectors | Verified vs unverified path |
| `tools/step4_auth_triage.sh` | 4 | `<RPC> <CONTRACT> [extra_sig ...]` | per-sig `guarded` / `OPEN <-- CHECK` | Free-win missing-auth check |
| `tools/step7_poc_scaffold.sh` | 7 | `<RPC> <TARGET> [POC_DIR]` | Foundry PoC skeleton + fork `forge test` cmd | Repeatable fork-only proof setup |
| `tools/step9_report_skeleton.py` | 9 | INTAKE + severity + title (+ optional) | filled Step 9 report markdown | Same report shape every hunt |
| `tools/step10_dm_skeleton.py` | 10 | project/severity/chain/component/impact | filled first DM text | Consistent private first contact |
| `tools/selftest.sh` | — | none | usage/exit smoke for all tools | Catch broken tools before a hunt |

---

## STEP 1 - Ground truth (is this real, and where)

```bash
./tools/step1_ground_truth.sh "$RPC" "$CID"
```
Confirms RPC alive and chain id matches intake; prints block number.

Gate:
- RPC/chain don't resolve, or no docs/verifiable contract exist → **STOP. Likely
  vaporware/scam.** Report that to the user; do not sink hours.
- Real chain confirmed → continue.

---

## STEP 2 - Locate the core contract(s)

Frontends hide addresses in runtime config. Use these in order until you have an address:

**A. Trace a live token/position → its creator (most reliable).**
```bash
# get a token addr from the app (a /tokens/0x... or /coin/0x... link, or the app's RPC calls)
./tools/step2_creator_trace.sh "$BS" "0x<token>"
```
Prints `creator_address_hash` — usually the factory/core.

**B. Grep the app bundle** (Vite: one `/assets/index-*.js`; Next: `/_next/static/chunks/*.js`):
```bash
./tools/step2_bundle_grep.sh "<WEBSITE>"
```
Fetches HTML + JS assets and greps for role-labeled contract addresses.

**C. Browser** (when config is fetched at runtime): load the app, read the network
requests, and pull the `to` addresses from the `eth_call`s; those are the contracts.

**D. Explorer**: search the chain's Blockscout for the token/contract names
(`qUSD`, `VaultManager`, project name).

---

## STEP 3 - Verification gate + surface map

```bash
./tools/step3_surface_map.sh "$RPC" "$CID" "0x<core>" "$BS"
```
Prints balance + code size; writes `src.json` (Sourcify) and `code.hex`; if unverified,
maps PUSH4 selectors and top tx-history selectors.

Gate:
- **Verified** → pull the source files from `src.json` and read them (30-min path).
- **Unverified** → use the script's selector map (bytecode + tx history) and continue.

---

## STEP 4 - Auth triage (find the free win first)

`eth_call` every state-changing admin/keeper function from an attacker address. If
it does NOT revert, the access control is missing = likely Critical.
```bash
./tools/step4_auth_triage.sh "$RPC" "0x<core>"
# optional extra signatures from Step 3 surface map:
# ./tools/step4_auth_triage.sh "$RPC" "0x<core>" "setMigrator(address)" "distribute(address[],uint256[])"
```
Probes default admin/keeper sigs from `0x…dEaD`; prints `guarded` or `OPEN <-- CHECK`.

---

## STEP 5 - Read with attack questions (by PRODUCT_TYPE)

Ask a fixed list. Hunt **one wrong assumption at the one moment value moves.**

Universal: who moves the money (every path?); what happens when funds cross
contracts (migration/liquidation/distribution); can a stranger trigger it; can
someone pay less / receive more; external call before state update (reentrancy).

- **launchpad** → graduation/migration into the DEX pool; LP lock; fee split;
  anti-snipe; token transfer restrictions; single-sided vs. raise-holding model.
- **lending/CDP** → oracle (staleness, manipulation, closed-market for equities);
  liquidation math; health factor; LTV; interest; stablecoin peg.
- **vault** → first-depositor / share inflation; rounding direction; donation
  attack; deposit/withdraw accounting.
- **perps** → is it its own engine or a wrapper (wrapper = smaller surface);
  oracle; funding; liquidation; margin accounting.
- **distribution/index** → snapshot weighting; permissionless crank; flash-inflatable
  balance; claim reentrancy; does it even custody funds (no custody = weak target).

---

## STEP 6 - Bug-class detection playbook

Each = the pattern, the detection, the fix.

1. **Migration pool squat (v3).** Graduation calls
   `createAndInitializePoolIfNecessary` and mints with `amount0Min/amount1Min = 0`
   and NO post-init price check. → anyone pre-creates the pool at a fake price
   (needs zero tokens), migration dumps the raise into it. *Detect:* grep for
   `createAndInitializePoolIfNecessary` + missing `slot0()` price check; confirm
   `getPool(token,weth,fee)==0` on a live token. *Dead if* single-sided
   instant-listing (no raise held). *Fix:* read `slot0()`, revert on price mismatch.
2. **Permissionless flash-inflated snapshot (distributions).** Weight = spot
   `balanceOf` at a permissionless snapshot, frozen once captured; token transfers
   fee-free → flash-borrow, get snapshotted, return, still collect. *Detect:*
   snapshot has no access modifier + reads live `balanceOf`; find a fee-free flash
   source (v4 pool `take`/`settle`). Capture ≈ `flashable/(eligible+flashable)`.
   *Fix:* time-weighted/checkpointed balances or Merkle snapshot.
3. **Push-payment DoS.** Handoff/claim pushes ETH to an address that can reject it.
   *Fix:* pull-pattern.
4. **Oracle staleness / closed-market.** Equity collateral prices go stale
   nights/weekends; no buffer-widen/halt → wrong-price borrow/liquidation.
5. **Keeper-trusted fund movement.** `distribute(holders,amounts)` only checks
   `total<=balance` → compromised keeper drains to any address. *Fix:* verify
   amounts on-chain / multisig.
6. **Owner backdoor on live positions.** Admin can swap migrator/oracle/fee on
   already-live positions ("trust owner" not "trust code"). *Fix:* timelock or
   per-position snapshot/freeze.
7. **First-depositor / share inflation (vaults).** Tiny deposit + direct donation
   inflates share price; next depositor rounds to 0 shares. *Fix:* virtual
   shares/dead shares.

Separate **owner-by-design centralization** (trust-risk, lower) from a
**permissionless exploit** (the real Critical). Never claim the former as the latter.

---

## STEP 7 - Fork-prove it (mandatory)

```bash
./tools/step7_poc_scaffold.sh "$RPC" "0x<core>" poc
```
Creates/refreshes a Foundry project, writes the SAFE local-fork-only `test/PoC.t.sol`
skeleton with `TARGET` set, and prints the exact `forge test --fork-url ...` command
(current block from RPC).

Fill `test_exploit()` with the value-moving sequence, then run the printed command:
```bash
cd poc && forge test --fork-url $RPC --fork-block-number $BLK -vv
```

Skeleton shape (already on disk after the tool runs; edit in place):
```solidity
// SAFE, read-only, LOCAL FORK ONLY. Uses test cheatcodes (vm.*) that do nothing on
// a real network, so this can never run as a live attack. No mainnet state touched.
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {Test, console} from "forge-std/Test.sol";
interface ITarget { /* add the exact fns from Step 3 */ }
contract PoC is Test {
    address constant TARGET = 0x<core>;
    address attacker = address(0xA11CE);
    function test_exploit() public {
        // 1. record victim/pot state
        // 2. vm.deal / vm.prank the attacker; execute the value-moving sequence
        // 3. assert the theft/loss in numbers:
        //    assertGt(attackerGain, attackerCost, "net profit"); // or funds stranded
    }
}
```
If a full-scale fork is impractical (thousands of holders on a slow RPC): replicate
the *exact* vulnerable logic from verified source into a self-contained test, and
cite the live on-chain numbers for the real magnitude (the payout is the contract's
own deterministic formula).

---

## STEP 8 - Severity call (honest rubric)

- **Critical** - unauthenticated theft/loss of a large share of funds, or a full
  drain / freeze. One transaction, no special role.
- **High** - unauthenticated, repeatable theft of user funds but **bounded**
  (state the bound), or theft needing a common condition.
- **Medium** - limited/conditional loss, griefing, or bounded value leak.
- **Trust/centralization** - owner-by-design power; disclose, but not a permissionless
  exploit. Label it as such.

Write the number you can defend, with the bound stated. Do not round up.

---

## STEP 9 - Report (fill-in template)

Always use researcher name **deviykee** (never dukedotsol or other handles).
Open every report with a plain-language "What this means" section so a non-technical
reader understands the danger before any code. Do not use em dashes (the long dash
character); use commas, periods, or a normal hyphen instead.

Scaffold the file from INTAKE + your Step 8 call (judgment fields you still fill by hand):
```bash
python3 ./tools/step9_report_skeleton.py \
  --project "<PROJECT_NAME>" \
  --severity "<High/Med/Crit>" \
  --title "<one-line title>" \
  --chain "<CHAIN>" \
  --chain-id "$CID" \
  --core "0x<core>" \
  --bound "<why; state the bound>" \
  --rpc "$RPC" \
  --blk "<BLK>" \
  -o "reports/<project>-<severity>.md"
```
Emits the same report skeleton as below; complete plain-language, root cause, attack,
impact, PoC result, and fix before disclosing.

```markdown
# <PROJECT> - <SEVERITY>: <one-line title>
**Researcher:** deviykee
**Severity:** <High/Med/Crit> - <why; state the bound>
**Status:** Verified on a local fork / read-only on-chain. No mainnet state touched.
**Disclosure:** Private. Live-exploitable now.  <!-- if applicable -->

## What this means in plain language (read this first)
<Explain the danger for non-technical readers: what users thought was safe, what
can go wrong, who loses money, that no admin key is needed if that is true, and
what the bound is. Use a simple analogy if helpful. No em dashes.>

## Affected contracts (<CHAIN>, chainId <CID>)
| Role | Address |
|---|---|
| <core> | 0x... |

## Summary
<the one wrong assumption, plain language>

## Root cause
<exact code quoted>

## Attack
1. ... 2. ... 3. ...

## Impact
Auth: none | Capital: <flash/zero> | Frequency: <once/every cycle> | Victims: <who> | Magnitude: <number/%>

## Proof of concept
`forge test --fork-url <RPC> --fork-block-number <BLK> -vv`  → <result: attacker gained X / Y stranded>

## Fix
<one or more concrete options>

## Disclosure & compensation
Good-faith private disclosure. I'd appreciate a bounty commensurate with a
<severity>. I am NOT conditioning the disclosure or fix on payment act on it now.
Happy to walk the team through it and review the fix.
deviykee
```

---

## STEP 10 - Disclose and get paid

Run this **after** the report file exists. Write the first DM as a separate file
(e.g. `reports/dm-<project>.md`). Do not put full exploit steps in the first DM.

1. **Find the private channel** from X_HANDLE (verified account / security email).
   Never a public thread while it's live.
2. **First message (short):** use the template below. Who you are, plain impact,
   severity + bound, verified how, nothing touched, offer full report + PoC privately.
3. **Share via a PRIVATE repo** (add them as collaborator) or attach files. Never
   public until patched.
   ```bash
   gh repo create <project>-security-disclosure --private --source=. --push   # confirm the RIGHT account first: gh api user --jq .login
   ```
4. **Skepticism is normal.** Point to the reproducible PoC: "run it yourself." Stay
   calm, don't threaten.
5. **Name the number AFTER they confirm.** Anchor on merit (severity + funds at risk
   + clean disclosure + you helped fix). No program = discretionary; plan a fair range.
6. **Help them fix it and review the patch.** This turns one bounty into repeat work.
7. **If they don't pay:** you still won a portfolio piece. After the fix ships, a
   factual timeline post (receipts, no rage, no threats) builds your name. Never
   bundle "pay or I post".

### First DM template (fill after the report; save separately)

Researcher voice: **Iyke** (http://x.com/deviykee). Also sign reports as **deviykee** / Iyke.
No em dashes. Short first message. No full attack runbook. No threats. No "pay or I publish."
Ask who owns the contracts so you get the right inbox. Save as `reports/dm-<project>.md`.

```bash
python3 ./tools/step10_dm_skeleton.py \
  --project "<PROJECT_NAME>" \
  --severity "<SEVERITY>" \
  --chain "<CHAIN>" \
  --component "<one-line component / flow, e.g. graduation flow>" \
  --impact "<one plain sentence: what an attacker can do to user funds>" \
  --scope "<scope, e.g. every un-graduated token>" \
  -o "reports/dm-<project>.md"
```

Filled shape:
```text
Hey <PROJECT_NAME or short product name>.

I'm Iyke, a security researcher. (http://x.com/deviykee)

I've found and verified a <SEVERITY> vulnerability in <PROJECT_NAME>'s <one-line component / flow, e.g. graduation flow> on <CHAIN> that <one plain sentence: what an attacker can do to user funds>. It's live-exploitable right now on <scope, e.g. every un-graduated token>, so it's time-sensitive.

I reproduced it on a <CHAIN> mainnet fork / local Foundry PoC, nothing was touched on-chain<, with N working PoCs if true>.

I want to share the full private write-up with whoever owns the contracts.

Who's the right person, or who do I talk to on the team?
```

Fill map from the report:
- `<PROJECT_NAME>`, `<CHAIN>` from INTAKE
- `<SEVERITY>` must match the report (do not inflate Critical if the report says High)
- One-line flow + attacker outcome from the plain-language section
- Scope/bound honest (per token vs whole protocol)
- PoC method: fork and/or local Foundry; say "nothing was touched on-chain"

Optional second message (after they reply and want details): attach or link the private
report + PoC repo. Still no public post until patched.

---

## Appendix - cheat-sheet

- `cast chain-id | block-number | code | balance | call | storage | 4byte | disassemble | tx`
- `forge test --fork-url $RPC --fork-block-number <BLK> -vv` - the PoC engine
- `anvil --fork-url $RPC --fork-block-number <BLK>` - persistent local fork (caches state)
- Sourcify verified source: `sourcify.dev/server/v2/contract/<CID>/<addr>?fields=sources`
- New chains use **Blockscout**, not Etherscan. `to`-addresses in the app's `eth_call`s = the contracts.
- Vanity CA suffix (e.g. tokens ending in a fixed 2 bytes) = a launchpad fingerprint.
- Playbook tools: see **Tools** table above and `tools/README.md`.

**Reminder:** fork only, honest severity, ask don't threaten, kill your own bad
findings, private until patched, stay token-conservative and route mechanical
work to smaller models. That discipline is the job.

deviykee
