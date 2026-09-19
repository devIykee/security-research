# WGC SuperchainOFT (Lisk) - Medium: 32 inbound pathways secured by a single DVN with erratic confirmation counts
**Researcher:** deviykee
**Severity:** Trust (downgraded from Medium: live supply is 1000 tokens at 6dp) - Conditional on compromise of DVN 0x6788f524...(lisk deployment named 'DVN'). Bounded by bridged WGC supply on lisk (not measured).
**Status:** Verified on a local fork / read-only on-chain. No mainnet state touched.
**Disclosure:** Private. Live-exploitable now.  <!-- if applicable -->

## What this means in plain language (read this first)
Every bridge leg of this token into Lisk depends on exactly one verifier, and the number of blocks it waits for varies wildly per chain, down to a single confirmation on Hyperliquid where fast finality assumptions do not hold like Ethereum.

## Affected contracts (Lisk, chainId 1135)
| Role | Address |
|---|---|
| core | 0x3d63825b0d8669307366e6c8202f656b9e91d368 |

## Summary
<the one wrong assumption, plain language>

## Root cause
All 32 src pathways: requiredDVNCount=1 [0x6788f52439aca6bff597d3eec2dc9a44b8fee842]; confirmations range 1..225000 (hyperliquid=1, xlayer=225000, polygon=512).

## Attack
1. Control the single DVN key. 2. Attest forged mint/unlock messages from any configured src. 3. Delivery proceeds at the leg's low confirmation setting.

## Impact
Auth: single DVN key | Capital: bridged supply | Frequency: repeatable | Victims: WGC holders

## Proof of concept
`forge test --fork-url <RPC> --fork-block-number <BLK> -vv`  → Read-only decode in poc/repro_findings.sh.

## Fix
Adopt multi-DVN set and rationalize per-chain confirmations.

## Disclosure & compensation
Good-faith private disclosure. I'd appreciate a bounty commensurate with a
Medium. I am NOT conditioning the disclosure or fix on payment act on it now.
Happy to walk the team through it and review the fix.
deviykee
