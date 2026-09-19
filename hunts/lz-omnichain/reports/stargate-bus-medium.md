# Stargate Sonic Bus - Info/KILLED: historical single-DVN config churn
**Researcher:** deviykee
**Severity:** Info (KILLED as vulnerability)
**Status:** Verified on-chain read-only.

## What this means in plain language
Event history shows the Sonic Hydra Bus once ran single-verifier configs, but the live
stored configuration on every checked leg (ethereum, arbitrum, base, abstract, plasma,
bsc) is now three required DVNs. No current exposure found.

## Live evidence (getUlnConfig, ReceiveUln302 0xe1844c5d...)
eid30101 conf=15 req=3; eid30110 conf=20 req=3; eid30184 conf=10 req=3;
eid30324 conf=20 req=3; eid30383 conf=5 req=3; eid30102 conf=20 req=3.
Repro: hunts/lz-omnichain/poc/repro_findings.sh

## Disposition
Kept as documentation of config-churn risk only. Not a finding.
deviykee
