# Security Research

A private collection of tools, scripts, notes, and proof-of-concept work for **Web3 / smart-contract security research**. This repo organizes hunt workflows, target notes, vendor skill packs, and Foundry PoCs used during authorized audits and bug bounty research.

It is meant as a personal research workspace—not a production security product. Contents range from recon scripts and report skeletons to Solidity PoCs and third-party methodology references.

## Folder structure

| Path | Contents |
|------|----------|
| `scripts/` | Hunt workflow scripts (recon, surface mapping, report/DM skeletons, selftests) |
| `config/` | Env templates and config notes (`.env.example`) |
| `docs/` | Methodology docs and bug-hunting skill playbooks (`docs/skills/`) |
| `src/` | Source / PoC projects (e.g. `src/theindex/` Foundry project) |
| `hunts/` | Per-target hunt workspaces (notes, sources, local PoCs) |
| `reports/` | Hunt notes, high-severity writeups, and outreach DM drafts |
| `targets/` | Target lists and scoring notes |
| `sessions/` | Dated research session bundles |
| `vendor/` | Third-party audit skills and methodology packs (vendored copies) |

## Setup

### Prerequisites

- **Git**
- **Python 3** (for report/DM skeleton scripts)
- **bash** / standard Unix tools (`curl`, `jq` useful for recon scripts)
- **[Foundry](https://book.getfoundry.sh/getting-started/installation)** (`forge`, `cast`) for Solidity PoCs

### Clone

```bash
git clone git@github.com:devIykee/security-research.git
cd security-research
```

### Environment

```bash
cp config/.env.example .env
# edit .env with your RPC URLs and API keys
```

### Scripts

```bash
# optional self-check for hunt scripts
bash scripts/selftest.sh

# example: generate a report skeleton
python3 scripts/step9-report-skeleton.py --help 2>/dev/null || python3 scripts/step9-report-skeleton.py
```

### Foundry PoC example (`src/theindex`)

```bash
cd src/theindex
# forge install if lib is missing
forge test
```

Per-hunt PoCs under `hunts/*/poc` follow the same pattern.

### Vendor tools

Some packages under `vendor/` (e.g. `sc-auditor`) are Node-based:

```bash
cd vendor/sc-auditor
npm install   # if package.json present
```

See each vendor folder’s own README for details.

## Env & secrets

- Put secrets in a **`.env`** file at the repo root (or as documented by a subproject).
- **Never commit** `.env`, private keys, API tokens, or wallet seed phrases.
- Use `config/.env.example` as a safe template only.
- `.gitignore` excludes env files, Python/Node artifacts, Foundry `out/`/`cache/`, and common secret patterns.

## Disclaimer

**This repository is for educational and authorized security research only.**

Do not use these materials to attack systems you do not own or lack explicit permission to test. Bug bounty and audit work must follow the program’s scope and rules. The authors assume no liability for misuse.

## Contributing

This is a private research repo. If you have collaborator access:

1. Work on a feature branch; open a PR into `main`.
2. Keep secrets out of commits; scrub RPC keys and private keys from notes before pushing.
3. Prefer lowercase-with-dashes for new markdown/script filenames (Solidity names may keep PascalCase).
4. Place new scripts in `scripts/`, docs in `docs/`, PoC source under `src/` or the relevant `hunts/<target>/`, and reports in `reports/`.
5. Update this README if you add a major top-level folder.

## License

Private — all rights reserved unless otherwise noted in vendored subfolders (which retain their upstream licenses).
