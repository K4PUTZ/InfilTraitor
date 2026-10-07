#!/usr/bin/env python3
##
## surfaces_gallery.py — boots the R3D-SURFACES art rooms in a real window and brings back what the art looks like in runtime:
## `SURFACES_GALLERY` (the photographic grounds with their patch rows, a transition pad, the human floors with the agent as the scale
## reference, the industrial floors) and `SURFACES_LAB` (the carpet matrix, five patterns x ten colours). One overview and close-ups per
## band, and the overview again from the E side (rotation is camera-only: the decals must follow it). It stitches a contact sheet to
## `Screenshots/surfaces/gallery_sheet.png`. No grenade, no shot: every mark is placed by the map (`gen_surfaces_gallery.py`, which this
## script re-runs first).
##
## It fails on what a gallery can prove at runtime: a SCRIPT ERROR, ANY `ERROR: [` line of the engine (a cell outside the light plane, a
## patch the rules forbid, a kind without art...: a gallery that boots with an error is not showing the truth), a capture that was not
## written, or a capture that is a flat colour.
##
##     python3 tools/persistent/surfaces_gallery.py [--zoom 0.7] [--tag name]

import argparse
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools" / "persistent"))
import gen_surfaces_gallery as gen  # noqa: E402

GODOT = "/Applications/Godot.app/Contents/MacOS/Godot"
CAPTURES = Path.home() / "Library/Application Support/Godot/app_userdata/INFILTRAITOR/captures"
OUT = ROOT / "Screenshots" / "surfaces"
BUFFER = 5
TAG = "[GALLERY]"


def scenario_gallery(tag: str, zoom: float) -> tuple[str, list[str]]:
    steps = ["framing desktop", "frames 40"]
    names = []

    def shot(name: str, cx: float, cy: float, z: float) -> None:
        steps.extend(["centre %d,%d" % (cx + BUFFER, cy + BUFFER), "zoom %.2f" % z, "frames 30", "capture %s_%s" % (tag, name)])
        names.append(name)
    mid_x = gen.COLUMN_X0 + gen.COLUMN_W * len(gen.BASES) / 2.0
    mid_y = gen.COLUMN_Y0 + gen.INNER_GALLERY[1] / 2.0 - 2.0
    shot("overview", mid_x, mid_y, 0.12)
    rows_y = gen.ROW_Y0 + (max(len(gen.single_decal_kinds()), 1) - 1) * gen.ROW_STEP / 2.0
    for c, base in enumerate(gen.BASES):
        shot(base, gen.COLUMN_X0 + c * gen.COLUMN_W + gen.COLUMN_W / 2.0, rows_y, zoom)
    for name, (x0, _fn) in gen.PAD_SHAPES.items():
        shot("pad_" + name, x0 + gen.PAD_W / 2.0, gen.PAD_Y0 + gen.PAD_H / 2.0, zoom * 0.8)
    hy = gen.HUMAN_Y0 + gen.HUMAN_H / 2.0
    shot("human_wide", gen.COLUMN_X0 + gen.HUMAN_W * len(gen.HUMAN) / 2.0, hy, 0.3)
    for i, mat in enumerate(gen.HUMAN):
        shot("human_" + mat, gen.COLUMN_X0 + i * gen.HUMAN_W + gen.HUMAN_W / 2.0, hy, zoom)
    iy = gen.IND_Y0 + gen.IND_H / 2.0
    shot("ind_wide", gen.COLUMN_X0 + gen.IND_W * len(gen.INDUSTRIAL) / 2.0, iy, 0.3)
    for i, mat in enumerate(gen.INDUSTRIAL):
        shot("ind_" + mat, gen.COLUMN_X0 + i * gen.IND_W + gen.IND_W / 2.0, iy, zoom * 1.4)
    ## the real openings, first clean (a few frames: the steam has not built up), then with the plumes (150 fixed frames = 2.5 s)
    mid_open_x = gen.COLUMN_X0 + gen.IND_W * 1.5 + 2.0
    shot("ind_open", mid_open_x, iy - 1.0, zoom * 1.2)
    steps.extend(["frames 150", "capture %s_ind_steam" % tag])
    names.append("ind_steam")
    steps.extend(["centre agent", "zoom 1.6", "frames 30", "capture %s_agent_scale" % tag])
    names.append("agent_scale")
    steps.extend(["centre %d,%d" % (mid_x + BUFFER, mid_y + BUFFER), "zoom 0.12", "perspective E", "frames 40",
                  "capture %s_overview_E" % tag, "quit"])
    names.append("overview_E")
    return "; ".join(steps), names


def scenario_lab(tag: str) -> tuple[str, list[str]]:
    steps = ["framing desktop", "frames 40"]
    names = []
    ly = gen.LAB_Y0 + len(gen.CARPET_COLOURS) * gen.LAB_ROW_H / 2.0
    for i, mat in enumerate(gen.LAB):
        steps.extend(["centre %d,%d" % (gen.COLUMN_X0 + i * gen.LAB_W + gen.LAB_W / 2.0 + BUFFER, ly + BUFFER), "zoom 0.26", "frames 30",
                      "capture %s_lab_%s" % (tag, mat)])
        names.append("lab_" + mat)
    steps.append("quit")
    return "; ".join(steps), names


def scenario_scatter(tag: str) -> tuple[str, list[str]]:
    steps = ["framing desktop", "frames 40"]
    names = []

    def shot(name: str, cx: float, cy: float, z: float) -> None:
        steps.extend(["centre %d,%d" % (cx + BUFFER, cy + BUFFER), "zoom %.2f" % z, "frames 30", "capture %s_%s" % (tag, name)])
        names.append(name)
    shot("sc_overview", 22, 14, 0.15)
    for name, (x, y, w, h) in gen.SCATTER_ROOMS.items():
        shot("sc_" + name, x + w / 2.0, y + h / 2.0, 0.34)
    for i, (x, y, w, h, density) in enumerate(gen.SCATTER_LADDER):
        shot("sc_ladder_%d" % i, x + w / 2.0, y + h / 2.0, 0.34)
    steps.extend(["perspective E", "frames 40", "capture %s_sc_overview_E" % tag, "quit"])
    names.append("sc_overview_E")
    return "; ".join(steps), names


def run_map(map_id: str, scen: str, names: list[str], tag: str, problems: list[str]) -> list:
    from PIL import Image
    for n in names:
        (CAPTURES / ("%s_%s.png" % (tag, n))).unlink(missing_ok=True)
    env = {**os.environ, "INFILTRAITOR_MAP": map_id, "INFILTRAITOR_RNG_SEED": "1", "INFILTRAITOR_SCENARIO": scen}
    log = ""
    for attempt in (1, 2):
        try:
            out = subprocess.run([GODOT, "--path", str(ROOT), "--fixed-fps", "60", "--position", "4000,4000"],
                                 capture_output=True, text=True, env=env, timeout=150)
            log = out.stdout + out.stderr
            break
        except subprocess.TimeoutExpired:
            ## An intermittent engine hang, seen twice in about twelve boots (2026-10-06): the process sits at ~100 % CPU after the
            ## scenario's `quit` and never exits; eight reruns did not reproduce it. Said out loud, retried once, never hidden.
            subprocess.run(["pkill", "-9", "-f", "MacOS/Godot"])
            print("%s WARNING: %s hung (no exit in 150 s) on attempt %d%s" % (TAG, map_id, attempt, ", retrying once" if attempt == 1 else ""))
            if attempt == 2:
                problems.append("%s: the engine hung twice (no exit in 150 s)" % map_id)
    if "SCRIPT ERROR" in log:
        problems.append("%s: a SCRIPT ERROR in the log" % map_id)
    for line in log.splitlines():
        if "ERROR: [" in line:
            problems.append("%s: %s" % (map_id, line.strip()))
    images = []
    for n in names:
        p = CAPTURES / ("%s_%s.png" % (tag, n))
        if not p.exists():
            problems.append("%s: capture %s was not written" % (map_id, n))
            continue
        im = Image.open(p).convert("RGB")
        if len(im.resize((64, 36)).getcolors(64 * 36)) < 40:
            problems.append("%s: capture %s is (nearly) a flat colour: the board did not draw" % (map_id, n))
        im.save(OUT / ("%s_%s.png" % (tag, n)))
        images.append(im)
    return images


def main() -> int:
    ap = argparse.ArgumentParser(description="Boot the surfaces art rooms and bring back a contact sheet (see the header)")
    ap.add_argument("--zoom", type=float, default=0.7, help="close-up zoom per band")
    ap.add_argument("--tag", default="gallery")
    args = ap.parse_args()
    try:
        from PIL import Image
    except ImportError:
        print("%s ERROR: needs Pillow (pip install pillow)" % TAG)
        return 2
    for map_id, path in gen.MAP_PATHS.items():
        path.write_text(__import__("json").dumps(gen.build(map_id), indent=1) + "\n")
    OUT.mkdir(parents=True, exist_ok=True)
    problems: list[str] = []
    images = []
    all_names = []
    for map_id, (scen, names) in (("SURFACES_GALLERY", scenario_gallery(args.tag, args.zoom)), ("SURFACES_LAB", scenario_lab(args.tag)),
                                  ("SURFACES_SCATTER", scenario_scatter(args.tag))):
        images += run_map(map_id, scen, names, args.tag, problems)
        all_names += names
    if images:
        w, h = images[0].size
        cols = 3
        rows = (len(images) + cols - 1) // cols
        sheet = Image.new("RGB", (w * cols, h * rows))
        for i, im in enumerate(images):
            sheet.paste(im, ((i % cols) * w, (i // cols) * h))
        sheet.save(OUT / ("%s_sheet.png" % args.tag))
        print("%s sheet: %s (%d capture(s): %s)" % (TAG, (OUT / ("%s_sheet.png" % args.tag)).relative_to(ROOT), len(images), ", ".join(all_names)))
    for p in problems:
        print("%s PROBLEM: %s" % (TAG, p))
    print("%s %s" % (TAG, "PASSED" if not problems else "FAILED"))
    return 0 if not problems else 1


if __name__ == "__main__":
    sys.exit(main())
