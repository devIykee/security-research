# Master findings table - Cosmos EVM cluster hunt (2026-08-25)

| ID | Severity | Status | Project | Component | Title |
|----|----------|--------|---------|-----------|-------|
| MZ-01 | Med-High (conditional) | OPEN, reportable | Mezo MUSD | PriceFeed.sol:14,46-58 | Single-oracle 60s staleness gate fails closed: outage reverts borrows, liquidations AND closeTrove while bad debt accrues |
| MZ-02 | Medium | OPEN, reportable | Mezo Tigris | Voter.sol:574-584 + Gauge.sol:110-119 | Emissions distributed to zero-supply gauges are permanently bricked (no totalSupply gate, killGauge sweep misses gauge balance) |
| MZ-03 | Medium (trust) | OPEN, note | Mezo MUSD | PCV.sol:296-300, MUSD.sol:46-83 | Persistent ERC20 allowance to council-set feeRecipient; mintList behind 1-step Ownable, no timelock |
| MZ-04 | Low-Med | OPEN, note | Mezo Tigris | rewards/Reward.sol:297-300 | Fee-on-transfer reward tokens credited gross; last-epoch claimers shorted |
| MZ-05 | Low | OPEN, note | Mezo Tigris | ManagedNFT.sol:136-153 | Current-epoch managed rewards stranded on withdrawManaged |
| MZ-06 | Low | KILLED (live) | Mezo Tigris | ChainFeeSplitter needle config | needle()=60 on mainnet, in-range; code-level footgun only |
| SM-01 | Critical-candidate | KILLED on public main | cosmos/evm shared | staking precompile + balance mirror | Over-delegate vesting acct -> SubBalance underflow -> 2^256 balance. state_object.go:152 panics; baseapp.go:801 recovers atomically. Incident fixes live in private chain forks |
| SM-02 | Critical-candidate | KILLED | cosmos/evm shared | SpendableCoin negative wrap | sdk Coin.SubAmount panics on negative before uint256 conversion |
| SM-03 | DoS candidate | DOWNgraded | cosmos/evm shared | poisoned vesting addr panic | recovered in runTx, atomic fail, self-inflicted, temporary |

Live verifications 2026-08-25 (RPC mezo-mainnet.boar.network, block ~11.38M):
- priceoracle precompile updatedAt == block.timestamp (per-block updates; kills routine-brick variant of MZ-01)
- MUSD totalSupply = 30,870,831.17 mUSD
- ChainFeeSplitter needle = 60

Disclosure posture: MZ-01/MZ-02 worth private disclosure to Mezo (security contacts via mezo-org/audits repo + docs). No live-exploitable theft found this session; nothing requires emergency contact.

## Round 2 - full-cluster sweep (2026-08-25)

| ID | Severity | Status | Project | Component | Title |
|----|----------|--------|---------|-----------|-------|
| MT-01 | Medium | OPEN, reportable | MANTRA | AlgebraEternalFarming.sol:241-248,169-187 | setRates/deactivateIncentive bind only to INCENTIVE_MAKER role, not incentive ownership: any maker can max-rate-drain or kill any other maker's live incentive |
| SG-01 | Med-High LATENT | OPEN (precondition unmet) | Saga Mustang | BorrowerOperations.sol:206,247 vs :407-499 | openTrove paths missing isBranchActive guard: after first governor branch removal, fresh Bold can be minted against delisted collateral; also blocks permanent cleanRemovedCollaterals. Live check 2026-08-25: all 8 branches ACTIVE, never removed |
| SG-02 | Medium (trust) | note | Saga Mustang | CollateralRegistry.sol:363-376 | Single governor EOA mutates MCR/CCR/SCR/debtLimit instantly, no timelock |
| MT-02 | Medium (trust) | note | MANTRA | SedaPriceStore | Relayer can push future timestamps (defeats downstream 600s staleness guards); no deviation bounds; UUPS owner-upgradable price layer under RWA chain |
| IN-01 | Info/Low | note | Initia | ConnectOracle.sol:16,22 | cosmosContract state var never set: get_all_currency_pairs() permanently reverts on zero address |
| MZ-07 | Low | OPEN, note | Mezo Tigris | Delegation.sol:208-214 + ManagedNFT.sol:99/200 | Delegatee credit drift on withdrawManaged (undercount, clamp hides); dead-delegatee burn strands delegated votes |
| KI-INT | intel | documented | KiiChain | commit b9be591a7 | Aug-4 fix re-blocked gov module for statedb mirroring = chains were patching this class pre-incident; validates shared-module mirror fragility |

## Cluster verdict

No Critical found across all seven projects this session. Every Critical candidate was killed with a named mechanism:
1. Shared-module over-delegate underflow -> panic + atomic revert (state_object.go:152, baseapp.go:801)
2. Negative SpendableCoin wrap -> sdk panic before conversion
3. Mezo module-account mirroring (KiiChain-style) -> allowedReceivingModAcc empty on Mezo
4. MUSD routine oracle brick -> per-block updates verified live (updatedAt==block.timestamp)
5. Tigris needle underflow -> live value in range
6. Mustang removed-branch mint -> precondition never met on-chain

Reportable now: MZ-01 (Med-High conditional), MZ-02, MT-01, SG-01. All private-disclosure candidates, none time-critical.

## Round 3 - report + PoC artifacts (2026-08-25)

| Finding | Report | PoC | PoC status |
|---|---|---|---|
| MZ-01 | mezo/reports/mezo-MZ01-medhigh-pricefeed-stale-lockout.md | mezo/poc/test/PoC.t.sol | PROVEN on Mezo fork blk 11394888 (2/2 pass) |
| MZ-02 | mezo/reports/mezo-MZ02-med-gauge-emission-brick.md | mezo/poc/test/GaugeStrand.t.sol | exact-logic replica PASS; latent live (Voter empty) |
| MT-01 | mantra/reports/mantra-MT01-med-eternal-farming-rate-hijack.md | mantra/poc/test/RateHijack.t.sol | scaffold; needs 2nd maker identity to run |
| SG-01 | saga/reports/saga-SG01-latent-open-trove-removed-branch.md | n/a | code-proof only; precondition unmet; disclosure HELD |

## Round 4 - SG-01 killed by PoC (2026-08-25)

| ID | Change |
|----|--------|
| SG-01 | FALSE POSITIVE. Fork PoC (saga/poc/mpov/DeploymentCore.t.sol) proves TroveManager.onOpenTrove->_requireIsActiveBranch() blocks mint on removed branches despite missing early BO guard. Report rewritten as kill record; dm-mustang.md withdrawn pre-send. |

Final reportable set: MZ-01 (fork-proven), MZ-02 (replica-proven, latent live), MT-01 (code-level, needs role census). No Critical found cluster-wide.
