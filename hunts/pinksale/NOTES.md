# PinkSale hunt notes (weaker-audits-iyke)

First pass against `protocols_by_weaker_audits.md` rank 37 (`no-audits`, ~$143M TVL, launchpad). DefiLlama TVL is PinkLock vault balances, not live presale ETH.

## INTAKE
See `INTAKE.md`. Researcher: deviykee.

## Step 1
- ETH `https://ethereum.publicnode.com` chainId 1 PASS (block ~25774923)
- BSC `https://bsc.publicnode.com` chainId 56 PASS (block ~116467637)

## Step 2 cores
Frontend is Cloudflare-gated (bundle grep failed).

Lockers (DefiLlama adapter):
| Chain | Role | Address | Verified |
|---|---|---|---|
| BSC | PinkLock02 (main) | `0x407993575c91ce7643a4d4cCACc9A98c36eE1BBE` | Sourcify exact, `PinkLock02` |
| BSC | PinkLock V1 proxy | `0x7ee058420e5937496F5a2096f04caA7721cF70cc` | ERC1967, impl below |
| BSC | PinkLock V1 impl | `0xB9abf98CAB2c8bd2aDF8282e52bf659aDb0260Fe` | Sourcify `PinkLock` UUPS |
| ETH | PinkLock02 | `0x71B5759d73262FBb223956913ecF4ecC51057641` | same `PinkLock02` |
| ETH | PinkLock V1 | `0x33d4cC8716Beb13F814F538Ad3b2de3b036f5e2A` | Sourcify `PinkLock` |
| docs | `0x5E5b9bE5fd939c578ABE5800a90C566eeEbA44a5` | no code on ETH/BSC |

Live BSC launchpad (homepage #1 DAPPS):
- pool clone `0x4B6211013Bc0Be572dEE127a3E06ca9Fb5b3434F` (EIP-1167, 1.45 BNB)
- impl `0x07f6351491b694f3a04c5f1e47d151d4ad927d45` (18227 bytes, **unverified**)
- factory diamond `0x1EE7736987F2ebD0f519ec5858b2b3BC6Fd0c6a0` (unverified, EIP-2535)
- feeTo `0x2e6C8927285353F24A00fcBAF605C54E2E18ea83`
- router `0x10ED43C718714eb63d5aA57B78B54704E256024E` (Pancake V2)
- owner `0xfc779C5004B95b4817d8A8edEcD808D0D184572C`

Public GitHub `pinkmoonfinance/pinksale-contracts` is **token templates + token factories only**, not lock/presale.

## Step 3
PinkLock02: 702708 locks, 265408 tokens, 241980 LP tokens. No native balance (ERC20/LP custody).

## Step 4 auth triage (live pool from 0xdead)
| Fn | Result |
|---|---|
| finalize / cancel / setTime / setEndTime / distributePurchasedTokens / distributeRefund / withdrawCancelledTokens / updatePoolDetails | `Only operator` |
| emergencyWithdraw / updateKycDetails | `Only governance` |
| factory `diamondCut` | `Unauthorized` |
| claim | `Owner has not closed the pool yet` (public after close) |
| withdrawContribution | `Pool is still in progress` (public after end, not a drain) |
| transferOwnership / renounceOwnership | `Ownable: caller is not the owner` |
| transferCurrency / recordContribution / register / withdraw | revert (not open) |

No OPEN money-mover.

V1 impl `upgradeTo` from stranger: `Function must be called through delegatecall` (OZ UUPS guard). Brick-via-impl **killed**.
V1 proxy `owner() == 0`, `poolManager == 0`, `fee == 0` (renounced).

## Step 5 foundation (PinkLock02)
- Who-writes: no admin. Only lock owner can unlock / edit (amount up, date later only) / transfer ownership.
- CEI: unlock updates `unlockedAmount` + cumulative book **before** `safeTransfer`.
- Token path: `transferFrom` exact-amount check on deposit; unlock sends book amount.
- Pause/upgrade: none on V2.

Checklist:
- Reentrancy: PASS (CEI)
- Access control privileged: PASS (no privileged drain)
- Oracle: N/A
- Slippage on DEX: N/A in locker (presale finalize unverified)
- Init/proxy V2: PASS (not a proxy)
- V1 upgrade: Trust (proxy owner renounced; impl UUPS direct-call blocked)
- Pause: N/A
- Events: PASS on lock/unlock/edit/owner change

## Step 5.5 killed paths
1. Permissionless unlock / drain locker → blocked by `owner == msg.sender` + time.
2. Shorten unlock via `editLock` → require new date >= old.
3. FoT donation / share inflation → exact-amount deposit; no shares.
4. First-lock `isLpToken` mis-flag → index/UI only, not theft.
5. V1 uninit UUPS selfdestruct → impl initialized + upgrade must be delegatecall.
6. Open `diamondCut` → Unauthorized.
7. Open finalize / transferCurrency / emergencyWithdraw → operator/governance.
8. `renounceLockOwnership` to 0 → lock-owner choice, permanent lock, not stranger.

## Step 6 launchpad questions
- Graduation/migration: operator `finalize` on unverified impl. Cannot confirm `amountMin=0` / pool squat without source. Operator-gated so not a stranger v3-squat unless operator is unprivileged (not shown).
- LP lock: finalize should call PinkLock02; cannot confirm from source.
- Fee split: factory `feeTo` set.
- Anti-snipe: token templates + antibot contracts in public repo; out of locker scope.
- Token transfer restrictions: docs tell owners to exclude PinkLock/presale from tax. Accounting-safe on deposit via exact-amount.

## Honest bound
No permissionless Critical on examined paths.
Trust: operator/governance can finalize, cancel, emergency-withdraw, and (diamond owner) replace facets.
Coverage incomplete on unverified presale impl / diamond facets.

Live DAPPS pool storage (clone): slot0 packed owner `0xfc779C…` + init=1; slot1 factory; slot2 Pancake router; slot9 likely sale token `0x34cc72f9…`; start `getTime` 2026-08-12 12:00 UTC (still in progress as of 2026-08-17). Diamond facets not on Sourcify.

No Step 7/9 this pass.
