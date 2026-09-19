# Addresses — GoPlus Locker V3

Sources: official docs + DefiLlama adapter `projects/goplus-locker-v3/index.js`.

## Cores (same address on ETH / BSC / Base / Arb unless noted)

| Role | Address | Notes |
|------|---------|-------|
| UniV3LPLocker (V3 TVL pot) | `0x25c9C4B56E820e0DEA438b145284F02D9Ca9Bd52` | DefiLlama V3 owner. ~$27.57M, 98% BSC |
| TokenLocker (V2) | `0xF17A08A7d41F53B24AD07Eb322CBBdA2ebdeC04b` | Official Token Locker; V2 adapter. Skip unless needed |
| TokenLocker old BSC | `0x7AA03D4b9051cF299e7A2272953D0590FEE485A4` | V2 adapter extra |

## Live config (BSC, 2026-08-17)

| Role | Address | Notes |
|------|---------|-------|
| owner | `0x296812aa1e707370e414f72F0680801e8666B50F` | EOA (codesize 0). Same on ETH |
| feeReceiver | `0x521faAcDFA097ad35a32387727e468F7fD032fD6` | EOA |
| customFeeSigner | `0x333A16307d8bEf80616F719E958Af5C76290CA85` | EOA, not zero |
| Pancake V3 NPM (allowlisted) | `0x46A15B0b27311cedF172AB29E4f4766fbE7F4364` | most sample locks |
| UniV3-style NPM (allowlisted) | `0x7b8A01B39D58278b5DE7e48c8449c9f4F5170613` | UI "UniV3" on BSC |

Fees: DEFAULT 40/160, LVP 64/80, LLP 24/280. nextLockId BSC=4317, ETH=66.

## Official docs extras (not V3 adapter)

| Role | Address |
|------|---------|
| UniV4 ETH | `0x83eab398539af72BF0f0f6A2aA5814D76a53F7D7` |
| UniV4 Base | `0x4F26fa33bCE395d50671CbC8C7a5D3c55a95519e` |
