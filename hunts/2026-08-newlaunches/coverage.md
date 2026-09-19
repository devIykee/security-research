# Coverage - multi-target screen (33 protocols)

| Target | Status | Notes |
|---|---|---|
| triage all 33 | done | recon/*.json, summarize.py |
| valos | active | Accountable private credit vault 0x8d3F9f9Eb2f5E8B48EFBB4074440D1E2A34Bc365 (Monad), unverified on Sourcify |
| agua | active | OpportunityOVault LZ-OFT+4626; eth 0xa98b4a70e17e55045cde4972b95bc2e8cec22a0f, monad 0x2abc42250154752273a4560e875c858623f83ecc |
| axis / azverse / bdex / others | pending | bundle grep empty -> step 2C/2D needed |

## AGUA deep pass (2026-08-26)
Files: OpportunityOVault.sol full read (769 lines, verified source via eth.blockscout).
Paths traced: deposit/requestRedemption/completeRedemption/redeemEarly/cancelRedemption/_updateRateFactor/_getCurrentRateFactor/_compoundFactor/_calculateRedemptionAssets/_lzReceive/_broadcastStateUpdate/_handleStateSync/_payNative/adminWithdraw/peer mgmt.
KILLED: cross-chain rate-factor arb — live factors ETH 1.018743e27@1787685491 vs MON 1.018467e27@1787595789 normalize to ~1.000002 ratio; no extractable gap.
KILLED: lzReceive length-heuristic forgery (peer-auth blocks non-peer senders); compose misroute requires peer origin.
OPEN (latent, env-triggered): dropped/out-of-order LZ state msg -> permanent path-dependent factor divergence -> grows unbounded (no gap-fill). Medium-High conditional.
TRUST: ETH vault holds $44.81 USDC vs $6.795M totalAssets(); redemptions depend on 3/5 MPC admin rebalance. By-design, disclosed in docs.
VERDICT: no permissionless Critical today. Moving on.

## AZVERSE AssetVault pass
Files: src/AssetVault.sol FULL READ (873 lines).
Paths traced: requestWithdraw/rebalanceWithdraw/batchTogglePendingWithdrawal/executeExpiredPendingWithdrawal/batchFlushWithdrawals/_verifyValidatorSignature/_nonceUsedCheckAndSet/_transfer/_refillWithdrawHotAmount/_increaseUsedWithdrawHotAmount/initialize/_authorizeUpgrade.
KILLED: sig double-count (forward-pointer scan); malleability replay; cross-chain digest replay (chainid+address bound); nonce reuse (global one-time); init hijack (constructor disables); reentrancy (guards + CEI ok).
NOTED (trust): VALIDATOR_ROLE self-manages validator set incl requiredPower -> quorum is team-controlled; custodian EOAs hold majority TVL off-contract.
Status: contract code clean; on-chain role check queued. Pivot to Axis.

## AXIS pass
Files: USDxMarket.sol FULL READ (678 lines), StakedUSDx.sol FULL READ (1258 lines).
Paths traced: settle/_checkSettlement/_checkOrder/_isValidOrderSignature/delegated signer enrollment/requestRedeem/serviceRedemptions/serviceRedeemRequest/cancelRedeemRequest/withdraw/redeem/_claimRedeemByShares/_claimRedeemByAssets/_restoreClaimIndexForServicedRequest/fundRewards/_checkpointRewards/_vestedRewards/_rescheduleActiveRewards/rescueTokens/redistribute*/initialize.
KILLED: order replay (EIP712+chainid+addr, nonce bitmaps, settled flag); delegated-signer takeover (two-step, source-controlled); claim rounding theft (floor/ceil directions correct + anti-roundup guard); rescue stripping liabilities (surplus guard); reward vesting double-count (checkpoint-before-convert); cancel accounting asymmetry (symmetric restore).
NOTED (trust): operator-signed settlement = offchain pricing trust; whitelist-gated signers -> no perm-less entry.
VERDICT: clean. Pivot to FermiSwap (unverified engine).

## FERMISWAP pass
Files: FermiSwapper.sol FULL READ (104 lines, verified); PrioUpdateRegistry.sol FULL READ (259 lines, verified); engine bytecode selector map.
Paths traced: fermiSwapWithAllowances/fermiSwapWithCallback/setFermi/setTraderVault/quote/swap behavioral probes/updateState/_writeState/batchUpdateStateWithSignature/getState.
KILLED: fallback-swallow false OPENs (verified non-reverting fallback -> all guarded fns actually guarded); oracle injection (registry writes updater/EIP712-gated); callback double-spend (WTA balance check + per-swapper nonReentrant).
NOTED: venue currently halts with StaleUpdate (keeper param lag) = liveness/trust; exact-out amountCheck=0 = full engine trust; engine+vault UNVERIFIED bytecode.
VERDICT: no permissionless Critical. Moving to BDEX diff + Robinhood bridge recon.

## BDEX pass
Files: UniswapV2Factory.sol FULL READ (50); BDexV3LiquidityLocker.sol FULL READ (878); BDexV2Locker FULL READ (710).
Paths traced: lock/collect/_collect/collectBatchPreview/increaseLiquidity/decreaseLiquidity/withdraw/relock/migrate/incrementLock/splitLock/transferLockOwnership/lockLPToken/setUCF/adminRefund*.
KILLED: ucf bypass on decrease (design, dust-level only); balance-diff donation theft (neutral); preview state mutation (revert-atomic); eternal-lock escape; storage-set cleanup bugs.
VERDICT: UNCX-derived, clean. TVL in standard pairs. No perm-less Critical.

## ROBINHOOD CHAIN BRIDGE pass
Vanilla Arbitrum Orbit (Offchain Labs deployed), verified proxies, 8-sig council + BoLD. Custom bits limited to L2 Stock Token uiMultiplier/oraclePaused advisory. Escrow = standard Bridge. No custom gateway code -> no hunt surface within session scope. Skipped deep dive.

## SUBFROST pass (recon only)
TVL ~$8.4M on Bitcoin L1 (FROST 9-signer p2tr custody); EVM side = $29k frUSD bridge proxy (verified ERC1967). Not EVM-huntable. Skipped.

## ARCUS pass (recon only)
$19.3M in Bridge Vault (Robinhood Chain 4663), off-chain CLOB + permissioned validators, ToB+OZ audited rootchain, escape hatch DA-dependent. No perm-less contract entry found in recon. Skipped pending others.

## Recon wave 3 results
- AFX: HACKED 2026-07-22 $24.15M (validator keys), TVL->0. Dead.
- Surge Credit: custody on BTC L1 MAST vaults; Base side small; unaudited impls but DCN-threshold model; parked.
- PredictStreet: Polymarket fork on ADI (36900); oracle/vault/operator custom; queued #2.
- Syntetika EmberVault (Base): custom unaudited 4626-style vault w/ signed NAV publishes + queues, $11.5M -> NEW PRIMARY.
- NUVA: 2x audited + Immunefi; deprioritized.
