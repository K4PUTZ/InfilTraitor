#!/usr/bin/env python3
##
## scale_study.py — the MAXIMUM MAP SIZE study's tooling (roadmap step A1, 2026-10-07; planning gap 9 of the roadmap).
##
## THE QUESTION: a standard map size will be set and the maximum must come from measurement, before the procedural (Freelance) generator
## is designed. Known limits to read the table against: the ~46 GU cell-plane limit (`CellPlaneStore.SOOT_TEX_SIZE`: past it a cell
## "draws with no light or soot"), memory per GU after CLAIMS, load time, idle draw cost. This script finds where each one BENDS.
##
## WHAT IT DOES: for each size N it writes `maps/SCALE_<N>.map.json` (git-ignored; `gen_stress_map.build(N, N)`: the STRESS room grid,
## walls every 15 x 13 GU, props / guards / lights at STRESS's density per GU^2, or `--content empty` for walls + floor only, which
## separates what SIZE costs from what CONTENT costs), boots it with the same flags and scenario every time, and reads the engine's own
## log lines into ONE row per size:
##   store   `[VOXEL-STORE] built`: claims, MB, ms          board   `[BOARD3D]` first build: faces, quads, chunks, ms
##   load    wall seconds from launch to the first scenario step (boot + map load + warm; the engine boot is a constant)
##   idle    median `[FRAME-PROBE]` ms/frame and `process` ms in the windows BEFORE the blast, + draw calls / primitives / nodes
##   blast   `[E-FRAME] detonation` mean and WORST frame, `hit-stop` lines     plane   ERROR lines naming the cell plane
##   mem     desktop only: system-available MB at boot minus at "40 map loaded" (a proxy; the handset number is PSS from device_run.py)
##
## USAGE
##     python3 tools/persistent/scale_study.py                              # desktop: sizes 24,32,44,64,96,128, dense content
##     python3 tools/persistent/scale_study.py --sizes 44,64 --content empty --out docs/measurements/scale_desktop.md
##     python3 tools/persistent/scale_study.py --print 64                   # the dev_flags.cfg for a handset (needs --keep + a fresh export)
##     python3 tools/persistent/scale_study.py --parse run.log              # the same row from a saved log (a logcat from the Moto)
## ⚠️ A handset run needs the maps INSIDE the APK: generate with `--keep --no-run`, then `export_android.py`, then push the printed flags.
## ⚠️ Desktop numbers are a SHAPE, not a budget: where a curve bends on the desktop it bends on the Moto too, only 3-4x higher.

import argparse
import os
import re
import statistics
import subprocess
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import gen_stress_map  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
GODOT = "/Applications/Godot.app/Contents/MacOS/Godot"
DEFAULT_SIZES = [24, 32, 44, 64, 96, 128]


def map_id(n: int) -> str:
    return "SCALE_%03d" % n


def write_map(n: int, content: str) -> Path:
    import json
    path = ROOT / "maps" / (map_id(n) + ".map.json")
    path.write_text(json.dumps(gen_stress_map.build(n, n, 0.0 if content == "empty" else 1.0, map_id(n)), indent=1) + "\n")
    return path


def flags(n: int) -> dict:
    c = n // 2
    return {"MAP": map_id(n), "GRENADE_GUS": "%d,%d" % (c - 2, c + 1), "RNG_SEED": "1", "EVENT_FRAMES": "1", "FRAME_PROBE": "1",
            "MEM_STAGES": "1", "SCENARIO": "framing portrait; centre agent; zoom 0.5; wait 8; mark idle; detonate 0; wait 2; quit"}


def num(pattern: str, text: str, group: int = 1, flags_: int = 0):
    m = re.search(pattern, text, flags_)
    return float(m.group(group).replace(",", "")) if m else None


def parse(text: str, load_s=None) -> dict:
    row = {"load_s": load_s}
    m = re.search(r"\[VOXEL-STORE\] built .*? — (\d+) claim\(s\) in (\d+) container\(s\).*?([\d.]+) MB, (\d+) ms", text)
    if m:
        row.update(claims=int(m.group(1)), containers=int(m.group(2)), store_mb=float(m.group(3)), store_ms=int(m.group(4)))
    m = re.search(r"\[BOARD3D\] (\d+) voxel\(s\).*? → (\d+) face\(s\) → (\d+) quad\(s\) in (\d+) chunk\(s\).*?collect (\d+) ms, mesh (\d+)", text)
    if m:
        row.update(faces=int(m.group(2)), quads=int(m.group(3)), chunks=int(m.group(4)), board_ms=int(m.group(5)) + int(m.group(6)))
    pre = text.split("blast.request")[0] if "blast.request" in text else text.split("[E-PRESENT]")[0]
    probes = re.findall(r"\[FRAME-PROBE\] ([\d.]+) ms/frame .*?([\d]+) draw call\(s\) · (\d+) primitive\(s\) · (\d+) object\(s\) · process ([\d.]+) ms.*?· (\d+) node\(s\)", pre)
    if probes:
        row["idle_frame_ms"] = round(statistics.median(float(p[0]) for p in probes), 1)
        row["idle_process_ms"] = round(statistics.median(float(p[4]) for p in probes), 1)
        row["draw_calls"], row["primitives"], row["nodes"] = int(probes[-1][1]), int(probes[-1][2]), int(probes[-1][5])
    m = re.search(r"\[E-FRAME\] detonation — (\d+) frame\(s\), (\d+) ms wall clock, mean ([\d.]+) ms · WORST ([\d.]+) ms", text)
    if m:
        row.update(blast_mean_ms=float(m.group(3)), blast_worst_ms=float(m.group(4)))
    stages = re.findall(r"system available\s+([\d.]+) MB", text)
    boot = re.search(r"\[MEM-STAGE\] 00 .*?system available\s+([\d.]+) MB", text)
    loaded = re.search(r"\[MEM-STAGE\] 40 .*?system available\s+([\d.]+) MB", text)
    if boot and loaded:
        row["mem_mb"] = round(float(boot.group(1)) - float(loaded.group(1)), 0)
    row["plane_errors"] = len(re.findall(r"cell plane", text))
    row["errors"] = len([l for l in text.splitlines() if l.startswith(("ERROR", "SCRIPT ERROR")) and "resources still in use" not in l])
    return row


COLUMNS = [("size", "GU"), ("claims", "claims"), ("store_mb", "store MB"), ("store_ms", "store ms"), ("quads", "quads"),
           ("board_ms", "board ms"), ("load_s", "load s"), ("idle_frame_ms", "idle ms/f"), ("idle_process_ms", "idle proc"),
           ("draw_calls", "draws"), ("nodes", "nodes"), ("blast_mean_ms", "blast mean"), ("blast_worst_ms", "blast worst"),
           ("mem_mb", "mem MB"), ("plane_errors", "plane err"), ("errors", "ERR")]


def table(rows: list) -> str:
    def cell(r, k):
        v = r.get(k)
        return "-" if v is None else ("%g" % v if isinstance(v, float) else str(v))
    lines = ["| " + " | ".join(h for _, h in COLUMNS) + " |", "|" + "---|" * len(COLUMNS)]
    for r in rows:
        lines.append("| " + " | ".join(cell(r, k) for k, _ in COLUMNS) + " |")
    # the bend: cost per GU^2 against the smallest size, so a curve that is not linear shows as a ratio drifting from 1
    base = rows[0] if rows else None
    if base and len(rows) > 1:
        lines.append("")
        lines.append("Cost per GU^2 relative to the %d GU row (1.00 = linear; above = the curve bends up):" % base["size"])
        for k, h in (("claims", "claims"), ("store_ms", "store ms"), ("board_ms", "board ms"), ("load_s", "load s"), ("mem_mb", "mem MB")):
            if base.get(k):
                ratios = ["%d: %.2f" % (r["size"], (r[k] / (r["size"] ** 2)) / (base[k] / (base["size"] ** 2))) for r in rows if r.get(k)]
                lines.append("- %s — %s" % (h, ", ".join(ratios)))
    return "\n".join(lines)


def run(n: int, timeout: int) -> dict:
    env = dict(os.environ, **{"INFILTRAITOR_" + k: v for k, v in flags(n).items()})
    t0 = time.time()
    load = {"t": None}
    proc = subprocess.Popen([GODOT, "--path", str(ROOT)], env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    lines = []
    try:
        deadline = t0 + timeout
        for line in proc.stdout:
            lines.append(line)
            if load["t"] is None and "[SCENARIO] 1/" in line:
                load["t"] = time.time() - t0
            if time.time() > deadline:
                proc.kill()
                lines.append("ERROR: scale_study timeout after %d s\n" % timeout)
                break
    finally:
        proc.wait()
    row = parse("".join(lines), None if load["t"] is None else round(load["t"], 1))
    row["size"] = n
    return row


def main() -> int:
    ap = argparse.ArgumentParser(description="the map-size scaling study (see the header)")
    ap.add_argument("--sizes", default=",".join(str(s) for s in DEFAULT_SIZES))
    ap.add_argument("--content", choices=["dense", "empty"], default="dense")
    ap.add_argument("--timeout", type=int, default=420)
    ap.add_argument("--out", default="", help="also write the table to this markdown file")
    ap.add_argument("--keep", action="store_true", help="leave maps/SCALE_*.map.json in place (a handset export needs them)")
    ap.add_argument("--no-run", action="store_true", help="only write the maps")
    ap.add_argument("--print", type=int, default=0, metavar="N", help="print the dev_flags.cfg for size N and stop")
    ap.add_argument("--parse", default="", help="parse a saved log into one row and stop")
    args = ap.parse_args()
    if args.print:
        print("# SCALE %d — push to /sdcard/Android/data/<package>/files/dev_flags.cfg (maps/%s.map.json must be in the APK)" % (
            args.print, map_id(args.print)))
        for k, v in flags(args.print).items():
            print("%s=%s" % (k, v))
        return 0
    if args.parse:
        row = parse(Path(args.parse).read_text(errors="ignore"))
        row["size"] = 0
        print(table([row]))
        return 0
    sizes = [int(x) for x in args.sizes.split(",") if x.strip()]
    written = [write_map(n, args.content) for n in sizes]
    rows = []
    try:
        if not args.no_run:
            for n in sizes:
                print("[SCALE] %d x %d (%s content) ..." % (n, n, args.content), flush=True)
                rows.append(run(n, args.timeout))
    finally:
        if not args.keep:
            for p in written:
                p.unlink(missing_ok=True)
    if rows:
        out = "## Scale study — %s content, desktop, %s\n\n%s\n" % (args.content, time.strftime("%Y-%m-%d"), table(rows))
        print(out)
        if args.out:
            Path(ROOT / args.out).write_text(out)
    return 1 if any(r.get("errors") for r in rows) else 0


if __name__ == "__main__":
    sys.exit(main())
