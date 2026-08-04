# SLVR - Medium: Lottery claim delegates can redirect proceeds to arbitrary recipients
**Researcher:** deviykee
**Severity:** Medium - Requires a pre-approved malicious or compromised delegate. Not a stranger drain of all users without prior `approveDelegate`. Bound: full claim value (ETH and/or SLVR) for each redirected round.
**Status:** Verified from live verified source on Robinhood Chain, cross-checked against MultiClaim and AutoCommit V1/V2. No mainnet state touched.
**Disclosure:** Private.

## What this means in plain language (read this first)
When you win a lottery round, you can approve a "delegate" so a bot or helper can claim for you (auto-mining, multi-claim helpers).

On SLVR, that approval is stronger than "claim as me." A delegate can choose **where** the ETH and SLVR go. Official helpers (AutoCommit, ClaimLocker, MultiClaim) hardcode safe recipients. If a user is tricked into approving a random wallet, or a bot key is stolen, that party can claim the user's wins **to themselves**.

Your own `SlvrMultiClaim` source documents the same issue: a generic multicall cannot safely be a lottery delegate because `claimAdvanced` lets the caller pick recipients.

This is not "anyone on the internet steals without approval." It is "delegate approval is full custody of claim proceeds unless the delegate is carefully written."

## Affected contracts (Robinhood Chain, chainId 4663)

| Role | Address |
|---|---|
| SlvrGridLottery (live) | 0x284Eb4016305Fa7FbC162Fb68F27227271001c7f |
| Related older lottery | 0xB0Cc994Ce4E8fb106da9Eb36e26fDd8C5f1e0c71 |
| Site | https://slvr.fun |
| X | https://x.com/S_L_V_R_FUN |

Related (safe helpers that hardcode recipients, for contrast):
| Role | Address |
|---|---|
| SlvrMultiClaim | 0x9F34a8561f97E388D4A1589c1D046C61d6915323 |
| AutoCommit V1 | 0x1399115FcF2a9C41e5080547A9214156A4Bf8a45 |
| AutoCommit V2 | 0x314c8D5755468224AC60c36FB5494F0D7D5Abb3B |
| ClaimLocker V2 | 0x83F84C5d431a986a1AB209F902B954b5D3550d8c |

## Summary
`claimAdvanced` authorizes either the user or an approved delegate, then transfers payouts to caller-supplied recipient fields with no force-to-user constraint (except `bypassFee` permanent-lock allowlist for the SLVR recipient).

## Root cause
```solidity
function claimAdvanced(ISlvrGridLottery.ClaimParams memory params) public nonReentrant whenNotPaused {
    if (params.user == address(0)) revert ZeroAddress();
    _validateClaimAuthorization(params.user); // user OR delegates[user][msg.sender]

    if (params.ethOnly) {
        address recipientNativeEth =
            params.recipientNative == address(0) ? params.user : params.recipientNative;
        _claimEthOnly(params.user, params.roundId, recipientNativeEth);
        return;
    }

    address recipientNative =
        params.recipientNative == address(0) ? params.user : params.recipientNative;
    address recipientSlvr =
        params.recipientSlvr == address(0) ? recipientNative : params.recipientSlvr;

    if (params.bypassFee && !authorizedPermanentLockContracts[recipientSlvr]) revert NotAuthorized();

    ClaimResult memory r = _claimCore(params.user, params.roundId, params.bypassFee);
    // transfers go to recipientNative / recipientSlvr (arbitrary if caller is a delegate)
    ...
}

function _validateClaimAuthorization(address user) private view {
    if (msg.sender != user) {
        if (!delegates[user][msg.sender]) revert NotAuthorized();
    }
}
```

`_claimEthOnly` pays `recipientNative` with no equality check against `user`.

Team acknowledgment in `SlvrMultiClaim.sol` (live verified):

```solidity
/// @dev The lottery only exposes single-round claims, and its delegate system is the only way a
///      contract can claim on a user's behalf. A generic executor (e.g. Multicall3) can't be that
///      delegate safely: anyone may call it, and claimAdvanced lets the caller pick recipients, so
///      approving it would let a third party steal the caller's winnings.
///      This contract is safe to approve because `user` and both recipients are hardcoded to
///      msg.sender
```

## Attack
1. Victim Alice wins rounds and has unclaimed payouts.
2. Alice calls `approveDelegate(Mallory)` (phishing, or Mallory is a "helper" bot whose key is later compromised).
3. Mallory calls `claimAdvanced` with `user = Alice`, `recipientNative = Mallory`, `recipientSlvr = Mallory` (or `ethOnly` + `recipientNative = Mallory`).
4. Alice's claim is marked claimed. Funds go to Mallory.

## Impact
Auth: victim-approved delegate | Capital: zero beyond gas | Frequency: every unclaimed win | Victims: users who approved a bad delegate | Magnitude: full claim value (ETH + SLVR for that round)

Official AutoCommit V1/V2 and MultiClaim / ClaimLocker paths hardcode safe recipients when *they* claim. This finding is about the **protocol API surface**, not a proven bug inside those helpers under normal use.

## Related observations (not separate Criticals)
- **AutoCommit V2** (`0x314c8D57…`): ~0.85 ETH in plans. Permissionless keepers can `executeFor` / `claimFor` enabled plans and take a gas-metered fee (live max **0.003 ETH** per call, premium **10%**). By design; bounded; does not steal lottery wins into the keeper wallet beyond the fee.
- **RNG:** live lottery uses `DrandRandomnessProvider` `0x1F3B0992…` with unlock floor + beacon verify. High-level resolve path looks sound; not a formal crypto audit.
- **ve staking** ~33.8 ETH rewards; auth on `distributeRoundRewards` / sweeps looks intentional.
- **LiquidityStaking / Zap:** no free drain found; LP stake active, rewardRate currently 0.

## Proof of concept
Logic-level: any address with `delegates[alice][attacker] == true` can set arbitrary recipients.  
Read-only confirmation of live lottery ABI + MultiClaim comments on-chain.  
Fork PoC outline: set or mock `delegates[user][attacker]`, fund a resolved win for `user`, call `claimAdvanced` with attacker recipients, assert balances.

## Fix
1. Prefer: if `msg.sender != user`, force `recipientNative == user && recipientSlvr == user` unless recipient is on an owner-managed allowlist of contracts (AutoCommit, ClaimLocker, MultiClaim).
2. Or: `approveDelegate(delegate, fixedRecipient)` binding at approval time.
3. UI / docs: treat delegate approval as "this address can take your winnings" unless restricted as above.

## Disclosure & compensation
Good-faith private disclosure. A bounty commensurate with a Medium trust finding is appreciated. I am NOT conditioning the disclosure or fix on payment. Happy to walk through the write-up and review a patch.

deviykee  
http://x.com/deviykee
