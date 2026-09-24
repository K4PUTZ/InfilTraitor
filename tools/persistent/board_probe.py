#!/usr/bin/env python3
##
## board_probe.py — RENDER3D R3D-0: compare BoardProbe dumps, and run the identity
## gate every later RENDER3D stage closes on.
##
## A dump is written by `BoardProbe.write()` (godot/scripts/systems/board_probe.gd),
## reached through the `probe <name>` scenario step. Its format is documented there,
## and this is the ONLY place two dumps are compared.
##
##   diff A B [--first N]
##       Per voxel (visible, damage, blast, carved side, variant, substrate, material)
##       and per cell-plane texel. Prints totals grouped by container kind and by
##       level, then the first N differences. Exit 0 identical, 1 different, 2 bad
##       input.
##
##   gate [--maps PLAYGROUND,GLASS] [--runs 2] [--env KEY=VALUE ...] [--out DIR]
##       Boots the real game on each map `--runs` times, each boot running
##           probe load; detonate 0; probe g0; detonate 1; probe g1; quit
##       and requires, per map:
##         1. IDENTITY — every probe of run 1 is identical to the same probe of every
##            other run;
##         2. THE CONTROL — `load` and `g0` of run 1 DIFFER. A probe that cannot see a
##            grenade would pass (1) forever (assert identity, not absence).
##       `--env` passes a flag to every boot (the `INFILTRAITOR_` prefix is added when
##       missing), so a later stage runs the same gate with its own flag flipped.
##
##   shadow [--maps PLAYGROUND,GLASS] [--env KEY=VALUE ...] [--out DIR]
##       RENDER3D R3D-1b: the packed `VoxelStore` in shadow must hold exactly what the
##       `Voxel` objects hold. Boots each map ONCE and, at every
##       stage — load, both grenades, a shot (PLAYGROUND), all four views and back, a
##       SaveState round trip, an F2 reload — writes the objects' dump (`o_<stage>`) and
##       the store's (`s_<stage>`) in the same frame. Requires, per map:
##         1. IDENTITY — `o_<stage>` and `s_<stage>` identical at every stage;
##         2. NO DRIFT — every `[VOXEL-STORE]` stage line reads grid mismatches 0,
##            unknown-container writes 0, misplaced writes 0;
##         3. THE CONTROLS — the objects changed where the scenario changed them
##            (load vs g0, and g1 vs shot), so (1) is not an empty agreement.
##
##   roundtrip [--maps PLAYGROUND,GLASS] [--wait 120] [--out DIR]
##       R3D-8 step 4: what the game holds must survive being carried. One boot per map runs
##           load; g0; g1; (shot); views E, S, W, N; save_restore; reload
##       with `--wait` frames before every probe (a relight lands a few frames after the step that asks
##       for it). Requires: 1. N-view after E→S→W→N is IDENTICAL to before the rotation (voxels AND cell
##       planes); 2. the SaveState restore is IDENTICAL to the state it captured; 3. an F2 reload is
##       IDENTICAL to a fresh load (planes included); the rotation and the restore are strict on VOXELS and
##       GEOMETRY, and on the cell PLANES of PLAYGROUND (earned 2026-09-24: 0 texels); GLASS prints its
##       cell-plane difference (1 light texel, see `roundtrip()`; `--strict-planes` fails on it). The planes
##       are compared where the board READS them (a visible non-glass cell), and the texels left out are
##       counted on the line. 4. THE CONTROLS: the damaged state differs from the loaded one (so
##       identity is not an empty agreement).
##
## ⚠️ THE GATE IS EARNED ON THE UNCHANGED CODE FIRST (R3D-0). A 0-difference claim
## from a nondeterministic run is noise wearing a number — the pixel-diff lesson of
## 2026-08-09, which measured 36 733 px between two identical captures.

import argparse
import base64
import gzip
import os
import re
import shutil
import struct
import subprocess
import sys
import tempfile
import time
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
GODOT_CANDIDATES = ["/Applications/Godot.app/Contents/MacOS/Godot", "godot"]
FORMAT_VERSION = "1"
DAMAGE = ["INTACT", "CRACKED", "DESTROYED", "DENTED"]
CARVED = ["NONE", "TOP", "BOTTOM", "LEFT", "RIGHT", "5", "6", "7"]
## Bytes per texel -> channel names. RG8 is the only plane format today.
PLANE_CHANNELS = {2: ["soot(R)", "light(G)"]}
TAG = "[BOARD-PROBE-DIFF]"
GATE_TAG = "[BOARD-PROBE-GATE]"

GATE_SCENARIO = "probe load; detonate 0; probe g0; detonate 1; probe g1; quit"
GATE_LABELS = ["load", "g0", "g1"]
## GLASS ships no dev grenades, and `_seed_dev_grenades_if_empty()` would seed
## PLAYGROUND's cells there. These are runtime GUs (authored + the map's buffer of 1),
## two rows south of what they aim at — PLAYGROUND's own spacing: #0 at the big pane
## (authored x 10..15, y 9), #1 at the small pane (authored 4, 9) beside the variant row.
MAP_ENV = {
    "PLAYGROUND": {},
    "GLASS": {"INFILTRAITOR_GRENADE_GUS": "14,12;5,12"},
}
PROBE_LINE = re.compile(r"^\[BOARD-PROBE\] (\S+) .*→ (.+)$")
## Lines that mean the scenario itself went wrong, as opposed to boot noise.
FATAL_MARKERS = ("SCRIPT ERROR", "[ScenarioRunner] step", "SCENARIO rejected",
                 "[BoardProbe]", "scenario_detonate:")
RUN_TIMEOUT_S = 900

## R3D-1b — the shadow gate's stages: (label, the step that produces it). PLAYGROUND's
## grenades sit beside four boxes' corners, where two slices claim one cell and their
## states diverge under a blast (R3D-1a) — the case a packed store is most likely to get
## wrong. GLASS ships no guards, so it takes no shot; its grenades shatter panes.
SHADOW_STAGES = {
    "PLAYGROUND": [("load", ""), ("g0", "detonate 0"), ("g1", "detonate 1"), ("shot", "shoot 0"),
                   ("view_e", "perspective E"), ("view_s", "perspective S"),
                   ("view_w", "perspective W"), ("view_n", "perspective N"),
                   ("restore", "save_restore"), ("reload", "reload")],
    "GLASS": [("load", ""), ("g0", "detonate 0"), ("g1", "detonate 1"),
              ("view_e", "perspective E"), ("view_s", "perspective S"),
              ("view_w", "perspective W"), ("view_n", "perspective N"),
              ("restore", "save_restore"), ("reload", "reload")],
}
SHADOW_ENV = {
    "PLAYGROUND": {"INFILTRAITOR_GRENADE_GUS": "25,2;37,2"},
    "GLASS": {"INFILTRAITOR_GRENADE_GUS": "14,12;5,12"},
}
SHADOW_CONTROLS = {"PLAYGROUND": [("load", "g0"), ("g1", "shot")], "GLASS": [("load", "g0")]}
STORE_LINE = re.compile(r"^\[VOXEL-STORE\] (s_\S+) — grid mismatches (\d+), writes mirrored (\d+), "
                        r"unknown container (\d+), misplaced (\d+)$")
SHADOW_FATAL = ("[Room] the shadow store has drifted", "[Room] the voxel store could not be built",
                "[VoxelStore]", "scenario_shoot:", "scenario_perspective:")


class DumpError(Exception):
    pass


# ── reading ──────────────────────────────────────────────────────────────────

def load(path):
    dump = {"path": str(path), "label": None, "meta": {}, "materials": {},
            "containers": {}, "planes": {}, "end": None, "duplicates": []}
    with open(path, "r", encoding="utf-8") as f:
        head = f.readline().rstrip("\n").split(" ")
        if len(head) != 3 or head[0] != "BOARDPROBE":
            raise DumpError("%s: not a BoardProbe dump (first line %r)" % (path, " ".join(head)))
        if head[1] != FORMAT_VERSION:
            raise DumpError("%s: format version %s, this tool reads %s" % (path, head[1], FORMAT_VERSION))
        dump["label"] = head[2]
        for lineno, raw in enumerate(f, start=2):
            line = raw.rstrip("\n")
            if not line:
                continue
            tag = line.split(" ", 1)[0]
            try:
                if tag == "META":
                    parts = line.split(" ", 2)
                    dump["meta"][parts[1]] = parts[2] if len(parts) > 2 else ""
                elif tag == "M":
                    parts = line.split(" ", 2)
                    dump["materials"][int(parts[1])] = parts[2] if len(parts) > 2 else ""
                elif tag == "C":
                    parts = line.split(" ")
                    if len(parts) != 6:
                        raise DumpError("a C record has 6 fields, this one has %d" % len(parts))
                    kind, cid, n = parts[1], parts[2], int(parts[3])
                    coords = b"" if parts[4] == "-" else base64.b64decode(parts[4])
                    state = b"" if parts[5] == "-" else base64.b64decode(parts[5])
                    if len(coords) != n * 12 or len(state) != n * 4:
                        raise DumpError("%s %s claims %d voxels, holds %d coord / %d state bytes"
                                        % (kind, cid, n, len(coords), len(state)))
                    key = (kind, cid)
                    if key in dump["containers"]:
                        dump["duplicates"].append(cid)
                        k = 2
                        while (kind, "%s~%d" % (cid, k)) in dump["containers"]:
                            k += 1
                        key = (kind, "%s~%d" % (cid, k))
                    dump["containers"][key] = (n, coords, state)
                elif tag == "P":
                    parts = line.split(" ")
                    if len(parts) != 8:
                        raise DumpError("a P record has 8 fields, this one has %d" % len(parts))
                    level, w, h, fmt, ox, oy = (int(v) for v in parts[1:7])
                    data = gzip.decompress(base64.b64decode(parts[7]))
                    if w <= 0 or h <= 0 or len(data) % (w * h) != 0:
                        raise DumpError("plane L%d: %d bytes do not tile %dx%d" % (level, len(data), w, h))
                    dump["planes"][level] = (w, h, fmt, ox, oy, data)
                elif tag == "END":
                    dump["end"] = line
                else:
                    raise DumpError("unknown record %r" % tag)
            except (ValueError, IndexError, base64.binascii.Error, OSError) as exc:
                raise DumpError("%s:%d: %s" % (path, lineno, exc))
            except DumpError as exc:
                raise DumpError("%s:%d: %s" % (path, lineno, exc))
    if dump["end"] is None:
        raise DumpError("%s: no END record — the dump is truncated" % path)
    return dump


# ── comparing ────────────────────────────────────────────────────────────────

def _fields(state4, material):
    b = state4[0]
    return {"visible": b & 1, "damage": DAMAGE[(b >> 1) & 3], "blast": (b >> 3) & 1,
            "carved": CARVED[(b >> 4) & 7], "variant": state4[1], "substrate": state4[2],
            "material": material}


def _changes(fa, fb):
    return ", ".join("%s %s→%s" % (k, fa[k], fb[k]) for k in fa if fa[k] != fb[k])


def _count(table, key):
    table[key] = table.get(key, 0) + 1


def _fmt_table(table):
    return ", ".join("%s: %d" % (k, table[k]) for k in sorted(table)) or "none"


def _glass_ids():
    """The glass family, read off `glass_materials.gd` by the L2 hook's own parser, or None when it cannot be."""
    try:
        import check_invariants
        return set(check_invariants._glass_family() or ()) or None
    except ImportError:
        return None


def _plane_read_cells(d, glass):
    """level -> set of (x, y) whose plane texel the 3D board reads: a cell with a visible claim that is not
    glass. The opaque face shader samples the cell plane for the face's own cell; the three glass shaders
    (`glass_pane3d`, `glass_tile`, `glass_pane`, and `glass_shading.gdshaderinc`) name neither the soot nor the
    light plane, so a glass cell's texel is written and never read."""
    cells = {}
    for _kind_id, (n, coords, state) in d["containers"].items():
        for i in range(n):
            if state[i * 4] & 1 and d["materials"].get(state[i * 4 + 3]) not in glass:
                x, y, level = struct.unpack_from("<iii", coords, i * 12)
                cells.setdefault(level, set()).add((x, y))
    return cells


def diff(a, b, first=20, out=print, occupied_only=False):
    """Compare two loaded dumps. Returns a dict of counts; `identical` is the verdict.

    `occupied_only` compares the cell planes only on the cells the board READS (`_plane_read_cells`, in A or
    B): a visible non-glass claim. Two classes of texel are never read, and both are measured, printed and
    returned rather than dropped: (1) a cell with no visible voxel — the incremental light writers
    (`apply_light_field_cells()` / `_gus()`) leave a bucket on a cell a blast just emptied where a full relight
    leaves it unwritten (714 texels after PLAYGROUND's two grenades, 3 103 once the shot is added); (2) a glass cell —
    `_soot_map` holds tone 0 on cracked glass the live wave never paints (260 texels on GLASS), and its light
    is derived like any cell's, but no glass shader samples either plane."""
    def describe(d):
        voxels = sum(c[0] for c in d["containers"].values())
        return "%s — label %s, %d voxels in %d containers, %d plane level(s)" % (
            d["path"], d["label"], voxels, len(d["containers"]), len(d["planes"]))

    out("%s A: %s" % (TAG, describe(a)))
    out("%s B: %s" % (TAG, describe(b)))
    for key in sorted(set(a["meta"]) | set(b["meta"])):
        if a["meta"].get(key) != b["meta"].get(key):
            out("%s note: META %s %s → %s (not counted)" % (TAG, key, a["meta"].get(key), b["meta"].get(key)))
    for d, name in ((a, "A"), (b, "B")):
        if d["duplicates"]:
            out("%s ⚠️ %s repeats %d container id(s), first %s — compared by occurrence"
                % (TAG, name, len(d["duplicates"]), d["duplicates"][:3]))

    only_a = [k for k in a["containers"] if k not in b["containers"]]
    only_b = [k for k in b["containers"] if k not in a["containers"]]
    geometry = []
    tables_equal = a["materials"] == b["materials"]
    voxels_compared = 0
    voxel_diffs = 0
    by_kind, by_level, examples = {}, {}, []
    for key, (na, ca, sa) in a["containers"].items():
        if key not in b["containers"]:
            continue
        nb, cb, sb = b["containers"][key]
        if na != nb or ca != cb:
            geometry.append("%s %s (%d → %d voxels)" % (key[0], key[1], na, nb))
            continue
        voxels_compared += na
        if tables_equal and sa == sb:
            continue
        for i in range(na):
            qa, qb = sa[i * 4:i * 4 + 4], sb[i * 4:i * 4 + 4]
            ma = a["materials"].get(qa[3], "#%d" % qa[3])
            mb = b["materials"].get(qb[3], "#%d" % qb[3])
            if qa[:3] == qb[:3] and ma == mb:
                continue
            voxel_diffs += 1
            x, y, level = struct.unpack_from("<iii", ca, i * 12)
            _count(by_kind, key[0])
            _count(by_level, level)
            if len(examples) < first:
                examples.append("%s %s #%d (%d,%d) L%d: %s" % (
                    key[0], key[1], i, x, y, level, _changes(_fields(qa, ma), _fields(qb, mb))))

    levels_only_a = sorted(set(a["planes"]) - set(b["planes"]))
    levels_only_b = sorted(set(b["planes"]) - set(a["planes"]))
    plane_shape = []
    texels_compared = 0
    texel_diffs = 0
    unoccupied_skipped = 0
    glass = (_glass_ids() or set()) if occupied_only else set()
    if occupied_only and not glass:
        out("%s ⚠️ the glass roster could not be read: glass cells are compared like any other" % TAG)
    vis_a = _plane_read_cells(a, glass) if occupied_only else None
    vis_b = _plane_read_cells(b, glass) if occupied_only else None
    by_channel, plane_by_level, plane_examples = {}, {}, []
    for level in sorted(set(a["planes"]) & set(b["planes"])):
        wa, ha, fa, oxa, oya, da = a["planes"][level]
        wb, hb, fb, oxb, oyb, db = b["planes"][level]
        if (wa, ha, fa, oxa, oya, len(da)) != (wb, hb, fb, oxb, oyb, len(db)):
            plane_shape.append(level)
            continue
        bpp = len(da) // (wa * ha)
        texels_compared += wa * ha
        if da == db:
            continue
        names = PLANE_CHANNELS.get(bpp, ["ch%d" % c for c in range(bpp)])
        row = wa * bpp
        for r in range(ha):
            ra, rb = da[r * row:(r + 1) * row], db[r * row:(r + 1) * row]
            if ra == rb:
                continue
            for j in range(row):
                if ra[j] == rb[j]:
                    continue
                if occupied_only:
                    cell = (j // bpp - oxa, r - oya)
                    if cell not in vis_a.get(level, ()) and cell not in vis_b.get(level, ()):
                        unoccupied_skipped += 1
                        continue
                texel_diffs += 1
                _count(by_channel, names[j % bpp])
                _count(plane_by_level, level)
                if len(plane_examples) < first:
                    tx = j // bpp
                    plane_examples.append("plane L%d cell (%d,%d) %s: %d→%d" % (
                        level, tx - oxa, r - oya, names[j % bpp], ra[j], rb[j]))

    if only_a:
        out("%s containers only in A: %d, first %s" % (TAG, len(only_a), [" ".join(k) for k in only_a[:5]]))
    if only_b:
        out("%s containers only in B: %d, first %s" % (TAG, len(only_b), [" ".join(k) for k in only_b[:5]]))
    if geometry:
        out("%s geometry: %d container(s) whose voxel count or coordinates differ, first %s"
            % (TAG, len(geometry), geometry[:5]))
    out("%s voxels: %d differ of %d compared — by kind %s; by level %s"
        % (TAG, voxel_diffs, voxels_compared, _fmt_table(by_kind), _fmt_table(by_level)))
    for line in examples:
        out("%s   %s" % (TAG, line))
    if levels_only_a or levels_only_b or plane_shape:
        out("%s plane levels only in A %s, only in B %s, shape differs %s"
            % (TAG, levels_only_a, levels_only_b, plane_shape))
    out("%s plane texels: %d channel byte(s) differ over %d texels compared — by channel %s; by level %s"
        % (TAG, texel_diffs, texels_compared, _fmt_table(by_channel), _fmt_table(plane_by_level)))
    for line in plane_examples:
        out("%s   %s" % (TAG, line))
    if occupied_only:
        out("%s plane texels on cells the board does not read (no visible voxel, or glass), not counted: %d channel byte(s)"
            % (TAG, unoccupied_skipped))

    identical = not (only_a or only_b or geometry or voxel_diffs or levels_only_a
                     or levels_only_b or plane_shape or texel_diffs)
    out("%s RESULT: %s" % (TAG, "IDENTICAL" if identical else
        "DIFFERENT — voxels %d, geometry %d, containers %d, plane texels %d, plane levels %d"
        % (voxel_diffs, len(geometry), len(only_a) + len(only_b), texel_diffs,
           len(levels_only_a) + len(levels_only_b) + len(plane_shape))))
    return {"identical": identical, "voxel_diffs": voxel_diffs, "voxels_compared": voxels_compared,
            "by_channel": dict(by_channel), "only": len(only_a) + len(only_b),
            "texel_diffs": texel_diffs, "geometry": len(geometry), "unoccupied_skipped": unoccupied_skipped,
            "containers_unmatched": len(only_a) + len(only_b)}


# ── the gate ─────────────────────────────────────────────────────────────────

def find_godot():
    for candidate in GODOT_CANDIDATES:
        if os.path.sep in candidate:
            if os.path.exists(candidate):
                return candidate
        elif shutil.which(candidate):
            return shutil.which(candidate)
    return None


def run_once(godot, map_id, run_dir, extra_env, scenario=GATE_SCENARIO, labels=GATE_LABELS,
             map_env=None, fatal=FATAL_MARKERS):
    env = os.environ.copy()
    env.update({"INFILTRAITOR_MAP": map_id, "INFILTRAITOR_RNG_SEED": "1",
                "INFILTRAITOR_SCENARIO": scenario})
    env.update(MAP_ENV.get(map_id, {}) if map_env is None else map_env)
    env.update(extra_env)
    run_dir.mkdir(parents=True, exist_ok=True)
    cmd = [godot, "--path", str(REPO), "--position", "4000,4000"]
    t0 = time.time()
    try:
        proc = subprocess.run(cmd, cwd=REPO, env=env, capture_output=True, text=True,
                              timeout=RUN_TIMEOUT_S)
        output, code = proc.stdout + proc.stderr, proc.returncode
    except subprocess.TimeoutExpired as exc:
        output = (exc.stdout or "") + (exc.stderr or "")
        if isinstance(output, bytes):
            output = output.decode("utf-8", "replace")
        code = "timeout after %ds" % RUN_TIMEOUT_S
    (run_dir / "godot.log").write_text(output, encoding="utf-8")
    problems = [] if code == 0 else ["exit %s" % code]
    probes = {}
    for line in output.splitlines():
        if any(marker in line for marker in fatal):
            problems.append(line.strip())
        match = PROBE_LINE.match(line.strip())
        if match:
            src = Path(match.group(2).strip())
            dst = run_dir / ("%s.txt" % match.group(1))
            if src.exists():
                shutil.move(str(src), dst)
                probes[match.group(1)] = dst
            else:
                problems.append("probe %s reported at %s, which does not exist" % (match.group(1), src))
    missing = [label for label in labels if label not in probes]
    if missing:
        problems.append("probe(s) never written: %s" % ", ".join(missing))
    return probes, problems, time.time() - t0


def shadow(args):
    godot = find_godot()
    if godot is None:
        print("%s ERROR: no Godot binary (looked in %s)" % (GATE_TAG, GODOT_CANDIDATES))
        return 2
    extra_env = {}
    for pair in args.env:
        if "=" not in pair:
            print("%s ERROR: --env takes KEY=VALUE, got %r" % (GATE_TAG, pair))
            return 2
        key, value = pair.split("=", 1)
        extra_env[key if key.startswith("INFILTRAITOR_") else "INFILTRAITOR_" + key] = value
    out_root = Path(args.out) if args.out else Path(tempfile.mkdtemp(prefix="board_probe_shadow_"))
    maps = [m.strip() for m in args.maps.split(",") if m.strip()]
    print("%s shadow: %d map(s), env %s → %s" % (GATE_TAG, len(maps), extra_env, out_root))
    failures = []
    for map_id in maps:
        if map_id not in SHADOW_STAGES:
            failures.append("%s has no shadow scenario" % map_id)
            continue
        stages = SHADOW_STAGES[map_id]
        steps, labels = [], []
        for label, step in stages:
            if step:
                steps.append(step)
            steps += ["probe o_%s" % label, "probe_store s_%s" % label]
            labels += ["o_%s" % label, "s_%s" % label]
        scenario = "; ".join(steps + ["quit"])
        run_dir = out_root / map_id
        probes, problems, seconds = run_once(godot, map_id, run_dir, extra_env, scenario, labels,
                                             SHADOW_ENV.get(map_id, {}), FATAL_MARKERS + SHADOW_FATAL)
        print("%s %s: %d probe(s) in %.0f s%s" % (GATE_TAG, map_id, len(probes), seconds,
              "" if not problems else " — %d problem(s)" % len(problems)))
        for line in problems[:8]:
            print("%s     %s" % (GATE_TAG, line))
        if problems:
            failures.append("%s did not run cleanly" % map_id)
        log = (run_dir / "godot.log").read_text(encoding="utf-8", errors="replace")
        store_lines = {}
        for line in log.splitlines():
            match = STORE_LINE.match(line.strip())
            if match:
                store_lines[match.group(1)] = [int(match.group(k)) for k in range(2, 6)]
        for line in log.splitlines():
            if line.startswith("[VOXEL-STORE] built"):
                print("%s %s   %s" % (GATE_TAG, map_id, line.strip()))
        quiet = [] if args.verbose else None
        sink = print if quiet is None else quiet.append
        for label, _step in stages:
            o, s_ = "o_%s" % label, "s_%s" % label
            if o not in probes or s_ not in probes:
                continue
            result = diff(load(probes[o]), load(probes[s_]), args.first, sink)
            counters = store_lines.get(s_)
            drift = counters is None or counters[0] != 0 or counters[2] != 0 or counters[3] != 0
            print("%s %s %-8s objects vs store %s — voxels %d/%d, plane texels %d; grid mismatches %s, writes mirrored %s, unknown %s, misplaced %s"
                  % (GATE_TAG, map_id, label, "IDENTICAL" if result["identical"] else "DIFFERENT",
                     result["voxel_diffs"], result["voxels_compared"], result["texel_diffs"],
                     *(counters if counters else ["?"] * 4)))
            if not result["identical"]:
                failures.append("%s %s: objects and store differ" % (map_id, label))
                if quiet is not None:
                    for line in quiet:
                        print(line)
            if drift:
                failures.append("%s %s: the store line is missing or reports drift" % (map_id, label))
            if quiet is not None:
                quiet.clear()
        for a, b in SHADOW_CONTROLS.get(map_id, []):
            if "o_%s" % a not in probes or "o_%s" % b not in probes:
                continue
            control = diff(load(probes["o_%s" % a]), load(probes["o_%s" % b]), args.first, sink)
            if quiet is not None:
                quiet.clear()
            print("%s %s control: objects %s vs %s — voxels %d%s" % (GATE_TAG, map_id, a, b,
                  control["voxel_diffs"], "" if control["voxel_diffs"] else " — ⛔ the stage changed nothing"))
            if control["voxel_diffs"] == 0:
                failures.append("%s control %s→%s changed no voxel" % (map_id, a, b))
    if failures:
        print("%s SHADOW FAIL — %s" % (GATE_TAG, "; ".join(failures)))
        return 1
    print("%s SHADOW PASS — dumps and logs in %s" % (GATE_TAG, out_root))
    return 0


## R3D-8 step 2 — the blast's uploads. A detonation that never tells `Board3DLive` (commit, soot, light) passes every
## identity check above, because the STATE is right and only the board is stale. Each grenade of the gate scenario must
## leave these lines in the log; the remesh and soot counts must also agree between runs (the light ramp's count is
## frame-driven, so it only has to be present).
HOOK_LINES = {
    "remesh commit": "[BOARD3D] remesh commit",
    "recolour commit": "[BOARD3D] recolour commit",
    "recolour soot": "[BOARD3D] recolour soot",
    "recolour light": "[BOARD3D] recolour light",
}
HOOK_EXACT = ("remesh commit", "recolour commit")
## The light ramp writes one upload per step: 28 measured for the two grenades (2026-09-23); with the ramp's
## `on_blast_light` calls removed it read 2 and a floor of 2 let that pass. 10 sits between the two.
HOOK_FLOOR = {"recolour light": 10}


def hook_counts(run_dir):
    text = (run_dir / "godot.log").read_text(encoding="utf-8", errors="replace")
    return {name: text.count(marker) for name, marker in HOOK_LINES.items()}


def gate(args):
    godot = find_godot()
    if godot is None:
        print("%s ERROR: no Godot binary (looked in %s)" % (GATE_TAG, GODOT_CANDIDATES))
        return 2
    extra_env = {}
    for pair in args.env:
        if "=" not in pair:
            print("%s ERROR: --env takes KEY=VALUE, got %r" % (GATE_TAG, pair))
            return 2
        key, value = pair.split("=", 1)
        extra_env[key if key.startswith("INFILTRAITOR_") else "INFILTRAITOR_" + key] = value
    out_root = Path(args.out) if args.out else Path(tempfile.mkdtemp(prefix="board_probe_gate_"))
    maps = [m.strip() for m in args.maps.split(",") if m.strip()]
    print("%s %d map(s) × %d run(s), env %s → %s" % (GATE_TAG, len(maps), args.runs, extra_env or "{}", out_root))
    failures = []
    for map_id in maps:
        runs = []
        for k in range(1, args.runs + 1):
            probes, problems, seconds = run_once(godot, map_id, out_root / map_id / ("run%d" % k), extra_env)
            print("%s %s run %d: %d probe(s) in %.0f s%s" % (
                GATE_TAG, map_id, k, len(probes), seconds,
                "" if not problems else " — %d problem(s)" % len(problems)))
            for line in problems[:8]:
                print("%s     %s" % (GATE_TAG, line))
            if problems:
                failures.append("%s run %d did not run cleanly" % (map_id, k))
            runs.append(probes)
        if any(label not in probes for probes in runs for label in GATE_LABELS):
            continue
        counts = [hook_counts(out_root / map_id / ("run%d" % k)) for k in range(1, args.runs + 1)]
        print("%s %s hooks: %s" % (GATE_TAG, map_id, "; ".join(
            "run %d %s" % (k + 1, ", ".join("%s %d" % kv for kv in c.items())) for k, c in enumerate(counts))))
        for name in HOOK_LINES:
            floor = HOOK_FLOOR.get(name, 2)
            if counts[0][name] < floor:
                failures.append("%s: %d `%s` line(s), needs >= %d for 2 grenades (the blast never told the board)"
                                % (map_id, counts[0][name], name, floor))
        for name in HOOK_EXACT:
            if len({c[name] for c in counts}) > 1:
                failures.append("%s: `%s` count differs between runs %s" % (map_id, name, [c[name] for c in counts]))
        quiet = [] if args.verbose else None
        sink = print if quiet is None else quiet.append
        for label in GATE_LABELS:
            for k in range(2, args.runs + 1):
                result = diff(load(runs[0][label]), load(runs[k - 1][label]), args.first, sink)
                verdict = "IDENTICAL" if result["identical"] else "DIFFERENT"
                print("%s %s %s: run 1 vs run %d %s — voxels %d/%d, plane texels %d"
                      % (GATE_TAG, map_id, label, k, verdict, result["voxel_diffs"],
                         result["voxels_compared"], result["texel_diffs"]))
                if not result["identical"]:
                    failures.append("%s %s: run 1 vs run %d differ" % (map_id, label, k))
                    if quiet is not None:
                        for line in quiet:
                            print(line)
                if quiet is not None:
                    quiet.clear()
        control = diff(load(runs[0]["load"]), load(runs[0]["g0"]), args.first, sink)
        if quiet is not None:
            quiet.clear()
        print("%s %s control: load vs g0 in run 1 — voxels %d, plane texels %d%s"
              % (GATE_TAG, map_id, control["voxel_diffs"], control["texel_diffs"],
                 "" if control["voxel_diffs"] else " — ⛔ the probe did not see the grenade"))
        if control["voxel_diffs"] == 0:
            failures.append("%s control: grenade #0 changed no voxel" % map_id)
    if failures:
        print("%s FAIL — %s" % (GATE_TAG, "; ".join(failures)))
        return 1
    print("%s PASS — dumps and logs in %s" % (GATE_TAG, out_root))
    return 0


## R3D-8 step 4 — (label, step) per stage of the round-trip gate. The wait is added per probe, not per step.
ROUNDTRIP_STAGES = {
    "PLAYGROUND": [("load", ""), ("g0", "detonate 0"), ("g1", "detonate 1"), ("shot", "shoot 0"),
                   ("view_e", "perspective E"), ("view_s", "perspective S"),
                   ("view_w", "perspective W"), ("view_n", "perspective N"),
                   ("restore", "save_restore"), ("reload", "reload")],
    "GLASS": [("load", ""), ("g0", "detonate 0"), ("g1", "detonate 1"),
              ("view_e", "perspective E"), ("view_s", "perspective S"),
              ("view_w", "perspective W"), ("view_n", "perspective N"),
              ("restore", "save_restore"), ("reload", "reload")],
}
## (before, after, must be identical): the damaged state is the last one before the rotation.
ROUNDTRIP_PAIRS = {
    "PLAYGROUND": [("shot", "view_n", "rotation E-S-W-N"), ("shot", "restore", "SaveState restore"),
                   ("load", "reload", "F2 reload")],
    "GLASS": [("g1", "view_n", "rotation E-S-W-N"), ("g1", "restore", "SaveState restore"),
              ("load", "reload", "F2 reload")],
}
ROUNDTRIP_CONTROLS = {"PLAYGROUND": ("load", "shot"), "GLASS": ("load", "g1")}


def roundtrip(args):
    godot = find_godot()
    if godot is None:
        print("%s ERROR: no Godot binary (looked in %s)" % (GATE_TAG, GODOT_CANDIDATES))
        return 2
    out_root = Path(args.out) if args.out else Path(tempfile.mkdtemp(prefix="board_probe_roundtrip_"))
    maps = [m.strip() for m in args.maps.split(",") if m.strip()]
    print("%s roundtrip: %d map(s), wait %d frame(s) → %s" % (GATE_TAG, len(maps), args.wait, out_root))
    failures = []
    for map_id in maps:
        stages = ROUNDTRIP_STAGES[map_id]
        steps, labels = [], []
        for label, step in stages:
            if step:
                steps.append(step)
            steps += ["frames %d" % args.wait, "probe rt_%s" % label]
            labels.append("rt_%s" % label)
        run_dir = out_root / map_id
        probes, problems, seconds = run_once(godot, map_id, run_dir, {}, "; ".join(steps + ["quit"]), labels,
                                             SHADOW_ENV.get(map_id, {}), FATAL_MARKERS)
        print("%s %s: %d probe(s) in %.0f s%s" % (GATE_TAG, map_id, len(probes), seconds,
              "" if not problems else " — %d problem(s)" % len(problems)))
        for line in problems[:8]:
            print("%s     %s" % (GATE_TAG, line))
        if problems:
            failures.append("%s did not run cleanly" % map_id)
            continue
        quiet = []
        for before, after, what in ROUNDTRIP_PAIRS[map_id]:
            result = diff(load(probes["rt_" + before]), load(probes["rt_" + after]), args.first, quiet.append,
                          occupied_only=True)
            light = result["by_channel"].get("light(G)", 0)
            hard = result["texel_diffs"] - light
            if hard or light:
                print("%s %s   (planes: %s)" % (GATE_TAG, map_id,
                      "GLASS rim residual, see the header" if not (args.strict_planes or what == "F2 reload"
                                                                  or map_id == "PLAYGROUND") else "STRICT"))
            print("%s %s %-18s %s vs %s: %s — voxels %d/%d, plane texels %d (soot etc. %d, light %d; %d more on "
                  "cells the board does not read, not counted)"
                  % (GATE_TAG, map_id, what, before, after, "IDENTICAL" if result["identical"] else "DIFFERENT",
                     result["voxel_diffs"], result["voxels_compared"], result["texel_diffs"], hard, light,
                     result["unoccupied_skipped"]))
            ## The cell PLANES are judged apart from the voxels. R3D-8 (2026-09-23) found two differences after a
            ## rotation or a restore; R3D-13 (2026-09-24) traced them: (1) the cook's LIGHT was built from a
            ## per-CELL predicted occupancy, which emptied a box corner or junction column at the first of its
            ## claims destroyed (21 and 13 cells apart from a full relight after PLAYGROUND's two grenades; fixed,
            ## `VoxelStore.occupancy_dict_after()`), the SaveState restore skipped the relight a rotation runs
            ## (fixed in `scenario_save_restore()`), and the incremental writers leave a bucket on a cell a blast
            ## emptied (never read; counted, not compared); (2) `_soot_map` holds tone 0 on cracked GLASS that the
            ## live wave never paints (never read: no glass shader samples the plane; counted, not compared).
            ## What is left: GLASS, 1 light texel, L88 (39,103) 7 -> 8: the glass opening's rim cut destroys a pane
            ## voxel at commit that the cook did not project, so a concrete cell beside it kept its pre-cut
            ## occlusion. PLAYGROUND earned strict planes, so it is strict by default; GLASS is strict with
            ## `--strict-planes`. The F2 reload is strict on everything.
            planes_strict = args.strict_planes or what == "F2 reload" or map_id == "PLAYGROUND"
            broken = result["voxel_diffs"] or result["geometry"] or result["only"] \
                or (planes_strict and result["texel_diffs"])
            if broken:
                failures.append("%s %s: %d voxel(s), %d plane texel(s) differ" % (
                    map_id, what, result["voxel_diffs"], result["texel_diffs"] if planes_strict else 0))
                for line in quiet[:args.first]:
                    print(line)
            quiet.clear()
        a, b = ROUNDTRIP_CONTROLS[map_id]
        control = diff(load(probes["rt_" + a]), load(probes["rt_" + b]), 0, quiet.append)
        print("%s %s control: %s vs %s — voxels %d%s" % (GATE_TAG, map_id, a, b, control["voxel_diffs"],
              "" if control["voxel_diffs"] else " — ⛔ the probe did not see the damage"))
        if control["voxel_diffs"] == 0:
            failures.append("%s control: the blast changed no voxel" % map_id)
    if failures:
        print("%s ROUNDTRIP FAIL — %s" % (GATE_TAG, "; ".join(failures)))
        return 1
    print("%s ROUNDTRIP PASS — dumps and logs in %s" % (GATE_TAG, out_root))
    return 0


def main():
    parser = argparse.ArgumentParser(description="Compare BoardProbe dumps / run the R3D identity gate")
    sub = parser.add_subparsers(dest="command", required=True)
    p_diff = sub.add_parser("diff", help="compare two dumps")
    p_diff.add_argument("a")
    p_diff.add_argument("b")
    p_diff.add_argument("--first", type=int, default=20, help="differences to list (default 20)")
    p_gate = sub.add_parser("gate", help="boot the game per map, twice, and require identical probes")
    p_gate.add_argument("--maps", default="PLAYGROUND,GLASS")
    p_gate.add_argument("--runs", type=int, default=2)
    p_gate.add_argument("--env", action="append", default=[], metavar="KEY=VALUE")
    p_gate.add_argument("--out", default=None, help="where dumps and logs go (default: a new temp dir)")
    p_gate.add_argument("--first", type=int, default=20)
    p_gate.add_argument("--verbose", action="store_true", help="print every diff in full")
    p_shadow = sub.add_parser("shadow", help="R3D-1b: require the shadow VoxelStore to equal the objects")
    p_shadow.add_argument("--maps", default="PLAYGROUND,GLASS")
    p_shadow.add_argument("--env", action="append", default=[], metavar="KEY=VALUE")
    p_shadow.add_argument("--out", default=None)
    p_shadow.add_argument("--first", type=int, default=20)
    p_shadow.add_argument("--verbose", action="store_true")
    p_round = sub.add_parser("roundtrip", help="R3D-8: rotation, SaveState restore and reload must be identity")
    p_round.add_argument("--maps", default="PLAYGROUND,GLASS")
    p_round.add_argument("--wait", type=int, default=120, help="frames before every probe")
    p_round.add_argument("--out", default=None)
    p_round.add_argument("--first", type=int, default=20)
    p_round.add_argument("--strict-planes", action="store_true", help="also fail on any cell-plane difference")
    args = parser.parse_args()
    if args.command == "roundtrip":
        try:
            return roundtrip(args)
        except DumpError as exc:
            print("%s ERROR: %s" % (GATE_TAG, exc))
            return 2
    if args.command == "shadow":
        try:
            return shadow(args)
        except DumpError as exc:
            print("%s ERROR: %s" % (GATE_TAG, exc))
            return 2
    if args.command == "diff":
        try:
            result = diff(load(args.a), load(args.b), args.first)
        except DumpError as exc:
            print("%s ERROR: %s" % (TAG, exc))
            return 2
        return 0 if result["identical"] else 1
    if args.runs < 2:
        print("%s ERROR: identity needs at least 2 runs" % GATE_TAG)
        return 2
    try:
        return gate(args)
    except DumpError as exc:
        print("%s ERROR: %s" % (GATE_TAG, exc))
        return 2


if __name__ == "__main__":
    sys.exit(main())
