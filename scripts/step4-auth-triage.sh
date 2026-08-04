#!/usr/bin/env bash
# =============================================================================
# step4_auth_triage.sh
#
# Purpose:
#   eth_call common admin/keeper functions from an attacker address; flag OPEN
#   (missing access control) (playbook Step 4).
#
# Usage:
#   step4_auth_triage.sh <RPC_URL> <CONTRACT_ADDR> [extra_sig ...]
#
# Args:
#   RPC_URL        JSON-RPC endpoint
#   CONTRACT_ADDR  Target 0x...
#   extra_sig      Optional additional signatures (e.g. 'setMigrator(address)')
#
# Example:
#   ./tools/step4_auth_triage.sh "https://rpc.example.chain" \
#     "0x2222222222222222222222222222222222222222" "setMigrator(address)"
#
# Exit codes:
#   0  triage completed (OPEN findings are still exit 0 — read GATE lines)
#   1  hard RPC/transport failure
#   2  bad usage / --help
# =============================================================================
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage: step4_auth_triage.sh <RPC_URL> <CONTRACT_ADDR> [extra_sig ...]

eth_call common state-changing admin/keeper functions from an attacker address.
If the call does NOT revert, access control may be missing (likely Critical).

Args:
  RPC_URL        JSON-RPC endpoint
  CONTRACT_ADDR  Target 0x...
  extra_sig      Optional additional signatures (e.g. 'setMigrator(address)')

Default signatures probed:
  setOwner(address) setKeeper(address) setOracle(address) setFee(uint256)
  mint(address,uint256) withdraw(uint256)

Example:
  ./tools/step4_auth_triage.sh "https://rpc.example.chain" \
    "0x2222222222222222222222222222222222222222"

Exit: 0 triage done; 1 RPC failure; 2 usage
EOF
  exit 2
}

if [[ $# -eq 1 && ( "$1" == "-h" || "$1" == "--help" ) ]]; then usage; fi
[[ $# -ge 2 ]] || usage
RPC="$1"
C="$2"
shift 2

if [[ ! "$C" =~ ^0x[a-fA-F0-9]{40}$ ]]; then
  echo "error: contract must be 0x + 40 hex chars" >&2
  exit 2
fi

ATK=0x000000000000000000000000000000000000dEaD
export CAST_TIMEOUT="${CAST_TIMEOUT:-20}"
run_cast() {
  if command -v timeout >/dev/null 2>&1; then
    timeout "$CAST_TIMEOUT" cast "$@"
  else
    cast "$@"
  fi
}

DEFAULT_SIGS=(
  "setOwner(address)"
  "setKeeper(address)"
  "setOracle(address)"
  "setFee(uint256)"
  "mint(address,uint256)"
  "withdraw(uint256)"
)
SIGS=("${DEFAULT_SIGS[@]}" "$@")

echo "== STEP 4: auth triage =="
echo "contract: $C"
echo "attacker (from): $ATK"
echo "probing ${#SIGS[@]} signature(s)..."

set +e
probe=$(run_cast chain-id --rpc-url "$RPC" 2>&1)
rc_probe=$?
set -e
if [[ $rc_probe -ne 0 ]]; then
  echo "GATE: FAIL — RPC error before triage: $probe" >&2
  exit 1
fi

open_count=0
for sig in "${SIGS[@]}"; do
  printf "%-28s " "$sig"
  args=()
  if [[ "$sig" == *"(address)"* ]]; then
    args=("$ATK")
  elif [[ "$sig" == *"(address,uint256)"* ]]; then
    args=("$ATK" "1")
  elif [[ "$sig" == *"(uint256)"* ]]; then
    args=("1")
  elif [[ "$sig" == *"(address,address)"* ]]; then
    args=("$ATK" "$ATK")
  elif [[ "$sig" == *"(uint256,uint256)"* ]]; then
    args=("1" "1")
  fi

  set +e
  out=$(run_cast call "$C" "$sig" "${args[@]}" --from "$ATK" --rpc-url "$RPC" 2>&1)
  rc=$?
  set -e

  if echo "$out" | grep -qiE 'timeout|connection refused|could not connect|error sending request|transport|dns'; then
    echo
    echo "GATE: FAIL — RPC error during triage: $out" >&2
    exit 1
  fi

  if echo "$out" | grep -qiE 'revert|error|execution reverted|EvmError'; then
    echo "guarded"
  elif [[ $rc -ne 0 ]]; then
    echo "guarded (cast rc=$rc)"
  else
    echo "OPEN <-- CHECK"
    open_count=$((open_count + 1))
  fi
done

echo "# control: same call from the real owner should behave differently (confirms auth revert, not generic)"
if [[ $open_count -gt 0 ]]; then
  echo "GATE: $open_count OPEN function(s) — investigate as likely Critical missing access control."
else
  echo "GATE: all default probes guarded — continue to Step 5 product-type questions (not a free win)."
fi
exit 0
