# Aumo hunt (private)

Everything for this target lives under `hunts/aumo/`.

```text
hunts/aumo/
├── README.md                 ← this file
├── INTAKE.md                 ← standardized hunt intake
├── ADDRESSES.md              ← intake addresses / contracts / testnet info
├── coverage.md               ← 100% custom contract & script audit coverage map
├── src/                      ← clean copies of production contracts
│   ├── AumoPool.sol
│   ├── AumoVault.sol
│   ├── adapters/
│   │   ├── AaveV3Adapter.sol
│   │   └── RwaUsdgAdapter.sol
│   └── interfaces/
│       └── IVenueAdapter.sol
├── reports/                  ← all vulnerability write-ups + first contact DM
│   ├── FINDINGS-MASTER.md    ← start here (scoreboard & summary)
│   ├── H1-nav-preferential-exit.md
│   ├── H5-redeem-path-sandwich.md
│   ├── C-candidate-dust-redeem-full-liquidation.md
│   ├── logic-bugs.md
│   ├── structured-audit.md
│   ├── multi-angle-index.md
│   ├── hunt-notes.md
│   └── dm-first-contact.md
├── audit/                    ← multi-angle pack + Slither outputs
│   ├── audit-report.md
│   ├── audit-context.md
│   ├── audit-debug.md
│   └── slither/
│       ├── slither-out.txt
│       ├── slither-report.json
│       └── slither-stderr.txt
├── poc/                      ← Foundry PoC test suites & run guide
│   ├── README.md
│   ├── AumoPool_Residual.t.sol
│   ├── AumoPool_LogicBugs.t.sol
│   ├── AumoPool_RedeemSandwich.t.sol
│   ├── AumoPool_CriticalHunt.t.sol
│   ├── AumoPool_CriticalPush.t.sol
│   ├── AumoPool_DustLastPass.t.sol
│   └── AumoPool_AdversarialAngles.t.sol
├── recon/                    ← site/bundle scrapes & extracts
│   ├── addrs.txt
│   ├── chunks.txt
│   ├── site.html
│   └── bundles/
└── repo/                     ← upstream workspace (contracts, agent, web, docs)
```

## What to send the team

Not this whole tree. Prefer:

1. `reports/dm-first-contact.md` first  
2. Then a small zip of: `reports/FINDINGS-MASTER.md`, `audit/audit-report.md`, `reports/H1-…`, `reports/logic-bugs.md`, and `poc/*.sol` + run commands  

Do not send `recon/` or unrelated workspace folders.

## Run PoCs

```bash
cd hunts/aumo/repo/contracts
forge test
```

## Researcher

deviykee / Iyke — private until patched.
