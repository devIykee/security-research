#!/usr/bin/env python3
"""Enumerate ALL OApps with custom receive configs by pulling UlnConfigSet events
from ReceiveUln302 on each target chain. Read-only."""
import json, subprocess, sys, time

CAST = "/home/iyke/.foundry/bin/cast"
TOPIC_ULNCFG = "0x82118522aa536ac0e96cc5c689407ae42b89d592aa133890a01f1509842f5081"
TOPIC_DEFAULT = "0xaaf3aaa0c11056e86ac56eb653e25b005ca1a7d4dcd21ba24647f7ab63f3b560"

def rpc(url, method, params, tries=3):
    for i in range(tries):
        out = subprocess.run(["curl", "-s", "-m", "20", "-X", "POST", "-H", "Content-Type: application/json",
                              "--data", json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}), url],
                             capture_output=True, text=True).stdout
        try:
            r = json.loads(out)
            if "error" in r:
                err = str(r["error"].get("message", r["error"]))[:100]
                if "rate" in err.lower() or "busy" in err.lower() or "limit" in err.lower():
                    time.sleep(2 + i * 2); continue
                return ("ERR", err)
            return ("OK", r["result"])
        except Exception:
            time.sleep(1 + i)
    return ("ERR", "badjson/exhausted")

def words(data_hex):
    b = data_hex[2:]
    return [b[i * 64:(i + 1) * 64] for i in range(len(b) // 64)]

def decode_struct(ws, base):
    # ws[base:] must hold [conf][req][opt][thr][offReq][offOpt] + tails
    if base + 6 > len(ws): return None
    def u(i): return int(ws[i], 16)
    def arr(off_bytes):
        idx = base + off_bytes // 32
        if off_bytes == 0 or idx >= len(ws): return []
        n = int(ws[idx], 16)
        out = ["0x" + ws[idx + 1 + k][24:] for k in range(min(n, 10))]
        return out
    return {"confirmations": u(base), "requiredDVNCount": u(base+1), "optionalDVNCount": u(base+2),
            "optionalDVNThreshold": u(base+3), "requiredDVNs": arr(u(base+4)), "optionalDVNs": arr(u(base+5))}

def decode_cfg(data_hex, tps):
    ws = words(data_hex)
    if len(tps) >= 3:            # new style: indexed oapp/eid, data = struct
        return decode_struct(ws, 0)
    if len(tps) == 1 and len(ws) >= 3:   # old style: data = [oapp][eid][structOffset][struct...]
        off = int(ws[2], 16)
        return decode_struct(ws, off // 32)
    return None

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

import re as _re
def err_max_range(e):
    try:
        nums = [int(x) for x in _re.findall(r"(\d+)", str(e))]
        cands = [n for n in nums if 10 <= n <= 2_000_000]
        return min(cands) if cands else None
    except Exception: return None

meta = json.load(open(sys.argv[1] if len(sys.argv) > 1 else "/tmp/opencode/lz-deployments.json"))
DEP = {}
for name, c in meta.items():
    if not name.endswith("-mainnet"): continue
    for d in c.get("deployments", []):
        if d.get("version") == 2 and d.get("stage") == "mainnet" and d.get("endpointV2"):
            DEP[c.get("chainKey")] = d

EIDNAME = {v: k for k, v in {
    "ethereum": 30101, "bsc": 30102, "avalanche": 30106, "polygon": 30109, "arbitrum": 30110,
    "optimism": 30111, "fantom": 30112, "apechain": 30312, "base": 30184, "linea": 30183,
    "mantle": 30181, "scroll": 30214, "mode": 30260, "blast": 30243, "sei": 30280,
    "solana": 30168, "ton": 30343, "aptos": 30108, "sui": 30378, "hyperliquid": 30367,
    "berachain": 30362, "sonic": 30332, "abstract": 30324, "plasma": 30383, "monad": 30390,
    "unichain": 30320, "worldchain": 30319, "hemi": 30329, "story": 30364, "katana": 30375,
    "lisk": 30321, "ink": 30339, "soneium": 30340, "zora": 30195, "opbnb": 30202,
}.items()}
def ename(e):
    n = EIDNAME.get(e)
    return f"{n}({e})" if n else f"eid{e}"

out = {}

def sweep_chain(cname, c):
    dep = DEP.get(c.get("key", cname))
    if not dep: return cname, [], f"=== {cname}: no v2 deployment"
    ruln = (dep.get("receiveUln302") or {}).get("address")
    if not ruln: return cname, [], f"=== {cname}: no receiveUln302"
    st, latest = rpc(c["rpc"], "eth_getBlockByNumber", ["latest", False])
    try: latest_n = int(latest["number"], 16)
    except Exception: latest_n = None
    logs, errs = [], []
    if latest_n is None:
        st2, lg = rpc(c["rpc"], "eth_getLogs", [{"address": ruln, "topics": [TOPIC_ULNCFG], "fromBlock": "0x0", "toBlock": "latest"}])
        if st2 == "OK": logs = lg
        else: errs.append(lg)
    else:
        step = 2_000_000
        fr = 0 if latest_n < 25_000_000 else max(latest_n - 20_000_000, 0)
        while fr <= latest_n:
            to = min(fr + step - 1, latest_n)
            while True:
                st2, lg = rpc(c["rpc"], "eth_getLogs", [{"address": ruln, "topics": [TOPIC_ULNCFG],
                              "fromBlock": hex(fr), "toBlock": hex(to)}])
                if st2 == "OK" and isinstance(lg, list):
                    logs += lg; break
                m_early = _re.search(r"earliest available block (\d+)", str(lg))
                if m_early:
                    fr = int(m_early.group(1)); continue
                m = err_max_range(lg)
                if m and step > m:
                    step = max(m, 50); to = min(fr + step - 1, latest_n); continue
                errs.append(f"[{fr}-{to}] {lg}"); break
            fr = to + 1
    lines=[f"\n=== {cname} recvUln={ruln} logs={len(logs)}"]
    if errs: lines.append("  getLogs errors:" + "".join("\n    "+e for e in errs[:3]))
    entries = []
    for lg in logs:
        tps = lg.get("topics", [])
        ws_ = words(lg.get("data","0x"))
        if len(tps) >= 3:
            oapp = "0x" + tps[1][26:]; eid = int(tps[2], 16)
        elif len(tps) == 1 and len(ws_) >= 2:
            oapp = "0x" + ws_[0][24:]; eid = int(ws_[1], 16)
        else:
            continue
        cfg = decode_cfg(lg.get("data","0x"), tps)
        if not cfg: continue
        flag = ""
        if cfg["requiredDVNCount"] == 255 and cfg["optionalDVNCount"] == 255: flag = "RESOLVED-EMPTY(DoS)"
        elif cfg["requiredDVNCount"] == 1: flag = f"SINGLE-REQ-DVN:{cfg['requiredDVNs'][0][:10]}"
        elif cfg["requiredDVNCount"] == 0: flag = f"NO-REQUIRED opt={cfg['optionalDVNCount']} thr={cfg['optionalDVNThreshold']}"
        if cfg["confirmations"] == 255: flag += " CONF=NIL"
        e = dict(oapp=oapp, src_eid=eid, src=ename(eid), **cfg, flag=flag.strip())
        entries.append(e)
        if flag: lines.append(f"  FLAG[{flag}] oapp={oapp} src={ename(eid)} conf={cfg['confirmations']} req={cfg['requiredDVNCount']} opt={cfg['optionalDVNCount']}/{cfg['optionalDVNThreshold']} dvns={[d[:10] for d in cfg['requiredDVNs']]+[d[:10] for d in cfg['optionalDVNs']]}")
    lines.append(f"  total custom-config entries: {len(entries)}")
    return cname, entries, "\n".join(lines)

from concurrent.futures import ThreadPoolExecutor, as_completed
with ThreadPoolExecutor(max_workers=7) as ex:
    futs = {ex.submit(sweep_chain, cn, c): cn for cn, c in CHAINS.items()}
    done = 0
    for fut in as_completed(futs):
        try:
            cname, entries, text = fut.result()
            out[cname] = entries
            print(text, flush=True)
        except Exception as exn:
            print(f"CHAINFAIL {futs[fut]}: {exn}", flush=True)
        done += 1
        json.dump(out, open("/tmp/opencode/ulncfg_events.json", "w"), indent=1)
print(f"\ndone {done}/13; saved /tmp/opencode/ulncfg_events.json")
