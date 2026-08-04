# Merry Men / PumpClaw (Robinhood Chain)

**Status:** HUNTED-HIGH (2026-07-21)  
**Report:** `reports/MerryMen-High-V4-preinit-factory-freeze.md`  
**DM:** `reports/dm-merrymen.md`  
**Site:** https://www.merrymen.fun  

## Contracts

| Role | Address |
|------|---------|
| Factory | `0xfa4B952c15BC9d418ae4f552F7Fc76b4470596fE` |
| LP Locker | `0xd404C0fF8dE11841a4ff9CC4382eA5F6e4010751` |
| PoolManager | `0x8366a39CC670B4001A1121B8F6A443A643e40951` |
| PositionManager | `0x58daec3116aae6D93017bAAea7749052E8a04fA7` |

## PoC

```bash
cd hunts/merrymen/poc
forge test --match-contract CreateAfterPreInitTest --fork-url <anvil-or-rpc> -vv
```
