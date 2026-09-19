# Liquity V1 hunt notes

Researcher: deviykee  
Status: first pass on core money paths. No permissionless Critical confirmed.  
Coverage: see coverage.md

## INTAKE

See INTAKE.md. Official addresses in ADDRESSES.md (lib-ethers mainnet.json).

## Repo vs live bytecode

`github.com/liquity/dev` `main` is **not** a clean 2021 deploy snapshot.

Live StabilityPool **reverts** on `getMaxAmountToOffset()` and `MIN_LUSD_IN_SP()`.
Repo StabilityPool / TroveManager include a later min-leave-1-LUSD offset patch (comments even say `totalBoldDeposits`).

Hunt the **deployed 2021** semantics: liquidations use `getTotalLUSDDeposits()`, SP can be fully offset, last-depositor wipe is the original design.

Sourcify verified sources saved under `recon/live-src/` (HTTP 200 for TM/BO/SP/PriceFeed/LUSD/ActivePool). Live TM:

`vars.LUSDInStabPool = stabilityPoolCached.getTotalLUSDDeposits();`

Live SP offset: `assert(_debtToOffset <= _totalLUSDDeposits)` and if equal, `LUSDLossPerUnitStaked = DECIMAL_PRECISION` (full pool wipe). That is intentional 2021 behavior, not the later min-leave patch.

PriceFeed live: aggregator `0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419` (Chainlink ETH/USD), tellorCaller `0xAd430500ECDa11E38C9bCB08a702274b94641112`, status 0, fetchPrice ~1881.51 vs lastGoodPrice ~1877.12.

Do not treat repo-only helpers as live.

## Step 4 auth triage

From `0x…dEaD` on live: `setAddresses`, LUSD `mint`/`burn`/`sendToPool`, ActivePool `sendETH`/debt, SP `offset` all **guarded**. Public `liquidate` / `redeemCollateral` / `openTrove` / `provideToSP` revert on empty/invalid args (tool labels that `guarded`; they are permissionless entry points, not missing-admin). No free-win missing auth.

## Step 5 foundation map

### 5A. Who writes

| State | Writer |
|-------|--------|
| Trove debt/coll/status/stake | BO (user ops) + TM internals (liq/redeem/redistribute apply) |
| L_ETH, L_LUSDDebt, snapshots | TM liquidation redistribute |
| ActivePool ETH / LUSDDebt | BO, TM, SP, DefaultPool receive |
| DefaultPool ETH / LUSDDebt | TM only |
| CollSurplus balances | TM accountSurplus; claim via BO |
| LUSD mint | BO only |
| LUSD burn | BO / TM / SP |
| SP deposits / P / S / G | user provide/withdraw + TM offset |
| PriceFeed lastGoodPrice / status | anyone via fetchPrice (oracle-driven) |
| Owners | all 0x0 after setAddresses |

### 5B. External call order (value paths)

- openTrove: checks → write trove → ActivePool receive ETH → mint LUSD (CEI OK)
- liquidate batch: close/account inner loop (DefaultPool→ActivePool ETH) → SP.offset (burn LUSD + pull ETH) → redistribute sendETH → surplus sendETH → gas LUSD + ETH to liquidator last
- redeem: mutate troves in loop (close may send surplus ETH mid-loop) → fee ETH to LQTYStaking → burn redeemer LUSD → sendETH redeemer
- SP withdraw: LQTY payout → LUSD returnFromPool → update deposit → send ETH gain

No reentrancy guard. Relies on CEI + non-hook LUSD/ETH. Liquidator/redeemer/staker `receive()` can reenter after settlement.

### 5C. Token paths

User ETH → ActivePool → (SP / DefaultPool / CollSurplus / LQTYStaking / user)  
LUSD minted at BO to user + GasPool (+ fee to LQTYStaking)  
LUSD burned on repay / redeem / SP offset / close  
No path that sends pool ETH to an arbitrary stranger except as liquidator gas (0.5% + 200 LUSD) or redeemer face-value-minus-fee

### 5D. Access gates

| Fn | Gate |
|----|------|
| TM setTroveStatus / inc/dec coll/debt / applyRewards / closeTrove | only BO |
| TM liquidate / liquidateTroves / redeemCollateral | public |
| SP offset | only TM |
| SP provide/withdraw | public |
| ActivePool sendETH / debt | BO or TM or SP |
| LUSD mint | BO |
| PriceFeed setAddresses | onlyOwner, then renounce |
| No pause | n/a |

### 5E. First-pass checklist

- Reentrancy / CEI: **PASS** on examined fund paths (state before untrusted ETH send; LUSD has no hooks)
- Access control on privileged writers: **PASS** (mint/offset/sendETH gated; owners 0)
- Oracle freshness: **UNCLEAR / residual** — 4h freeze → lastGoodPrice; Tellor V1 fallback likely dead; status currently chainlinkWorking
- Slippage on DEX: **PASS** (no DEX in core)
- Frontrun/sandwich: **PASS** as theft (redemption/liquidation MEV is intended)
- Init / proxy: **PASS** (no proxies; constructors + renounce)
- Upgrade storage: **PASS** (immutable)
- Pause: **PASS** (none; cannot freeze liquidations)
- Events on policy: **PASS** (no live policy knobs)

## Step 5.5 scoreboard

| Angle | Path | Result |
|-------|------|--------|
| Drain via extra LUSD mint | LUSD.mint | **Killed** — BO only |
| Drain ActivePool sendETH | stranger call | **Killed** — BO/TM/SP |
| Redeem more ETH than LUSD face | redeemCollateral | **Killed** — ETHLot = LUSD/price, then fee |
| SP offset steal extra ETH | rounding / cap | **Killed as Critical** — floors lean pool; live has no min-leave patch |
| Recovery 110% cap surplus | capped offset | **Killed as bug** — surplus is borrower's |
| Last trove immune | close / liq / full redeem | **Killed as bug** — explicit invariant |
| Self-liq profit beyond gas | liquidate self | **Killed as Critical** — 0.5% + 200 LUSD only |
| hasPendingRewards only checks L_ETH | 0-ETH redistribute then withdraw on stale debt | **Killed as live** — needs dust coll + SP not covering; L_ETH live = 0, DefaultPool empty, TCR 504% |
| Tracker vs balance desync | force-feed / bug | **Killed live** — AP/SP/CS trackers == balances |
| Empty LQTY stake fee stick | increaseF_ETH/F_LUSD when total=0 | **Killed as stranger theft** — known stuck-fee; live 57M LQTY staked, ETH matches pending model |
| Tellor dead + lastGoodPrice | oracle | **Residual / not attacker-controlled** unless Chainlink also broken/frozen |
| SP withdraw freeze | ICR < MCR exists | **By design** — anyone can liquidate; temporary |
| Push ETH DoS on claim/liq | contract recipient reverts | **By design / grief** — user-chosen address |
| Liquidator reenter after gas ETH | second liquidate/redeem | **Open low** — no double-pay found; would be another honest liq |
| Repo getMaxAmountToOffset | live SP | **Not deployed** |

## Step 6 CDP questions

- Oracle: Chainlink ETH/USD primary, Tellor reqId=1 fallback, 4h timeout, 50% consecutive-round deviation, lastGoodPrice if both fail. Not spot/TWAP-manipulable via flash loan.
- Liquidation: ICR < 110% normal; recovery also ICR < TCR with SP-full-cover cap at 110%.
- Health / LTV: MCR 110%, CCR 150%, min net debt 1800 LUSD + 200 gas.
- Interest: none. Fees are one-shot borrow/redeem baseRate.
- Peg: hard redeem at oracle face minus fee. 79 troves, 7.6M LUSD in SP.

## Findings table

| ID | Severity | Status | Component |
|----|----------|--------|-----------|
| — | — | none confirmed this pass | — |

No Step 7/9/10. Nothing to disclose.

## Next (if continuing this target)

- Diff etherscan-verified 2021 sources vs this repo (especially TM liq SP read + original SP offset assert)
- Fuzz original last-depositor / P=0 empty-pool path against live P=0.117
- PriceFeed + live TellorCaller against current Tellor master (fallback liveness only)
- Do not start Convex until that diff is on disk if hunting V1 deeper
