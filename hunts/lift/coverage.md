# Coverage — Lift (PlayFi Node License Sale)

Coverage: 4/8 files (50%). Core contracts: 4/4 (100%).

Last updated: Complete (2026-09-16)

| File | Read? | Paths traced | Notes |
|------|-------|--------------|-------|
| contracts/PlayFiLicenseSale.sol | yes | All claim functions (team, F&F, early, partner, public, whitelist), referral system, tier management, payment flow, admin functions | COMPLETE - Found 2 Medium + 1 Low |
| contracts/PlayFiLicense.sol | yes | mint(), _beforeTokenTransfer (transfer blocking), tokenURI generation, access control | COMPLETE - Safe |
| contracts/PlayFiLicenseMint.sol | yes | mintLicenses(), EIP-712 signature verification, merkle proof, cross-chain logic | COMPLETE - Safe |
| contracts/PreOrderLicenseClaimer.sol | yes | claimPreOrders(), batch claiming, withdraw | COMPLETE - Safe |
| contracts/interfaces/IPlayFiLicenseSale.sol | no | - | Interface (not security-critical) |
| contracts/interfaces/IPlayFiLicense.sol | no | - | Interface (not security-critical) |
| contracts/interfaces/IPlayFiLicenseMint.sol | no | - | Interface (not security-critical) |
| contracts/interfaces/IPreOrderLicenseClaimer.sol | no | - | Interface (not security-critical) |

## Explicitly excluded

| Path / area | Reason |
|-------------|--------|
| test/** | Test files (not in audit scope) |
| deploy/** | Deployment scripts (not in audit scope) |
| scripts/** | Utility scripts (not in audit scope) |
| node_modules/** | Dependencies |
