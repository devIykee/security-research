# Banana Gun Bug Hunt - INTAKE

```
PROJECT_NAME   : Banana Gun
X_HANDLE       : @BananaGunBot
WEBSITE        : https://pro.bananagun.io/
DOCS           : https://docs.bananagun.io/
SECURITY_EMAIL : (to be determined in Step 10A)
DISCLOSURE     : discretionary
CHAIN          : Multi-chain (Ethereum, Base, BSC, Blast, Sonic, Unichain)
RPC            : (multiple - to be determined per chain)
CHAIN_ID       : 1 (Ethereum), 8453 (Base), 56 (BSC), 81457 (Blast), etc.
EXPLORER       : (per chain)
KNOWN_ADDRS    : 
  - Ethereum: 0x3328f7f4a1d1c57c35df56bbf0c9dcafca309c49
  - Base: 0x1fba6b0bbae2b74586fba407fb45bd4788b7b130
  - BSC: 0x461efe0100be0682545972ebfc8b4a13253bd602
  - Blast: 0x461efe0100be0682545972ebfc8b4a13253bd602
  - Sonic: 0xdc13700db7f7cda382e10dba643574abded4fd5b
  - Unichain: 0x461efe0100be0682545972ebfc8b4a13253bd602
PRODUCT_TYPE   : Trading bot / MEV protection / DeFi execution layer
BOUNTY/CONTEST : discretionary / none known
NOTES          : 
  - Telegram trading bot with web interface
  - Processes $16B+ volume
  - Multi-chain support (6+ chains)
  - MEV protection features
  - Revenue sharing model (40% to $BANANA holders)
RESEARCHER     : deviykee
```

## Sources
- [DefiLlama Dimension Adapters](https://github.com/DefiLlama/dimension-adapters/blob/master/fees/banana-gun-trading.ts)
- [Banana Gun Blog](https://blog.bananagun.io/)
- [Learn Bybit - Banana Gun](https://learn.bybit.com/defi/what-is-banana-gun/)
- [Pro Terminal](https://pro.bananagun.io/)

## Hunt Strategy
Starting with Ethereum mainnet as primary target, then Base (L2 with high activity).
Focus areas:
1. Trading execution contracts
2. Fee collection mechanisms
3. MEV protection logic
4. Multi-sig/access controls
5. Fund custody (if any)
