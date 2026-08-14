# Aumo - Critical-class: Dust redeem forces full lastPass liquidation of lossy venue

**Researcher:** deviykee  
**Severity call:** **High** under strict “theft of funds to attacker” rubric; **Critical-class amplification** for value destruction / MEV (O(1) withdraw → O(TVL) forced exit). See honesty note below.  
**Status:** Verified with local Foundry PoC. No mainnet touch.  
**Disclosure:** Private.

## Honesty note (severity)

There is still **no** proven path where a stranger mints free money or drains 100% of TVL into their wallet with zero preconditions.

What **is** proven: any shareholder can `withdraw(1e6)` (1 USDT0) while the pool is fully deployed in a **lossy / swap venue**, and `_ensureIdle`’s last pass uses `pull = type(uint256).max`, **fully liquidating the venue**. Exit costs and redeem-path sandwich (up to `maxSlippageBps`, e.g. 2%) then apply to **the entire position**, not the 1 USDT dust.

That is unbounded **relative to attacker/redeemer size** as RWA TVL grows. Many programs rate “unbounded loss / forced liquidation of all funds in a strategy from a dust action” as Critical. Under this playbook’s strict Critical (full drain/theft, one shot, no special role), the clean label is **High with Critical impact scaling**; call it **Critical** only if the program equates “force full strategy exit + up to floor% MEV on full notional” with Critical.

## Root cause

```solidity
// AumoPool._ensureIdle
uint256 pull = (need >= live || lastPass) ? type(uint256).max : need;
try this.retreatSelf(v, pull) {} catch {}
```

With a lossy venue (RWA swap), partial pulls **under-deliver** vs `need`, so multi-pass cannot finish on partial sizes and **lastPass** fires `pull = max` → full venue withdraw.

Redeem path: `enforce=false` (no loss budget). User-triggered. Permissionless if you hold any shares.

## Attack flow

1. Pool fully (or mostly) allocated to RwaUsdgAdapter (or any lossy venue).
2. Attacker (or any user) holds ≥ dust shares / withdraws `1` USDT0 of assets when idle ≈ 0.
3. `_ensureIdle` loops; lossy under-delivery → lastPass → `withdraw(type(uint256).max)`.
4. Entire RWA position exits through Uni `exactInputSingle` with `minOut` floor only.
5. MEV sandwich (permissionless) can take up to ~`maxSlippageBps` of **full** notional; remaining LPs absorb exit loss. Redeemer still receives their tiny claim from pre-tx NAV.

## PoC

```bash
cd hunts/aumo/repo/contracts
forge test --match-test test_DustAssets_1U_LastPass -vv
```

Observed:
- `faceBefore` 100_000e6  
- `withdraw(1e6)` (1 USDT0)  
- `faceAfter` **0** — **FULL LIQUIDATION**  
- Face pulled = entire 100_000 USDT0 position  

Control: `redeem(1 share)` may convert to 0 assets (offset) and pull nothing.

## Impact

| Dimension | Value |
|-----------|--------|
| Auth | any shareholder (dust) |
| Capital | ~1 USDT0 of shares / withdraw |
| Frequency | whenever idle short and lossy venue holds almost all |
| Victims | all remaining LPs (exit cost + sandwich on full TVL) |
| Magnitude | up to full venue face liquidated; MEV ≤ maxSlippageBps × face |

## Fix

1. **Never use `pull = max` on lastPass for residual dust.** Cap pull at `need * surplusBps / 10000` or retry with slightly inflated need, not full face.  
2. Prefer **lossless venues first**; never lastPass-max a swap venue for dust.  
3. Single-pass pull sized as `need` inflated by known max slippage once, not n+2 passes ending in max.  
4. Keep material idle buffer so dust redeems never touch venues.

## Relation

| ID | Link |
|----|------|
| H-5 sandwich | Same swap; this finding **forces full notional** into that sandwich |
| H-1 stuck NAV | Opposite extreme (revert); this is in-floor full exit |
| L1 lastPass order | Same lastPass mechanism |

deviykee
