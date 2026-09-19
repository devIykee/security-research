#!/bin/bash
A=$1
mkdir -p src/$A
R=$(curl -s -m 30 "https://sourcify.dev/server/v2/contract/4663/$A?fields=sources,compilation")
echo "$R" | python3 -c "
import json,sys
d=json.load(sys.stdin)
srcs=d.get('sources') or {}
comp=d.get('compilation') or {}
print(f'$A name={comp.get(\"name\")} files={len(srcs)}')
for p,c in srcs.items():
    body = c if isinstance(c,str) else c.get('content','')
    fn='src/$A/'+p.replace('/','_')
    open(fn,'w').write(body)
"
