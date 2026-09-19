# Coverage — lz-omnichain (LayerZero ecosystem sweep)

Coverage: 13/13 chains ground-truthed. Receive-config history decoded on 11 chains;
send-side sweep completed; worldchain event history excluded (RPC caps, defaults
probed directly). Gate pass executed on F1/F2 - both Highs killed with on-chain proof.
Source-level reads done for TSBSatellite (tutorial app) and WGC OFT (stock code).
Other stacks (Wormhole/Axelar/CCIP) scoped only; Hyperlane partial probe.

Last updated: line-by-line core audit done (see audit-stargate/AUDIT-lzv2-core.md)

| Target / File | Read? | Paths traced | Notes |
|------|-------|--------------|-------|
| metadata.layerzero-api.com deployments | yes | all mainnet v2 rows | canonical addrs, deadDVN per chain |
| UlnBase.sol / ReceiveUln302View.sol (LZ-v2 repo) | yes | getUlnConfig DEFAULT/NIL resolution, verifiable() flow | |
| Default configs: 13 chains x 7 remotes | yes | all r1 defaults = DeadDVN (fail-closed proven) | hyperevm recheck rate-limited |
| UlnConfigSet receive events (11 chains, 3900+) | yes | latest-per-(oapp,src) classified | worldchain excluded |
| UlnConfigSet send events | yes | same families mirrored | Info class |
| Stargate Hydra TM/CM/Bus + Kelp + TSBSatellite + WGC | yes | peers(), owners, balances, source reads | F1-F4 all killed/downgraded by gate |
| Auth triage: bus/TM/CM/satellite (16 sigs each) | yes | all guarded | |
| Hyperlane Base defaultIsm | partial | moduleType=2 aggregation ISM | full tree unaudited |
| LZv2 core: EndpointV2, MessagingChannel, MessageLibManager, ULN302 recv path, LzExecutor delivery, OAppReceiver, OFT/OFTAdapter | yes (function-complete) | 12 files, invariants verified | verdicts CLEAN; 3 Info observations; exclusions listed in audit file |

## Explicitly excluded

| Path / area | Reason |
|-------------|--------|
| worldchain event history | public RPC getLogs caps (100 blocks); needs keyed RPC |
| hyperevm event history + default recheck | 1000-block cap + rate limits; needs keyed RPC |
| Wormhole/Axelar/CCIP config probes | authoritative registries unreachable this session; scoped only |
| Full per-app audits beyond identified set | out of session scope |

## Hunt lanes

1. Kelp-class DVN misconfig — EXECUTED; no exploitable instance survived the gate.
2. Auth triage — EXECUTED (no free win).
3. OFT supply unification / app logic — EXECUTED for identified apps (stock code).

| Target / File | Read? | Paths traced | Notes |
|------|-------|--------------|-------|
| metadata.layerzero-api.com deployments | yes | all mainnet v2 rows | canonical addrs, deadDVN per chain |
| UlnBase.sol / ReceiveUln302View.sol (LZ-v2 repo) | yes | getUlnConfig DEFAULT/NIL resolution, verifiable() flow, _assertAtLeastOneDVN revert semantics | |
| Default configs: 13 chains x 7 remotes | yes | getUlnConfig(dummy,eid) decoded; r1 defaults proven = DeadDVN | fail-closed confirmed via verify() eth_call revert |
| UlnConfigSet events: sonic 1171, hemi 1122, unichain 915, abstract 456, story 425, lisk 72 | yes | latest-config-per-(oapp,src) resolved; singles/dead/blocked classified | worldchain+hyperevm excluded (RPC range limits) |
| App ID: Stargate Hydra Bus/TM/CM, Kelp rsETH adapter, TSBSatellite x2, WGC_SuperchainOFT | yes | selectors, peers, owners, balances | Kelp hemi TVL=0 killed as value target |
| Auth triage: bus/TM/CM/satellite (16 sigs each) | yes | all guarded | no free win |

## Explicitly excluded

| Path / area | Reason |
|-------------|--------|
| worldchain, hyperevm event history | public RPC getLogs range limits (100/1000 blocks); defaults probed instead |
| Send-side ULN configs | weaker security impact for inbound forgery lane |
| Full code audit of each identified app | out of session scope; config layer only |

## Hunt lanes

1. Kelp-class DVN misconfig on emerging-chain endpoints — EXECUTED (F1-F4).
2. Auth triage on OFT/OApp apps — EXECUTED (no free win).
3. OFT supply unification bugs — NOT REACHED (needs source-level audit per app).
