//! Environment-free instruction builders.
//!
//! Thin composition helpers over the generated instruction structs: they derive
//! every PDA and associated token account from the program's fixed seeds, so a
//! caller only supplies the signing authority and the mint addresses. Shared by
//! the LiteSVM test-suite and the `satrush-cli` binary.

use crate::instructions::{
    CancelPublicAutomation, ClaimUsd, ClaimUsdInstructionArgs, CloseRound, CreateBoard, CreateEpochVault,
    CreateOneBtcVault, CreatePublicAutomation, CreatePublicAutomationInstructionArgs, CreateSatrushConfig,
    CreateSatrushConfigInstructionArgs, CreateSatsVault, CreateTreasury, DeployPublic, DeployPublicInstructionArgs,
    ExecutePublicAutomation, ExecutePublicAutomationInstructionArgs, RotateRound, SettleDeployPublic, SwapRoundStake,
    SwapRoundStakeInstructionArgs, TopUpPublicAutomation, TopUpPublicAutomationInstructionArgs,
    UpdateBoardRoundDuration, UpdateBoardRoundDurationInstructionArgs, UpdateDeployFees,
    UpdateDeployFeesInstructionArgs, UpdateDeploymentSettleGraceDuration,
    UpdateDeploymentSettleGraceDurationInstructionArgs, UpdateEpochVaultIterationDuration,
    UpdateEpochVaultIterationDurationInstructionArgs, UpdateMinDeployUsdAmount,
    UpdateMinDeployUsdAmountInstructionArgs, UpdateStrikeTriggerModulus, UpdateStrikeTriggerModulusInstructionArgs,
    UpdateUnclaimedHashrateBps, UpdateUnclaimedHashrateBpsInstructionArgs,
};
use crate::types::AutomationStrategy;
use crate::{
    get_board_address, get_epoch_vault_address, get_epoch_vault_iteration_address, get_event_authority_address,
    get_miner_address, get_one_btc_vault_address, get_one_btc_vault_iteration_address, get_public_automation_address,
    get_public_deployment_address, get_round_address, get_satrush_config_address, get_sats_vault_address,
    get_treasury_address,
};
use solana_instruction::{AccountMeta, Instruction};
use solana_pubkey::Pubkey;

/// SPL Token program.
pub const TOKEN_PROGRAM_ID: Pubkey = Pubkey::from_str_const("TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA");
/// SPL Associated Token Account program.
pub const ASSOCIATED_TOKEN_PROGRAM_ID: Pubkey = Pubkey::from_str_const("ATokenGPvbdGVxr1b2hvZbsiqW5xWH25efTNsLJA8knL");
/// System program.
pub const SYSTEM_PROGRAM_ID: Pubkey = Pubkey::from_str_const("11111111111111111111111111111111");
/// SlotHashes sysvar.
pub const SLOT_HASHES_ID: Pubkey = Pubkey::from_str_const("SysvarS1otHashes111111111111111111111111111");

/// Derive the canonical associated token account for `wallet` holding `mint`.
pub fn get_associated_token_address(wallet: &Pubkey, mint: &Pubkey) -> Pubkey {
    Pubkey::find_program_address(
        &[wallet.as_ref(), TOKEN_PROGRAM_ID.as_ref(), mint.as_ref()],
        &ASSOCIATED_TOKEN_PROGRAM_ID,
    )
    .0
}

/// `create_satrush_config`: the config PDA holding authorities, mints and fee
/// parameters. `authority` pays and must equal the program's upgrade authority.
pub fn get_create_satrush_config_instruction(
    authority: Pubkey,
    args: CreateSatrushConfigInstructionArgs,
) -> Instruction {
    CreateSatrushConfig {
        authority,
        satrush_config: get_satrush_config_address().0,
        system_program: SYSTEM_PROGRAM_ID,
    }
    .instruction(args)
}

/// `create_board`: the board singleton, its USD/BTC pools and the initial round
/// (id 1). Signed by the config's admin authority.
pub fn get_create_board_instruction(authority: Pubkey, usd_mint: Pubkey, btc_mint: Pubkey) -> Instruction {
    let board = get_board_address().0;
    CreateBoard {
        authority,
        satrush_config: get_satrush_config_address().0,
        board,
        initial_round: get_round_address(1).0,
        usd_mint,
        btc_mint,
        board_usd_ata: get_associated_token_address(&board, &usd_mint),
        board_btc_ata: get_associated_token_address(&board, &btc_mint),
        token_program: TOKEN_PROGRAM_ID,
        associated_token_program: ASSOCIATED_TOKEN_PROGRAM_ID,
        system_program: SYSTEM_PROGRAM_ID,
    }
    .instruction()
}

/// `update_board_round_duration`: overwrite the board's `round_duration` (slots).
/// Applies to future round activations only; the active round keeps its window.
/// Signed by the config's admin authority.
pub fn get_update_board_round_duration_instruction(authority: Pubkey, new_round_duration: u32) -> Instruction {
    UpdateBoardRoundDuration {
        authority,
        satrush_config: get_satrush_config_address().0,
        board: get_board_address().0,
    }
    .instruction(UpdateBoardRoundDurationInstructionArgs { new_round_duration })
}

/// `update_min_deploy_usd_amount`: overwrite the config's minimum gross deploy
/// size (USD mint base units). Applies to every subsequent manual deploy,
/// automation creation and automation execution. Signed by the config's admin
/// authority.
pub fn get_update_min_deploy_usd_amount_instruction(authority: Pubkey, new_min_deploy_usd_amount: u64) -> Instruction {
    UpdateMinDeployUsdAmount {
        authority,
        satrush_config: get_satrush_config_address().0,
    }
    .instruction(UpdateMinDeployUsdAmountInstructionArgs {
        new_min_deploy_usd_amount,
    })
}

/// `update_unclaimed_hashrate_bps`: overwrite the config's deferred hashrate
/// bonus ratio (bps of each settled play's reward). Signed by the config's
/// admin authority.
pub fn get_update_unclaimed_hashrate_bps_instruction(
    authority: Pubkey,
    new_unclaimed_hashrate_bps: u32,
) -> Instruction {
    UpdateUnclaimedHashrateBps {
        authority,
        satrush_config: get_satrush_config_address().0,
    }
    .instruction(UpdateUnclaimedHashrateBpsInstructionArgs {
        new_unclaimed_hashrate_bps,
    })
}

/// `update_deploy_fees`: atomically overwrite the four deploy-time fee legs.
/// Each leg must be at least 1 bps and the legs must sum to exactly 800 bps
/// (8%); the split may vary but the total never changes. Signed by the
/// config's admin authority.
pub fn get_update_deploy_fees_instruction(
    authority: Pubkey,
    new_strike_fee_bps: u32,
    new_epoch_fee_bps: u32,
    new_one_btc_fee_bps: u32,
    new_protocol_fee_bps: u32,
) -> Instruction {
    UpdateDeployFees {
        authority,
        satrush_config: get_satrush_config_address().0,
    }
    .instruction(UpdateDeployFeesInstructionArgs {
        new_strike_fee_bps,
        new_epoch_fee_bps,
        new_one_btc_fee_bps,
        new_protocol_fee_bps,
    })
}

/// `update_epoch_vault_iteration_duration`: overwrite the config's epoch vault
/// iteration length (slots). Applies to the currently accumulating iteration
/// immediately. Signed by the config's admin authority.
pub fn get_update_epoch_vault_iteration_duration_instruction(
    authority: Pubkey,
    new_iteration_duration: u64,
) -> Instruction {
    UpdateEpochVaultIterationDuration {
        authority,
        satrush_config: get_satrush_config_address().0,
    }
    .instruction(UpdateEpochVaultIterationDurationInstructionArgs { new_iteration_duration })
}

/// `update_strike_trigger_modulus`: admin retunes the Sat Strike odds (the
/// jackpot fires when `rng % modulus == 0`). Signed by the config's admin
/// authority.
pub fn get_update_strike_trigger_modulus_instruction(authority: Pubkey, new_modulus: u16) -> Instruction {
    UpdateStrikeTriggerModulus {
        authority,
        satrush_config: get_satrush_config_address().0,
    }
    .instruction(UpdateStrikeTriggerModulusInstructionArgs { new_modulus })
}

/// `update_deployment_settle_grace_duration`: admin retunes the settle grace
/// window (slots after a round settles before stale deployments may be
/// force-cleaned; 0 disables cleanup).
pub fn get_update_deployment_settle_grace_duration_instruction(
    authority: Pubkey,
    new_grace_duration: u64,
) -> Instruction {
    UpdateDeploymentSettleGraceDuration {
        authority,
        satrush_config: get_satrush_config_address().0,
    }
    .instruction(UpdateDeploymentSettleGraceDurationInstructionArgs { new_grace_duration })
}

/// `create_epoch_vault`: the epoch vault singleton, its USD/BTC pools and the
/// first iteration (id 1).
pub fn get_create_epoch_vault_instruction(authority: Pubkey, usd_mint: Pubkey, btc_mint: Pubkey) -> Instruction {
    let epoch_vault = get_epoch_vault_address().0;
    CreateEpochVault {
        authority,
        satrush_config: get_satrush_config_address().0,
        epoch_vault,
        epoch_vault_iteration: get_epoch_vault_iteration_address(1).0,
        usd_mint,
        btc_mint,
        epoch_vault_usd_ata: get_associated_token_address(&epoch_vault, &usd_mint),
        epoch_vault_btc_ata: get_associated_token_address(&epoch_vault, &btc_mint),
        token_program: TOKEN_PROGRAM_ID,
        associated_token_program: ASSOCIATED_TOKEN_PROGRAM_ID,
        system_program: SYSTEM_PROGRAM_ID,
    }
    .instruction()
}

/// `create_one_btc_vault`: the 1 BTC vault singleton, its USD/BTC pools and the
/// first iteration (id 1).
pub fn get_create_one_btc_vault_instruction(authority: Pubkey, usd_mint: Pubkey, btc_mint: Pubkey) -> Instruction {
    let one_btc_vault = get_one_btc_vault_address().0;
    CreateOneBtcVault {
        authority,
        satrush_config: get_satrush_config_address().0,
        one_btc_vault,
        one_btc_vault_iteration: get_one_btc_vault_iteration_address(1).0,
        usd_mint,
        btc_mint,
        one_btc_vault_usd_ata: get_associated_token_address(&one_btc_vault, &usd_mint),
        one_btc_vault_btc_ata: get_associated_token_address(&one_btc_vault, &btc_mint),
        token_program: TOKEN_PROGRAM_ID,
        associated_token_program: ASSOCIATED_TOKEN_PROGRAM_ID,
        system_program: SYSTEM_PROGRAM_ID,
    }
    .instruction()
}

/// `create_treasury`: the treasury singleton and its USD fee pool.
pub fn get_create_treasury_instruction(authority: Pubkey, usd_mint: Pubkey) -> Instruction {
    let treasury = get_treasury_address().0;
    CreateTreasury {
        authority,
        satrush_config: get_satrush_config_address().0,
        treasury,
        usd_mint,
        treasury_usd_ata: get_associated_token_address(&treasury, &usd_mint),
        token_program: TOKEN_PROGRAM_ID,
        associated_token_program: ASSOCIATED_TOKEN_PROGRAM_ID,
        system_program: SYSTEM_PROGRAM_ID,
    }
    .instruction()
}

/// `deploy_public`: stake `amount` USD (base units; all fees are deducted from
/// it, so the miner parts with exactly `amount`) on the tiles
/// in `selection_mask` for round `round_id`, as the miner `authority`. The round
/// must be the board's current one and open for deploys; the miner profile and
/// deployment record PDAs are created by the instruction.
pub fn get_deploy_public_instruction(
    authority: Pubkey,
    usd_mint: Pubkey,
    round_id: u32,
    selection_mask: u32,
    amount: u64,
) -> Instruction {
    let board = get_board_address().0;

    DeployPublic {
        authority,
        satrush_config: get_satrush_config_address().0,
        board,
        usd_mint,
        board_usd_ata: get_associated_token_address(&board, &usd_mint),
        authority_usd_ata: get_associated_token_address(&authority, &usd_mint),
        round: get_round_address(round_id).0,
        public_deployment: get_public_deployment_address(authority, round_id).0,
        miner: get_miner_address(authority).0,
        token_program: TOKEN_PROGRAM_ID,
        system_program: SYSTEM_PROGRAM_ID,
        event_authority: get_event_authority_address().0,
        program: crate::SATRUSH_ID,
    }
    .instruction(DeployPublicInstructionArgs { selection_mask, amount })
}

/// `rotate_round`: reveal `current_round_id`'s winning tile, sweep the round's
/// accumulated fee legs from the board pool to the epoch/1 BTC/treasury pools
/// (plus, on a strike trigger, the strike skim's USD and BTC legs to the epoch
/// vault), and deploy round `current_round_id + 1` as the board's new active
/// round. Signed by the config's round authority; valid once the round's
/// window elapsed.
pub fn get_rotate_round_instruction(
    authority: Pubkey,
    usd_mint: Pubkey,
    btc_mint: Pubkey,
    current_round_id: u32,
) -> Instruction {
    let board = get_board_address().0;
    let epoch_vault = get_epoch_vault_address().0;
    let one_btc_vault = get_one_btc_vault_address().0;
    let treasury = get_treasury_address().0;

    RotateRound {
        authority,
        satrush_config: get_satrush_config_address().0,
        board,
        current_round: get_round_address(current_round_id).0,
        next_round: get_round_address(current_round_id + 1).0,
        usd_mint,
        btc_mint,
        board_usd_ata: get_associated_token_address(&board, &usd_mint),
        board_btc_ata: get_associated_token_address(&board, &btc_mint),
        epoch_vault,
        epoch_vault_usd_ata: get_associated_token_address(&epoch_vault, &usd_mint),
        epoch_vault_btc_ata: get_associated_token_address(&epoch_vault, &btc_mint),
        one_btc_vault,
        one_btc_vault_usd_ata: get_associated_token_address(&one_btc_vault, &usd_mint),
        treasury,
        treasury_usd_ata: get_associated_token_address(&treasury, &usd_mint),
        slot_hashes: SLOT_HASHES_ID,
        token_program: TOKEN_PROGRAM_ID,
        system_program: SYSTEM_PROGRAM_ID,
        event_authority: get_event_authority_address().0,
        program: crate::SATRUSH_ID,
    }
    .instruction()
}

/// `swap_round_stake`: relay a pre-built aggregator route that converts part of
/// the revealed round's USD into BTC. `swap_data` and `route_accounts` are the
/// route's opaque instruction data and account list; the on-chain handler
/// enforces the economics against observed balance deltas. Signed by the
/// config's round authority.
#[allow(clippy::too_many_arguments)]
pub fn get_swap_round_stake_instruction(
    authority: Pubkey,
    usd_mint: Pubkey,
    btc_mint: Pubkey,
    round_id: u32,
    min_btc_out: u64,
    swap_program: Pubkey,
    swap_data: Vec<u8>,
    route_accounts: &[AccountMeta],
) -> Instruction {
    let board = get_board_address().0;
    SwapRoundStake {
        authority,
        satrush_config: get_satrush_config_address().0,
        board,
        round: get_round_address(round_id).0,
        usd_mint,
        btc_mint,
        board_usd_ata: get_associated_token_address(&board, &usd_mint),
        board_btc_ata: get_associated_token_address(&board, &btc_mint),
        swap_program,
        token_program: TOKEN_PROGRAM_ID,
        event_authority: get_event_authority_address().0,
        program: crate::SATRUSH_ID,
    }
    .instruction_with_remaining_accounts(SwapRoundStakeInstructionArgs { min_btc_out, swap_data }, route_accounts)
}

/// `settle_deploy_public`: settle `deployment_authority`'s deployment in a
/// Settled round. `authority` signs (the owner, or the round authority for
/// automated deployments); `rent_recipient` must be the round authority for
/// automated deployments and the owner for manual ones.
pub fn get_settle_deploy_public_instruction(
    authority: Pubkey,
    deployment_authority: Pubkey,
    rent_recipient: Pubkey,
    usd_mint: Pubkey,
    btc_mint: Pubkey,
    round_id: u32,
) -> Instruction {
    let board = get_board_address().0;
    let sats_vault = get_sats_vault_address().0;
    let public_automation = get_public_automation_address(deployment_authority).0;
    SettleDeployPublic {
        authority,
        rent_recipient,
        satrush_config: get_satrush_config_address().0,
        round: get_round_address(round_id).0,
        board,
        public_deployment: get_public_deployment_address(deployment_authority, round_id).0,
        miner: get_miner_address(deployment_authority).0,
        public_automation,
        automation_usd_ata: get_associated_token_address(&public_automation, &usd_mint),
        board_usd_ata: get_associated_token_address(&board, &usd_mint),
        sats_vault,
        btc_mint,
        usd_mint,
        board_btc_ata: get_associated_token_address(&board, &btc_mint),
        sats_vault_btc_ata: get_associated_token_address(&sats_vault, &btc_mint),
        token_program: TOKEN_PROGRAM_ID,
        associated_token_program: ASSOCIATED_TOKEN_PROGRAM_ID,
        system_program: SYSTEM_PROGRAM_ID,
        event_authority: get_event_authority_address().0,
        program: crate::SATRUSH_ID,
    }
    .instruction()
}

/// `create_public_automation`: escrow `deposit_usd_amount` and configure the
/// crank to deploy `per_round_usd_amount` per round with the given strategy.
/// One automation per authority.
#[allow(clippy::too_many_arguments)]
pub fn get_create_public_automation_instruction(
    authority: Pubkey,
    usd_mint: Pubkey,
    strategy: AutomationStrategy,
    selection_mask: u32,
    per_round_usd_amount: u64,
    reload: bool,
    deposit_usd_amount: u64,
) -> Instruction {
    let public_automation = get_public_automation_address(authority).0;
    CreatePublicAutomation {
        authority,
        satrush_config: get_satrush_config_address().0,
        public_automation,
        usd_mint,
        authority_usd_ata: get_associated_token_address(&authority, &usd_mint),
        automation_usd_ata: get_associated_token_address(&public_automation, &usd_mint),
        miner: get_miner_address(authority).0,
        token_program: TOKEN_PROGRAM_ID,
        associated_token_program: ASSOCIATED_TOKEN_PROGRAM_ID,
        system_program: SYSTEM_PROGRAM_ID,
    }
    .instruction(CreatePublicAutomationInstructionArgs {
        strategy,
        selection_mask,
        per_round_usd_amount,
        reload,
        deposit_usd_amount,
    })
}

/// `top_up_public_automation`: move `amount` USD from the authority's account
/// into the automation's escrow.
pub fn get_top_up_public_automation_instruction(authority: Pubkey, usd_mint: Pubkey, amount: u64) -> Instruction {
    let public_automation = get_public_automation_address(authority).0;
    TopUpPublicAutomation {
        authority,
        satrush_config: get_satrush_config_address().0,
        public_automation,
        usd_mint,
        authority_usd_ata: get_associated_token_address(&authority, &usd_mint),
        automation_usd_ata: get_associated_token_address(&public_automation, &usd_mint),
        token_program: TOKEN_PROGRAM_ID,
    }
    .instruction(TopUpPublicAutomationInstructionArgs { amount })
}

/// `cancel_public_automation`: refund the full escrow balance and close the
/// automation and its token account. Unconditional; in-flight deployments
/// settle to the miner profile later.
pub fn get_cancel_public_automation_instruction(authority: Pubkey, usd_mint: Pubkey) -> Instruction {
    let public_automation = get_public_automation_address(authority).0;
    CancelPublicAutomation {
        authority,
        satrush_config: get_satrush_config_address().0,
        public_automation,
        usd_mint,
        automation_usd_ata: get_associated_token_address(&public_automation, &usd_mint),
        authority_usd_ata: get_associated_token_address(&authority, &usd_mint),
        token_program: TOKEN_PROGRAM_ID,
        associated_token_program: ASSOCIATED_TOKEN_PROGRAM_ID,
        system_program: SYSTEM_PROGRAM_ID,
    }
    .instruction()
}

/// `execute_public_automation`: crank-signed per-round deploy funded from
/// `automation_authority`'s escrow. `selection_mask` must be `Some` for
/// Discretionary automations and `None` otherwise.
pub fn get_execute_public_automation_instruction(
    crank_authority: Pubkey,
    automation_authority: Pubkey,
    usd_mint: Pubkey,
    round_id: u32,
    selection_mask: Option<u32>,
) -> Instruction {
    let board = get_board_address().0;
    let public_automation = get_public_automation_address(automation_authority).0;

    ExecutePublicAutomation {
        authority: crank_authority,
        satrush_config: get_satrush_config_address().0,
        board,
        round: get_round_address(round_id).0,
        public_automation,
        usd_mint,
        automation_usd_ata: get_associated_token_address(&public_automation, &usd_mint),
        board_usd_ata: get_associated_token_address(&board, &usd_mint),
        public_deployment: get_public_deployment_address(automation_authority, round_id).0,
        miner: get_miner_address(automation_authority).0,
        slot_hashes: SLOT_HASHES_ID,
        token_program: TOKEN_PROGRAM_ID,
        system_program: SYSTEM_PROGRAM_ID,
        event_authority: get_event_authority_address().0,
        program: crate::SATRUSH_ID,
    }
    .instruction(ExecutePublicAutomationInstructionArgs { selection_mask })
}

/// `claim_usd`: withdraw `amount` of the miner `authority`'s unclaimed USD
/// winnings from the board's USD pool to the authority's USD account. No exit
/// fee — the full amount transfers.
pub fn get_claim_usd_instruction(authority: Pubkey, usd_mint: Pubkey, amount: u64) -> Instruction {
    let board = get_board_address().0;
    ClaimUsd {
        authority,
        satrush_config: get_satrush_config_address().0,
        board,
        miner: get_miner_address(authority).0,
        usd_mint,
        board_usd_ata: get_associated_token_address(&board, &usd_mint),
        authority_usd_ata: get_associated_token_address(&authority, &usd_mint),
        token_program: TOKEN_PROGRAM_ID,
        associated_token_program: ASSOCIATED_TOKEN_PROGRAM_ID,
        system_program: SYSTEM_PROGRAM_ID,
    }
    .instruction(ClaimUsdInstructionArgs { amount })
}

/// `create_sats_vault`: the sats vault singleton and its BTC reserve pool.
pub fn get_create_sats_vault_instruction(authority: Pubkey, btc_mint: Pubkey) -> Instruction {
    let sats_vault = get_sats_vault_address().0;
    CreateSatsVault {
        authority,
        satrush_config: get_satrush_config_address().0,
        sats_vault,
        btc_mint,
        sats_vault_btc_ata: get_associated_token_address(&sats_vault, &btc_mint),
        token_program: TOKEN_PROGRAM_ID,
        associated_token_program: ASSOCIATED_TOKEN_PROGRAM_ID,
        system_program: SYSTEM_PROGRAM_ID,
    }
    .instruction()
}

/// `close_round`: tear down a Finished round, sweeping a no-winner round's
/// orphaned pot (USD and BTC) into the treasury. Signed by the config's admin
/// authority, which receives the round account's rent.
pub fn get_close_round_instruction(
    authority: Pubkey,
    usd_mint: Pubkey,
    btc_mint: Pubkey,
    round_id: u32,
) -> Instruction {
    let board = get_board_address().0;
    let treasury = get_treasury_address().0;
    CloseRound {
        authority,
        satrush_config: get_satrush_config_address().0,
        board,
        round: get_round_address(round_id).0,
        treasury,
        usd_mint,
        btc_mint,
        board_usd_ata: get_associated_token_address(&board, &usd_mint),
        board_btc_ata: get_associated_token_address(&board, &btc_mint),
        treasury_usd_ata: get_associated_token_address(&treasury, &usd_mint),
        treasury_btc_ata: get_associated_token_address(&treasury, &btc_mint),
        token_program: TOKEN_PROGRAM_ID,
        associated_token_program: ASSOCIATED_TOKEN_PROGRAM_ID,
        system_program: SYSTEM_PROGRAM_ID,
        event_authority: get_event_authority_address().0,
        program: crate::SATRUSH_ID,
    }
    .instruction()
}
