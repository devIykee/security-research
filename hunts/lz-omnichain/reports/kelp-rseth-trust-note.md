# Kelp rsETH (Hemi) - Trust: rsETH Hemi legs rely on one LZ-DVN while Ethereum leg uses four (config asymmetry)
**Researcher:** deviykee
**Severity:** Trust - Trust/config note. Adapter currently holds 0 rsETH so no immediate value exposure measured. Kelp has publicly migrated large portions of bridging to CCIP.
**Status:** Verified on a local fork / read-only on-chain. No mainnet state touched.
**Disclosure:** Private. Live-exploitable now.  <!-- if applicable -->

## What this means in plain language (read this first)
The same app demands four independent verifiers from Ethereum but accepts one from every other chain connected to Hemi. Today nothing is locked there, but if the adapter refills, the weaker legs become the soft spot.

## Affected contracts (Hemi, chainId 43111)
| Role | Address |
|---|---|
| core | 0xc3eacf0612346366db554c991d7858716db09f58 |

## Summary
<the one wrong assumption, plain language>

## Root cause
Latest configs: 10/12 L2 legs req=1 [0x282b3386...] conf=42; ethereum leg req=4 conf=64.

## Attack
Precondition: adapter funded again + single DVN key control.

## Impact
No current exposure; future refill recreates Kelp-class risk.

## Proof of concept
`forge test --fork-url <RPC> --fork-block-number <BLK> -vv`  → balanceOf(adapter)=0 captured in notes; decode repro available.

## Fix
Unify all legs at req>=2 before re-funding.

## Disclosure & compensation
Good-faith private disclosure. I'd appreciate a bounty commensurate with a
Trust. I am NOT conditioning the disclosure or fix on payment act on it now.
Happy to walk the team through it and review the fix.
deviykee
