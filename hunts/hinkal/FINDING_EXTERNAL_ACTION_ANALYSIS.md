# CRITICAL FINDING - EXTERNAL ACTION ACCOUNTING BYPASS

## Summary

**Severity**: HIGH to CRITICAL (needs PoC verification)
**Component**: External Action Trust Model (Hinkal.sol + ExternalActionSwap.sol)
**Impact**: Potential accounting manipulation allowing malicious external actions to create inflated UTXO commitments

## Root Cause Analysis

### The Flow

1. **Hinkal sends tokens to external action** (Hinkal.sol lines 247-256):
```solidity
for (uint256 i = 0; i < circomData.erc20TokenAddresses.length; i++) {
    deltaAmountChanges[i] = _calculateDeltaAmount(circomData, i);
    if (deltaAmountChanges[i] < 0) {
        transferERC20TokenOrETH(
            circomData.erc20TokenAddresses[i],
            circomData.externalActionData.externalAddress,
            uint256(-deltaAmountChanges[i])
        );
    }
}
```

2. **External action returns UTXO array** (line 258-260):
```solidity
return IExternalActionV2(circomData.externalActionData.externalAddress).runAction(circomData, deltaAmountChanges);
```

3. **Balance equation validates** (Hinkal.sol lines 137-146):
```solidity
require(
    balanceDif == (circomData.onChainCreation[i] ? int256(0) : circomData.amountChanges[i]) + int256(utxoAmount),
    "Balance Diff Should be equal to sum of onchain and offchain created commitments"
);
```

### The Vulnerability

**ExternalActionSwap returns a UTXO with amount SENT BACK to Hinkal**:

```solidity
// ExternalActionSwap.sol lines 93-101
uint256 amountToSendToHinkal = swappedAmount - totalFee;
transferERC20TokenOrETH(outputToken, msg.sender, amountToSendToHinkal);

utxoSet = new UTXO[](1);
utxoSet[0] = UTXO({
    amount: amountToSendToHinkal,  // ← Claims this amount
    erc20Address: outputToken,
    stealthAddressStructure: circomData.stealthAddressStructure,
    timeStamp: block.timestamp
});
```

**But what if the external action LIES about the amount?**

### Attack Scenario

**Scenario 1: Malicious External Action**

A malicious external action (registered by compromised admin) could:

```solidity
function runAction(CircomData calldata circomData, int256[] calldata deltaAmounts) 
    external override onlyAllowedRecipient returns (UTXO[] memory) {
    
    // Receive 100 tokens from Hinkal
    uint256 received = uint256(-deltaAmounts[0]); // 100
    
    // Send back only 50 tokens
    transferERC20TokenOrETH(circomData.erc20TokenAddresses[0], msg.sender, 50);
    
    // But claim we sent back 100!
    utxoSet = new UTXO[](1);
    utxoSet[0] = UTXO({
        amount: 100,  // ← LIE! Only sent 50
        erc20Address: circomData.erc20TokenAddresses[0],
        stealthAddressStructure: circomData.stealthAddressStructure,
        timeStamp: block.timestamp
    });
    
    // Keep 50 tokens (steal from protocol)
}
```

**Balance Equation Check**:
```
oldBalance = 1000 (Hinkal's balance before)
Hinkal sends 100 to external action → balance = 900
External action sends back 50 → balance = 950
newBalance = 950

balanceDif = newBalance - oldBalance = 950 - 1000 = -50

From proof:
amountChanges[0] = -100 (user withdrawing 100 from private balance)

From external action:
utxoAmount = 100 (claimed)

Balance equation:
-50 == -100 + 100
-50 == 0  ← FAILS!
```

**Wait...** the balance check SHOULD catch this. Let me reconsider...

### Re-analysis: The Balance Check Protection

The balance equation is:
```
(newBalance - oldBalance) = amountChanges[i] + utxoAmount
```

For a swap where user spends tokenA and receives tokenB:
- `amountChanges[0]` (tokenA) = -100 (user spends)
- `amountChanges[1]` (tokenB) = 0 (off-chain doesn't know swap output yet)
- External action returns UTXO for tokenB with amount = swapped amount

**For tokenA**:
```
balanceDif(tokenA) = -100 (sent to external action)
amountChanges[0] = -100
utxoAmount = 0 (no UTXO created for tokenA)
Check: -100 == -100 + 0 ✅
```

**For tokenB**:
```
balanceDif(tokenB) = +90 (received from external action after fees)
amountChanges[1] = 0 (nothing from off-chain)
utxoAmount = 90 (UTXO created for received amount)
Check: 90 == 0 + 90 ✅
```

**If external action steals**:
```
balanceDif(tokenB) = +50 (only 50 sent back)
utxoAmount = 90 (UTXO claims 90)
Check: 50 == 0 + 90 ❌ FAILS!
```

### Conclusion on This Attack

**Status**: ❌ FALSE POSITIVE - The balance equation DOES protect against this.

The external action cannot lie about the amount because:
1. The actual balance change is measured by Hinkal
2. The UTXO amount must match the balance change
3. If they don't match, transaction reverts

---

## HOWEVER - NEW ATTACK VECTOR IDENTIFIED

### Attack Scenario 2: External Action Doesn't Send Tokens Back

What if the external action:
1. Receives tokens from Hinkal
2. Returns an EMPTY UTXO array: `utxoSet = new UTXO[](0)`
3. Keeps all the tokens

**Balance Check**:
```
balanceDif(tokenA) = -100 (sent to external action)
amountChanges[0] = -100
utxoAmount = 0 (no UTXOs created)
Check: -100 == -100 + 0 ✅ PASSES!
```

**Result**: User loses their tokens, gets no UTXO commitment, external action keeps everything.

**But**: This would be caught by slippage check!

```solidity
// Hinkal.sol lines 111-114
require(
    balanceDif >= circomData.slippageValues[i],
    "slippage param is violated"
);
```

For the output token, user sets `slippageValues[1] = 90` (minimum expected).
If external action doesn't send anything back:
```
balanceDif = 0
slippageValues[1] = 90
Check: 0 >= 90 ❌ FAILS!
```

### Conclusion

**Status**: ✅ PROTECTED - Slippage check prevents external action from stealing by not returning tokens.

---

## ACTUAL VULNERABILITY FOUND

### Attack Scenario 3: Fee-on-Transfer + External Action

**The Setup**:
1. User swaps from USDT (fee-on-transfer) to USDC
2. User's proof claims withdrawing 100 USDT
3. External action expects 100 USDT

**The Flow**:
```solidity
// Hinkal sends 100 USDT to external action
transferERC20TokenOrETH(USDT, externalAction, 100);
// But external action only receives 99 (1% fee)

// External action tries to swap 100 USDT
// Swap fails or swaps only 99
// Returns UTXO for 89 USDC (after swap + fees)

// Balance check for USDT:
balanceDif = -99 (actual balance change due to fee)
amountChanges[0] = -100 (from proof)
utxoAmount = 0
Check: -99 == -100 + 0 ❌ FAILS!
```

**Result**: Transaction reverts, but protocol accounting is off by 1 USDT.

**Actually wait**, let me trace this more carefully:

```solidity
// Line 182-187 in Hinkal.sol (_internalTransact)
transferERC20TokenFromOrCheckETH(
    circomData.erc20TokenAddresses[i],
    circomData.externalActionData.externalAddress,
    address(this),
    uint256(circomData.amountChanges[i])
);
```

This is for deposits (positive amountChanges). For external actions, it's:

```solidity
// Line 250-255 (_externalTransact)
transferERC20TokenOrETH(
    circomData.erc20TokenAddresses[i],
    circomData.externalActionData.externalAddress,
    uint256(-deltaAmountChanges[i])
);
```

Using `transferERC20TokenOrETH` which uses SafeERC20.

**For fee-on-transfer tokens**:
- Hinkal's balance decreases by amount sent (100)
- External action receives less (99)
- External action can only work with what it received (99)
- It sends back less to Hinkal
- Balance check should catch the discrepancy

But the balance check is measuring Hinkal's balance, not the external action's!

**Let me trace a concrete example**:

Initial: Hinkal has 1000 USDT (fee-on-transfer), External action has 0
1. User wants to swap 100 USDT → USDC via external action
2. `oldBalances` = [1000, 0] (USDT, USDC)
3. Hinkal transfers 100 USDT to external action:
   - Hinkal's balance: 900 USDT (sent 100)
   - External action receives: 99 USDT (1 deducted by token)
4. External action swaps 99 USDT → gets 98 USDC (after fees)
5. External action sends 98 USDC back to Hinkal
6. `newBalances` = [900, 98]
7. Balance checks:
   - USDT: `balanceDif = 900 - 1000 = -100`, `amountChanges[0] = -100`, `utxoAmount = 0`
     Check: `-100 == -100 + 0` ✅
   - USDC: `balanceDif = 98 - 0 = 98`, `amountChanges[1] = 0`, `utxoAmount = 98`
     Check: `98 == 0 + 98` ✅
   
Transaction succeeds! But external action only received 99 USDT, not 100.

**Is this a problem?** Not really - Hinkal sent 100, its balance decreased by 100. The fee is eaten by the external action, which is expected behavior for fee-on-transfer tokens.

---

## Final Verdict

**Status**: ✅ NO CRITICAL VULNERABILITY in external action accounting

The balance equation and slippage checks effectively prevent:
1. External actions from lying about UTXO amounts
2. External actions from not returning tokens
3. Fee-on-transfer token accounting issues

**The protection works because**:
- Balance changes are measured on Hinkal's side, not trusted from external action
- UTXO amounts must exactly match what Hinkal receives
- Slippage checks ensure minimum amounts are received

---

## Remaining Concern: Admin Trust

External actions are **admin-registered** only:
```solidity
function registerExternalAction(uint256 externalActionId, address externalActionAddress) 
    public onlyRole(DEFAULT_ADMIN_ROLE)
```

**Trust Requirement**: Admin must only register well-audited, non-malicious external actions.

**Risk**: If admin is compromised or malicious, they could register an action that:
- Doesn't properly validate inputs
- Has exploitable bugs
- Could be used to drain funds through complex interactions

**Severity**: TRUST/CENTRALIZATION - Not a permissionless exploit, but admin has significant power.
