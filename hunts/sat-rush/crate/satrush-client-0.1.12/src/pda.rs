use super::SATRUSH_ID;
use solana_pubkey::Pubkey;

pub fn get_satrush_config_address() -> (Pubkey, u8) {
    let seeds = &[b"satrush_config".as_ref()];
    Pubkey::find_program_address(seeds, &SATRUSH_ID)
}

/// Anchor's event-CPI authority PDA — the extra signer every `#[event_cpi]`
/// instruction takes alongside the program account.
pub fn get_event_authority_address() -> (Pubkey, u8) {
    let seeds = &[b"__event_authority".as_ref()];
    Pubkey::find_program_address(seeds, &SATRUSH_ID)
}

pub fn get_board_address() -> (Pubkey, u8) {
    let seeds = &[b"board".as_ref()];
    Pubkey::find_program_address(seeds, &SATRUSH_ID)
}

pub fn get_round_address(round_id: u32) -> (Pubkey, u8) {
    let seeds = &[b"round".as_ref(), &round_id.to_le_bytes()];
    Pubkey::find_program_address(seeds, &SATRUSH_ID)
}

pub fn get_public_deployment_address(authority: Pubkey, round_id: u32) -> (Pubkey, u8) {
    let seeds = &[
        b"public_deployment".as_ref(),
        &authority.to_bytes(),
        &round_id.to_le_bytes(),
    ];
    Pubkey::find_program_address(seeds, &SATRUSH_ID)
}

pub fn get_miner_address(authority: Pubkey) -> (Pubkey, u8) {
    let seeds = &[b"miner".as_ref(), &authority.to_bytes()];
    Pubkey::find_program_address(seeds, &SATRUSH_ID)
}

pub fn get_sats_vault_address() -> (Pubkey, u8) {
    let seeds = &[b"sats_vault".as_ref()];
    Pubkey::find_program_address(seeds, &SATRUSH_ID)
}

pub fn get_epoch_vault_address() -> (Pubkey, u8) {
    let seeds = &[b"epoch_vault".as_ref()];
    Pubkey::find_program_address(seeds, &SATRUSH_ID)
}

pub fn get_epoch_vault_iteration_address(iteration_id: u32) -> (Pubkey, u8) {
    let seeds = &[b"epoch_vault_iteration".as_ref(), &iteration_id.to_le_bytes()];
    Pubkey::find_program_address(seeds, &SATRUSH_ID)
}

pub fn get_epoch_vault_entry_address(iteration_id: u32, authority: Pubkey) -> (Pubkey, u8) {
    let seeds = &[
        b"epoch_vault_entry".as_ref(),
        &iteration_id.to_le_bytes(),
        &authority.to_bytes(),
    ];
    Pubkey::find_program_address(seeds, &SATRUSH_ID)
}

pub fn get_epoch_vault_page_address(iteration_id: u32, page_index: u16) -> (Pubkey, u8) {
    let seeds = &[
        b"epoch_vault_page".as_ref(),
        &iteration_id.to_le_bytes(),
        &page_index.to_le_bytes(),
    ];
    Pubkey::find_program_address(seeds, &SATRUSH_ID)
}

pub fn get_one_btc_vault_address() -> (Pubkey, u8) {
    let seeds = &[b"one_btc_vault".as_ref()];
    Pubkey::find_program_address(seeds, &SATRUSH_ID)
}

pub fn get_one_btc_vault_iteration_address(iteration_id: u32) -> (Pubkey, u8) {
    let seeds = &[b"one_btc_vault_iteration".as_ref(), &iteration_id.to_le_bytes()];
    Pubkey::find_program_address(seeds, &SATRUSH_ID)
}

pub fn get_treasury_address() -> (Pubkey, u8) {
    let seeds = &[b"treasury".as_ref()];
    Pubkey::find_program_address(seeds, &SATRUSH_ID)
}

pub fn get_public_automation_address(authority: Pubkey) -> (Pubkey, u8) {
    let seeds = &[b"public_automation".as_ref(), &authority.to_bytes()];
    Pubkey::find_program_address(seeds, &SATRUSH_ID)
}
