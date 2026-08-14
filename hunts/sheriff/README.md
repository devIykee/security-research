# Sheriff Hunt (Private)

Everything for the **sheriff.money** hunt lives under `hunts/sheriff/`.

```text
hunts/sheriff/
├── README.md                 ← this file
├── INTAKE.md                 ← standardized hunt intake
├── ADDRESSES.md              ← live deployment addresses on Robinhood Chain (4663)
├── coverage.md               ← 88% (29/33) custom contract coverage map
├── code.hex                  ← on-chain bytecode dump
├── src.json                  ← verified source metadata
├── src/                      ← decompiled / verified production contract sources
│   ├── AlgebraFactory.sol
│   ├── AlgebraPool.sol
│   ├── SecurityRegistry.sol
│   ├── SheriffBasePlugin/
│   ├── SheriffBasePluginFactory/
│   ├── SheriffFeeHelper/
│   ├── SheriffYakRouter/
│   ├── TeamVestingLocker/
│   ├── CampaignFactory/
│   ├── v2/
│   └── npm/
├── reports/                  ← vulnerability reports & hunt documentation
│   ├── FINDINGS-MASTER.md    ← master scoreboard (M-1, L-1..L-2, I-1..I-2)
│   ├── sheriff-medium-burn-registry-zero.md
│   ├── hunt-notes.md
│   └── dm-first-contact.md
├── audit/                    ← audit staging
├── poc/                      ← self-contained Foundry PoC environment
│   ├── README.md
│   ├── foundry.toml
│   ├── lib/
│   └── test/
│       └── PoC.t.sol
└── recon/                    ← on-chain bytecode & sourcify scrapes
```

## What to send the team

1. `reports/dm-first-contact.md` first  
2. Then a zip of: `reports/FINDINGS-MASTER.md`, `reports/sheriff-medium-burn-registry-zero.md`, and `poc/` + run commands  

Do not send `recon/` or unrelated workspace folders.

## Run PoCs

```bash
cd hunts/sheriff/poc
forge test -vv
```

## Researcher

deviykee / Iyke — private until patched.
