Hey Tolly Labs.

I'm Iyke, a security researcher. (http://x.com/deviykee)

I've found and verified a Critical vulnerability in Tolly Labs's pool initialization in createToken on Arc that allows an attacker to steal 50-90% of token supply by front-running pool initialization at manipulated price. It's live-exploitable right now on every token launch on TollyPad, so it's time-sensitive.

I reproduced it on an Arc mainnet fork with a working PoC, nothing was touched on-chain.

I want to share the full private write-up with whoever owns the contracts.

Who's the right person, or who do I talk to on the team?
