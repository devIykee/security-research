Hey Aumo.

I'm Iyke, a security researcher. (http://x.com/deviykee)

I've found and verified a High vulnerability in Aumo's multi-venue ERC-4626 pool (NAV / redemption path) on X Layer that lets early redeemers drain healthy-venue liquidity when another venue is stuck but still counted in share price. It is source-verified with a local Foundry PoC (mainnet pool not required to prove the logic). Pre-launch timing makes this a good window to fix before funds scale.

I reproduced it on a local Foundry unit test, nothing was touched on-chain.

I want to share the full private write-up with whoever owns the contracts.

Who's the right person, or who do I talk to on the team?
