# MetaLaunch — addresses (Robinhood Chain 4663)

**Website:** https://metalaunch.fun  
**Researcher:** deviykee · **Date:** 2026-07-20

| Role | Address | Verified |
|------|---------|----------|
| Factory V12 (current) | `0x1B2A2ee9E66862e6323B0D43b26f60235214660A` | yes |
| Locker V11 | `0x68BE04B93F732B7ed4dA06305EC0A7a82e456092` | partial |
| Token deployer V12 | `0x543293FE04C84FedFBf008b9889f294FDb158070` | yes |
| Factory V11 | `0x76f1d938d4917B615eaC478754951Ed4aa92420C` | yes |
| Factory V6 | `0x6813de2fC38775f7E1c311645aFE03E6315CC0DE` | yes |
| Pad V5 (FoundryLaunchpad) | `0x49A3D384cd90A58815df31C1852dB4095B90c0De` | yes |
| MetaLocker V3–V6 | `0x49A955A2818069C4320b52602deF1706411bC0De` | yes |
| Owner / treasury (docs) | `0x4F298f5991661150Ee85A5b0690653D13e0fc42c` | n/a |
| WETH | `0x0Bd7D308f8E1639FAb988df18A8011f41EAcAD73` | — |
| Uni V3 factory | `0x1f7d7550B1b028f7571E69A784071F0205FD2EfA` | — |
| NPM | `0x73991a25C818Bf1f1128dEAaB1492D45638DE0D3` | — |
| Swap router | `0xCaf681a66D020601342297493863E78C959E5cb2` | — |

**Report:** `reports/MetaLaunch-hunt-notes.md`  
**Key mitigation (V12):** `TickMisaligned` after `createAndInitializePoolIfNecessary` + salt requires `getPool==0`.
