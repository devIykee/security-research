# TownSquare live addresses (Monad, chainId 143)

Sources: DefiLlama adapter `projects/townsquare/index.js`, `projects/townsquare-vaults/index.js`, docs vault-setup.

## Hub / spoke (from TownSqVault docs)

| Role | Address |
|------|---------|
| spokeOperations | `0x63CB1CF5aCCbCC57e0cCa047bE9673EA5022b8DB` |
| spokeTokenOperations | `0xA457235B68606a7921b7c525D92e9592e793b4C0` |
| loanManager | `0xC4C20EFbEfA4Bde14091a3040d112cF981d8B2DB` |
| USDC assetHubPool | `0xdb4E67F878289A820046f46f6304fd6Ee1449281` |
| vault script owner | `0xa031f11d7CDF039eeF0e73E47Bd5B487f3659B65` |
| USDC (Monad) | `0x754704Bc059F8C67012fEd69BC8A327a5aafb603` |

## Lending pools (DefiLlama adapter)

| Pool | Underlying |
|------|------------|
| `0x106d0e2bff74b39d09636bdcd5d4189f24d91433` | native MON |
| `0xdb4e67f878289a820046f46f6304fd6ee1449281` | USDC |
| `0xf358f9e4ba7d210fde8c9a30522bb0063e15c4bb` | WMON |
| `0x7821ba4e39c86ac4bdd2482e853f9c7ba57d01d0` | USDT |
| `0x0394728ef18258ca21f782ce37ebf1a16799d7ef` | WETH |
| `0xd636d6ab7072483de6ddc067f9147f8c1e512f18` | WBTC |
| `0x7f5996865e952bd7892366712d319de59b9ecc6b` | AUSD |
| `0x3249df5ca0b825e7c3e7d84a4bb11c2eacd8c0f6` | USD1 |
| `0x09cd0233ad57bac4f916ca7aa08321b96effbaf2` | MUBOND |
| `0xaa3f243731d724f2195271a9c3f5c744f0d0b948` | AZND |
| `0x7d99267be583d46273803b2b1c5edb98bff6538d` | earnAUSD |
| `0xd2108dec68089646c3d4d95f01ea42ee1142e7f4` | shMON |
| `0xc0fda7f80e772ac3f85735f66ecb1ac964a033f2` | kintsu sMON |
| `0xfdd72592a657775249da1b013ac1371ccd45d885` | aprMON |
| `0x428bebf994c970656854eb66586583fe682cc1d3` | gMON |
| `0x4C79B2368d0FFa1BC7399ee0fB3569e220C3f52d` | sAUSD |
| `0x9f2Bc225892Eee4C2B579d4b7cB3a74859b5D622` | yzUSD |
| `0x8A0F894ec72c879b0f808c6d3FC1FBc7B130Cc69` | syzUSD |

enzoBTC pool excluded by DefiLlama (wash/inflation).

## Loop / credit vaults (DefiLlama townsquare-vaults)

| Chain | Vault | Note |
|-------|-------|------|
| Monad | `0x6B00868e2D1385b3804127827bBaB461d3E697E7` | fromBlock 85979242 |
| Monad | `0xcD1D2D602C3e7394515DaAe96e4FFe16DE71e5B4` | curated by Native, fromBlock 70146973 |
| Base | `0xe7aFdA918134eAA42607ec3E5463c955A02F3d70` | dust TVL |
