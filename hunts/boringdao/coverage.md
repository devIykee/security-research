# Coverage — BoringDAO

Coverage: 2/42 files (5%). Path-scoped. Not a full audit.

Last updated: 2026-08-15 after tunnel + CrossLock pass

| File | Read? | Paths traced | Notes |
|------|-------|--------------|-------|
| repo/contracts/TunnelV2.sol | partial | pledge/redeem onlyBoringDAO, lock duration | first 200 lines |
| repo/contracts/bsc/CrossLock.sol | yes | lock public, unlock CROSSER_ROLE, txid replay | full read |
| repo/contracts/BoringDAOV2.sol | no | | planned |
| repo/contracts/MintProposal.sol | no | | planned |
| repo/contracts/BurnProposal.sol | no | | planned |

## Explicitly excluded

| Path / area | Reason |
|-------------|--------|
| repo/contracts/fake/** | test fakes |
| repo/contracts/interface/** | interfaces |
| repo/contracts/gov/** | governor |
