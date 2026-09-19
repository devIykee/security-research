# Coverage — Cosmos EVM cluster (Mezo primary)

Coverage: shared-module static pass DONE (7 core files traced); Mezo lane starting.

Last updated: 2026-08-25 shared-module pass complete

## Shared module (cosmos/evm @ 3e646c43, public main)

| File | Read? | Paths traced | Notes |
|------|-------|--------------|-------|
| precompiles/staking/staking.go | yes | Run→Execute→Delegate dispatch; BalanceHandlerFactory wired | full read |
| precompiles/staking/tx.go | yes | delegate/undelegate/redelegate/cancelUnbonding auth (sender==delegator); NO code-check on Delegate/Undelegate vs CreateValidator's check | full read |
| precompiles/common/precompile.go | yes | RunNativeAction: snapshot→FlushToCacheCtx→action→AfterBalanceChange; HandleGasError re-panics non-OOG | full read |
| precompiles/common/balance_handler.go | yes | CoinSpent/CoinReceived events → SubBalance/AddBalance mirror | full read |
| x/vm/keeper/statedb.go | yes | GetAccount(SpendableCoin), SetBalanceWithLocked(total=amount+locked) invariant | full read |
| x/vm/keeper/keeper.go:310-350 | partial | SpendableCoin negative→nil; lockedCoin snapshot | value paths only |
| x/vm/wrappers/bank.go | yes | SpendableCoin→bank view; SetBalance→UncheckedSetBalance | full read |
| x/vm/statedb/state_object.go:137-172 | partial | SubBalance underflow PANICS (guard present) | money path |
| x/vm/statedb/statedb.go:495-548, journal | partial | AddPrecompileFn/MultiStoreSnapshot revert machinery | money path |
| cosmos-sdk v0.54.3 bank view.go / coin.go (remote) | yes | SpendableCoin=balance-locked UNCLAMPED (panics neg via Coin.SubAmount); LockedCoins vesting-aware | fetched raw |

### Killed findings (shared module)
1. Over-delegate(>total-locked) via staking precompile → mirror SubBalance underflow → 2^256 balance. DEAD on main: state_object.go panics; baseapp.go:801 recovers → atomic fail. Incident fix lives in private chain forks.
2. Negative SpendableCoin → uint256 wrap. DEAD: sdk Coin.SubAmount panics on negative before conversion.
3. Panic-as-DoS from poisoned vesting addr. DOWNgraded: recovered in runTx, tx fails cleanly, self-inflicted, temporary (vests out). Max Medium griefing.

## Explicitly excluded

| Path / area | Reason |
|-------------|--------|
| lib/** or node_modules/** | vendored |
| test/** or **/*_test* | tests (exclude unless in scope) |
| CosmWasm / MoveVM (MANTRA MultiVM, Echelon) | EVM-focus this hunt |
| KiiChain/TAC deep-dive | halted mid-incident, private patches, no public diff to audit yet |

## Mezo (Tigris/Earn) — in progress

| File | Read? | Paths traced | Notes |
|------|-------|--------------|-------|

## Mezo Tigris + MUSD + mezod pass (2026-08-25)

| File | Read? | Paths traced | Notes |
|------|-------|--------------|-------|
| tigris RewardsDistributor/Voter/rewards/* | yes (subagent) | distribute→notifyRewardAmount→claimable integrals; vote/reset/burn; managed NFT share math | full money-path trace |
| tigris Splitter.sol / ChainFeeSplitter / EpochGovernor | yes (subagent) | nudge/proposal gating, epoch races | clean |
| tigris Pool.sol swap/fees | partial (subagent) | amountIn post-hook, K check | clean |
| tigris AutoCompounder.sol | yes (lead) | claimBribes/Fees→swap(0 slippage)→reward(min(1%,factory))→ve.increaseAmount | MEV-bounded only; holds no user principal |
| musd PriceFeed.sol | yes | fetchPrice staleness gate MAX_PRICE_DELAY=60; setOracle owner-only | F1 |
| musd PCV.sol / InterestRateManager / GovernableVariables / StabilityPool / ActivePool / MUSD | yes (subagent) | fee distribution allowances, SP accounting internal counters, mint list | F4/F5/F6/F9 |
| musd BorrowerOperations/TroveManager custom paths | partial (subagent) | recovery-mode gates, closeTrove, redemption hints | F3/F7 |
| mezod precompile/assetsbridge/{outflow_limit,erc20}.go | yes | PoA-owner gated CRUD; limits non-negative | clean |
| mezod precompile/priceoracle/*.go | yes | GetPrice(BTC/USD) read-only view of Connect oracle state; fail-fast nil/zero | clean |
| LIVE probes | n/a | needle()=60 (kills #5); oracle updatedAt==block.timestamp (kills routine-brick); MUSD totalSupply=30.87M | explorer+RPC |

## Explicitly excluded (this session)

| Path / area | Reason |
|-------------|--------|
| mezod x/bridge keeper mint path + triparty.go/bridge_out.go/min_amount.go | Go-only fork proof needed (no go toolchain installed); static review next session |
| MANTRA Algebra V4 + EternalFarming | not reached; ~$0.5M TVL, lower priority than Mezo lanes |
| Saga Mustang, Initia EVM, XRPL/Stable | not reached (low TVL / enterprise) |
| ve/Delegation.sol + CompoundOptimizer internals | not reached |

Coverage statement: shared-module core paths traced; Mezo EVM surfaces path-scoped (~60% of Tigris, ~70% of MUSD custom code). Findings apply to examined paths only. NOT a complete audit of any project.

## Full-cluster sweep round 2 (2026-08-25)

| File | Read? | Paths traced | Notes |
|------|-------|--------------|-------|
| tigris ve/Delegation.sol + CompoundOptimizer.sol (+NFT/Escrow/ManagedNFT interplay) | yes (subagent) | delegate/dedelegate credit deltas; delegateBySig; optimizer route building | Lows only; killed paths documented |
| mezod app/app.go BlockedAddrs wiring | yes | allowedReceivingModAcc EMPTY -> all module accts blocked | KILLS KiiChain gov-module mirror bug class on Mezo |
| KiiChain kiichain repo commits b9be591a7 etc | yes (remote) | Aug-4 gov-module statedb-mirroring fix diffed; repo predates Aug-22 incident | intel only |
| TAC TacBuild repos | yes (remote) | all pushed <= Aug-11, predate incident | no patch to diff |
| MANTRA AlgebraEternalFarming (46 verified srcs) + EternalVirtualPool + VirtualTickStructure | yes (subagent) | crossTo distribution order, double-claim loops, solvency caps, FoT | F1 Med role-gap |
| MANTRA SedaPriceStore (15 srcs) | yes (lead) | updatePrices monotonic ts, relayer ACL, UUPS owner | trust notes |
| Mustang must-finance (Liquity V2 fork) custom files | yes (subagent) | CollateralRegistry add/removeBranch, BO branch gates, BoldToken mint ACL, SaviorToken, BatchSender | latent Med-High; live check: all 8 branches active |
| initia-evm-contracts src/*.sol | yes (lead, 414 LOC) | ConnectOracle dead cosmosContract; ERC20Factory ownership flow | Info only |
| xrplevm node+evm repos | yes (remote) | default branches end Jul-28/Feb-26; no post-Aug-22 diffs | lane closed |

Coverage statement: every project in the intake list received at least a targeted hunt pass or an explicit close-out with reason. Deep path coverage remains concentrated on Mezo (~70% of its EVM surfaces) and MANTRA farming core. Not a complete audit of any project.
