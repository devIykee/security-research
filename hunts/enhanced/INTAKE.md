# INTAKE — Enhanced

```
PROJECT_NAME   : Enhanced
X_HANDLE       : @enhanced_defi
WEBSITE        : https://enhanced.finance
DOCS           : https://paxg-vol.enhanced.finance/  (litepaper)
CHAIN          : Ethereum mainnet
CHAIN_ID       : 1
EXPLORER       : https://etherscan.io
PRODUCT_TYPE   : vault (structured product / covered-call option vault) + options engine (RFQ)
REPO           : Enhanced-Finance/contracts (public)
AUDIT          : Sherlock collaborative audit, May 26 - Jun 17 2026
                 leads: 1337web3, PeterSR, vinica_boy
                 audited commit 4e55bcfa33a0ebca729f81cb4f2af4eaaf548365
                 final commit  eb2167e14bfc9794ea392dadf39f7fe75a7f0777
                 results: 1 High, 7 Medium, 26 Low/Info (all addressed/ack'd)
BOUNTY/CONTEST : none published yet / discretionary
RESEARCHER     : deviykee
```

## Product model

- Depositors put PAXG into `EnhancedVault`. Vault writes bi-weekly European-style
  OTM covered calls, strike 3-7% above spot, sold via signed RFQ auction to
  institutional market makers.
- Premiums paid in stablecoin (USDC) to a **separately withdrawable premium balance**
  (novel: income without touching principal). Optional premium buyback -> compound
  into PAXG.
- Fee ~0.019% per 2-week epoch (~0.5% annualized).
- Core is a fork/derivative of Opyn Gamma Protocol (Otoken, Controller,
  MarginCalculator, MarginPool, Whitelist, Oracle) plus:
  - `EnhancedOptions` — RFQ execution gateway, EIP-712 signed quotes
  - `MMarket` — market-maker balance ledger
  - `EnhancedVault` — cycle-based vault, queued deposits/withdrawals
  - **physical settlement** (`isPhysicallySettled`) — NOT in upstream Opyn

## Deltas vs audited scope (hunt these first)

Files present at repo HEAD but NOT in the audit scope file list:

| File | Note |
|---|---|
| `src/core/libs/EnhancedOptionsTimelockLib.sol` | 341 lines, post-audit addition |
| `src/core/interfaces/IEnhancedOptionsTimelock.sol` | 51 lines, post-audit addition |

The audit added timelocks in response to L-3 / L-6 / L-11 (retroactive owner
params). New timelock code was never audited. Priority target.

## Known-weak areas flagged by the audit (check the fixes actually hold)

- H-1 physical-settlement writer ordering (shared oToken redemption balances)
- M-1 buyback not updating `totalDeposited` / `initialAmountTotal`
- M-3 ghost `initialAmountTotal` blocking re-entry after losses
- M-4 **ACKNOWLEDGED, not fixed**: fee not in EIP-712 type string -> operator can
  drain maker MMarket balance
- M-7 unbatched deferred-queue flush bricks cycle advancement
- L-3 / L-6 / L-11 **ACKNOWLEDGED**: unbounded owner params, no timelock (retroactive)
- L-5 **ACKNOWLEDGED**: full pause during Type-2 exercise window locks out buyers
- L-7 **ACKNOWLEDGED**: insolvent expired naked vault drains shared MarginPool
