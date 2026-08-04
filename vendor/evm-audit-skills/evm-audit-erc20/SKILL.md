---
name: evm-audit-erc20
description: Weird ERC20 token edge cases that break protocols. Covers fee-on-transfer, rebasing, missing return values, blocklists, multiple addresses, flash minting, ERC777 hooks, approval race conditions, and more. Load when the contract interacts with ANY ERC20 tokens.
---

# EVM Audit — Weird ERC20 Edge Cases

Load when the contract interacts with **any** ERC20 tokens via transfers, approvals, or balances.

## Reference Files
- `references/checklist.md` — Full dense checklist of every weird ERC20 behavior
