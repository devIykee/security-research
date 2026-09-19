# Line-by-line audit - LayerZero v2 protocol core (receive path)

**Researcher:** deviykee | **Date:** Aug 2026 | **Repo:** LayerZero-Labs/LayerZero-v2 @ main (shallow)
**Method:** full-function reads with attack questions (reentrancy, auth, math edges,
state-machine races), cross-checked against live on-chain behavior probed earlier.

## Files audited (function-complete reads)

| File | Verdict |
|---|---|
| protocol/contracts/EndpointV2.sol | CLEAN |
| protocol/contracts/MessagingChannel.sol | CLEAN |
| protocol/contracts/MessageLibManager.sol | CLEAN |
| messagelib/contracts/uln/uln302/ReceiveUln302.sol | CLEAN |
| messagelib/contracts/uln/ReceiveUlnBase.sol | CLEAN |
| messagelib/contracts/uln/UlnBase.sol | CLEAN |
| messagelib/contracts/uln/uln302/ReceiveUln302View.sol | CLEAN |
| messagelib/contracts/ReceiveLibBaseE2.sol | CLEAN |
| messagelib/contracts/uln/LzExecutor.sol (delivery path) | CLEAN |
| oapp/contracts/oapp/OAppReceiver.sol | CLEAN |
| oapp/contracts/oft/OFTCore.sol | CLEAN |
| oapp/contracts/oft/OFT.sol / OFTAdapter.sol | CLEAN |

## Key invariants verified

1. Payload-hash binding: executor-supplied message bytes must match committed hash;
   cleared before external call (reentrancy-safe). lzReceive re-entry impossible.
2. Verify authority: only configured (or grace-period) receive lib can call verify();
   lib registration/config changes are oapp/delegate-gated.
3. Nonce state machine: gapless lazy cursor; nilify counts as present for the walk
   but unexecutable; burn requires executed-range; skip is oapp-only (+1 exactly).
4. Attestation accounting: per-(headerHash,payloadHash,dvn) records; threshold math
   cannot underflow; empty resolved configs revert at set-time and read-time.
5. OFT supply invariant: OFT burns on src / mints on dst via same SD conversion;
   adapter locks/unlocks 1:1 with documented FoT caveat.
6. peers==0 => OnlyPeer revert at OAppReceiver.lzReceive - confirms killed finding F1.

## Observations (non-security)

- O1: hashLookup entries written by DVNs outside the CURRENT config are never
  reclaimed on commit (bounded storage growth; writers are DVNs only).
- O2: CONFIG_TYPE_ULN=2 on ULN302 libs vs different value in 301-era code; API
  footgun for integrator tooling (our sweeps were unaffected - used getUlnConfig).
- O3: commitAndExecute is all-or-nothing; receiver revert rolls back the commit;
  attestations persist so retries work. Design choice, documented here.

## Excluded from this pass

SendUln302 internals, Worker/Treasury fee math, MessagingComposer, ReadLib1002,
DVN implementations (MultiSig/adapters), precrime stack, non-EVM packages.

## Bottom line

No exploitable vulnerability found in the audited surface. Combined with the config
sweep (hunts/lz-omnichain/findings.md): nothing reportable above Info severity.
