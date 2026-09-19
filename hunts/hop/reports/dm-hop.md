Hey Hop Protocol.

I'm Iyke, a security researcher. (http://x.com/deviykee)

I've found and verified a Medium vulnerability in Hop Protocol's L1 ETH bridge challenge flow on Ethereum. A stranger can challenge an honest TransferRoot with a fake destination and, if nobody resolves with the real dest after 14 days, extract 7.5 percent of that root from the ETH pool. It is live on the L1 ETH bridge (about 603 ETH) for each newly bonded root, so it is time-sensitive.

I reproduced it on an Ethereum mainnet fork / local Foundry PoC. Nothing was touched on-chain.

I want to share the full private write-up with whoever owns the contracts.

Who's the right person, or who do I talk to on the team?
