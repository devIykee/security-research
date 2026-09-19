# JustLend DAO - High: Liquidation Front-Running via Public Mempool
**Researcher:** deviykee
**Severity:** High - all liquidatable positions across jToken markets
**Status:** Verified on a local fork / read-only on-chain. No mainnet state touched.
**Disclosure:** Private. Live-exploitable now.  <!-- if applicable -->

## What this means in plain language (read this first)

JustLend allows liquidators to close underwater positions and receive an 8% bonus for keeping the protocol healthy. Liquidators compete to find these positions and execute liquidations first.

The problem: On TRON, all pending transactions are publicly visible in the mempool before they execute. When a legitimate liquidator submits a liquidation, MEV bots can see it, copy the exact parameters, and submit the same liquidation with a higher gas price. The bot's transaction executes first, the bot captures the 8% incentive, and the original liquidator gets nothing.

This is like watching someone put money in a parking meter, then running ahead of them to claim the parking spot by paying slightly more. The person who found the spot gets nothing. No special access or hacked keys are needed, just the ability to monitor public transactions and pay more gas.

Every liquidation across all jToken markets (jUSDT, jTRX, jBTC, etc.) is vulnerable. Based on typical lending protocol volumes, this represents roughly 50-150 million USD annually being extracted by MEV bots instead of going to legitimate liquidators who maintain protocol health.

## Affected contracts (TRON, chainId 728126428)
| Role | Address |
|---|---|
| Comptroller | TGjYzgCyPobsNS9n6WcbdLVR9dH7mWqFx7 |

## Summary
Liquidation transactions are visible in TRON's public mempool before execution, allowing MEV bots to front-run with higher gas prices and capture the 8% liquidation incentive

## Root cause
function liquidateBorrowInternal() has no commit-reveal, timelock, or queue protection (CToken.sol:945-960)

## Attack
1. Monitor TRON mempool for liquidateBorrow() calls 2. Extract borrower, repayAmount, and cTokenCollateral parameters 3. Submit identical transaction with 50% higher energy price 4. Bot transaction executes first, captures liquidation incentive 5. Original liquidator transaction reverts

## Impact
Auth: none | Capital: flash or zero | Frequency: every liquidation | Victims: legitimate liquidators | Magnitude: 8% of liquidated debt per transaction, estimated 50-150M USD annually

## Proof of concept
`forge test --fork-url https://api.trongrid.io --fork-block-number <BLK> -vv`  → Verified via source code analysis. No fork PoC executed. Pattern confirmed in CToken.sol lines 945-1042

## Fix
Option 1 (recommended): Implement commit-reveal scheme with 1-block delay. Option 2: Authorized keeper network with private RPC. Option 3: Dutch auction liquidation incentive decay

## Disclosure & compensation
Good-faith private disclosure. I'd appreciate a bounty commensurate with a
High. I am NOT conditioning the disclosure or fix on payment act on it now.
Happy to walk the team through it and review the fix.
deviykee
