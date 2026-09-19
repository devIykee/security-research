# INTAKE — TownSquare (Lending / Loop Vaults)

```
PROJECT_NAME   : TownSquare
X_HANDLE       : @TownSquarexyz
WEBSITE        : https://app.townsq.xyz
DOCS           : https://docs.townsq.xyz
CHAIN          : Monad
RPC            : https://rpc.monad.xyz
CHAIN_ID       : 143
EXPLORER       : https://monadvision.com
PRODUCT_TYPE   : lending/CDP + multi-strategy-vault (loop vaults + ERC-4626 TownSqVault)
BOUNTY/CONTEST : none on Immunefi/Cantina/Sherlock public bounty (Q3 2025 private Sherlock collaborative + Astrasec; docs say further audits unpublished)
NOTES          : Folks Finance-style hub/spoke money market. DefiLlama parent TVL ~$753k (Monad). Lending adapter audits field = 0. Loop vaults listed Aug 2026 (~$210k). Raised $17.57m. Researcher: deviykee
RESEARCHER     : deviykee
```

## Gate (24 Aug 2026)

| Criterion | Result |
|-----------|--------|
| Live chain | PASS. Monad RPC `https://rpc.monad.xyz` chainId 143, block 98800127 |
| Live TVL | PASS. DefiLlama parent ~$753k (lending ~$0.54m + loop vaults ~$0.21m). App-claimed $46m is inflated; adapter warns unproductive positions |
| Permissionless custody | PASS. User deposit/borrow/repay/withdraw via SDK (`@townsq/mm-sdk`) calling spoke/hub. Liquidation is permissionless (needs own loan). Loop vaults are ERC-style credit-pool deposits |
| Audits | 2 in Q3 2025 (Sherlock collaborative 2025-10-14 + Astrasec 2025-09-18). Docs: "Further audits will be published here." Hunt **post-audit new code** only: TownSqVault (Aug 2026), Yield-Vault / new-yield-vault (Jul–Aug 2026), loop vaults listed Aug 2026, VE |
| Public bounty | No live Immunefi/Cantina/H1 program found. Sherlock was a collaborative audit, not a public contest/bounty |
| Funded + reachable | PASS. $16.25m Series A (WLF, OKX Ventures, Amber, Animoca) + $1.32m public sale. X @TownSquarexyz, docs, GitHub org TowneSquare |
| Custom vs fork | Hub/spoke is Folks-style (`spokeOperations`, `loanManager`, message adapters). Custom: efficiency modes, RWA/stock-price oracles, ERC-4626 2-step vault, loop vaults |

## Hunt focus (post-audit new custody)

1. `TownSqVault` ERC-4626 2-step withdraw + mint-back on failed transfer (dual-ledger)
2. Loop vaults `0x6B0086…` / `0xcD1D2D…` (Native credit-pool pattern per DefiLlama)
3. `new-yield-vault` / `Yield-Vault` (updated 24 Aug 2026)
4. Efficiency-mode LTV + earnAUSD stock-price oracle (if live and post-audit)

## Stay out of

- `hunts/sat-rush/`, `hunts/enhanced/`, `hunts/base-dollar/`, `hunts/predict-fun/`
- Heavily audited Folks-identical hub/spoke unless live bytecode diffs from audited commit
