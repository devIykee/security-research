# NOTES — GoPlus Locker V3

Session: 2026-08-17. Agent: weaker-audits-iyke. Researcher: deviykee.

## Gate

- Live DefiLlama TVL: **$27.57M** (BSC $27.09M, Base $474k, ETH $10.5k, Arb $457). Material. Hunt V3.
- Custom locker: official SafeToken Locker docs + DefiLlama adapter `owners=['0x25c9…Bd52']`.
- Sourcify **exact_match** `UniV3LPLocker` (solc 0.8.20). Not a thin wrapper. No public third-party locker audit found.
- Product: UniV3 NFT liquidity locker. TokenLocker `0xF17A…C04b` is V2 (~$333k). UniV4 lockers not in V3 adapter.

## Step 1

BSC `https://bsc.publicnode.com` chainId 56, block 116470611. PASS.

## Step 2 cores

| Role | Address |
|------|---------|
| UniV3LPLocker (V3 pot) | `0x25c9C4B56E820e0DEA438b145284F02D9Ca9Bd52` (same on ETH/BSC/Base/Arb) |
| TokenLocker (V2, out of Y) | `0xF17A08A7d41F53B24AD07Eb322CBBdA2ebdeC04b` |
| Owner (EOA) | `0x296812aa1e707370e414f72F0680801e8666B50F` |
| feeReceiver (EOA) | `0x521faAcDFA097ad35a32387727e468F7fD032fD6` |
| customFeeSigner (EOA) | `0x333A16307d8bEf80616F719E958Af5C76290CA85` |

BSC allowlisted NPMs: Pancake V3 `0x46A15B0b27311cedF172AB29E4f4766fbE7F4364`, UniV3-style `0x7b8A01B39D58278b5DE7e48c8449c9f4F5170613`.
nextLockId BSC=4317, ETH=66. Not a proxy (EIP-1967 empty). Native balance 0.002 BNB leftover.

Live fees: DEFAULT 40/160, LVP 64/80, LLP 24/280 (bps of 10_000). Sample locks are Pancake V3, collectFee=160, many owned by `0x5c9520…762b` (token factory) with collector `0x487359…30b9`. Lock 4316 endTime = uint256.max (forever).

## Step 3

Verified. Y=4 production files (OZ excluded). See coverage.md.

## Step 4

All probed money-movers from `0x…dEaD` **guarded**: unlock, transferLock, acceptLock, relock, setCollectAddress, collect, adminRefund*, updateFee*, addSupportedNftManager, transferOwnership, renounceOwnership, removeFee. No OPEN.

## Step 5 foundation

### 5A who-writes

| State | Writer |
|-------|--------|
| fees / feeNameHashSet | owner `addOrUpdateFee` / `removeFee` |
| feeReceiver / customFeeSigner | owner |
| nftManagers | owner add-only (no remove) |
| disabledSigs | owner |
| locks / userLocks / nextLockId | `lock`/`lockWithCustomFee` (public); owner fields via validLockOwner / acceptLock |
| Ownable owner | owner |

### 5B CEI

- `lock` / `unlock` have **no** `nonReentrant`. External: NFT transfer, NPM collect/decrease, ERC20 transfers, then state write (`unlock` deletes lock last).
- `collect` / `increaseLiquidity` / `decreaseLiquidity` / `relock` / adminRefunds **are** `nonReentrant`.
- Cross-function: unlock can reenter lock/unlock/transfer (unguarded) but not collect/increase (guarded).

### 5C token paths

User NFT → locker via `safeTransferFrom(msg.sender)`. Liquidity stays in the NFT. Exit: owner after `endTime` via `unlock` (NFT out) or `decreaseLiquidity` (tokens out). Trading fees: owner or collector → recipient, minus stored `collectFee` to feeReceiver. On lock, `lpFee` % of liquidity is decreased and collected to feeReceiver. Anyone may `increaseLiquidity` (pays tokens in).

### 5D access

| Function | Gate |
|----------|------|
| lock / lockWithCustomFee | public; custom path needs fee signer |
| increaseLiquidity | public (by design) |
| collect | lock owner OR collector |
| unlock / decreaseLiquidity | validLockOwner + endTime < now |
| relock | validLockOwner; endTime can only increase |
| transferLock | validLockOwner → pending |
| acceptLock | msg.sender == pendingOwner |
| adminRefundEth/ERC20, fee/NPM admin | onlyOwner |

### 5E checklist

- Reentrancy / CEI: UNCLEAR (lock/unlock unguarded) → killed as stranger drain (see 5.5)
- Access control on privileged writers: PASS
- Oracle / pricing: PASS (none; face NFT)
- Slippage on DEX: UNCLEAR (lpFee decrease uses 0 mins; MEV on fee take only)
- Frontrun / sandwich: PASS for principal (fee-take MEV only)
- Init / proxy: PASS (non-proxy, constructor Ownable)
- Upgrade storage: PASS (not upgradeable)
- Pause: PASS (none; exits stay owner-gated)
- Events on policy: PASS (fee/signer/NPM)

## Step 5.5 scoreboard

| Angle | Path | Result |
|-------|------|--------|
| Malicious | stranger unlock / decrease / collect | blocked by validLockOwner / owner\|\|collector |
| Malicious | stranger transferLock / accept | blocked; accept needs pendingOwner |
| Malicious | victim approve locker, attacker lock() | `safeTransferFrom(msg.sender)` — attacker cannot pull victim NFT |
| Malicious | increaseLiquidity steal leftovers / donations | balance-before snapshot; donation stays; underflow on FoT+leftover |
| Malicious | reenter unlock to double-transfer NFT | second unlock would transfer then first reverts (same tx) |
| Malicious | reenter collect during unlock to skim in-flight fees | second collect delta=0; increaseLiquidity snapshot includes in-flight |
| Economic | FoT / rebase steal | V3 uses balance deltas on collect; leftover + FoT reverts |
| Economic | lpFee > 100% | onlyOwner; new locks only; decrease reverts if liquidity exceeded |
| State | missing modifier on money-mover | none OPEN from dEaD |
| State | lock/unlock unguarded | sloppy; no permissionless drain |
| Edges | relock shorten | require new end > old and > now |
| Edges | increment/split | N/A (NFT atomic). V2 `updateLock` requires moreAmount>0 and later endTime |
| Edges | lockId 0 / deleted lock collect | nftId=0 / owner=0, revert |
| External | malicious NPM | owner add-only; existing locks store NPM immutably |
| External | onERC721Received always accepts | stray NFTs stuck; no admin NFT rescue; not a drain of locked ones |
| External | customFee encodePacked(string) | SWC-133 self-grief / promo voucher; sig bound to msg.sender+chainid |
| External | customFeeSigner == 0 | live signer is EOA, not zero |
| Admin | adminRefundERC20 steal locked NFT | ERC20 transfer; cannot move ERC721. **Cannot drain locked NFTs** |
| Admin | adminRefund leftover ERC20 during increaseLiquidity | owner sandwich; Trust |
| Admin | set 100% fee / malicious NPM | new locks only; Trust |

## Step 6 locker questions

1. **Premature unlock** — killed. `endTime < now` + owner.
2. **Owner drain of locked NFTs** — killed. No admin unlock / migrate / NFT approval. adminRefund is leftover ERC20/ETH only.
3. **FoT / rebase accounting** — killed for stranger theft on V3 collect/increase.
4. **Increment / split** — V3 N/A. V2 TokenLocker (skim, not in Y): cannot 0-amount reset; cannot shorten.
5. **Vesting math** — V3 none. V2: tge+cycle; `cycle==0` permanently locks (locker self-grief). `updateLock` blocked after any unlock.
6. **Lock-owner vs stranger** — stranger cannot unlock, decrease, transfer, or collect. Collector can only collect trading fees, not liquidity.
7. **CEI** — inverted on lock/unlock; killed as fund-loss (see 5.5).

## Verdict

**No permissionless Critical.** No Step 7 / 9.

Trust/centralization (not Critical): owner, feeReceiver, and customFeeSigner are EOAs. Owner can retarget fees/signer, add NPMs, and sweep leftover ERC20/ETH. Owner cannot withdraw locked UniV3 NFTs.

Coverage: 4/4 V3 production files (100% of Y). Path-scoped to UniV3LPLocker. TokenLocker V2 and UniV4 not in Y.

## Killed paths (do not reopen without new evidence)

1. Permissionless unlock / drain of locked NFTs
2. Relock / updateLock shortening endTime
3. Open adminRefund / fee / ownership / diamondCut (no diamond)
4. Stranger collect of principal
5. increaseLiquidity leftover / donation theft
6. FoT share inflation
7. customFeeSigner zero-address recover
8. Cross-user signature replay
9. Reentrancy double-unlock / in-flight fee steal
10. V2 increment-reset and vesting underflow under live constraints
