# Coverage — PinkSale

Coverage: 5/8 files (62%) of verified production in this pass.
Traced locker + token-factory base. Presale impl + diamond facets unverified (not in Y).

Last updated: 2026-08-17 first-pass close

| File | Read? | Paths traced | Notes |
|------|-------|--------------|-------|
| src/pinklock02/contracts__PinkLock02.sol | yes | `lock`/`vestingLock`/`multipleVestingLock` → `_createLock` → unlock/edit/transfer | full read |
| src/pinklock02/contracts__IPinkLock.sol | yes | interface only | |
| src/pinklock02/contracts__FullMath.sol | yes | `mulDiv` used by vesting | Uniswap FullMath |
| src/bsc-pinklock-v1/contracts__PinkLock.sol | yes | `lock`/`unlock`/`editLock`/`initialize`/`_authorizeUpgrade` | UUPS, owner renounced on proxy |
| src/eth-pinklock-v1/contracts__PinkLock.sol | partial | compared as V1 sibling | shorter, no UUPS in this copy |
| repo/contracts/factories/token/TokenFactoryBase.sol | yes | `setImplementation`/`create` fee path | owner can swap impl |
| repo/contracts/factories/token/TokenFactoryManager.sol | partial | `assignTokensToOwner` onlyOwner factories | grep |
| repo/contracts/factories/token/StandardTokenFactory.sol | no | — | planned, no TVL |
| repo/contracts/factories/token/LiquidityGeneratorTokenFactory.sol | no | — | planned, no TVL |
| presale impl 0x07f635… | no | selectors + auth only | unverified |
| factory diamond 0x1EE773… | no | diamondCut Unauthorized | unverified |

## Explicitly excluded

| Path / area | Reason |
|-------------|--------|
| lib/** / OZ copies under src/pinklock02/@openzeppelin | vendored |
| repo token templates (`*Token.sol`) | user-created meme tokens, not platform custody |
| test/** | none in scope |
| 11 diamond facets | no Sourcify match this pass |

