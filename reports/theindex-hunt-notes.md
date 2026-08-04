# The Index (theindex.finance) — hunt notes

**Researcher:** deviykee  
**Primary skill:** `duke-web3-bug-hunting`  
**Secondary skill:** `duke-web3-bug-hunting-dukedotsol` (methods only; reports signed deviykee)  
**Date:** 2026-07-21  

## Status

| Item | Status |
|---|---|
| Target real on Robinhood Chain (4663) | yes |
| Core: USDGBuyerDistributor | `0x2459DedB3012d1E929EdD17DF26620120bDF11bf` |
| INDEX ReflectionToken | `0x56910D4409F3a0C78C64DD8D0545FF0705389870` |
| Finding | permissionless live-balanceOf snapshot (flash-inflatable) |
| Local PoC | PASS (`LocalFlashSnapshotTest`) |
| Full multi-holder fork distribute | deferred (RPC slow / 2.4k holders); skill Step 7 allows exact-logic local + on-chain magnitude |
| Report | `TheIndex-High-flash-inflated-snapshot.md` |
| First DM | `dm-theindex.md` → @TheIndexFi |
| Mainnet exploit | NEVER |

## INTAKE

```
PROJECT_NAME   : The Index (theindex.finance)
X_HANDLE       : @TheIndexFi
WEBSITE        : https://theindex.finance
CHAIN          : Robinhood Chain
RPC            : https://rpc.mainnet.chain.robinhood.com/
CHAIN_ID       : 4663
PRODUCT_TYPE   : distribution/index
BOUNTY/CONTEST : none / discretionary
RESEARCHER     : deviykee
```

## Key on-chain reads (session)

- interval 900s, 18 stocks, ~2440 holders, minShare 10k INDEX  
- PM excluded, holds ~25M+ INDEX (flash-source shape)  
- Admin: guarded. Crank: permissionless by design  
- canStart observed true in windows between cycles  

## PoC commands

```bash
cd /root/coding/secres/poc-theindex
forge test --match-contract LocalFlashSnapshotTest -vvv
# optional fork (needs healthy RPC / anvil cache):
# forge test --match-contract ForkFlashSnapshotPoC -vvv --fork-url $RPC
```

## Severity call

**High** (not Critical): permissionless theft but **bounded** per cycle by pot size and flash/eligible ratio. Do not round up unless pot TVL and proven share are large.

## Next

1. Private DM to @TheIndexFi using `dm-theindex.md`  
2. Share report + `poc-theindex` privately after they reply  
3. Do not public post until patched  
