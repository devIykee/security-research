#!/usr/bin/env bash
# SAFE: read-only eth_call reproduction of findings F1-F4, F6.
# No transactions are broadcast. Run from anywhere with foundry installed.
set -u
RPC_HEMI="https://rpc.hemi.network/rpc"
RPC_UNI="https://mainnet.unichain.org"
RPC_LISK="https://rpc.api.lisk.com"
RPC_SONIC="https://rpc.soniclabs.com"
ULN="0xe1844c5d63a9543023008d332bd3d2e6f1fe1043"   # ReceiveUln302 (batch chains)
DEAD_HEMI="0x6788f52439aca6bff597d3eec2dc9a44b8fee842"

decode(){ python3 -c '
import sys
h=sys.argv[1]
if not h or len(h)<200: print("  <no data / revert>"); sys.exit()
b=h[2:]; ws=[b[i*64:(i+1)*64] for i in range(len(b)//64)]
off=int(ws[0],16)//32
def arr(w):
    o=int(ws[off+w],16)
    if o==0: return []
    idx=off+o//32; n=int(ws[idx],16)
    return ["0x"+ws[idx+1+k][24:] for k in range(min(n,6))]
print(f"  confirmations={int(ws[off],16)} requiredDVNCount={int(ws[off+1],16)} requiredDVNs={arr(4)} optional={int(ws[off+2],16)}/{int(ws[off+3],16)} {arr(5)}")
' "$1"; }
getcfg(){ echo "   raw:"; r=$(cast call "$ULN" "getUlnConfig(address,uint32)" "$1" "$2" --rpc-url "$3" 2>/dev/null); decode "$r"; }

echo "== F1: TokenMessaging(hemi) sophon(30334) latest custom config"
echo "   (event-sourced; verify via stored config below)"
getcfg 0xaf5191b0de278c7286d6c7cc6ab6bb8a73ba2cd6 30334 "$RPC_HEMI"

echo "== F2: TSBSatellite(unichain) arbitrum(30110) resolved config"
getcfg 0x3d354c963d881d33937d278117f9546bb9b0f6ae 30110 "$RPC_UNI"
echo "   sole DVN code size (expect EOA=0):"
cast code 0xb85775a6868c6711bf35ff67557ee83cd252dc79 --rpc-url "$RPC_UNI" | wc -c

echo "== F3: Sonic Bus ethereum-leg resolved config (single required + optional thr=1)"
getcfg 0x2086f755a6d9254045c257ea3d382ef854849b0f 30101 "$RPC_SONIC"

echo "== F4: WGC(lisk) hyperliquid(30367) leg conf=1 single DVN"
getcfg 0x3d63825b0d8669307366e6c8202f656b9e91d368 30367 "$RPC_LISK"

echo "== F6: Hemi chain DEFAULT for eth(30101) requires DeadDVN"
getcfg 0x000000000000000000000000000000000000dEaD 30101 "$RPC_HEMI"
echo "   DeadDVN.verify() reverts (fail-closed proof):"
cast call "$DEAD_HEMI" "verify(bytes,bytes32,uint64)" 0x1234 \
  0xdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef 1 \
  --rpc-url "$RPC_HEMI" 2>&1 | head -c 120
echo
echo "== Kelp kill-check: rsETH held by hemi adapter (expect 0)"
T=$(cast call 0xc3eacf0612346366db554c991d7858716db09f58 "token()(address)" --rpc-url "$RPC_HEMI" 2>/dev/null)
cast call "$T" "balanceOf(address)(uint256)" 0xc3eacf0612346366db554c991d7858716db09f58 --rpc-url "$RPC_HEMI" 2>/dev/null
