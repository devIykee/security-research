# Mezo mainnet addresses (chainId 31612)

Source: official docs + tigris README. Re-verified live 2026-08-25 via `cast codesize` on `https://mezo-mainnet.boar.network` (block 11382167).

## Earn / Tigris

| Role | Address | codesize (bytes) |
|------|---------|------------------|
| Router | `0x16A76d3cd3C1e3CE843C6680d6B37E9116b5C706` | 18209 |
| PoolFactory | `0x83FE469C636C4081b87bA5b3Ae9991c6Ed104248` | 3515 |
| VeBTC | `0x7D807e9CE1ef73048FEe9A4214e75e894ea25914` | 1159 (proxy-sized) |
| VeBTCVoter | `0x3A4a6919F70e5b0aA32401747C471eCfe2322C1b` | TBD |
| VeBTCRewardsDistributor | `0x535E01F948458E0b64F9dB2A01Da6F32E240140f` | TBD |
| VeBTCEpochGovernor | `0x1494102fa1b240c3844f02e0810002125fb5F054` | TBD |
| ChainFeeSplitter | `0xcb79aE130b0777993263D0cdb7890e6D9baBE117` | TBD |
| MUSD/BTC Pool | `0x52e604c44417233b6CcEDDDc0d640A405Caacefb` | 45 (clone) |
| MUSD/mUSDC Pool | `0xEd812AEc0Fecc8fD882Ac3eccC43f3aA80A6c356` | TBD |
| MUSD/mUSDT Pool | `0x10906a9E9215939561597b4C8e4b98F93c02031A` | TBD |

## Tokens / MUSD / NTT

| Role | Address |
|------|---------|
| MUSD | `0xdD468A1DDc392dcdbEf6db6e34E89AA338F9F186` |
| BTC (tBTC-style precompile) | `0x7b7C000000000000000000000000000000000000` |
| mUSDC | `0x04671C72Aab5AC02A03c1098314b1BB6B560c197` |
| mUSDT | `0xeB5a5d39dE4Ea42C2Aa6A57EcA2894376683bB8E` |
| mcbBTC | `0x6a7CD8E1384d49f502b4A4CE9aC9eb320835c5d7` |
| Ntt manager (Mezo) | `0x7efb386675d75280D39Aae42964A6776DE0ee0bD` |
| Wormhole Transceiver (Mezo) | `0x56E27f1A8425515FFD4BD76A254Ac1a5c0B66D71` |

## Ethereum-side Portal / native bridge

| Role | Address |
|------|---------|
| Portal Proxy | `0xAB13B8eecf5AA2460841d75da5d5D861fD5B8A39` |
| Portal Implementation | `0xD7097AF27b14e204564C057c636022fae346fE60` |
| BitcoinDepositor Proxy | `0x1D50D75933b7b7C8AD94dbfb748B5756E3889C24` |
| MezoBridge Proxy | `0xF6680EA3b480cA2b72D96ea13cCAF2cFd8e6908c` |
