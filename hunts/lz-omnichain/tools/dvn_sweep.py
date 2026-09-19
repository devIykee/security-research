#!/usr/bin/env python3
"""Sweep LayerZero V2 receive-library configs across emerging chains.
Reads default UlnConfig per remote-EID and flags weak verification sets.
Read-only eth_call only."""
import json, subprocess, sys
from concurrent.futures import ThreadPoolExecutor

CAST = "/home/iyke/.foundry/bin/cast"

def rpc(url, method, params):
    out = subprocess.run(["curl", "-s", "-m", "10", "-X", "POST", "-H", "Content-Type: application/json",
                          "--data", json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}), url],
                         capture_output=True, text=True).stdout
    try:
        r = json.loads(out)
        if "error" in r: return ("ERR", r["error"].get("message", str(r["error"]))[:80])
        return ("OK", r["result"])
    except Exception:
        return ("ERR", "badjson")

def call(rpcurl, to, data):
    return rpc(rpcurl, "eth_call", [{"to": to, "data": data}, "latest"])

def sig(s):
    return subprocess.run([CAST, "sig", s], capture_output=True, text=True).stdout.strip()

def w(i, raw):  # i-th 32-byte word of result hex
    b = raw[2:]
    if i * 64 + 64 > len(b): return None
    return int(b[i * 64:(i + 1) * 64], 16)

def decode_uln_config(raw, chain_rpc):
    # struct UlnConfig {uint64 confirmations; uint8 requiredDVNCount; uint8 optionalDVNCount;
    #                   uint8 optionalDVNThreshold; address[] requiredDVNs; address[] optionalDVNs;}
    conf = w(0, raw); req_n = w(1, raw); opt_n = w(2, raw); opt_thr = w(3, raw)
    req_off = w(4, raw); opt_off = w(5, raw)
    def arr(off):
        if off is None: return []
        b = raw[2:]; o = off
        n = int(b[o:o + 64], 16)
        out = []
        for k in range(min(n, 8)):
            a = "0x" + b[o + 64 + k * 64 + 24: o + 64 + (k + 1) * 64]
            out.append(a)
        return out
    return {"confirmations": conf, "requiredDVNCount": req_n, "optionalDVNCount": opt_n,
            "optionalDVNThreshold": opt_thr, "requiredDVNs": arr(req_off), "optionalDVNs": arr(opt_off)}

CHAINS = {
  "plasma":     {"rpc": "https://rpc.plasma.to", "eid": 30383},
  "sonic":      {"rpc": "https://rpc.soniclabs.com", "eid": 30332},
  "berachain":  {"key": "bera", "rpc": "https://rpc.berachain.com", "eid": 30362},
  "hyperevm":   {"key": "hyperliquid", "rpc": "https://rpc.hyperliquid.xyz/evm", "eid": 30367},
  "abstract":   {"rpc": "https://api.mainnet.abs.xyz", "eid": 30324},
  "lisk":       {"rpc": "https://rpc.api.lisk.com", "eid": 30321},
  "monad":      {"rpc": "https://rpc.monad.xyz", "eid": 30390},
  "unichain":   {"rpc": "https://mainnet.unichain.org", "eid": 30320},
  "worldchain": {"rpc": "https://worldchain-mainnet.g.alchemy.com/public", "eid": 30319},
  "hemi":       {"rpc": "https://rpc.hemi.network/rpc", "eid": 30329},
  "story":      {"rpc": "https://mainnet.storyrpc.io", "eid": 30364},
  "katana":     {"rpc": "https://rpc.katana.network", "eid": 30375},
  "sei":        {"rpc": "https://evm-rpc.sei-apis.com", "eid": 30280},
}
REMOTES = {"ethereum": 30101, "bsc": 30102, "avalanche": 30106, "arbitrum": 30110,
           "optimism": 30111, "polygon": 30109, "base": 30184}

meta = json.load(open(sys.argv[1] if len(sys.argv) > 1 else "/tmp/opencode/lz-deployments.json"))
DEP = {}
for name, c in meta.items():
    if not name.endswith("-mainnet"): continue
    key = c.get("chainKey")
    for d in c.get("deployments", []):
        if d.get("version") == 2 and d.get("stage") == "mainnet" and d.get("endpointV2"):
            DEP[key] = d

SEL_DRL = sig("defaultReceiveLibrary(uint32)")
SEL_GETCFG = sig("getConfig(address,uint32,address,uint32)")
SEL_GETCFG3 = sig("getConfig(address,uint32,uint32)")

results = {}
def sweep_chain(cname, c):
    dep = DEP.get(c.get("key", cname))
    if not dep:
        return f"{cname}: NO V2 DEPLOYMENT", {}
    ep = dep["endpointV2"]["address"]; ruln = (dep.get("receiveUln302") or {}).get("address")
    st, cid = rpc(c["rpc"], "eth_chainId", [])
    lines = [f"\n=== {cname} eid={c['eid']} cid={cid} ep={ep[:12]} recvUln={str(ruln)[:12]}"]
    if not ruln:
        lines.append("  no receiveUln302 recorded"); return "\n".join(lines), {}
    res = {}
    def one(rn_reid):
        rname, reid = rn_reid
        st1, drl = call(c["rpc"], ep, SEL_DRL + f"{reid:064x}")
        lib = "0x" + drl[26:66] if st1 == "OK" and drl and len(drl) >= 66 else None
        expired = ""
        if st1 == "OK" and drl and len(drl) >= 66:
            expiry = int(drl[66:130], 16) if len(drl) >= 130 else 0
            expired = f"@{expiry}"
        st2, cfg = call(c["rpc"], ruln, SEL_GETCFG3 + "deaddeaddeaddeaddeaddeaddeaddeaddeaddead" + f"{reid:064x}" + f"{1:064x}")
        if st2 != "OK" or not cfg or cfg == "0x":
            return f"  {rname:9s} defaultLib={lib}{expired} cfg=({st2}:{cfg})", None
        u = decode_uln_config(cfg, c["rpc"])
        flag = ""
        if u["requiredDVNCount"] == 0 and u["optionalDVNCount"] == 0: flag = " <<< NO-VERIFY"
        elif u["requiredDVNCount"] == 0: flag = " <<< REQ-ONLY-OPTIONAL"
        elif u["requiredDVNCount"] == 1: flag = " << single-required-DVN"
        return (f"  {rname:9s} lib={str(lib)[:12]}{expired:14s} conf={u['confirmations']} req={u['requiredDVNCount']} opt={u['optionalDVNCount']} thr={u['optionalDVNThreshold']}{flag}", u)
    with ThreadPoolExecutor(max_workers=8) as ex:
        for line, u in ex.map(one, REMOTES.items()):
            lines.append(line)
            if u: res[line.split()[0]] = u
    return "\n".join(lines), res

with ThreadPoolExecutor(max_workers=13) as ex:
    futs = {ex.submit(sweep_chain, cname, c): cname for cname, c in CHAINS.items()}
    for fut in futs:
        pass
    from concurrent.futures import as_completed
    for fut in as_completed(list(futs.keys())):
        cname = futs[fut]
        text, res = fut.result()
        print(text); results[cname] = res

json.dump(results, open("/tmp/opencode/dvn_defaults.json", "w"), indent=1)
print("\nsaved /tmp/opencode/dvn_defaults.json")
