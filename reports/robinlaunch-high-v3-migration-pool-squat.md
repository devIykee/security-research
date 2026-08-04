# Robinlaunch - High: Uniswap V3 graduation / Direct Pool migration pool squat

**Researcher:** deviykee  
**Severity:** High  
**Status:** Verified against fully verified on-chain source (Blockscout). Logic proven with a local Foundry test that mirrors the vulnerable call sequence. No mainnet state touched.  
**Disclosure:** Private until patched.

---

## What this means in plain language (read this first)

Robinlaunch is a place where people launch meme tokens. Buyers put in real ETH while the token is on a bonding curve. When enough ETH is raised (about 2.5 ETH for bonding launches), the app is supposed to move that money and the remaining tokens into a Uniswap pool at a fair price so everyone can keep trading.

**The bug:** anyone can set up that Uniswap pool *ahead of time* at a *fake* price, for almost free (just gas). They do not need to hold the meme token. When the launch "graduates" or when someone uses Direct Pool, Robinlaunch still pours the raised ETH and tokens into that pool without checking that the price is honest.

**Why that is dangerous:**

- Money that buyers put in for a fair launch can be parked at a rigged market price.
- An attacker can then trade against that broken pool and pull value out (arbitrage). People who bought on the curve can lose a large share of *that token's* raise.
- The attacker does not need special admin rights. No password, no owner key. Any stranger can do the setup.
- It can happen again on every new token that graduates or lists this way, until the code is fixed.
- Creators and later traders also get a worse pool than the product promised ("locked liquidity at the right price").

**What it is not:** this is not a single button that empties *every* Robinlaunch token at once. Damage is per launch (up to roughly the full raise and LP inventory for that one token). We rate it **High**, not Critical, for that reason. It is still serious for anyone who bought a vulnerable launch.

**Analogy:** imagine a fundraiser that, at the end, is supposed to put all donations into a public vault at the real exchange rate. Instead, a stranger can open the vault early with a fake exchange rate, and when the fundraiser auto-deposits, the money lands in that rigged vault and can be skimmed.

---

## INTAKE

```
PROJECT_NAME   : Robinlaunch
WEBSITE        : https://robinlaunch.fun
DOCS           : https://robinlaunch.fun/how-it-works
CHAIN          : Robinhood Chain
RPC            : https://rpc.mainnet.chain.robinhood.com
CHAIN_ID       : 4663
EXPLORER       : https://robinhoodchain.blockscout.com
KNOWN_ADDRS    :
  factory_v8=0x108eB6D67c079bEb1EF328850a88c2BbDB4617ea
  direct_factory_v3=0x52afeBDb95Cda3C221eB415Abb9cEE051E3Ca082
  lp_fee_collector=0x705D3937aD95F54b803481c90CAF3203DA697f22
  factory_v7_legacy=0xa4552a787ea97649568adcf82e258b714d8affd4
  weth=0x0Bd7D308f8E1639FAb988df18A8011f41EAcAD73
  univ3_npm=0x73991a25C818Bf1f1128dEAaB1492D45638DE0D3
  univ3_factory=0x1f7d7550B1b028f7571E69A784071F0205FD2EfA
PRODUCT_TYPE   : launchpad
BOUNTY/CONTEST : none / discretionary
NOTES          : Bonding curve to Uniswap V3 at 2.5 ETH; Direct Pool instant V3; LpFeeCollector holds LP NFTs
RESEARCHER     : deviykee
```

---

## Affected contracts (Robinhood Chain, chainId 4663)

| Role | Address | Verified |
|------|---------|----------|
| Factory v8 (bonding) | `0x108eB6D67c079bEb1EF328850a88c2BbDB4617ea` | yes (name `Factory`) |
| BondingCurve (logic) | per-token clone from Factory source `src/BondingCurve.sol` | yes (via Factory additional sources) |
| DirectFactory v3 | `0x52afeBDb95Cda3C221eB415Abb9cEE051E3Ca082` | yes |
| LpFeeCollector | `0x705D3937aD95F54b803481c90CAF3203DA697f22` | yes (not the root cause; holds LP after) |

Sources pulled from Blockscout `/api/v2/smart-contracts/<addr>` on 2026-07-19.

---

## Technical summary

At graduation (bonding curve) and at Direct Pool launch, Robinlaunch creates a Uniswap V3 pool via `createAndInitializePoolIfNecessary` and mints full-range liquidity with **`amount0Min = 0` and `amount1Min = 0`**, and **never checks `slot0().sqrtPriceX96` after init**.

Anyone can **pre-create and initialize** the `token/WETH` 1% pool at an arbitrary price **before** graduation/launch (no tokens required for V3 `createPool` + `initialize`). When the pad later "creates" the pool, Uniswap reuses the existing pool and **ignores** the honest price. Liquidity is deposited into an **attacker-chosen price**, so the raised ETH / token inventory is mis-deployed and can be extracted via arb against the broken full-range LP.

This is the classic **"migration pool squat (v3)"** launchpad bug class.

---

## Root cause

### BondingCurve._graduate (Factory v8 embedded source)

```solidity
address pool = positionManager.createAndInitializePoolIfNecessary(
    token0,
    token1,
    UNISWAP_FEE,
    sqrtPriceX96   // intended price from amount0/amount1
);

(uint256 tokenId, uint128 liquidity,,) = positionManager.mint(
    INonfungiblePositionManager.MintParams({
        ...
        amount0Desired: amount0,
        amount1Desired: amount1,
        amount0Min:     0,   // <-- no protection
        amount1Min:     0,   // <-- no protection
        recipient:      mintRecipient,
        deadline:       block.timestamp
    })
);
// NO: require(IUniswapV3Pool(pool).slot0() matches intended sqrtPriceX96)
// NO: refund / revert if used amounts diverge wildly
```

File: verified `src/BondingCurve.sol` lines ~379-408 (local copy: `hunts/robinlaunch/clean/src/BondingCurve.sol`).

### DirectFactory._createPool / _mintAndReturn

Same pattern:

```solidity
pool = INonfungiblePositionManager(positionManager).createAndInitializePoolIfNecessary(
    token0, token1, UNISWAP_FEE, _computeSqrtPriceX96(amount0, amount1)
);
// mint with amount0Min: 0, amount1Min: 0
```

File: `hunts/robinlaunch/clean/src/DirectFactory.sol` ~214-254.

BondingCurve additionally **does not return mint dust** (DirectFactory does via `_returnDust`). After a squat, unused WETH/tokens can remain stuck on the curve contract forever.

---

## Attack

**Auth:** none  
**Capital:** ~0 to pre-create/initialize a V3 pool (gas only); flash/arb capital optional for extraction  
**Timing:** after token address is known (curve live) and before graduation tx, **or** frontrun Direct Pool `createToken` if token address is CREATE-predictable / same-block race on pool key

1. Observe a bonding-curve token approaching 2.5 ETH `realEthCollected`, or watch mempool for DirectFactory launches.
2. Compute `token0/token1` ordering with WETH `0x0Bd7…AD73` and fee tier `10000` (1%).
3. Call Uniswap V3 Factory `createPool` + `initialize(fakeSqrtPriceX96)` (or initialize at extreme tick).
4. Wait for (or frontrun) `_graduate` / DirectFactory mint.
5. Pad deposits full raise + remaining tokens as full-range LP at **fake** price.
6. Arb the mispriced pool / pick up value from one-sided residual inventory.

---

## Impact

| Dimension | Value |
|-----------|--------|
| Auth | none |
| Capital | gas-only setup |
| Frequency | once per token graduation/launch (each is independently attackable) |
| Victims | all curve buyers (raise ETH) + future V3 traders; creator LP fee share degraded |
| Magnitude | up to ~entire graduation pot (~2.5 ETH net per bonding token at threshold, plus 200M LP tokens) per successful squat; Direct Pool = entire `liquidityEth` + 1B supply LP |

Honest severity: **High** (permissionless, repeated per token, large fraction of that token's raise). Not labeled Critical "drain all pads in one tx" because each launch is separate and attacker still needs timing/arb skill; bound is per-token liquidity, not global TVL in one shot.

---

## Proof of concept

Self-contained Foundry test (no mainnet / no real funds):

```bash
cd hunts/robinlaunch/poc
forge test --match-contract PoolSquatLogicTest -vv
```

File: `hunts/robinlaunch/poc/test/PoolSquatLogic.t.sol`

**Result (2026-07-19, forge 1.7.1):** **2/2 PASS**

```
[PASS] test_poolSquat_attackerPriceSurvivesGraduation()
Logs:
  VULN CONFIRMED: graduation used attacker sqrtPriceX96
[PASS] test_withoutSquat_honestPriceApplies()
```

Live read (cast, chain 4663): Factory v8 `totalTokens() = 9`, DirectFactory v3 `totalTokens() = 4`. Real launches exist; each graduation/list remains in-scope for this bug class.

Optional live fork check (read-only):

```bash
# After a known token address T is live and not yet graduated:
# cast call $UNIV3_FACTORY "getPool(address,address,uint24)(address)" $T $WETH 10000 --rpc-url $RPC
# If non-zero before graduation -> already squattable / possibly already compromised.
```

Static confirmation: verified source contains `createAndInitializePoolIfNecessary` + `amount0Min: 0` + no `slot0` check (grep-clean).

---

## Secondary notes (not the primary finding)

| Issue | Severity | Notes |
|-------|----------|-------|
| Creator fee push-payment DoS | Medium / griefing | `claimCreatorFees` uses raw `call{value}`; if `creatorFeeRecipient` is a contract that reverts on receive, fees stuck until recipient changed (creator can `setCreatorFeeRecipient`) |
| Owner fee withdrawal / setCreateFee | Trust | `onlyOwner` by design, not a permissionless exploit |
| Factory.createToken not `nonReentrant` | Low / informational | Initial `curve.buy` pays fees into Factory `receive`; no clear cross-function drain found |
| LpFeeCollector owner setMinter/setFactory | Trust | Owner can expand minters; cannot `decreaseLiquidity` (good). Still centralization. |

Auth triage expectation: `setCreateFee` / `withdrawFees` from `address(0xdead)` must revert (`Ownable`). Protocol owner powers only.

---

## Fix

1. **After** `createAndInitializePoolIfNecessary`, read `slot0` and **revert** if `sqrtPriceX96` is not the intended price (or outside a tight BPS band).
2. Set `amount0Min` / `amount1Min` to computed minimums with slippage bounds (e.g. 99% of desired).
3. Prefer a pool deploy pattern that cannot be front-run (hard on a public V3 factory), or revert if `getPool` is already non-zero before the pad's first init.
4. On bonding curve: return unused mint balances to LP recipient or re-add; never leave raise ETH stuck.
5. Optional: check `getPool(token,weth,fee)==address(0)` before graduation and revert if already created by a third party.

---

## Disclosure and compensation

Good-faith private disclosure. I would appreciate a bounty commensurate with a **High** on a live memecoin launchpad (per-token raise at risk on every graduation). I am **not** conditioning disclosure or fix on payment. Act on it now. Happy to walk the team through a patch and re-review.

deviykee
