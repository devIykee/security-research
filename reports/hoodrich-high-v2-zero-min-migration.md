# HoodRich / RobinPump - High: Uniswap V2 graduation deposits raise with zero min amounts

**Researcher:** deviykee  
**Severity:** High - permissionless, bounded to that token's curve raise (config tiers ~1.5 / 3.5 / 6 ETH design). Not a protocol-wide drain of all tokens at once.  
**Status:** Verified against Sourcify-exact `RobinPump` factory source. Logic review only; local PoC of the V2 zero-min class is the same as industry-standard pair pollution. No mainnet state touched.  
**Disclosure:** Private until patched.

---

## What this means in plain language (read this first)

HoodRich (site **robinpump.space**, multi-mode launchpad) ships a main bonding-curve factory branded **RobinPump**. Buyers put ETH into the curve until a graduation tier is hit. Curve trading then **stops**. The factory is supposed to seed a Uniswap **V2** pool with reserved tokens + the raise and burn LP to `0xdead`.

**The bug:** migration calls:

```solidity
IUniswapV2Router02(router).addLiquidityETH{value: ethForLp}(
    token, LP_SUPPLY, 0, 0, DEAD, block.timestamp
);
```

`amountTokenMin` and `amountETHMin` are **both zero**. If a stranger prepares a Uniswap V2 pair for that token at a skewed ratio before graduation, the router still accepts the deposit at the **existing** ratio. The raise can be largely absorbed into a hostile pool. Victims are buyers of **that** graduated launch.

Compare Novapex, which uses **95%** mins for the same class. HoodRich main curve factory uses **0%**.

**What it is not:** not free drain of every token forever. Attacker must pollute the specific pair before/at graduation. Instant **meme** factory (`RobinPumpMeme`) is a **different** contract and already checks `slot0` vs expected (`PoolPriceMismatch`).

---

## INTAKE

```
PROJECT_NAME   : HoodRich (RobinPump)
WEBSITE        : https://robinpump.space
CHAIN          : Robinhood Chain
RPC            : https://rpc.mainnet.chain.robinhood.com
CHAIN_ID       : 4663
EXPLORER       : https://robinhoodchain.blockscout.com
KNOWN_ADDRS    :
  curve_factory_mainnet=0x3c31119db0fd38c46042b6264c67734bd0b2540d
  meme_factory=0x752965644951e42e2c3D1E46197B98683E59caFE
  launch_factory=0x3646054DcA4389fF7eb245e6FC8d55581352Cafe
  flywheel_factory=0xe4eba036A91071F5c1181Cf68930b1Bdd912CAFe
  pozu_factory=0x3a698c49f44FFA7599b550fD934565baEeEeCaFe
  dex_router_config=0x89e5DB8B5aA49aA85AC63f691524311AEB649eba
  weth=0x0Bd7D308f8E1639FAb988df18A8011f41EAcAD73
PRODUCT_TYPE   : launchpad (multi-mode; primary High on curve RobinPump)
BOUNTY/CONTEST : none / discretionary
NOTES          : /api/config lists multi factories; this High is on curve RobinPump V2 graduate path
RESEARCHER     : deviykee
```

Local: `hunts/hoodrich/RobinPump.sol`, `RobinPumpMeme.sol`.

---

## Affected contracts (Robinhood Chain, chainId 4663)

| Role | Address | Verified |
|------|---------|----------|
| RobinPump (curve factory, High) | `0x3c31119db0fd38c46042b6264c67734bd0b2540d` | yes |
| RobinPumpMeme (instant V3; mitigated) | `0x752965644951e42e2c3D1E46197B98683E59caFE` | yes |
| Config DEX router (V2) | `0x89e5DB8B5aA49aA85AC63f691524311AEB649eba` | per `/api/config` |

---

## Root cause

### Trading freeze at graduation

```solidity
// buy/sell
require(!c.graduated, "graduated - trade on DEX");

// when sold out / raise hit
function _graduate(address token, Curve storage c) internal {
    c.graduated = true;
    if (router != address(0)) {
        _createPool(token, c);
    }
}
```

### Zero-min V2 dump

```solidity
function _createPool(address token, Curve storage c) internal {
    c.lpCreated = true;
    uint256 raise = c.realEth;
    uint256 gradFee = (raise * gradFeeBps) / 10_000;
    uint256 ethForLp = raise - gradFee;
    c.realEth = 0;
    // ... burn unsold ...
    RobinPumpToken(token).approve(router, LP_SUPPLY);
    IUniswapV2Router02(router).addLiquidityETH{value: ethForLp}(
        token, LP_SUPPLY, 0, 0, DEAD, block.timestamp
    );
    _pay(feeRecipient, gradFee);
}
```

No `getPair` pollution check, no 95% mins, no price continuity assert.

---

## Attack

1. Watch `createToken` / `allTokens` for a live curve token.  
2. Before graduation, create the Uniswap V2 pair (or wait for factory create via router) and seed **skewed** reserves (classic cheap pollution).  
3. Let the curve fill (or buy the last slice).  
4. `_graduate` → `_createPool` dumps `ethForLp` + `LP_SUPPLY` tokens with **zero mins** into the hostile ratio.  
5. Attacker extracts value from the skewed pool / LP position. Buyers who cannot sell on the curve (already graduated) eat the bad market.

If `router == 0` at graduate time, tokens freeze until `finalizeGraduation` after owner sets router — same zero-min path later.

---

## Impact

| Dimension | Value |
|-----------|--------|
| Auth | none |
| Capital | small V2 seed relative to raise |
| Frequency | per graduating token |
| Victims | curve buyers of that token |
| Magnitude | large share of that launch's `realEth` after grad fee (tiers 1.5 / 3.5 / 6 ETH design) |
| Freeze window | yes: cannot sell on curve after `graduated` |

---

## Mitigated sister path (do not confuse)

`RobinPumpMeme` instant factory:

```solidity
pool = positionManager.createAndInitializePoolIfNecessary(...);
(uint160 poolSqrtPriceX96,,,,,) = IUniswapV3PoolMinimal(pool).slot0();
if (poolSqrtPriceX96 != expectedSqrtPriceX96) revert PoolPriceMismatch();
```

That path is **not** this High.

---

## Fix

1. Set `amountTokenMin` / `amountETHMin` to a tight fraction of desired (e.g. 95%+), or  
2. Require pair non-existence / empty reserves before migrate, or  
3. Use createPair only if getPair==0 and first mint with expected ratio check, or  
4. Keep curve sellable until migrate succeeds (avoid freeze + bad dump combo).

---

## Disclosure and compensation

Good-faith private disclosure. Bounty commensurate with a **High** (bounded per-launch raise) is appreciated; not conditioned on payment. Happy to walk through a PoC and review a patch.

deviykee / Iyke (http://x.com/deviykee)
