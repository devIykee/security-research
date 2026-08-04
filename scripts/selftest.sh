#!/usr/bin/env bash
# =============================================================================
# selftest.sh
#
# Purpose:
#   Smoke-check every tools/ script: --help or no-args must exit non-zero with
#   a clear usage message, and must not hang.
#
# Usage:
#   ./tools/selftest.sh
#
# Example:
#   ./tools/selftest.sh
#
# Exit codes:
#   0  all scripts failed gracefully (usage/help path OK)
#   1  at least one script hung, crashed without usage, or exited 0 on empty args
# =============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

TIMEOUT_SECS="${SELFTEST_TIMEOUT:-8}"
fail=0

run_check() {
  local name="$1"
  shift
  local out rc
  echo -n "  $name ... "
  set +e
  if command -v timeout >/dev/null 2>&1; then
    out=$(timeout "$TIMEOUT_SECS" "$@" 2>&1)
    rc=$?
  else
    out=$("$@" 2>&1)
    rc=$?
  fi
  set -e

  # timeout(1) returns 124 on hang
  if [[ $rc -eq 124 ]]; then
    echo "FAIL (hung after ${TIMEOUT_SECS}s)"
    fail=1
    return
  fi
  if [[ $rc -eq 0 ]]; then
    echo "FAIL (exit 0 on help/no-args; expected non-zero)"
    fail=1
    return
  fi
  if ! echo "$out" | grep -qiE 'usage|help|required|arguments|error:'; then
    echo "FAIL (no clear usage/error message)"
    echo "    output: $(echo "$out" | head -2 | tr '\n' ' ')"
    fail=1
    return
  fi
  echo "OK (exit $rc)"
}

echo "== tools selftest (graceful failure on help / missing args) =="
echo "timeout per check: ${TIMEOUT_SECS}s"
echo

# Shell scripts: no args + --help
for s in \
  step1_ground_truth.sh \
  step2_creator_trace.sh \
  step2_bundle_grep.sh \
  step3_surface_map.sh \
  step4_auth_triage.sh \
  step7_poc_scaffold.sh
do
  run_check "$s (no args)" "./$s"
  run_check "$s (--help)" "./$s" --help
done

# Python fillers: no args (argparse exits 2) + --help (argparse exits 0 for --help!)
# Spec: --help OR no args — for argparse, --help exits 0 by design. Check no-args
# for non-zero, and --help for a usage string (exit 0 is OK for --help only).
for s in step9_report_skeleton.py step10_dm_skeleton.py; do
  run_check "$s (no args)" python3 "./$s"
  # --help must print usage and not hang; exit 0 is acceptable for argparse --help
  echo -n "  $s (--help) ... "
  set +e
  if command -v timeout >/dev/null 2>&1; then
    out=$(timeout "$TIMEOUT_SECS" python3 "./$s" --help 2>&1)
    rc=$?
  else
    out=$(python3 "./$s" --help 2>&1)
    rc=$?
  fi
  set -e
  if [[ $rc -eq 124 ]]; then
    echo "FAIL (hung)"
    fail=1
  elif ! echo "$out" | grep -qiE 'usage|options|help'; then
    echo "FAIL (no usage text)"
    fail=1
  else
    echo "OK (exit $rc, usage printed)"
  fi
done

# selftest itself with --help style: document only
echo
if [[ $fail -ne 0 ]]; then
  echo "SELFTEST FAIL: one or more scripts did not fail gracefully."
  exit 1
fi
echo "SELFTEST PASS: all scripts emit usage and exit non-zero on missing args."
exit 0
