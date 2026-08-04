#!/usr/bin/env bash
# =============================================================================
# step7_poc_scaffold.sh
#
# Purpose:
#   Scaffold a Foundry project + SAFE local-fork-only PoC skeleton and print
#   the fork test command (playbook Step 7). Never touches mainnet state.
#
# Usage:
#   step7_poc_scaffold.sh <RPC_URL> <TARGET_ADDR> [POC_DIR]
#
# Args:
#   RPC_URL      JSON-RPC endpoint (resolve current block for the test cmd)
#   TARGET_ADDR  Core contract 0x... written into the skeleton
#   POC_DIR      Output directory (default: ./poc)
#
# Example:
#   ./tools/step7_poc_scaffold.sh "https://rpc.example.chain" \
#     "0x2222222222222222222222222222222222222222" "poc"
#
# Exit codes:
#   0  scaffold written and fork block resolved
#   1  forge/cast missing or RPC block-number failed
#   2  bad usage / --help
# =============================================================================
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage: step7_poc_scaffold.sh <RPC_URL> <TARGET_ADDR> [POC_DIR]

Create (or refresh) a Foundry project with a SAFE local-fork-only PoC skeleton.

Args:
  RPC_URL      JSON-RPC endpoint (used to resolve current block for the test cmd)
  TARGET_ADDR  Core contract 0x... written into the skeleton
  POC_DIR      Output directory (default: ./poc)

Example:
  ./tools/step7_poc_scaffold.sh "https://rpc.example.chain" \
    "0x2222222222222222222222222222222222222222" "poc"

Does NOT execute an exploit on mainnet — fork-only verification.
Exit: 0 scaffold ready; 1 tool/RPC fail; 2 usage
EOF
  exit 2
}

if [[ $# -eq 1 && ( "$1" == "-h" || "$1" == "--help" ) ]]; then usage; fi
[[ $# -ge 2 && $# -le 3 ]] || usage
RPC="$1"
TARGET="$2"
POC_DIR="${3:-poc}"

if [[ ! "$TARGET" =~ ^0x[a-fA-F0-9]{40}$ ]]; then
  echo "error: TARGET_ADDR must be 0x + 40 hex chars" >&2
  exit 2
fi

if ! command -v forge >/dev/null 2>&1; then
  echo "error: forge not on PATH" >&2
  exit 1
fi
if ! command -v cast >/dev/null 2>&1; then
  echo "error: cast not on PATH" >&2
  exit 1
fi

export CAST_TIMEOUT="${CAST_TIMEOUT:-20}"
run_cast() {
  if command -v timeout >/dev/null 2>&1; then
    timeout "$CAST_TIMEOUT" cast "$@"
  else
    cast "$@"
  fi
}

echo "== STEP 7: forge PoC scaffold =="
echo "target: $TARGET"
echo "dir:    $POC_DIR"

mkdir -p "$POC_DIR"
(
  cd "$POC_DIR"
  if [[ ! -f foundry.toml ]]; then
    forge init --no-git . 2>/dev/null || true
  fi
  rm -f src/Counter.sol test/Counter.t.sol test/Counter.sol 2>/dev/null || true
  find test -name 'Counter*' -delete 2>/dev/null || true
)

cat > "$POC_DIR/test/PoC.t.sol" <<EOF
// SAFE, read-only, LOCAL FORK ONLY. Uses test cheatcodes (vm.*) that do nothing on
// a real network, so this can never run as a live attack. No mainnet state touched.
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {Test, console} from "forge-std/Test.sol";
interface ITarget { /* add the exact fns from Step 3 */ }
contract PoC is Test {
    address constant TARGET = ${TARGET};
    address attacker = address(0xA11CE);
    function test_exploit() public {
        // 1. record victim/pot state
        // 2. vm.deal / vm.prank the attacker; execute the value-moving sequence
        // 3. assert the theft/loss in numbers:
        //    assertGt(attackerGain, attackerCost, "net profit"); // or funds stranded
    }
}
EOF

echo "wrote $POC_DIR/test/PoC.t.sol"

set +e
BLK=$(run_cast block-number --rpc-url "$RPC" 2>&1)
rc=$?
set -e
if [[ $rc -ne 0 ]]; then
  echo "GATE: FAIL — cannot resolve fork block from RPC: $BLK" >&2
  exit 1
fi

echo "fork block: $BLK"
echo
echo "Drop in exploit logic, then run:"
echo "  cd $POC_DIR && forge test --fork-url $RPC --fork-block-number $BLK -vv"
echo
echo "GATE: scaffold ready — fill test_exploit(), then run the forge command above (fork only)."
echo "If full-scale fork is impractical: replicate exact vulnerable logic locally and cite on-chain magnitude."
exit 0
