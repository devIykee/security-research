#!/usr/bin/env bash
# =============================================================================
# step2_bundle_grep.sh
#
# Purpose:
#   Grep frontend JS bundles (Vite/Next) for role-labeled contract addresses
#   (playbook Step 2B).
#
# Usage:
#   step2_bundle_grep.sh <WEBSITE_URL>
#
# Args:
#   WEBSITE_URL  App origin or full URL (from INTAKE WEBSITE)
#
# Example:
#   ./tools/step2_bundle_grep.sh "https://app.example"
#
# Exit codes:
#   0  HTML fetched (addresses may or may not be present — see GATE lines)
#   1  website HTML fetch failed
#   2  bad usage / --help
# =============================================================================
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage: step2_bundle_grep.sh <WEBSITE_URL>

Fetch the app HTML and JS bundles (Vite or Next), grep for role-labeled 0x addrs.

Args:
  WEBSITE_URL  App origin or full URL (e.g. https://app.example)

Example:
  ./tools/step2_bundle_grep.sh "https://app.example"

Exit: 0 HTML ok; 1 fetch failed; 2 usage
EOF
  exit 2
}

if [[ $# -eq 1 && ( "$1" == "-h" || "$1" == "--help" ) ]]; then usage; fi
[[ $# -eq 1 ]] || usage
WEBSITE="${1%/}"

echo "== STEP 2B: bundle grep =="
echo "WEBSITE: $WEBSITE"

workdir=$(mktemp -d)
trap 'rm -rf "$workdir"' EXIT
cd "$workdir"

set +e
curl -sSL --max-time 45 -o app.html "$WEBSITE" 2>curl.err
rc=$?
set -e
if [[ $rc -ne 0 ]] || [[ ! -s app.html ]]; then
  echo "GATE: FAIL — could not fetch website: $(cat curl.err 2>/dev/null)" >&2
  exit 1
fi

mapfile -t assets < <(
  {
    grep -oE '/assets/[^"'\'' ]+\.js' app.html || true
    grep -oE '/_next/static/[^"'\'' ]+\.js' app.html || true
    grep -oE 'https?://[^"'\'' ]+\.js' app.html || true
  } | sort -u | head -40
)

if [[ ${#assets[@]} -eq 0 ]]; then
  echo "No JS asset paths found in HTML. Try browser network tab (Step 2C)."
  echo "GATE: no bundle paths — fall through to browser/explorer methods."
  exit 0
fi

echo "Found ${#assets[@]} JS path(s); grepping for named addresses..."
pattern='(factory|launch|vault|pool|router|oracle|manager|locker)"?:"?0x[a-fA-F0-9]{40}'
found=0
for path in "${assets[@]}"; do
  if [[ "$path" =~ ^https?:// ]]; then
    url="$path"
  else
    url="${WEBSITE}${path}"
  fi
  set +e
  body=$(curl -sS --max-time 45 "$url" 2>/dev/null)
  rc=$?
  set -e
  [[ $rc -eq 0 && -n "$body" ]] || continue
  matches=$(printf '%s' "$body" | grep -oiE "$pattern" | sort -u || true)
  if [[ -n "$matches" ]]; then
    echo "--- $url ---"
    echo "$matches"
    found=1
  fi
done

if [[ $found -eq 0 ]]; then
  echo "No role-labeled 0x addresses in scanned bundles."
  echo "GATE: empty grep — try Step 2C (browser eth_call) or 2D (explorer)."
else
  echo "GATE: addresses found — verify candidates in Step 3."
fi
exit 0
