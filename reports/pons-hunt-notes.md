# Pons (#21) - hunt notes (no High proven)

**Researcher:** deviykee  
**Date:** 2026-07-20  
**Status:** Website `pons.family` did not resolve from this environment (DNS/timeout). On-chain **PonsLaunchFactory** is live, verified (Sourcify exact), and fully reviewed. Instant single-sided Uniswap V3 + permanent locker. **No permissionless High claimed.** No mainnet exploit attempted.

---

## What this means in plain language (read this first)

Pons is an **instant Uniswap V3** launchpad (not a bonding-curve raise pad). `launchToken` deploys a fixed-supply token via CREATE2, opens a one-sided V3 position, locks the NFT, and can run an optional first buy in the same transaction.

The dangerous RH-chain class (pre-create pool at a fake price, pad dumps a held raise with zero mins) is **blocked** here by an explicit check:

```solidity
if (IUniswapV3FactoryLike(dex.factory).getPool(predictedToken, config.pairToken, dex.poolFee) != address(0)) {
    revert PoolAlreadyExists();
}
```

If a stranger pre-inits the predicted pool, the launch **reverts** instead of minting into a wrong price. There is also **no curve raise** sitting on the factory to steal.

---

## INTAKE

```
PROJECT_NAME   : Pons
WEBSITE        : https://pons.family/launchpad/create  (unresolved at hunt time)
CHAIN          : Robinhood Chain
RPC            : https://rpc.mainnet.chain.robinhood.com
CHAIN_ID       : 4663
EXPLORER       : https://robinhoodchain.blockscout.com
KNOWN_ADDRS    :
  ponsLaunchFactory=0xA5aAb3F0c6EeadF30Ef1D3Eb997108E976351feB
  locker=0x736d76699c26d0d966744cae304c000d471f7f35
  owner=0xda4bCee76B29EFEc9697Fcf663601c2042043968
  sample_token=0xea18CbA473858577c43b76B49aa9B2f65bB77084
  weth=0x0Bd7D308f8E1639FAb988df18A8011f41EAcAD73
  univ3_factory=0x1f7d7550B1b028f7571E69A784071F0205FD2EfA
  position_manager=0x73991a25C818Bf1f1128dEAaB1492D45638DE0D3
  swap_router=0xCaf681a66D020601342297493863E78C959E5cb2
PRODUCT_TYPE   : launchpad (instant single-sided V3 + locker)
BOUNTY/CONTEST : none / discretionary
NOTES          : Tokens named PonsLauncherToken; launch fee ~0.0005 ETH live; launchEnabled=true
RESEARCHER     : deviykee
```

Local: `hunts/pons/PonsLaunchFactory.sol`, `PonsLauncherToken.sol`.

---

## Architecture

| Step | Behavior |
|------|----------|
| Predict | CREATE2 address from salt + params |
| Gate | `getPool(predicted, pair, fee) == 0` or `PoolAlreadyExists` |
| Deploy | CREATE2 `PonsLauncherToken` |
| Pool | `createAndInitializePoolIfNecessary` at config tick |
| Liquidity | One-sided mint full `config.supply`, `amount0Min/amount1Min = 0` |
| Lock | NFT → `locker.lockPosition` |
| Optional | Native first buy with **`amountOutMinimum: 0`** |

Live: `launchConfigCount=1`, `dexConfigCount=1` (Uniswap v3, fee 10000 / 1%, tickSpacing 200).  
`graduationThreshold` on config is used by view `graduationStatus` (principal-in-position telemetry), **not** a curve migration path.

---

## Findings

### 1. V3 pool squat / wrong-price dump — mitigated (not High)

- Pre-existence check on **predicted** token address before deploy.  
- Same-tx createAndInitialize after deploy: no window for stranger init after check.  
- Instant single-sided → no held raise to dump (duke playbook: classic High is dead without raise).

Compare Hood Tech / MetaLaunch V12 mitigations.

### 2. First-buy `amountOutMinimum: 0` — residual Low/Medium lead

Optional opening buy accepts zero min out. With pool-pre-exists blocked, residual risk is normal sandwich of the creator's own first buy, not factory-side wrong pool. Bound = creator's first-buy ETH only.

### 3. Owner surfaces

Ownable2Step; owner can set fee, configs, whitelist, enable/disable launches. Centralization only.

### 4. Locker

Immutable `locker` address; position transferred then `lockPosition`. Locker bytecode not fully source-audited in this pass; principal lock claims should be verified on `0x736d7669…7f35` if reopened.

### 5. Website offline

Cannot validate frontend salt grinding or off-chain API. On-chain factory remains the source of truth.

---

## Severity summary

| Item | Severity |
|------|----------|
| V3 migration pool squat | **Mitigated** (`PoolAlreadyExists` + no raise) |
| First-buy minOut=0 | Residual sandwich / Low–Medium on creator funds only |
| Permissionless theft of user raise | **Not applicable** (instant listing) |

**Campaign status: HUNTED-NOTES**

deviykee
