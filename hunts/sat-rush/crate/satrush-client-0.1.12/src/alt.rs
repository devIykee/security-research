//! Address Lookup Table helpers for the rotate crank.
//!
//! `rotate_round` + `swap_round_stake` are sent together in one transaction;
//! in a legacy message the protocol's fixed accounts alone consume most of the
//! 1232-byte budget, leaving no room for a realistic aggregator route. Storing
//! those fixed accounts in a protocol-owned lookup table shrinks each to a
//! 1-byte index in a v0 message. Route accounts stay raw in the message.

use solana_pubkey::Pubkey;

use crate::{
    get_associated_token_address, get_board_address, get_epoch_vault_address, get_event_authority_address,
    get_one_btc_vault_address, get_satrush_config_address, get_treasury_address, SLOT_HASHES_ID, SYSTEM_PROGRAM_ID,
    TOKEN_PROGRAM_ID,
};

/// The fixed accounts referenced by `rotate_round` + `swap_round_stake` that
/// belong in the protocol's lookup table.
///
/// Excluded on purpose:
/// - the round authority — signers must stay in a v0 message's static keys;
/// - the satrush program id — a top-level program id cannot be loaded from a
///   lookup table;
/// - the round PDAs — they change every round, so they stay raw in the message.
pub fn get_lookup_table_entries(usd_mint: Pubkey, btc_mint: Pubkey, swap_program: Pubkey) -> Vec<Pubkey> {
    let board = get_board_address().0;
    let epoch_vault = get_epoch_vault_address().0;
    let one_btc_vault = get_one_btc_vault_address().0;
    let treasury = get_treasury_address().0;
    vec![
        get_satrush_config_address().0,
        board,
        get_associated_token_address(&board, &usd_mint),
        get_associated_token_address(&board, &btc_mint),
        epoch_vault,
        get_associated_token_address(&epoch_vault, &usd_mint),
        get_associated_token_address(&epoch_vault, &btc_mint),
        one_btc_vault,
        get_associated_token_address(&one_btc_vault, &usd_mint),
        treasury,
        get_associated_token_address(&treasury, &usd_mint),
        usd_mint,
        btc_mint,
        SLOT_HASHES_ID,
        TOKEN_PROGRAM_ID,
        SYSTEM_PROGRAM_ID,
        get_event_authority_address().0,
        swap_program,
    ]
}

/// Decode a raw lookup-table account into the form `MessageV0::try_compile`
/// consumes.
pub fn decode_address_lookup_table(
    address: Pubkey,
    data: &[u8],
) -> Result<solana_message::AddressLookupTableAccount, std::io::Error> {
    let table = solana_address_lookup_table_interface::state::AddressLookupTable::deserialize(data)
        .map_err(|e| std::io::Error::other(format!("account {address} is not an address lookup table: {e:?}")))?;
    Ok(solana_message::AddressLookupTableAccount {
        key: address,
        addresses: table.addresses.to_vec(),
    })
}

/// Fetch and decode the lookup table at `address`.
#[cfg(feature = "fetch")]
pub fn fetch_address_lookup_table(
    rpc: &solana_rpc_client::rpc_client::RpcClient,
    address: &Pubkey,
) -> Result<solana_message::AddressLookupTableAccount, std::io::Error> {
    let account = rpc
        .get_account(address)
        .map_err(|e| std::io::Error::other(format!("lookup table {address} not found: {e}")))?;
    decode_address_lookup_table(*address, &account.data)
}

#[cfg(test)]
mod tests {
    use super::*;
    use solana_address_lookup_table_interface::state::{AddressLookupTable, LookupTableMeta};
    use std::borrow::Cow;
    use std::collections::HashSet;

    #[test]
    fn entries_are_unique_and_keep_signers_and_program_ids_static() {
        let btc_mint = Pubkey::new_unique();
        let entries = get_lookup_table_entries(Pubkey::new_unique(), btc_mint, Pubkey::new_unique());
        let unique: HashSet<_> = entries.iter().collect();
        assert_eq!(unique.len(), entries.len(), "duplicate entries waste table slots");
        assert_eq!(entries.len(), 18);
        // rotate_round's strike skim writes the epoch vault's BTC ATA — a fixed
        // address that belongs in the table.
        assert!(entries.contains(&get_associated_token_address(&get_epoch_vault_address().0, &btc_mint)));
        // A v0 message cannot load a top-level program id from a lookup table,
        // and the round PDAs change every round — none of them belong here.
        assert!(!entries.contains(&crate::SATRUSH_ID));
        assert!(!entries.contains(&crate::get_round_address(0).0));
    }

    #[test]
    fn decodes_a_serialized_lookup_table() {
        let address = Pubkey::new_unique();
        let stored = vec![Pubkey::new_unique(), Pubkey::new_unique()];
        let data = AddressLookupTable {
            meta: LookupTableMeta::default(),
            addresses: Cow::Owned(stored.clone()),
        }
        .serialize_for_tests()
        .unwrap();

        let decoded = decode_address_lookup_table(address, &data).unwrap();
        assert_eq!(decoded.key, address);
        assert_eq!(decoded.addresses, stored);
    }

    #[test]
    fn rejects_non_lookup_table_data() {
        assert!(decode_address_lookup_table(Pubkey::new_unique(), &[0u8; 8]).is_err());
    }
}
