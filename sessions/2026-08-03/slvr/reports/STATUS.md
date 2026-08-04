# SLVR (slvr.fun) — Hunt Status
**Researcher:** deviykee  
**Date:** 2026-08-03  
**Chain:** Robinhood Chain (4663)  
**Site:** https://slvr.fun/  
**X:** https://x.com/S_L_V_R_FUN  
**Mode:** fork / eth_call only. Nothing touched on mainnet.

## INTAKE
```
PROJECT_NAME   : SLVR
X_HANDLE       : @S_L_V_R_FUN
WEBSITE        : https://slvr.fun
CHAIN          : Robinhood Chain
RPC            : https://rpc.mainnet.chain.robinhood.com
CHAIN_ID       : 4663
EXPLORER       : https://robinhoodchain.blockscout.com
PRODUCT_TYPE   : gamified mining / grid lottery + ve-staking
BOUNTY/CONTEST : none / discretionary
RESEARCHER     : deviykee
```

## Architecture (verified)

| Role | Address | Notes |
|------|---------|-------|
| SlvrToken (SLVR) | `0x791229E3EbD6CFdC3D8157f48722684173C29aD9` | Taxed ERC20, mint role, swapback |
| SlvrVoteEscrow | `0xd9b8FBD61033145c5496132153CE675756313B71` | veNFT locks |
| SlvrVoteEscrowStaking | `0xaF68598eBd245DC3cB92FF16E9Ba1814DD137200` | **~33.8 ETH** staker rewards |
| SlvrAutoCommit | `0x1399115FcF2a9C41e5080547A9214156A4Bf8a45` | Auto-bet keeper |
| **SlvrGridLottery (live)** | `0x284Eb4016305Fa7FbC162Fb68F27227271001c7f` | **~1.59 ETH**, round ~23702 |
| SlvrGridLottery (older) | `0xB0Cc994Ce4E8fb106da9Eb36e26fDd8C5f1e0c71` | ~0.47 ETH residual |
| SlvrHub | `0x55FC0daaB486E46fBF1d60787420c0311d9Dd57f` | Emission / staker feed; staking.LOTTERY points here |
| SlvrJackpot | `0x24B723e2Da172961F60Cd6a4699654c89D4aC6cd` | ~0.27 ETH |
| SlvrClaimLockerV2 | `0x83F84C5d431a986a1AB209F902B954b5D3550d8c` | Permanent lock claims |
| Deployer / owner | `0x11111972FE1b7e52D36609bCaF8702c65b025B46` | Single EOA owner across stack |

Not SLVR: HoodCash MiningPool `0xf275020a…` (different deployer).

## Auth triage (attacker = 0x…dEaD)

| Call | Result |
|------|--------|
| Token mint / initialMint | guarded (AccessControl / Ownable) |
| VE setAuthorizedContract | Ownable |
| Staking distributeRoundRewards | `unauthorized` (not Hub) |
| Staking sweepExcess wrong sig | reverts |
| AutoCommit executeFor (no plan) | `disabled` |

No free open admin.

## Findings

### S1 — claimAdvanced: approved delegates can redirect claim proceeds to any address
**Severity:** Medium (trust / privilege) — requires victim already approved a malicious or compromised delegate. Not permissionless against all users.
**Status:** Code-confirmed on live `SlvrGridLottery`.

**Root cause:** `_validateClaimAuthorization` only checks `msg.sender == user || delegates[user][msg.sender]`. After that, `claimAdvanced` / `_claimEthOnly` honor **caller-chosen** `recipientNative` / `recipientSlvr` with **no** force-to-user constraint.

```solidity
// claimAdvanced
_validateClaimAuthorization(params.user);
address recipientNative = params.recipientNative == address(0) ? params.user : params.recipientNative;
address recipientSlvr = params.recipientSlvr == address(0) ? recipientNative : params.recipientSlvr;
// transfers go to recipients — arbitrary if caller is a delegate
```

**Impact:** If Alice `approveDelegate(Bob)`, Bob can claim Alice’s wins to Bob’s wallet (ETH + SLVR).  
AutoCommit path hardcodes safe recipients when *it* claims (good). ClaimLocker requires `msg.sender == user` (good). Risk is any other delegate (phishing, compromised bot key, buggy third-party).

**Fix options:**
1. For delegates: force `recipientNative == user && recipientSlvr == user` unless recipient is in an allowlist (AutoCommit, ClaimLocker).
2. Or: `approveDelegate(delegate, allowedRecipient)` binding.
3. Document strongly: delegate approval is full claim custody.

### S2 — Centralization / owner surface (trust, not Critical)
Single EOA owns token, lottery, hub, staking, jackpot controls: pause, setJackpot, setConfig fees, Hub `rescue`, staking `sweepUnallocated`, mint roles via lottery hub.

### S3 — Tax swapback `swapbackMinOut() == 0` (Low)
Live read: automatic swapback can be sandwiched; value leak to MEV, not full drain of jackpot accounting.

### S4 — No permissionless Critical found this pass
- Staking reward accounting tracks `totalRewardsOwed` vs force-feed (conscious anti-sweep bugfix).
- `claimOnBurn` only VE; stake/unstake ownership checks solid.
- `bypassFee` gated by `authorizedPermanentLockContracts`.
- `executeForInternalWrapper` self-only.
- Randomness: external provider (not fully audited this pass).

## Live pot snapshot
| Contract | ETH |
|----------|-----|
| VoteEscrowStaking | ~33.83 (≈ totalRewardsOwed) |
| GridLottery live | ~1.59 |
| Jackpot | ~0.27 |
| Older lottery | ~0.47 |

## Pass 2 — AutoCommitV2 / LP staking / MultiClaim / RNG (2026-08-03 cont.)

### Additional cores

| Contract | Address | ETH | Verdict |
|----------|---------|-----|---------|
| SlvrAutoCommitV2 | `0x314c8D57…bb3B` | **~0.85** | Hardcoded claim recipients (safe). Keeper fee model: maxFee **0.003 ETH**, premium **10%**. Auth `setFeeParams` owner-only. |
| Lib lottery | `0x284Eb…` | | **RNG:** `DrandRandomnessProvider` `0x1F3B0992…` (verifyBeacon, unlock floor). `requestResolve` / `resolveRound` permissionless; settle gated by provider. Looks sound at high level. |
| SlvrLiquidityStaking | `0x7D888f4C…DfeA` | 0 | LP staked ~6.94e18; **rewardRate=0**. depositFor whitelist OK. claimRewardsTo only for self. emergencyRescue Ownable. |
| SlvrLiquidityZap | `0x85b10820…b9F0` | 0 | Zap-in then depositFor; careful WETH/sync comments. No free drain path found. |
| SlvrMultiClaim | `0x9F34a856…5323` | 0 | **Documents S1 explicitly** in source: generic multicall unsafe because claimAdvanced lets caller pick recipients; MultiClaim hardcodes msg.sender. |

### Pass 2 findings

### S5 — AutoCommitV2: permissionless keepers can force-execute plans and charge fees (by design / Low)
Anyone may call `executeFor` / `claimFor` on an **enabled** plan with `autoClaim` and take up to `maxFeePerExecution` (live **0.003 ETH**) + premium from the user’s plan balance when something actually executes.  
Not theft of lottery wins (claims go into the user’s plan). Can still **drain plan balance over time** via repeated legitimate keeper runs or grief force-bets.  
**Label:** product/keeper economics, not Critical. Bound: fee caps + need claimable rounds or open bets.

### S6 — MultiClaim is the team’s own mitigation note for S1
`SlvrMultiClaim.sol` comments state that Multicall3 cannot safely be a lottery delegate because `claimAdvanced` allows arbitrary recipients. Confirms S1 is intentional API risk, not a misread.

### Still no permissionless Critical
- Hub `mintReward` / `rescue` guarded  
- LP staking reward stream + empty-pool fold carefully written  
- Lottery randomness: external provider with time unlock; not fully formal-verified this pass  

## Next (optional pass 3)
1. Jackpot bribe math + `continueDistributeBribes`  
2. Permanent lock convert / stake checkpoint races under weight changes  
3. Tax token swapback sandwich magnitude with live volume  

## Files
Sources: `slvr-hunt/src/`, `slvr-hunt/src2/`  
Reports: `slvr-hunt/reports/`  
Dated copy: `2026-08-03/slvr/`
