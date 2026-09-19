# Hop Protocol - Medium: challenge dest is not bound, so a wrong dest pays the challenger from the ETH pool
**Researcher:** deviykee
**Severity:** Medium - permissionless 7.5% extract + 2.5% burn of a bonded TransferRoot, after the 14-day resolve window. A watcher who resolves with the *confirmed* dest can still invalidate it. Bound is 10% of each challenged root (7.5% attacker, 2.5% burned). Capital: 10% of the root, locked 14 days.
**Status:** Verified on a local Ethereum mainnet fork. No mainnet state touched.
**Disclosure:** Private.

## What this means in plain language (read this first)
Hop lets anyone challenge a bonder who posts a TransferRoot they think is fake. The challenger posts 10% of the root as a stake. After two weeks, if the root was never confirmed, the challenger is paid from the bridge ETH pool.

The contract never records *which destination* was bonded. The dest is an argument the caller picks at challenge time and again at resolve time. An attacker can challenge a real, honest root using a fake dest such as `999`. Confirm only writes the real dest, so dest `999` stays unconfirmed. After 14 days the attacker resolves with dest `999` and is paid as if the bond were fraudulent.

On a fork of the live L1 ETH bridge (`0xb8901acB…727f`, ~603 ETH), bonding a 10 ETH root and challenging dest `999` netted the attacker 0.75 ETH. Another 0.25 ETH was burned to `0xdead`.

A keeper who saw the original bond can still resolve with the *real* dest after confirm and turn this into an invalid challenge. That is why this is Medium, not High/Critical.

## Escalation (tried, still Medium)

We tried to turn this into a Critical full drain. It does not go there.

1. **L1 dest double outflow (proven).** `bondTransferRoot` on dest 1 sets the TransferRoot immediately. `withdraw` still pays the full root after a fake-dest challenge. Same ETH pot then also pays 7.5% to the attacker and burns 2.5%. Fork: 10 ETH to the user + 1 ETH challenge leakage = 11 ETH from that root. The rest of the ~603 ETH pot stays. Test: `test_l1RootStillPaysUsersPlusFakeDestExtract`.
2. **24h additionalDebit gap (proven, bonder-gated).** After `challengePeriod` the bond drops out of `_additionalDebit` while a challenge is still allowed. The allowlisted bonder can unstake the 110% lock, then a fake-dest resolve still takes 7.5% from remaining deposits. A stranger cannot force the bonder to unstake. Test: `test_slotGapUnstakeThenFakeDestStillExtracts`.
3. **No path to empty the pot.** You can only hit roots bonded in the last day. Each hit needs 10% capital and 14 days. Live ETH bonder free credit is ~0, so huge new roots are not sitting there. Repeat-to-zero is not realistic.
4. **Keeper still wins.** Resolving with the dest that was actually confirmed still cancels the 1.75x payout.

Worse case for an honest L1-bound root: **110% of that root** leaves the pot (100% users + 10% challenge leak). That is still per-root and still stoppable if anyone resolves with the confirmed dest. Not a one-tx unauthenticated drain of the bridge.

## Affected contracts (Ethereum, chainId 1)
| Role | Address |
|---|---|
| L1 ETH Bridge | 0xb8901acB165ed027E32754E0FFe830802919727f |

USDC L1 (`0x3666f603…`) still has the 2-arg challenge ABI. This write-up is for the 3-arg live ETH bridge.

## Summary
`TransferBond` and `transferRootId` do not include `destinationChainId`. `challengeTransferBond` / `resolveChallenge` treat "confirmed on the dest the caller passed" as "confirmed at all".

## Root cause
Live `L1_Bridge.sol` (Sourcify exact match):

```
function challengeTransferBond(bytes32 rootHash, uint256 originalAmount, uint256 destinationChainId)
```

`transferRootId = keccak256(rootHash, totalAmount)` is dest-agnostic. Confirm writes `transferRootCommittedAt[realDest][id]`. Resolve with `fakeDest` reads a zero slot and takes the "valid challenge" branch, crediting `1.75 * amount/10` to the challenger from the pool.

## Attack
1. Wait for (or cause) `bondTransferRoot(root, realDest, amount)` within the 1-day challenge window.
2. `challengeTransferBond(root, amount, 999)` with `msg.value = amount/10`.
3. Wait `challengeResolutionPeriod` (live: 14 days).
4. `resolveChallenge(root, amount, 999)` then `unstake`.
5. Net +7.5% of `amount` in ETH. 2.5% burned.

## Impact
Auth: none | Capital: 10% of root for 14 days | Frequency: each newly bonded root | Victims: ETH in the L1 bridge / bonder liveness | Magnitude: 10% of challenged root (7.5% stolen, 2.5% burned). Defeated if anyone resolves with the confirmed dest first.

## Proof of concept
`hunts/hop/poc/test/HopChallengeDest.t.sol`

```
cd hunts/hop/poc
forge test --fork-url https://ethereum.publicnode.com -vv
```

- `test_wrongDestChallengeExtractsFromPool`: attacker gained 0.75 ETH on a 10 ETH root. Pool lost 1 ETH (0.75 stolen + 0.25 burned).
- `test_keeperResolveWithConfirmedDestBlocksExtract`: after a confirm is written for dest 1, resolving with dest 1 does not pay the 1.75x bounty.

## Fix
Store `destinationChainId` on `TransferBond` at bond time. Ignore the caller dest on challenge/resolve, or require it matches the stored dest. Treat any dest confirmation of that `transferRootId` as confirmation.

## Disclosure & compensation
Good-faith private disclosure. I'd appreciate a bounty commensurate with a Medium. I am NOT conditioning the disclosure or fix on payment. Happy to walk the team through it and review the fix.
deviykee
