import json, urllib.request
def norm(x):
    if isinstance(x, dict): return {k:(norm(v)) for k,v in x.items()}
    return x
for slug in ["adi-bridge","morpho-midnight","sodax","uncx-network-v4","wise-token","xgld"]:
    try:
        with urllib.request.urlopen(f"https://api.llama.fi/protocol/{slug}", timeout=30) as r:
            d = json.load(r)
        addr = d.get("address")
        if isinstance(addr, dict): slim_addr = {k:v for k,v in addr.items() if v}
        else: slim_addr = {"_": addr} if addr else {}
        slim = {"slug":slug,"name":d.get("name"),"url":d.get("url"),"twitter":d.get("twitter"),
                "github":d.get("github"),"chains":d.get("chain"),"tvl":d.get("tvl"),
                "address":slim_addr,"methodology":d.get("methodology")}
        json.dump(slim, open(f"meta/{slug}.json","w"), indent=1)
        print(slug,"OK url=",slim["url"],"tw=",slim["twitter"],"addr=",slim_addr)
    except Exception as e:
        print(slug,"ERR",e)
