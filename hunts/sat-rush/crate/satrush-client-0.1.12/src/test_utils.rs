//! Mock swap route support for validation environments.
//!
//! Devnet builds of the program (`--features devnet`) hardcode the mock swap
//! aggregator as their `SWAP_PROGRAM` in place of Jupiter. These helpers build
//! the mock's route data and account list, shared by the LiteSVM test-suite and
//! the CLI when cranking devnet rounds. Not for mainnet use.

use crate::builders::{get_associated_token_address, TOKEN_PROGRAM_ID};
use solana_instruction::AccountMeta;
use solana_pubkey::Pubkey;

/// Mock swap aggregator program (must match the program's `declare_id!` and
/// the `devnet` `SWAP_PROGRAM` constant).
pub const MOCK_SWAP_PROGRAM_ID: Pubkey = Pubkey::from_str_const("FwagBBXsQVcn7iAT3bGV4cHBs8oU2wnazL9Ue9BTVRru");

/// Seed for the mock swap program's pool authority PDA.
pub const MOCK_POOL_AUTHORITY_SEED: &[u8] = b"pool";

/// Anchor instruction discriminator for the mock swap program's `mock_swap`.
const MOCK_SWAP_DISCRIMINATOR: [u8; 8] = [132, 118, 185, 134, 25, 56, 106, 10];

/// The mock swap program's pool authority PDA (owner of its liquidity ATAs).
pub fn get_mock_pool_authority() -> Pubkey {
    Pubkey::find_program_address(&[MOCK_POOL_AUTHORITY_SEED], &MOCK_SWAP_PROGRAM_ID).0
}

/// Instruction data for the mock swap program: it moves exactly `amount_in`
/// USD into the pool and pays exactly `amount_out` BTC from it.
pub fn get_mock_swap_data(amount_in: u64, amount_out: u64) -> Vec<u8> {
    let mut swap_data = MOCK_SWAP_DISCRIMINATOR.to_vec();
    swap_data.extend_from_slice(&amount_in.to_le_bytes());
    swap_data.extend_from_slice(&amount_out.to_le_bytes());
    swap_data
}

/// The mock swap program's account list (order matches its `MockSwap` struct)
/// for a USD -> BTC swap out of `source_authority`'s ATAs. `source_authority`
/// is passed as a non-signer at the transaction level (it is a PDA) — the
/// relaying satrush instruction marks it a signer for the CPI and signs via
/// `invoke_signed`.
pub fn get_mock_swap_route_accounts(source_authority: Pubkey, usd_mint: Pubkey, btc_mint: Pubkey) -> Vec<AccountMeta> {
    let pool_authority = get_mock_pool_authority();
    vec![
        AccountMeta::new(get_associated_token_address(&source_authority, &usd_mint), false), // source_ata
        AccountMeta::new_readonly(source_authority, false),                                  // source_authority
        AccountMeta::new(get_associated_token_address(&pool_authority, &usd_mint), false),   // pool_source_ata
        AccountMeta::new(get_associated_token_address(&pool_authority, &btc_mint), false),   // pool_dest_ata
        AccountMeta::new(get_associated_token_address(&source_authority, &btc_mint), false), // dest_ata
        AccountMeta::new_readonly(pool_authority, false),                                    // pool_authority
        AccountMeta::new_readonly(TOKEN_PROGRAM_ID, false),                                  // token_program
    ]
}
