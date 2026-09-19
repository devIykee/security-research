/// Display decimals of hashrate points, mirroring the program's
/// `HASHRATE_DECIMALS`: 1 raw unit = 0.01 point.
pub const HASHRATE_DECIMALS: u8 = 2;

/// Raw hashrate units per vault ticket, mirroring the program's
/// `HASHRATE_PER_TICKET` (10^HASHRATE_DECIMALS): one ticket costs 1.00 point.
pub const HASHRATE_PER_TICKET: u64 = 100;

/// Loyalty channel weight (α) in the hashrate reward formula, mirroring the
/// program's `LOYALTY_WEIGHT`.
pub const LOYALTY_WEIGHT: u64 = 1;

/// Skill channel weight (β) in the hashrate reward formula, mirroring the
/// program's `SKILL_WEIGHT`.
pub const SKILL_WEIGHT: u64 = 1;

/// Rounds after a Sat Strike during which settled plays earn boosted hashrate,
/// mirroring the program's `STRIKE_BOOST_ROUNDS`.
pub const STRIKE_BOOST_ROUNDS: u32 = 240;

/// Hashrate multiplier during the post-strike boost window, mirroring the
/// program's `STRIKE_BOOST_HASHRATE_MULTIPLIER`. Pass it as
/// [`hashrate_reward`]'s `hashrate_multiplier` when
/// `Round::is_hashrate_boosted` is set; pass 1 otherwise.
pub const STRIKE_BOOST_HASHRATE_MULTIPLIER: u64 = 2;

/// Format raw hashrate units as the UI points amount with 2 decimals
/// ([`HASHRATE_DECIMALS`]): raw 101 → `"1.01"`. Lossless for the full u64
/// range, unlike an f64 conversion.
pub fn get_hashrate_ui_amount(hashrate: u64) -> String {
    format!("{}.{:02}", hashrate / HASHRATE_PER_TICKET, hashrate % HASHRATE_PER_TICKET)
}

/// Whole vault tickets purchasable with `hashrate` raw units, flooring at
/// [`HASHRATE_PER_TICKET`] raw units (1.00 point) per ticket.
pub fn get_hashrate_tickets_count(hashrate: u64) -> u64 {
    hashrate / HASHRATE_PER_TICKET
}

/// The reward one settled play would credit, split into its channels for the
/// emitted event, as computed by [`hashrate_reward`]. `loyalty_points +
/// skill_points == total` by construction.
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq)]
pub struct HashrateReward {
    /// α·m channel contribution (absorbs the rounding remainder).
    pub loyalty_points: u64,
    /// β·N/n channel contribution.
    pub skill_points: u64,
    /// Total points that would be added to `Miner::hashrate_amount`.
    pub total: u64,
}

#[derive(Debug, thiserror::Error)]
pub enum HashrateRewardError {
    #[error("hashrate reward overflows u64")]
    MathOverflow,
}

/// Hashrate points a play would credit, mirroring the program's
/// `hashrate_reward` so a caller can preview them before deploying or
/// settling.
///
/// - `stake` — net USD stake in the mint's native units
///   (`PublicDeployment::deployed_usd_amount` for an existing deployment).
/// - `streak` — the streak multiplier `m`, already capped
///   (`PublicDeployment::streak_multiplier` for an existing deployment, or
///   [`crate::next_streak_multiplier`] to preview an upcoming one).
/// - `covered` / `total_tiles` — tiles selected (`n`) out of the board
///   (`N`, [`crate::TILE_COUNT`]); `covered` is in `1..=total_tiles`.
/// - `usd_unit` — `10^decimals` of the USD mint.
/// - `hashrate_multiplier` — scales the floored base total, mirroring the
///   program's post-strike boost (1 = no boost;
///   [`STRIKE_BOOST_HASHRATE_MULTIPLIER`] while `Round::is_hashrate_boosted`).
///
/// The returned points are raw units with 2 display decimals
/// ([`HASHRATE_DECIMALS`]): raw 101 = 1.01 points.
///
/// Returns an all-zero reward when `stake == 0` or `covered == 0`.
pub fn hashrate_reward(
    stake: u64,
    streak: u32,
    covered: u32,
    total_tiles: u32,
    usd_unit: u64,
    hashrate_multiplier: u64,
) -> Result<HashrateReward, HashrateRewardError> {
    // No stake or no coverage → no points (also guards the `covered` divisor).
    if stake == 0 || covered == 0 {
        return Ok(HashrateReward::default());
    }

    let covered = covered as u128;
    let denom = covered * usd_unit as u128;
    let base = stake as u128;

    // Channel numerators share `base`; clearing the `N/n` division in the
    // single final divide keeps rounding to one floor.
    let skill_num = base * (SKILL_WEIGHT as u128 * total_tiles as u128);
    let loyalty_num = base * (LOYALTY_WEIGHT as u128 * streak as u128 * covered);

    let total: u64 = ((loyalty_num + skill_num) / denom)
        .try_into()
        .map_err(|_| HashrateRewardError::MathOverflow)?;
    // The boost scales the floored base total (mirroring the program), and
    // both channels with it so they keep summing to `total`.
    let total = total
        .checked_mul(hashrate_multiplier)
        .ok_or(HashrateRewardError::MathOverflow)?;
    // `total >= skill` since `loyalty_num >= 0`, so `loyalty` never underflows.
    // Loyalty absorbs the rounding remainder so the channels sum to `total`.
    let skill_points: u64 = (skill_num / denom) as u64 * hashrate_multiplier;
    let loyalty_points = total - skill_points;

    Ok(HashrateReward {
        loyalty_points,
        skill_points,
        total,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    const USD_UNIT: u64 = 1_000_000; // 6-decimal USDC
    const N: u32 = 21;

    /// Boost inactive: the identity multiplier used by every pre-existing test.
    const NO_BOOST: u64 = 1;

    #[test]
    fn boost_doubles_total_and_channels_still_sum() {
        // Base (44-point worked example) doubled: total 88.
        let r = hashrate_reward(2_000_000, 15, 3, N, USD_UNIT, STRIKE_BOOST_HASHRATE_MULTIPLIER).unwrap();
        assert_eq!(r.total, 88);
        assert_eq!(r.loyalty_points + r.skill_points, r.total);
    }

    #[test]
    fn boost_matches_program_boosted_settle() {
        // Mirrors the LiteSVM boosted settle: $1, m = 2, full coverage -> base 3,
        // boosted total 6.
        let r = hashrate_reward(1_000_000, 2, N, N, USD_UNIT, STRIKE_BOOST_HASHRATE_MULTIPLIER).unwrap();
        assert_eq!(r.total, 6);
    }

    #[test]
    fn worked_example_two_dollars_streak_15_three_tiles() {
        // s = $2, m = 15, n = 3, N = 21 → 44 points.
        let r = hashrate_reward(2_000_000, 15, 3, N, USD_UNIT, NO_BOOST).unwrap();
        assert_eq!(r.total, 44);
    }

    #[test]
    fn channels_sum_to_total() {
        let r = hashrate_reward(2_000_000, 15, 3, N, USD_UNIT, NO_BOOST).unwrap();
        assert_eq!(r.loyalty_points + r.skill_points, r.total);
    }

    #[test]
    fn full_coverage_has_no_skill_bonus_beyond_floor() {
        // n = N → N/n = 1. Multiplier = α·m + β·1. With m = 1: 1 + 1 = 2.
        // $1 stake → 2 points; skill channel contributes β·1 = 1.
        let r = hashrate_reward(1_000_000, 1, N, N, USD_UNIT, NO_BOOST).unwrap();
        assert_eq!(r.total, 2);
        assert_eq!(r.skill_points, 1);
        assert_eq!(r.loyalty_points, 1);
    }

    #[test]
    fn single_tile_is_max_conviction() {
        // n = 1 → N/n = N = 21. m = 1, $1 stake.
        // Multiplier = α·1 + β·21 = 22 → 22 points.
        let r = hashrate_reward(1_000_000, 1, 1, N, USD_UNIT, NO_BOOST).unwrap();
        assert_eq!(r.total, 22);
    }

    #[test]
    fn ceiling_multiplier_per_dollar() {
        // A high streak, n = 1 → α·30 + β·21 = 51. $1 stake → 51 points.
        let r = hashrate_reward(1_000_000, 30, 1, N, USD_UNIT, NO_BOOST).unwrap();
        assert_eq!(r.total, 51);
    }

    #[test]
    fn one_dollar_at_max_streak_earns_1_01_points() {
        // m = 100, full coverage → 101 raw units = 1.01 points under the
        // 2-decimal convention (HASHRATE_DECIMALS).
        let r = hashrate_reward(1_000_000, 100, N, N, USD_UNIT, NO_BOOST).unwrap();
        assert_eq!(r.total, 101);
        assert_eq!(HASHRATE_PER_TICKET, 10u64.pow(HASHRATE_DECIMALS as u32));
    }

    #[test]
    fn zero_stake_earns_nothing() {
        let r = hashrate_reward(0, 30, 1, N, USD_UNIT, NO_BOOST).unwrap();
        assert_eq!(r, HashrateReward::default());
    }

    #[test]
    fn zero_coverage_earns_nothing_without_dividing_by_zero() {
        let r = hashrate_reward(1_000_000, 5, 0, N, USD_UNIT, NO_BOOST).unwrap();
        assert_eq!(r, HashrateReward::default());
    }

    #[test]
    fn sub_unit_stake_floors_to_zero() {
        // $0.01 stake at base multiplier floors to 0 points.
        let r = hashrate_reward(10_000, 1, N, N, USD_UNIT, NO_BOOST).unwrap();
        assert_eq!(r.total, 0);
    }

    #[test]
    fn ui_amount_formats_raw_units_with_two_decimals() {
        assert_eq!(get_hashrate_ui_amount(101), "1.01");
        assert_eq!(get_hashrate_ui_amount(0), "0.00");
        assert_eq!(get_hashrate_ui_amount(5), "0.05");
        assert_eq!(get_hashrate_ui_amount(230), "2.30");
        assert_eq!(get_hashrate_ui_amount(u64::MAX), "184467440737095516.15");
    }

    #[test]
    fn tickets_count_floors_raw_units_to_whole_tickets() {
        assert_eq!(get_hashrate_tickets_count(0), 0);
        assert_eq!(get_hashrate_tickets_count(99), 0);
        assert_eq!(get_hashrate_tickets_count(100), 1);
        assert_eq!(get_hashrate_tickets_count(6_550), 65);
        assert_eq!(get_hashrate_tickets_count(u64::MAX), u64::MAX / 100);
    }

    #[test]
    fn matches_next_streak_multiplier_for_an_upcoming_deploy() {
        // Preview an upcoming deploy: miner played round 5 last, streak 4;
        // deploying into round 6 (consecutive) with full coverage.
        let streak = crate::next_streak_multiplier(4, 5, 6);
        assert_eq!(streak, 5);
        let r = hashrate_reward(1_000_000, streak, N, N, USD_UNIT, NO_BOOST).unwrap();
        assert_eq!(r.total, 6);
    }
}
