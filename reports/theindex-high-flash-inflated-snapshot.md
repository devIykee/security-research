# The Index (theindex.finance) - High: Permissionless live-balanceOf snapshot is flash-loanable

**Researcher:** deviykee
**Severity:** High - unauthenticated, repeatable theft of a **bounded** share of each distribution pot. Bound = `flashable_INDEX / eligible_INDEX` of the stock inventory frozen at `startCycle`. No special role required.
**Status:** Verified with a local Foundry PoC that mirrors production snapshot/distribute logic from verified source, plus read-only on-chain checks. No mainnet state touched.
**Disclosure:** Private. Live-exploitable whenever `canStart()` is true and the pot is non-empty.

## What this means in plain language (read this first)

Holders of INDEX are told they get paid tokenized stocks (AAPL, NVDA, TSLA, ...) every ~15 minutes, pro-rata to how much INDEX they hold.

The system figures out "how much you hold" by reading your **current** INDEX balance at a moment anyone can trigger. There is no minimum hold time, no historical checkpoint, and no freeze of balances from an earlier block.

That means someone can temporarily borrow a huge pile of INDEX (same idea as a flash loan), get themselves counted as a whale in the snapshot, give the INDEX back, and still receive the stock payout later as if they still held those tokens.

Honest long-term holders lose a slice of every distribution cycle equal to the attacker's inflated share. No admin key is needed. The absolute dollars per cycle equal whatever stock inventory is sitting in the distributor pot at that cycle (fees accumulate over time; larger pots mean larger theft).

Analogy: a raffle that weighs tickets by "how many tickets you hold when the camera clicks," and anyone can borrow tickets for the photo then return them before prizes are handed out.

## INTAKE

```
PROJECT_NAME   : The Index (theindex.finance)
X_HANDLE       : @TheIndexFi
WEBSITE        : https://theindex.finance
CHAIN          : Robinhood Chain
RPC            : https://rpc.mainnet.chain.robinhood.com/
CHAIN_ID       : 4663
PRODUCT_TYPE   : distribution/index
BOUNTY/CONTEST : none / discretionary (no public program found)
RESEARCHER     : deviykee
```

## Affected contracts (Robinhood Chain, chainId 4663)

| Role | Address |
|---|---|
| USDGBuyerDistributor (stock pot + snapshot/distribute) | `0x2459DedB3012d1E929EdD17DF26620120bDF11bf` |
| ReflectionToken (INDEX holder registry) | `0x56910D4409F3a0C78C64DD8D0545FF0705389870` |
| Uniswap v4 PoolManager (rewardsExcluded INDEX custody / flash source shape) | `0x8366a39CC670B4001A1121B8F6A443A643e40951` |
| Owner (admin knobs only) | `0x89562Eb8979dB1E85A01E85120BFD6A7C47a39cb` |

Related (fee path into pot, not the snapshot bug itself): IndexFeeHook, StockTreasury, USDG buy path. The load-bearing bug is in the distributor snapshot.

## Summary

`snapshotHolders` is permissionless and freezes each holder's **live** `indexToken.balanceOf(h)` into `_bals[]`. `startCycle` locks that array and the pot. `distributeBatch` pays `pot * bals[i] / eligible` with **no re-check** of current INDEX balance.

Temporary INDEX (flash-loan shaped) therefore freezes into a permanent claim on that cycle's stock pot. Capital can be returned before distribute.

This is bug-class **permissionless flash-inflated snapshot** (playbook Step 6 #2).

## Root cause

From verified `USDGBuyerDistributor` (production bytecode at the address above):

```solidity
// snapshotHolders — permissionless, no holding period
for (uint256 i = snapCount; i < end; ++i) {
    address h = indexToken.holderAt(i);
    uint256 b = indexToken.balanceOf(h); // LIVE balance — flashable
    _holders.push(h);
    _bals.push(b);
    elig += b;
}
```

```solidity
// distributeBatch — pays frozen bals, never re-reads balanceOf
uint256 amt = (_pot[k] * b) / elig;
if (amt != 0) _trySend(_stock[k], h, amt);
```

INDEX (`ReflectionToken`) is a plain transferable ERC-20 with a holder registry refreshed on transfer. PoolManager is `rewardsExcluded`, so LP custody is not paid, but INDEX sitting there is still a realistic temporary-balance source via v4 `take`/`settle` (PoC simulates the same economic shape with a temporary transfer out of PM).

There is no ERC20Votes-style checkpoint, no TWAB, no "must hold since previous interval," and no same-block balance-delta guard.

## Attack

Preconditions: `!cycleActive`, `block.timestamp >= nextDistribution`, non-empty stock pot (`_hasPot()`).

1. **Borrow** a large INDEX balance into attacker (e.g. v4 unlock `take` from PoolManager, or any fee-free temporary source). Attacker joins holder registry if `balance >= minShareBalance` (10_000e18).
2. **Call** permissionless `snapshotHolders(count)` until `snapshotRemaining() == 0` (paginated; ~2.4k holders on-chain).
3. **Call** permissionless `startCycle()` — freezes `_bals` and pot.
4. **Repay** the borrowed INDEX (attacker live balance can return to 0).
5. **Call** permissionless `distributeBatch` until the cycle finishes. Attacker receives `pot_k * flashBal / eligible` of each stock token.

Repeat every `interval` (900 seconds) when a new pot has accumulated.

## Impact

| Field | Value |
|---|---|
| Auth | none (snapshot / startCycle / distribute are permissionless) |
| Capital | temporary INDEX (flash-loan shaped); net INDEX retained can be 0 |
| Frequency | every distribution cycle (~15 min when pot non-empty) |
| Victims | all honest INDEX holders sharing that cycle's pot |
| Magnitude (bound) | `flash / eligible` of the frozen pot. With ~26M INDEX in PM and ~1B total supply, order-of-magnitude share is a few percent of the pot if most circulating INDEX is eligible; larger if eligible is smaller or flash is larger. |
| Pot custody | real stock inventory on the distributor (18 registered stocks observed). Absolute USD scales with accumulated buy-side inventory; small at snapshot times observed, but the mechanism is live and grows with volume. |

Admin functions (`setKeeper`, `addStock`, `sweepForeign`, ownership) are **guarded** (`onlyOwner`). This is not an owner-backdoor finding. It is a permissionless economic exploit of snapshot design.

Stock payouts use `_trySend` (non-reverting). Tokenized stocks that refuse transfer to an address skip that holder; prior session eth_call transfer sims and product design treat stocks as transferable to EOAs. If a given stock ever blocks arbitrary recipients, that line of the pot may skip rather than pay the attacker (and honest holders with the same restriction).

## Proof of concept

### Local unit PoC (exact logic mirror) — PASS

Path: `poc-theindex/`

```bash
cd poc-theindex
forge test --match-contract LocalFlashSnapshotTest -vvv
```

Result:

```
[PASS] test_flashLoanSnapshotStealsMajorityOfPot()
  eligible (inflated): 1000000000000000000000000
  attacker gained stock: 900000000000000000000000   # 90% of pot
  honest gained stock:   100000000000000000000000   # 10% of pot
  attacker share bps:    9000
  EXPLOIT CONFIRMED (local): flash snapshot stole 90% of pot

[PASS] test_withoutFlashHonestGetsFullPot()
  control OK: honest alone receives full pot
```

The distributor logic in `src/VulnerableDistributor.sol` is a faithful extraction of production `snapshotHolders` / `startCycle` / `distributeBatch` (live `balanceOf` freeze + pot math). Production source was pulled from verified bytecode of `USDGBuyerDistributor`.

### On-chain ground truth (read-only)

```
chainId=4663  block≈15633097
canStart=true  cycleActive=false  snapPending=false
interval=900  stocksLength=18  holders≈2440
minShareBalance=10000e18
PM INDEX ≈ 2.56e25 (~25.6M INDEX), rewardsExcluded(PM)=true
totalSupply=1e27 (1B INDEX)
owner=0x89562Eb8979dB1E85A01E85120BFD6A7C47a39cb  paused=false
```

Auth triage (attacker): admin setters revert; crank surface is intentionally public (reverts only on timing/pot/cycle state).

Full multi-holder mainnet-fork distribute is slow on public RPC (~2.4k holders). Per playbook Step 7, the local exact-logic PoC plus live pot/eligible formulas is the verification path used here. Optional fork harnesses live under `poc-theindex/test/ForkFlashSnapshot.t.sol` and `FlashSnapshot.t.sol` for anvil/cached forks.

## Fix

Any one of:

1. **Checkpointed balances** (ERC20Votes / TWAB): snapshot uses `getPastVotes(holder, block.number - 1)` or balance as of prior interval end, never same-tx balance.
2. **Minimum holding period**: only balances that were held continuously since `nextDistribution - interval` (or since last cycle start) count.
3. **Same-block / flash detection**: reject or zero weight for accounts whose balance increased in the current block (or since snap start) above a threshold.
4. **Merkle / off-chain weighted snapshot** with a committed root from a past block (keeper posts root of historical balances).
5. Operational mitigation (incomplete alone): reduce flashable INDEX in non-excluded venues; does not fix the root cause if any temporary transfer path remains.

## Disclosure and compensation

Good-faith private disclosure. I'd appreciate a bounty commensurate with a **High**. I am NOT conditioning the disclosure or fix on payment; act on it now.

Happy to walk the team through the PoC and review a patch.

deviykee
http://x.com/deviykee
