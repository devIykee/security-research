# Flap (Robinhood Chain)

**Status:** HUNTED-NOTES (2026-07-21) — no High PoC this pass  
**Report:** `reports/Flap-hunt-notes.md`  
**Site:** https://flap.sh · docs https://docs.flap.sh · Val#12 / #28

## Core (RH mainnet, 4663)

| Role | Address |
|------|---------|
| Portal (proxy) | `0x26605f322f7fF986f381bB9A6e3f5DAb0bEaEb09` |
| Portal impl | `0xd9C9981D784A3765D8264D6104650B901C4e36b1` |
| Portal ETH (approx) | ~60 ETH at hunt time |
| uniV3Migrator (immutable) | `0xa80cc552c2b425715d73dbb3f71e754788377dd4` |
| uniV2Migrator | `0x40373043d4a672c55f1dde0ae137e9da4ab37083` |
| tokenLauncher | `0x662575ba5540af30531b1f1acb852c81e2ada2a9` |
| tokenTradeV2 | `0x362fd190fa57ea181b85c86df2e5b2113c2834c7` |
| portalDexRouter | `0x6f8de19af17c3622af9342930f8f459e429f31f7` |
| V4 PoolManager | `0x8366a39CC670B4001A1121B8F6A443A643e40951` |
| V4 PositionManager | `0x58daec3116aae6D93017bAAea7749052E8a04fA7` |
| WETH | `0x0Bd7D308f8E1639FAb988df18A8011f41EAcAD73` |
| token impl (non-tax) | `0x88882688a067FE97E11C2185b996286e53132222` |
| tax token V3 | `0x7777C8743c88B3aff3cf262135beF2c8b2e83333` |
| swapRegistry | `0x35Bae0b77753a586f68f9C4CD0E8d1a468169031` |

Config from frontend `main-app-*.js` robinhood chain block (`portal`, vanity 8888 / tax 7777).

Sources: Portal (+Base/Common) verified Sourcify. Migrator facets have bytecode, **not** verified on RH Blockscout/Sourcify this pass.
