# Coverage - Sat Rush

Coverage: 12/41 instruction surfaces mapped via generated client (29%). Program source NOT available (unverified bytecode only). All analysis from client SDK types + on-chain state + tx logs.

Last updated: 2026-08-23 (Step 3-4)

| File / Module | Read? | Paths traced | Notes |
|------|-------|--------------|-------|
| satrush-client/pda.rs | yes | All 15 PDA seed derivations | Full PDA map |
| satrush-client/sats.rs | yes | btc_to_sats, sats_to_btc formulas | Full read incl tests |
| generated/accounts/sats_vault.rs | yes | All fields | Layout confirmed on-chain |
| generated/accounts/board.rs | yes | All fields | Decoded live state |
| generated/accounts/round.rs | yes | All fields + RoundState + TileStake | Decoded round 26870 |
| generated/accounts/miner.rs | yes | All fields | Layout documented |
| generated/accounts/satrush_config.rs | yes | All fields | Decoded live config |
| generated/accounts/public_deployment.rs | yes | All fields | Layout documented |
| generated/instructions/claim_sats.rs | yes | Accounts + args (shares: u64) | Full interface |
| generated/instructions/deploy_public.rs | yes | Accounts + args (selection_mask, amount) | Full interface |
| generated/instructions/settle_deploy_public.rs | yes | 20 accounts, no args | Full interface |
| generated/instructions/mod.rs | yes | 41 instruction names | Full inventory |

## Not examined (no source)

| Path / area | Reason |
|-------------|--------|
| On-chain program logic (satRushGBRY2vgapeTAkoxz26vL2cYqyPi6CnBj7Tco) | Unverified bytecode; no Sourcify/Anchor IDL publish |
| Worker program (WKhLkiPw8dSMoV1n81Mxyo61Eu3rH9CKtQTnLjGv4BS) | Separate program, no source |
| satrush-client: hashrate.rs, streak.rs, selection.rs, builders.rs | Not yet fetched |
| Epoch vault / 1BTC vault instructions | Not yet examined |

## Key limitation

Without verified program source, all findings are based on interface inference (account types, SDK math, on-chain state, tx logs). Root-cause cannot be quoted from code. PoC must rely on instruction-level testing against the live program.