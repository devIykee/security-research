#!/usr/bin/env bash
# =============================================================================
# step3_surface_map.sh
#
# Purpose:
#   Verification gate + surface map: balance, code size, Sourcify, selectors
#   (playbook Step 3).
#
# Usage:
#   step3_surface_map.sh <RPC_URL> <CHAIN_ID> <CONTRACT_ADDR> [EXPLORER_API_V2_BASE]
#
# Args:
#   RPC_URL               JSON-RPC endpoint
#   CHAIN_ID              Numeric chain id (for Sourcify)
#   CONTRACT_ADDR         Core contract 0x...
#   EXPLORER_API_V2_BASE  Optional Blockscout API base for tx-history selectors
#
# Example:
#   ./tools/step3_surface_map.sh "https://rpc.example.chain" "4663" \
#     "0x2222222222222222222222222222222222222222" \
#     "https://explorer.example/api/v2"
#
# Exit codes:
#   0  surface map completed (verified or selector map)
#   1  hard RPC failure or no code at address
#   2  bad usage / --help
# =============================================================================
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage: step3_surface_map.sh <RPC_URL> <CHAIN_ID> <CONTRACT_ADDR> [EXPLORER_API_V2_BASE]

Map funds-at-risk, code size, Sourcify verification, and (if unverified) selectors.

Args:
  RPC_URL               JSON-RPC endpoint
  CHAIN_ID              Numeric chain id (for Sourcify)
  CONTRACT_ADDR         Core contract 0x...
  EXPLORER_API_V2_BASE  Optional Blockscout API base for tx-history selectors

Example:
  ./tools/step3_surface_map.sh "https://rpc.example.chain" "4663" \
    "0x2222222222222222222222222222222222222222" \
    "https://explorer.example/api/v2"

Exit: 0 mapped; 1 RPC/empty-code; 2 usage
EOF
  exit 2
}

if [[ $# -eq 1 && ( "$1" == "-h" || "$1" == "--help" ) ]]; then usage; fi
[[ $# -ge 3 && $# -le 4 ]] || usage
RPC="$1"
CID="$2"
C="$3"
BS="${4:-}"

if [[ ! "$C" =~ ^0x[a-fA-F0-9]{40}$ ]]; then
  echo "error: contract must be 0x + 40 hex chars" >&2
  exit 2
fi

export CAST_TIMEOUT="${CAST_TIMEOUT:-20}"
run_cast() {
  if command -v timeout >/dev/null 2>&1; then
    timeout "$CAST_TIMEOUT" cast "$@"
  else
    cast "$@"
  fi
}

echo "== STEP 3: verification gate + surface map =="
echo "contract: $C  chainId: $CID"

set +e
bal=$(run_cast balance "$C" --rpc-url "$RPC" 2>&1)
rc_bal=$?
set -e
if [[ $rc_bal -ne 0 ]]; then
  echo "GATE: FAIL — cast balance error: $bal" >&2
  exit 1
fi
echo "balance (wei): $bal   # funds at risk. ~0 and no downstream value => weak target"

set +e
code=$(run_cast code "$C" --rpc-url "$RPC" 2>&1)
rc_code=$?
set -e
if [[ $rc_code -ne 0 ]]; then
  echo "GATE: FAIL — cast code error: $code" >&2
  exit 1
fi
if [[ "$code" == "0x" || -z "$code" ]]; then
  echo "code size (chars): 0  # EOA or empty — not a contract"
  echo "GATE: no code at address — pick a different candidate."
  exit 1
fi
code_chars=${#code}
echo "code size (chars of hex dump): $code_chars   # size => complexity"
printf '%s\n' "$code" > code.hex
echo "wrote code.hex"

src_url="https://sourcify.dev/server/v2/contract/${CID}/${C}?fields=sources,compilation"
echo "Sourcify: $src_url"
set +e
http_code=$(curl -sS --max-time 30 -o src.json -w "%{http_code}" "$src_url" 2>/tmp/step3_curl.err)
rc_curl=$?
set -e
match="none"
comp_name=""
if [[ $rc_curl -eq 0 && "$http_code" == "200" && -s src.json ]]; then
  read -r match comp_name < <(python3 -c "
import json
d=json.load(open('src.json'))
print(d.get('match') or 'none', (d.get('compilation') or {}).get('name') or '')
" 2>/dev/null || echo "none ")
fi
echo "sourcify match: $match  compilation.name: $comp_name"

if [[ "$match" != "none" && "$match" != "null" && -n "$match" && "$match" != "None" ]]; then
  if [[ "$match" == "exact_match" || "$match" == "match" || "$match" == "partial" || "$match" == "partial_match" || "$match" == "true" ]]; then
    echo "GATE: Verified — pull source files from src.json and read them (30-min path)."
    exit 0
  fi
  if [[ "$match" != "none" ]]; then
    echo "GATE: Sourcify returned match='$match' — inspect src.json; if sources present, read them."
  fi
fi

echo "GATE: Unverified (or Sourcify miss) — mapping selectors from bytecode + tx history..."

set +e
dis_out=$(run_cast disassemble "$code" 2>&1)
rc_dis=$?
set -e
if [[ $rc_dis -ne 0 ]]; then
  echo "warn: cast disassemble failed: $dis_out" >&2
else
  echo "--- selectors (PUSH4 near EQ) ---"
  printf '%s\n' "$dis_out" \
    | awk '/PUSH4 0x/{s=$0;h=NR} /EQ/&&(NR-h<=2){print s}' \
    | grep -Eo '0x[0-9a-fA-F]{8}' | sort -u \
    | while read -r x; do
        set +e
        name=$(run_cast 4byte "$x" 2>/dev/null | head -1)
        set -e
        printf "%s %s\n" "$x" "${name:-?}"
      done
fi

if [[ -n "$BS" ]]; then
  BS="${BS%/}"
  tx_url="$BS/addresses/$C/transactions"
  echo "--- top selectors from tx history ($tx_url) ---"
  set +e
  curl -sS --max-time 30 "$tx_url" -o txs.json 2>/tmp/step3_tx.err
  rc_tx=$?
  set -e
  if [[ $rc_tx -eq 0 && -s txs.json ]]; then
    python3 -c "
import json
from collections import Counter
d=json.load(open('txs.json'))
items=d.get('items') or d.get('result') or []
c=Counter((t.get('raw_input') or t.get('input') or '0x')[:10] for t in items)
for sel,n in c.most_common(10):
    print(n, sel)
"
  else
    echo "warn: could not fetch tx history" >&2
  fi
fi

echo "GATE: surface map done — use selectors + balance to drive Step 4 auth triage."
exit 0
