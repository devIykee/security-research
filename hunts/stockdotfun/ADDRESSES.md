# StockDotFun / stock.fun — addresses (Robinhood Chain 4663)

**Website:** https://stockdotfun.com (stock.fun DNS dead)  
**Researcher:** deviykee  
**Date:** 2026-07-20

| Role | Address |
|------|---------|
| StockDotFunFactoryV2 | `0x470aca74d71269833de8cf65640dfb558393569e` |
| GraduationManager | `0x408fA5743a43de08C596169B58f11E303026D835` |
| UniswapV4GraduationAdapter | `0x74993f85f42ba26d613c37cb82b0c5f586a22d39` |
| V4LiquidityLocker | `0x19f19e9e6b414e0e128597289dda4c218d9c7aa1` |
| StockRewardTreasury | `0x284c47ef1754fa82b85cbe8207dd749e6f9ca389` |
| StockRouteRegistry | `0xf1c7181324dec91bf0fb94a2f05608927e06b97c` |
| Owner | `0xCBC88Ba92a79bd1EC8D11886c20FB1087b7572b6` |
| WETH | `0x0Bd7D308f8E1639FAb988df18A8011f41EAcAD73` |
| Router (frontend) | `0xee348959309506e9c9ec302fa449b25b767ff51b` |
| Sample token[0] | `0xc8a5345bfd37f5edd92684ccfebf8a9f35249957` |
| Sample pool[0] | `0x63760d1926205706c614500617380d51ef6b7f25` |
| Uniswap V4 PoolManager (locker) | `0x8366a39cc670b4001a1121b8f6a443a643e40951` |
| Locker feeRecipient | `0x988a17f089f057b3364f2ae1f4756e4cc09bde86` |

**Curve (factory):** fee 100 bps, virtualQuote 3 ETH, graduationTarget 4.4 ETH, gradFee 10000, tickSpacing 200.  
**allTokensLength:** 11 (sample pools mostly ACTIVE with small realQuote; largest sample ~0.063 ETH when checked)

**Finding:** High — V4 pre-init freezes graduation. Report: `reports/StockDotFun-High-V4-preinit-graduation-freeze.md`  
**PoC:** `hunts/stockdotfun/poc` — `forge test --match-contract V4PreInitGraduationFreezeTest -vv`
