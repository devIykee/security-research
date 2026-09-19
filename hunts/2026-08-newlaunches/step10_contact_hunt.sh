#!/usr/bin/env bash
# =============================================================================
# step10_contact_hunt.sh
#
# Purpose:
#   Fetch official pages and extract candidate security inboxes (emails,
#   Immunefi/HackerOne/Cantina/Code4rena links) plus nearby quote lines.
#   Decodes Cloudflare data-cfemail. Does not send mail. Agent must still
#   write reports/contacts.md with URL + exact quote and reject lookalikes.
#
# Usage:
#   step10_contact_hunt.sh <URL> [URL ...]
#
# Example:
#   ./tools/step10_contact_hunt.sh \
#     "https://raw.githubusercontent.com/example/docs/master/faq.md" \
#     "https://docs.example.com/faq.md"
#
# Exit codes:
#   0  at least one URL fetched
#   1  every fetch failed
#   2  usage / --help
# =============================================================================
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage: step10_contact_hunt.sh <URL> [URL ...]

Fetch official docs/forum pages and print security-contact candidates
(emails, bounty-platform links) with nearby quote lines.

Exit: 0 some fetch ok · 1 all fetches failed · 2 usage
EOF
  exit 2
}

if [[ $# -eq 0 || "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
fi

decode_cfemail() {
  local hex="$1"
  python3 - "$hex" <<'PY'
import sys
s = sys.argv[1]
if len(s) < 4 or len(s) % 2:
    sys.exit(0)
try:
    key = int(s[:2], 16)
    out = "".join(chr(int(s[i:i+2], 16) ^ key) for i in range(2, len(s), 2))
except ValueError:
    sys.exit(0)
if "@" in out and all(32 <= ord(c) < 127 for c in out):
    print(out)
PY
}

fetch_one() {
  local url="$1"
  local body
  if command -v timeout >/dev/null 2>&1; then
    body=$(timeout 25 curl -fsSL -A "iykes-web3-bughunt-skill/step10_contact_hunt" --max-time 20 "$url" 2>/dev/null) || return 1
  else
    body=$(curl -fsSL -A "iykes-web3-bughunt-skill/step10_contact_hunt" --max-time 20 "$url" 2>/dev/null) || return 1
  fi
  printf '%s\n' "$body"
}

echo "== STEP 10A: official contact hunt =="
ok=0
fail=0

for url in "$@"; do
  echo
  echo "URL: $url"
  body=$(fetch_one "$url" || true)
  if [[ -z "${body:-}" ]]; then
    echo "  FETCH FAIL"
    fail=$((fail + 1))
    continue
  fi
  ok=$((ok + 1))

  # Cloudflare-protected emails
  while IFS= read -r hex; do
    [[ -z "$hex" ]] && continue
    decoded=$(decode_cfemail "$hex" || true)
    if [[ -n "${decoded:-}" ]]; then
      echo "  cfemail: $decoded"
    fi
  done < <(printf '%s\n' "$body" | grep -oE 'data-cfemail="[0-9a-fA-F]+"|email-protection#[0-9a-fA-F]+' | sed -E 's/.*[=#]//' | sort -u)

  # Emails
  emails=$(printf '%s\n' "$body" | grep -oE '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' | sort -u || true)
  if [[ -n "${emails:-}" ]]; then
    echo "  emails:"
    printf '%s\n' "$emails" | sed 's/^/    /'
  fi

  # Bounty platforms
  plats=$(printf '%s\n' "$body" | grep -oE 'https?://[^"[:space:]<>]+(immunefi|hackerone|cantina|code4rena|hats-finance)[^"[:space:]<>]*' | sort -u || true)
  if [[ -n "${plats:-}" ]]; then
    echo "  bounty platforms:"
    printf '%s\n' "$plats" | sed 's/^/    /'
  fi

  # Nearby quote lines
  quotes=$(printf '%s\n' "$body" | grep -iE 'security@|contact@|bugs@|report.*bug|bug bounty|immunefi|hackerone|how can i contact' | head -12 || true)
  if [[ -n "${quotes:-}" ]]; then
    echo "  quotes:"
    printf '%s\n' "$quotes" | cut -c1-220 | sed 's/^/    /'
  fi

  if [[ -z "${emails:-}" && -z "${plats:-}" && -z "${quotes:-}" ]]; then
    echo "  no contact-like hits (still fetched)"
  fi
done

echo
if [[ $ok -eq 0 ]]; then
  echo "GATE: FAIL - no URL fetched. Do not invent an inbox."
  exit 1
fi
echo "GATE: fetched $ok page(s). Cite URL + quote in reports/contacts.md before any DM."
echo "Prefer security@ / bounty platform over generic contact@. Reject lookalike X handles."
exit 0
