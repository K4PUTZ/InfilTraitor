#!/usr/bin/env python3
##
## independence_gate.py — the R3D-END ENTRY GATE: does the 3D board still depend on the hidden 2D board?
##
## R3D-END deletes the 2D board and "is entered when NOTHING depends on it" (Director, 2026-09-23: the look is not a
## gate; independence is). A grep cannot say that: a reader of a tile layer looks identical to a dead one. This runs the
## real game twice per map, the second time with the hidden 2D board EMPTIED after every step that rebuilds or blasts it
## (`drop2d`: every opaque, glass and structure layer cleared; the floor layer holds 0 cells since R3D-11), and requires
## the two runs to be the same world and the same picture:
##
##   STATE   the roundtrip scenario (load; grenades; shot; rotations E-S-W-N; save_restore; reload), a `BoardProbe`
##           dump after every step, keep vs drop, through `board_probe.diff(occupied_only=True)`: voxels IDENTICAL and
##           the cell planes identical where the board reads them.
##   PIXELS  `pixel_gate.py`'s cases (PLAYGROUND: load, grenade, pistol shot; GLASS: load, two grenades) at
##           `--fixed-fps 60` and a 400-frame settle, keep vs drop, 0 px above the gate's noise (8/255).
##   CONTROL `drop2d` must really have emptied something (its log line names the cells), or the gate could not fail.
##
## MEASURED 2026-09-24, before this file was written, and the reason it is a gate: PLAYGROUND is identical in every
## dump and every frame; **GLASS is not — after a grenade the crack/craze webs on the standing panes vanish (19 391 px
## on g0, 10 881 on g1; 42 and 82 light texels on cracked glass)**, because `VoxelRenderer._build_crack_occupancy()`
## and the other glass mechanics still read `_glass_layers`, the hidden TileMapLayers that are the glass state's
## authority. Until that authority moves to the store this gate is RED, and R3D-END (which deletes those layers) is not
## enterable. Its first green run is the entry condition.
##
## ⚠️ RUN IT WITH NO OTHER GODOT ALIVE (the pixel half depends on frame timing; see `pixel_gate.py`).
##
## Usage:   python3 tools/persistent/independence_gate.py [--maps PLAYGROUND,GLASS] [--no-pixels] [--no-state]

import argparse
import re
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import board_probe as bp  # noqa: E402
import pixel_gate as pg  # noqa: E402

TAG = "[INDEPENDENCE-GATE]"
DROPPED = re.compile(r"\[BOARD3D\] dropped the hidden 2D board — (\d+) opaque cell\(s\) in \d+ layer\(s\), (\d+) glass cell\(s\)")


def state_scenario(map_id: str, drop: bool):
    """The roundtrip scenario, with `drop2d` after every step that rebuilds or blasts the board when `drop`."""
    steps, labels = [], []
    for label, step in bp.ROUNDTRIP_STAGES[map_id]:
        if step:
            steps.append(step)
            if drop:
                steps += ["frames 30", "drop2d"]
        elif drop:
            steps.append("drop2d")
        steps += ["frames 120", "probe rt_%s" % label]
        labels.append("rt_%s" % label)
    return "; ".join(steps + ["quit"]), labels


def dropped_cells(log_path: Path):
    """(opaque, glass) cells the FIRST `drop2d` of a run emptied; (0, 0) when it never ran."""
    try:
        for line in log_path.read_text(encoding="utf-8", errors="replace").splitlines():
            m = DROPPED.search(line)
            if m:
                return int(m[1]), int(m[2])
    except OSError:
        pass
    return 0, 0


def run_state(map_id: str, godot: str, root: Path, failures: list):
    runs = {}
    for name, drop in (("keep", False), ("drop", True)):
        scenario, labels = state_scenario(map_id, drop)
        out = root / map_id / name
        probes, problems, seconds = bp.run_once(godot, map_id, out, {}, scenario, labels,
                                                bp.SHADOW_ENV.get(map_id, {}), bp.FATAL_MARKERS)
        print("%s STATE %s %s: %d probe(s) in %.0f s%s" % (TAG, map_id, name, len(probes), seconds,
              "" if not problems else " — %d problem(s): %s" % (len(problems), problems[:2])))
        if problems:
            failures.append("STATE %s %s did not run cleanly" % (map_id, name))
            return
        runs[name] = probes
    opaque, glass = dropped_cells(root / map_id / "drop" / "godot.log")
    print("%s CONTROL %s: the first drop2d emptied %d opaque and %d glass cell(s)" % (TAG, map_id, opaque, glass))
    if opaque + glass == 0:
        failures.append("CONTROL %s: drop2d emptied nothing, so this gate could not have failed" % map_id)
    for label in runs["keep"]:
        quiet = []
        result = bp.diff(bp.load(runs["keep"][label]), bp.load(runs["drop"][label]), 5, quiet.append, occupied_only=True)
        verdict = "IDENTICAL" if result["identical"] else "DIFFERENT"
        print("%s STATE %s %-10s keep vs drop: %s — voxels %d/%d, plane texels %d (%d more on cells the board does not read)"
              % (TAG, map_id, label, verdict, result["voxel_diffs"], result["voxels_compared"], result["texel_diffs"],
                 result["unoccupied_skipped"]))
        if not result["identical"]:
            failures.append("STATE %s %s: %d voxel(s), %d plane texel(s) differ once the 2D board is empty"
                            % (map_id, label, result["voxel_diffs"], result["texel_diffs"]))
            for line in quiet[:6]:
                print(line)


def run_pixels(case: str, settle: int, failures: list):
    original = pg.case_env

    def dropped(c, s, tag):
        scenario, env, labels = original(c, s, tag)
        scenario = scenario.replace("framing portrait;", "framing portrait; drop2d;", 1)
        scenario = re.sub(r"(detonate \d;|shoot \d;)", r"\1 drop2d;", scenario)
        return scenario, env, labels

    keep, k_err, _ = pg.boot(case, settle, "indep_%s_keep" % case)
    pg.case_env = dropped
    try:
        drop, d_err, d_log = pg.boot(case, settle, "indep_%s_drop" % case)
    finally:
        pg.case_env = original
    if k_err or d_err:
        failures.append("PIXELS %s: script error (keep %s, drop %s)" % (case, k_err, d_err))
    steps = d_log.count("dropped the hidden 2D board")
    print("%s CONTROL %s pixels: %d drop2d step(s) ran" % (TAG, case, steps))
    if steps == 0:
        failures.append("CONTROL %s pixels: drop2d never ran" % case)
    for label in keep:
        if not keep[label].exists() or not drop[label].exists():
            failures.append("PIXELS %s %s: a capture is missing" % (case, label))
            continue
        strict = pg.differing(keep[label], drop[label], 0, pg.MASK.get(case))
        loose = pg.differing(keep[label], drop[label], pg.NOISE, pg.MASK.get(case))
        print("%s PIXELS %s %-5s keep vs drop: %d px strict, %d px above noise %d" % (TAG, case, label, strict, loose, pg.NOISE))
        if loose:
            failures.append("PIXELS %s %s: %d px differ once the 2D board is empty" % (case, label, loose))


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--maps", default="PLAYGROUND,GLASS")
    ap.add_argument("--settle", type=int, default=400)
    ap.add_argument("--no-pixels", action="store_true")
    ap.add_argument("--no-state", action="store_true")
    ap.add_argument("--out", default=None)
    args = ap.parse_args()
    godot = bp.find_godot()
    if godot is None:
        print("%s ERROR: no Godot binary" % TAG)
        return 2
    root = Path(args.out) if args.out else Path(tempfile.mkdtemp(prefix="independence_gate_"))
    maps = [m.strip() for m in args.maps.split(",") if m.strip()]
    failures: list = []
    for map_id in maps:
        if not args.no_state:
            run_state(map_id, godot, root, failures)
        if not args.no_pixels:
            run_pixels(map_id, args.settle, failures)
    for f in failures:
        print("%s   %s" % (TAG, f))
    print("%s %s%s" % (TAG, "FAIL" if failures else "PASS", " — R3D-END is not enterable" if failures else
                       " — nothing the gate can see depends on the hidden 2D board"))
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
