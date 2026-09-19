# Recon Brief - sweep 2026-07 (READ-ONLY)

You are doing read-only security recon for a bug-bounty sweep.
NO exploitation, NO state-changing txs, NO wallet use.

## Environment
- Workspace: /home/iyke/coding/security-research/hunts/sweep-2026-07/
- Foundry: cast/forge in PATH (/home/iyke/.foundry/bin)
- Helper scripts: /home/iyke/coding/security-research/.agents/skills/iykes-evm-bughunt-skill/tools/
  - step2_bundle_grep.sh <WEBSITE>        # greps app JS bundles for labeled 0x addrs
  - step3_surface_map.sh <RPC> <CID> <ADDR> [BS]   # balance/codesize/verification/selectors
  - step4_auth_triage.sh <RPC> <ADDR> [extra sigs] # eth_calls admin fns from 0xdEaD; OPEN = missing auth
- Save downloaded sources under workspace src/<addr>/ using:
  curl -s "https://sourcify.dev/server/v2/contract/<CID>/<ADDR>?fields=sources,compilation"
  then parse .sources[path].content into files (content may be dict {content: "..."}).
- Blockscout API pattern: <EXPLORER>/api/v2/addresses/<ADDR>  -> is_verified,name
- If bundle grep empty: fetch site HTML, look for config json endpoints (*.json), or grep JS chunks manually for /0x[a-fA-F0-9]{40}/ with nearby words like factory|router|vault|pool|manager|oracle|perps|market.

## RPCs
- ethereum: https://ethereum-rpc.publicnode.com (1)
- base: https://base-rpc.publicnode.com (8453)
- arbitrum: https://arb1.arbitrum.io/rpc (42161)
- bsc: https://bsc-dataseed1.bnbchain.org (56)
- monad: https://rpc.monad.xyz (143)
- robinhood chain: https://rpc.mainnet.chain.robinhood.com (4663), explorer https://robinhoodchain.blockscout.com/api/v2
- katana: https://rpc.katana.network (747474)
- megaeth: https://mainnet.megaeth.com/rpc (4326)
- intuition: https://rpc.intuition.systems (1155)
- hyperliquid evm: https://rpc.hyperliquid.xyz/evm (999)
- sonic: https://rpc.soniclabs.com (146)

## Common token addresses (ethereum): USDC 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, USDT 0xdAC17F958D2ee523a2206206994597C13D831ec7, WETH 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2

## Per-target checklist (keep bounded, ~10 min/target max)
1. Core contract addr(s) via bundle grep / explorer search.
2. step3_surface_map: verified? balance? code size?
3. Pull sources if Sourcify-verified; else record top selectors.
4. step4_auth_triage on main value-holding contract; note any "OPEN <-- CHECK".
5. Balances: ETH via cast balance; USDC/USDT/WETH balanceOf if ethereum.
6. Note 2-3 most interesting value-moving functions from selector list.

## Return format (STRICT, max ~40 lines total)
Per protocol one block:
NAME | chain | core addrs | verified y/n+where | balances | OPEN auth hits | interesting fns | sources saved path
Plus final line: BEST_TARGET: <name> <one-line why>
