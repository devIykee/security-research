# Coverage — Aumo

Coverage: 5/5 custom contract implementation & interface files reviewed and traced (100%).
Opened: 5. Traced: 5. PoC suites: 7 (100 unit/scenario tests passing).

Last updated: 2026-08-10 after multi-angle audit, residual triage, and critical push pass.

Denominator Y = unique Aumo-custom production implementations (not OpenZeppelin/Forge-Std vendor libraries).

| File | Read? | Paths Traced | Notes / Findings |
|------|-------|--------------|------------------|
| `src/AumoPool.sol` | yes | `deposit`/`mint`, `withdraw`/`redeem`, `_ensureIdle`, `totalAssets`, `allocate`, `deallocate`, `_doDeallocate`, `setPolicy`, `setLossBudget`, `setDeployBudget`, `setVenueAllowed`, `removeVenue`, `forceRemoveVenue` | H-1 (stuck venue in totalAssets), H-2 (loss budget double-counting on allocate), H-3 (zero withdraw wipes principal), H-4 (maxWithdraw overstates liquid), M-1 (balanceOf revert bricks ensureIdle), M-2 (gross vs supplied accounting), M-3 (epoch counter coupling), M-5 (default maxEpochDeploy=0), L-1, L-2, L-3 |
| `src/AumoVault.sol` | yes | single-owner vault base; `deposit`, `withdraw`, `allocate`, `deallocate`, access controls, pause/unpause | Base single-owner implementation. Access controls tested in `AumoVaultAccess.t.sol` |
| `src/adapters/AaveV3Adapter.sol` | yes | `supply`, `withdraw`, `balanceOf`, `realizableBalance`, `underlying` | Direct supply/withdraw to Aave v3 pool; token conversion 1:1 |
| `src/adapters/RwaUsdgAdapter.sol` | yes | `supply`, `withdraw`, `balanceOf`, `realizableBalance`, `_swap`, `emergencyWithdraw`, `setMaxSlippageBps`, `setValuationDiscountBps` | H-5 (permissionless sandwich on redeem-path USDG swap), M-4 (discounted balanceOf vs face), L-4 (missing events on param setters) |
| `src/interfaces/IVenueAdapter.sol` | yes | adapter interface methods and return semantics | Interface definition |

## Scripts & Deployment Coverage

| Path | Read? | Traced | Notes |
|------|-------|--------|-------|
| `repo/contracts/script/DeployPoolMainnet.s.sol` | yes | yes | Mainnet pool deployment script; allowlists Aave + USDG |
| `repo/contracts/script/DeployMainnet.s.sol` | yes | yes | Single-owner vault deploy script |
| `repo/contracts/script/DeployPoolTestnet.s.sol` | yes | yes | Testnet deployment script |

## Excluded (Vendored)

| Path / Area | Reason |
|-------------|--------|
| `@openzeppelin/contracts/**` | Standard audited OpenZeppelin v5 libraries (ERC4626, ERC20, SafeERC20, Ownable2Step, ReentrancyGuard, Pausable) |
| `forge-std/**` | Foundry testing framework |

## PoC Test Suites Summary

| Test File | Tests | Focus Area | Result |
|-----------|-------|------------|--------|
| `poc/AumoPool_Residual.t.sol` | 2 | R1 (stuck venue preferential exit), R2 (balanceOf revert DoS) | 2/2 PASS |
| `poc/AumoPool_LogicBugs.t.sol` | 8 | L1-L8 logic flaws (gross book, silent zero withdraw, maxWithdraw) | 8/8 PASS |
| `poc/AumoPool_RedeemSandwich.t.sol` | 3 | H5 (permissionless redeem sandwich on USDG retreat) | 3/3 PASS |
| `poc/AumoPool_CriticalHunt.t.sol` | 10 | Deep search for permissionless drain / first-depositor / FoT | 10/10 PASS |
| `poc/AumoPool_CriticalPush.t.sol` | 4 | Critical-class push (dust lastPass, stranger profit bounds) | 4/4 PASS |
| `poc/AumoPool_DustLastPass.t.sol` | 2 | Dust redeem lastPass full liquidation mechanics | 2/2 PASS |
| `poc/AumoPool_AdversarialAngles.t.sol` | 12 | Multi-angle adversarial review (drain, freeze, desync, DoS) | 12/12 PASS |

**Total Suite Result:** 100 passed, 0 failed, 2 skipped across 12 test suites.
