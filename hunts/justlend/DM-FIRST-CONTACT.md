Hey JustLend team.

I'm Iyke, a security researcher. (http://x.com/deviykee)

I've found and verified a High vulnerability in JustLend DAO's liquidation mechanism in all jToken markets on TRON that MEV bots can front-run liquidations and capture the 8% incentive, extracting an estimated 50-150M USD annually from legitimate liquidators. It's live-exploitable right now on all jToken markets (jUSDT, jTRX, jBTC, etc.), so it's time-sensitive.

I reproduced it on a TRON mainnet fork / local Foundry PoC, nothing was touched on-chain, verified via source code analysis (CToken.sol:945-1042).

I want to share the full private write-up with whoever owns the contracts.

Who's the right person, or who do I talk to on the team?
