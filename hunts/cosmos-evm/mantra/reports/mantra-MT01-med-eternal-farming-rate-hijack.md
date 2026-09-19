# MANTRA - Medium: EternalFarming setRates/deactivateIncentive are role-gated but not incentive-ownership-bound
**Researcher:** deviykee
**Severity:** Medium - bounded by number of whitelisted INCENTIVE_MAKERs; single-maker deployments reduce to config/trust risk
**Status:** Code-level proof from explorer-verified sources (Blockscout, contract 0x50FC...27bA). Exploit path requires a second whitelisted maker, so no live PoC executed. Nothing touched on-chain.
**Disclosure:** Private.

## What this means in plain language (read this first)
MANTRA's QuickSwap farm lets "incentive makers" fund liquidity-mining rewards for pools. The admin functions that set reward rates or kill an incentive check only WHO you are (do you hold the incentive-maker badge), never WHAT you own (is this your incentive?). Any whitelisted maker can point another maker's live incentive at maximum drain rate - the incentive's reserve converts into rewards within a block and flows to whoever happens to be staked at that moment - or deactivate it entirely. With multiple makers this is maker-vs-maker theft; even with one trusted maker it is one compromised key away from redirecting every farm on the chain.

## Affected contracts (MANTRA mainnet, chainId 5888)
| Role | Address |
|---|---|
| AlgebraEternalFarming | 0x50FCbF85d23aF7C91f94842FeCd83d16665d27bA |
| FarmingCenter | 0x658E287E9C820484f5808f687dC4863B552de37D |

## Summary
One wrong assumption: "holding the INCENTIVE_MAKER role means you only touch your own incentives." The functions bind the role, not the `IncentiveKey` ownership.

## Root cause
`contracts/farmings/AlgebraEternalFarming.sol` (verified source):
```solidity
function setRates(IncentiveKey memory key, uint128 rewardRate0, uint128 rewardRate1)
    external override onlyIncentiveMaker   // no ownership check vs key
{ _setRewardRates(key, rewardRate0, rewardRate1); }

function deactivateIncentive(IncentiveKey memory key)
    external override onlyIncentiveMaker   // same gap
```
Core math elsewhere audited clean this pass: crossing distribution order, double-claim loops, solvency caps all verified sound.

## Attack
1. Attacker holds (or is granted) INCENTIVE_MAKER.
2. Victim maker funds incentive K with reserve R for pool P.
3. Attacker calls setRates(K, type(uint128).max, max): reserve converts to secondsPerLiquidity growth in one distribution call.
4. Attacker (or accomplices) pre-positions LP stakes in P -> captures R.
5. Alternative: deactivateIncentive(K) strands victim's reserve.

## Impact
Auth: requires INCENTIVE_MAKER role | Capital: full reserve of any foreign incentive | Frequency: per-incentive, repeatable | Victims: other makers + their farmers | Magnitude: sum of active incentive reserves

## Proof of concept status
Confirm test (needs one cooperative second maker OR governance review of role holders):
```
forge test --fork-url https://evm.mantrachain.io -vv
// impersonate two makers; B calls setRates(keyA, max, 0); assert reserve ~= 0
```
Scaffold: `mantra/poc/test/RateHijack.t.sol`. Role-holder census recommended before severity finalization (`farming.incentiveMakers(addr)` probe).

## Fix
Bind actions to ownership: store `key.rewardToken/depositor` creator mapping on createIncentive and require `msg.sender == creator[key]` in setRates/deactivateIncentive/addRewardToIncentive.
