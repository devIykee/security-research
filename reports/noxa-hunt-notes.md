# Noxa / Rain.fun — hunt notes (no High)

**Researcher:** deviykee  
**Date:** 2026-07-21  
**Severity:** Notes  
**Val#13 / #31**

## Sites

| URL | Status |
|-----|--------|
| https://noxa.fi | “Coming soon” splash |
| https://noxa.fun | Landing rebranded as **Rain.fun — Live Now** (marketing only; no factory addr in HTML) |
| https://rain.fun | Next.js app live (separate product surface to map later) |

## On-chain candidate factory

Creator of verified `Noxa` token `0x39E0…c56E`:

| Role | Address |
|------|---------|
| Launch contract (unverified) | `0xD9eC2db5f3D1b236843925949fe5bd8a3836FCcB` |
| Owner | `0x7E035Fb048a31e0481b88074557415b1C187242B` |
| ETH balance | 0 |

Selectors (4byte): `launchToken`, `launchEnabled`, `getLaunchConfig`, `createPool`, `initialize(uint160)`, whitelist launcher, launch fee.

### Live state

```
launchEnabled() = false
getLaunchConfig(0) = (WETH, 0, tick -204200, supply 1e27, …)
getLaunchConfig(1) reverts InvalidLaunchConfigId
```

**Launches disabled.** No permissionless High on a closed factory this pass.

## Residual

- Re-open if `launchEnabled` flips true or Rain.fun ships a new verified factory.  
- Instant V3 path (`createPool` + `initialize`) is the class to re-test first (same family as Bow/Merry Men).

deviykee
