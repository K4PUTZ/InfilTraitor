#!/usr/bin/env python3
##
## segment_budget.py — PERFORMANCE_BUDGET PB-7: no game segment may hold more content than the HEAVY `segment_spec`.
##
## WHY A COUNT AND NOT A MEMORY READING: HEAVY was MEASURED to fit the exit criterion (§0d) on both handsets on 2026-10-09 — Moto g04s
## PSS 757 MiB, Galaxy A16 741 MiB, against the 1.0 GiB ceiling — and PB-3 measured each kind's marginal cost one at a time. So a
## segment whose every count is <= HEAVY's is inside the measured envelope, and that can be checked from the map file in milliseconds,
## on every commit, with no handset. What this cannot see is a change of COST (a heavier prop model, a new shader, a new content kind):
## that is re-measured on the handsets with `pb3_study.py --device <serial> --only HEAVY --max-pss-mib 1024`.
##
## WHICH MAPS: those that declare `"meta": {"segment": true}` (the game's segments). Dev and test maps (PLAYGROUND, GLASS, STRESS, the
## galleries, the PB-3 sweeps) are deliberately outside it. The three spec maps `gen_segment_map.py` writes carry the flag.
##
## WHAT IS COUNTED (the kinds of PB-1 that a map file states): footprint (inner GU), guards, props, lights, glass (GU x storeys of pane,
## any glass-family material), materials in use (distinct non-glass ids over blocks, panels, roofs, floor zones), roofs. Rooms and
## cameras are not in the map format and are not counted.
##
##     python3 tools/persistent/segment_budget.py              # the self-test, then every flagged map; exit 1 on any excess (verify quick)
##     python3 tools/persistent/segment_budget.py maps/X.map.json --force   # one map, flagged or not
##     python3 tools/persistent/segment_budget.py --self-test  # HEAVY passes, HEAVY + 1 of each kind fails

import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))
import gen_segment_map as seg  # noqa: E402

HEAVY = seg.SPECS["HEAVY"]
BUDGET = {"width": seg.W, "height": seg.H, "guards": HEAVY["guards"], "props": HEAVY["props"], "lights": HEAVY["lights"],
          "glass": HEAVY["glass"], "materials": HEAVY["materials"], "roofs": HEAVY["roofs"]}
GLASS_SOURCE = ROOT / "godot" / "scripts" / "systems" / "glass_materials.gd"


def glass_family() -> list:
    """The glass family read from the seam module (rule 10), never duplicated here."""
    for line in GLASS_SOURCE.read_text(encoding="utf-8").splitlines():
        m = re.match(r"^const\s+FAMILY\s*:.*=\s*\[(.*)\]", line)
        if m:
            return [t.strip().strip('"') for t in m.group(1).split(",") if t.strip()]
    raise SystemExit("[SEGMENT-BUDGET] cannot read the glass FAMILY from %s" % GLASS_SOURCE)


def count(data: dict, glass: list) -> dict:
    sec = data.get("sections", {})
    size = sec.get("board", {}).get("inner_size", [0, 0])
    items = lambda name: sec.get(name, {}).get("items", [])
    legacy = sec.get("legacy_compiler", {})
    mats = set()
    glass_gu = 0
    for it in items("blocks") + items("panels"):
        m = str(it.get("material", ""))
        if m in glass:
            glass_gu += int(it.get("storeys", 1))
        elif m:
            mats.add(m)
    for it in items("roofs") + items("floor_zones"):
        m = str(it.get("material", ""))
        if m and m not in glass:
            mats.add(m)
    return {"width": int(size[0]), "height": int(size[1]), "guards": len(sec.get("actors", {}).get("guards", [])),
            "props": len(items("props")), "lights": len(legacy.get("lights", [])), "glass": glass_gu,
            "materials": len(mats), "roofs": len(items("roofs"))}


def excess(counts: dict) -> list:
    return ["%s %d > %d" % (k, counts[k], BUDGET[k]) for k in BUDGET if counts[k] > BUDGET[k]]


def self_test(glass: list) -> int:
    heavy = seg.build(dict(HEAVY), "SEG_SELFTEST")
    bad = 0
    if excess(count(heavy, glass)):
        print("[SEGMENT-BUDGET] self-test FAIL: HEAVY itself exceeds: %s" % excess(count(heavy, glass)))
        bad += 1
    for kind in ("props", "guards", "lights", "glass", "roofs"):
        over = dict(HEAVY)
        over[kind] += 1 if kind != "glass" else 2   ## windows are written two GU at a time
        found = excess(count(seg.build(over, "SEG_SELFTEST"), glass))
        if not any(f.startswith(kind) for f in found):
            print("[SEGMENT-BUDGET] self-test FAIL: HEAVY + %s was not caught (%s)" % (kind, found))
            bad += 1
    wide = seg.build(dict(HEAVY), "SEG_SELFTEST", w=seg.W + 1)
    if not any(f.startswith("width") for f in excess(count(wide, glass))):
        print("[SEGMENT-BUDGET] self-test FAIL: a wider footprint was not caught")
        bad += 1
    print("[SEGMENT-BUDGET] self-test %s" % ("PASS" if bad == 0 else "FAIL (%d)" % bad))
    return 1 if bad else 0


def main() -> int:
    ap = argparse.ArgumentParser(description="PB-7 segment content budget (see the header)")
    ap.add_argument("maps", nargs="*", help="map files (default: every maps/*.map.json flagged as a segment)")
    ap.add_argument("--force", action="store_true", help="check the given maps even when they are not flagged")
    ap.add_argument("--self-test", action="store_true")
    args = ap.parse_args()
    glass = glass_family()
    if args.self_test:
        return self_test(glass)
    paths = [Path(p) for p in args.maps] or sorted((ROOT / "maps").glob("*.map.json"))
    checked, failed = 0, 0
    if not args.maps:   ## the gate's own proof first: a gate that cannot fail is not run as one
        failed += self_test(glass)
    for path in paths:
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, ValueError) as e:
            print("[SEGMENT-BUDGET] %s: unreadable (%s)" % (path.name, e))
            failed += 1
            continue
        if not (args.force or (data.get("meta") or {}).get("segment") is True):
            continue
        checked += 1
        counts = count(data, glass)
        over = excess(counts)
        if over:
            failed += 1
            print("[SEGMENT-BUDGET] %s: OVER the HEAVY segment_spec: %s" % (path.name, ", ".join(over)))
        else:
            print("[SEGMENT-BUDGET] %s: ok %s" % (path.name, counts))
    print("[SEGMENT-BUDGET] %d segment map(s) checked, %d over budget" % (checked, failed))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
