Hey xStocks / CDP team.

I'm Iyke, a security researcher. (http://x.com/deviykee)

I've found and verified a Trust/Centralization issue (high impact if the key is compromised) in EquityOracle V1 wired to a live CdpEngine on Robinhood Chain: a single reporter (currently the same address as the CDP owner) can set any collateral price and over-mint or unfairly liquidate against live vaults. Scope includes the CDP at 0x5812E883... with on-chain collateral/debt in the thousands of xTSLA / hundreds of thousands of xUSD class. This is not a permissionless stranger exploit. It is a live-TVL trust model your own V2 comments treat as a drain-class design.

I confirmed it with read-only on-chain checks (quorum, reporter count, owner == sole reporter, vault balances). Nothing was touched on-chain.

I want to share the full private write-up with whoever owns the contracts.

Who's the right person, or who do I talk to on the team?
