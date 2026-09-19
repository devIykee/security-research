/// Cap on the streak multiplier credited toward the hashrate reward, mirroring
/// the program's `REWARD_MAX_STREAK`. The miner's live streak
/// (`Miner::current_streak_count`) is uncapped; only the multiplier frozen
/// onto a deployment is clamped here.
pub const REWARD_MAX_STREAK: u32 = 100;

/// Streak multiplier a deploy into `next_round_id` would freeze onto its
/// `PublicDeployment`, computed from the miner's live state without
/// submitting a transaction. Mirrors `Miner::record_play` followed by
/// `Miner::get_hashrate_streak_multiplier`; feed the result into
/// [`crate::hashrate_reward`] to preview the points a deploy would earn.
///
/// `current_streak_count` / `last_mined_round_id` are the miner's live fields
/// (`Miner::current_streak_count`, `Miner::last_mined_round_id`); pass `0` for
/// both when the `Miner` account does not exist yet (a miner's first ever
/// play), matching the program's zeroed initial state.
pub fn next_streak_multiplier(current_streak_count: u32, last_mined_round_id: u32, next_round_id: u32) -> u32 {
    let streak = if last_mined_round_id == next_round_id.saturating_sub(1) {
        current_streak_count.saturating_add(1)
    } else {
        1
    };
    streak.min(REWARD_MAX_STREAK)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn first_ever_play_starts_the_streak_at_one() {
        // No prior play: current_streak_count = 0, last_mined_round_id = 0,
        // matching a freshly created `Miner`.
        assert_eq!(next_streak_multiplier(0, 0, 1), 1);
    }

    #[test]
    fn first_play_into_a_later_round_starts_at_one() {
        assert_eq!(next_streak_multiplier(0, 0, 42), 1);
    }

    #[test]
    fn consecutive_rounds_increment_the_streak() {
        assert_eq!(next_streak_multiplier(1, 5, 6), 2);
        assert_eq!(next_streak_multiplier(2, 6, 7), 3);
    }

    #[test]
    fn a_gap_resets_the_streak() {
        // Last play was round 6; skipping round 7 to deploy into round 8.
        assert_eq!(next_streak_multiplier(2, 6, 8), 1);
    }

    #[test]
    fn streak_is_capped_at_reward_max_streak() {
        assert_eq!(next_streak_multiplier(REWARD_MAX_STREAK, 10, 11), REWARD_MAX_STREAK);
        assert_eq!(next_streak_multiplier(REWARD_MAX_STREAK - 1, 10, 11), REWARD_MAX_STREAK);
    }

    #[test]
    fn does_not_overflow_at_u32_max() {
        assert_eq!(next_streak_multiplier(u32::MAX, 10, 11), REWARD_MAX_STREAK);
    }
}
