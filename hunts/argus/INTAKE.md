# INTAKE - Argus Launchpad Bug Hunt

```
PROJECT_NAME   : Argus
X_HANDLE       : (to be found in Step 10A)
WEBSITE        : https://argus.world
DOCS           : (none found)
SECURITY_EMAIL : (to be found in Step 10A)
DISCLOSURE     : discretionary
CHAIN          : Arc Chain
RPC            : https://rpc.mainnet.arc.io
CHAIN_ID       : 5042
EXPLORER       : https://explorer.mainnet.arc.io
KNOWN_ADDRS    : token=0xeCe5cA8bf9220718E5727754026757512212cb3c, implementation=0x122c82cfca7a3a2227285cc21f4522e8f551db3a, owner=0x7d613c6316eDe9d257f3BF512777Cb4Ea4A6beE4
PRODUCT_TYPE   : launchpad
BOUNTY/CONTEST : none / discretionary
NOTES          : Bonding curve → Uniswap V3 graduation pattern (pump.fun style)
RESEARCHER     : deviykee
```

## Hunt Progress

- [x] Step 1: Ground truth (RPC confirmed, Chain ID 5042)
- [x] Step 2: Core contracts located (token + implementation via proxy pattern)
- [x] Step 3: Surface map (contracts unverified, bytecode decompiled 1.2MB)
- [x] Step 4: Auth triage (access control properly implemented)
- [x] Step 5: Foundation map (graduation flow mapped, portal delegation pattern)
- [x] Step 6: Bug-class detection (Pool Squat vulnerability confirmed)
- [x] Step 7: PoC development (Working fork test, 2/2 tests passed)
- [x] Step 8: Severity assessment (CRITICAL - CVSS 9.8)
- [ ] Step 9: Report writing (using skill methodology)
- [ ] Step 10: Disclosure (find contacts, prepare DM)
