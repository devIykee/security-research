# Stable Chain ecosystem hunt — INTAKE (Iyke lead)

```
PROJECT_NAME   : Stable / StableEarn (+ ecosystem)
X_HANDLE       : @Stable
WEBSITE        : https://app.stable.xyz / https://stable.xyz
DOCS           : https://docs.stable.xyz
CHAIN          : Stable Mainnet
RPC            : https://rpc.stable.xyz
CHAIN_ID       : 988
EXPLORER       : https://stablescan.xyz
KNOWN_ADDRS    : see map below
PRODUCT_TYPE   : vault (StableEarn Morpho V2) + RWA collateral + DEX + OFT bridge
BOUNTY/CONTEST : none / discretionary (verify)
RESEARCHER     : deviykee
```

## Target priority (token-efficient)

| Priority | Target | Why | Hunt status |
|---|---|---|---|
| P0 | **StableEarn** Morpho VaultV2 | ~$30.4M TVL, live yield product | Mapped; no perm-less Critical yet |
| P0 | **Morpho Blue markets** (thBILL, sthUSD collaterals) | Supplies StableEarn; oracle/RWA risk | Markets + oracles identified |
| P1 | **USDT0 dual-balance** footguns | Documented non-EVM behavior breaks assumptions | Documented; Morpho uses ERC20 path (likely OK) |
| P1 | **Theo thBILL / sthUSD** | Custom tokens, owner-gated | Surface only |
| P2 | Uniswap V3/V2 on Stable | Canonical deploy; low novel surface | Addresses only |
| P2 | USDT0 OFT / LiFi | Bridge complexity, external audit likely | Addresses only |
| P3 | Morpho / Gauntlet / Concrete core | Battle-tested partners | Defer unless custom Stable adapters |

## Core address map (mainnet 988)

| Role | Address |
|---|---|
| USDT0 (native gas + ERC20) | `0x779Ded0c9e1022225f8E0630b35a9b54bE713736` |
| StableEarn VaultV2 | `0xb7Df8db22A5DBBFA9ebeb94b3910aec6a4f05c08` |
| Adapter registry | `0xCe93fcB2849EB886F1e81d45D2747dF803f843C3` |
| MorphoBlue adapter | `0x595727fF23c47F5a555AAe7604B653D97ebD1bEe` |
| Morpho Blue | `0xa40103088A899514E3fe474cD3cc5bf811b1102e` |
| Adapter factory | `0x9282DBa3d1788f4f02B5DdFc4fc5985e70197620` |
| thBILL collateral | `0xfDD22Ce6D1F66bc0Ec89b20BF16CcB6670F55A5a` |
| sthUSD collateral | `0xd1dB209087516883Ec705CFEB99e80BB6032d540` |
| Oracle thBILL | `0x4fc5FcBF3Cf6e9791115A39a19f60Bacc27b526F` → feed `0x7532df…` |
| Oracle sthUSD | `0xD1493f70eE808cb056Dd71aC1EA0CdE82055254c` → feed `0xb81131…` |
| IRM (shared) | `0x41e846FC8108b8527C1D4EDB4c9564E56442940f` |
| Vault owner | `0x5a4E19842e09000a582c20A4f524C26Fb48Dd4D0` |
| Curator + allocator | `0x9E33faAE38ff641094fa68c65c2cE600b3410585` |
| Fee recipient | `0x2F50825411455178534d96071Ea35c2726e7a333` |
| Uniswap V3 factory | `0x88F0a512eF09175D456bc9547f914f48C013E4aA` |
| SwapRouter02 | `0x32eaf9B5d5F2CD7361c5012890C943D7de84C22a` |
| Universal Router | `0x5Be52b52f3d1dbC324d2959637471a4208626144` |
| LiFi Diamond | `0x026F252016A7C47CDEf1F05a3Fc9E20C92a49C37` |
| USDT0 OApp | `0xedaba024be4d87974d5aB11C6Dd586963CcCB027` |
| Reserve (fractional recon) | `0x5113954bbC0eD721F1C68671EBa3d91e9e9bF7b5` |
