# Argus Hunt - Current Status & Approach

## Challenge
- argus.world is behind security check (Cloudflare/similar)
- Website not easily scrapable for contract addresses
- No public GitHub repository found for Argus launchpad contracts
- Block explorer (arcscan.app) API not accessible

## What We Know
1. ARGUS token: 0xeCe5cA8bf9220718E5727754026757512212cb3c
2. Implementation: 0x122c82cfca7a3a2227285cc21f4522e8f551db3a
3. Pattern: EIP-1167 minimal proxy (factory creates clones)
4. Product: pump.fun-style launchpad with Uniswap integration
5. Dominance: 86% of Arc token launches, 49% of DEX volume

## Next Steps (Alternative Approaches)
A. Use browser dev tools to capture actual contract addresses from app usage
B. Search for verified contracts on Arc chain that match launchpad pattern
C. Analyze the implementation contract (0x122c...) bytecode/storage directly
D. Look for similar tokens to find common factory
E. Report based on general launchpad vulnerability patterns (Step 6)

## Decision
Proceeding with Option C + E: Analyze what we have and apply launchpad-specific
bug hunting patterns from the skill (graduation, migration, fee-split, etc.)
