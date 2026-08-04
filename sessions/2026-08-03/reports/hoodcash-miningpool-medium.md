# HoodCash MiningPool - Medium: Underfunded claim permanently burns unpaid reward accrual
**Researcher:** deviykee
**Severity:** Medium - Loss equals unpaid pending when pool balance is less than accrued. Not a cross-user drain. Live risk is currently low while ~40M HCASH is prefunded and totalStaked is 0.
**Status:** Verified with a local Foundry PoC that mirrors live claim accounting. Live addresses and balances checked read-only on Robinhood Chain. No mainnet state touched.
**Disclosure:** Private.

## What this means in plain language (read this first)
Miners stake Genesis Miner NFTs and expect HCASH to accrue over time, then claim it later.

If the MiningPool ever has less HCASH than the total accrued claims, a miner who claims only gets what is left in the pool. The contract still marks them as "fully claimed up to now." The unpaid slice is gone forever. Even if the team refills the pool the next day, that unpaid amount never comes back.

No admin key is needed. Any staker who claims while the pool is short triggers it on their own rewards. It does not steal other users' already-paid balances. The bound is: unpaid pending at the moment of claim, for that staker only.

Analogy: your timesheet says you earned 10 hours, payroll only has cash for 5, and the system stamps your timesheet "paid in full" anyway.

## Affected contracts (Robinhood Chain, chainId 4663)
| Role | Address |
|---|---|
| MiningPool | 0xf275020a10DCD04C63EC4347C41317612e727591 |
| rewardToken (HCASH) | 0x6143bDee01d0C403E17DdC8BC1FC24714D92d02D |
| minerNFT | 0x8FC2D503326308273d696538fc45d77d5451d2fA |

Live snapshot (read-only): totalStaked = 0, pool held ~40e24 wei HCASH (40M tokens), emissionEnd still years out, default rate ~60 HCASH/day/NFT.

## Summary
The contract advances `lastClaim` to the current timestamp before (and regardless of) whether the full accrued amount was actually transferred. Partial payout under `_payout` permanently deletes the unpaid accrual.

## Root cause
In `claim` (and the reward path inside `unstake`), every stake's `lastClaim` is set to `block.timestamp` while accruing `reward`:

```solidity
// claim()
for (uint256 i = 0; i < ids.length; i++) {
    StakeInfo storage info = stakes[ids[i]];
    reward += _pendingFor(info);
    info.lastClaim = uint64(block.timestamp); // advanced unconditionally
}
require(reward > 0, "Nothing to claim");
_payout(msg.sender, reward);
```

`_payout` silently caps to the current token balance:

```solidity
function _payout(address to, uint256 amount) internal {
    uint256 balance = rewardToken.balanceOf(address(this));
    uint256 pay = amount > balance ? balance : amount;
    require(pay > 0, "Pool empty");
    rewardToken.safeTransfer(to, pay);
    emit Claimed(to, pay);
}
```

There is no residual debt, no proportional `lastClaim`, and no revert when `pay < amount`.

## Attack / trigger path
1. Miner has staked NFTs and accrued pending rewards `P`.
2. Pool HCASH balance `B` satisfies `0 < B < P` (underfunded: emission overruns buffer, owner raised rate, tokens swept early after emission end, etc.).
3. Miner calls `claim()` or `unstake(...)`.
4. Contract pays `B`, sets `lastClaim = now`.
5. Pending becomes 0. Lost amount is `P - B`. Refilling the pool does not restore it.

No special role. No flash loan required. Condition is pool underfunding at claim time.

## Impact
Auth: none (any staker) | Capital: zero | Frequency: once per underfunded claim | Victims: stakers who claim while short | Magnitude: unpaid pending for that claim (bounded by shortfall)

Not Critical under the playbook: this is not unauthenticated theft of a large share of *other* users' funds in one shot. It is conditional loss of the caller's own accrued rewards.

## Proof of concept
Local Foundry test that mirrors live accounting order (no mainnet interaction):

```text
cd hunts/robinhood-chain/slvr/poc
forge test -vv
# [PASS] test_underfundedClaimBurnsUnpaidPending()
```

Scenario: stake at t=1000, warp to t=1010 so pending = 10 ether units, seed pool with 5. Claim pays 5, pending becomes 0, refill to 100 does not restore the lost 5.

Live numbers for magnitude if underfunding ever occurs: full design allocation is roughly 400 NFTs x 60 HCASH/day x 365 x 4 years ≈ 35.04M HCASH against a 40M buffer. Rate max is 1000 HCASH/day/NFT via `setRewardRate`, which can break the buffer if used aggressively.

## Fix
One of:

1. **Strict payout (simplest):**  
   `require(rewardToken.balanceOf(address(this)) >= amount, "underfunded");` then transfer full amount. Only then update `lastClaim`.

2. **Proportional lastClaim:**  
   If paying `pay < amount`, advance `lastClaim` only by `elapsed * pay / amount` (or keep an explicit `rewardsDebt` mapping).

3. **Accounting debt:**  
   Track `unpaid[user] += amount - pay` and allow later claim of debt without re-accrual loss.

Prefer (1) for mining pools with a fixed prefund.

## Disclosure & compensation
Good-faith private disclosure. I would appreciate a bounty commensurate with a Medium, given the conditional nature and current low live stake. I am NOT conditioning the disclosure or fix on payment. Please act on the fix when convenient; happy to walk through the PoC and review a patch.

deviykee  
http://x.com/deviykee
