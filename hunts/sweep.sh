#!/bin/bash
declare -A RPCS=(
 [ethereum]="https://ethereum-rpc.publicnode.com" [binance]="https://bsc-rpc.publicnode.com"
 [arbitrum]="https://arbitrum-one-rpc.publicnode.com" [base]="https://base-rpc.publicnode.com"
 [avalanche]="https://avalanche-c-chain-rpc.publicnode.com" [blast]="https://rpc.blast.io"
 [mantle]="https://rpc.mantle.xyz" [cronos]="https://evm.cronos.org"
 [cronos-zkevm]="https://cronos-zkevm.drpc.org" [filecoin]="https://api.node.glif.io"
 [hyperevm]="https://rpc.hyperliquid.xyz/evm" [plasma]="https://rpc.plasma.to"
 [robinhood2]="https://robinhood-rpc.publicnode.com" [ink]="https://ink.drpc.org"
 [berachain]="https://rpc.berachain.com" [zksync]="https://mainnet.zksync.io"
 [linea]="https://rpc.linea.build" [scroll]="https://rpc.scroll.io"
 [strato]="https://noderpc.strato.nexus/rpc" [morph]="https://rpc.morphl2.io" [ronin]="https://api.roninchain.com/rpc"
 [megaeth]="https://megaeth.drpc.org" [tempo]="https://tempo-rpc.publicnode.com"
 [monad]="https://rpc.monad.xyz" [fluent]="https://rpc.fluent.xyz"
 [merlin]="https://rpc.merlinchain.io" [kaia]="https://public-en.node.kaia.io"
 [hemi]="https://rpc.hemi.network" [pulsechain]="https://rpc.pulsechain.com"
)
DEAD=0x000000000000000000000000000000000000dEaD
while IFS=$'\t' read -r name chain cid addr; do
  rpc="${RPCS[$chain]}"; [ -z "$rpc" ] && { echo "$name|$chain|NO-RPC"; continue; }
  sz=$(cast code $addr --rpc-url $rpc 2>/dev/null | wc -c)
  [ "$sz" -le 10 ] && { echo "### $name | $chain | $addr | EMPTY-ADDR"; continue; }
  echo "### $name | $chain | $addr | codesize=${sz}"
  while read -r sig; do
    out=$(cast call $addr "$sig" --from $DEAD --rpc-url $rpc 2>&1 | head -2)
    if echo "$out" | grep -qi "error\|revert\|execution"; then :; else
      echo "  OPEN <-- CHECK $sig"
    fi
  done < "$2"
done < "$1"
