# Openfair - High: Uniswap V3 graduation / seed pool squat

**Researcher:** deviykee  
**Severity:** High  
**Status:** Verified against fully verified Blockscout source for `LaunchFactory` + `OpenLaunch`. Same root cause class as Robinlaunch. Logic covered by shared self-contained Foundry PoC (`hunts/robinlaunch/poc`, identical Uniswap `createAndInitializePoolIfNecessary` semantics). No mainnet state touched.  
**Disclosure:** Private until patched.  
**X:** @OpenFairApp

---

## What this means in plain language (read this first)

Openfair lets people launch tokens on Robinhood Chain. In fair-launch mode, the community buys on a bonding curve until enough ETH is raised (about 5 ETH per their docs). The app is then supposed to put that ETH and a reserve of tokens into a Uniswap pool at a correct starting price, with liquidity locked so nobody can rug the LP.

**The bug:** a stranger can create that Uniswap pool *before* graduation (or before / around an instant listing) and set the starting price to whatever they want. They only need gas. They do not need the token. When Openfair "graduates" or seeds the pool, it does not check that the price is the one it computed. It dumps the community raise (or listing liquidity) into the attacker-chosen market.

**Why that is dangerous:**

- Community ETH raised for a fair launch can be locked into a rigged price instead of the intended fair market.
- The attacker can trade against that pool and extract value. Buyers on the curve can lose a large share of *that token's* pot.
- No special role is required. Anyone on the internet can run the setup.
- Instant listing paths that seed Uniswap the same way are exposed too, including single-sided listings that trust whatever price already sits on the pool.
- Every future launch that uses these paths stays at risk until the contracts are fixed.

**What it is not:** not a one-shot drain of all Openfair activity forever. Impact is per launch (up to that launch's raised ETH and LP tokens). Severity is **High**, not Critical, because the bound is per token, not "empty the whole protocol in one transaction." It is still a serious loss for people who funded a vulnerable launch.

**Analogy:** the app promises to put everyone's contributions into a public market at the right sticker price. A thief can open the market stall first with a fake sticker price. When the app auto-stocks the stall, it never checks the sticker, so the thief can buy cheap or sell expensive against that inventory.

---

## INTAKE

```
PROJECT_NAME   : Openfair
X_HANDLE       : @OpenFairApp
WEBSITE        : https://openfair.app
DOCS           : https://openfair.app/docs
CHAIN          : Robinhood Chain
RPC            : https://rpc.mainnet.chain.robinhood.com
CHAIN_ID       : 4663
EXPLORER       : https://robinhoodchain.blockscout.com
KNOWN_ADDRS    :
  launch_factory=0x2505522fF2796E4152277028f75626F9136dA0cF
  fair_token_deployer=0x12F394C101bA7ed4dbb71b978060F89B7c958143
  simple_token_deployer=0x69B229843fD08E76D55373901CB57dE571987c36
  promotions=0x1aF3Cc534ad6F78eEaBCFfe295FA0210CdFf6b31
  weth=0x0Bd7D308f8E1639FAb988df18A8011f41EAcAD73
  swap_router=0xCaf681a66D020601342297493863E78C959E5cb2
PRODUCT_TYPE   : launchpad
BOUNTY/CONTEST : none / discretionary
NOTES          : Fair launch bonding curve (~5 ETH) + instant Uniswap V3 listing; LP locked in harvester
RESEARCHER     : deviykee
```

---

## Affected contracts (Robinhood Chain, chainId 4663)

| Role | Address | Verified |
|------|---------|----------|
| LaunchFactory | `0x2505522fF2796E4152277028f75626F9136dA0cF` | yes |
| OpenLaunch (per-token curve; logic in factory sources) | deployed per launch | yes (`src/OpenLaunch.sol` via Factory) |
| FairTokenDeployer | `0x12F394C101bA7ed4dbb71b978060F89B7c958143` | yes |
| Owner (cast) | `0x5aF99e6aad5F7c09eb16115204a02217a448B157` | n/a |

Frontend config extracted from `https://openfair.app` JS bundle (`factory: 0x2505…`).

---

## Technical summary

Openfair graduates fair launches and seeds instant listings by calling Uniswap V3  
`NonfungiblePositionManager.createAndInitializePoolIfNecessary(...)` then minting LP with  
**`amount0Min = 0` / `amount1Min = 0`** and **no require that `slot0().sqrtPriceX96` equals the intended price**.

Anyone can **pre-create + initialize** the `token/WETH` pool at an arbitrary `sqrtPriceX96` before graduation (or before/alongside an instant list). The pad reuses that pool, **ignores** its intended price, and deposits community raise / listing liquidity into an **attacker-chosen market**. Classic **migration pool squat (v3)**.

---

## Root cause

### A) Fair-launch graduation: `OpenLaunch.graduate()`

```solidity
uint160 sqrtPriceX96 = _sqrtPriceX96(amount0, amount1);
address pool = positionManager.createAndInitializePoolIfNecessary(
    token0, token1, poolFeeTier, sqrtPriceX96
);

(uint256 tokenId,, uint256 used0, uint256 used1) = positionManager.mint(
    INonfungiblePositionManager.MintParams({
        ...
        amount0Desired: amount0,
        amount1Desired: amount1,
        amount0Min: 0,
        amount1Min: 0,
        recipient: address(this),
        deadline: block.timestamp
    })
);
// NO: require(IUniswapV3Pool(pool).slot0().sqrtPriceX96 == sqrtPriceX96)
```

File: `hunts/openfair/src/src_OpenLaunch.sol` ~710-730.

### B) Instant dual-sided seed: `LaunchFactory._seedAndLockPool`

```solidity
pool = npm.createAndInitializePoolIfNecessary(token0, token1, feeTier, sqrtPriceX96);
// mint amount0Min: 0, amount1Min: 0
```

File: `hunts/openfair/src/LaunchFactory.sol` ~420-438.

### C) Single-sided listing: `_singleSidedLockPool` (still broken)

Reads `slot0()` **after** create, but only to **align ticks to whatever price already exists**, not to reject a squat:

```solidity
pool = npm.createAndInitializePoolIfNecessary(...);
(, int24 tick,,,,,) = IUniswapV3PoolState(pool).slot0();
// uses tick for range; attacker who pre-inited controls that tick
```

File: `LaunchFactory.sol` ~473-508.  
So single-sided mode does **not** mitigate the squat; it mints the one-sided range around the **attacker** price.

---

## Attack

1. Token address known (fair launch live on curve, or CREATE address predicted / same-block for instant list).
2. Attacker: Uniswap V3 Factory `createPool(token, WETH, fee)` + `initialize(fakeSqrtPriceX96)`. Zero meme tokens required.
3. Permissionless `graduate()` (or factory seed path) runs.
4. Pad mints full-range (or single-sided) LP at fake price with min amounts 0.
5. Attacker arbs mispriced liquidity / extracts value from community raise.

**Auth:** none · **Capital:** gas · **Frequency:** once per launch · **Victims:** all curve buyers / listing LPs for that token.

---

## Impact

| | |
|--|--|
| Auth | none |
| Capital | gas-only setup |
| Bound | entire `ethCollected` at graduation + `graduationTokens` LP inventory; or instant-list `liquidityEth` + pool tokens |
| Docs claim | fair launch collects **5 ETH** from community (openfair blog) before graduation; that pot is the natural magnitude per token |

**Severity: High** (permissionless, repeated per token, large share of that token's raise). Not Critical global drain of every Openfair launch in one tx.

---

## Proof of concept

Same Uniswap semantics as Robinlaunch (proven locally):

```bash
cd hunts/robinlaunch/poc
forge test --match-test test_poolSquat_attackerPriceSurvivesGraduation -vv
# PASS: VULN CONFIRMED: graduation used attacker sqrtPriceX96
```

Static: verified Openfair sources contain `createAndInitializePoolIfNecessary` + `amount0Min: 0` + no intended-price equality check on dual-sided paths.

Optional live check for a not-yet-graduated Openfair token `T`:

```bash
cast call $UNIV3_FACTORY "getPool(address,address,uint24)(address)" $T $WETH $FEE --rpc-url $RPC
# non-zero before graduate => already pre-created (squattable / possibly compromised)
```

---

## Fix

1. After `createAndInitializePoolIfNecessary`, **require** `slot0.sqrtPriceX96 == intended` (or tight BPS band).
2. Non-zero `amount0Min` / `amount1Min` from desired amounts.
3. Prefer revert if `getPool != address(0)` before first init by the pad.
4. Single-sided path: same price integrity check **before** trusting `slot0` for tick math.

---

## Disclosure and compensation

Good-faith private disclosure to @OpenFairApp / any security contact on openfair.app.  
Bounty commensurate with a **High** on a live RH Chain launchpad appreciated. Not conditioned on payment. Happy to review a patch.

deviykee
