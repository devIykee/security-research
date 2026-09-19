# JustLend Disclosure Package - Ready to Send

Date: 2026-08-28
Researcher: deviykee (Iyke)
Status: READY FOR DISCLOSURE

---

## Deliverables Created

### 1. First Contact DM
**File:** hunts/justlend/DM-FIRST-CONTACT.md
**Platform:** X/Twitter DM or Discord/Telegram
**Length:** 4 sentences, professional tone
**Content:** High-level vulnerability notice, asks for security contact

### 2. Technical Report
**File:** hunts/justlend/REPORT-LIQUIDATION-FRONTRUN.md
**Format:** Full vulnerability report using skill template
**Sections:**
- Plain language explanation
- Affected contracts
- Root cause (CToken.sol:945-960)
- Attack steps
- Impact assessment
- Recommended fixes

### 3. Detailed Analysis (Supporting)
**File:** hunts/justlend/CONFIRMED-LIQUIDATION-FRONTRUN.md
**Format:** Deep technical analysis with code snippets
**Content:** Source code evidence, line-by-line analysis, economics

### 4. Original Disclosure Draft (Supporting)
**File:** hunts/justlend/DISCLOSURE-REPORT.md
**Format:** Comprehensive disclosure package
**Content:** Executive summary, timeline proposal, remediation options

---

## Vulnerability Summary

**Title:** Liquidation Front-Running via Public Mempool
**Severity:** High
**Confidence:** 95% (source code verified)
**Impact:** 50-150M USD annual MEV extraction
**Scope:** All jToken markets (jUSDT, jTRX, jBTC, etc.)
**Status:** Live-exploitable on TRON mainnet
**Verification:** Source code analysis, no mainnet exploitation

---

## Contact Information Needed

Find JustLend security contact via:
- X/Twitter: @JustLendDAO or @JUST_DeFi
- Discord: JustLend official server
- Telegram: JustLend community
- Email: security@just.network or team@just.network
- GitHub: github.com/justlend/justlend-protocol (check for SECURITY.md)

---

## Sending Instructions

### Step 1: Locate Contact
Search for official JustLend security channel

### Step 2: Send Initial DM
Copy content from: hunts/justlend/DM-FIRST-CONTACT.md
Platform: X/Twitter DM preferred (private, direct)

### Step 3: Wait for Response
Expected: 1-7 days
If no response: Try alternative channels (Discord, Telegram, email)

### Step 4: Share Full Report (After They Respond)
Send: hunts/justlend/REPORT-LIQUIDATION-FRONTRUN.md
Optional supporting docs:
- hunts/justlend/CONFIRMED-LIQUIDATION-FRONTRUN.md (detailed analysis)
- hunts/justlend/DISCLOSURE-REPORT.md (full package)

### Step 5: Coordinate Timeline
Propose: 90-day coordinated disclosure
- T+7: Acknowledgment
- T+30: Fix development
- T+60: Deploy to mainnet
- T+90: Public disclosure

---

## Key Points for Communication

DO:
- Be professional and respectful
- Emphasize no exploitation occurred
- Offer to help with fix validation
- Be flexible on timeline
- Request bug bounty if available

DO NOT:
- Make threats or ultimatums
- Set hard deadlines
- Publicly disclose before fix
- Share exploit code publicly
- Demand specific payment

---

## Disclosure Ethics

This research followed responsible disclosure principles:
- Private first contact
- No mainnet exploitation
- No public disclosure before fix
- Coordinated timeline
- Good faith communication

---

## Files Overview

Primary (send these):
- DM-FIRST-CONTACT.md (initial message)
- REPORT-LIQUIDATION-FRONTRUN.md (main report)

Supporting (optional):
- CONFIRMED-LIQUIDATION-FRONTRUN.md (detailed technical)
- DISCLOSURE-REPORT.md (comprehensive package)

All files use professional tone, no emojis, clear structure per skill template.

---

Status: READY TO SEND
Next Step: Locate JustLend security contact and send DM-FIRST-CONTACT.md
