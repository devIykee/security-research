/// Number of selectable tiles on the board.
pub const TILE_COUNT: usize = 21;

/// Convert a fixed-size array of tile selections into the packed `u32` selection
/// mask expected by `deploy_public`: bit `i` is set when `tiles[i]` is `true`.
///
/// Because the array is exactly [`TILE_COUNT`] long, the result always fits in the
/// low `TILE_COUNT` bits. Note the program still rejects an all-`false` selection
/// (mask `0`), so callers should pick at least one tile.
pub fn selection_mask_from_tiles(tiles: [bool; TILE_COUNT]) -> u32 {
    let mut mask = 0u32;
    for (i, &selected) in tiles.iter().enumerate() {
        if selected {
            mask |= 1u32 << i;
        }
    }
    mask
}

/// Inverse of [`selection_mask_from_tiles`]: unpack a `u32` selection mask into a
/// per-tile boolean array. Bits above [`TILE_COUNT`] are ignored.
pub fn tiles_from_selection_mask(mask: u32) -> [bool; TILE_COUNT] {
    let mut tiles = [false; TILE_COUNT];
    for (i, tile) in tiles.iter_mut().enumerate() {
        *tile = mask & (1u32 << i) != 0;
    }
    tiles
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn builds_mask_from_tiles() {
        let mut tiles = [false; TILE_COUNT];
        tiles[0] = true;
        tiles[3] = true;
        tiles[20] = true;
        // bits 0, 3, 20 set
        assert_eq!(selection_mask_from_tiles(tiles), (1 << 0) | (1 << 3) | (1 << 20));
    }

    #[test]
    fn empty_and_full_selections() {
        assert_eq!(selection_mask_from_tiles([false; TILE_COUNT]), 0);
        assert_eq!(selection_mask_from_tiles([true; TILE_COUNT]), (1u32 << TILE_COUNT) - 1);
    }

    #[test]
    fn round_trips() {
        let mut tiles = [false; TILE_COUNT];
        tiles[1] = true;
        tiles[7] = true;
        tiles[19] = true;
        assert_eq!(tiles_from_selection_mask(selection_mask_from_tiles(tiles)), tiles);
    }
}
