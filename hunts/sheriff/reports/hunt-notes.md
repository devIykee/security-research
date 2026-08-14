# sheriff.money — hunt notes (deviykee)

Playbook: Iyke Steps 1–6 only this session. Fork/eth_call only. No mainnet state touched.

## INTAKE

PROJECT sheriff.money | CHAIN Robinhood 4663 | RPC https://rpc.mainnet.chain.robinhood.com
PRODUCT Algebra Integral CLAMM + Camelot V2 + campaigns | BOUNTY 4-week junior event
RESEARCHER deviykee

Coverage: see `hunts/sheriff/coverage.md` — **29/33 (88%)**. Path-scoped, not a full audit.

## Step 4

All probed admin/keeper sigs on live Campaign proxy, Distributor, SecurityRegistry, PluginFactory, V2 factory, YakRouter, sample plugin, AlgebraFactory: **guarded**. No missing-auth free win.

`create`/`createPair` "guarded" from dEaD is input/transfer revert, not hidden auth. Those paths are permissionless by design.

## Step 5 checklist (examined paths)

| Item | Result |
|------|--------|
| Reentrancy / CEI on fund paths | PASS pair `lock`; distributor `nonReentrant`; plugin hooks `onlyPool` |
| Access control on privileged changers | PASS on live targets (Step 4) |
| Oracle / pricing | PASS for swaps (not a lending oracle). TWAP is fee input only |
| Slippage on DEX | PASS user minOut on router; Yak mid-hops use 0 (standard, user-bound at end) |
| Frontrun / sandwich | UNCLEAR/expected AMM surface |
| Init / proxy | FAIL-INFO: CampaignFactory impl `0xE1eA…` `initialize` still callable (`eth_call` from dEaD returns success). Proxy already initialized. No funds on impl |
| Upgrade storage | UNCLEAR proxy is Transparent + ProxyAdmin owner=deployer (trust) |
| Pause | PASS owner-only |
| Events on policy | PASS |

## Step 5.5 scoreboard

| Path | Result |
|------|--------|
| Missing auth drain | KILLED — Step 4 |
| V2 K/fee desync vs library | KILLED — library reads per-pair fee |
| SecurityPlugin `setSecurityRegistry` write-before-auth | KILLED — `_authorize` reverts, tx atomic |
| `_checkStatusOnBurn` if registry=0 | KILLED live (registry set). Latent if admin zeros it |
| Both fees off → feeOverride=0 | KILLED as stranger exploit (admin only). Live both true |
| AlgebraV2Adapter public `swap` leftover drain | KILLED live — adapter balances 0. Dust sits on Yak router (4.14 USDG), maintainer recover |
| Custom pool malicious plugin on default pools | KILLED — `setPlugin` only that deployer's custom pool |
| Distributor merkle steal | KILLED as permissionless. **Trust**: updater `0x8d0d…` can set any root over 5.51M POINTS |
| Campaign cancel refund | No refund. Creator/owner ops. Not stranger theft |
| FeeHelper WINDOW 1 day vs oracle 4 hours | Confirmed quote mismatch. View helper only, not custody |
| Yak user-supplied adapter | Caller spends own tokens. Phishing, not protocol drain |
| Points as campaign TVL | Unverified ERC20, owner=deployer, 1B supply. Treat as trust/mintable until source |

## Residual (not permissionless exploitables)

- **Info**: uninitialized CampaignFactory implementation
- **Low**: FeeHelper WINDOW != VolatilityOracle.WINDOW
- **Low**: campaign `cancel` does not return incentives (already at distributor)
- **Low**: distributor unwrap+push ETH DoS if `token==wNative` and `user` rejects ETH
- **Trust**: merkle updater, feeTo/setFee, SecurityRegistry owner/guard, Yak maintainer recover, Points owner

## Findings

| ID | Sev | Status | Component |
|----|-----|--------|-----------|
| M-1 | Medium | CONFIRMED code, not live-triggered | SecurityPlugin burn vs zero registry |
| L-1 | Low | CONFIRMED | FeeHelper WINDOW 1d vs oracle 4h |
| L-2 | Low | CONFIRMED | campaign `cancel` does not refund |
| I-1 | Info | CONFIRMED | CampaignFactory impl still initializable |
| I-2 | Info | CONFIRMED | communityFeeReceiver=0, ~0.40 WETH + 683 USDG stuck in vault |

Live check: 17/17 Algebra pools have registry `0x0AeB…`. M-1 is a sibling-function landmine, not a current freeze.

PoC: `hunts/sheriff/poc && forge test --match-contract PoC -vv` (3/3 pass).

