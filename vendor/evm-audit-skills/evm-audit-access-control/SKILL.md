---
name: evm-audit-access-control
description: EVM smart contract audit checklist for non-obvious access control issues. Covers centralization risks, privilege escalation, two-step ownership, role management, and admin rug vectors. Use when auditing protocols with privileged roles, admin functions, or governance. Load references/checklist.md for the full checklist.
---

# Access Control Audit Skill

## Overview
Non-obvious access control vulnerabilities beyond basic missing `onlyOwner` checks. Focuses on centralization risks, privilege escalation, and admin attack vectors.

## Reference Files
- **references/checklist.md** — Full audit checklist, load this when auditing access control
