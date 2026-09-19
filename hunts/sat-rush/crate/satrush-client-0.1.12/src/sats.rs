/// Virtual share base used by the on-chain vault math (decimal offset of 3):
/// conversions behave as if `SHARE_OFFSET` extra shares and 1 extra satoshi
/// always exist, so an empty vault mints 1_000 shares per satoshi.
pub const SHARE_OFFSET: u64 = 1_000;

/// BTC value of a sats-vault share amount, as computed by [`sats_to_btc`].
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct BtcSharesValue {
    /// Value at the current exchange rate, before the claim fee.
    pub gross: u64,
    /// Fee withheld on claim; the payout is `gross - fee`.
    pub fee: u64,
}

#[derive(Debug, thiserror::Error)]
pub enum BtcSharesValueError {
    #[error("shares exceed the vault's issued shares")]
    InsufficientShares,
    #[error("claim fee bps exceed the 10000 denominator")]
    InvalidClaimFeeBps,
}

/// BTC value of `shares` against a vault holding `vault_amount` BTC with
/// `vault_shares` shares issued (`SatsVault::btc_amount` /
/// `SatsVault::btc_shares`). `claim_fee_bps` is
/// `SatrushConfig::sats_vault_claim_fee_bps`; pass `0` when only the gross
/// value matters. Zero `shares` value to zero without error; `shares`
/// exceeding `vault_shares` is rejected.
pub fn sats_to_btc(
    shares: u64,
    vault_amount: u64,
    vault_shares: u64,
    claim_fee_bps: u32,
) -> Result<BtcSharesValue, BtcSharesValueError> {
    const BPS_DENOMINATOR: u128 = 10_000;

    if claim_fee_bps as u128 > BPS_DENOMINATOR {
        return Err(BtcSharesValueError::InvalidClaimFeeBps);
    }
    if shares == 0 {
        return Ok(BtcSharesValue { gross: 0, fee: 0 });
    }
    if shares > vault_shares {
        return Err(BtcSharesValueError::InsufficientShares);
    }

    // shares <= vault_shares bounds gross strictly below vault_amount + 1, and
    // claim_fee_bps <= BPS_DENOMINATOR bounds fee <= gross: both narrowing
    // conversions are lossless.
    let gross = (shares as u128 * (vault_amount as u128 + 1) / (vault_shares as u128 + SHARE_OFFSET as u128)) as u64;
    let fee = (gross as u128 * claim_fee_bps as u128 / BPS_DENOMINATOR) as u64;
    Ok(BtcSharesValue { gross, fee })
}

#[derive(Debug, thiserror::Error)]
pub enum BtcToSatsError {
    #[error("share amount is not computable for the vault state")]
    MathOverflow,
}

/// Shares minted for depositing `btc_amount` BTC into a vault holding
/// `vault_amount` BTC with `vault_shares` shares issued
/// (`SatsVault::btc_amount` / `SatsVault::btc_shares`): scaled by the vault's
/// virtual `(shares + SHARE_OFFSET) / (assets + 1)` ratio and floored, so an
/// empty vault mints [`SHARE_OFFSET`] shares per satoshi. Errors when the
/// result exceeds `u64::MAX`.
pub fn btc_to_sats(btc_amount: u64, vault_amount: u64, vault_shares: u64) -> Result<u64, BtcToSatsError> {
    u64::try_from(btc_amount as u128 * (vault_shares as u128 + SHARE_OFFSET as u128) / (vault_amount as u128 + 1))
        .map_err(|_| BtcToSatsError::MathOverflow)
}

#[cfg(test)]
mod tests {
    use super::*;

    /// 10% claim fee, matching the program's default
    /// `SatrushConfig::sats_vault_claim_fee_bps`.
    const CLAIM_FEE_BPS: u32 = 1_000;

    #[test]
    fn values_shares_at_the_current_exchange_rate() {
        // 100 BTC / 100k shares (offset parity): 50k shares -> gross 50, fee 5 (10%).
        assert_eq!(sats_to_btc(50_000, 100, 100_000, CLAIM_FEE_BPS).unwrap(), BtcSharesValue { gross: 50, fee: 5 });
    }

    #[test]
    fn full_drain_of_appreciated_vault_matches_on_chain_payout() {
        // 55 BTC / 50k shares (appreciated): all shares -> gross 54, fee 5,
        // matching the on-chain redeem payout of 49 (the vault keeps the
        // remaining 6 as `leftovers`).
        assert_eq!(sats_to_btc(50_000, 55, 50_000, CLAIM_FEE_BPS).unwrap(), BtcSharesValue { gross: 54, fee: 5 });
    }

    #[test]
    fn floors_gross_and_fee() {
        // 1k shares of 10 BTC / 3k shares: gross floor(1000*11/4000) = 2,
        // fee floor(200/10000) = 0.
        assert_eq!(sats_to_btc(1_000, 10, 3_000, CLAIM_FEE_BPS).unwrap(), BtcSharesValue { gross: 2, fee: 0 });
    }

    #[test]
    fn zero_fee_bps_yields_gross_only() {
        assert_eq!(sats_to_btc(50_000, 100, 100_000, 0).unwrap(), BtcSharesValue { gross: 50, fee: 0 });
    }

    #[test]
    fn zero_shares_are_worth_zero() {
        assert_eq!(sats_to_btc(0, 100, 100_000, CLAIM_FEE_BPS).unwrap(), BtcSharesValue { gross: 0, fee: 0 });
        // Even against an empty vault.
        assert_eq!(sats_to_btc(0, 0, 0, CLAIM_FEE_BPS).unwrap(), BtcSharesValue { gross: 0, fee: 0 });
    }

    #[test]
    fn rejects_claim_fee_above_the_bps_denominator() {
        assert!(matches!(sats_to_btc(50_000, 100, 100_000, 10_001), Err(BtcSharesValueError::InvalidClaimFeeBps)));
    }

    #[test]
    fn full_fee_withholds_the_entire_gross() {
        assert_eq!(sats_to_btc(50_000, 100, 100_000, 10_000).unwrap(), BtcSharesValue { gross: 50, fee: 50 });
    }

    #[test]
    fn rejects_overdraw() {
        assert!(matches!(
            sats_to_btc(100_001, 100, 100_000, CLAIM_FEE_BPS),
            Err(BtcSharesValueError::InsufficientShares)
        ));
        // Any nonzero claim against an empty vault is an overdraw.
        assert!(matches!(sats_to_btc(1, 5, 0, CLAIM_FEE_BPS), Err(BtcSharesValueError::InsufficientShares)));
    }

    #[test]
    fn handles_max_values_without_overflow() {
        // shares == vault_shares at u64::MAX: gross is the whole vault minus
        // the sliver absorbed by the virtual base.
        let max = u64::MAX;
        let value = sats_to_btc(max, max, max, CLAIM_FEE_BPS).unwrap();
        assert!(value.gross <= max && value.gross > max - SHARE_OFFSET);
    }

    #[test]
    fn first_deposit_mints_at_the_offset_rate() {
        assert_eq!(btc_to_sats(100, 0, 0).unwrap(), 100 * SHARE_OFFSET);
    }

    #[test]
    fn later_deposit_mints_at_exchange_rate_and_floors() {
        // 55 BTC / 50k shares: 11 BTC -> floor(11 * 51_000 / 56) = 10_017
        // shares, matching the on-chain deposit.
        assert_eq!(btc_to_sats(11, 55, 50_000).unwrap(), 10_017);
        // 10 BTC -> floor(10 * 51_000 / 56) = 9_107 shares.
        assert_eq!(btc_to_sats(10, 55, 50_000).unwrap(), 9_107);
    }

    #[test]
    fn small_deposit_into_appreciated_vault_mints_shares() {
        // 2x appreciated: 1 satoshi mints ~SHARE_OFFSET/2 shares instead of
        // flooring to zero like the pre-offset math did.
        assert_eq!(btc_to_sats(1, 2_000, 1_000_000).unwrap(), 500);
    }

    #[test]
    fn zero_deposit_mints_zero_shares() {
        assert_eq!(btc_to_sats(0, 100, 100_000).unwrap(), 0);
        assert_eq!(btc_to_sats(0, 0, 0).unwrap(), 0);
    }

    #[test]
    fn shares_without_btc_no_longer_error() {
        // The virtual satoshi keeps the on-chain denominator nonzero, so this
        // (unreachable post-reset) state values deposits instead of erroring.
        assert_eq!(btc_to_sats(1, 0, 100).unwrap(), 1_100);
    }

    #[test]
    fn errors_where_on_chain_math_fails() {
        // Result exceeds u64: MAX BTC against a nearly-empty vault.
        assert!(matches!(btc_to_sats(u64::MAX, 1, 2), Err(BtcToSatsError::MathOverflow)));
    }

    #[test]
    fn round_trips_with_sats_to_btc_at_zero_fee() {
        // Deposit at offset parity, then value the minted shares against the
        // post-deposit vault state: exact round trip.
        let (deposit, vault_amount, vault_shares) = (11, 100, 100_000);
        let shares = btc_to_sats(deposit, vault_amount, vault_shares).unwrap();
        assert_eq!(shares, 11_000);
        let value = sats_to_btc(shares, vault_amount + deposit, vault_shares + shares, 0).unwrap();
        assert_eq!(value.gross, deposit);
    }
}
