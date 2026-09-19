# Stargate Hydra (LayerZero) - High: Sole required DVN with single required verifier (current conf=20) guards TokenMessaging/CreditMessaging inbound from Sophon pathway
**Researcher:** deviykee
**Severity:** High - Conditional on compromise/misbehavior of ONE verifier key (0x04830f6d...). Not stranger-exploitable today. Magnitude bounded by pool-token/credit value routable through the sophon pathway of these 70-pathway apps.
**Status:** Verified on a local fork / read-only on-chain. No mainnet state touched.
**Disclosure:** Private. Live-exploitable now.  <!-- if applicable -->

## What this means in plain language (read this first)
Users assume cross-chain messages arrive only after multiple independent security firms attest them. For this pathway a single verifier decides everything (current setting waits twenty blocks). If that one verifier key leaks or turns malicious, no second opinion exists to stop a forged message. If that one verifier key leaks or turns malicious, forged messages can mint/route pool tokens or credit with nothing else standing in the way.

## Affected contracts (Hemi + Unichain, chainId 43111/130)
| Role | Address |
|---|---|
| core | 0xaf5191b0de278c7286d6c7cc6ab6bb8a73ba2cd6 |

## Summary
<the one wrong assumption, plain language>

## Root cause
UlnConfigSet events show latest receive config for src eid 30334 (sophon): requiredDVNCount=1, requiredDVNs=[0x04830f6decf08dec9ed6c3fcad215245b78a59e1], confirmations=20, no optionals - on both TokenMessaging (0xaf368c91... unichain / 0xaf5191b0... hemi) and CreditMessaging (0xb1eead69... unichain / 0x45a01e4e... hemi).

## Attack
1. Compromise/misbehave as the single required DVN. 2. Attest a forged packet from eid 30334 claiming arbitrary TokenMessaging/CreditMessaging payload. 3. After the leg's confirmation window the ULN302 commits and the endpoint delivers the forged lzReceive.

## Impact
Auth: requires single-DVN key | Capital: whatever the pathway routes | Frequency: repeatable while config stands | Victims: bridge users on that leg

## Proof of concept
`forge test --fork-url <RPC> --fork-block-number <BLK> -vv`  → Read-only reproduction in poc/repro_findings.sh (getUlnConfig decode + event cites). No fork drain because no permissionless path exists.

## Fix
Raise sophon leg to the same req=3 set used on other pathways [0x07c05eab,0x282b3386,0x396dc0a7] and set sane confirmations.

## Disclosure & compensation
Good-faith private disclosure. I'd appreciate a bounty commensurate with a
High. I am NOT conditioning the disclosure or fix on payment act on it now.
Happy to walk the team through it and review the fix.
deviykee
