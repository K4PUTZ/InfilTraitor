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


def diff(a, b, first=20, out=print):
    """Compare two loaded dumps. Returns a dict of counts; `identical` is the verdict."""
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

    identical = not (only_a or only_b or geometry or voxel_diffs or levels_only_a
                     or levels_only_b or plane_shape or texel_diffs)
    out("%s RESULT: %s" % (TAG, "IDENTICAL" if identical else
        "DIFFERENT — voxels %d, geometry %d, containers %d, plane texels %d, plane levels %d"
        % (voxel_diffs, len(geometry), len(only_a) + len(only_b), texel_diffs,
           len(levels_only_a) + len(levels_only_b) + len(plane_shape))))
    return {"identical": identical, "voxel_diffs": voxel_diffs, "voxels_compared": voxels_compared,
            "texel_diffs": texel_diffs, "geometry": len(geometry),
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


def run_once(godot, map_id, run_dir, extra_env):
    env = os.environ.copy()
    env.update({"INFILTRAITOR_MAP": map_id, "INFILTRAITOR_RNG_SEED": "1",
                "INFILTRAITOR_SCENARIO": GATE_SCENARIO})
    env.update(MAP_ENV.get(map_id, {}))
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
        if any(marker in line for marker in FATAL_MARKERS):
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
    missing = [label for label in GATE_LABELS if label not in probes]
    if missing:
        problems.append("probe(s) never written: %s" % ", ".join(missing))
    return probes, problems, time.time() - t0


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
    args = parser.parse_args()
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
