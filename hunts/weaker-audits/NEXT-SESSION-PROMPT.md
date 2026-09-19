# Next-session prompt (copy everything below the line)

---

Use https://github.com/devIykee/iykes-evm-bughunt-skill.git (Iyke's EVM bughunt skill) to hunt the next protocol from protocols_by_weaker_audits.md.

You are weaker-audits-iyke. Register in TODO.md under that identity. Read the handoff first:

- hunts/weaker-audits/HUNT-LOG.md (what was already hunted / skipped and why)
- hunts/pinksale/ if you need PinkSale details (do not re-hunt PinkSale)
- hunts/goplus-locker-v3/ if you need GoPlus Locker V3 details (do not re-hunt GoPlus)
- hunts/zoo-finance/ if you need Zoo Finance details (do not re-hunt Zoo)

Start with Predict Fun. List rank 121, prediction market. Prior note said ~$15–19M. Do not trust the list number.

Confirm the DefiLlama slug (try predict-fun / predictfun / predict.fun).

Gate before sinking hours:

1. Confirm live DefiLlama TVL is still material (skip if under ~$2M or $0).
2. Confirm custom contracts + verified or official source.
3. If Predict Fun is a thin wrapper, already well-audited with no extra surface, or has no source: take the next name from the HUNT-LOG fallback list (Harvest Finance → SuperEarn → Privacy Pools). Re-check live TVL on each. Never hunt curators, RWA wrappers, canonical L2 bridges, ether.fi, Cooler, Flux, Spectra, Yield Basis, Tydro, Infrared, QuickPerps, River4Fun, PinkSale, GoPlus, or Zoo Finance.

Then run the playbook in order:

1. Fill INTAKE (researcher deviykee). Workspace hunts/predict-fun/ (or the fallback slug).
2. Step 1 ground truth on the chain that holds TVL.
3. Step 2 locate cores (DefiLlama adapter + official docs + explorer). Do not trust the list TVL numbers.
4. Step 3 surface map + Sourcify. Set coverage.md Y after inventory.
5. Step 4 auth triage from 0x…dEaD on every money-mover (deposit, withdraw, redeem, harvest, claim, migrate, admin withdraw, setStrategy, diamondCut if any).
6. Steps 5–6 product questions: prediction resolution, oracle, claim, share inflation if any vault, CEI.
7. Fork-prove only if a permissionless path survives. Honest severity. Trust/centralization is not Critical.
8. Update hunts/weaker-audits/HUNT-LOG.md and TODO.md when you close or skip.

Rules: fork / eth_call only. Never mainnet. Kill your own finding. Private until patched. Token-conservative. Coverage.md incremental. If coverage is low, say so.

Start now. Do not ask me to pick unless every fallback also fails the gate.
