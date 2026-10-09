#!/usr/bin/env python3
##
## pb3_study.py — PERFORMANCE_BUDGET PB-3: the MARGINAL-COST table, one content kind at a time, on segment-shaped maps.
##
## THE QUESTION: what does each kind of content cost on the floor device (the Moto g04s), so PB-5 can judge the `segment_spec`
## against the exit criterion (§0d: HEAVY fits with PSS <= 1.0 GiB, play frames <= 33.3 ms with the content in view, ...)?
##
## WHAT IT DOES: writes one `maps/SEG_<variant>.map.json` per variant with `gen_segment_map.py` (git-ignored) — BASE (the rooms
## and materials of TYPICAL, nothing else), one sweep per kind on top of BASE, and the three specs — then boots each with the same
## flags and scenario and reads ONE row from the engine's log (`scale_study.parse`: store, board, idle frame / process / draws,
## blast mean / worst) plus, on a handset, the `[MEM-POLL]` peaks (TOTAL PSS, GL mtrack, native heap; MiB) and the load seconds
## (`[RNG] seeded` -> the first scenario step, the device clock). A row minus the BASE row is that kind's marginal cost.
##
## USAGE
##     python3 tools/persistent/pb3_study.py --write                     # only (re)write the maps (before an export)
##     python3 tools/persistent/pb3_study.py --device ZF524T5TG5         # every variant on the handset (the APK must hold the maps)
##     python3 tools/persistent/pb3_study.py --device ZF524T5TG5 --only BASE,P30 --boots 2
##     python3 tools/persistent/pb3_study.py                             # the same on the desktop (a SHAPE, not a budget)
## ⚠️ Handset: `--write`, then `export_android.py --install`, then run. The flags file is removed after each variant.
## ⚠️ Idle is measured UNCAPPED (`MAX_FPS=0`): under the 30 fps cap every frame that fits reads 33.3 ms.

import argparse
import json
import re
import subprocess
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import gen_segment_map as seg  # noqa: E402
import scale_study  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
SCRATCH = ROOT / "docs" / "measurements"   ## logs land here, git-ignored like the other device logs

## (variant, base spec, overrides): BASE first, so every sweep row can be read against it
VARIANTS = [("BASE", "BASE", {})]
VARIANTS += [("P%d" % n, "BASE", {"props": n}) for n in (15, 30, 60, 100)]
VARIANTS += [("G%d" % n, "BASE", {"guards": n}) for n in (4, 6, 10, 24)]
VARIANTS += [("L%d" % n, "BASE", {"lights": n}) for n in (3, 6, 10)]
VARIANTS += [("GL%d" % n, "BASE", {"glass": n}) for n in (4, 8, 12)]
VARIANTS += [("R%d" % n, "BASE", {"roofs": n}) for n in (1, 2, 3)]
VARIANTS += [("M%d" % n, "BASE", {"materials": n}) for n in (4, 9)]
VARIANTS += [(n, n, {}) for n in ("LOW", "TYPICAL", "HEAVY")]

## the grenade lands in the middle of the segment, beside the agent (agent at 9,18)
GRENADE = "8,21"
SCENARIO = "framing portrait; centre agent; zoom 0.5; wait 10; mark idle; detonate 0; wait 5; quit"


def map_id(v: str) -> str:
    return "SEG_" + v


## The GPU attribution (PERFORMANCE_BUDGET §0d: the segment valve does not reach the per-frame GPU floor). One map, one thing
## hidden per row through `HIDE_NODES` / `HIDE_NON_VOXEL` (room.gd `_apply_perf_ablations`), plus two controls: PLAYGROUND at
## the same zoom (is it the build or the segment?) and the standard zoom 0.75.
ABLATIONS = [
    ("ctl_PLAYGROUND_z05", "PLAYGROUND", {}, 0.5),
    ("ctl_PLAYGROUND_z075", "PLAYGROUND", {}, 0.75),
    ("seg_z075", "SEG_BASE", {}, 0.75),
    ("seg_none", "SEG_BASE", {}, 0.5),
    ("seg_hide_non_voxel", "SEG_BASE", {"HIDE_NON_VOXEL": "1"}, 0.5),
    ("seg_hide_geometry", "SEG_BASE", {"HIDE_NODES": "Geometry"}, 0.5),
    ("seg_hide_fog", "SEG_BASE", {"HIDE_NODES": "FogRect"}, 0.5),
    ("seg_hide_canvases3d", "SEG_BASE", {"HIDE_NODES": "GroundCanvas3D,WorldCanvas3D"}, 0.5),
    ("seg_hide_hud", "SEG_BASE", {"HIDE_NODES": "HUD"}, 0.5),
    ("seg_hide_contact", "SEG_BASE", {"HIDE_NODES": "ContactShadow"}, 0.5),
]


def flags(v: str, zoom: float = 0.5) -> dict:
    return {"MAP": map_id(v), "GRENADE_GUS": GRENADE, "RNG_SEED": "1", "EVENT_FRAMES": "1", "FRAME_PROBE": "1", "MEM_STAGES": "1",
            "MAX_FPS": "0", "SCENARIO": SCENARIO.replace("zoom 0.5", "zoom %g" % zoom)}


def write_all() -> None:
    for v, base, over in VARIANTS:
        seg.write(seg.spec_from(base, **over), map_id(v))
    print("[PB-3] wrote %d maps (maps/SEG_*.map.json)" % len(VARIANTS))


def mib(text: str, key: str):
    vals = [int(m) / 1024.0 for m in re.findall(re.escape(key) + r"\s+(\d+)", text)]
    return round(max(vals)) if vals else None


def device_extra(text: str) -> dict:
    out = {}
    pre = text.split("[SCENARIO] 6/")[0]
    gpu = [float(g) for g in re.findall(r"\[FRAME-PROBE\].*?render gpu ([\d.]+) ms", pre)]
    if gpu:
        out["idle_gpu_ms"] = round(sorted(gpu)[len(gpu) // 2], 1)
    polls = "\n".join(l for l in text.splitlines() if "[MEM-POLL]" in l)
    out["pss_mib"] = mib(polls, "TOTAL PSS:")
    out["gl_mib"] = mib(polls, "GL mtrack")
    out["native_mib"] = mib(polls, "Native Heap")
    t0 = re.search(r"(\d\d):(\d\d):(\d\d)\.(\d+).*\[RNG\] seeded", text)
    t1 = re.search(r"(\d\d):(\d\d):(\d\d)\.(\d+).*\[SCENARIO\] 1/", text)
    if t0 and t1:
        s = lambda m: int(m.group(1)) * 3600 + int(m.group(2)) * 60 + int(m.group(3)) + float("0." + m.group(4))
        out["load_s"] = round(s(t1) - s(t0), 1)
    return out


def run_device(serial: str, v: str, boot: int, f: dict = None) -> dict:
    import device_run
    adb = device_run._find_adb()
    files = "/sdcard/Android/data/%s/files" % device_run.PACKAGE
    cfg = Path("/tmp/pb3_dev_flags.cfg")
    cfg.write_text("".join("%s=%s\n" % kv for kv in (f or flags(v)).items()))
    log = SCRATCH / ("device_pb3_%s_%s_%d.log" % (serial[:6], v, boot))
    try:
        subprocess.run([adb, "-s", serial, "push", str(cfg), files + "/dev_flags.cfg"], check=True, capture_output=True)
        subprocess.run([sys.executable, str(ROOT / "tools/persistent/device_run.py"), "--device", serial, "--seconds", "110",
                        "--mem-poll", "2", "--save", str(log)], capture_output=True, text=True)
    finally:
        subprocess.run([adb, "-s", serial, "shell", "rm", "-f", files + "/dev_flags.cfg"], capture_output=True)
    text = log.read_text(errors="ignore") if log.exists() else ""
    row = scale_study.parse(text)
    row.update(device_extra(text))
    if "[SCENARIO] 1/" not in text:
        row["errors"] = (row.get("errors") or 0) + 1
    return row


def run_desktop(v: str) -> dict:
    env_flags = flags(v)
    row = None
    import os
    env = dict(os.environ, **{"INFILTRAITOR_" + k: val for k, val in env_flags.items()})
    t0 = time.time()
    proc = subprocess.run([scale_study.GODOT, "--path", str(ROOT)], env=env, capture_output=True, text=True, timeout=400)
    text = proc.stdout + proc.stderr
    row = scale_study.parse(text, None)
    row["wall_s"] = round(time.time() - t0, 1)
    return row


COLS = [("variant", "variant"), ("claims", "claims"), ("store_ms", "store ms"), ("quads", "quads"), ("load_s", "load s"),
        ("pss_mib", "PSS MiB"), ("gl_mib", "GL MiB"), ("native_mib", "native MiB"), ("idle_frame_ms", "idle ms/f"), ("idle_gpu_ms", "idle gpu"),
        ("idle_process_ms", "idle proc"), ("draw_calls", "draws"), ("blast_mean_ms", "blast mean"),
        ("blast_worst_ms", "blast worst"), ("errors", "ERR")]


def table(rows: list) -> str:
    def cell(r, k):
        v = r.get(k)
        return "-" if v is None else ("%g" % v if isinstance(v, float) else str(v))
    out = ["| " + " | ".join(h for _, h in COLS) + " |", "|" + "---|" * len(COLS)]
    out += ["| " + " | ".join(cell(r, k) for k, _ in COLS) + " |" for r in rows]
    return "\n".join(out)


def main() -> int:
    ap = argparse.ArgumentParser(description="PB-3 marginal-cost table (see the header)")
    ap.add_argument("--write", action="store_true", help="only write the maps")
    ap.add_argument("--device", default="", help="adb serial; empty = desktop")
    ap.add_argument("--only", default="", help="comma-separated variants")
    ap.add_argument("--boots", type=int, default=1)
    ap.add_argument("--gpu-ablation", action="store_true", help="the GPU attribution rows (ABLATIONS) instead of the variants")
    ap.add_argument("--out", default="", help="also write the table (and the raw rows as JSON next to it)")
    args = ap.parse_args()
    if args.write:
        write_all()
        return 0
    rows = []
    if args.gpu_ablation:
        for label, m, extra, zoom in ABLATIONS:
            if args.only and label not in args.only.split(","):
                continue
            f = flags("X", zoom)
            f["MAP"] = m
            f.update(extra)
            for b in range(1, args.boots + 1):
                row = run_device(args.device, label, b, f)
                row["variant"] = label if args.boots == 1 else "%s #%d" % (label, b)
                rows.append(row)
                print("[PB-3] %s" % json.dumps(row), flush=True)
        print(table(rows))
        if args.out:
            Path(args.out).write_text(table(rows) + "\n")
            Path(args.out).with_suffix(".json").write_text(json.dumps(rows, indent=1) + "\n")
        return 0
    wanted = [v for v, _, _ in VARIANTS if not args.only or v in args.only.split(",")]
    for v in wanted:
        for b in range(1, args.boots + 1):
            row = run_device(args.device, v, b) if args.device else run_desktop(v)
            row["variant"] = v if args.boots == 1 else "%s #%d" % (v, b)
            rows.append(row)
            print("[PB-3] %s" % json.dumps(row), flush=True)
    text = table(rows)
    print(text)
    if args.out:
        Path(args.out).write_text(text + "\n")
        Path(args.out).with_suffix(".json").write_text(json.dumps(rows, indent=1) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
