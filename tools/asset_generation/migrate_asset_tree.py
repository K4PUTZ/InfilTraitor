#!/usr/bin/env python3
"""
migrate_asset_tree.py — ASSET_TREE_REFORM: move the material art into one folder
per material (`ASSETS/materials/<id>/`).

WHY THIS IS A COMMITTED TOOL AND NOT A ONE-OFF SHELL LINE, which is the whole
reason it exists. `.gitignore:52` excludes `ASSETS/*` by an explicit Director
decision (2026-07-16, heavy binaries stay local), so **not one of the 99 material
PNGs is tracked by git**. Two consequences, both load-bearing:

  1. `git mv` cannot be used, and there is no `git checkout` to undo a bad move.
     BACK THE FOLDERS UP BEFORE RUNNING THIS. It refuses to overwrite, but a
     half-finished run on an unbacked tree is unrecoverable art.
  2. The reform's file moves are INVISIBLE to the repo. A second machine that
     pulls the code flip without moving its own files gets `Tier.NONE` on every
     material — which renders something and reports nothing. So the move has to
     ship as a script anyone can replay, and that script is this file.

Idempotent: a file already at its destination is skipped, so re-running after a
partial run finishes the job instead of doubling it.

A PNG's `.import` sidecar travels with it and has its `source_file` rewritten.
The `uid` survives (it lives in the sidecar); Godot regenerates `path` and
`dest_files` on the next import, because the compiled `.ctex` name is hashed
from the source path. **Always run `godot --headless --path . --import`
afterwards**, then the two acceptance gates:

    python3 tools/persistent/check_facade.py --all
    python3 tools/persistent/check_decal.py --all

Usage:
    python3 tools/asset_generation/migrate_asset_tree.py --plan    # print, move nothing
    python3 tools/asset_generation/migrate_asset_tree.py --apply
"""

import os
import re
import shutil
import sys

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DEST_ROOT = os.path.join("ASSETS", "materials")

FACADE_DIR = os.path.join("ASSETS", "TEXTURES", "defaults")
VOXEL_DIR = os.path.join("ASSETS", "ISOMETRIC", "source_assets", "voxels")

## The material-agnostic decal family (D25) belongs to no material, so it gets a
## folder that cannot collide with one — the leading underscore is deliberate.
GENERIC_DIR = "_generic"


def _plan_facades():
    """facade_<id>.png / slab_<id>.png -> materials/<id>/<same name>."""
    out = []
    src = os.path.join(REPO_ROOT, FACADE_DIR)
    if not os.path.isdir(src):
        return out
    for f in sorted(os.listdir(src)):
        m = re.match(r"^(?:facade|slab)_(.+)\.png$", f)
        if not m:
            continue
        out.append((os.path.join(FACADE_DIR, f),
                    os.path.join(DEST_ROOT, m.group(1), f)))
    return out


def _plan_voxels():
    """voxels/materials/voxel_<id>.png -> materials/<id>/<same name>.

    `voxel_earth_0..7` are the eight earth variants, not eight materials —
    EarthVariantSelector indexes them. The regex strips the trailing index so
    they land together in `earth/`, which is the one place a naive
    split-on-underscore would have quietly created eight bogus folders.
    """
    out = []
    src = os.path.join(REPO_ROOT, VOXEL_DIR, "materials")
    if not os.path.isdir(src):
        return out
    for f in sorted(os.listdir(src)):
        m = re.match(r"^voxel_(.+?)(?:_(\d+))?\.png$", f)
        if not m:
            continue
        out.append((os.path.join(VOXEL_DIR, "materials", f),
                    os.path.join(DEST_ROOT, m.group(1), f)))
    return out


def _plan_halves():
    """voxels/halves/voxel_<id>_half_<side>.png -> materials/<id>/halves/."""
    out = []
    src = os.path.join(REPO_ROOT, VOXEL_DIR, "halves")
    if not os.path.isdir(src):
        return out
    for f in sorted(os.listdir(src)):
        m = re.match(r"^voxel_(.+)_half_(top|bottom|left|right)\.png$", f)
        if not m:
            continue
        out.append((os.path.join(VOXEL_DIR, "halves", f),
                    os.path.join(DEST_ROOT, m.group(1), "halves", f)))
    return out


def _plan_decals():
    """voxels/decals/decal_<family>_<id>_<n>.png -> materials/<id>/decals/.

    `decal_generic_*` is the material-agnostic family and goes to `_generic/`.
    Non-decal files in that folder (README.txt, the authoring template) stay
    where they are: they are documentation and a canvas, not a material's art.
    """
    out = []
    src = os.path.join(REPO_ROOT, VOXEL_DIR, "decals")
    if not os.path.isdir(src):
        return out
    for f in sorted(os.listdir(src)):
        if not f.startswith("decal_") or not f.endswith(".png"):
            continue
        if f.startswith("decal_generic_"):
            out.append((os.path.join(VOXEL_DIR, "decals", f),
                        os.path.join(DEST_ROOT, GENERIC_DIR, "decals", f)))
            continue
        m = re.match(r"^decal_(?:bullet|dent|crack)_(.+)_\d+\.png$", f)
        if not m:
            print("  ⚠ unrecognised decal name, LEFT IN PLACE: %s" % f)
            continue
        out.append((os.path.join(VOXEL_DIR, "decals", f),
                    os.path.join(DEST_ROOT, m.group(1), "decals", f)))
    return out


def _plan_json():
    """materials/<id>.json -> ASSETS/materials/<id>/<id>.json."""
    out = []
    src = os.path.join(REPO_ROOT, "materials")
    if not os.path.isdir(src):
        return out
    for f in sorted(os.listdir(src)):
        if not f.endswith(".json"):
            continue
        out.append((os.path.join("materials", f),
                    os.path.join(DEST_ROOT, f[:-len(".json")], f)))
    return out


PLANNERS = {
    "facades": _plan_facades,
    "voxels": _plan_voxels,
    "halves": _plan_halves,
    "decals": _plan_decals,
    "json": _plan_json,
}


def _move(rel_src, rel_dst):
    src = os.path.join(REPO_ROOT, rel_src)
    dst = os.path.join(REPO_ROOT, rel_dst)
    if not os.path.exists(src):
        return "absent"
    if os.path.exists(dst):
        ## Idempotent, but never destructive: a destination that already exists
        ## is a completed move OR a collision, and this tool refuses to decide
        ## which. `ASSETS/*` is untracked, so an overwrite here is art nobody can
        ## get back.
        return "already-there"
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    shutil.move(src, dst)

    imp_src, imp_dst = src + ".import", dst + ".import"
    if os.path.exists(imp_src):
        shutil.move(imp_src, imp_dst)
        text = open(imp_dst, encoding="utf-8").read()
        old_res, new_res = "res://" + rel_src, "res://" + rel_dst
        if old_res not in text:
            print("  ⚠ %s did not name %s — sidecar left as found" % (rel_dst + ".import", old_res))
        open(imp_dst, "w", encoding="utf-8").write(text.replace(old_res, new_res))
    return "moved"


def main() -> int:
    args = sys.argv[1:]
    apply_it = "--apply" in args
    if not apply_it and "--plan" not in args:
        print(__doc__.strip().split("Usage:")[1].strip())
        return 2

    families = [a for a in args if not a.startswith("--")] or list(PLANNERS)
    totals = {}
    for fam in families:
        if fam not in PLANNERS:
            print("unknown family %r — known: %s" % (fam, ", ".join(PLANNERS)))
            return 2
        pairs = PLANNERS[fam]()
        print("\n[%s] %d file(s)" % (fam.upper(), len(pairs)))
        counts = {}
        for rel_src, rel_dst in pairs:
            if apply_it:
                status = _move(rel_src, rel_dst)
            else:
                status = "would-move"
            counts[status] = counts.get(status, 0) + 1
            print("  %-14s %s -> %s" % (status, rel_src, rel_dst))
        totals[fam] = counts

    print("\n" + "=" * 60)
    for fam, counts in totals.items():
        print("%-10s %s" % (fam, counts))
    if apply_it:
        print("\nNOW RUN, in this order:")
        print("  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import")
        print("  python3 tools/persistent/check_facade.py --all")
        print("  python3 tools/persistent/check_decal.py --all")
    return 0


if __name__ == "__main__":
    sys.exit(main())
