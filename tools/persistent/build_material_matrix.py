#!/usr/bin/env python3
"""
build_material_matrix.py — M3-5: one grenade and one shot on every material,
as a table.

MATERIALS_MASTER_PLAN M3-5. The numbers this prints have been produced by hand
half a dozen times across the materials milestone — the cascade calibration, the
MAT-SOFT-01 tier proof, the burn measurements, the plywood falloff. Each time
they were assembled from a different ad-hoc command line, which is how two runs
end up not being comparable.

WHAT IT MEASURES, per material, from a REAL boot of the REAL map:

  GRENADE   `[E-PLAN]` census (destroyed / dented / cracked per surface),
            `[E-EMBER]` how many voxels caught, `[E-BURN]` how many burn away
            and over how long, and the passage the fire opened.
  SHOT      `[AGENT-SHOT-TIER]` per material and depth, with the material's
            resistance and breach threshold.

⚠️ EVERY CELL IS A REAL BOOT, which is why this takes minutes rather than
seconds. That is the point: CLAUDE.md's floor-dent case (69 dents on a synthetic
patch, zero on PLAYGROUND) is exactly what a fixture-based matrix would have
missed, and the MAT-SOFT-01 and burn-column bugs this milestone found were both
invisible until something ran the real path and read the real counts.

The geometry is derived from `maps/PLAYGROUND.map.json`, never hardcoded: the
material blocks have moved twice already (the 44x22 reform, then the five new
materials at step 4 instead of 5), and a table pointing at where they used to be
would report zeroes that look like findings.

Usage:
    python3 tools/persistent/build_material_matrix.py                # every material
    python3 tools/persistent/build_material_matrix.py brick plywood  # just these
    python3 tools/persistent/build_material_matrix.py --grenade-only
"""

import json
import os
import re
import subprocess
import sys

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
GODOT = "/Applications/Godot.app/Contents/MacOS/Godot"
MAP = os.path.join(REPO_ROOT, "maps", "PLAYGROUND.map.json")
OUT = os.path.join(REPO_ROOT, "Screenshots", "material_matrix.md")

## Far enough that the blast has to travel — the distance the arsenal was
## calibrated at — and directly in front of the block so every material is hit
## the same way. The plywood falloff measurement (M3-4) is what makes "the same
## way" load-bearing: consumption varies with distance, so a table where one
## material sat closer than another would be comparing two different questions.
GRENADE_ROWS_BELOW = 3
AGENT_ROWS_BELOW = 8
GUARD_ROWS_BELOW = 3


def blocks_by_material():
    """{material: [gu, ...]} from the real map, in map-internal coords."""
    spec = json.load(open(MAP))
    out = {}
    for item in spec["sections"]["blocks"]["items"]:
        out.setdefault(item["material"], []).append(tuple(item["gu"]))
    return out


def _run(env_extra, quit_after):
    env = os.environ.copy()
    env["INFILTRAITOR_AUTO_SCREENSHOT"] = "1"
    env["INFILTRAITOR_SCREENSHOT_ONCE"] = "1"
    env.update(env_extra)
    proc = subprocess.run(
        [GODOT, "--path", REPO_ROOT, "--position", "4000,4000",
         "--quit-after", str(quit_after)],
        cwd=REPO_ROOT, env=env, capture_output=True, text=True, timeout=180,
    )
    return proc.stdout + proc.stderr


def grenade_row(material, gu):
    """One detonation in front of `material`'s block."""
    cell = "%d,%d" % (gu[0] + 1, gu[1] + GRENADE_ROWS_BELOW)
    text = _run({
        "INFILTRAITOR_CAPTURE_ACTION": "test_zone_detonate",
        "INFILTRAITOR_GRENADE_GUS": cell,
        "INFILTRAITOR_CAPTURE_DETONATE_WAIT_FRAMES": "400",
    }, 900)

    census = {}
    for line in text.splitlines():
        m = re.search(r"\[E-PLAN\]\s+(\S+)\s+destroyed\s+(\d+) · dented\s+(\d+) · cracked\s+(\d+)", line)
        if m and m.group(1).endswith("/" + material):
            surface = m.group(1).split("/")[0]
            census[surface] = (int(m.group(2)), int(m.group(3)), int(m.group(4)))
    ember = re.search(r"\[E-EMBER\] (\d+) ember", text)
    burn = re.search(r"\[E-BURN\] (\d+) voxel\(s\) scheduled to burn AWAY, last at ([\d.]+)s", text)
    passage = re.search(r"passage over \d+ burnt edge\(s\): (\{[^}]*\})", text)
    return {
        "cell": cell,
        "census": census,
        "ember": int(ember.group(1)) if ember else 0,
        "burn": int(burn.group(1)) if burn else 0,
        "burn_s": float(burn.group(2)) if burn else 0.0,
        "passage": passage.group(1).strip() if passage else "—",
    }


def shot_row(material, gu):
    """One forced-miss shotgun burst into `material`'s block."""
    x = gu[0] + 1
    text = _run({
        "INFILTRAITOR_CAPTURE_ACTION": "agent_shot",
        "INFILTRAITOR_SHOT_AGENT_CELL": "%d,%d" % (x, gu[1] + AGENT_ROWS_BELOW),
        "INFILTRAITOR_SHOT_GUARD_CELL": "%d,%d" % (x, gu[1] + GUARD_ROWS_BELOW),
        "INFILTRAITOR_SHOT_TAG": "matrix_%s" % material,
    }, 600)
    rows = []
    for line in text.splitlines():
        m = re.search(
            r"\[AGENT-SHOT-TIER\]\s+(\S+)\s+cracked=\s*(\d+) dented=\s*(\d+) destroyed=\s*(\d+)\s+\(resist ([\d.]+), breach ([\d.]+)\)",
            line)
        if m and m.group(1).split(":")[0] == material:
            rows.append({"depth": m.group(1), "cracked": int(m.group(2)),
                         "dented": int(m.group(3)), "destroyed": int(m.group(4)),
                         "resist": float(m.group(5)), "breach": float(m.group(6))})
    return rows


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    grenade_only = "--grenade-only" in sys.argv
    if not os.path.isfile(GODOT):
        print("[MATRIX] Godot not found at %s" % GODOT)
        return 2

    blocks = blocks_by_material()
    materials = args or sorted(blocks)
    missing = [m for m in materials if m not in blocks]
    if missing:
        print("[MATRIX] no block on PLAYGROUND for: %s" % ", ".join(missing))
        print("[MATRIX] the map has: %s" % ", ".join(sorted(blocks)))
        return 1

    lines = ["# Material matrix — M3-5",
             "",
             "Every row is a REAL boot of PLAYGROUND. Regenerate with",
             "`python3 tools/persistent/build_material_matrix.py`.",
             "",
             "## Grenade",
             "",
             "⚠️ `lit` and `burns` are BLAST TOTALS, not per-material: `[E-EMBER]` and",
             "`[E-BURN]` count the whole detonation. The census columns beside them ARE",
             "per-material. It shows: the `glass` row reads 1 lit with glass at",
             "flammability 0.0 — that ember is a plywood cell three GU away, inside the",
             "same blast. Read the two halves of this table as answering different",
             "questions, or make the prints per-material first.",
             "",
             "| material | at | WALL d/dt/ck | FLOOR d/dt/ck | lit* | burns* | over | passage |",
             "|---|---|---|---|---|---|---|---|"]
    print("\n".join(lines[5:]))


    shot_lines = ["", "## Shot (shotgun, forced miss)", "",
                  "| material | depth | cracked | dented | destroyed | resist | breach |",
                  "|---|---|---|---|---|---|---|"]

    for material in materials:
        gu = sorted(blocks[material])[0]
        g = grenade_row(material, gu)
        wall = g["census"].get("WALL", (0, 0, 0))
        floor = g["census"].get("FLOOR", (0, 0, 0))
        row = "| `%s` | %s | %d/%d/%d | %d/%d/%d | %d | %d | %.2fs | %s |" % (
            material, g["cell"], wall[0], wall[1], wall[2],
            floor[0], floor[1], floor[2], g["ember"], g["burn"], g["burn_s"], g["passage"])
        lines.append(row)
        print(row)

        if not grenade_only:
            for r in shot_row(material, gu):
                srow = "| `%s` | %s | %d | %d | %d | %.2f | %.2f |" % (
                    material, r["depth"], r["cracked"], r["dented"], r["destroyed"],
                    r["resist"], r["breach"])
                shot_lines.append(srow)

    lines.extend(shot_lines)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    open(OUT, "w").write("\n".join(lines) + "\n")
    print("\n".join(shot_lines))
    print("\n[MATRIX] wrote %s" % OUT)
    return 0


if __name__ == "__main__":
    sys.exit(main())
