# ARCLINGS Function Analysis

**Contract:** 0xEb03AC9cE0DCCbb95c0ecF17C957D979233D97Fd  
**Analysis Date:** 2026-09-16  
**Method:** Bytecode selector extraction + 4byte.directory lookup

---

## 🔴 CRITICAL - Admin/Privileged Functions

| Selector | Function | Risk | Notes |
|----------|----------|------|-------|
| `0xf2fde38b` | `transferOwnership(address)` | CRITICAL | Ownership transfer |
| `0x40c10f19` | `adminMint(address,uint256)` | CRITICAL | Privileged minting |
| `0xa04689d2` | `adminMintBatch(address[],uint256[])` | CRITICAL | Batch privileged minting |
| `0x3ccfd60b` | `withdraw()` | HIGH | Withdraw funds |
| `0x44004cc1` | `withdrawERC20(address,address,uint256)` | HIGH | Withdraw ERC20 tokens |
| `0xf4a0a528` | `setMintPrice(uint256)` | HIGH | Change mint price |
| `0xc03afb59` | `setPhase(uint8)` | HIGH | Change sale phase |
| `0x8b533ea4` | `setMaxPerWalletPublic(uint256)` | MEDIUM | Change mint limits |
| `0x34b1d403` | `setMaxPerWalletAllowlist(uint256)` | MEDIUM | Change allowlist limits |
| `0x7cb64759` | `setMerkleRoot(bytes32)` | MEDIUM | Update whitelist |
| `0xc2e5ec04` | `setTradingEnabled(bool)` | MEDIUM | Enable/disable trading |
| `0xa9fc664e` | `setTransferValidator(address)` | MEDIUM | Set transfer validation contract |
| `0x5944c753` | `setTokenRoyalty(uint256,address,uint96)` | MEDIUM | Set royalty info |
| `0x01b9a397` | `setDescriptor(address)` | MEDIUM | Update metadata/render contract |

---

## 🟡 MEDIUM - Minting Functions

| Selector | Function | Risk | Notes |
|----------|----------|------|-------|
| `0x2db11544` | `publicMint(uint256)` | MEDIUM | Public minting (payable) |
| `0x1338a83f` | `allowlistMint(uint256,bytes32[])` | MEDIUM | Whitelist mint with Merkle proof |

---

## 🟢 LOW - View/Query Functions

| Selector | Function | Type |
|----------|----------|------|
| `0x06fdde03` | `name()` | View |
| `0x95d89b41` | `symbol()` | View |
| `0x18160ddd` | `totalSupply()` | View |
| `0x8da5cb5b` | `owner()` | View |
| `0x6817c76c` | `mintPrice()` | View |
| `0x2eb4a7ab` | `merkleRoot()` | View |
| `0x32cb6b0c` | `MAX_SUPPLY()` | View (returns 6283) |
| `0xb1c9fe6e` | `phase()` | View (enum: 0/1/2) |
| `0x4ada218b` | `tradingEnabled()` | View |
| `0xb029a514` | `maxPerWalletPublic()` | View |
| `0x303e74df` | `descriptor()` | View (metadata contract) |
| `0x3828914a` | `totalPublicMinted()` | View |
| `0x6221d13c` | `autoApproveTransfersFromValidator()` | View |
| `0xe8a3d485` | `contractURI()` | View |
| `0x2a55205a` | `royaltyInfo(uint256,uint256)` | View (ERC2981) |

---

## 🔵 STANDARD - ERC-721 Functions

| Selector | Function | Type |
|----------|----------|------|
| `0x70a08231` | `balanceOf(address)` | View |
| `0x6352211e` | `ownerOf(uint256)` | View |
| `0x42842e0e` | `safeTransferFrom(address,address,uint256)` | State |
| `0xb88d4fde` | `safeTransferFrom(address,address,uint256,bytes)` | State |
| `0x23b872dd` | `transferFrom(address,address,uint256)` | State |
| `0x095ea7b3` | `approve(address,uint256)` | State |
| `0xa22cb465` | `setApprovalForAll(address,bool)` | State |
| `0x081812fc` | `getApproved(uint256)` | View |
| `0xe985e9c5` | `isApprovedForAll(address,address)` | View |
| `0xc87b56dd` | `tokenURI(uint256)` | View |
| `0x4f6ccce7` | `tokenByIndex(uint256)` | View (enumerable) |
| `0x2f745c59` | `tokenOfOwnerByIndex(address,uint256)` | View (enumerable) |
| `0x42966c68` | `burn(uint256)` | State (burnable) |
| `0x01ffc9a7` | `supportsInterface(bytes4)` | View |

---

## 🚨 HIGH-PRIORITY ATTACK VECTORS

### 1. Access Control on Admin Functions
**Test:** Can non-owner/non-admin call privileged functions?
```bash
# Test from attacker address
cast call $TARGET "adminMint(address,uint256)" 0xdead 1 --from 0xdeadbeef...
cast call $TARGET "withdraw()" --from 0xdeadbeef...
cast call $TARGET "setMintPrice(uint256)" 0 --from 0xdeadbeef...
```

### 2. Merkle Proof Validation
**Test:** Can attacker forge whitelist proofs?
- Invalid proof acceptance
- Proof reuse across addresses
- Empty proof array handling

### 3. Mint Limit Bypass
**Test:** Can attacker mint beyond per-wallet limits?
- Multiple transactions in same block
- Transfer + re-mint pattern
- Limit enforcement during phase changes

### 4. Reentrancy in Minting
**Test:** Callback exploitation during mint
- Refund handling
- Excess ETH/USDC return
- State updates before external calls

### 5. Phase Transition Logic
**Test:** Can attacker exploit phase changes?
- Mint during phase=0 (disabled)
- Price manipulation during transition
- Allowlist bypass after public phase

### 6. Supply Cap Enforcement
**Test:** Can supply exceed 6283 (0x188b)?
- AdminMint vs supply check
- Overflow protection
- Batch mint totals

### 7. Transfer Validator Bypass
**Test:** Can trading restrictions be bypassed?
- Direct transfer vs validator check
- Validator = address(0) handling
- Approval manipulation

### 8. Burn Function Authorization
**Test:** Who can burn tokens?
- Owner-only or any holder?
- Approval required?
- Event emission

---

## 🔍 SPECIFIC TESTS TO RUN

### Auth Triage (Step 4)
```bash
TARGET=0xEb03AC9cE0DCCbb95c0ecF17C957D979233D97Fd
ATTACKER=0x000000000000000000000000000000000000dead

# Admin functions from unauthorized caller
cast call $TARGET "adminMint(address,uint256)" $ATTACKER 1 --from $ATTACKER
cast call $TARGET "withdraw()" --from $ATTACKER  
cast call $TARGET "setMintPrice(uint256)" 0 --from $ATTACKER
cast call $TARGET "setPhase(uint8)" 2 --from $ATTACKER
cast call $TARGET "setMerkleRoot(bytes32)" 0x00...00 --from $ATTACKER
```

### Mint Flow Test
```bash
# Check current phase
cast call $TARGET "phase()(uint8)"

# Check mint price
cast call $TARGET "mintPrice()(uint256)"

# Check per-wallet limit
cast call $TARGET "maxPerWalletPublic()(uint256)"

# Try public mint (will need correct value)
cast send $TARGET "publicMint(uint256)" 1 --value [MINT_PRICE] --from [YOUR_ADDR]
```

### Supply Validation
```bash
# Check current vs max supply
cast call $TARGET "totalSupply()(uint256)"
cast call $TARGET "MAX_SUPPLY()(uint256)"  # Should return 6283 (0x188b)
```

---

## 📋 NOTES

- Contract uses **3-phase minting**: enum Phase { Disabled, Allowlist, Public }
- **Transfer validation** system present (external validator contract)
- **Merkle tree** whitelist for allowlist phase
- **Per-wallet limits** for both allowlist and public phases
- **ERC2981** royalty standard implemented
- **External descriptor contract** for tokenURI generation
- Uses **reentrancy guard** patterns (detected in bytecode)

---

## ⚠️ INCOMPLETE ANALYSIS

Missing from bytecode-only analysis:
- Storage variable layout
- Internal function logic
- Exact access control modifiers
- Reentrancy protection details
- Merkle proof validation implementation
- Phase transition guard conditions
- Supply cap enforcement location
- Merge/burn engine implementation (Phase 3 - not yet deployed)

**Recommendation:** Obtain source code or perform full decompilation for complete audit.
