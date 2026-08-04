---
name: duke-web3-bug-hunting
description: >-
  Duke's end-to-end smart-contract bug-hunting playbook (@dukedotsol). Invoke to
  hunt vulnerabilities in an EVM smart contract / DeFi protocol and turn a finding
  into a responsible, paid disclosure. Fill the INTAKE block, then run the steps in
  order — each has exact commands, decision gates, and fill-in templates for the
  PoC, report, and disclosure message. Verification is fork / eth_call ONLY. Never
  exploit mainnet. Use when the user names a target (project, handle, or website)
  and wants it audited for bounties, or says "hunt", "audit this", "find bugs".
---

# Duke's Web3 Bug-Hunting Playbook

By **@dukedotsol**. Fill the INTAKE, then execute the steps top to bottom. Every
step is copy-paste ready. Decision gates tell you exactly what to do next. You
should not have to invent anything — just run it.

---

## INTAKE — fill this in before running

```
PROJECT_NAME   : <e.g. hood.fun>
X_HANDLE       : <e.g. @hooddotfun>          # for finding the private disclosure channel
WEBSITE        : <https://...>               # app URL (where tokens/positions render)
DOCS           : <https://docs... or "none">
CHAIN          : <e.g. Robinhood Chain>
RPC            : <https://... or "unknown">  # confirm in Step 1
CHAIN_ID       : <e.g. 4663 or "unknown">
EXPLORER       : <Blockscout base or "unknown">
KNOWN_ADDRS    : <any contract addrs the user already has, else "none">
PRODUCT_TYPE   : <launchpad | lending/CDP | vault | perps | distribution/index | other | unknown>
BOUNTY/CONTEST : <live program? amount? or "none / discretionary">
NOTES          : <anything the user said: "running a contest", "new today", etc.>
RESEARCHER     : @dukedotsol
```

Set shell vars from the intake and reuse them:
```bash
RPC="<RPC>"; CID="<CHAIN_ID>"; BS="<EXPLORER>/api/v2"
```

---

## Operating rules (non-negotiable — read once, apply always)

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

---

## STEP 1 — Ground truth (is this real, and where)

```bash
cast chain-id --rpc-url $RPC          # must match CHAIN_ID; if RPC unknown, get it from docs/chainlist
cast block-number --rpc-url $RPC      # RPC alive?
```
Gate:
- RPC/chain don't resolve, or no docs/verifiable contract exist → **STOP. Likely
  vaporware/scam.** Report that to the user; do not sink hours.
- Real chain confirmed → continue.

---

## STEP 2 — Locate the core contract(s)

Frontends hide addresses in runtime config. Use these in order until you have an address:

**A. Trace a live token/position → its creator (most reliable).**
```bash
# get a token addr from the app (a /tokens/0x... or /coin/0x... link, or the app's RPC calls)
T=0x<token>
curl -s "$BS/addresses/$T" | python3 -c "import sys,json;print(json.load(sys.stdin).get('creator_address_hash'))"
# the creator is usually the factory/core
```

**B. Grep the app bundle** (Vite: one `/assets/index-*.js`; Next: `/_next/static/chunks/*.js`):
```bash
curl -sL "<WEBSITE>" -o app.html
# Vite:
J=$(grep -oE '/assets/[^"]+\.js' app.html | head -1); curl -s "<WEBSITE>$J" \
 | grep -oiE '(factory|launch|vault|pool|router|oracle|manager|locker)"?:"?0x[a-fA-F0-9]{40}' | sort -u
# Next: fetch all chunks, grep the same
```

**C. Browser** (when config is fetched at runtime): load the app, read the network
requests, and pull the `to` addresses from the `eth_call`s — those are the contracts.

**D. Explorer**: search the chain's Blockscout for the token/contract names
(`qUSD`, `VaultManager`, project name).

---

## STEP 3 — Verification gate + surface map

```bash
C=0x<core>
cast balance $C --rpc-url $RPC                       # funds at risk. ~0 and no downstream value => weak target
cast code $C --rpc-url $RPC | wc -c                  # size => complexity
# verified source? (fast path)
curl -s "https://sourcify.dev/server/v2/contract/$CID/$C?fields=sources,compilation" -o src.json
python3 -c "import json;d=json.load(open('src.json'));print(d.get('match'), (d.get('compilation') or {}).get('name'))"
```
Gate:
- **Verified** → pull the source files from `src.json` and read them (30-min path).
- **Unverified** → map selectors from bytecode + tx history:
```bash
cast code $C --rpc-url $RPC > code.hex
cast disassemble $(cat code.hex) \
 | awk '/PUSH4 0x/{s=$0;h=NR} /EQ/&&(NR-h<=2){print s}' | grep -Eo '0x[0-9a-fA-F]{8}' | sort -u \
 | while read x; do printf "%s %s\n" "$x" "$(cast 4byte $x|head -1)"; done
# recover non-standard selectors from real tx history:
curl -s "$BS/addresses/$C/transactions" | python3 -c "import sys,json;from collections import Counter;d=json.load(sys.stdin);c=Counter((t.get('raw_input') or '0x')[:10] for t in d.get('items',[]));print(c.most_common(10))"
```

---

## STEP 4 — Auth triage (find the free win first)

`eth_call` every state-changing admin/keeper function from an attacker address. If
it does NOT revert, the access control is missing = likely Critical.
```bash
ATK=0x000000000000000000000000000000000000dEaD
for sig in "setOwner(address)" "setKeeper(address)" "setOracle(address)" "setFee(uint256)" "mint(address,uint256)" "withdraw(uint256)"; do
  printf "%-28s " "$sig"
  out=$(cast call $C "$sig" $ATK --from $ATK --rpc-url $RPC 2>&1)
  echo "$out" | grep -qi "revert\|error" && echo "guarded" || echo "OPEN <-- CHECK"
done
# control: same call from the real owner should behave differently (confirms it's an auth revert, not a generic one)
```

---

## STEP 5 — Read with attack questions (by PRODUCT_TYPE)

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

## STEP 6 — Bug-class detection playbook

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

## STEP 7 — Fork-prove it (mandatory)

```bash
mkdir -p poc && cd poc && forge init --no-git . 2>/dev/null; rm -f src/Counter.sol test/*.sol
```
Drop in a test using this skeleton, then:
```bash
BLK=$(cast block-number --rpc-url $RPC)
forge test --fork-url $RPC --fork-block-number $BLK -vv
```

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

## STEP 8 — Severity call (honest rubric)

- **Critical** — unauthenticated theft/loss of a large share of funds, or a full
  drain / freeze. One transaction, no special role.
- **High** — unauthenticated, repeatable theft of user funds but **bounded**
  (state the bound), or theft needing a common condition.
- **Medium** — limited/conditional loss, griefing, or bounded value leak.
- **Trust/centralization** — owner-by-design power; disclose, but not a permissionless
  exploit. Label it as such.

Write the number you can defend, with the bound stated. Do not round up.

---

## STEP 9 — Report (fill-in template)

```markdown
# <PROJECT> — <SEVERITY>: <one-line title>
**Researcher:** @dukedotsol
**Severity:** <High/Med/Crit> — <why; state the bound>
**Status:** Verified on a local fork / read-only on-chain. No mainnet state touched.
**Disclosure:** Private. Live-exploitable now.  <!-- if applicable -->

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
<severity>. I am NOT conditioning the disclosure or fix on payment — act on it now.
Happy to walk the team through it and review the fix.
— @dukedotsol
```

---

## STEP 10 — Disclose and get paid

1. **Find the private channel** from X_HANDLE (verified account / security email).
   Never a public thread while it's live.
2. **First message (short):** who you are, one-line impact, "verified on a fork,
   nothing touched, PoC you can run." Then send the report + PoC.
3. **Share via a PRIVATE repo** (add them as collaborator) or attach files. Never
   public until patched.
   ```bash
   gh repo create <project>-security-disclosure --private --source=. --push   # confirm the RIGHT account first: gh api user --jq .login
   ```
4. **Skepticism is normal.** Point to the reproducible PoC — "run it yourself." Stay
   calm, don't threaten.
5. **Name the number AFTER they confirm.** Anchor on merit (severity + funds at risk
   + clean disclosure + you helped fix). No program = discretionary; plan a fair range.
6. **Help them fix it and review the patch.** This turns one bounty into repeat work.
7. **If they don't pay:** you still won a portfolio piece. After the fix ships, a
   factual timeline post (receipts, no rage, no threats) builds your name. Never
   bundle "pay or I post".

---

## Appendix — cheat-sheet

- `cast chain-id | block-number | code | balance | call | storage | 4byte | disassemble | tx`
- `forge test --fork-url $RPC --fork-block-number <BLK> -vv` — the PoC engine
- `anvil --fork-url $RPC --fork-block-number <BLK>` — persistent local fork (caches state)
- Sourcify verified source: `sourcify.dev/server/v2/contract/<CID>/<addr>?fields=sources`
- New chains use **Blockscout**, not Etherscan. `to`-addresses in the app's `eth_call`s = the contracts.
- Vanity CA suffix (e.g. tokens ending in a fixed 2 bytes) = a launchpad fingerprint.

**Reminder:** fork only, honest severity, ask don't threaten, kill your own bad
findings, private until patched. That discipline is the job.

— @dukedotsol

---
---

# PART 2 — AI AUDIT TOOL STACK (integrated)

All free, on GitHub, built by working auditors. Use these to power the steps above. Verify each repo before running untrusted code. Clone under `bounty-hunt-tracker/tools/`.

## Where each tool plugs into the playbook

| Playbook step | Tool | What it does here |
|---|---|---|
| Step 2-3 (locate + map) | **pashov/x-ray** | Builds the threat model, invariants, and entry points before you read a line |
| Step 3-5 (read) | **pashov/solidity-auditor** | Sub-5-min security feedback on the target / on your diff |
| Step 5 (breadth) | **Archethect/sc-auditor** | 6 parallel specialists (reentrancy, accounting, oracle, economic...) + Devil's Advocate kills weak findings |
| Step 5-6 (depth) | **0xiehnnkta/nemesis-auditor** | Feynman (why does this line exist) + coupled-state hunt on the value-holding contract |
| Step 6 (pattern-match) | **marchev/claudit** | MCP into Solodit's 20k+ findings — pull the exact precedent for a suspicious mechanism |
| Step 6-7 (heavy, paid) | **PlamenTSV/plamen** | 20-100 autonomous agents, fuzzes invariants, PoC-gated, judge kills false positives. $30-100+/run. EVM/Solana/Move/L1 |
| Step 7 (package) | **cholakovvv/foundry-poc-mainnet-fork** | Turns the finding into a submission-ready mainnet-fork PoC — real addresses, no mocks, no `vm.store` cheats |

## The 6 tools

1. **[pashov/skills](https://github.com/pashov/skills)** (@pashovkrum) — `solidity-auditor` (fast diff security feedback) + `x-ray` (pre-audit scan: threat model, invariants, entry points). Run `x-ray` FIRST on any new target.
2. **[marchev/claudit](https://github.com/marchev/claudit)** (@MartinMarchev) — MCP plugging Solodit's 20,000+ findings into Claude. Describe the bug class, it pulls the exact reports.
3. **[PlamenTSV/plamen](https://github.com/PlamenTSV/plamen)** (@p_tsanev) — autonomous audit agent, 20-100 agents, only reports PoC-verified bugs, judge stage kills false positives. Paid ($30-100+). Heavy artillery for high-value targets.
4. **[cholakovvv/foundry-poc-mainnet-fork](https://github.com/cholakovvv/foundry-poc-mainnet-fork)** (@cholakovvv) — finding → submission-ready Foundry mainnet-fork PoC. Real deployed addresses, no mocks.
5. **[Archethect/sc-auditor](https://github.com/Archethect/sc-auditor)** (@archethect) — Map, Hunt, Attack. 6 parallel specialist agents, then a Devil's Advocate that tries to kill each finding.
6. **[0xiehnnkta/nemesis-auditor](https://github.com/0xiehnnkta/nemesis-auditor)** (@0xiehnnkta) — Feynman auditor (questions WHY every line) + state auditor (coupled state updated on one side only), looped until nothing new surfaces. Closest to a human.

> **Gap: no dedicated invariants tool yet.** Slot in one of: Foundry `invariant` testing, Echidna, Medusa, Halmos (symbolic), Certora (formal).

## Suggested chain (map → package)
1. **Map** — `x-ray` → entry points + invariants + threat model.
2. **Breadth** — `sc-auditor` → 6 specialists, Devil's Advocate trims.
3. **Depth** — `nemesis-auditor` on the value-holding contract.
4. **Pattern-match** — `claudit` → Solodit precedent for anything suspicious.
5. **Heavy (optional, paid)** — `plamen` on high-value targets.
6. **Package** — `foundry-poc-mainnet-fork` → submission-ready PoC.
7. **Disclose** — Step 10 above (private repo + private channel, honest severity, help fix).

## Workflow / productivity skills
- **Matt Pocock skills** (@mattpocockuk): `/grill-me` (agent grills you until the task's gaps are clear — 80+ questions), then `/to-issues` → **goal mode**. Explicitly tell it to spawn a subagent per task, test the work when done, and redo if not actually done. Multi-hour runs.
- **[obra/Superpowers](https://github.com/obra/Superpowers)** — broader Claude capability pack.

## Methodology reference
- **wadgamaraldeen — Bug Hunting Methodology**: [My Bug Hunting Methodology.md](https://github.com/wadgamaraldeen/My-Hunting-Methodology-/blob/main/My%20Bug%20Hunting%20Methodology.md) (dated in parts, still useful for AI prompts).

## Writing style — strip AI-slop from reports/messages/posts
Cut these tells: "Real talk", "Not...Not...Not...", "It's not just X. It's Y.", "This isn't about X. It's about Y.", "But here's the thing.", "The truth is.../The reality is...", "What people don't realize is...", "What makes this interesting is...", "Let's break it down.", "Here's the catch.", "Think about it.", "With that being said...", "This raises the question...", "This underscores...", "The bigger picture...". No em dashes as a crutch, no emoji in professional reports.

— @dukedotsol
