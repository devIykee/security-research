#!/usr/bin/env python3
# Search for factory by looking at contract events or recent token launches
import subprocess
import json

RPC = "https://rpc.mainnet.arc.io"
TOKEN = "0xeCe5cA8bf9220718E5727754026757512212cb3c"

# Try to get Transfer events to find who received initial supply
print("Searching for initial Transfer events (mint)...")
cmd = f"cast logs --rpc-url {RPC} --address {TOKEN} 'Transfer(address,address,uint256)' --from-block 0 --to-block 100000"
result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
print(result.stdout[:1000] if result.stdout else "No output")
print(result.stderr[:500] if result.stderr else "")
