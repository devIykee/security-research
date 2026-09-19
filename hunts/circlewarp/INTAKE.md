# CircleWarp Hunt - INTAKE

```
PROJECT_NAME   : CircleWarp (Warp)
X_HANDLE       : @circlewarp
WEBSITE        : https://circlewarp.fun/
DOCS           : (searching)
SECURITY_EMAIL : (to be determined in Step 10A)
DISCLOSURE     : discretionary
CHAIN          : Arc (Circle's USDC-native L1)
RPC            : https://rpc.mainnet.arc.io
CHAIN_ID       : 5042 (verified)
EXPLORER       : https://explorer.arc.io
KNOWN_ADDRS    : LaunchpadFactory=0x34988939648578a1d90Db742bc1C903fD6F7c1b0, WarpV4PoolManager=0x8366a39cc670b4001a1121b8f6a443a643e40951 (5.2M USDC), V4Router=0x53bf6b0684ec7ef91e1387da3d1a1769bc5a6f77, V2Router=0x33c2bfa0684342b210b62ca7e92abe3fecb0bfa3, BridgeReceiver=0x2093c42161793eC793a0d7b818e786e61D58074d
PRODUCT_TYPE   : launchpad
BOUNTY/CONTEST : none known / discretionary
NOTES          : Bonding curve launchpad with graduation to V4 DEX. Unverified contracts. Key functions: createToken, buy, sell, migrate (graduation), virtualUsdc reserves, graduationMcap threshold, fee collection (protocol + creator).
RESEARCHER     : deviykee
```

## Status
- [x] Step 1: Ground truth (RPC/chain verification) - PASS (chainId=5042, block=21177335)
- [x] Step 2: Locate core contracts - Found LaunchpadFactory at 0x34988939648578a1d90Db742bc1C903fD6F7c1b0
- [x] Step 3: Surface map - Unverified, mapped 66+ selectors
- [ ] Step 4: Auth triage
- [ ] Step 5: Foundation map
- [ ] Step 6: Attack questions
- [ ] Step 7: PoC
- [ ] Step 8: Severity
- [ ] Step 9: Report
- [ ] Step 10: Disclosure
