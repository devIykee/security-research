# Mezo - Medium (latent): Emissions distributed to zero-supply gauges are permanently bricked
**Researcher:** deviykee
**Severity:** Medium - permanent value stranding per occurrence, bounded by the affected gauge's weekly emission share; LATENT on mainnet today (see Status)
**Status:** Code-level proof against deployed source (tigris @ 0a3b5e8). Live state check 2026-08-25: VeBTCVoter 0x3A4a...C1b has totalWeight=0 and zero registered pools - voting/emissions not yet active at this address, so no live stranded funds exist today. Becomes live-loss the day distribution starts.
**Disclosure:** Private.

## What this means in plain language (read this first)
Tigris distributes protocol emissions weekly to gauges in proportion to votes. If a gauge has votes but nobody staking in it, the week's emission slice is sent into that gauge and can never be claimed by anyone - and there is no sweep path to recover it. It is a leak: real tokens move out of the treasury into a black box every week until someone notices. No attacker needed; a misconfigured or abandoned gauge does it silently.

## Affected contracts (Mezo mainnet, chainId 31612)
| Role | Address |
|---|---|
| Voter | 0x3A4a6919F70e5b0aA32401747C471eCfe2322C1b (currently empty config) |
| Gauges | created via GaugeFactory |

## Summary
One wrong assumption: "a gauge receiving emissions must have stakers." `_distribute()` gates only on claimable size and duration - never checks `IGauge(_gauge).totalSupply() > 0`.

## Root cause
`solidity/contracts/Voter.sol:574-584`:
```solidity
function _distribute(address _gauge) internal {
    uint256 _claimable = ...;
    if (_claimable > IGauge(_gauge).left() && _claimable / DURATION > 0) {
        IGauge(_gauge).notifyRewardAmount(_claimable);   // no totalSupply gate
```
With `totalSupply == 0`, `Gauge.rewardPerToken()` returns stored unchanged (`supply floored at 1` divides, nothing accrues), so notified tokens sit forever. `killGauge()` sweeps only `Voter.claimable[gauge]`, not balances already notified INTO the gauge.

## Attack / failure sequence
1. NFT votes for fresh gauge G before any deposit (permissionless ordering).
2. Weekly distribute() notifies G's share into G.
3. Nobody can ever earn it; no admin sweep exists for gauge balances.
4. Repeats every week G retains vote weight.

## Impact
Auth: none | Capital: one week's emission share per affected gauge-week | Frequency: continuous while condition holds | Victims: all other gauge stakers (dilution) | Magnitude: bounded by vote weight share

## Proof
Exact-logic replica PoC at `mezo/poc/test/GaugeStrand.t.sol` (runs without fork):
- notify into zero-supply gauge -> earned() stays 0 for all future depositors; balance remains stranded.
Live magnitude: none today (Voter empty). Re-check after voting goes live.

## Fix
1. Gate `_distribute` on `IGauge(_gauge).totalSupply() > 0` (defer notification until first stake), or
2. pro-rata refund undistributed `left()` back to splitter on killGauge, plus a permissionless sweep for dead gauges.
