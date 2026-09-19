# Sat Rush - Hunt Findings

**Researcher:** deviykee
**Date:** 2026-08-23
**Status:** Path-scoped review, NOT a full audit. Program source unavailable (unverified bytecode).
**Coverage:** See `coverage.md` - 12/41 instruction surfaces mapped (29%) via generated client SDK.

## Verdict

No permissionless critical or high found on examined paths. The vault share math is
correct, the swap path is authority-gated, and the PDA seed design prevents cross-user
griefing on the paths traced. What remains is centralization risk plus three unconfirmed
questions that need program source to close.

## Confirmed On-Chain State (2026-08-23)

| Item | Value |
|------|-------|
| Program | `satRushGBRY2vgapeTAkoxz26vL2cYqyPi6CnBj7Tco` |
| Deployed | 2026-08-13 04:04 UTC (slot 438945746) |
| Upgrade authority | `AEeAcZseSP7kqVkpX3Ut1tDh3nhZkoTbf5sGzfmytgZz` |
| Worker program | `WKhLkiPw8dSMoV1n81Mxyo61Eu3rH9CKtQTnLjGv4BS` (slot 440431827) |
| Worker upgrade authority | `3B8wpWfD1T9oAhyDrAWEQU3Zxpog3nmrShr2XoEVXUML` (different key) |
| SatsVault btc_amount | 542,744,612 sats (5.427 BTC) |
| SatsVault btc_shares | 309,132,629,548 |
| SatsVault leftovers | 0 |
| Vault ATA actual | 543,522,908 sats (+778,296 unbooked) |
| Claim fee | 1000 bps (10%) |
| Round fee to vault | 1200 bps (12%) |
| settle_grace_duration | 0 slots |
| Round duration | 150 slots (~60s) |
| Strike odds | 1-in-1097 |

## Killed Leads

| # | Hypothesis | Why killed |
|---|-----------|-----------|
| 1 | Share math rounding / free mint | `SHARE_OFFSET = 1000` virtual offset. `btc_to_sats` and `sats_to_btc` are exact inverses under floor division. Verified against live state: full drain leaves 1 sat + fee as leftovers, invariant `ATA == btc_amount + leftovers` holds. |
| 2 | First-depositor share inflation | Virtual offset makes an empty vault mint 1000 shares/sat. No divide-by-zero, no rounds-to-zero for the second depositor. |
| 3 | Donation attack on share price | `sats_to_btc` reads `SatsVault.btc_amount` (struct field), not the ATA token balance. Sending cbBTC directly to `2zpcctvd7sCdtWe4bAYcNmfVFzaiFVtH81tfMAWCtMh9` inflates the ATA but not the price. Confirmed live: ATA already holds 778,296 sats above booked amount with no price effect. |
| 4 | Third-party cancel of automation | `public_automation` PDA seeds are `["public_automation", authority]`. Owner key is in the seeds, so a stranger cannot address someone else account. |
| 5 | Hashrate inflation | Hashrate accrues only through `SettleDeployPublic`, which requires a real USDC stake (min 1 USDC) paying a 12% round fee. Farming costs money. |
| 6 | Swap sandwich (permissionless) | All four `swap_*_stake` instructions observed on-chain are signed by `game_authority` = `CDRqHM8PkALZ5jRhQ1ikjzegr4LuuWuunxuoWeKNuokK`. `min_btc_out` slippage arg exists. Not a stranger path. |

## Trust / Centralization (disclose, not a permissionless exploit)

1. **Single key holds owner + admin + upgrade authority.** `AEeAcZseSP7kqVkpX3Ut1tDh3nhZkoTbf5sGzfmytgZz` is simultaneously config `owner_authority`, `admin_authority`, and the program upgrade authority. Compromise of this one key allows arbitrary logic replacement and full vault drain. No timelock or multisig observed.

2. **game_authority can set `min_btc_out = 0` on swaps.** `swap_round_stake`, `swap_epoch_stake`, `swap_one_btc_stake`, `swap_strike_stake` each take a keeper-supplied `min_btc_out` plus an opaque `swap_data` Jupiter route blob, with the `board` PDA signing the CPI. A malicious keeper can route through an adversarial pool and extract the round USD. Bound per round is small (~$25 observed) but recurs every 60 seconds.

3. **Split upgrade authority across programs.** The Worker program upgrade authority differs from the main program, and the Worker handles user USDC mid-batch during `WkDeployBatch`. Two separate keys, two separate attack surfaces.

## Informational

1. **SDK CPI builder flag transposition.** In `satrush-client` 0.1.12, `ClaimSatsCpiBuilder::add_remaining_account(account, is_writable, is_signer)` stores `(account, is_writable, is_signer)` but `invoke_signed_with_remaining_accounts` reads `.1` as `is_signer` and `.2` as `is_writable`. Client-side only; the program validates accounts independently.

2. **`anchor-idl-build` discriminators are all zeros.** Every generated account type exposes a `Discriminator` impl with `&[0; 8]`, not matching the real discriminator constant. Anchor consumers relying on it would mismatch accounts.

3. **SlotHashes as lottery entropy.** `trigger_epoch_draw` passes SlotHashes raw (parsed manually, "because the sysvar is too large to deserialize"). A block producer knows this value. Exploitability depends on the iteration state machine, not visible in the client.

## Open Questions (need program source to close)

| # | Question | Why it matters |
|---|----------|---------------|
| A | Is trigger_epoch_draw authority checked against game_authority? Can buy_epoch_tickets + trigger_epoch_draw land in one transaction? | If permissionless and atomically composable, a caller could simulate locally, buy only winning tickets, then trigger. Would be a High bounded by the epoch prize pool. |
| B | With settle_grace_duration = 0, can a stranger call SettleDeployPublic on another user deployment immediately? | public_deployment closes to rent_recipient, documented as independent of the signer. A stranger taking the rent is a small value leak plus a forced-settlement grief. |
| C | On claim_sats, is btc_amount decremented by gross (with leftovers += fee) or by gross - fee? | Decrementing by gross - fee while the fee stays in the ATA breaks the invariant ATA == btc_amount + leftovers and silently strands the fee. Live state (leftovers == 0) is consistent with either, since no full drain has occurred. |

## Next Steps

Closing A, B, and C requires program source or a decompiled BPF dump. In order of cost:

1. Ask the team for source or an Anchor IDL publish. They already ship a codama client, so an IDL exists internally.
2. Build a LiteSVM harness that clones the live program binary and probes the three questions with a non-authority signer. No mainnet state touched.
3. Dump and decompile the BPF ELF for the three specific handlers.

Payout ceiling is a 5.4 BTC vault with no bounty program and no published security contact
found. Recommend closing A and B via LiteSVM before investing further, since those are the
only two paths that could reach High.
