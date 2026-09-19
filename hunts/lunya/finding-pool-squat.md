# Critical Finding Investigation - Pool Squat on Graduation

## Vulnerability Pattern
From bug-class detection playbook (Step 6.5, item #1):
**Migration pool squat (v3).** Graduation calls pool creation and mints liquidity with NO post-init price check. 
→ attacker pre-creates the pool at a fake price, graduation dumps the raise into it at wrong price.

## Lunya's Claimed Defense
From docs: "Graduation reverts if the target pool already exists, preventing attackers from creating pools first"

## Questions to Verify
1. Does the graduation flow actually check if pool exists BEFORE calling lister?
2. Can the lister be bypassed? Is there a Public Lister that allows anyone to create pools?
3. What happens if graduation proceeds but the pool was already created?
4. Is the price check AFTER pool creation sufficient?

## Contract Addresses to Test
- **Public Lister**: 0x82eaca02d46b0663d9af54b643d4e0f01f73c0de (allows anyone to list concentrated pools)
- **Terms Lister**: 0x3d9c0db2d81188726f5a4b3823ca4fa8ae2fff38 (lists pools under governance terms)
- **Pool Factory**: 0x711492df23f320745de6fd7f0ab9564fdbfea016

## Test Plan
1. Check if Public Lister allows creation of CP (constant-product) pools
2. If yes, test attack: pre-create pool with fake price before a token graduates
3. Verify if graduation checks pool existence or just trusts lister
4. Check if price verification happens AFTER liquidity is added (too late)

## Status
**Docs claim this is mitigated**: "On this deployment, constant-product pools aren't open to public listing"
→ Need to verify this on-chain by testing Public Lister capabilities
