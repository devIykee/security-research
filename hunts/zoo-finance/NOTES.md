# Hunt notes — Zoo Finance

Identity: weaker-audits-iyke. Playbook: iykes-web3-bughunt-skill.
First pass closed 2026-08-17. No permissionless Critical. No Step 7/9.

## Gate (2026-08-17)

1. Live TVL: **PASS**. DefiLlama slug `zoo-finance`. `currentChainTvls` BSC $13.82M + Sei $4.11M + dust = **~$17.95M** (list $13.97M; older note $29M).
2. Custom + source: **PASS** (partial). Org `zoofiio` has no public LVT repo. Verified: `VestingToken`, `FilecoinSPNodes`, `ProtocolOwner`. Unverified: LvtVault impl, vtSwapHook, ZooProtocol, settings. Frontend ABI `abiLVTVault` + revert strings used for the unverified vault.
3. Not a curator / thin wrapper / canonical bridge. Certik is **B-Vault only** (Berachain ~$707). LVT path is the TVL and is unaudited.

## Product

Filecoin 540-Locked Vault (BSC). Docs: SP sector-collateral FIL stays on Filecoin; BSC issues vFIL claims. Adapter TVL = `vFIL.totalSupply * UniV3 quote` (`doublecounted: true`), **not** FIL in Zoo contracts.

Live books (BSC, block ~116473776):

| Book | Amount |
|------|--------|
| vFIL supply | 21.77M |
| vault `aVT()` | 13.93M |
| FIL in vault | 0.92 |
| UniV3 FIL/vFIL 500 | 239 FIL + 240 vFIL |
| hook `reserve0/1` | 8712 / 8713 (virtual) |
| vFIL in v4 PoolManager | 0.82 |
| FIL in v4 PoolManager (all BSC v4) | 326 |
| FilecoinSPNodes id=1 in vault | 1 |

Owner `mintVestingTokens` **succeeds** on `eth_call` with no FIL. That plus 1 deposited SP node vs 21.77M vFIL is the dual-ledger: claims are not 1:1 with on-chain FIL.

## Step 5 foundation

### 5A who-writes

| State | Writer |
|-------|--------|
| vFIL supply | vault only (`onlyVault`) |
| FilecoinSPNodes id=1 | protocol owner (`onlyOwner`) |
| vault aVT / pauseDeposit | owner or operator |
| vault UUPS impl | owner or upgrader |
| buyback | authorized (owner passed; stranger `Caller not authorized`) |
| hook LP / reserves | public `addLiquidity` / `removeLiquidity` (needs tokens) |

Owner EOA: `0x7077323c13af514629C57F89cb4542019402dfBd`. Protocol `isOperator`/`isUpgrader` all false for owner, rewards-op, dead. Rewards operator `0xE8f7…DE48` is a separate list.

### 5B CEI

VestingToken: nonReentrant on mint/burn/transfer. Vault impl + hook unverified. **UNCLEAR** on vault/hook internals.

### 5C token path

SP NFT (owner-minted) → `deposit(uint256)` (reverts `Not enough NFT balance` without NFT) → vFIL. Alternate: owner `mintVestingTokens` (no T). Secondary: UniV3 + v4 hook AMM. Buyback is authorized, needs T in vault. Filecoin L1 collateral is **not** in these contracts.

### 5D access

See revert table in killed paths. `deposit` is not auth-gated; it is NFT-gated. Hook LP is public.

### 5E checklist

| Item | Result |
|------|--------|
| Reentrancy / CEI | UNCLEAR (vault/hook unverified). Token side PASS |
| Access control on privileged writers | PASS (revert-string confirmed) |
| Oracle / pricing | N/A for solvency. Price is AMM. Hook reserves != PM inventory |
| Slippage | Frontend router has mins. Hook addLiquidity has amountMin |
| Frontrun / sandwich | Public AMM; expected |
| Init / proxy | UUPS 5.0.0; `initialize` reverts from dead |
| Upgrade storage | Trust: owner/upgrader |
| Pause vs redeem | `pauseDeposit` owner/op. No `pausedRedeem` selector on this impl. Public exit is sell vFIL, not vault redeem |
| Events | UNCLEAR (impl unverified) |

## Step 5.5 / 5.6 / 6

| Path | Result |
|------|--------|
| Permissionless `mintVestingTokens` | **killed** — `Caller is not the owner` |
| Permissionless `FilecoinSPNodes.mint` | **killed** — `Caller is not the owner` |
| Permissionless `burnVT` | **killed** — owner |
| Permissionless `buyback` | **killed** — `Caller not authorized` |
| Permissionless UUPS | **killed** — owner or upgrader |
| `VestingToken.mint/burn` stranger | **killed** — `onlyVault` |
| Hook `add/removeLiquidity` auth missing | **killed as Critical** — public by design; dead hits allowance/balance, not auth |
| First-depositor vFIL | **killed** — 21.77M already outstanding; not ERC-4626 |
| First-depositor hook LP | **killed** — LP supply 5724 already |
| Donation to vault inflates shares | **killed** — no share mint from FIL sitting in vault |
| Dual-ledger hook reserves vs PM | **open / not proven** — virtual 8712 vs 0.82 vFIL in PM. Quotes ~1:1. Large swap likely reverts. No fork drain |
| aVT 13.93M vs vFIL 21.77M | **trust / design** — extra via owner mint |
| Pause bricks redeem | Public path is sell, not vault redeem |
| Owner compromised | Unlimited vFIL + UUPS + SP NFT mint. **Trust**, not Critical |

## Killed (do not reopen without new source)

1. Stranger mint / burn vFIL
2. Stranger mint FilecoinSPNodes
3. Open UUPS / pause / buyback / updateaVT
4. Hook LP as missing-auth Critical
5. First-depositor / donation on vFIL
6. Treating DefiLlama $18M as EVM-custodied FIL

## Coverage honesty

Y = 7 verified Zoo files (100%). Vault impl + hook not in Y. Findings apply to examined paths only.

## Contacts (not sent)

No Step 9. Official: https://doc.zoofi.io , https://zoofi.io , X `@ZooFinanceIO`. Audit page only links Certik B-Vault PDF. No Immunefi found this pass.
