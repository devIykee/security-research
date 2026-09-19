# Solana Mobile Bug Bounty Submission Form Guide

- **URL**: https://solanamobile.com/security
- **Target**: Solana Mobile / Seeker Ecosystem
- **Vulnerability**: Zero-Balance Token Account Gating Bypass in Seeker Genesis Token (SGT) Verification Reference
- **PoC ZIP File**: `hunts/solana-mobile/solana_mobile_poc.zip`

---

### Form Fields & Values

#### 1. Project / Organization Name *
```text
Individual Security Researcher / deviykee
```

#### 2. Severity *
```text
Tier 1 (Critical) - or Tier 2 (High)
```
*(Select **Tier 1** or **Tier 2** depending on dropdown format)*

#### 3. Summary *
```text
The official Seeker Genesis Token (SGT) verification reference implementation in `skills/seeker-genesis-token/references/sgt-verification.md` (`checkWalletForSGT`) fails to check whether a wallet's Token-2022 Associated Token Account holds a non-zero balance (`amount > 0`). In the Solana Token-2022 standard, when an NFT is transferred out of an Associated Token Account (ATA) to another wallet, the original ATA remains open on-chain with `amount: "0"`. Because the reference implementation extracts all Token-2022 mint addresses without filtering for `amount !== "0"`, any wallet that previously held an SGT and transferred it away permanently retains `hasSGT: true`. An attacker with a single physical Seeker device can cycle the SGT across unlimited wallets, permanently qualifying all of them for Seeker-gated privileges, whitelists, and airdrops.
```

#### 4. Affected component *
```text
Seeker Genesis Token (SGT) Backend Verification Infrastructure (Section 2.3) / skills/seeker-genesis-token/references/sgt-verification.md
```

#### 5. Reproduction steps *
```text
1. Inspect `skills/seeker-genesis-token/references/sgt-verification.md` lines 95–108 (standard RPC) and lines 156–161 (Helius pagination).
2. Observe that `tokenAccounts` are mapped directly to `mint` pubkeys via `entry.account.data.parsed?.info?.mint` without checking `tokenAmount.amount !== "0"`.
3. On a Solana test validator or mainnet RPC, construct a wallet `Wallet_A` that previously received a Seeker Genesis Token (Token-2022 NFT) and transferred it to `Wallet_B`.
4. `Wallet_A` retains an open Token-2022 ATA pointing to the SGT mint with balance `0`.
5. Execute `checkWalletForSGT(Wallet_A)`.
6. Observe that `findSgtMint()` successfully verifies the on-chain mint authority (`GT2zuHVa...`) and metadata pointer (`GT22s89n...`).
7. Observe that `checkWalletForSGT(Wallet_A)` returns `{ hasSGT: true, mintAddress: SGT_MINT }` despite `Wallet_A` having a zero balance.
```

#### 6. Proof-of-concept (PoC) code * (Upload ZIP)
```text
(Upload hunts/solana-mobile/solana_mobile_poc.zip)
```

#### 7. Impact assessment *
```text
- Whether funds could be lost: Yes, potential loss of ecosystem token rewards, airdrop allocations, and gated incentives distributed to Sybil wallets.
- What data could be exposed: Unauthorized access to Seeker-gated dApp endpoints and exclusive services.
- Whether user action is required: No user action required beyond initial SGT token transfer.
- Whether additional software needs to be installed locally: No.
- Whether the user must grant any permissions: No.
- Whether the device configuration must be manually changed: No.
- Scope impact: Complete breakdown of the 1-claim-per-device anti-Sybil model for Seeker Genesis Tokens.
```

#### 8. Suggested fix (optional but encouraged)
```javascript
// In skills/seeker-genesis-token/references/sgt-verification.md:
const mintPubkeys = tokenAccounts
  .filter((entry) => {
    const amount = entry.account?.data?.parsed?.info?.tokenAmount?.amount;
    return amount && amount !== '0';
  })
  .map((entry) => entry.account.data.parsed?.info?.mint)
  .filter(Boolean)
  .map((mint) => new PublicKey(mint));
```

---

### Personal & Contact Fields

- **Country**: *(Your country of residence, e.g. Nigeria)*
- **First Name**: *(Your first name)*
- **Last Name**: *(Your last name)*
- **Email \***: *(Your primary contact email)*
- **Twitter (X)**: `@devIykee` *(or your X handle)*
- **Telegram \***: `@devIykee` *(or your Telegram handle)*

