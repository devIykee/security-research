# INTAKE - Ellipse Hunt

```
PROJECT_NAME   : Ellipse
X_HANDLE       : @ellipsefun
WEBSITE        : https://ellipse.fun/
DOCS           : https://ellipse.fun/docs
SECURITY_EMAIL : (to be determined in Step 10A)
DISCLOSURE     : (to be determined - check for bounty program)
CHAIN          : Arc (Circle's USDC-native L1)
RPC            : https://rpc.mainnet.arc.io
CHAIN_ID       : 5042
EXPLORER       : https://arcscan.app (Blockscout)
KNOWN_ADDRS    : ELLIPSE=0x86F7424C3e1EBb3F42e1E687468e36D5f2A1222E
PRODUCT_TYPE   : multi-function (DEX/AMM + Bridge + Launchpad)
BOUNTY/CONTEST : unknown (to be determined)
NOTES          : Real-world asset bridge platform on Arc. TVL ~$75.94K. Launched tokens via bonding curve model. Uses Uniswap v3 pools. Dinari integration for tokenized stocks.
RESEARCHER     : deviykee
```

## Hunt Status
- Step 1: PASS - Chain confirmed (chainId=5042, block=21636886)
- Step 2: In progress - Locating core contracts

## Core Contracts Identified (Step 2)

**Launchpad (primary target):**
- Launchpad V6 (current): 0x66bdc0803807f8a62763943fb2dd584ed9fb9c16
- Launch hook (V6): 0x143d72d4bd0f0e1a6c6fd4f2f671a45d9e003a88
- Buyback reserve (V6): 0xea51ef0975a238cbbbc9edad537ec4be4f6ede7a
- Pair registry: 0x1dfa98d6dc2ab6e452c09c1c7c706b5f4a3f623f

**Bridge:**
- Fast bridge router (Arc): 0x4b6fa68debb9592d0572f424baf4bfc24d1327af

**DEX/AMM:**
- Uniswap v3 factory: 0xf0db7b58379503491d857db50ac9ece64c653918
- Position manager: 0x39654a85a4c05127f5fd6ed22caec077a0fb1377

**Legacy versions:** V5, V4, V3, V2, V1 launchpads (historical only)
