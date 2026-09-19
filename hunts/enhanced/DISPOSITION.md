# Enhanced — hunt disposition: DROPPED (audited, weak edge)

**Date:** 2026-08-23
**Researcher:** deviykee
**Decision:** stand down. Not worth further hours vs Tier 1/2 alternatives.

## Why dropped

1. **Recently and thoroughly audited.** Sherlock collaborative audit, 26 May - 17 Jun
   2026, three lead experts (1337web3, PeterSR, vinica_boy). 1 High, 7 Medium,
   26 Low/Info. Zero issues left unfixed *and* unacknowledged. Audit report:
   `audit-report.txt` (exported from the team's Google Doc).
2. **Deployed bytecode matches the post-audit repo exactly.** Extracted the verified
   on-chain sources for the live vault implementation and diffed against
   `Enhanced-Finance/contracts` HEAD (`5448732`):
   - `src/periphery/vault/EnhancedVault.sol` — IDENTICAL
   - `src/periphery/vault/libs/EnhancedVaultRecordsLib.sol` — IDENTICAL
   - `src/periphery/vault/libs/EnhancedVaultCycleLib.sol` — IDENTICAL
   - `src/core/libs/Parser.sol` — IDENTICAL
   So there is no "deployed drift from audited code" edge, which is usually the
   best angle on a freshly audited protocol.
3. **Low TVL.** ~$173k. Even a genuine High caps the realistic discretionary
   payout well below the effort.
4. **No published bounty program.** Not on Immunefi. Payment would be entirely
   discretionary after the fact.

## What was actually examined (small, honest scope)

| File | Read | Traced |
|---|---|---|
| `src/core/libs/EnhancedOptionsTimelockLib.sol` | full | schedule/execute/cancel + revoke paths for all 4 config types |
| `src/core/libs/Parser.sol` | full | `parseQuoteAndConfirmation` (377-byte assembly layout), `parseTransfer` (130/150), all 3 EIP-712 struct hashes |
| `src/core/EnhancedOptions.sol` | partial | state layout, error set, `_doTransferAsset` / `_doDepositTransferAsset` / composite deposit-and-open |
| Everything else in `src/` | no | — |

Coverage: roughly 3/22 production files, one of them partial. **Nowhere near an
audit.** No finding was confirmed and none was even brought to PoC stage.

## Leads left on the table (for anyone who revisits)

These are *unverified starting points*, not findings.

- **`EnhancedOptionsTimelockLib.sol` and `IEnhancedOptionsTimelock.sol` are
  post-audit additions** — neither appears in the audit's scope file list. They
  were added in response to L-3 / L-6 / L-11 (unbounded, retroactive owner
  params). 392 lines of unreviewed access-control code is the single best angle
  left. Note the asymmetry the library deliberately builds in: revoking a trusted
  role and zeroing a custody limit are instant, granting is timelocked 48h. Worth
  checking whether `scheduleConfigUpdate` / `executeConfigUpdate` silently no-op
  on an unrecognized `configType` (the if/else chain has no final `else revert`),
  and whether the caller in `EnhancedOptions.sol` gates them on owner.
- **M-4 is acknowledged, not fixed.** `fee` is read from raw payload offset 361
  and is absent from both EIP-712 type strings, so a maker's signature never
  commits to it; the operator can set `fee` to the maker's whole MMarket balance
  and route it to `feeRecipient`. The team's position: operator is trusted, and
  `feeRecipient` needs the separate owner role to change. That reasoning holds,
  so this is a **trust/centralization disclosure at best, not a permissionless
  exploit** — it affects institutional makers, not vault depositors. Not worth
  a report on its own.
- **`parseTransfer` payer variant.** `_doDepositTransferAsset` checks the
  signature against `effectivePayer`, but `transferStructHash` does **not**
  include `payer` in its type string (`"Transfer(address user,address asset,
  uint256 chainId,uint256 amount,bool isDeposit,uint64 nonce)"`). A signature a
  user produced for a self-paid deposit is therefore digest-identical to one
  where they are named as someone else's payer. This looked like the most
  promising real lead: it is the same class of omitted-field bug as M-4 but on a
  field that selects **whose tokens move**. **Not investigated further** — would
  need `MMarket.operate` Deposit semantics traced to see whether `user2` as payer
  actually pulls from the payer's own balance or from an allowance, plus the
  digest-replay guard (`_consumeDigest`) checked. Anyone reopening Enhanced
  should start exactly here.

## Reusable artifacts

- `audit-report.txt` — full Sherlock report text (117 KB), useful as a reference
  for how this team's reviewers reason and what they accept as "acknowledged".
- `repo/` — cloned `Enhanced-Finance/contracts`.
- `onchain/src/**` — verified deployed sources for diffing.
- `INTAKE.md`, `coverage.md`.

No disclosure sent. Nothing was contacted. No mainnet state touched.
