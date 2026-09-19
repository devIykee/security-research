#!/usr/bin/env bash
# =============================================================================
# step1_ground_truth.sh
#
# Purpose:
#   Confirm the RPC is alive and returns the expected chain ID (playbook Step 1).
#
# Usage:
#   step1_ground_truth.sh <RPC_URL> <EXPECTED_CHAIN_ID>
#
# Args:
#   RPC_URL            JSON-RPC endpoint (from INTAKE RPC)
#   EXPECTED_CHAIN_ID  Chain id from INTAKE (e.g. 4663)
#
# Example:
#   ./tools/step1_ground_truth.sh "https://rpc.example.chain" "4663"
#
# Exit codes:
#   0  chain id matches and block-number succeeds (GATE PASS)
#   1  RPC error or chain id mismatch (GATE FAIL / STOP)
#   2  bad usage / --help
# =============================================================================
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage: step1_ground_truth.sh <RPC_URL> <EXPECTED_CHAIN_ID>

Confirm the RPC is reachable and returns the expected chain ID.

Args:
  RPC_URL            JSON-RPC endpoint
  EXPECTED_CHAIN_ID  Chain id from INTAKE (e.g. 4663)

Example:
  ./tools/step1_ground_truth.sh "https://rpc.example.chain" "4663"

Exit: 0 pass; 1 RPC/mismatch; 2 usage
EOF
  exit 2
}

if [[ $# -eq 1 && ( "$1" == "-h" || "$1" == "--help" ) ]]; then usage; fi
[[ $# -eq 2 ]] || usage
RPC="$1"
EXPECTED_CID="$2"

export CAST_TIMEOUT="${CAST_TIMEOUT:-15}"
run_cast() {
  if command -v timeout >/dev/null 2>&1; then
    timeout "$CAST_TIMEOUT" cast "$@"
  else
    cast "$@"
  fi
}

echo "== STEP 1: ground truth =="
echo "RPC: $RPC"
echo "Expected chain id: $EXPECTED_CID"

set +e
got_cid=$(run_cast chain-id --rpc-url "$RPC" 2>&1)
rc_cid=$?
set -e
if [[ $rc_cid -ne 0 ]]; then
  echo "GATE: FAIL — RPC/chain-id error: $got_cid" >&2
  echo "STOP. Likely vaporware/scam or bad RPC. Do not sink hours." >&2
  exit 1
fi

echo "cast chain-id: $got_cid"

if [[ "$got_cid" != "$EXPECTED_CID" ]]; then
  echo "GATE: FAIL — chain id mismatch (got $got_cid, expected $EXPECTED_CID)" >&2
  echo "STOP. Fix RPC or CHAIN_ID in INTAKE before continuing." >&2
  exit 1
fi

set +e
blk=$(run_cast block-number --rpc-url "$RPC" 2>&1)
rc_blk=$?
set -e
if [[ $rc_blk -ne 0 ]]; then
  echo "GATE: FAIL — block-number error: $blk" >&2
  echo "STOP. RPC not usable." >&2
  exit 1
fi

echo "cast block-number: $blk"
echo "GATE: PASS — Real chain confirmed (chainId=$got_cid, block=$blk). Continue."
exit 0
