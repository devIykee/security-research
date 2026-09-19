# First DM to Argus Team

## For Twitter/X DM or Email

---

Hey Argus.

I'm Iyke, a security researcher. (http://x.com/deviykee)

I've found and verified a CRITICAL vulnerability in Argus's token graduation flow on Arc Chain that allows an attacker to steal 100% of graduation liquidity with zero capital (only gas fees). It's live-exploitable right now on every un-graduated token, so it's time-sensitive.

I reproduced it on an Arc Chain mainnet fork with working PoCs, nothing was touched on-chain.

I want to share the full private write-up with whoever owns the contracts.

Who's the right person, or who do I talk to on the team?

---

## Notes

- **Severity**: CRITICAL (CVSS 9.8)
- **Attack cost**: $0 (only gas)
- **Scope**: Every token using Argus graduation
- **Proof**: Fork testing completed, 2 working PoCs
- **Ethics**: Read-only analysis, no mainnet interaction

## Next Steps After Reply

When they respond and want details:
1. Share the full report: `reports/REPORT.md`
2. Share PoC code: `poc/test/PoolSquatExploit.t.sol`
3. Offer to walk through the vulnerability
4. Assist with fix implementation and review

**Do NOT** share these publicly until the fix is deployed.
