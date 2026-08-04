# Bankr — hunt notes (no High / weak SC surface)

**Researcher:** deviykee  
**Date:** 2026-07-21  
**Severity:** Notes — no permissionless SC High claimed  
**Product:** AI trading agent / terminal (https://bankr.bot) · $BNKR · Val#2

## Ground truth

- RH Chain enabled (`chainId` 4663) in frontend + `api.bankr.bot/chains`.
- RH config: WETH `0x0Bd7…AD73`, USDC `0x5fc5…d168` only — **no Bankr factory/vault/escrow address** in chain config.
- Token launches: docs + dashboard stats route through **Clanker** and **Doppler** (not a Bankr-owned launchpad factory). UI: `claimClankerFees`, `api.bankr.bot/user/clankers`, `public/doppler/*`.
- $BNKR on RH: `0x178E54df3D091EE4D0B2534742eF9e3692b76526` (BankrCoin); created via CREATE2 factory `0x4e59…956C`.
- Volume/fees largely off-protocol (agent wallets + external pads).

## Attack surface assessment

| Surface | Finding |
|---------|---------|
| Custom RH pad factory | **Not found** in app bundle |
| On-chain raise / migrate | **N/A** (uses Clanker/Doppler) |
| Permissionless drain of protocol TVL | No dedicated custody contract located |

Residual: user-wallet / agent-API security, Clanker fee claim flows, Doppler v4 claim builders — out of classic launchpad High classes unless a Bankr-controlled module appears.

## Gate

Playbook: no verifiable core custody contract → stop deep SC dive. Re-open if they ship a RH factory / vault with funds.

deviykee
