# TSBSatellite - High: Arbitrum inbound secured by a raw EOA as sole required DVN at conf=1
**Researcher:** deviykee
**Severity:** High - Conditional on control of EOA 0xb85775a6868c1a729447951fd59f9f7f095cd0b1. Not stranger-exploitable today. Bounded by satellite-held/custodied value (native balances observed 0; token custody not measured).
**Status:** Verified on a local fork / read-only on-chain. No mainnet state touched.
**Disclosure:** Private. Live-exploitable now.  <!-- if applicable -->

## What this means in plain language (read this first)
This app trusts one ordinary wallet key, the kind that lives in a browser or operator laptop, to vouch for every message arriving from Arbitrum, with just one block of confirmation. One phished key equals full control over what the app believes happened on Arbitrum.

## Affected contracts (Unichain + Lisk, chainId 130/1135)
| Role | Address |
|---|---|
| core | 0x3d354c963d881d33937d278117f9546bb9b0f6ae |

## Summary
<the one wrong assumption, plain language>

## Root cause
Latest UlnConfigSet for oapp 0x3d354c96... (and proxy 0xf0485999...) src arbitrum(30110): requiredDVNCount=1 requiredDVNs=[0xb85775a6868c1a729447951fd59f9f7f095cd0b1] confirmations=1. eth_getCode on that DVN returns empty: it is an Externally Owned Account, not a verifier network contract.

## Attack
1. Obtain/control the EOA key. 2. Sign verify() for any forged packet header/payloadHash from arbitrum. 3. conf=1 passes after a single block; ULN302 commits; endpoint delivers forged lzReceive.

## Impact
Auth: one EOA key | Capital: satellite-dependent | Frequency: repeatable | Victims: app users on this leg

## Proof of concept
`forge test --fork-url <RPC> --fork-block-number <BLK> -vv`  → Read-only: cast code shows empty account; getUlnConfig decode in poc/repro_findings.sh.

## Fix
Replace EOA with a real multi-operator DVN or add 2+ required DVNs; raise confirmations.

## Disclosure & compensation
Good-faith private disclosure. I'd appreciate a bounty commensurate with a
High. I am NOT conditioning the disclosure or fix on payment act on it now.
Happy to walk the team through it and review the fix.
deviykee
