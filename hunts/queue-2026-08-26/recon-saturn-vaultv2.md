# RECON: Saturn VaultV2 deployments (Ethereum mainnet)

Date: 2026-08-26 · Mode: RECON ONLY (read-only RPC + public APIs) · Status: COMPLETE

## Target identification

Known ctor pairs → deployed addresses (constructor args verified via Blockscout
`/api/v2/smart-contracts/{addr}` `constructor_args`):

### Pair 2: (owner=0xC56EA16EA06B0a6A7b3B03B2f48751e549bE40fD, asset=USDC) → FOUND
- **satUSDC ("Saturn USDC") = `0xAbe418cc8c06D265E4EB009C02eA4B265eCA7240`**
- Verified ctor args: `0000…c56ea16ea06b0a6a7b3b03b2f48751e549be40fd` +
  `0000…a0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48` — exact match.
- On-chain (cast @ ethereum.publicnode.com):
  - `asset()` = USDC ✓, `symbol()` = `satUSDC`, `name()` = "Saturn USDC"
  - `owner()` now = `0xEe7E9bb21D5589BF657b94083dB2fA349a3918C8` (Hyperithm ops;
    ownership transferred post-deploy from ctor's 0xC56E…40fD)
  - `curator()` = `0x75178137D3B4B9A0F771E0e149b00fB8167BA325` (Hyperithm curator)
  - `totalAssets()` = `1433552309731` (6 dec) ≈ **$1.43M** → MATERIAL TVL (>$1M)
  - Morpho API: netApy ≈ 9.63%, created ts 1780634903 (~Jun 2026), liquidity ~$4 idle
- Listed on Morpho app: https://app.morpho.org/ethereum/vault/0xAbe418cc8c06D265E4EB009C02eA4B265eCA7240/saturn-usdc

### Pair 1: (owner=0x415ca88b148CD7a3bbAd61788A9b90F2a788EEc7, asset=0x00000000eFE302BEAA2b3e6e1b18d08D69a9012a) → FOUND
- Asset token identified: **AUSD** (symbol AUSD, name AUSD, 6 dec,
  totalSupply 68,751.31 ≈ $68.75k) — Agora's stablecoin, vanity `0x00000000eFE3…` address.
- **fAUSDe ("Flowdesk AUSD Equity Strategy") = `0xF7c3A485ED9Ec23d22686D03440EBC6e3C87920F`**
- Verified ctor args: `…415ca88b148cd7a3bbad61788a9b90f2a788eec7` + `…00000000efe302beaa2b3e6e1b18d08d69a9012a` — exact match.
- On-chain: `symbol()` = fAUSDe, `totalAssets()` = **0** — EMPTY vault, no TVL.
- No adapters registered in Morpho index.

## Related same-deployer vaults (creator `0xA1D94F746dEfa1928926b84fB2596c06926C0405`)
- `fdstp` = `0xA8bE6eB833734Bd97D9118ee76beb116ed8d9475` (owner=curator=0x415c…EEc7,
  asset AUSD): totalAssets = 3.01 AUSD ($3) — dust. Adapter: MorphoMarketV1
  `0xC178DD57d298cA835746Cc510B633226400B87F1`. Ctor args not exposed by explorer.
- Hyperithm family (same curator 0x7517…A325): hyperUSDCc `0x0229dB3921dE71CFa43Cfe9fb6A87b403647A9ae`
  ($5.4k), hyperUSDCa `0x093272C07700d3cA5301C3Bf9B3A392624179E2F` ($6.73M),
  plus ETH Apex/USDT/cbBTC and Monad instances. Monad satUSDC:
  `0x75753e494e5e374C52E1d84fc04EB14B10F2C079` (chain 143).

## Saturn STRC vault product → NOT FOUND (as standalone VaultV2)
- No VaultV2 or ERC4626 named "STRC" on Ethereum mainnet (Morpho index + DeFiLlama + app bundle).
- STRC exposure lives INSIDE sUSDat (`0xD166337499E176bbC38a1FBd113Ab144e5bd2Df7`,
  ERC4626, TVL ≈ $80.57M per DeFiLlama pool 47e72726) via:
  - Saturn STRC Price Feed / StrcPriceOracle: `0x5f7eCD0D045c393da6cb6c933c671AC305A871BF`
    (defaultAdmin 0x610182581C93687Ca03F4a8E7f124f8cEC616820 = Saturn Admin Fireblocks ⅔ MPC)
  - Chainlink STRC feed: `0xf4d2076277fff631EFC4385Ab36b1f7734218d23`
- App JS bundle contains sUSDat ABI (strcOracle, convertFromStrc, strcPurchasePrice…) but no
  satSTRC product key. Docs Key Addresses page lists no STRC vault.

## Adapters / gates visible
- satUSDC adapter: **MorphoMarketV1 `0xc231DA3F9c5F0Bb372191816636F3B5505167b5D`**
  (supplies USDC into Morpho Blue markets collateralized by Saturn tokens per Morpho UI blurb).
- fdstp adapter: MorphoMarketV1 `0xC178DD57d298cA835746Cc510B633226400B87F1`.
- fAUSDe: none. Gates: not exposed via API/app config (query returned no gate entities).

## Methods used (cheapest-first)
1. Websearch → Morpho UI page for Saturn USDC vault (address directly in URL).
2. Gitbook docs `llms.txt` → Key Addresses page (core tokens, oracle, admin wallets).
3. app.saturn.credit Next.js chunks (42 files) → token/product address map incl. AUSD.
4. DeFiLlama yields API filtered server-side (python) → saturn SUSDAT $80.57M pool.
5. Morpho blue-api GraphQL `vaultV2s` filters (ownerAddress_in) → full candidate list.
6. Blockscout v2 `constructor_args` → definitive ctor-pair ↔ address mapping.
7. cast call verification of asset/owner/symbol/totalAssets on mainnet RPC.

## Audit-relevant notes
- Saturn deployer EOA/factory: `0xA1D94F746dEfa1928926b84fB2596c06926C0405`.
- Owner role of satUSDC handed from Saturn signer (0xC56E…40fD) to Hyperithm ops
  (0xEe7E…18C8); curator is a separate Hyperithm address — multi-party admin path worth mapping.
- Prior public disclosure exists (Innora SAT-001..004 vs sUSDat, Apr 2026, toleranceBps=2000 etc.).
