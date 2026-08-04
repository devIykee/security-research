Hey RoughLaunch / Inkfeather.

I'm Iyke, a security researcher. (http://x.com/deviykee)

I reviewed RoughLaunch on Robinhood Chain (LaunchToken verified; factory and fee locker as UUPS proxies). I did not find a permissionless High I can prove without factory source. Graduation looks like a milestone only, and launches are single-sided V3 from block one, so the classic "dump a bonding-curve raise into a pre-rigged pool" class is less direct here.

One residual lead: the factory implementation bytecode includes createAndInitializePoolIfNecessary. On other RH pads that pattern plus zero mins and no price check was High. Your factory is still closed-source, so I cannot close that lead cleanly.

I only used fork / eth_call / verified token source. Nothing was touched on-chain.

Happy to share private notes if you want, or re-check after you verify the factory/locker implementations.

Who owns the contracts on the team?
