---
name: evm-audit-dos
description: EVM smart contract audit checklist for denial-of-service and griefing attacks. Covers gas griefing, unbounded loops, returndata bombing, block stuffing, and DoS via revert. Use when auditing protocols with loops, external calls, or time-sensitive operations. Load references/checklist.md for the full checklist.
---

# DoS & Griefing Audit Skill

## Overview
Denial-of-service and griefing attack patterns in smart contracts. Focuses on gas exhaustion, revert-based DoS, and economic griefing.

## Reference Files
- **references/checklist.md** — Full audit checklist, load this when auditing for DoS/griefing
