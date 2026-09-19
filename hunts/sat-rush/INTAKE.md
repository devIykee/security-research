# INTAKE - Sat Rush

```
PROJECT_NAME   : Sat Rush
X_HANDLE       : @SatRush / @SatRushIO
WEBSITE        : https://satrush.io
DOCS           : (403 - behind cloudflare)
CLUSTER        : mainnet-beta
RPC            : https://api.mainnet-beta.solana.com
EXPLORER       : https://explorer.solana.com
KNOWN_PROGRAMS : satrush=satRushGBRY2vgapeTAkoxz26vL2cYqyPi6CnBj7Tco, worker=WKhLkiPw8dSMoV1n81Mxyo61Eu3rH9CKtQTnLjGv4BS
KNOWN_ACCOUNTS : config=5pJUG7jjfQxQ8jmrbdpNNCZrNmqXXkppKPNMs4Twfyfc, sats_vault=5ATZbUaByMDTePxRdjAaisopAULwsjMFTrM4f5vXVJQu, board=FbVd1fsYKpEj1Bzupbjo2VGJyfgLU9aw4r8U5uuR8v6s, epoch_vault=Ei1gqB9fyR7F7JBPz49YjkAD5karR4iqxPoyYczJGk8Q, one_btc_vault=9xMBPy3aRD92QvkhYZfVwJ6ZvfLTzM84pX6ZbjBnHfGP, treasury=FP7MRz61w5HEhFa3s4ifn26A3yQGHVdvPjhqu34jfQPt, sats_vault_btc_ata=2zpcctvd7sCdtWe4bAYcNmfVFzaiFVtH81tfMAWCtMh9
FRAMEWORK      : anchor (codama-generated client; program uses BPFLoaderUpgradeable)
PRODUCT_TYPE   : vault + lottery (BTC/cbBTC deposit via USD rounds, share-based vault, epoch/1BTC prize draws)
TOKEN_SURFACE  : spl-token (cbBTC mint: cbbtcf3aa214zXHbiAZQwf4122FBYbraNdFqgw4iMij, USDC: EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v)
BOUNTY/CONTEST : none found (no Immunefi, Cantina, Sherlock, C4, H1 listings)
NOTES          : Program deployed 2026-08-13. Upgrade authority = AEeAcZseSP7kqVkpX3Ut1tDh3nhZkoTbf5sGzfmytgZz (same as owner_authority in config). Worker program WKhLkiPw8dSMoV1n81Mxyo61Eu3rH9CKtQTnLjGv4BS wraps DeployPublic into batches. settle_grace_duration = 0 slots. Round duration 150 slots (~60s). 10% claim fee. Strike jackpot 1-in-1097 odds.
RESEARCHER     : deviykee
```

## Key Parameters (live on-chain 2026-08-23)

| Parameter | Value |
|-----------|-------|
| owner_authority | AEeAcZseSP7kqVkpX3Ut1tDh3nhZkoTbf5sGzfmytgZz |
| admin_authority | AEeAcZseSP7kqVkpX3Ut1tDh3nhZkoTbf5sGzfmytgZz |
| game_authority | CDRqHM8PkALZ5jRhQ1ikjzegr4LuuWuunxuoWeKNuokK |
| fee_recipient | 2vLD91xpSuvTPEAu7qQ921K9jARzdcf9cVaV1hFVmBGS |
| usd_mint (USDC) | EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v |
| btc_mint (cbBTC) | cbbtcf3aa214zXHbiAZQwf4122FBYbraNdFqgw4iMij |
| strike_fee_bps | 294 |
| epoch_fee_bps | 232 |
| one_btc_fee_bps | 132 |
| sats_vault_round_fee_bps | 1200 (12%) |
| sats_vault_claim_fee_bps | 1000 (10%) |
| protocol_fee_bps | 142 |
| unclaimed_hashrate_bps | 3500 (35%) |
| min_deploy_usd_amount | 1,000,000 (1.00 USDC) |
| epoch_vault_iteration_duration | 648,000 slots (~72h) |
| deployment_settle_grace_duration | 0 slots |
| strike_trigger_modulus | 1097 |

## Live Vault State

- SatsVault btc_amount: 542,744,612 sats (5.427 BTC)
- SatsVault btc_shares: 309,132,629,548
- SatsVault leftovers: 0
- sats_vault_btc_ata actual balance: 543,522,908 sats (+778,296 pending)
- Exchange rate: ~569.57 shares per sat

## Architecture

1. **DeployPublic** (user tx via Worker batch): user picks tiles (21-bit mask), stakes USDC
2. **SettleDeployPublic** (keeper/operator): after round ends, converts USD to BTC, credits shares + hashrate to miner
3. **ClaimSats** (user tx): burns shares, receives BTC at rate = shares * (vault_amount+1) / (vault_shares+SHARE_OFFSET)
4. **Lottery**: Epoch Vault + 1BTC Vault, tickets bought with hashrate points
5. **Strike**: 1-in-1097 jackpot per round

## Attack Surface Hypotheses

1. **Share math rounding** - SHARE_OFFSET=1000 prevents first-depositor but check edge cases
2. **settle_grace_duration = 0** - third-party settle of stale deployments immediately?  
3. **SlotHashes RNG** - validators can predict/manipulate winning tile
4. **Worker program trust** - does it have elevated privileges over the satrush program?
5. **Donation to sats_vault_btc_ata** - can inflating ATA balance skew share pricing?
6. **Claim fee as permanent loss** - 10% exit fee, does the fee credit benefit remaining holders?
7. **Epoch/1BTC vault accounting** - fee routing from rounds to prize vaults
