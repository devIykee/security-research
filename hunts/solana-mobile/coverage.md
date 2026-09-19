# Coverage Tracker: Solana Mobile & Seeker Ecosystem

- **Target**: Solana Mobile / Seeker
- **Repositories Audited**:
  - `hunts/solana-mobile/solana-mobile-skills`
  - `hunts/solana-mobile/seed-vault-sdk`
  - `hunts/solana-mobile/mobile-wallet-adapter`

## Coverage Table

| File / Component | Status | Notes |
|---|---|---|
| `skills/seeker-genesis-token/references/sgt-verification.md` | Complete | Identified SOL-01 (Zero-balance Token Account SGT verification bypass). |
| `skills/seeker-genesis-token/SKILL.md` | Complete | Audited SIWS signature verification & anti-Sybil claim storage patterns. |
| `seed-vault-sdk/SeedVaultSimulator/.../WalletContentProvider.kt` | Complete | Identified SOL-02 (Null callingPackage forced unwrap DoS crash). |
| `seed-vault-sdk/seedvault/.../WalletContractV1.java` | Complete | Audited Wallet API contract, permissions, and BIP32/44 URI specs. |
| `seed-vault-sdk/SeedVaultSimulator/.../SignPayloadUseCase.kt` | Complete | Audited Ed25519 payload signing and secret key size validations. |
| `mobile-wallet-adapter/android/walletlib/.../LocalAssociationUri.java` | Complete | Audited local WebSocket association parsing and port boundary limits. |
| `mobile-wallet-adapter/android/walletlib/.../JsonRpc20Server.java` | Complete | Audited JSON-RPC message framing and session lifecycle. |

