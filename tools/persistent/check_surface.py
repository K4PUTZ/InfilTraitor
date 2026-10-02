#!/usr/bin/env python3
##
## check_surface.py — the acceptance gate for a delivered photographic ground surface (R3D-SURFACES).
##
## WHY THIS EXISTS. A `slab_<id>.png` that violates the spec produces NO ERROR AT ALL, the same silent-failure
## shape `check_facade.py` was built to close: `TextureResolver` returns Tier.NONE on a wrong-size or unimported
## file and the material just falls back to its flat `base_color` (no photo role is applied) — it renders *something*,
## so eyeballing it in the editor cannot catch the mistake either.
##
## R3D-SURFACES's own design note (RENDER3D_MASTER_PLAN) picked REPEAT over the 2D bake's MIRROR specifically
## because mirroring hides a seam a photograph cannot hide — which makes a seam at the tile's own two borders a
## real defect this gate can and should catch, not a cosmetic nit. The four existing `slab_<id>.png` files
## (grass/dirt/gravel/sand) predate this rule: they were authored for the retired MIRROR compositor, so this
## gate is expected to fail them on border difference until they are re-authored or replaced (see the
## RENDER3D_MASTER_PLAN R3D-SURFACES block) — that is the gate doing its job, not a bug in the gate.
##
## Checks, in the order they bite:
##   1. dimensions      — 1024x1024 exactly (SURFACE_W/SURFACE_H; TEX_AUTHORING_N = 16 texels/voxel over the
##                        8x8 GU / 64x64 voxel plane the plan pins).
##   2. no alpha        — REJECTED here, unlike check_facade's alpha (reported only, B3 discards facade alpha).
##                        A surface plane is opaque, unshaded, no Godot blend mode (the plan's own wording); an
##                        alpha channel on one is wasted import memory at best and a silent blend-mode mismatch
##                        at worst.
##   3. border match    — the plane REPEATs (uniform sampler2D ... repeat_enable in board3d_live.gd), so its
##                        left/right and top/bottom edges must be close: a REPEAT of a non-matching edge is a
##                        hard visible seam every 8 GU. Reported as mean absolute channel difference; FAILs
##                        above a generous tolerance (this is a photograph, not a synthetic tile — some edge
##                        drift is normal, a hard mismatch is not).
##   3b. not mirrored   — (S4, 2026-10-02) a plane that equals its own mirror image on both axes was authored for the
##                        retired MIRROR compositor: its OUTER border matches by construction (check 3 passes it) while
##                        a kaleidoscope seam sits at its centre and REPEATs every 8 GU. Measured on the eight slab files:
##                        concrete / metal / wood differ from their mirror by 0.00-0.01 (mean channel, 0-255), the real
##                        photographs by 5.8 (sand) to 34.9 (gravel). Fails under MIRROR_TOLERANCE = 1.0.
##   4. imported        — the .import sidecar's own dest_files exist on disk (same check as check_facade.py,
##                        same reason: an mtime comparison flags known-good art after a plain reimport).
##
## Usage:
##     python3 tools/persistent/check_surface.py <file.png> [<file.png> ...]
##     python3 tools/persistent/check_surface.py --all        # every slab_*.png on disk
##     python3 tools/persistent/check_surface.py --declared   # the planes a material's `surfaces` actually uses (verify.py runs this)

import os
import sys

try:
    from PIL import Image
except ImportError:
    print("[SURFACE] Pillow is required: python3 -m pip install pillow")
    sys.exit(2)

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MATERIALS_ROOT = os.path.join(REPO_ROOT, "ASSETS", "materials")

## The plan's own spec: 1024x1024 = 64x64 voxels = 8x8 GU at TEX_AUTHORING_N = 16, same texel density as a
## facade, never pre-squared or split — the whole square is one continuous photograph.
SURFACE_W = 1024
SURFACE_H = 1024

## Mean absolute channel difference (0-255 scale) between a plane's opposite edges above which a REPEAT tile
## shows a visible seam. Not measured against a real seam-perception threshold yet (no accepted art exists to
## calibrate against) — generous on purpose so it flags an obvious mismatch (a hard colour change at the border)
## without failing plausible photographic noise. Revisit once the first accepted surface sets a real baseline.
BORDER_TOLERANCE = 18.0

## Mean absolute channel difference between a plane and its own mirror image (both axes) below which the art is a
## mirror-authored tile. See check 3b.
MIRROR_TOLERANCE = 1.0


def _image_diff(a, b):
    """Mean absolute channel difference of two same-size RGB images, 0-255."""
    from PIL import ImageChops, ImageStat
    return sum(ImageStat.Stat(ImageChops.difference(a, b)).mean) / 3.0


def check(path):
    """Returns (ok: bool, lines: list[str])."""
    name = os.path.basename(path)
    notes = []

    if not os.path.exists(path):
        return False, ["%-28s FAIL  file does not exist" % name]

    try:
        im = Image.open(path)
    except Exception as exc:
        return False, ["%-28s FAIL  not a readable image: %s" % (name, exc)]

    ok = True

    ## 1. Dimensions.
    w, h = im.size
    if (w, h) != (SURFACE_W, SURFACE_H):
        ok = False
        notes.append("dimensions %dx%d, expected %dx%d" % (w, h, SURFACE_W, SURFACE_H))

    ## 2. No alpha — rejected, not just reported (see the header: a surface plane is opaque by design).
    if "A" in im.getbands():
        alpha = im.convert("RGBA").getchannel("A")
        lo, hi = alpha.getextrema()
        if lo < 255:
            ok = False
            notes.append("carries an alpha channel (range %d-%d) — a surface plane is opaque, "
                         "no Godot blend mode; export without alpha" % (lo, hi))

    ## 3. Border match, only when the size is right (a wrong-size image has no border to compare in the
    ## plane's own units).
    if (w, h) == (SURFACE_W, SURFACE_H):
        rgb = im.convert("RGB")
        lr_diff = _image_diff(rgb.crop((0, 0, 1, h)), rgb.crop((w - 1, 0, w, h)))
        tb_diff = _image_diff(rgb.crop((0, 0, w, 1)), rgb.crop((0, h - 1, w, h)))
        worst = max(lr_diff, tb_diff)
        notes.append("border diff: left/right %.1f, top/bottom %.1f (tolerance %.1f)"
                     % (lr_diff, tb_diff, BORDER_TOLERANCE))
        if worst > BORDER_TOLERANCE:
            ok = False
            notes.append("REPEAT will show a seam at this plane's own edge — re-author "
                         "or replace (this art may predate the REPEAT rule; see check_surface.py's header)")

    ## 3b. Not mirror-authored.
    if (w, h) == (SURFACE_W, SURFACE_H):
        rgb = im.convert("RGB")
        mirror_lr = _image_diff(rgb, rgb.transpose(Image.FLIP_LEFT_RIGHT))
        mirror_tb = _image_diff(rgb, rgb.transpose(Image.FLIP_TOP_BOTTOM))
        notes.append("mirror diff: left-right %.2f, top-bottom %.2f (tolerance %.2f)" % (mirror_lr, mirror_tb, MIRROR_TOLERANCE))
        if mirror_lr < MIRROR_TOLERANCE and mirror_tb < MIRROR_TOLERANCE:
            ok = False
            notes.append("the plane is its own mirror image: authored for the retired MIRROR compositor, so REPEAT "
                         "shows a kaleidoscope seam at its centre — replace it with a real seamless photograph")

    ## 4. Imported.
    imp = path + ".import"
    if not os.path.exists(imp):
        ok = False
        notes.append("no .import sidecar — Godot has not imported this file. "
                     "Focus the editor, or run: godot --headless --import --path .")
    else:
        dests = []
        for line in open(imp, encoding="utf-8", errors="replace"):
            if line.startswith("dest_files="):
                dests = [d.strip().strip('"') for d in
                         line.split("[", 1)[-1].rstrip().rstrip("]").split(",") if d.strip()]
                break
        missing = [d for d in dests
                   if not os.path.exists(os.path.join(REPO_ROOT, d.replace("res://", "")))]
        if not dests:
            ok = False
            notes.append(".import sidecar names no dest_files — the import did not "
                         "complete. Run: godot --headless --import --path .")
        elif missing:
            ok = False
            notes.append("compiled resource missing (%s) — reimport: "
                         "godot --headless --import --path ." % ", ".join(missing))

    head = "%-28s %s  %dx%d %s" % (name, "PASS" if ok else "FAIL", w, h, im.mode)
    return ok, [head] + ["    - " + n for n in notes]


def declared_paths():
    """The `slab_<id>.png` of every material whose JSON declares a `photo` role (`surfaces`): the art the game draws. A slab
    file no material declares is unused (the old mirror-era art for concrete / metal / stone / wood) and not this gate's business."""
    import json
    paths = []
    for material in sorted(os.listdir(MATERIALS_ROOT)):
        row = os.path.join(MATERIALS_ROOT, material, material + ".json")
        if not os.path.isfile(row):
            continue
        surfaces = json.load(open(row, encoding="utf-8")).get("surfaces", {})
        if "photo" in surfaces.values():
            paths.append(os.path.join(MATERIALS_ROOT, material, "slab_%s.png" % material))
    return paths


def _usage_text():
    """See check_facade.py's identical helper for why this reads its own header
    instead of a docstring."""
    try:
        with open(__file__, encoding="utf-8") as fh:
            header = []
            for line in fh:
                if line.startswith("#"):
                    header.append(line.rstrip("\n"))
                elif header:
                    break
        text = "\n".join(header)
        if "## Usage:" in text:
            body = text.split("## Usage:")[1]
            return "Usage:\n" + "\n".join(
                l.lstrip("#").rstrip() for l in body.splitlines() if l.strip("# ").strip()
            )
    except OSError:
        pass
    return "Usage: python3 %s <file.png> [<file.png> ...] | --all" % __file__


def main():
    args = sys.argv[1:]
    if not args:
        print(_usage_text())
        return 2

    if args == ["--declared"]:
        paths = declared_paths()
        if not paths:
            print("[SURFACE] no material declares a photographic surface")
            return 1
    elif args == ["--all"]:
        paths = []
        for material in sorted(os.listdir(MATERIALS_ROOT)) if os.path.isdir(MATERIALS_ROOT) else []:
            mdir = os.path.join(MATERIALS_ROOT, material)
            if not os.path.isdir(mdir):
                continue
            paths.extend(sorted(
                os.path.join(mdir, f) for f in os.listdir(mdir)
                if f.startswith("slab_") and f.endswith(".png")
            ))
        if not paths:
            print("[SURFACE] no slab_*.png found under %s" % MATERIALS_ROOT)
            return 1
    else:
        paths = args

    all_ok = True
    for p in paths:
        ok, lines = check(p)
        all_ok = all_ok and ok
        for line in lines:
            print(line)

    print("")
    print("[SURFACE] %d file(s), %s" % (len(paths), "all PASS" if all_ok else "FAILURES above"))
    return 0 if all_ok else 1


if __name__ == "__main__":
    sys.exit(main())
