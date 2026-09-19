#!/usr/bin/env python3
# =============================================================================
# step9_report_skeleton.py
#
# Purpose:
#   Fill the Step 9 report markdown skeleton from INTAKE + severity fields.
#   Mechanical only — does not judge severity or invent root cause.
#
# Usage:
#   step9_report_skeleton.py --project PROJECT --severity SEVERITY --title TITLE
#       --chain CHAIN --chain-id CHAIN_ID [options] [-o PATH]
#
# Args (required):
#   --project     PROJECT_NAME from INTAKE
#   --severity    Critical|High|Medium|Trust (already decided in Step 8)
#   --title       One-line title after severity
#   --chain       CHAIN from INTAKE
#   --chain-id    CHAIN_ID from INTAKE
#
# Example:
#   python3 ./tools/step9_report_skeleton.py \
#     --project "example.fun" --severity High --title "pool squat on graduation" \
#     --chain "Example Chain" --chain-id 4663 \
#     --core 0x2222222222222222222222222222222222222222 \
#     --bound "per un-graduated token raise" \
#     -o reports/example-high.md
#
# Exit codes:
#   0  skeleton written (stdout or -o)
#   2  argparse usage / missing required args
# =============================================================================
"""STEP 9 - Fill the report markdown skeleton from INTAKE + severity fields.

Mechanical template filler only. Does not judge severity or invent root cause.
Judgment fields stay as placeholders or pass-through args you already decided.
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path


def main() -> int:
    p = argparse.ArgumentParser(
        description="Fill Step 9 report skeleton (researcher: deviykee).",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  step9_report_skeleton.py \\
    --project example.fun --severity High --title "pool squat on graduation" \\
    --chain "Example Chain" --chain-id 4663 \\
    --core 0x2222222222222222222222222222222222222222 \\
    --bound "per un-graduated token raise" \\
    -o reports/example-high.md
""",
    )
    p.add_argument("--project", required=True, help="PROJECT_NAME from INTAKE")
    p.add_argument("--severity", required=True, help="Critical|High|Medium|Trust (already decided)")
    p.add_argument("--title", required=True, help="One-line title after severity")
    p.add_argument("--chain", required=True, help="CHAIN from INTAKE")
    p.add_argument("--chain-id", required=True, dest="chain_id", help="CHAIN_ID from INTAKE")
    p.add_argument("--core", default="", help="Core contract address (optional)")
    p.add_argument("--core-role", default="core", help="Role label for core row (default: core)")
    p.add_argument("--bound", default="", help="Severity bound sentence fragment")
    p.add_argument("--rpc", default="<RPC>", help="RPC URL for PoC command line")
    p.add_argument("--blk", default="<BLK>", help="Fork block number for PoC command")
    p.add_argument("--root-cause", default="<exact code quoted>", help="Optional root-cause quote")
    p.add_argument(
        "--plain",
        default=(
            "<Explain the danger for non-technical readers: what users thought was safe, what "
            "can go wrong, who loses money, that no admin key is needed if that is true, and "
            "what the bound is. Use a simple analogy if helpful. No em dashes.>"
        ),
        help="Plain-language section body",
    )
    p.add_argument("--summary", default="<the one wrong assumption, plain language>")
    p.add_argument("--attack", default="1. ... 2. ... 3. ...")
    p.add_argument(
        "--impact",
        default="Auth: none | Capital: <flash/zero> | Frequency: <once/every cycle> | Victims: <who> | Magnitude: <number/%>",
    )
    p.add_argument("--poc-result", default="<result: attacker gained X / Y stranded>")
    p.add_argument("--fix", default="<one or more concrete options>")
    p.add_argument("-o", "--output", default="-", help="Output path or - for stdout")
    args = p.parse_args()

    sev_line = args.severity
    if args.bound:
        sev_line = f"{args.severity} - {args.bound}"

    core_row = f"| {args.core_role} | {args.core} |" if args.core else "| <core> | 0x... |"

    body = f"""# {args.project} - {args.severity}: {args.title}
**Researcher:** deviykee
**Severity:** {sev_line}
**Status:** Verified on a local fork / read-only on-chain. No mainnet state touched.
**Disclosure:** Private. Live-exploitable now.  <!-- if applicable -->

## What this means in plain language (read this first)
{args.plain}

## Affected contracts ({args.chain}, chainId {args.chain_id})
| Role | Address |
|---|---|
{core_row}

## Summary
{args.summary}

## Root cause
{args.root_cause}

## Attack
{args.attack}

## Impact
{args.impact}

## Proof of concept
`forge test --fork-url {args.rpc} --fork-block-number {args.blk} -vv`  → {args.poc_result}

## Fix
{args.fix}

## Disclosure & compensation
Good-faith private disclosure. I'd appreciate a bounty commensurate with a
{args.severity}. I am NOT conditioning the disclosure or fix on payment act on it now.
Happy to walk the team through it and review the fix.
deviykee
"""

    if args.output == "-":
        sys.stdout.write(body)
    else:
        out = Path(args.output)
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(body, encoding="utf-8")
        print(f"wrote {out}", file=sys.stderr)
    print(
        "GATE: report skeleton filled — complete judgment sections, then open Step 10 DM.",
        file=sys.stderr,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
