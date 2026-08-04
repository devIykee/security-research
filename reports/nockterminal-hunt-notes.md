# Nock Terminal (#5) - hunt notes (no High confirmed)

**Researcher:** deviykee  
**Date:** 2026-07-20  
**Status:** Full surface mapped. No permissionless High proven. No mainnet exploit attempted (fork / eth_call / local read only).

---

## What this means in plain language (read this first)

Nock Terminal is mainly a **screener / guided launcher**, not a bonding-curve vault that holds buyer ETH until graduation.

When you "launch" through Nock, your **wallet** signs a multi-step flow:

1. Pay a small 0.002 ETH fee to Nock's wallet  
2. Deploy a plain fixed-supply ERC-20 yourself  
3. Initialize a Uniswap **v4** pool (shared PoolManager)  
4. Add **single-sided token** liquidity (no ETH raise held on a pad contract)  
5. Try to send the LP position NFT to the dead address  
6. Register the launch in Nock's off-chain index  

Because **there is no shared factory holding the raise**, the classic Highs we found elsewhere (V3 migration pool squat; V2 pair pollution freeze) **do not apply** the same way. Buyers are not depositing into a pad-controlled curve that later migrates their ETH at a pad-chosen price.

Residual risks are mostly **product / trust / UX** (listing can succeed while LP burn is still pending; fee is an EOA payment; tokens are standard ERC-20 with no extra pad custody).

---

## INTAKE (known only)

```
PROJECT_NAME   : Nock Terminal
X_HANDLE       : @NockTerminal
WEBSITE        : https://nockterminal.com/launch
CHAIN          : Robinhood Chain
RPC            : https://rpc.mainnet.chain.robinhood.com
CHAIN_ID       : 4663
EXPLORER       : https://robinhoodchain.blockscout.com
KNOWN_ADDRS    :
  fee_and_demo_launcher_eoa=0x06aD94da5D6cEe869A7754eB5A68d046c897dAc5
  univ4_pool_manager=0x8366a39CC670B4001A1121B8F6A443A643e40951
  univ4_position_manager=0x58daec3116aae6D93017bAAea7749052E8a04fA7
  sample_token_NOCT=0xba513a5db53cfc025013107beb7903247844bd06
PRODUCT_TYPE   : launchpad (guided V4 single-sided; no shared factory)
BOUNTY/CONTEST : none / discretionary
RESEARCHER     : deviykee
```

Public registry: https://nockterminal.com/api/public/nock-launches.json  
Methodology write-up: https://nockterminal.com/research/nock-robinhood-chain-launch-registry  
Founder / operator X: @NFTAlphaSociety (listed in NockTerminal bio)

---

## Architecture

| Piece | Role | Notes |
|-------|------|--------|
| Creator wallet (EOA) | Pays gas, deploys token, inits pool, mints LP, may transfer LP | Demo launches use `0x06aD94…dAc5` |
| Fee payment | 0.002 ETH plain transfer to Nock wallet | Not a privileged vault contract |
| ERC-20 token | Fixed 1e9 * 1e18 supply; **standard ERC-20 selectors only** | Unverified sample; no `owner()` |
| Uniswap v4 PoolManager | Shared RH deployment | Official infra, not Nock-owned |
| PositionManager | Shared RH deployment | LP NFT mint + transfer |
| Off-chain registry | JSON + site listing | Explicitly can list incomplete evidence |

Sample launch evidence (NOCT): deploy + pool `initialize` + `modifyLiquidities` + LP `transferFrom` to `dEaD` all present on Blockscout.

Token selectors on sample `0xba51…bd06`:

`name`, `symbol`, `decimals`, `totalSupply`, `balanceOf`, `transfer`, `approve`, `transferFrom`, `allowance` only. No mint/pause/blacklist surface in the runtime selector set.

---

## Attack questions checked (launchpad + audit routing)

Loaded: duke-web3-bug-hunting, evm-audit-master routing (general, precision-math, defi-amm, erc20, access-control, dos, flashloans, chain-specific), plus web3-bug-classes / web3-grep-arsenal surface thinking.

| Question | Result |
|----------|--------|
| Permissionless drain of pad-held raise? | **N/A** - no raise held on a Nock factory |
| V3 `createAndInitializePoolIfNecessary` + zero mins squat? | **N/A** - flow is V4 + wallet-driven |
| V2 pair pollution freeze? | **N/A** - no V2 bonding factory |
| Missing auth on admin of a pad vault? | **N/A** - no pad vault; fee is EOA |
| LP "burn" incomplete but UI lists as launched? | **Yes product risk** - registry already flags incomplete LP transfer (e.g. TNOCK) |
| Registration without full tx evidence? | **Yes product risk** - "tes" / incomplete rows with null txs |

---

## Findings (honest)

| ID | Severity | Title | Status |
|----|----------|--------|--------|
| NT-1 | Info | No shared Nock factory; launches are multi-tx wallet flows against Uniswap v4 | Confirmed on registry + live txs |
| NT-2 | Info / Trust | Launch fee is EOA transfer, not a verified fee contract | Confirmed |
| NT-3 | Info / UX | Listing / registration can complete while LP dead-address transfer is still pending or missing | First-party documented |
| NT-4 | - | Permissionless High fund theft on Nock custom contracts | **Not found** |

**No High / Critical claimed.** Bound: this is a thin custom surface (EOA fee + indexer + guided Uniswap calls). Residual scam risk is creator-side token behavior after launch (normal for any open launcher), not a Nock factory bug.

---

## Why known High root causes do not port

1. **V3 migration pool squat** needs a pad that *holds* raise ETH and later mints LP with `amount0Min/amount1Min = 0` and no `slot0` check. Nock never holds the raise; liquidity is single-sided token from the creator wallet.  
2. **V2 pair pollution** needs a V2 pair + weak pollution check + freeze on `readyToGraduate`. Not present.

---

## Sources / evidence on disk

- Live registry snapshot: `https://nockterminal.com/api/public/nock-launches.json`  
- Notes path: `reports/NockTerminal-hunt-notes.md`  
- Sample deploys traced via Blockscout API v2 for `0xba51…bd06` and creator `0x06aD94…dAc5`

---

## Optional follow-ups (not blocking)

1. Pull full token creation bytecode from one deploy and compare across launches (bytecode template backdoors).  
2. Review Nock Telegram bot (`NockTradeBot`) off-chain permissions separately (out of SC scope).  
3. If Nock later ships a **bonding curve / factory that custodies ETH**, re-run full migration hunt.

---

deviykee
