# Foundation Map - Tolly Labs

## 5A. State Who-Writes

### TollyPad
- `owner` - admin can update (transferOwnership)
- `banned` (name/symbol blacklist) - owner can set (setBanned)
- `tokens` (TokenInfo mapping) - pad writes during createToken
- `allTokens` array - pad appends during createToken
- `_expectedPoolCallback` - internal, set during _devBuy

### TollyToken
- `pool` - pad sets once (setPool), immutable after
- Balances/supply - standard ERC20, public transfers
- Anti-snipe exemptions - set at construction, immutable

### TollyFeeLocker
- `furnace`, `universalForge`, `treasury`, `holderVault` - initializer sets once (initialize), then burns key
- `positions` - pad registers via register()
- `claimable` - updated during _distribute, decreased by claim()
- `payoutOf` - creator self-service (setPayout)

## 5B. External Call Order

### TollyPad.createToken (main launch flow)
1. **Checks**: banned name/symbol, meta validation
2. **Effects**: 
   - CREATE2 deploy TollyToken (whole supply minted to pad)
   - Create pool via v3Factory.createPool
   - Set pool in token (token.setPool)
3. **Interactions**:
   - pool.initialize (set sqrtPrice)
   - positionManager.mint (LP NFT to locker)
   - locker.register (record position)
   - forge.createUniversalBurner (if forge wired)
   - Optional: _devBuy → pool.swap (callback to pad)

**CEI pattern**: Clean - effects before external calls

### TollyFeeLocker.collect (fee harvesting)
1. **Checks**: furnace initialized, position exists
2. **Interaction**: positionManager.collect (fees to this)
3. **Effects + Interactions** (interleaved in _distribute):
   - Token side: burn to DEAD
   - Quote side 5-way split:
     - Approve + furnace.depositToll (9% TOLLY burn)
     - Transfer to treasury (10% protocol)
     - Transfer to holderVault + try bookAccrual (12% holders)
     - Transfer to burner OR increment claimable[creator] (5% project burn)
     - Try depositPrepaid OR transfer to payout OR increment claimable (64% creator)

**CEI inversion**: Multiple external calls after partial effects. Protected by ReentrancyGuard.

## 5C. Token Paths (Entry → Exit)

### Launch Flow (Single-sided LP)
1. User calls `createToken` with devBuyQuote
2. Pad deploys token with 1B supply → Pad
3. Pad mints entire supply as single-sided LP (token only, 0 USDC) → Locker (NFT permanently locked)
4. If devBuyQuote > 0:
   - Pad pulls USDC from user
   - Swaps USDC → token on fresh pool
   - Delivers tokens to user
   - Refunds unspent USDC

### Fee Collection Flow (Quote = USDC)
1. Anyone calls `locker.collect(tokenId)`
2. Locker harvests fees from Uniswap position
3. Token-side fees → DEAD (100% burn)
4. Quote-side fees split 5 ways:
   - 9% → Furnace (buys/burns TOLLY)
   - 10% → Treasury
   - 12% → HolderVault (with project booking)
   - 5% → Project burner (buys/burns project token) OR claimable if no burner
   - 64% → Creator's payout destination OR claimable

### Creator Payout Destination Options
- Default (address(0)): claimable mapping, pull via claim()
- Set address: push via depositPrepaid (toll-exempt) OR plain transfer
- On transfer fail: falls back to claimable

## 5D. Access Control Gates

| Function | Modifier / Require | Pausable? |
|----------|-------------------|-----------|
| **TollyPad** | | |
| createToken | public, nonReentrant | No |
| updateMeta | creator only (tokens[token].creator == msg.sender) | No |
| setBanned | onlyOwner | No |
| transferOwnership | onlyOwner | No |
| **TollyToken** | | |
| setPool | onlyPad (msg.sender == pad) | No |
| transfers | anti-snipe cap during window | No |
| **TollyFeeLocker** | | |
| initialize | onlyInitializer (msg.sender == initializer), once | No |
| register | onlyPad (msg.sender == pad) | No |
| collect | permissionless, nonReentrant | No |
| claim | permissionless (own balance), nonReentrant | No |
| setPayout | permissionless (own payout), no guard | No |

**No pause mechanism anywhere.**

## 5E. Structured First-Pass Checklist

- [x] **Reentrancy / CEI on all fund paths**: PASS - ReentrancyGuard on createToken, collect, claim. _distribute has interleaved external calls but is guarded.
- [x] **Access control on privileged state changers**: PASS - Owner can only ban names (not touch funds). Pad-only for register/setPool. Initializer burns after one-time setup.
- [ ] **Oracle / pricing freshness**: N/A - No oracle. Prices are pool-native Uniswap V3 sqrtPriceX96.
- [?] **Slippage on DEX interactions**: UNCLEAR - _mintSingleSided has amount0Min=0, amount1Min=0. _devBuy has no slippage param but swaps to range edge (sqrtLimit).
- [ ] **Frontrun / sandwich surface**: POTENTIAL - createToken with devBuyQuote can be front-run (atomic but public txn). Single-sided mint is at exact tick (no slippage).
- [x] **Init / proxy**: PASS - Not upgradeable. TollyFeeLocker.initialize is one-shot with key burn.
- [ ] **Upgrade storage safety**: N/A - Not upgradeable.
- [x] **Pause semantics**: N/A - No pause.
- [ ] **Events on policy / risk parameter changes**: PASS - setBanned emits BannedSet. transferOwnership emits OwnershipTransferred.

## Key Observations

### Anti-Grief Mechanism (CREATE2 Walk)
- TollyPad uses CREATE2 with random salt + 64-try walk to avoid pool-griefing
- Checks: `v3Factory.getPool(predicted, quote, fee) == 0 && predicted.code.length == 0`
- **Potential issue**: What if all 64 tries are poisoned? Reverts with LaunchGriefed.

### Single-Sided LP Invariants
- Must consume ~100% of token supply (check: `tokenUsed >= supply - supply/1000`)
- Must consume exactly 0 USDC (check: `quoteUsed != 0` reverts)
- Liquidity must be non-zero

### Fee Split Constants (Immutable)
- Creator: 64%
- Holders: 12%
- Protocol: 10%
- TOLLY burn: 9%
- Project burn: 5%
- Total: 100%

### Trust Boundaries
1. **Owner** (TollyPad): Can ban names/symbols for future launches. Cannot touch existing tokens or funds.
2. **Initializer** (TollyFeeLocker): One-time wiring, then key burned. Cannot change furnace/treasury/vault after.
3. **Creator**: Can update own token metadata, set own payout destination. Cannot touch others' funds.
4. **Furnace/Treasury/HolderVault**: Receive protocol shares. Locker cannot redirect these after initialize.

### External Dependencies
- Uniswap V3 Factory (pool creation)
- Uniswap V3 Position Manager (LP NFT)
- TollyFurnace (TOLLY buyback)
- UniversalForge (project burner resolution)
- HolderVault (holder rewards, bookAccrual optional)
- Treasury (protocol fee receiver)
