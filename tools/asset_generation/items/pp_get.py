"""ITEMS_MASTER_PLAN §3 — Download Poly Pizza models (CC0 checked again on the model's own page) into <dest>/<group>/<Title>-<id>.glb + one ATTRIBUTION.txt per group.
Usage: python3 -I pp_get.py <dest_root> <list.txt>   (list lines: group id; '#' comments)"""
import os, re, subprocess, sys, time, datetime


def get(url, binary=False):
    out = subprocess.run(["curl", "-sL", "--fail", "--max-time", "60", "-A", "Mozilla/5.0", url], capture_output=True, check=True).stdout
    return out if binary else out.decode("utf-8", "replace")


dest, listing = sys.argv[1], sys.argv[2]
today = datetime.date.today().isoformat()
records = {}
for line in open(listing):
    line = line.split("#")[0].strip()
    if not line:
        continue
    group, mid = line.split()
    folder = os.path.join(dest, group)
    os.makedirs(folder, exist_ok=True)
    try:
        h = get("https://poly.pizza/m/" + mid)
    except subprocess.CalledProcessError:
        print("FAIL page", group, mid); continue
    lic = (re.search(r'"Licence":"([^"]+)"', h) or [None, ""])[1]
    title = (re.search(r'"Title":"([^"]+)"', h) or [None, mid])[1]
    creator = (re.search(r'"Creator":\{"Username":"([^"]+)"', h) or [None, "?"])[1]
    glb = re.search(r'(https://static\.poly\.pizza/[0-9a-f-]{36}\.glb)', h)
    if not lic.startswith("CC0") or glb is None:
        print("SKIP", group, mid, title, lic or "no licence", "" if glb else "no glb"); continue
    if creator.lower() == "kenney":
        print("SKIP (Kenney)", group, mid, title); continue
    name = re.sub(r"[^A-Za-z0-9]+", "_", title).strip("_") + "-" + mid + ".glb"
    path = os.path.join(folder, name)
    if not os.path.exists(path):
        data = get(glb.group(1), binary=True)
        if data[:4] != b"glTF":
            print("BAD (not a glb)", group, mid); continue
        open(path, "wb").write(data)
        time.sleep(1.5)
    records.setdefault(group, []).append((name, title, creator, mid, lic, os.path.getsize(path)))
    print("OK  %-14s %-40s %-14s %7.1f KB" % (group, name, creator, os.path.getsize(path) / 1024.0))

for group, rows in records.items():
    with open(os.path.join(dest, group, "ATTRIBUTION.txt"), "w") as f:
        f.write("Downloaded %s for INFILTRAITOR (ITEMS_MASTER_PLAN phase 1). Every model checked CC0 on its own Poly Pizza page.\n"
                "No attribution legally required (CC0); credited anyway. ASSETS/ is git-ignored: the tracked record is props/MODEL_SOURCES.md.\n\n" % today)
        for name, title, creator, mid, lic, size in rows:
            f.write("%s | \"%s\" by %s | https://poly.pizza/m/%s | %s | %.1f KB\n" % (name, title, creator, mid, lic, size / 1024.0))
