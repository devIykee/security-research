# SunSwap V4 Hook Vulnerability - Source Code Verification

Date: 2026-08-28
Status: VERIFICATION IN PROGRESS
Method: Source code analysis (read-only)

---

## What I'm Verifying

Agent claimed: "SunSwap V4 has unvalidated hook returns allowing pool drain"

Looking at actual source code to check if this is true.

---

## Source Code Analysis

### Files Examined

1. `/hunts/_verified-contracts/sunswap-v4/contracts/libraries/CLHooks.sol`
2. `/hunts/_verified-contracts/sunswap-v4/contracts/libraries/Hooks.sol`
3. `/hunts/_verified-contracts/sunswap-v4/contracts/PoolManager.sol`

### Hook Call Flow

**Lines 125-161 in CLHooks.sol - beforeSwap function:**

```solidity
function beforeSwap(PoolKey memory key, ICLPoolManager.SwapParams memory params, bytes calldata hookData)
    internal
    returns (int256 amountToSwap, BeforeSwapDelta beforeSwapDelta, uint24 lpFeeOverride)
{
    ICLHooks hooks = ICLHooks(address(key.hooks));
    amountToSwap = params.amountSpecified;

    if (!key.parameters.shouldCall(HOOKS_BEFORE_SWAP_OFFSET, hooks)) {
        return (amountToSwap, beforeSwapDelta, lpFeeOverride);
    }

    bytes memory result = Hooks.callHook(hooks, abi.encodeCall(ICLHooks.beforeSwap, (msg.sender, key, params, hookData)));

    // A length of 96 bytes is required to return a bytes4, a 32 byte delta, and an LP fee
    if (result.length != 96) revert Hooks.InvalidHookResponse();  // LINE 141 - VALIDATION EXISTS
    
    // ... rest of function
    
    if (key.parameters.hasOffsetEnabled(HOOKS_BEFORE_SWAP_RETURNS_DELTA_OFFSET)) {
        beforeSwapDelta = BeforeSwapDelta.wrap(result.parseReturnDelta());
        int128 hookDeltaSpecified = beforeSwapDelta.getSpecifiedDelta();

        if (hookDeltaSpecified != 0) {
            bool exactInput = amountToSwap < 0;
            amountToSwap += hookDeltaSpecified;
            if (exactInput ? amountToSwap > 0 : amountToSwap < 0) revert Hooks.HookDeltaExceedsSwapAmount();  // LINE 158 - VALIDATION EXISTS
        }
    }
}
```

---

## FINDINGS

### Validation Present

**Line 141:** `if (result.length != 96) revert Hooks.InvalidHookResponse();`
- Checks hook return data is exactly 96 bytes
- This is a basic validation

**Line 158:** `if (exactInput ? amountToSwap > 0 : amountToSwap < 0) revert Hooks.HookDeltaExceedsSwapAmount();`
- Checks that hook delta doesn't flip swap direction
- Prevents extreme manipulation

### Still Need to Check

1. Is there validation on the MAGNITUDE of hookDelta?
2. Can hooks still drain pools with values within allowed range?
3. Need to read Hooks.sol for callHookWithReturnDelta logic

---

## Status: INCOMPLETE

Cannot confirm vulnerability yet. SunSwap V4 DOES have some validation (unlike claimed).

Need to check:
- Full validation logic in Hooks.sol
- Whether magnitude limits exist
- Actual exploitability

**Current confidence: 30% - Likely FALSE ALARM**

The agent may have been wrong about "no validation."
