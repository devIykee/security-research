# Robinfun - High: cheap Uniswap V2 pair pollution freezes graduation and traps raise ETH

**Researcher:** deviykee  
**Severity:** High  
**Status:** Verified against fully verified Factory V2 source on Blockscout. Logic proven with local Foundry unit tests. Live Factory V5 is the current whitepaper factory (unverified) but exposes the same buy/sell/price admin surface; V2 is the audited published implementation. No mainnet state touched.  
**Disclosure:** Private until patched.

---

## What this means in plain language (read this first)

Robinfun is a memecoin launchpad. Buyers put ETH into a bonding curve until a dollar target is hit. Then the app is supposed to move that ETH plus reserved tokens into a Uniswap V2 pool and burn the LP so liquidity stays locked.

**The bug:** when the raise is hit, trading on the curve freezes and only a final `graduate` step can finish. Anyone can prepare a tiny Uniswap V2 pool for that token first (very little capital). Then the normal `graduate` call reverts as "polluted." Buyers can no longer sell on the curve. The only escape is an **owner-only** recovery path that sends the **entire raise to the treasury**, not back to buyers automatically.

**Why that is dangerous:**

- Strangers can freeze a token the moment it should graduate, with dust-level WETH pollution cost relative to the raise (for a 3 ETH LP slice, about 0.000003 ETH of WETH on the pair is enough to fail the dust check).
- Users who bought on the curve cannot exit while `readyToGraduate` is true.
- Recovery is not permissionless and does not refund buyers line by line. Owner takes the raise to treasury and may or may not make users whole.
- Live Factory V5 holds multiple ETH of protocol balance (on the order of ~6.9 ETH when checked) and is the whitepaper "current" factory, while full source for V5 is not verified. Same product class of risk until V5 is published and proven fixed.

**What it is not:** not a free one-click drain of every token's raise without setup. Attacker must pollute the pair (and typically hold a bit of the token to mint a real V2 position). Severity is **High** because the freeze is permissionless, cheap relative to funds trapped, and user exit is cut off until owner acts.

**Analogy:** the fundraiser locks the doors when the goal is hit and says "we will open the public market now." A stranger can jam the lock for pennies. Until staff use a back room key, nobody can leave, and staff may take the cash box to the office instead of handing it straight back to donors.

---

## INTAKE

```
PROJECT_NAME   : Robinfun
X_HANDLE       : @robinfunxyz
WEBSITE        : https://robinfun.live
DOCS           : https://robinfun.live/whitepaper
CHAIN          : Robinhood Chain
RPC            : https://rpc.mainnet.chain.robinhood.com
CHAIN_ID       : 4663
EXPLORER       : https://robinhoodchain.blockscout.com
KNOWN_ADDRS    :
  factory_v5_current=0xd861cb5DC71A0171E8F0f6586cADb069f3A35E4d
  factory_v2_verified=0xD69A9fDee44a42c8E614128FEda486128cB27222
  factory_v4_legacy=0x42B1f2Fb09502b66Ae21769b3384a7788d020d73
  factory_v3_legacy=0x9A4a94Bd3aF6acF5567A3B22f264E08B0962B8c8
  staking_eth=0x2cE2B3B7bC9A0093681Fc280b1bF77C30DB3f1a3
PRODUCT_TYPE   : launchpad
BOUNTY/CONTEST : none / discretionary
NOTES          : V2 Uniswap graduation; vanity token suffix 0x4663; post-audit hardening comments in V2
RESEARCHER     : deviykee
```

---

## Affected contracts (Robinhood Chain, chainId 4663)

| Role | Address | Verified |
|------|---------|----------|
| RobinFunFactory V2 (analyzed) | `0xD69A9fDee44a42c8E614128FEda486128cB27222` | yes (`RobinFunFactoryV2`) |
| RobinFunFactory V5 (current per whitepaper, holds ~6.9 ETH) | `0xd861cb5DC71A0171E8F0f6586cADb069f3A35E4d` | no |
| Owner (V5 cast) | `0xf94a68B1d082B786F85e65466e9b9Ffd5fc58821` | n/a |

Source: Blockscout + whitepaper. Local copy: `hunts/robinfun/src/RobinFunFactoryV2_0xD69A9fDe.sol`.

---

## Technical summary

1. When `realEth >= raiseTarget`, `_buy` sets `readyToGraduate = true`.
2. `buy` / `sell` both require `!c.readyToGraduate` (and `!c.graduated`). Curve trading stops.
3. Permissionless `graduate(token)` is the only public finalize path. It:
   - Creates or reuses `uniFactory.getPair(token, WETH)`
   - If `pair.totalSupply() != 0`, requires dust-sized reserves:
     `wethRes * 1e6 <= lpEth && tokRes * 1e6 <= LP_SUPPLY`
   - Otherwise reverts `PAIR_POLLUTED`
4. `graduateWithRecovery` is **onlyOwner**, sends **entire** `curveEth` to treasury, burns tokens, does not auto-refund buyers.

So a cheap material pollution (or even a one-sided reserve that fails the dust test after a pre-mint) turns graduation into an owner-gated freeze of the full raise.

---

## Root cause

### Freeze after raise

```solidity
// _buy when raise hit
if (c.realEth >= c.raiseTarget) {
    c.readyToGraduate = true;
    emit ReadyToGraduate(token, c.realEth);
}

// buy/sell
require(!c.graduated && !c.readyToGraduate, "NOT_TRADABLE");
```

### Pollution gate (too tight / griefable)

```solidity
uint256 public constant POLLUTION_DUST_FACTOR = 1e6;
// ...
if (pairTs != 0) {
    IUniswapV2Pair(pair).sync();
    // ...
    require(
        wethRes * POLLUTION_DUST_FACTOR <= lpEth && tokRes * POLLUTION_DUST_FACTOR <= LP_SUPPLY,
        "PAIR_POLLUTED"
    );
}
```

For `lpEth = 3 ether`, minimum WETH reserve to fail the check is `3e18/1e6 + 1 = 3_000_000_000_001` wei (~0.000003 ETH).

### Recovery takes raise to treasury

```solidity
function graduateWithRecovery(address token) external onlyOwner nonReentrant {
    // ...
    if (curveEth > 0) {
        _payTreasury(curveEth);
    }
    // burn tokens; no buyer refund loop
}
```

---

## Attack

1. Launch or watch a Robinfun token (V2 path; confirm V5 still uses same gates if source is released).
2. Before raise completes: buy a small amount of tokens on the curve; `createPair(token, WETH)` if needed; seed a real V2 mint so `totalSupply > 0` with reserves above the dust thresholds (WETH side alone can be enough if paired with enough token).
3. Let the raise hit `readyToGraduate` (or buy the last ETH yourself).
4. Call `graduate(token)` -> reverts `PAIR_POLLUTED`.
5. Buyers cannot `sell`. Funds sit until owner runs `graduateWithRecovery` (treasury gets raise) or somehow cleans the pair.

**Auth:** none for freeze  
**Capital:** dust relative to raise (plus tiny token purchase / gas)  
**Victims:** all curve buyers of that token  
**Bound:** full `realEth` / raise for that token trapped until owner acts

---

## Impact

| Dimension | Value |
|-----------|--------|
| Auth | none (freeze); owner-only recovery |
| Capital | ~dust vs raise |
| Frequency | once per token that can be polluted before graduate |
| Magnitude | up to full curve raise for that token (USD targets ~$9.3k at snapshot in V2 comments) |

Honest severity: **High** (permissionless freeze + user exit cut off + recovery centralization). Not Critical free theft without owner path, but live risk is real.

Secondary trust notes (not the main finding): owner can set ETH/USD freely; keeper can move price within band; CTO can reassign fee recipients.

---

## Proof of concept

```bash
cd hunts/robinfun/poc
forge test --match-contract PairPollutionGriefTest -vv
```

**Result:** 2/2 PASS. Logs min WETH wei `3000000000001` to block graduation for 3 ETH `lpEth`.

Static: V2 verified source as quoted above.

V5 live read (cast): `owner`, `WETH`, `router` present; `buy`/`sell`/`setEthUsdPrice` selectors match product class. Full V5 audit blocked by missing verification.

---

## Fix

1. Do not freeze sells on `readyToGraduate` until LP is actually burned, or allow sell until graduate succeeds.
2. If pair is polluted, auto-path should not depend on owner alone (e.g. create a new salt-isolated pair, or refund buyers proportionally permissionlessly).
3. Raise `POLLUTION_DUST_FACTOR` only does not fix freeze; remove the frozen middle state.
4. Publish and verify V5 source; confirm same gates are fixed or document why not.
5. Prefer router-independent mint into a pair that only the factory can create (hard on public Uni V2 factory).

---

## Disclosure and compensation

Good-faith private disclosure. Bounty commensurate with a **High** on a live launchpad appreciated. Not conditioned on payment. Happy to review a patch.

deviykee
