# Clanker (Robinhood Chain)

**Status:** HUNTED-NOTES (2026-07-21) — no permissionless High claimed  
**Report:** `reports/Clanker-hunt-notes.md`  
**X:** @clanker_world · **Site:** https://www.clanker.world · **Token:** $CLANKER ~$15–27M MC (user value rank #4)

## Chain defaults

```
CHAIN_ID  : 4663
RPC       : https://rpc.mainnet.chain.robinhood.com
EXPLORER  : https://robinhoodchain.blockscout.com
```

## Core contracts (from frontend `clanker_v4_robinhood` config)

| Role | Address | Codesize (hex chars) | Verified |
|------|---------|----------------------|----------|
| Factory `Clanker` v4 | `0xD3f2cC1731b7Fd17f28798835C2E02f0a1839A94` | ~24k | Yes (Sourcify match) |
| LP Locker `ClankerLpLockerFeeConversion` | `0x290F735F63824BB5836cDe24a35F5103A5B5Bc99` | ~49k | Yes |
| Vault extension | `0x99B2a80ed21c7af1F5cc1A97383DADeEC7DD1427` | ~7.5k | Yes |
| Airdrop V2 | `0x6f27372FF493A3855E6746b9a4fe6Ed2Cc3034B5` | ~9.5k | Yes |
| Eth DevBuy | `0xa27b1986e5c7e5371Cb6507f87918fBD0302fF5a` | ~13.5k | Yes |
| MEV Descending Fees | `0xEA1Fe197dF140e5d88fC6B49f2d21Ea05092299e` | ~7.4k | Yes |
| Fee Locker | `0x88db2340bE5991B2b5Fca2Baee39B5CE048Cd70c` | ~5.3k | Yes |
| Static Fee Hook V2 | `0x48B8F6AD3A1b4aA477314c9a23035b8F84dDe8cc` | — | Yes |
| Dynamic Fee Hook V2 | `0x65efDF8Cce99b53C925DF878Df275Df21cB6E8Cc` | — | Yes |
| WETH | `0x0Bd7D308f8E1639FAb988df18A8011f41EAcAD73` | — | — |

## Live state (2026-07-21)

- `deprecated()` = false  
- `owner()` = `0xEea96d959963EaB488A3d4B7d5d347785cf1Eab8`  
- `teamFeeRecipient()` = `0xFC535Ead4104177B70bf235D67Ab436d99788e04`  
- Factory ETH balance ≈ 0 (instant list; no raise custody)  
- High activity: many successful `deployToken` txs same day  

## Sources on disk

- `hunts/clanker/src/` — factory + token + interfaces  
- `hunts/clanker/related/{locker,vault,airdrop,devbuy,mev,feelocker,staticHook,dynamicHook}/`  
