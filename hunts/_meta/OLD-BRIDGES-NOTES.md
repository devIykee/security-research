# Older-bridge hunt wrap-up (Hop / Meson / Synapse / BoringDAO)

Researcher: deviykee
Skill: iykes-web3-bughunt-skill (https://github.com/devIykee/iykes-evm-bughunt-skill.git)
RPC: https://ethereum.publicnode.com (chainId 1)
Status: path-scoped pass closed. One Medium confirmed (Hop). No permissionless Critical.
Coverage incomplete. See each `hunts/<project>/coverage.md`.

## INTAKE summary

| Project | Product | Live TVL (user) | Core trust root |
|---------|---------|-----------------|-----------------|
| Hop | L2 AMM + bonder bridge | ~$3M | Registered bonder + challenge game |
| Meson | HTLC stablecoin swap | ~$0.5M | LP lock/release + user signatures |
| Synapse | Validator mint/burn + RFQ + CCTP | ~$11-12M | NODEGROUP_ROLE / relayer+guard |
| BoringDAO | Trustee oToken + two-way lock | low | Trustee / CROSSER_ROLE |

## Master findings table

| ID | Project | Severity | Status | Component | Note |
|----|---------|----------|--------|-----------|------|
| H-1 | Hop | — | KILLED | transferId | `abi.encode` includes chainId, recipient, amount, nonce, fee, swapData |
| H-2 | Hop | — | KILLED | bondWithdrawal vs withdraw | bond path forces SwapData(0,0,0); L2 uses `bondWithdrawalAndDistribute` for swaps |
| H-3 | Hop | — | KILLED | settleBondedWithdrawals | public, but root id is keccak(merkle(ids) \|\| total); cannot hit another root |
| H-4 | Hop | Medium | CONFIRMED (fork PoC) | challenge dest unbound | Escalation attempted: L1 dest pays users 100% plus 10% leak; 24h debit-gap needs bonder. Not Critical. Keeper still blocks. |
| H-5 | Hop | Info | NOTED | sendToL2 forwardedValue | repo L1 computes it and never forwards; live ETH path uses messenger wrapper |
| H-6 | Hop | — | KILLED | CCTP send | thin wrapper; fee to collector then Circle burn; no leftover custody |
| S-1 | Synapse | Trust | NOTED | mint/withdraw | NODEGROUP_ROLE; not a stranger exploit |
| S-2 | Synapse | — | KILLED | kappa | shared map across mint/withdraw/redeem siblings |
| S-3 | Synapse | Trust | NOTED | FastBridge prove/claim | 30m optimistic; GUARD_ROLE is the check |
| S-4 | Synapse | — | KILLED | FastBridge sender field | refund uses `params.sender` but pull is from `msg.sender` |
| S-5 | Synapse | — | KILLED | CCTP receive | requestID-salted MinimalForwarder; amount must match mint |
| M-1 | Meson | — | KILLED | chain binding | post checks inChain; lock checks outChain; swapId = keccak(encoded, initiator) |
| M-2 | Meson | — | KILLED | hardcoded .call | SKALE faucets only; not pool drains |
| M-3 | Meson | — | KILLED | simpleExecuteSwap | permissionless deposit into pool 1; caller pays |
| M-4 | Meson | Trust | NOTED | directRelease r=0 | premium manager only when combined with feeWaived checks |
| B-1 | BoringDAO | Trust | NOTED | Tunnel mint | onlyBoringDAO / trustee quorum |
| B-2 | BoringDAO | Trust | NOTED | CrossLock.unlock | CROSSER_ROLE + txid replay map |

## Deliverables

| Item | Path |
|------|------|
| Hop Medium report | `hunts/hop/reports/hop-medium-challenge-dest.md` |
| Hop first DM (not sent) | `hunts/hop/reports/dm-hop.md` |
| Hop fork PoC | `hunts/hop/poc/test/HopChallengeDest.t.sol` |
| Addresses | `hunts/{hop,meson,synapse,boringdao}/ADDRESSES.md` |
| Coverage | `hunts/{hop,meson,synapse,boringdao}/coverage.md` |

PoC command:

```
cd hunts/hop/poc
forge test --fork-url https://ethereum.publicnode.com --match-test test_wrongDestChallengeExtractsFromPool -vv
```

Result: attacker +0.75 ETH on a 10 ETH root. Pool also burns 0.25 ETH to `0xdead`.

## Coverage this pass

| Project | Traced | Note |
|---------|--------|------|
| Hop | 10/30 (33%) plus live Sourcify L1 | path-scoped; saddle not traced |
| Meson | 5/16 (31%) | official repo private; public fork |
| Synapse | 5/225 (2%) | bridge + FastBridge + CCTP only |
| BoringDAO | 2/42 (5%) | tunnel + CrossLock only |

`Coverage incomplete.` Findings apply to examined paths only.

## Closed without further pass

Hop saddle, Synapse FastBridgeRouter leftover, Meson live token-index table, BoringDAO proposal replay (trust), and Step 4 auth-triage loops. Those remain optional follow-ups, not part of this close.

Step 10 DM is drafted and **not sent**.
