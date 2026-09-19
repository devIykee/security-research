# Stake DAO hunt notes

Researcher: deviykee
Status: first pass on Curve liquid locker (sdCRV). No permissionless Critical confirmed.

## Live (eth_call)

- DefiLlama `stake-dao` TVL ~$117.2M
- Depositor 0xa50C…c335: version 4.0.0, state ACTIVE, gov 0xe5d6…8b91
- sdCRV operator == depositor
- sdCRV supply 119,049,916
- veCRV.locked(locker) amount 119,154,642 CRV (slightly above supply; no overmint)
- Accumulator 0x11F7…b4Cd version 4.0.0, claimerFee 0

## Foundation

- deposit: transfer CRV to locker Safe → increase_amount + maybe increase_unlock_time via module → mint sdCRV 1:1
- No unlock path (liquid locker). Exit is sell sdCRV
- SafeModule reverts on failed execute (no silent skip)
- Accumulator claimAndNotifyAll: claim crvUSD from fee distro, pull to acc, notify gauge; public notifyReward
- Governance can shutdown depositor and rotate sdToken operator (**trust**)

## 5.5

| Path | Result |
|------|--------|
| Mint sdCRV without locking | **Killed** — lock execute must succeed or revert |
| sdCRV supply > locked CRV | **Killed live** — locked 119.15M > supply 119.05M |
| Stranger mint/burn sdCRV | **Killed** — operator = depositor |
| Accumulator drain via claimerFee | **Killed** — fee 0 live; gov-set |
| claimAndNotifyAll early return if 0 crvUSD | **Killed as theft** — notifyReward is public separately |
| _shareWithDelegation underflow | **Killed** — share from current balance |
| Governance setSdTokenMinterOperator | **Trust** |

No Step 7/9. Strategies / Votemarket / other lockers not in this pass.
