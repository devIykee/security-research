//! `getProgramAccounts` queries: scan the program's accounts by discriminator
//! (account type) plus field filters, returning decoded accounts.

use crate::accounts::{
    OneBtcVaultEntry, PublicDeployment, ONE_BTC_VAULT_ENTRY_DISCRIMINATOR, PUBLIC_DEPLOYMENT_DISCRIMINATOR,
};
use crate::shared::DecodedAccount;
use crate::SATRUSH_ID;
use solana_account_decoder::UiAccountEncoding;
use solana_pubkey::Pubkey;
use solana_rpc_client::rpc_client::RpcClient;
use solana_rpc_client_api::config::{RpcAccountInfoConfig, RpcProgramAccountsConfig};
use solana_rpc_client_api::filter::{Memcmp, RpcFilterType};

/// Byte offset of `PublicDeployment.authority`: the 8-byte discriminator,
/// `version: u16` and `bump: u8` precede it.
const PUBLIC_DEPLOYMENT_AUTHORITY_OFFSET: usize = 8 + 2 + 1;

/// Fetch every open `PublicDeployment` owned by `authority` (claiming closes a
/// deployment, so what remains is exactly the open set).
pub fn fetch_public_deployments_by_authority(
    rpc: &RpcClient,
    authority: &Pubkey,
) -> Result<Vec<DecodedAccount<PublicDeployment>>, std::io::Error> {
    let config = RpcProgramAccountsConfig {
        filters: Some(vec![
            RpcFilterType::Memcmp(Memcmp::new_base58_encoded(0, &PUBLIC_DEPLOYMENT_DISCRIMINATOR)),
            RpcFilterType::Memcmp(Memcmp::new_base58_encoded(PUBLIC_DEPLOYMENT_AUTHORITY_OFFSET, authority.as_ref())),
        ]),
        account_config: RpcAccountInfoConfig {
            encoding: Some(UiAccountEncoding::Base64),
            ..Default::default()
        },
        ..Default::default()
    };

    let accounts = rpc
        .get_program_ui_accounts_with_config(&SATRUSH_ID, config)
        .map_err(|e| std::io::Error::other(e.to_string()))?;

    accounts
        .into_iter()
        .map(|(address, ui_account)| {
            let account: solana_account::Account = ui_account
                .decode()
                .ok_or_else(|| std::io::Error::other(format!("failed to decode account {address}")))?;
            let data = PublicDeployment::from_bytes(&account.data)?;
            Ok(DecodedAccount { address, account, data })
        })
        .collect()
}

/// Byte offset of `OneBtcVaultEntry.iteration_id`: the 8-byte discriminator
/// and `version: u16` precede it.
const ONE_BTC_ENTRY_ITERATION_OFFSET: usize = 8 + 2;
/// Byte offset of `OneBtcVaultEntry.authority`: `iteration_id: u32` follows
/// the iteration offset.
const ONE_BTC_ENTRY_AUTHORITY_OFFSET: usize = ONE_BTC_ENTRY_ITERATION_OFFSET + 4;

/// Fetch every 1 BTC ticket receipt `authority` bought in `iteration_id`.
/// Receipts are non-PDA accounts created per purchase, so a scan is the only
/// way to enumerate them.
pub fn fetch_one_btc_vault_entries_by_authority(
    rpc: &RpcClient,
    authority: &Pubkey,
    iteration_id: u32,
) -> Result<Vec<DecodedAccount<OneBtcVaultEntry>>, std::io::Error> {
    let config = RpcProgramAccountsConfig {
        filters: Some(vec![
            RpcFilterType::Memcmp(Memcmp::new_base58_encoded(0, &ONE_BTC_VAULT_ENTRY_DISCRIMINATOR)),
            RpcFilterType::Memcmp(Memcmp::new_base58_encoded(
                ONE_BTC_ENTRY_ITERATION_OFFSET,
                &iteration_id.to_le_bytes(),
            )),
            RpcFilterType::Memcmp(Memcmp::new_base58_encoded(ONE_BTC_ENTRY_AUTHORITY_OFFSET, authority.as_ref())),
        ]),
        account_config: RpcAccountInfoConfig {
            encoding: Some(UiAccountEncoding::Base64),
            ..Default::default()
        },
        ..Default::default()
    };

    let accounts = rpc
        .get_program_ui_accounts_with_config(&SATRUSH_ID, config)
        .map_err(|e| std::io::Error::other(e.to_string()))?;

    accounts
        .into_iter()
        .map(|(address, ui_account)| {
            let account: solana_account::Account = ui_account
                .decode()
                .ok_or_else(|| std::io::Error::other(format!("failed to decode account {address}")))?;
            let data = OneBtcVaultEntry::from_bytes(&account.data)?;
            Ok(DecodedAccount { address, account, data })
        })
        .collect()
}
