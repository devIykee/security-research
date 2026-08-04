# StockDotFun - High: V4 pool pre-init freezes graduation and traps the full curve raise

**Researcher:** deviykee  
**Severity:** High - permissionless permanent freeze of that launch's full curve principal (bound: one token's `realQuote` at graduation, factory target ~4.4 ETH class). Not a cross-token protocol drain.  
**Status:** Verified against fully verified V2 source on Blockscout. Control flow proven with local Foundry unit tests (`hunts/stockdotfun/poc`). No mainnet state touched.  
**Disclosure:** Private until patched.

---

## What this means in plain language (read this first)

StockDotFun (live site: **stockdotfun.com**; stock.fun DNS dead) is a stock-paired memecoin launchpad on Robinhood Chain. Buyers put WETH into a bonding curve until a graduation target is hit. Then the protocol is supposed to move that WETH plus reserved meme tokens into a **Uniswap V4** MEME/WETH pool and **permanently lock** the liquidity.

**The bug:** the graduation locker always calls Uniswap V4 `PoolManager.initialize` with the intended price. Anyone can call `initialize` first on the same pool key (meme, WETH, fee, tick spacing, no hooks) with any fake price, using **only gas and zero tokens**. When the pad later tries to graduate, `initialize` reverts because the pool already exists. The curve marks **MIGRATION_FAILED**, keeps the WETH on the curve, and **buy/sell stay off** forever for that token. There is **no owner recovery path** in the verified pool source that refunds buyers or migrates under a different key.

**Why that is dangerous:**

- Attack is permissionless and costs only gas (no meme inventory required).
- Once the raise is hit, curve trading is already frozen (`READY_TO_GRADUATE` / `MIGRATION_FAILED` are not `ACTIVE`).
- Retries of `GraduationManager.finalize` keep failing while the pool key stays initialized.
- Bound is the full principal of **that** launch (`realQuote`), not every token at once. Factory graduation target is about **4.41 ETH** of net quote per launch (live `curve()` read).

**What it is not:** not the Robinlaunch/Openfair V3 "dump raise into a fake price" theft. StockDotFun uses hard `initialize` (reverts if pre-inited) rather than V3 `createAndInitializePoolIfNecessary` (which reuses a wrong price). The outcome is **freeze**, not wrong-price LP mint. Still High because the raise becomes permanently inaccessible to holders with no in-protocol escape.

**Analogy:** when the fundraiser hits its goal, the doors lock and staff try to open the public market. A stranger can open the market door first and jam it. Staff keep the cash box on the table, but nobody can leave or open the real market, and there is no back-room key in the code.

---

## INTAKE

```
PROJECT_NAME   : StockDotFun (stock.fun / stockdotfun.com)
WEBSITE        : https://stockdotfun.com
CHAIN          : Robinhood Chain
RPC            : https://rpc.mainnet.chain.robinhood.com
CHAIN_ID       : 4663
EXPLORER       : https://robinhoodchain.blockscout.com
KNOWN_ADDRS    :
  factory=0x470aca74d71269833de8cf65640dfb558393569e
  graduationManager=0x408fA5743a43de08C596169B58f11E303026D835
  graduationAdapter=0x74993f85f42ba26d613c37cb82b0c5f586a22d39
  v4LiquidityLocker=0x19f19e9e6b414e0e128597289dda4c218d9c7aa1
  treasury=0x284c47ef1754fa82b85cbe8207dd749e6f9ca389
  owner=0xCBC88Ba92a79bd1EC8D11886c20FB1087b7572b6
  registry=0xf1c7181324dec91bf0fb94a2f05608927e06b97c
  weth=0x0Bd7D308f8E1639FAb988df18A8011f41EAcAD73
  sample_token=0xc8a5345bfd37f5edd92684ccfebf8a9f35249957
  sample_pool=0x63760d1926205706c614500617380d51ef6b7f25
PRODUCT_TYPE   : launchpad (stock-route bonding curve -> Uniswap V4 lock)
BOUNTY/CONTEST : none / discretionary
NOTES          : Factory name StockDotFunFactoryV2; 11 tokens listed via allTokensLength; fee 1%; grad fee 10000 (1%); tickSpacing 200
RESEARCHER     : deviykee
```

---

## Affected contracts (Robinhood Chain, chainId 4663)

| Role | Address | Verified |
|------|---------|----------|
| StockDotFunFactoryV2 | `0x470aca74d71269833de8cf65640dfb558393569e` | yes |
| GraduationManager | `0x408fA5743a43de08C596169B58f11E303026D835` | yes |
| UniswapV4GraduationAdapter | `0x74993f85f42ba26d613c37cb82b0c5f586a22d39` | yes (source on disk) |
| V4LiquidityLocker | `0x19f19e9e6b414e0e128597289dda4c218d9c7aa1` | yes (source on disk) |
| BondingCurvePoolV2 (per token) | e.g. `0x63760d…7f25` | yes (template) |
| Owner | `0xCBC88Ba92a79bd1EC8D11886c20FB1087b7572b6` | n/a |

Local sources: `hunts/stockdotfun/`.

### Live factory curve config (eth_call `curve()`)

| Field | Value |
|-------|--------|
| totalFeeBps | 100 (1%) |
| holder / creator / protocol share | 4000 / 3000 / 3000 |
| virtualQuote | 3 ETH |
| graduationTarget | ~4.41 ETH net quote |
| gradFee | 10000 (Uniswap V4 1%) |
| gradTickSpacing | 200 |
| allTokensLength | 11 |

---

## Technical summary

1. On launch, factory deploys `MemeTokenV2` + `BondingCurvePoolV2` with immutable `gradFee`, `gradTickSpacing`, `graduationAdapter`.
2. Buys push `realQuote` until `graduationTarget`. Crossing buy sets `state = READY_TO_GRADUATE`. Further buy/sell require `ACTIVE` and revert.
3. Permissionless `GraduationManager.finalize(pool)` calls `pool.finalizeGraduation()`.
4. Pool approves adapter and calls `adapter.graduate(meme, weth, principal, memeForLiq, gradFee, gradTickSpacing)`.
5. Adapter builds deterministic PoolKey (sorted meme/WETH, fee, tickSpacing, **hooks = address(0)**), computes `sqrtPriceX96` from amount ratio, then `locker.lockLiquidity(key, sqrtPriceX96, amounts, doInitialize=true)`.
6. Locker:
   ```solidity
   if (doInitialize) poolManager.initialize(key, sqrtPriceX96);
   // then modifyLiquidity with liquidity derived from the intended price
   ```
7. If an attacker already called `poolManager.initialize` on that key, step 6 reverts. Pool `try/catch` sets `MIGRATION_FAILED`, leaves `realQuote` intact, clears approvals. **No alternate migrate key, no refund, no owner rescue in verified pool code.**

Pool key is known as soon as the token exists: meme address from `TokenCreated`, WETH constant, fee/tickSpacing from pool immutables / factory curve.

---

## Root cause

### Trading freeze at graduation

```solidity
// BondingCurvePoolV2.buy — when target crossed
state = PoolLifecycle.READY_TO_GRADUATE;

// _requireActive used by buy/sell
if (state != PoolLifecycle.ACTIVE) revert NotActive();
```

### Hard initialize without pre-existence handling

```solidity
// V4LiquidityLocker.lockLiquidity
if (doInitialize) poolManager.initialize(key, sqrtPriceX96);
// Uniswap V4 reverts PoolAlreadyInitialized if key already live
```

### Failure leaves funds trapped

```solidity
// BondingCurvePoolV2.finalizeGraduation
try IGraduationAdapterLike(graduationAdapter).graduate(...) returns (...) {
    // success path burns leftovers, clears realQuote
} catch (bytes memory reason) {
    // approvals zeroed; state = MIGRATION_FAILED; realQuote unchanged
    return (bytes32(0), 0);
}
```

There is no `recoverRaise`, no fee/tick override, and no second pool key. Retry uses the same key.

---

## Attack

1. Watch `TokenCreated` (or factory `allTokens` / `poolOf`).
2. Read `gradFee`, `gradTickSpacing`, `memeToken`, `weth` from the curve pool (all public).
3. Build the same PoolKey as `UniswapV4GraduationAdapter.poolKeyFor` (sorted currencies, fee, tickSpacing, hooks=0).
4. Call Uniswap V4 `PoolManager.initialize(key, attackerSqrtPrice)` (any valid price). Gas only.
5. Wait until buyers fill `graduationTarget` (or buy the last slice yourself).
6. Call or wait for `GraduationManager.finalize(pool)`. It fails; state becomes `MIGRATION_FAILED`.
7. Holders cannot sell. Principal WETH stays on the curve. Every later finalize fails the same way.

---

## Impact

| Dimension | Value |
|-----------|--------|
| Auth | none |
| Capital | gas only (zero tokens) |
| Frequency | once per token (permanent for that PoolKey) |
| Victims | all holders of that un-graduated raise after target |
| Magnitude | 100% of that launch's `realQuote` (~graduation target net of fees, ~4.4 ETH class per factory config) |
| Theft vs freeze | **permanent freeze** (principal not stolen by attacker; users lose exit and market migration) |

---

## Proof of concept

```bash
export PATH="$HOME/.foundry/bin:$PATH"
cd hunts/stockdotfun/poc
forge test --match-contract V4PreInitGraduationFreezeTest -vv
# 2 passed:
#   happy path graduates when pool not pre-inited
#   attacker pre-init -> MIGRATION_FAILED, realQuote trapped, sell reverts, retry fails
```

Logic mirrors verified `BondingCurvePoolV2` + `V4LiquidityLocker` control flow (local mocks of PoolManager initialize semantics).

---

## Mitigations (good defenses already present)

- Graduation amounts and price are derived on-chain from terminal curve state (not attacker params).
- Adapter cannot be pointed at an arbitrary pool key (key from meme+weth+fee+ts only).
- V4 locker has no negative-liquidity path (stronger than NFT lock).
- Hard `initialize` avoids the V3 **wrong-price dump** class (good), but turns pre-init into **freeze** instead.

---

## Fix

Pick one (or combine):

1. **If pool already initialized:** read current sqrt price from PoolManager; **require** it matches intended `sqrtPriceX96` within a tight tick tolerance; only then add liquidity. If price mismatches, revert with a distinct error and provide a **governance/timelock recovery** that refunds WETH pro-rata or remaps fee/tickSpacing once.
2. **Salted / hook-bound PoolKey** unique to the pad (or per-launch salt) so strangers cannot initialize the production key first.
3. **Do not freeze sells on READY_TO_GRADUATE** until migration succeeds; or allow sell-while-ready so users can exit if migrate fails.
4. **Owner/guardian `rescueFailedGraduation`** that only activates in `MIGRATION_FAILED`, sends principal to a refund module or re-tries under a new fee tier. Document the trust model.

Minimum for High fix: never leave user principal in a state with no sell and no successful migrate path.

---

## Disclosure and compensation

Good-faith private disclosure. I'd appreciate a bounty commensurate with a **High** (permanent freeze of full per-launch raise). I am not conditioning disclosure or fix on payment. Happy to walk the team through the PoC and review a patch.

deviykee / Iyke (http://x.com/deviykee)
