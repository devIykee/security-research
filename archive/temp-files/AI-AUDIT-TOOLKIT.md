# AI Audit Toolkit

A reusable reference of AI-powered smart-contract audit tools, workflow skills, and methodology. All the audit tools below are free, on GitHub, and built by working auditors. Curated for @dukedotsol's web3 bug-hunting workflow.

---

## 1. Audit tool stack

| # | Tool | Author | One-liner | Cost |
|---|------|--------|-----------|------|
| 1 | [pashov/skills](https://github.com/pashov/skills) | @pashovkrum | Fast, cheap Claude skills for security feedback + pre-audit scan | Free |
| 2 | [marchev/claudit](https://github.com/marchev/claudit) | @MartinMarchev | MCP that plugs Solodit's 20k+ findings into Claude | Free |
| 3 | [PlamenTSV/plamen](https://github.com/PlamenTSV/plamen) | @p_tsanev | Autonomous audit agent, 20-100 agents, PoC-verified findings | $30-100+/run |
| 4 | [cholakovvv/foundry-poc-mainnet-fork](https://github.com/cholakovvv/foundry-poc-mainnet-fork) | @cholakovvv | Turns a finding into a submission-ready mainnet-fork Foundry PoC | Free |
| 5 | [Archethect/sc-auditor](https://github.com/Archethect/sc-auditor) | @archethect | 6 parallel specialist agents + Devil's Advocate to kill false positives | Free |
| 6 | [0xiehnnkta/nemesis-auditor](https://github.com/0xiehnnkta/nemesis-auditor) | @0xiehnnkta | Feynman + state-coupling auditor loop, closest to a human auditor | Free |

### 1. Pashov skills — `pashov/skills`
Two skills, fast and efficient:
- **`solidity-auditor`** — security feedback on your changes in under 5 minutes.
- **`x-ray`** — pre-audit scan that builds a threat model, invariants, and entry points.

Best as the **first pass** on any new codebase: run `x-ray` to get the map (entry points + invariants + threat model), then `solidity-auditor` on the diff.

### 2. Claudit — `marchev/claudit`
An MCP server that connects **Solodit's 20,000+ audit findings** directly into Claude. Describe the bug class you are hunting and it pulls the exact matching historical reports.

Use it to **pattern-match**: once you spot a suspicious mechanism, ask Claudit for prior findings of that shape (e.g. "permissionless snapshot flash-inflation", "minOut=0 sandwich", "first-depositor share inflation") and copy the proven attack path.

### 3. Plamen — `PlamenTSV/plamen`
A fully autonomous audit agent that spins up **20-100 agents**, fuzzes invariants, and only reports bugs that come with a **verified PoC**. A judge stage kills false positives.
- Cost: $30-100+ for a thorough run.
- Supports **EVM, Solana, Move, and L1s**.

Use it as the **heavy artillery** on a high-value target where a paid deep run is worth it. Its PoC-gate + judge means low noise.

### 4. foundry-poc-mainnet-fork — `cholakovvv/foundry-poc-mainnet-fork`
Turns a raw finding into a **submission-ready Foundry PoC on a mainnet fork**: real deployed addresses, no mocks, no `vm.store` cheats.

This is the **packaging step** — exactly the workflow that fork-proved the Ratchet finding. Once a bug is suspected, this produces the clean, reviewer-reproducible artifact.

### 5. sc-auditor — `Archethect/sc-auditor`
**Map, Hunt, Attack.** Six specialized agents hunt in parallel (reentrancy, accounting, oracle, economic, ...), then every finding runs through a **Devil's Advocate** that tries to kill it before it reaches you.

Good **breadth pass**: parallel specialists cover more ground than a single linear read, and the Devil's Advocate stage does what discipline requires — try to break your own finding before believing it.

### 6. Nemesis — `0xiehnnkta/nemesis-auditor`
Two agents in a loop:
- **Feynman auditor** — questions WHY every line exists.
- **State auditor** — hunts for coupled state that updates on one side only.

Each pass feeds the next until nothing new surfaces. Described as the closest to how a human actually audits.

Use it as the **depth pass** on the one contract that holds the value — the coupled-state check (something incremented but never decremented, or updated in `deposit` but not `withdraw`) is where accounting drains hide.

> **Gap: no dedicated invariants tool yet.** Candidates to slot in later: Foundry `invariant` testing, Echidna, Medusa, Halmos (symbolic), Certora (formal). TODO: pick and add one.

---

## 2. Suggested pipeline (how to chain them)

1. **Map** — `pashov/x-ray` builds entry points + invariants + threat model.
2. **Breadth** — `sc-auditor` runs the 6 parallel specialists; Devil's Advocate trims.
3. **Depth** — `nemesis-auditor` on the value-holding contract for coupled-state / why-does-this-exist bugs.
4. **Pattern-match** — `claudit` pulls Solodit precedents for any suspicious mechanism.
5. **Heavy run** (optional, paid) — `plamen` on high-value targets, PoC-gated.
6. **Package** — `foundry-poc-mainnet-fork` turns the confirmed bug into a submission-ready fork PoC.
7. **Disclose** — private repo + private channel, honest severity, help fix. (See methodology below.)

---

## 3. Workflow / productivity skills

### Matt Pocock skills (@mattpocockuk)
- **`/grill-me`** — start with a broad, messy task; the agent keeps asking questions until the gaps are clear. Answering the questions forces you to actually understand the task and surface the details you skipped. Runs can go 80+ questions deep.
- **`/to-issues`** — turn the grilled task into concrete issues, then kick them off in **goal mode**.
  - Explicitly instruct it to: **spawn a subagent per task**, **test the work when finished**, and **redo it if it is not actually done**.
  - Runs go for hours; kick one off and work another session in parallel.

### Superpowers (@obra)
- [github.com/obra/Superpowers](https://github.com/obra/Superpowers) — a broader Claude skill/capability pack. Add to the stack.

---

## 4. Methodology reference

- **wadgamaraldeen — Bug Hunting Methodology** (~2 years old, some parts dated but still practical for AI prompts):
  [My Bug Hunting Methodology.md](https://github.com/wadgamaraldeen/My-Hunting-Methodology-/blob/main/My%20Bug%20Hunting%20Methodology.md)

### Duke's proven disclosure loop (already paying)
Find → **fork-prove (never touch mainnet)** → honest report → private disclosure → ask fair → help fix.
Full playbook: `bounty-hunt-tracker/duke-web3-bughunting/SKILL.md`.

---

## 5. Writing style — AI-slop words to strip

Tells that out someone using AI to write. Strip these from reports, disclosure messages, and posts:

- "Real talk"
- "Not... Not... Not..."
- "It's not just X. It's Y."
- "This isn't about X. It's about Y."
- "But here's the thing."
- "The truth is..." / "The reality is..."
- "What people don't realize is..."
- "What makes this interesting is..."
- "Let's break it down." / "Let's talk about..."
- "Here's the catch."
- "Think about it."
- "With that being said..."
- "This raises the question..."
- "This underscores..."
- "The bigger picture..."

Also avoid: em dashes as a stylistic crutch, and emoji in professional reports.

---

*Sources: audit-tools thread + follow-ups (July 2026). Links normalized to https. Verify each repo before running untrusted code.*
