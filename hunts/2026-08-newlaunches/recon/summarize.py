import json, glob, sys
rows=[]
for f in sorted(glob.glob("*.json")):
    try: d=json.load(open(f))
    except Exception as e: rows.append((f[:-5],-1,"PARSE_FAIL","","","","","")); continue
    raw=d.get("tvl") or 0; tvl=int((raw[-1].get("totalLiquidityUSD",0) if isinstance(raw,list) and raw else raw if isinstance(raw,(int,float)) else 0))
    chains=d.get("chains") or []
    ct=d.get("chainTvls") or {}
    top=""
    if ct:
        try:
            best=max(((k,(v.get("tvl") or [0])[-1]) for k,v in ct.items() if k not in ("borrowed","staking","pool2","doublecountedLockup")), key=lambda x:x[1])
            top=f"{best[0]}:${(best[1] or 0)/1e6:.1f}M"
        except Exception: pass
    rows.append((f[:-5], tvl, ",".join(chains[:4]), d.get("url") or "-", (d.get("twitter") or "-").replace("https://twitter.com/","@"), str(len(d.get("audit_links") or [])), d.get("address") or "-", top))
rows.sort(key=lambda r:-r[1])
for r in rows:
    print(f"{r[0][:26]:26s} ${r[1]/1e6:>8.1f}M | {r[7]:>22s} | {r[2][:28]:28s} | audits:{r[5]} | {r[4]:16s} | {r[3][:60]}")
