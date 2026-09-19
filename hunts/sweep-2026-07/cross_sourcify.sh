#!/bin/bash
ADDRS="0x0742D64925E4C78cb1bAFfce2fA1dceBa8Cf133c 0x1f7d7550B1b028f7571E69A784071F0205FD2EfA 0x53BF6B0684Ec7eF91e1387Da3D1a1769bC5A6F77 0xCaf681a66D020601342297493863E78C959E5cb2 0x46A15B0b27311cedF172AB29E4f4766fbE7F4364 0x73991a25C818Bf1f1128dEAaB1492D45638DE0D3 0x0BFbCF9fa4f9C56B0F40a671Ad40E0805A091865 0x559771bc4561600383Ac39Fd8945e5CABc55D22C"
CHAINS="1155 4326 4200 143 988 4663 8453 1"
for a in $ADDRS; do
  for c in $CHAINS; do
    R=$(curl -s -m 15 "https://sourcify.dev/server/v2/contract/$c/$a?fields=compilation")
    N=$(echo "$R" | python3 -c "
import json,sys
try:
    d=json.load(sys.stdin)
    comp=d.get('compilation') or {}
    print((comp.get('name') or '')+ '|' + str(d.get('match')!='' and d.get('match') is not None))
except Exception as e: print('none|False')
")
    NAME=${N%%|*}; M=${N##*|}
    if [ "$NAME" != "none" ] && [ "$NAME" != "" ]; then echo "HIT $c $a -> $NAME match=$M"; fi
  done
done
echo DONE
