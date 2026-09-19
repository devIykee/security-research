#!/usr/bin/env python3
# =============================================================================
# step10_dm_skeleton.py
#
# Purpose:
#   Fill the Step 10 first private DM template from INTAKE + report fields.
#   Mechanical only. Severity must already match the report (do not inflate).
#
# Usage:
#   step10_dm_skeleton.py --project PROJECT --severity SEVERITY --chain CHAIN
#       --component COMPONENT --impact IMPACT [--scope SCOPE] [-o PATH]
#
# Args (required):
#   --project     PROJECT_NAME from INTAKE
#   --severity    Must match the report severity
#   --chain       CHAIN from INTAKE
#   --component   One-line component/flow (e.g. graduation flow)
#   --impact      One plain sentence: what an attacker can do to user funds
#
# Example:
#   python3 ./tools/step10_dm_skeleton.py \
#     --project "example.fun" --severity High --chain "Example Chain" \
#     --component "graduation flow" \
#     --impact "an attacker can drain the raise into a fake-priced pool" \
#     --scope "every un-graduated token" \
#     -o reports/dm-example.md
#
# Exit codes:
#   0  DM text written (stdout or -o)
#   2  argparse usage / missing required args
# =============================================================================
"""STEP 10 - Fill the first private DM template from INTAKE + report fields.

Mechanical only. Severity must already match the report (do not inflate).
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


def main() -> int:
    p = argparse.ArgumentParser(
        description="Fill Step 10 first-DM skeleton (voice: Iyke / deviykee).",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  step10_dm_skeleton.py \\
    --project example.fun --severity High --chain "Example Chain" \\
    --component "graduation flow" \\
    --impact "an attacker can drain the raise into a fake-priced pool" \\
    --scope "every un-graduated token" \\
    -o reports/dm-example.md
""",
    )
    p.add_argument("--project", required=True, help="PROJECT_NAME from INTAKE")
    p.add_argument("--severity", required=True, help="Must match the report severity")
    p.add_argument("--chain", required=True, help="CHAIN from INTAKE")
    p.add_argument(
        "--component",
        required=True,
        help="One-line component/flow (e.g. graduation flow)",
    )
    p.add_argument(
        "--impact",
        required=True,
        help="One plain sentence: what an attacker can do to user funds",
    )
    p.add_argument(
        "--scope",
        default="the affected contracts",
        help="Honest scope/bound (e.g. every un-graduated token)",
    )
    p.add_argument(
        "--poc-note",
        default="",
        help="Optional clause after 'on-chain', e.g. ', with 2 working PoCs'",
    )
    p.add_argument(
        "--greeting-name",
        default="",
        help="How to greet (default: project name)",
    )
    p.add_argument("-o", "--output", default="-", help="Output path or - for stdout")
    args = p.parse_args()

    greet = args.greeting_name or args.project
    poc_extra = args.poc_note
    if poc_extra and not poc_extra.startswith(","):
        poc_extra = ", " + poc_extra

    def clean(s: str) -> str:
        return s.replace("\u2014", "-").replace("\u2013", "-")

    body = f"""Hey {clean(greet)}.

I'm Iyke, a security researcher. (http://x.com/deviykee)

I've found and verified a {clean(args.severity)} vulnerability in {clean(args.project)}'s {clean(args.component)} on {clean(args.chain)} that {clean(args.impact)}. It's live-exploitable right now on {clean(args.scope)}, so it's time-sensitive.

I reproduced it on a {clean(args.chain)} mainnet fork / local Foundry PoC, nothing was touched on-chain{clean(poc_extra)}.

I want to share the full private write-up with whoever owns the contracts.

Who's the right person, or who do I talk to on the team?
"""

    if args.output == "-":
        sys.stdout.write(body)
    else:
        out = Path(args.output)
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(body, encoding="utf-8")
        print(f"wrote {out}", file=sys.stderr)
        slug = re.sub(r"[^a-z0-9]+", "", args.project.lower())
        if slug and f"dm-" not in out.name.lower():
            print(
                f"note: playbook suggests reports/dm-<project>.md (got {out.name})",
                file=sys.stderr,
            )
    print(
        "GATE: first DM drafted — send on private channel only; no full exploit steps.",
        file=sys.stderr,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
