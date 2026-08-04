#!/usr/bin/env bash
# =============================================================================
# step2_creator_trace.sh
#
# Purpose:
#   Trace a live token/position to its creator (usually factory/core) via
#   Blockscout-style API (playbook Step 2A).
#
# Usage:
#   step2_creator_trace.sh <EXPLORER_API_V2_BASE> <TOKEN_OR_POSITION_ADDR>
#
# Args:
#   EXPLORER_API_V2_BASE   e.g. https://explorer.example/api/v2
#   TOKEN_OR_POSITION_ADDR 0x... address from the app
#
# Example:
#   ./tools/step2_creator_trace.sh "https://explorer.example/api/v2" \
#     "0x1111111111111111111111111111111111111111"
#
# Exit codes:
#   0  creator resolved
#   1  HTTP/JSON/missing-creator error
#   2  bad usage / --help
# =============================================================================
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage: step2_creator_trace.sh <EXPLORER_API_V2_BASE> <TOKEN_OR_POSITION_ADDR>

Trace a live token/position to its creator_address_hash (usually factory/core).

Args:
  EXPLORER_API_V2_BASE    e.g. https://explorer.example/api/v2
  TOKEN_OR_POSITION_ADDR  0x... address from the app

Example:
  ./tools/step2_creator_trace.sh "https://explorer.example/api/v2" \
    "0x1111111111111111111111111111111111111111"

Exit: 0 creator found; 1 explorer/JSON error; 2 usage
EOF
  exit 2
}

if [[ $# -eq 1 && ( "$1" == "-h" || "$1" == "--help" ) ]]; then usage; fi
[[ $# -eq 2 ]] || usage
BS="${1%/}"
T="$2"

if [[ ! "$T" =~ ^0x[a-fA-F0-9]{40}$ ]]; then
  echo "error: token address must be 0x + 40 hex chars, got: $T" >&2
  exit 2
fi

URL="$BS/addresses/$T"
echo "== STEP 2A: creator trace ==" >&2
echo "GET $URL" >&2

tmp=$(mktemp)
trap 'rm -f "$tmp" "${tmp}.err"' EXIT

set +e
http_code=$(curl -sS --max-time 30 -o "$tmp" -w "%{http_code}" "$URL" 2>"${tmp}.err")
rc=$?
set -e
if [[ $rc -ne 0 ]]; then
  echo "GATE: FAIL — curl error contacting explorer: $(cat "${tmp}.err" 2>/dev/null)" >&2
  exit 1
fi
if [[ "$http_code" != "200" ]]; then
  echo "GATE: FAIL — explorer HTTP $http_code for $URL" >&2
  head -c 500 "$tmp" >&2 || true
  echo >&2
  exit 1
fi

creator=$(python3 -c "
import json,sys
try:
    d=json.load(open('$tmp'))
except Exception as e:
    print('JSON_ERROR', e, file=sys.stderr)
    sys.exit(1)
c=d.get('creator_address_hash')
if not c:
    print('NO_CREATOR', file=sys.stderr)
    print(json.dumps({k:d.get(k) for k in list(d)[:8]}, indent=2)[:800], file=sys.stderr)
    sys.exit(1)
print(c)
")

echo "token:   $T"
echo "creator: $creator"
echo "# the creator is usually the factory/core"
echo "GATE: creator resolved — use as core candidate (verify in Step 3)."
exit 0
