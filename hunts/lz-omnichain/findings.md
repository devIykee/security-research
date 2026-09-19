# Findings — LayerZero ecosystem config sweep (emerging chains)

**Researcher:** deviykee (Iyke)
**Scope:** LayerZero V2 receive-library configs, 13 emerging EVM chains + Ethereum baseline.
**Method:** read-only eth_call + eth_getLogs. No mainnet state touched. No fork needed
(no permissionless exploit materialized; findings are config/trust class).

## Master findings table

| ID | Severity | Status | Component |
|----|----------|--------|-----------|
| F1 | KILLED -> Info | GATE FAILED | sophon legs single-DVN conf=20 BUT peers(30334)=0 on all four TM/CM contracts: pathway undeliverable, config is dead code |
| F2 | High (conditional) | CONFIRMED on-chain | TSBSatellite (unichain 0x3d354c96 / 0xf0485999, lisk copies): Arbitrum inbound guarded by a raw EOA EOA 0xb85775a6868c1a72...cd0b1 as only DVN, conf=1 |
| F3 | KILLED | downgraded to Info | Sonic Bus: single-DVN rows were historical; all live legs req=3 (see stargate-bus-medium.md) |
| F4 | Trust -> downgraded | CONFIRMED but immaterial | WGC_SuperchainOFT: single DVN 32 legs BUT source is stock OFT+IERC7802 and lisk totalSupply=1000 tokens (6dp); no material exposure |
| F5 | Info/ops | CONFIRMED | Kelp rsETH OFTAdapter hemi: 10/12 legs single LZ-DVN (ethereum leg 4-DVN). Killed as value finding: adapter holds 0 rsETH |
| F6 | Info/ops | CONFIRMED | Chain DEFAULT ULN302 configs on hemi/abstract/lisk/etc = DeadDVN-required (verify() reverts, proven by eth_call) = fail-closed block forcing explicit app config. NOT exploitable |
| F7 | Info/ops | CONFIRMED | Abstract Bus pair (0x183d6b82/0xc0bdf915): several legacy srcs pinned to abstract's DeadDVN = intentionally bricked pathways |

## Key kill-your-own record

- "Defaults are single-live-DVN" — KILLED: every req=1 default decoded to DeadDVN
  (blocked), except ethereum/berachain r4 and sonic/plasma/monad ethereum-leg r4.
- "Kelp Hemi adapter drain" — KILLED: zero rsETH held; no value at risk there.
- Auth triage (setPeer/setPlanner/setFares/setAssetId/setDelegate/…) on bus,
  TokenMessaging, CreditMessaging, satellite — ALL GUARDED.

## Bound honesty

F1-F4 require compromise or misbehavior of ONE verifier key/network each to convert
into theft of the app's bridged value. That is the exact Kelp-class root cause from
Jan 2025. They are NOT stranger-exploitable today, so they do not meet this rubric's
Critical bar. Magnitude per app is bounded by its bridged TVL (not measured here for
satellites/WGC beyond zero native balances).

## Data files

- notes/ulncfg_events.json — 3,900+ decoded UlnConfigSet events (11 chains)
- notes/dvn_defaults2.json — default getUlnConfig per chain x remote eid
- notes/dvn_defaults_sweep.txt, rpcs.txt — probes

## Coverage statement

Coverage incomplete for full-protocol audits: this was a config-layer sweep across
chains, not line-by-line code audit of each app. Findings apply to examined paths
(receive-config security surface + auth triage of identified apps).


## Addendum (tasks 3-4)

- Send-side ULN sweep completed: same families, single-LZ-DVN send configs exist
  (affects outbound verification strictness only; not an inbound forgery lane).
- HyperEVM defaults probe rate-limited at time of check; earlier reading showed
  r1 defaults for eth/bsc legs - identity unverified, flagged as residual gap.
- Worldchain event history excluded (public RPC getLogs caps); defaults proven
  DeadDVN-blocked (fail-closed) via direct eth_call.
- TSBSatellite source read: stock LayerZero MyOApp tutorial (lastMessage only).
- WGC_SuperchainOFT source read: stock OFT + IERC7802 crosschainMint gated to
  SuperchainTokenBridge predeploy; no custom logic.

## Other stacks scoped this session (task 4)

| Stack | Status | Notes |
|---|---|---|
| Wormhole | SCOPED ONLY | guardian-set probe deferred: canonical core addr unresolved (my recalled addr has NO code on 4 RPCs; docs sources 503'd). Needs registry pull next session |
| Axelar | SCOPED ONLY | PoS validator set off-chain; needs chain-registry intake |
| Hyperlane | PARTIAL PROBE | Base mailbox 0xeA87ae93Fa0019a82A727bfd3eBd1cFCa8f64f1D defaultIsm=0x5e74186F... moduleType=2 (aggregation ISM, not NULL/weak). Full ISM-tree audit = future work |
| CCIP | SCOPED ONLY | DON+RMN model; no cheap public config probe; out of quick-pass scope |
