Hey The Index / @TheIndexFi.

I'm Iyke, a security researcher. (http://x.com/deviykee)

I've found and verified a High vulnerability in theindex.finance's INDEX holder distribution (USDGBuyerDistributor snapshot/payout) on Robinhood Chain that lets an attacker flash-inflate their INDEX balance at snapshot time and take a disproportionate share of the tokenized-stock pot, with no admin key and zero lasting INDEX capital. It's live-exploitable on every distribution cycle when the pot is non-empty, so it's time-sensitive.

I reproduced it with a local Foundry PoC that mirrors the verified on-chain snapshot logic, plus read-only on-chain checks. Nothing was touched on-chain.

I want to share the full private write-up with whoever owns the contracts.

Who's the right person, or who do I talk to on the team?
