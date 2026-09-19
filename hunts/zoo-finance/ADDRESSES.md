# Addresses — Zoo Finance

Live DefiLlama 2026-08-17: ~$17.95M. BSC $13.82M, Sei $4.11M, Arb $12k, Base $9.6k, Berachain $707, Story $0.

## BSC (chain 56) — Filecoin 540-Locked LVT

| Role | Address | Verified | Notes |
|------|---------|----------|-------|
| FIL (T) | `0x0D8Ce2A99Bb6e3B7Db580eD848240e4a0F9aE153` | BEP20 proxy | Binance-peg FIL |
| vFIL (VT) | `0x24ef95c39dfaa8f9a5adf58edf76c5b22c34ef46` | Sourcify exact `VestingToken` | supply ~21.77M |
| FilecoinSPNodes (deposit NFT) | `0xd7fc9ab355567af429fb5bb3b535eab4c7e48567` | Sourcify exact ERC1155 | id=1; mint `onlyOwner`; vault holds 1 |
| LvtVault proxy | `0xeBF1039d30D7A03E6F09d0815431DB339017d031` | ERC-1967 130b | FIL ~0.92; `aVT` 13.93M |
| LvtVault impl | `0xd3be6f86846b1949aa32f0c655fdd7d8c14feade` | **no** | UUPS 5.0.0; codesize 10377 |
| vtSwapHook (vFIL-FIL-LP) | `0xed202a7050ee856ba9f0d3cd5eabcab6b8a23a88` | **no** | public add/removeLiquidity |
| ZooProtocol | `0x170e0C91ffa71dc3c16d43f754b3AECe688470c8` | no | owner `0x7077…dfBd` |
| ProtocolSettings | `0x2f70e725553c8E3341e46CAa4e9B303E9d810fC9` | no | — |
| UniV3 FIL/vFIL 500 | `0x9f114D4BA253f1D229bfbdd9c7f85C74531b9c5a` | UniswapV3Pool | 239 FIL + 240 vFIL |
| UniV3 QuoterV2 | `0x78D78E420Da98ad378D7799bE8f4AF69033EB077` | vendor | adapter quote |
| Uni v4 PoolManager | `0x28e2Ea090877bF75740558f6BFB36A5ffeE9e9dF` | vendor | 0.82 vFIL |
| buybackPool | `0x38402aa01220a1d19edfe061760877a353728214` | 130b proxy | also a Story vault addr |
| owner EOA | `0x7077323c13af514629C57F89cb4542019402dfBd` | — | vault, hook, protocol, SP NFT |
| rewardsOperator | `0xE8f7C649037565ff4091466d6484b7E62336DE48` | — | `rewardsOperators()[0]` |
| VT deployer | `0x1e1840f1eB9d9b89f4B1F2ad469e31E9877b820D` | — | Sourcify |

## Sei (chain 1329) — SEI 360-Locked LVT (~$4.1M)

| Role | Address |
|------|---------|
| WSEI | `0xE30feDd158A2e3b13e9badaeABaFc5516e95e8C7` |
| VT | `0x92838ccdb9dceabc8e77415d73ecb06f8050cc5f` |
| vault | `0x5d5958f62ffc35a93c426c0d5fc55cd3dffc9e20` |
| vthook | `0x3362cb23043cb5e7c52711c5763c69fd513a3a88` |

Same LVT family. Not re-hunted this pass.

## Dust / skip

Arb Aethir LNT, Base Reppo, Story Verio, Berachain B-Vault. Adapter: `projects/zoofi-io/index.js`.
