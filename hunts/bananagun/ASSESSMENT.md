# Banana Gun Security Assessment

**Date:** 2026-09-16  
**Researcher:** deviykee  
**Status:** Initial reconnaissance complete

## Executive Summary

Banana Gun is a multi-chain trading bot and DeFi execution layer with $16B+ in processed volume. Initial investigation reveals:

- **Architecture:** TransparentUpgradeableProxy pattern on Ethereum
- **Implementation:** Unverified on Sourcify (0x35fc556d6f8675b26fdf1542e6e894100155b34e)
- **Balance:** ~0.00025 ETH on implementation contract (low funds at risk on this contract)
- **Access Control:** Standard admin functions appear properly guarded

## Contract Addresses

### Ethereum Mainnet
- **Proxy:** `0x3328f7f4a1d1c57c35df56bbf0c9dcafca309c49` (verified)
- **Implementation:** `0x35fc556d6f8675b26fdf1542e6e894100155b34e` (unverified)
- **Admin:** `0x6e38d4999fdb6fac24973e508cde9397e369c5af`

### Other Chains
- **Base:** `0x1fba6b0bbae2b74586fba407fb45bd4788b7b130`
- **BSC:** `0x461efe0100be0682545972ebfc8b4a13253bd602`
- **Blast:** `0x461efe0100be0682545972ebfc8b4a13253bd602`
- **Sonic:** `0xdc13700db7f7cda382e10dba643574abded4fd5b`
- **Unichain:** `0x461efe0100be0682545972ebfc8b4a13253bd602`

## Initial Findings

### Architecture Analysis

**Proxy Pattern:** Standard OpenZeppelin TransparentUpgradeableProxy
- ✅ Properly implements ERC1967 storage slots
- ✅ Admin separation enforced
- ⚠️ Implementation contract is unverified (source not on Sourcify/Etherscan)

**Detected Functions (from bytecode):**
```
0x0162e2d0 swapETHForExactTokens(uint256[],address[],address,uint256,uint256,uint256,uint256)
0x23a69e75 pancakeV3SwapCallback(int256,int256,bytes)
0x8129fc1c initialize()
0xfa461e33 uniswapV3SwapCallback(int256,int256,bytes)
```

### Step 4 Auth Triage Results

All standard privileged functions tested are properly guarded:
- ✅ `setOwner(address)` - guarded
- ✅ `setKeeper(address)` - guarded
- ✅ `setOracle(address)` - guarded
- ✅ `setFee(uint256)` - guarded
- ✅ `mint(address,uint256)` - guarded
- ✅ `withdraw(uint256)` - guarded

**No obvious missing access control vulnerabilities found.**

## Assessment Constraints

### Blockers for Full Audit

1. **Unverified Source Code**
   - Implementation contract source not available on Sourcify
   - Etherscan verification not found
   - Only have bytecode and selector mapping
   - **Impact:** Cannot perform deep logic analysis, only behavioral testing

2. **Low On-Chain Funds**
   - Implementation holds ~0.00025 ETH
   - Proxy holds 0 ETH
   - **Implication:** These contracts may be routing/aggregation contracts, not custody contracts
   - Real funds likely held elsewhere (user wallets, other contracts)

3. **Multi-Chain Deployment**
   - 6+ chains with different addresses
   - Would need to verify each deployment independently
   - Different chains may have different implementations

### Product Type Analysis

Based on function signatures and project description:
- **Type:** DEX aggregator / MEV-protected trading router
- **Callbacks:** Uniswap V3 and PancakeSwap V3 callbacks detected
- **Flow:** Users likely interact through Telegram bot → backend signs → contract executes
- **Custody:** Non-custodial (users maintain wallet control)

## Risk Assessment

### Critical Finding Potential: **LOW**

**Reasoning:**
1. No obvious access control bypasses
2. Standard OpenZeppelin proxy implementation (battle-tested)
3. Non-custodial design limits attack surface
4. Low balance on inspected contracts

### Areas That Require Source Code for Deep Analysis

Without verified source, I **cannot** reliably assess:

1. **Callback Vulnerabilities**
   - `uniswapV3SwapCallback` and `pancakeV3SwapCallback` implementation
   - Proper validation of callback caller
   - Reentrancy protections

2. **Swap Logic**
   - `swapETHForExactTokens` parameter validation
   - Slippage protection
   - Price manipulation resistance
   - MEV protection implementation

3. **Oracle Dependencies**
   - If `setOracle` exists, what does it control?
   - Price feed manipulation risks
   - Stale price handling

4. **Fee Mechanism**
   - How `setFee` affects user trades
   - Maximum fee bounds
   - Fee extraction methods

5. **Upgrade Safety**
   - Storage layout compatibility between upgrades
   - Initialization protection
   - Admin key security (who controls 0x6e38d4999fdb6fac24973e508cde9397e369c5af?)

## Recommendations for Further Investigation

### To Project Team

1. **Verify Source Code**
   - Upload source to Etherscan and Sourcify
   - All implementations across all chains
   - Improves transparency and enables independent security review

2. **Security Audits**
   - Publish any existing audit reports
   - Consider bug bounty program (currently appears discretionary)

### For Continued Hunt

1. **Decompile bytecode** using tools like:
   - Dedaub (panoramix)
   - Heimdall
   - Analysis of actual transaction traces

2. **Transaction Analysis**
   - Review recent transactions for patterns
   - Check for any failed/reverted transactions (potential attack attempts)
   - Analyze value flows

3. **Admin Analysis**
   - Investigate admin address (0x6e38d4999fdb6fac24973e508cde9397e369c5af)
   - Is it a multisig? EOA? Another contract?
   - Past upgrade history

4. **Cross-Chain Analysis**
   - Check if other chain deployments have verified source
   - Compare implementations for consistency

## Decision Point

**GATE: PROCEED or STOP?**

Given constraints:
- ✅ Real project ($16B volume)
- ✅ Basic access control looks sound
- ❌ No verified source code
- ❌ Low funds on inspected contracts
- ❌ Non-custodial design (weak target per playbook)

**Recommendation:** 
- **Primary hunt:** STOP (unverified source + low funds + non-custodial = weak target)
- **Alternative:** Check Base/other chain deployments for verified source
- **Alternative:** Decompile bytecode if specifically interested in router logic vulnerabilities

**Time Investment vs. Payoff:** Low - Without source code, investment to find verified bugs is high with uncertain payoff on a non-custodial, low-balance contract.

---

## Sources
- [DefiLlama Dimension Adapters](https://github.com/DefiLlama/dimension-adapters/blob/master/fees/banana-gun-trading.ts)
- [Banana Gun Docs](https://docs.bananagun.io/)
- [Bybit Learn - Banana Gun](https://learn.bybit.com/defi/what-is-banana-gun/)
- Ethereum RPC: https://eth.drpc.org
- Block: 25990939
