#!/bin/bash
cd "$(dirname "$0")"
SLUGS="robinhood-chain-bridge valos niza wise-token axis y10k-capital syntetika agua subfrost nuva fermiswap adi-bridge diamond-finance predictstreet webot sato katana-perps sodax coinmerce-capital byzanlink-rwa-markets surge-credit azverse bdex arcus afx-protocol unitas resolv noxa up uncx-network meridian.xyz ammalgam"
for s in $SLUGS; do
  [ -s "$s.json" ] || curl -s --max-time 20 "https://api.llama.fi/protocol/$s" -o "$s.json" &
  while [ $(jobs -r | wc -l) -ge 8 ]; do wait -n; done
done
wait
for s in $SLUGS; do
  if [ -s "$s.json" ]; then
    jq -r '[.] | map("\(.slug // "'"$s"'")\t\(."tvl" // 0|floor)\t\(([.chains[]?] | join(",")) )\t\(.url // "-")\t\((.audit_links // []) | length)\t\(.twitter // "-")") | .[0]' -r "$s.json" 2>/dev/null || echo "$s	FAILED"
  else echo "$s	NODATA"; fi
done | sort -t$'\t' -k2 -rn | awk -F'\t' '{printf "%-28s %12s  %-40s %-45s audits:%s tw:%s\n",$1,$2,$3,$4,$5,$6}'
