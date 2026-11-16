"""ITEMS_MASTER_PLAN §3 — Scan Poly Pizza search pages: for each term, every model's title, creator, licence, triangles, glb url. CC0 only in the output.
Usage: python3 -I pp_scan.py out.json term1 term2 ..."""
import json, re, sys, time, urllib.request, urllib.parse, concurrent.futures as cf

UA = {"User-Agent": "Mozilla/5.0"}


import subprocess
def get(url):
    return subprocess.run(["curl", "-sL", "--max-time", "30", "-A", "Mozilla/5.0", url], capture_output=True, check=True).stdout.decode("utf-8", "replace")


def model(mid):
    try:
        h = get("https://poly.pizza/m/" + mid)
    except Exception as e:
        return {"id": mid, "error": str(e)}
    def f(pat):
        m = re.search(pat, h)
        return m.group(1) if m else ""
    glb = f(r'(https://static\.poly\.pizza/[0-9a-f-]{36}\.glb)')
    return {"id": mid, "title": f(r'"Title":"([^"]+)"'), "creator": f(r'"Creator":\{"Username":"([^"]+)"'),
            "licence": f(r'"Licence":"([^"]+)"'), "tris": int(f(r'"Tris":(\d+)') or 0), "glb": glb}


out = {}
for term in sys.argv[2:]:
    try:
        h = get("https://poly.pizza/search/" + urllib.parse.quote(term))
    except Exception as e:
        print(term, "ERR", e); continue
    time.sleep(3)
    ids = sorted(set(re.findall(r'/m/([A-Za-z0-9_-]{8,12})', h)))
    if len(ids) <= 1:   # throttled: wait and try once more
        time.sleep(30)
        h = get("https://poly.pizza/search/" + urllib.parse.quote(term))
        ids = sorted(set(re.findall(r'/m/([A-Za-z0-9_-]{8,12})', h)))
    with cf.ThreadPoolExecutor(3) as ex:
        rows = list(ex.map(model, ids))
    cc0 = [r for r in rows if r.get("licence", "").startswith("CC0")]
    out[term] = cc0
    print("%-22s %3d results, %3d CC0" % (term, len(rows), len(cc0)))
    for r in sorted(cc0, key=lambda r: r["creator"] != "Quaternius"):
        print("    %-34s %-18s %6d tris  %s" % (r["title"][:34], r["creator"][:18], r["tris"], r["id"]))
json.dump(out, open(sys.argv[1], "w"), indent=1)
