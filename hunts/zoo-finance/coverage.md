# Coverage — Zoo Finance

Coverage: 7/7 verified Zoo files (100% of Y). Core LvtVault impl + vtSwapHook **unverified**, not in Y. Path-scoped. Do not read this as a full audit.

Last updated: first-pass close (Steps 1–6)

| File | Read? | Paths traced | Notes |
|------|-------|--------------|-------|
| src/src/tokens/VestingToken.sol | yes | `mint`/`burn` → `onlyVault` | Sourcify exact vFIL |
| src/src/erc20/ZooERC20.sol | yes | `transfer`/`transferFrom`/`_mint`/`_burn` | self-transfer blocked; uint248 supply |
| src/src/interfaces/IVestingToken.sol | yes | interface only | — |
| src/src/thirdparty/filecoin/FilecoinSPNodes.sol | yes | `mint` → `onlyOwner` + id==1 | Sourcify exact ERC1155 gate |
| src/src/core/ProtocolOwner.sol | yes | `owner()` → `IProtocol.owner()` | shared owner |
| src/src/interfaces/IProtocol.sol | yes | role surface | protocol unverified |
| src/src/interfaces/IProtocolOwner.sol | yes | interface only | — |
| LvtVault impl `0xd3be…eade` | no | ABI + revert-reason only | unverified; 33/67 sels mapped |
| vtSwapHook `0xed20…3a88` | no | ABI + LP/quote probes | unverified; public add/removeLiquidity |

## Explicitly excluded

| Path / area | Reason |
|-------------|--------|
| lib/** (OZ ERC20/ERC1155/ReentrancyGuard) | vendored |
| FIL BEP20 proxy `0x0D8C…` | Binance-peg FIL |
| UniV3 pool `0x9f11…` | Uniswap, not Zoo |
| Uni v4 PoolManager | vendor; shared FIL inventory |
| Berachain B-Vault / L-Vault | dust TVL; Certik is B-Vault only |
| Sei / Story / Arb / Base LVT-LNT | same product family; not re-traced this pass |
