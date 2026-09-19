# TronBid: Remediation Roadmap & Implementation Guide

## Priority 1: CRITICAL (Implement This Week)

### 1.1 Payment-Delegation Atomicity
**Goal:** Ensure buyer funds are never locked without receiving energy.

**Implementation:**
```solidity
// Option A: Atomic Escrow
contract EnergyEscrow {
    struct Order {
        address buyer;
        address seller;
        uint256 energy;
        uint256 payment;
        uint256 expiration;
        bool delegated;
        bool refunded;
    }
    
    function createOrder(
        address seller,
        uint256 energy,
        uint256 duration
    ) external payable returns (bytes32 orderId) {
        bytes32 id = keccak256(abi.encode(seller, msg.sender, block.timestamp));
        
        orders[id] = Order({
            buyer: msg.sender,
            seller: seller,
            energy: energy,
            payment: msg.value,
            expiration: block.timestamp + duration,
            delegated: false,
            refunded: false
        });
        
        // HOLD payment in contract (escrow)
        // Do NOT send to seller yet
        
        return id;
    }
    
    function fulfillOrder(bytes32 orderId) external {
        Order storage order = orders[orderId];
        require(msg.sender == order.seller, "Only seller can fulfill");
        require(!order.delegated, "Already delegated");
        
        // Attempt delegation
        bool delegationSuccess = delegateEnergy(
            order.seller,
            order.buyer,
            order.energy
        );
        
        if (delegationSuccess) {
            order.delegated = true;
            // NOW release payment to seller
            payable(order.seller).transfer(order.payment);
            emit OrderFulfilled(orderId);
        } else {
            // Delegation failed; refund buyer immediately
            order.refunded = true;
            payable(order.buyer).transfer(order.payment);
            emit OrderRefunded(orderId);
        }
    }
}
```

**Verification Steps:**
1. Deploy escrow contract to testnet
2. Create order: verify funds held in contract
3. Trigger delegation failure: verify automatic refund
4. Trigger delegation success: verify payment released to seller

**Timeline:** 1-2 days

---

### 1.2 Energy Expiration Grace Period
**Goal:** Prevent race conditions at delegation expiration.

**Implementation:**
```solidity
// Extend delegation past rental window
contract EnergyMarket {
    uint256 constant GRACE_PERIOD = 5 minutes;  // Extend delegation 5 min past rental
    
    function delegateEnergy(
        address seller,
        address buyer,
        uint256 energyAmount,
        uint256 rentalDuration
    ) internal {
        uint256 actualDuration = rentalDuration + GRACE_PERIOD;
        
        // Call TRON's DelegateResource with extended duration
        bytes memory payload = abi.encodePacked(
            "DelegateResource",
            seller,
            buyer,
            energyAmount,
            actualDuration,
            "ENERGY"
        );
        
        // Invoke TRON VM
        (bool success, ) = TRON_SYSTEM_CONTRACT.call(payload);
        require(success, "Delegation failed");
        
        // Log actual expiration for monitoring
        emit DelegationCreated(seller, buyer, energyAmount, actualDuration);
    }
}
```

**Verification Steps:**
1. Monitor delegation expiration via TRONSCAN
2. Confirm grace period extends expiration by 5 minutes
3. Submit transaction at original expiration + 4 minutes: should still use delegated energy
4. Submit transaction at original expiration + 6 minutes: should burn TRX (grace expired)

**Timeline:** 1 day

---

### 1.3 SR Account Key Security Audit
**Goal:** Verify SR account uses multisig/hardware wallet.

**Checklist:**
- [ ] Confirm private key is NOT stored in Git, Docker, or config files
- [ ] Verify key is on hardware wallet (Ledger, Trezor) or multisig contract
- [ ] Confirm multisig is 2-of-3 or 3-of-5 (not 1-of-1)
- [ ] Test: attempt unauthorized delegation from random key → should fail
- [ ] Implement key rotation schedule (quarterly)
- [ ] Enable TRONSCAN alerts for unusual SR delegation activity
- [ ] Set up monitoring: if delegation revocations spike, alert security team

**Remediation (if key is exposed):**
1. Rotate private key immediately
2. Pause marketplace temporarily
3. Cancel all pending delegations
4. Compensate affected users

**Timeline:** 2-3 days (includes multisig setup if needed)

---

### 1.4 API Key Spending Caps
**Goal:** Prevent B2B API key abuse through unlimited orders.

**Implementation:**
```python
# FastAPI rate limiting middleware
from datetime import datetime, timedelta
from redis import Redis

redis_client = Redis(host='localhost', port=6379)

async def check_spending_cap(api_key: str, order_cost: float):
    """Enforce per-minute, per-hour, per-day spending limits"""
    
    # Define limits per tier
    tier = get_api_tier(api_key)  # "free", "pro", "enterprise"
    limits = {
        "free": {"minute": 10, "hour": 100, "day": 1000},
        "pro": {"minute": 100, "hour": 1000, "day": 10000},
        "enterprise": {"minute": 1000, "hour": 10000, "day": 100000},
    }
    
    current_limits = limits[tier]
    now = datetime.now()
    
    # Check minute limit
    minute_key = f"spend_{api_key}_{now.strftime('%Y%m%d%H%M')}"
    minute_spent = redis_client.get(minute_key) or 0
    
    if float(minute_spent) + order_cost > current_limits["minute"]:
        return False, f"Minute limit exceeded: {minute_spent}/{current_limits['minute']} TRX"
    
    # Check hour limit
    hour_key = f"spend_{api_key}_{now.strftime('%Y%m%d%H')}"
    hour_spent = redis_client.get(hour_key) or 0
    
    if float(hour_spent) + order_cost > current_limits["hour"]:
        return False, f"Hour limit exceeded: {hour_spent}/{current_limits['hour']} TRX"
    
    # Check day limit
    day_key = f"spend_{api_key}_{now.strftime('%Y%m%d')}"
    day_spent = redis_client.get(day_key) or 0
    
    if float(day_spent) + order_cost > current_limits["day"]:
        return False, f"Day limit exceeded: {day_spent}/{current_limits['day']} TRX"
    
    # Update counters (expire after period)
    redis_client.incrbyfloat(minute_key, order_cost)
    redis_client.expire(minute_key, 60)
    
    redis_client.incrbyfloat(hour_key, order_cost)
    redis_client.expire(hour_key, 3600)
    
    redis_client.incrbyfloat(day_key, order_cost)
    redis_client.expire(day_key, 86400)
    
    return True, "OK"

@app.post("/api/v2/quick-rent/orders")
async def create_order(api_key: str, order_data: OrderRequest):
    # Check spending cap
    order_cost = order_data.energy * 0.0005  # TRX per energy unit
    allowed, reason = await check_spending_cap(api_key, order_cost)
    
    if not allowed:
        return HTTPException(status_code=429, detail=reason)
    
    # Proceed with order
    ...
```

**Verification:**
1. Create API key with "pro" tier (100 TRX/minute limit)
2. Submit 150 TRX of orders in 1 minute
3. Verify 50 TRX rejected with 429 status code
4. Wait 60 seconds, resubmit: verify accepted

**Timeline:** 2-3 days

---

## Priority 2: HIGH (Implement This Month)

### 2.1 Order Book Atomicity & Race Condition Prevention
**Goal:** Prevent two sellers from accepting same order simultaneously.

**Implementation:**
```solidity
// Use state machine with mutex-like protection
contract OrderBook {
    enum OrderState {
        OPEN,
        PENDING_FULFILLMENT,
        FULFILLED,
        CANCELLED
    }
    
    struct Order {
        address buyer;
        uint256 energy;
        uint256 pricePerUnit;
        OrderState state;
        address fulfilledBySeller;
    }
    
    mapping(bytes32 => Order) public orders;
    mapping(bytes32 => bool) private orderLocked;  // Mutex
    
    function acceptOrder(bytes32 orderId, address seller) external returns (bool) {
        Order storage order = orders[orderId];
        
        // Atomic check + set (prevents race)
        require(order.state == OrderState.OPEN, "Order not open");
        require(!orderLocked[orderId], "Order locked by another seller");
        
        // LOCK the order
        orderLocked[orderId] = true;
        
        // Try to transition state
        try this.executeOrderFulfillment(orderId, seller) {
            order.state = OrderState.PENDING_FULFILLMENT;
            order.fulfilledBySeller = seller;
            return true;
        } catch {
            // Unlock if fulfillment fails
            orderLocked[orderId] = false;
            revert("Fulfillment failed");
        }
    }
    
    function executeOrderFulfillment(bytes32 orderId, address seller) external {
        Order memory order = orders[orderId];
        // Attempt delegation and payment transfer here
        // If fails, transaction reverts (lock released)
    }
}
```

**Verification:**
1. Deploy to testnet
2. Simulate two concurrent seller accept requests
3. Verify only one succeeds; other gets "Order locked" error
4. Verify failed seller's transaction reverts before energy delegated

**Timeline:** 3-5 days

---

### 2.2 API Key Rotation & Revocation
**Goal:** Enable users to rotate/revoke keys; leak cleanup procedure.

**Implementation:**
```python
# API endpoint for key rotation
@app.post("/api/v2/admin/keys/{key_id}/rotate")
async def rotate_api_key(key_id: str, user: User):
    old_key = get_api_key(key_id)
    assert old_key.owner == user.id
    
    # Generate new key
    new_key = secrets.token_urlsafe(32)
    
    # Disable old key immediately
    old_key.status = "REVOKED"
    old_key.revoked_at = datetime.now()
    db.commit()
    
    # Create new key with same permissions
    new_api_key = APIKey(
        user_id=user.id,
        key=new_key,
        permissions=old_key.permissions,
        tier=old_key.tier,
    )
    db.add(new_api_key)
    db.commit()
    
    return {
        "new_key": new_key,
        "old_key_revoked": True,
        "revoked_at": old_key.revoked_at,
    }

@app.post("/api/v2/admin/keys/{key_id}/revoke")
async def revoke_api_key(key_id: str, user: User):
    api_key = get_api_key(key_id)
    assert api_key.owner == user.id
    
    api_key.status = "REVOKED"
    api_key.revoked_at = datetime.now()
    db.commit()
    
    # Invalidate all sessions using this key
    invalidate_sessions_with_key(key_id)
    
    return {"status": "revoked"}

@app.middleware("http")
async def check_key_revoked(request: Request, call_next):
    api_key = request.headers.get("Authorization", "").replace("Bearer ", "")
    
    key_obj = get_api_key(api_key)
    if key_obj.status == "REVOKED":
        return JSONResponse(status_code=401, content={"error": "Key revoked"})
    
    response = await call_next(request)
    return response
```

**Verification:**
1. Create API key
2. Test key works (POST /orders succeeds)
3. Revoke key
4. Test key fails (POST /orders returns 401)
5. Rotate key to new one
6. Test new key works

**Timeline:** 2-3 days

---

### 2.3 Custody Model Transparency & Escrow Verification
**Goal:** Clarify whether TronBid holds funds in escrow or delegates directly.

**Action Items:**
- [ ] Publish all escrow contract addresses on tronbid.com/transparency
- [ ] Deploy contracts to TRONSCAN with source code verification
- [ ] Add real-time audit dashboard showing:
  - Total TRX in escrow
  - Per-order escrow breakdown
  - Refund history
- [ ] Third-party audit of custody model (ChainSecurity or SlowMist)
- [ ] If non-custodial: prove with on-chain verification contract

**Timeline:** 1-2 weeks

---

### 2.4 USDT Reentrancy Protection
**Goal:** Prevent reentrancy exploits if USDT payments are integrated.

**Implementation:**
```solidity
// Use checks-effects-interactions pattern
contract USDTMarket {
    IERC20 usdt;
    
    // DON'T do this (vulnerable):
    // usdt.transferFrom(buyer, seller, amount);
    // delegateEnergy(...);
    
    // DO this (safe):
    function fulfillWithUSDT(bytes32 orderId) external {
        Order memory order = orders[orderId];
        
        // CHECKS: Verify order state
        require(order.state == OrderState.PENDING_PAYMENT, "Invalid state");
        
        // EFFECTS: Update internal state first
        orders[orderId].state = OrderState.DELEGATING;
        
        // INTERACTIONS: Only do external calls last
        bool delegationSuccess = delegateEnergy(...);
        require(delegationSuccess, "Delegation failed");
        
        // Transfer USDT only after successful delegation
        bool transferSuccess = usdt.transferFrom(buyer, seller, amount);
        require(transferSuccess, "USDT transfer failed");
        
        // Update final state
        orders[orderId].state = OrderState.FULFILLED;
    }
}
```

**Verification:**
1. Deploy malicious reentrancy contract as buyer
2. Attempt to re-enter `fulfillWithUSDT` during payment
3. Verify contract state prevents second execution
4. Confirm attacker receives only 1x energy despite reentrancy

**Timeline:** 1-2 days

---

### 2.5 Price Slippage Protection for Quick Rent
**Goal:** Prevent front-running and price manipulation.

**Implementation:**
```python
@app.post("/api/v2/quick-rent/orders")
async def create_order_with_slippage(
    target_address: str,
    energy_amount: int,
    max_price_per_1k: float,  # NEW: user specifies max acceptable price
    duration_minutes: int,
):
    """
    Accept order only if current market price <= max_price_per_1k
    """
    
    # Get current market price from order book
    current_price = get_market_price()  # e.g., 0.48 TRX per 1k energy
    
    # Check slippage
    if current_price > max_price_per_1k:
        return {
            "status": "REJECTED",
            "reason": "Price slippage exceeded",
            "current_price": current_price,
            "max_acceptable": max_price_per_1k,
            "slippage_percent": ((current_price - max_price_per_1k) / max_price_per_1k) * 100,
        }
    
    # Proceed with order at current_price
    order = create_order(
        target=target_address,
        energy=energy_amount,
        price=current_price,  # Actual price (not user's max)
        duration=duration_minutes,
    )
    
    return order
```

**Verification:**
1. Set max_price_per_1k = 0.40 TRX
2. Current market = 0.50 TRX
3. Verify order rejected with slippage reason
4. Set max_price_per_1k = 0.60 TRX
5. Verify order accepted at 0.50 TRX market price

**Timeline:** 1 day

---

## Priority 3: MEDIUM (Implement This Quarter)

### 3.1 Formal Verification of Order Matching
**Goal:** Mathematically prove order fairness and prevent races.

**Approach:**
- Use Certora formal verification framework
- Prove invariants:
  - **Fairness:** Each order matched exactly once
  - **Atomicity:** Payment and delegation both succeed or both fail
  - **Ordering:** Older orders prioritized over newer
  - **No double-spend:** Energy consumption tracked cumulatively per buyer

**Timeline:** 2-3 weeks (requires hiring security expert)

---

### 3.2 On-Chain Order Book (Decentralization)
**Goal:** Move from API-centric to on-chain order matching for fairness.

**Architecture:**
```solidity
// Decentralized order book on TRON
contract DecentralizedEnergyMarket {
    struct Order {
        address maker;
        uint256 energyAmount;
        uint256 pricePerUnit;
        uint256 expirationBlock;
        bool isBuy;  // true = buyer order, false = seller order
        OrderState state;
    }
    
    uint256 nextOrderId;
    mapping(uint256 => Order) public orders;
    
    // Matching engine on-chain
    function matchOrders() external {
        // Fetch all OPEN buy orders sorted by price DESC
        // Fetch all OPEN sell orders sorted by price ASC
        // Match highest-bid buy order with lowest-ask sell order
        // Atomically update state + execute delegation
    }
}
```

**Benefits:**
- Eliminates API single point of failure
- Achieves true decentralization
- Prevents race conditions (TRON blockchain ordering is final)
- Users verify fairness directly

**Timeline:** 4-6 weeks

---

### 3.3 Emergency Pause & Circuit Breaker
**Goal:** Gracefully handle cascade failures (e.g., SR account unstaking).

**Implementation:**
```solidity
contract EmergencyControl {
    address public admin;
    bool public marketPaused;
    
    event MarketPaused(string reason);
    event OrdersCanceledGracefully(uint256 count);
    
    function emergencyPause(string calldata reason) external onlyAdmin {
        marketPaused = true;
        emit MarketPaused(reason);
        
        // Stop new orders
        // Keep existing orders live (don't cancel yet)
    }
    
    function gracefulShutdown() external onlyAdmin {
        // Called if SR account unstakes or key is compromised
        
        uint256 orderCount = totalOrders;
        
        // Cancel all pending orders
        // Refund all buyers
        // Return delegated energy to sellers
        
        for (uint256 i = 0; i < orderCount; i++) {
            if (orders[i].state == OrderState.PENDING_FULFILLMENT) {
                refundBuyer(orders[i].buyer, orders[i].payment);
                undelegateEnergy(orders[i].seller, orders[i].buyer);
                orders[i].state = OrderState.CANCELLED;
            }
        }
        
        emit OrdersCanceledGracefully(orderCount);
    }
}
```

**Timeline:** 2-3 days

---

## Verification Checklist

- [ ] All 5 Priority 1 items completed
- [ ] All 5 Priority 2 items completed
- [ ] Formal audit by third-party firm (ChainSecurity, SlowMist, etc.)
- [ ] Bounty program launched ($5k-50k for critical bugs)
- [ ] Public security roadmap published
- [ ] Quarterly security reviews scheduled

---

## Disclosure Timeline

| Week | Action |
|------|--------|
| 1 | Send initial advisory to TronBid security team |
| 1-4 | Provide detailed PoCs and remediation guidance |
| 4-12 | TronBid implements fixes (90-day window) |
| 12 | Verify patches deployed |
| 13 | Public disclosure (blog post, Twitter thread) |

---

## Post-Remediation Testing

After TronBid implements fixes:

1. **Re-run all 11 PoCs** - Verify exploits no longer work
2. **Fuzz API** - Attempt 100k malformed requests
3. **Stress test** - 1000 concurrent orders; verify no races
4. **Monitor mainnet** - Check for unusual patterns for 2 weeks
5. **Public audit** - Publish findings (redacted if requested)

