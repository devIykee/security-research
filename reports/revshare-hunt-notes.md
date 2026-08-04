# RevShare (#4) - hunt notes (no High confirmed yet)

**Researcher:** deviykee  
**Date:** 2026-07-20  
**Status:** Partial. Live on Robinhood Chain, but the create/factory and graduation-source contracts that hold the real launch path are **not verified**. Token reward layer is verified and reviewed. No permissionless fund-steal proof without factory source. No mainnet exploit attempted.

---

## What we know (plain language)

RevShare is a multi-chain style app that includes Robinhood Chain (chain id 4663). Users launch tokens that can pay holder rewards and track a "graduation" progress bar toward a native ETH threshold (default 4 ETH on the token layer).

The pieces we could open:

- Marketing site: https://revshare.dev  
- Apps: https://app.revshare.ltd , https://app.revshare.dev  
- X: @revshare_app  

The **token** for sample launch "CashWolf" is verified. The **factory** that created it and the **graduation source** that reports curve liquidity are **not** verified. Without those sources we cannot responsibly claim a High migration/pool bug the way we could for Robinlaunch or Robinfun V2.

---

## INTAKE (known only)

```
PROJECT_NAME   : RevShare
X_HANDLE       : @revshare_app
WEBSITE        : https://revshare.dev
CHAIN          : Robinhood Chain
RPC            : https://rpc.mainnet.chain.robinhood.com
CHAIN_ID       : 4663
EXPLORER       : https://robinhoodchain.blockscout.com
KNOWN_ADDRS    :
  sample_token_CashWolf=0x06e88c10b600b175d39498D8fDFFe04a4C240133
  token_owner=0xCE93d71da3C946fC2Fb2434bd7DaA0c7c7D2D5fA
  factory_creator_unverified=0x37584357aDeaDab1083B17Dd60D5Ad3a44c8a9e3
  graduation_source_unverified=0x5728721F8E71094Cd3EDa799ad43b5fe5EF109AE
  taxable_token_sample=0xDc915668e68A6a1C56F71361C857689b8C2A1762
PRODUCT_TYPE   : launchpad
RESEARCHER     : deviykee
```

Live reads on sample token: `graduationThreshold = 4 ETH`, `getCurve ≈ 0.117 ETH`, `isGraduate = false`.

---

## Verified surface reviewed

### RevShareGraduationToken / RevShareHolderRewardToken (from token additional sources)

- Graduation on the token is mostly a **flag**: `checkGraduation()` sets `isGraduate` when `graduationSource.graduationNativeLiquidity() >= threshold`. It does **not** by itself move the raise into a DEX pool in this file.
- Holder rewards: multi-asset streams, 7-day drip, max 16 assets, depositor-gated deposits, owner exclusions until lock.
- Claim uses push ETH (`call{value}`) for native / unwrap paths: possible **Medium grief** if a holder is a contract that rejects ETH (their own claim fails; not protocol drain).
- Owner can exclude addresses from rewards until `lockRewardExclusions`.
- Native donations to `receive()` are unsolicited; comments say use `depositNativeRewards`.

### Not available

- Factory bytecode at `0x3758…a9e3` (create path): **unverified**, selectors not fully mapped to public ABI.
- Graduation source `0x5728…09AE`: **unverified**, has `owner()`, returns live liquidity figure, nonpayable mutators present. This is the contract that actually represents native-side liquidity for graduation math.

---

## Findings (honest)

| ID | Severity | Title | Status |
|----|----------|--------|--------|
| RS-1 | Info / Trust | Core factory and graduation-source contracts unverified | Confirmed |
| RS-2 | Trust | Token owner + reward depositor centralization on reward accounting | By design |
| RS-3 | Medium (conditional) | Native reward claim push can fail for rejecting contracts | Theoretical / grief |

**No High / Critical permissionless theft proven** on RevShare with current evidence.

---

## Next steps to finish RevShare

1. Get verified source for factory `0x3758…` and graduation source `0x5728…` (team, Sourcify, or decompile carefully).
2. Audit create + liquidity seed for V3/V4 pool squat (`createAndInitializePoolIfNecessary` + zero mins), same class as Robinlaunch/Openfair.
3. Auth triage all nonpayable selectors on graduation source as attacker via `cast call`.
4. If a High appears, write full report + DM in Iyke style.

---

## Do not send a "we found Critical" DM yet

Until factory/source is readable, a disclosure DM would overclaim. Prefer asking the team for source, or continue offline decompile.

deviykee
