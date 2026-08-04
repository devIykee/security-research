# Bug-hunt playbook tools

Mechanical helpers for **Iyke's Web3 Bughunt Skill** (`iykes-web3-bughunt-skill`).
Judgment (severity, root cause, disclosure strategy) stays in `docs/skills/iykes-web3-bughunt-skill.md`. These
scripts only run the repeatable shell/python steps.

## Prerequisites

```bash
# Foundry (forge + cast)
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Python 3 (stdlib only for the fillers)
# Debian/Ubuntu: sudo apt-get install -y python3
# macOS: brew install python3

# curl (usually preinstalled)
# gh is optional (only for Step 10 private disclosure repo creation)
# jq is optional (not required by these scripts)
```

Make scripts executable once:

```bash
chmod +x scripts/*.sh scripts/*.py
```

Optional: `CAST_TIMEOUT` (seconds, default 15–20) for cast wrappers that use `timeout(1)`.

Smoke-check graceful failures:

```bash
./scripts/selftest.sh
```

## Scripts

### `step1-ground-truth.sh` — Step 1

**Purpose:** Confirm RPC alive and chain id matches intake.

**Usage:** `step1-ground-truth.sh <RPC_URL> <EXPECTED_CHAIN_ID>`

**Example:**
```bash
./scripts/step1-ground-truth.sh "https://rpc.example.chain" "4663"
```

**Prints:** chain-id, block-number, GATE PASS/FAIL.

**Exit:** `0` pass · `1` RPC error or chain mismatch · `2` usage

---

### `step2-creator-trace.sh` — Step 2A

**Purpose:** Trace token/position → creator (factory/core candidate) via Blockscout API.

**Usage:** `step2-creator-trace.sh <EXPLORER_API_V2_BASE> <TOKEN_OR_POSITION_ADDR>`

**Example:**
```bash
./scripts/step2-creator-trace.sh "https://explorer.example/api/v2" \
  "0x1111111111111111111111111111111111111111"
```

**Prints:** `token`, `creator`, GATE line.

**Exit:** `0` creator found · `1` HTTP/JSON error · `2` usage

---

### `step2-bundle-grep.sh` — Step 2B

**Purpose:** Grep Vite/Next JS bundles for role-labeled `0x` addresses.

**Usage:** `step2-bundle-grep.sh <WEBSITE_URL>`

**Example:**
```bash
./scripts/step2-bundle-grep.sh "https://app.example"
```

**Prints:** matching role/address lines or empty-grep GATE.

**Exit:** `0` HTML fetched (hits optional) · `1` fetch failed · `2` usage

---

### `step3-surface-map.sh` — Step 3

**Purpose:** Balance, code size, Sourcify verification, bytecode/tx selectors.

**Usage:** `step3-surface-map.sh <RPC_URL> <CHAIN_ID> <CONTRACT_ADDR> [EXPLORER_API_V2_BASE]`

**Example:**
```bash
./scripts/step3-surface-map.sh "https://rpc.example.chain" "4663" \
  "0x2222222222222222222222222222222222222222" \
  "https://explorer.example/api/v2"
```

**Prints:** balance, code size, Sourcify match; may write `src.json`, `code.hex`, selector list.

**Exit:** `0` mapped · `1` hard RPC fail or no code · `2` usage

---

### `step4-auth-triage.sh` — Step 4

**Purpose:** `eth_call` admin/keeper sigs from attacker; flag `OPEN <-- CHECK`.

**Usage:** `step4-auth-triage.sh <RPC_URL> <CONTRACT_ADDR> [extra_sig ...]`

**Example:**
```bash
./scripts/step4-auth-triage.sh "https://rpc.example.chain" \
  "0x2222222222222222222222222222222222222222" "setMigrator(address)"
```

**Prints:** per-sig `guarded` or `OPEN <-- CHECK`.

**Exit:** `0` triage done (OPEN is still 0) · `1` RPC failure · `2` usage

---

### `step7-poc-scaffold.sh` — Step 7

**Purpose:** Foundry PoC scaffold + SAFE fork-only skeleton; print `forge test` cmd.

**Usage:** `step7-poc-scaffold.sh <RPC_URL> <TARGET_ADDR> [POC_DIR]`

**Example:**
```bash
./scripts/step7-poc-scaffold.sh "https://rpc.example.chain" \
  "0x2222222222222222222222222222222222222222" "poc"
```

**Prints:** path to `test/PoC.t.sol`, fork block, exact `forge test --fork-url ...` command.

**Exit:** `0` scaffold ready · `1` forge/cast missing or RPC fail · `2` usage

---

### `step9-report-skeleton.py` — Step 9

**Purpose:** Fill report markdown skeleton (researcher deviykee). No severity judgment.

**Usage:**
```text
step9-report-skeleton.py --project P --severity S --title T --chain C --chain-id ID
  [--core ADDR] [--bound TEXT] [--rpc URL] [--blk N] [-o PATH]
```

**Example:**
```bash
python3 ./scripts/step9-report-skeleton.py \
  --project "example.fun" --severity High --title "one-line title" \
  --chain "Example Chain" --chain-id 4663 \
  --core 0x2222222222222222222222222222222222222222 \
  --bound "state the bound" -o reports/example-high.md
```

**Prints:** report markdown to stdout or `-o`.

**Exit:** `0` written · `2` missing required args / `--help`

---

### `step10-dm-skeleton.py` — Step 10

**Purpose:** Fill first private DM text (voice: Iyke / deviykee). No strategy judgment.

**Usage:**
```text
step10-dm-skeleton.py --project P --severity S --chain C --component FLOW --impact SENTENCE
  [--scope BOUND] [-o PATH]
```

**Example:**
```bash
python3 ./scripts/step10-dm-skeleton.py \
  --project "example.fun" --severity High --chain "Example Chain" \
  --component "graduation flow" \
  --impact "an attacker can drain the raise into a fake-priced pool" \
  --scope "every un-graduated token" \
  -o reports/dm-example.md
```

**Prints:** DM text to stdout or `-o`.

**Exit:** `0` written · `2` missing required args / `--help`

---

### `selftest.sh`

**Purpose:** Confirm every script fails gracefully on missing args / prints usage.

**Usage:** `./scripts/selftest.sh`

**Exit:** `0` all OK · `1` hang, cryptic crash, or wrong exit

---

## Summary table

| Script | Step | Inputs | Outputs / gates | Why this exists |
|---|---|---|---|---|
| `step1-ground-truth.sh` | 1 | RPC, chain id | PASS/STOP on chain | Avoid hours on dead/scam RPCs |
| `step2-creator-trace.sh` | 2A | explorer API, token | creator address | Reliable factory/core discovery |
| `step2-bundle-grep.sh` | 2B | website URL | role-labeled 0x hits | Find hidden frontend config addrs |
| `step3-surface-map.sh` | 3 | RPC, chain, contract, [API] | balance, Sourcify, selectors | Verified vs unverified path |
| `step4-auth-triage.sh` | 4 | RPC, contract, [sigs] | guarded / OPEN | Free-win missing-auth check |
| `step7-poc-scaffold.sh` | 7 | RPC, target, [dir] | Foundry PoC + forge cmd | Repeatable fork-only proof setup |
| `step9-report-skeleton.py` | 9 | INTAKE + severity fields | report markdown | Same report shape every hunt |
| `step10-dm-skeleton.py` | 10 | project/severity/impact | first DM text | Consistent private first contact |
| `selftest.sh` | — | none | pass/fail per script | CI-style smoke for tools |

**Reminder:** fork / `eth_call` only. Never exploit mainnet. Honest severity. Private until patched.
