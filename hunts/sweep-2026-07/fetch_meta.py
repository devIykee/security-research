import json, urllib.request, concurrent.futures, os

SLUGS = ["robinhood-chain-bridge","valos","niza","wise-token","axis","azverse-perps",
"y10k-capital","arcus-perps","afx-lp","syntetika","xgld","agua","subfrost","nuva",
"vault-street-primeusd","fermiswap","noxa-fun","up-v3","morpho-midnight","adi-bridge",
"predictstreet","webot","uncx-network-v4","sato","katana-perps","sodax",
"meridian-perps","coinmerce-capital","ammalgam-vaults","byzanlink-rwa-markets"]

def fetch(slug):
    url = f"https://api.llama.fi/protocol/{slug}"
    try:
        with urllib.request.urlopen(url, timeout=30) as r:
            d = json.load(r)
        slim = {
            "slug": slug, "name": d.get("name"), "url": d.get("url"),
            "twitter": d.get("twitter"), "github": d.get("github"),
            "chains": d.get("chain"), "tvl": d.get("tvl"),
            "address": {k: v for k, v in (d.get("address") or {}).items() if v},
            "methodology": d.get("methodology"),
        }
        return slug, slim
    except Exception as e:
        return slug, {"slug": slug, "error": str(e)}

with concurrent.futures.ThreadPoolExecutor(10) as ex:
    results = dict(ex.map(fetch, SLUGS))

for s in SLUGS:
    with open(f"meta/{s}.json", "w") as f:
        json.dump(results[s], f, indent=1)

# compact triage print
for s in SLUGS:
    d = results[s]
    if "error" in d:
        print(f"{s}: FETCH-ERROR {d['error'][:60]}"); continue
    addr = "; ".join(f"{k}:{','.join(v)}" for k, v in d["address"].items()) if d["address"] else "-"
    if len(addr) > 160: addr = addr[:157] + "..."
    tw = "@" + d["twitter"] if d.get("twitter") else "-"
    gh = "GH:" + ",".join(d["github"]) if d.get("github") else "-"
    print(f"{s} | ${round((d['tvl'] or 0)/1e6,1)}M | {','.join(d['chains'])} | url={d['url'] or '-'} | {tw} | {gh}")
    print(f"   addr: {addr}")
