# Coverage — multi-protocol hunt (protocols_by_weaker_audits.md sweep)

Coverage: triage 170/170 slugs resolved; deep-traced: 2 protocols (Saturn done-clean, YB deprioritized-audited); discovery done: Tydro/Nado/Rysk/Royco/Pharaoh.

Last updated: 2026-08-25 wave 2

## Protocol verdicts so far

| Protocol | TVL | Verdict | Reason |
|----------|-----|---------|--------|
| Yield Basis | $130M | SKIP (audited) | 10 audits incl Sherlock contest Aug-Sep 2025 |
| Saturn | $172M | CLEAN-CORE | stock Morpho VaultV2 + MorphoMarketV1Adapter; only custom = StrcPriceOracle (admin-gated, bounded). Roles are owner/curator EOAs (trust-risk only) |
| Royco V2 | $24M | SKIP (audited) | Hexens x3 + Certora FV + Cyfrin + Immunefi |
| Rysk V1 | $41M | LOW-PRI | withdraw-only mode; audits cover V12 not V1 |
| Cooler Loans | $215M | SKIP | ChainSecurity audited |
| PinkSale | $143M | PENDING | battle-tested since 2021; app Cloudflare-walled; need factory addrs |
| Tydro | $56M | DEEP-DIVE | Aave v3 L2 fork, NO published audits, docs claim audits but none exist |
| Nado Spot | $47M | DEEP-DIVE | off-chain orderbook + on-chain Clearinghouse; NO audits found; public repo nadohq/nado-contracts |
| Pharaoh V3 | $26M | DEEP-DIVE | Ramses-v3 fork; docs admit no Pharaoh-deployment audit |

## Explicitly excluded

| Path / area | Reason |
|-------------|--------|
| canonical-bridge category (~25 protos) | security-council/multi-party trust models, not permissionless-exploitable |
| rwa/stablecoin-issuer/risk-curators (~45 protos) | centralized/off-chain management; contracts are third-party audited infra |
| ether.fi, mETH, Nexus, Hyperlane, dYdX, Flux, Boros, sDAI, Infrared(partially) | actually audited despite list label |

## Wave 3+ verdicts (2026-08-26)

| Protocol | Verdict |
|----------|---------|
| Capyfi | KILLED FALSE POSITIVE: Compound-style uint error codes decode as bool true via cast; forge fork test proves admin unchanged (Safe-gated). No bug. LESSON: verify "OPEN" with fork state assertions |
| Antarctic | No unauth path; handler/admin/gov key centralization (High-trust, Med severity class); sigs lack chainId (Low) |
| Kumbaya | BlockSec-audited v1.0; bytecode unverified vs audit; dust custody only |
| Project X | stock UniswapV3 + clean BatchClaim; unaudited but nothing open |
| Altura | Audited x6 (Adevarlabs, Omniscia, Sherlock); single-EOA operator/reporter roles (Med trust) |
| HyperVault | ALREADY RUGGED Sep 2025 ($3.6M admin drain); dead |
| GrowiHF | stock Morpho VaultV2; curator Safe risk |
| Pac Finance | DEAD: pools drained, llama TVL frozen fiction since Oct 2025 |
| Vena Finance | Sherlock-audited Apr 2026; guarded; single-EOA provider owner |
| Templar Protocol | NEAR-based; immutable markets; 3 audits on file |
| Predict Fun | Cyfrin+Sherlock; guarded; dispute-free oracle whitelist (Med design, disclosed) |
| IntentX | SYMMIO Sherlock #85; guarded; TVL ~2x overstated by llama |
| Perpl | Safe-gated CLOB; audits page empty despite CertiK badge |
| Tempo Fee AMM | Enshrined precompiles; governance-level risk only |
| Katana DEX | Sky Mavis; fee-switch removed; unaudited modified Uni forks (process risk) |

## Open items
- Syntropia ERC7540 Vault.sol + Silo (sources downloaded, review next)
- StableHodl stake_pool impl (downloaded)
- STRATO SAVE_USDST_VAULT 0x22550671fcad04a213697ac7ae4f4366e96446ed + VAULT 0x34bc729f66106a146b0864e673a3571b28fa23e1
- Wildcat, PulseX V1, Blur Bids, Agni, SyncSwap, Thruster V2, Zoo, RockSolid, Merlin trio, SuperEarn, Aegis JUSD, GoPlus Locker real addrs, RocketSwap Anubis, Infrared deep, Pharaoh CL-pool/gauge math
