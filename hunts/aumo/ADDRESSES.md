# Aumo — addresses (private hunt)

## Intake

| Field | Value |
|-------|--------|
| PROJECT | Aumo |
| X | @aumofinance |
| WEB | https://www.aumo.finance/ |
| CHAIN | X Layer |
| CHAIN_ID | 196 |
| RPC | https://rpc.xlayer.tech |
| PRODUCT | ERC-4626 multi-depositor vault + agent (RWA/Aave) |
| BOUNTY | none / discretionary |
| RESEARCHER | deviykee |

## Status (2026-08-10)

- **Mainnet pool not deployed** in repo/web config (`NEXT_PUBLIC_POOL` / `venues.mainnet.json` still zero).
- Live product path points at **X Layer testnet** pool.

## Testnet (chainId 1952)

| Role | Address |
|------|---------|
| AumoPool | `0x057Caa4fC699bF830b8AE2E3B1f5D0D75eABd626` |
| AumoVault | `0x52Fc89beD432e068a0a837065fbCFaDb3573A55e` |
| TestUSDT0 | `0xFc440733d882f28012B190b11Bbec56b44508448` |
| MockYield | `0x05398D5289a8ed29629362290cf7954430a95702` |
| StableVault | `0xD831D3e472c4E39f43C6de60a2b5954a8FB54A24` |
| owner/agent (note) | `0x197ED5B2313fA482EC271861360E839A8eF75731` |

## Mainnet reference (X Layer 196, not Aumo contracts)

| Role | Address |
|------|---------|
| USDT0 | `0x779Ded0c9e1022225f8E0630b35a9b54bE713736` |
| Aave v3 Pool | `0xE3F3Caefdd7180F884c01E57f65Df979Af84f116` |
| aXlrUSDT0 | `0xF356ae412dB5df43BD3a10746f7ad4e1C4De4297` |
| USDG | `0x4ae46a509F6b1D9056937BA4500cb143933D2dc8` |
| aUSDG | `0x228765a3C18065C923F23a0CCb6c7cEFB3eA2223` |
| Uni SwapRouter02 | `0x4f0C28f5926AFDA16bf2506D5D9e57Ea190f9bcA` |

## Source

- GitHub: https://github.com/cryptoduke01/aumo
- Local clone: `hunts/aumo/repo/`
