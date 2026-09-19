# INTAKE — Cosmos EVM cluster (Mezo primary)

```
PROJECT_NAME   : Mezo (Cosmos EVM cluster)
WEBSITE        : https://mezo.org
DOCS           : https://mezo-org-documentation.mintlify.app
CHAIN          : Mezo mainnet (Cosmos EVM)
RPC            : https://mezo-mainnet.boar.network
CHAIN_ID       : 31612
EXPLORER       : https://explorer.mezo.org
KNOWN_ADDRS    : PortalProxy=0xAB13B8eecf5AA2460841d75da5d5D861fD5B8A39
                 TigrisRouter=0x16A76d3cd3C1e3CE843C6680d6B37E9116b5C706
                 PoolFactory=0x83FE469C636C4081b87bA5b3Ae9991c6Ed104248
                 VeBTC=0x7D807e9CE1ef73048FEe9A4214e75e894ea25914
                 MUSD=0xdD468A1DDc392dcdbEf6db6e34E89AA338F9F186
                 NttManager=0x7efb386675d75280D39Aae42964A6776DE0ee0bD
PRODUCT_TYPE   : other (Cosmos EVM L1 + Solidly-style DEX/gauges + native BTC bridge + MUSD CDP)
BOUNTY/CONTEST : discretionary (Mezo audits public; Immunefi TBD)
NOTES          : Cluster hunt. Priority: Mezo TVL then shared cosmos/evm staking+vesting precompile residual (Aug 2026 incident on KiiChain/TAC; MANTRA halt). Fork/eth_call only. Known incident is public; hunt residual + Mezo-specific value paths.
RESEARCHER     : deviykee
```

Workspace: `hunts/cosmos-evm/`

Recommended order: Mezo → shared cosmos/evm module → KiiChain/TAC → MANTRA → Initia/Saga/XRPL.

Stay out of: sat-rush, enhanced, base-dollar, predict-fun, townsquare-lending, weaker-audits in-progress.
