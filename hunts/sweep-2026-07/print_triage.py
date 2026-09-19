import json, glob, os
def norm(x):
    if isinstance(x, list): return ",".join(map(str,x))
    return str(x)
for p in sorted(glob.glob("meta/*.json")):
    d = json.load(open(p))
    s = d.get("slug", os.path.basename(p)[:-5])
    if "error" in d:
        print(f"{s}: FETCH-ERROR {d['error'][:60]}"); continue
    tvl = d.get("tvl")
    cur = round(tvl[-1]["totalLiquidityUSD"]/1e6,1) if isinstance(tvl,list) and tvl else 0
    addr = d.get("address")
    addr_s = norm(addr) if isinstance(addr,(str,list)) else ";".join(f"{k}:{norm(v)}" for k,v in (addr or {}).items())
    if len(addr_s)>140: addr_s = addr_s[:137]+"..."
    tw = "@"+str(d["twitter"]) if d.get("twitter") else "-"
    gh = "GH:"+norm(d["github"]) if d.get("github") else "-"
    print(f"{s} | ${cur}M | {norm(d['chains'])} | url={d['url'] or '-'} | {tw} | {gh}")
    if addr_s: print(f"   addr: {addr_s}")
