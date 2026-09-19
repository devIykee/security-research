# Lunya Hunt Notes

## Initial Observations

### Contracts Identified
1. **Launch Factory** (0xfb68a7bdc87b6754b5dd092586b8e2904baad46e)
   - Creates launch contracts (token launchpad)
   - Manages quote tokens, fees, graduation parameters
   - Owner-controlled with Ownable2Step pattern

2. **Liquidity Locker** (0x225375b9e6c26E1c3DE691F3864D1f2eBED1C25a)
   - Locks graduated liquidity positions (NFTs)
   - Fee distribution to creator and protocol
   - Only DEPOSITOR can lock positions

3. **Launch Contract (LunyaLaunchCP)**
   - Constant-product bonding curve
   - Handles buy/sell on curve
   - Graduation flow (transitions to DEX pool)

### Key Functions of Interest

#### Launch Factory
- `createLaunch()` / `createLaunchWithNative()` - creates new token launches
- `openPool()` - opens a pool (unclear who can call this)
- `setImplementation()` - owner can change launch implementation
- `approveQuoteToken()` / `revokeQuoteToken()` - owner manages approved tokens
- `sweepFees()` - anyone can sweep fees to feeRecipient
- `depositFees()` - deposits fees (who can call?)

#### Liquidity Locker
- `lock()` - locks a position NFT (only DEPOSITOR can call)
- `collectFees()` - collects fees from locked positions
- `transferSelf()` - transfers tokens (OnlySelf error suggests internal only)

#### Launch Contract (LunyaLaunchCP)
- `buy()` / `buyWithNative()` - buy tokens on curve
- `sell()` / `sellForNative()` - sell tokens back
- `collectFees()` - collects creator and protocol fees
- **NO `graduate()` function visible in ABI** - need to check how graduation happens

### Questions to Investigate
1. **Graduation flow**: How is graduation triggered? Is there a separate function? Who can call it?
2. **Pool creation squat**: Can an attacker pre-create the pool with a malicious price before graduation?
3. **Access control on openPool()**: Missing auth check?
4. **Fee distribution**: Can fees be stolen or manipulated?
5. **Liquidity locking**: Is the lock actually permanent? Can it be bypassed?
6. **Implementation upgrade**: Can owner rug by upgrading implementation?

## Product Type Analysis
This is a **launchpad** - highest priority vulnerability classes:
- Migration/graduation pool manipulation (v3 pool squat)
- Missing access control on graduation
- Liquidity lock bypass
- Fee manipulation
- First buyer advantage / snipe tax bypass
