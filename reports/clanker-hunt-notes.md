# Clanker — hunt notes (no High)

**Researcher:** deviykee  
**Date:** 2026-07-21  
**Severity:** Notes only — no permissionless High claimed  
**Status:** Verified source review + auth eth_call + live RH activity. Fork / eth_call only; nothing touched on mainnet.

## What this means in plain language

Clanker on Robinhood Chain is a **direct Uniswap v4 token launcher**. In one transaction it deploys a token, initializes a v4 pool at a chosen tick, and mints single-sided liquidity into a locker. It does **not** hold a bonding-curve raise that later migrates. That design kills the main High classes we have been finding on RH pads (V3 pool squat on graduation, V2 pollution freeze, V4 pre-init freeze of a trapped raise).

## Affected contracts (Robinhood Chain, chainId 4663)

| Role | Address |
|------|---------|
| Factory | `0xD3f2cC1731b7Fd17f28798835C2E02f0a1839A94` |
| LP Locker | `0x290F735F63824BB5836cDe24a35F5103A5B5Bc99` |
| Static / Dynamic hooks | `0x48B8F6…e8cc` / `0x65efDF…E8Cc` |
| MEV / Vault / Airdrop / DevBuy / FeeLocker | see `hunts/clanker/ADDRESSES.md` |

## Product surface

- **Type:** modular launchpad (instant V4, configurable fees, sniper/MEV tax module, vault/airdrop/devbuy extensions)  
- **Factory:** `Clanker` version string `"4"` — verified Sourcify match  
- **Token:** CREATE2 via `ClankerDeployer` with salt `keccak256(tokenAdmin, salt)`; vanity suffix finder used by frontend  
- **Liquidity:** single-sided meme tokens only (`amount` of paired = 0); positions require `tickLower >= tickIfToken0IsClanker`  
- **Modules enabled only by owner/admin** (`setHook` / `setLocker` / `setExtension` / `setMevModule`)

## Step 4 — auth triage

From attacker `0x…dEaD` via `eth_call`:

| Function | Result |
|----------|--------|
| `setDeprecated` / `setTeamFeeRecipient` / `claimTeamFees` | guarded |
| `setHook` / `setLocker` / `setMevModule` / `setExtension` | guarded |

No free-win missing access control on factory admin surface.

## Classic High classes — result

| Class | Result on Clanker |
|-------|-------------------|
| V3 migration pool squat | **N/A** — no V3 graduation / no raise migrate |
| V2 pair pollution / zero-min migrate | **N/A** |
| V4 pre-init graduation freeze | **Dead as High** — `poolManager.initialize` is hard; pre-init makes **atomic** `deployToken` revert. No raise sits on a curve. Creator can re-salt. At most salt grief if address known early |
| Flash snapshot distribution | **N/A** on factory; airdrop is Merkle + lockup |
| Permissionless admin | **Not found** on factory |

### V4 initialize detail (why pre-init is not StockDotFun-class)

Hook `_initializePool` always calls:

```solidity
poolManager.initialize(_poolKey, initialPrice);
```

If the pool key is already initialized, Uniswap v4 reverts. Factory `deployToken` is `nonReentrant` and does deploy → init → liquidity → extensions in one call. Failure rolls back; factory balance stays ~0.

### Liquidity placement

`ClankerLpLockerFeeConversion.placeLiquidity` is `onlyFactory`. Mints with `amount0Max`/`amount1Max` equal to intended single-sided amounts (not a raise dump into a stranger-chosen price). Starting price is set by the same factory path in the same tx.

### Extensions

- **Vault:** min 7d lockup; claim after unlock/vest to admin — trust/creator design  
- **Airdrop V2:** Merkle `keccak256(bytes.concat(keccak256(abi.encode(recipient, amount))))`; admin can update root only if zero claims and (root zero or 1d post-lockup overwrite window); admin residual claim after expiration — trust residual, not stranger drain  
- **DevBuy:** ETH → (optional intermediate) → token; final swap `amountOutMinimum: 1` is creator self-slippage on their own dev buy, not third-party custody  

### MEV module

`ClankerMevDescendingFees`: same-second trade blocked; descending LP fee for up to `MAX_MEV_MODULE_DELAY` (2 minutes). Fee to LPs/protocol, not an attacker free mint.

### Fee locker

Pull pattern `claim(feeOwner, token)` sends to `feeOwner` only. Depositors allowlisted by owner.

## Trust / residual notes (not High)

1. Owner/admin can enable malicious hook/locker/extension modules (centralization).  
2. Airdrop admin can rewrite Merkle root under narrow conditions or claim leftovers after expiry.  
3. Token admin can update metadata/image/admin.  
4. Predictable CREATE2 + hard initialize → possible **deploy grief** if salt/token address leaked before inclusion (no fund theft).  
5. Dev buy final min-out of 1 is weak slippage for the creator’s own ETH.

## Severity call

**No High.** Instant single-sided V4 listing with verified module gates and no raise-holding graduation path. Does not match paid High patterns from Robinlaunch / Openfair / StockDotFun / HoodRich / TheIndex.

## Next steps (if re-opening)

- Diff future factory version if redeployed  
- Hunt optional third-party **pool extensions** on allowlist when new ones ship  
- Bankr uses Clanker ecosystem coins; Bankr itself has no separate RH pad factory in the app bundle  

## Disclosure

Notes only. No live-exploitable permissionless bug claimed. No DM required for a High.

deviykee
