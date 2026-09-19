# TronBid Architecture Analysis

## System Components

### 1. Market Layer
- **Type:** P2P Resource Marketplace
- **Assets:** TRON Energy, TRON Bandwidth
- **Payment:** TRX, USDT
- **Model:** Rental with fixed expiration (15-60 minutes)

### 2. Smart Contracts Layer
- **Delegation Contract:** Likely uses TRON's built-in `DelegateResource` RPC
- **Payment Contract:** Receives TRX in `on-chain mode` or debits from balance in `balance mode`
- **Order Book Contract:** Tracks active orders and fulfillment state
- **Status:** Closed-source; not published on GitHub or TRONSCAN

### 3. API Layer
- **Endpoint:** `https://tronbid.com/api/v2/quick-rent`
- **Auth:** Bearer token (OpenAPI 3.1)
- **Key Methods:**
  - `POST /orders` - Create rental order
  - `GET /orders/{id}` - Check order status
  - `POST /orders/{id}/cancel` - Cancel order
  - `GET /market/stats` - Market data

### 4. Payment Flow

#### On-Chain Mode (Default)
```
User → API generates pay_address → User sends TRX → API triggers DelegateResource → Energy delegated to target_address → Delegation expires after rental window → TRX returned or keeps partial if not fully used
```

#### Balance Mode
```
User → API debits pre-funded balance → API triggers DelegateResource → Energy delegated → Delegation expires → Balance returned if partial energy unused
```

## Data Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                          TronBid Marketplace                        │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  1. Order Creation                                                  │
│     User (Buyer) ─────────────────┐                                │
│                                   │                                │
│                     POST /orders   │                                │
│                     {target_addr}  │                                │
│                                   ↓                                │
│                        API Server (Node 1-N)                       │
│                                   │                                │
│                                   ├─→ Generate pay_address         │
│                                   ├─→ Reserve order slot           │
│                                   └─→ Return order_id              │
│                                                                     │
│  2. Payment (On-Chain Mode)                                        │
│     User ─────────────────────────→ pay_address (TRX)             │
│                                        │                           │
│                                        ↓                           │
│                                  Seller wallet                     │
│                                        │                           │
│                                   [Payment Confirm]                │
│                                        │                           │
│                                        ↓                           │
│  3. Delegation                  API detects payment                │
│     API ─────────────────────────→ TRON DelegateResource RPC      │
│            {seller, buyer,             │                          │
│             energy, duration}          ↓                           │
│                              TRON Network (MainNet)                │
│                              Delegation: seller                    │
│                              delegated energy to                   │
│                              buyer address for                     │
│                              ~30 minutes                           │
│                                        │                           │
│                                   [Confirm]                        │
│                                        │                           │
│                                        ↓                           │
│  4. Order Complete              API updates order state            │
│     API ─────────────────────────→ User (confirmation)             │
│            {status: fulfilled,                                     │
│             effective_energy,                                      │
│             expiration_time}                                       │
│                                        │                           │
│  5. Energy Expiration (Auto)           │                           │
│     [15-60 min later]                  │                           │
│     TRON Network ──────────────────────┘                           │
│     Delegation expires automatically                               │
│     Energy returns to seller                                       │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

## Critical State Machines

### Order State Machine
```
[PENDING] 
    ↓ user pays / balance confirmed
[PAID]
    ├─→ delegation succeeds → [ACTIVE]
    ├─→ delegation fails → [REFUND_PENDING]
    └─→ timeout (5 min) → [EXPIRED]
    
[ACTIVE]
    ├─→ expiration time reached → [COMPLETED]
    └─→ user cancels → [CANCELLED]
    
[REFUND_PENDING]
    ├─→ refund sent → [REFUNDED]
    └─→ timeout (48h) → [MANUAL_REVIEW]
    
[COMPLETED/CANCELLED/REFUNDED/MANUAL_REVIEW]
    └─→ archived
```

## Trust Model

**Current Model (API-Centric):**
- TronBid API coordinates between buyers and sellers
- TronBid controls delegation timing and payment flow
- Users must trust TronBid's contract deployment and key management
- Custody model unclear (escrow vs direct delegation)

**Attack Surface:**
- SR Partner account (TGcwj4sP1iiSwMrMEPmDw43J1V3CehK7rM) is single point of failure
- API nodes are centralized trust points
- No on-chain order book provides fairness guarantees
- Payment-delegation atomicity not enforced

## Risk Assessment by Component

| Component | Risk Level | Reason |
|-----------|-----------|--------|
| SR Partner Account | CRITICAL | Holds delegation authority for all energy |
| API Server | HIGH | Coordinates payment and delegation; race conditions |
| Order Book Contract | HIGH | State consistency in async environment |
| Delegation RPC | MEDIUM | Relies on TRON network fairness |
| Payment Processing | HIGH | No visible escrow or atomic confirmation |

