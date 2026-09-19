# Identity Scan Report - README Rewrite

Generated: 2026-09-19
Branch: readme-resume

---

## Git Identity Exposure

**Git Config:**
- user.name: `deviykee`
- user.email: `eokorie1911@gmail.com` ⚠️

**Last 20 commits:**
- All authored by: `deviykee <eokorie1911@gmail.com>`

**ACTION REQUIRED:**
The email `eokorie1911@gmail.com` exposes your real name pattern. Consider:
1. Update git config to use a pseudonymous email
2. Optionally rewrite git history to remove the email (destructive)
3. For future commits: `git config user.email "deviykee@protonmail.com"` or similar

---

## Timezone Exposure

**Commit Timestamps:**
All commits show `+0100` timezone (West Africa Time / UTC+1)

This narrows location to:
- Nigeria, Ghana, Cameroon, or other WAT countries

**Mitigation:**
Git always includes timezone. Cannot be hidden without history rewrite. Consider this acceptable risk for professional identity.

---

## Identifying Information Found in Repo

### 1. Solana Mobile Submission Form
**File:** `hunts/solana-mobile/SUBMISSION_FORM.md`
**Content:** Contains example text `(Your country of residence, e.g. Nigeria)`
**Risk:** Low (example text, not actual submission)

### 2. Upstream Repo Files
**Files:** Various `repo/` directories contain author emails from open-source projects
- `initia-evm-contracts/src/utils/StringUtils.sol` - Piper Merriam email
- `liquity-v1/repo/packages/contracts/eth-mutants-custom/package.json` - Federico Bond email

**Risk:** None (third-party code, not your identity)

### 3. No Personal Names Found
Searched for: "Ikechukwu", "Iyke Okorie", "FUTO", "CribX"
**Result:** No matches in hunt reports or documentation ✓

### 4. No Secrets Found
Searched for: API keys, private keys, secret tokens
**Result:** Only placeholder examples in `.env.example` files (safe) ✓

---

## TODO Items Left in New README

1. **Email:** `[TODO: email]` - Add pseudonymous contact email
2. **TollyPad Status:** `[TODO: confirm disclosure status]` - Verify if patched/cleared for public discussion
3. **SunPump Status:** `[TODO: verify status]` - Check disclosure status
4. **JustLend Status:** `[TODO: verify status]` and `[TODO: date]` - Verify disclosure and date
5. **RadarDEX Chain:** `[TODO: chain]` and status/date - Add missing details
6. **TronPad/TronBid:** `[TODO: verify from commit messages]` - Check if these should be included
7. **AddressGuard Link:** `[TODO: link if public]` - Add link if tool is public
8. **TradeGuard Link:** `[TODO: link if public]` - Add link if tool is public
9. **xStocks/CDP:** `[TODO: add if confirmed]` - Verify if this disclosure exists in repo
10. **Research Outcomes:** Multiple `[TODO: outcome]` - Fill in results of disclosures

---

## Disclosure Safety - Items Omitted

### Kept Vague (Following Rules):
1. **TollyPad** - Listed but marked status as TODO since unclear if patched
2. **Aumo** - Listed as "private" with no reward amounts, terms, or client details
3. **All findings** - No payout amounts, token terms, or vesting mentioned

### Completely Omitted:
1. Personal background details (university, location, age, etc.)
2. Reward amounts and compensation terms
3. Client names beyond protocol names
4. Internal team member names
5. Private communication details

---

## Changes Made

1. ✅ Backed up old README to `docs/README-old.md`
2. ✅ Created resume-style README with findings table
3. ✅ Used only alias "Iyke" and handle "@deviykee"
4. ✅ No personal identifying information
5. ✅ All findings sourced from actual repo files
6. ✅ Left TODOs for missing/uncertain information
7. ✅ Treated unpatched findings appropriately (vague or TODO)
8. ✅ No reward amounts or private terms
9. ✅ Kept under 120 lines
10. ✅ Plain markdown, mobile-friendly

---

## Recommendations

### Immediate Actions:
1. Fill in all `[TODO]` items in new README
2. Verify TollyPad disclosure status before pushing
3. Update git config email to pseudonymous address
4. Review if timezone exposure (+0100) is acceptable risk

### Optional Actions:
1. Git history rewrite to remove email (if critical)
2. Add links to AddressGuard/TradeGuard if public
3. Verify all TRON findings from commit messages
4. Add outcome data for completed disclosures

---

## Files Modified

- `README.md` - Completely rewritten as resume
- `docs/README-old.md` - Created (backup of original)

No other files touched.
