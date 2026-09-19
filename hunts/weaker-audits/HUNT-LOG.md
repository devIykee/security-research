# Weaker-audit list — hunt log

Campaign: `protocols_by_weaker_audits.md` (174 protocols, ranked weaker audit first, then EVM TVL).
Skill: https://github.com/devIykee/iykes-evm-bughunt-skill.git
Researcher: **deviykee** / Iyke
Agent identity: **weaker-audits-iyke**
Session date: 2026-08-17

This file is the handoff. Do not re-hunt a row marked **done** or **skip** unless the reason expired (TVL returned, new unverified module, etc.).

---

## 1. Protocols hunted from the list

### PinkSale (done — first pass closed)

| Field | Value |
|---|---|
| List rank | 37, section 1 `no-audits` |
| List TVL | $143,572,195 |
| Live TVL (session) | ~$143M (DefiLlama; almost all PinkLock, not live presale ETH) |
| Category | launchpad |
| Workspace | `hunts/pinksale/` |
| Coverage | 5/8 verified files (62%). Path-scoped. Presale impl + diamond facets unverified, not in Y. |
| Permissionless Critical | **None confirmed** |
| Step 7 / 9 | Not opened |
| Trust notes | Operator/governance can finalize, cancel, emergency-withdraw. Diamond owner can `diamondCut`. |

Cores (BSC 56 / ETH 1):

| Role | Address |
|---|---|
| PinkLock02 BSC (main pot) | `0x407993575c91ce7643a4d4cCACc9A98c36eE1BBE` |
| PinkLock V1 proxy BSC | `0x7ee058420e5937496F5a2096f04caA7721cF70cc` |
| PinkLock V1 impl BSC | `0xB9abf98CAB2c8bd2aDF8282e52bf659aDb0260Fe` |
| PinkLock02 ETH | `0x71B5759d73262FBb223956913ecF4ecC51057641` |
| PinkLock V1 ETH | `0x33d4cC8716Beb13F814F538Ad3b2de3b036f5e2A` |
| Presale factory (EIP-2535 diamond, unverified) | `0x1EE7736987F2ebD0f519ec5858b2b3BC6Fd0c6a0` |
| Presale impl (EIP-1167 target, unverified) | `0x07f6351491b694f3a04c5f1e47d151d4ad927d45` |
| Sample live pool | `0x4B6211013Bc0Be572dEE127a3E06ca9Fb5b3434F` |
| feeTo | `0x2e6C8927285353F24A00fcBAF605C54E2E18ea83` |

Killed paths (do not reopen without new evidence):

1. Permissionless locker unlock / drain
2. `editLock` shortening the unlock date
3. Fee-on-transfer / share inflation on PinkLock02
4. V1 UUPS impl selfdestruct from a stranger (`upgradeTo` must be `delegatecall`)
5. Open `diamondCut`
6. Open `finalize` / `transferCurrency` / `emergencyWithdraw`
7. `renounceLockOwnership` to `address(0)` as a stranger bug (owner choice)

Open hole if someone continues PinkSale later: unverified presale `finalize` (possible zero-min LP / pool squat) is **operator-gated**, so it is not a stranger Critical unless operator is shown to be unprivileged.

Read: `hunts/pinksale/INTAKE.md`, `NOTES.md`, `ADDRESSES.md`, `coverage.md`.

### GoPlus Locker V3 (done — first pass closed)

| Field | Value |
|---|---|
| List rank | 83, section 1 `no-audits` (list named **V2**) |
| List TVL | $27,771,084 (stale V2) |
| Live TVL (session) | **$27.57M V3** (BSC $27.09M, Base $474k, ETH $10.5k, Arb dust). V2 remnant ~$333k |
| Category | token-locker |
| Workspace | `hunts/goplus-locker-v3/` |
| Coverage | 4/4 V3 production files (100% of Y). Path-scoped. TokenLocker V2 + UniV4 not in Y |
| Permissionless Critical | **None confirmed** |
| Step 7 / 9 | Not opened |
| Trust notes | Owner / feeReceiver / customFeeSigner are EOAs. Owner cannot pull locked NFTs. Owner can change fees/signer, add NPMs, sweep leftover ERC20/ETH |

Cores (BSC 56 / ETH 1, same addresses):

| Role | Address |
|---|---|
| UniV3LPLocker (V3 pot) | `0x25c9C4B56E820e0DEA438b145284F02D9Ca9Bd52` |
| TokenLocker (V2, not hunted) | `0xF17A08A7d41F53B24AD07Eb322CBBdA2ebdeC04b` |
| owner (EOA) | `0x296812aa1e707370e414f72F0680801e8666B50F` |
| feeReceiver (EOA) | `0x521faAcDFA097ad35a32387727e468F7fD032fD6` |
| customFeeSigner (EOA) | `0x333A16307d8bEf80616F719E958Af5C76290CA85` |
| Pancake V3 NPM | `0x46A15B0b27311cedF172AB29E4f4766fbE7F4364` |

Killed paths (do not reopen without new evidence):

1. Permissionless unlock / drain of locked UniV3 NFTs
2. Relock / V2 updateLock shortening the unlock date
3. Open adminRefund / fee / ownership
4. Stranger collect of principal (collector gets trading fees only)
5. increaseLiquidity leftover / donation theft
6. FoT share inflation
7. customFeeSigner address(0) + ECDSA recover(0)
8. Cross-user custom-fee signature replay
9. Reentrancy double-unlock / in-flight fee steal
10. V2 increment-reset (`moreAmount==0`) and vesting underflow

Read: `hunts/goplus-locker-v3/INTAKE.md`, `NOTES.md`, `ADDRESSES.md`, `coverage.md`.

### Zoo Finance (done — first pass closed)

| Field | Value |
|---|---|
| List rank | 114, section 1 `no-audits` |
| List TVL | $13,966,023 (stale) |
| Live TVL (session) | **~$17.95M** (BSC LVT $13.82M, Sei LVT $4.11M, Arb/Base dust, Berachain B-Vault $707, Story $0) |
| Category | yield / LVT structured claim |
| Workspace | `hunts/zoo-finance/` |
| Coverage | 7/7 verified Zoo files (100% of Y). LvtVault impl + vtSwapHook unverified, not in Y. Path-scoped. |
| Permissionless Critical | **None confirmed** |
| Step 7 / 9 | Not opened |
| Trust notes | Owner EOA `0x7077…dfBd` can `mintVestingTokens` (eth_call succeeds with no FIL), mint FilecoinSPNodes, UUPS-upgrade the vault, pauseDeposit, update aVT. Filecoin SP collateral is off-chain. DefiLlama TVL is vFIL market cap, not FIL in Zoo contracts (vault holds 0.92 FIL). |

Cores (BSC 56):

| Role | Address |
|---|---|
| vFIL (`VestingToken`) | `0x24ef95c39dfaa8f9a5adf58edf76c5b22c34ef46` |
| FilecoinSPNodes ERC1155 | `0xd7fc9ab355567af429fb5bb3b535eab4c7e48567` |
| LvtVault proxy | `0xeBF1039d30D7A03E6F09d0815431DB339017d031` |
| LvtVault impl (unverified) | `0xd3be6f86846b1949aa32f0c655fdd7d8c14feade` |
| vtSwapHook (unverified) | `0xed202a7050ee856ba9f0d3cd5eabcab6b8a23a88` |
| ZooProtocol | `0x170e0C91ffa71dc3c16d43f754b3AECe688470c8` |
| UniV3 FIL/vFIL 500 | `0x9f114D4BA253f1D229bfbdd9c7f85C74531b9c5a` |
| owner EOA | `0x7077323c13af514629C57F89cb4542019402dfBd` |

Killed paths (do not reopen without new evidence / source):

1. Permissionless `mintVestingTokens` / `burnVT` / `VestingToken.mint`
2. Permissionless `FilecoinSPNodes.mint`
3. Open UUPS / pause / buyback / updateaVT
4. Hook `addLiquidity` as missing-auth Critical (public AMM; reverts on allowance)
5. First-depositor / donation on vFIL
6. Treating $18M TVL as EVM-custodied FIL

Open hole if someone continues Zoo later: unverified vault impl + hook AMM math (virtual reserves 8712 vs 0.82 vFIL in PoolManager). Quotes are ~1:1; no fork drain this pass.

Read: `hunts/zoo-finance/INTAKE.md`, `NOTES.md`, `ADDRESSES.md`, `coverage.md`.

---

## 2. Protocols triaged from the list (not hunted)

Confirm **live DefiLlama TVL** and **real custom source** before treating any of these as new work. List TVL was often stale; `no-audits` was often wrong.

| Protocol | List TVL | Live check (2026-08-17) | Decision | Why |
|---|---|---|---|---|
| Cooler Loans | $215M | — | **skip** | Multiple public audits (Sherlock, Electisec, panprog) |
| Flux Finance | $44M | — | **skip** | Compound v2 fork + Code4rena; $550k bounty |
| Spectra V2 | $41M | — | **skip** | Code4rena + Pashov |
| Yield Basis | $129M | — | **skip** | Statemind + Quantstamp |
| Tydro | $56M | — | **skip** | Aave v3 on Ink, not custom |
| Wildcat | $9.9M | — | **skip this pass** | Code4rena + Immunefi |
| Royco V2 | $24M | — | **skip this pass** | Hexens Jan 2026 |
| Infrared Finance | $16.4M | $16.56M Berachain | **skip this pass** | 10 published audits; Cantina |
| QuickPerps | $210M | **$0** | **skip** | Dead TVL. Repo cloned at `hunts/quickperps/repo/` only |
| River4Fun | $78M | **~$1.7k** | **skip** | Dust TVL |
| GoPlus Locker V2 | $27M | **~$333k** | **skip V2** | List pointed at V2; value moved to **V3 ~$26M** |
| Risk curators (Steakhouse, Sentora, Gauntlet, …) | high | — | **skip class** | Morpho/Euler curators, no custom custody |
| RWA wrappers (Exod, Tether Gold, Paxos Gold, …) | high | — | **skip class** | Off-chain / legal, not permissionless EVM |
| Canonical L2 bridges (Base, Linea, World Chain, …) | high | — | **skip class** | Official bridges; DefiLlama `no-audits` is a classification quirk |
| ether.fi / Arbitrum Nitro / USDCx | high | — | **skip class** | Misclassified or not this playbook |

---

## 3. Recommended next hunt

**Primary: Predict Fun**

| Field | Value |
|---|---|
| Why | List rank 121, prediction market. Re-check live DefiLlama TVL (prior note ~$15–19M). |
| Category | prediction / other |
| DefiLlama | confirm slug (search `predict-fun` / `predictfun`) |
| Product type for INTAKE | other |

Fall through in this order (re-check live TVL first):

1. Harvest Finance (~$14.5M, list section 2 `partial-unaudited`; Immunefi exists; DefiLlama now says audits yes)
2. SuperEarn (~$10.6M yield, list rank 112)
3. Privacy Pools (~$8.3M privacy, list rank 141)

Do **not** start ether.fi, curators, RWA, canonical bridges, PinkSale, GoPlus, or Zoo Finance.

---

## 4. Operating rules for the next session

Copy the playbook from https://github.com/devIykee/iykes-evm-bughunt-skill.git (or local `~/.grok/skills/iykes-web3-bughunt-skill/`).

1. Register in `TODO.md` under **weaker-audits-iyke**. Do not collide with other agents.
2. Confirm **live** DefiLlama TVL. If under ~$2M or $0, skip and take the next name.
3. Confirm custom contracts + source (Sourcify / official GitHub). Adapter-only / curator / wrapper = skip.
4. Fill INTAKE. Create `hunts/<slug>/` with `INTAKE.md`, `coverage.md`, `ADDRESSES.md`, `NOTES.md`.
5. Run Steps 1–6 in order. Mechanical probes: skill `tools/`.
6. Fork / `eth_call` only. Never mainnet exploit.
7. Honest severity. Owner-by-design is Trust, not Critical.
8. Kill your own finding. Update this log when you close or skip.
9. Sign reports as **deviykee**. First DM as Iyke. Private until patched.

RPCs used this campaign: ETH `https://ethereum.publicnode.com`, BSC `https://bsc.publicnode.com`.

---

## 5. Prompt for the next session

Paste the block in `NEXT-SESSION-PROMPT.md` as the first user message.
