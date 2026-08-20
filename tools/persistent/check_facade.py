#!/usr/bin/env python3
##
## check_facade.py — the acceptance gate for a delivered wall facade.
##
## WHY THIS EXISTS. A facade that violates the spec produces NO ERROR AT ALL:
## `TextureResolver` returns Tier.NONE, the surface falls back to the generic
## atlas, and the material just looks vaguely wrong. That has already cost this
## project one delivery — the first `facade_earth.png` arrived full-colour and
## was caught only because somebody measured the file. Eyeballing it in the
## editor cannot catch either failure mode, because both render *something*.
##
## Checks, in the order they bite:
##   1. dimensions      — 1024x512 exactly (FACADE_W/FACADE_H, bake_compositor.gd)
##   2. grayscale       — R == G == B on every pixel (invariant B2)
##   3. alpha           — reported, not enforced. B3 says the silhouette comes
##                        from the canonical voxel atom, so facade alpha is
##                        simply ignored; the SHIPPED facade_concrete.png
##                        carries alpha down to 224 and renders correctly. A
##                        gate that failed it would be failing known-good art
##   4. imported        — the .import sidecar's own `dest_files` exist on disk.
##                        NOT an mtime comparison: Godot rewrites the compiled
##                        .ctex without touching the sidecar's mtime, so mtime
##                        flags known-good art (measured: facade_metal.png)
##
## Usage:
##     python3 tools/persistent/check_facade.py <file.png> [<file.png> ...]
##     python3 tools/persistent/check_facade.py --all
##
## Exit code is 0 only if every file PASSes, so it can gate a delivery.

import os
import sys

try:
    from PIL import Image
except ImportError:
    print("[FACADE] Pillow is required: python3 -m pip install pillow")
    sys.exit(2)

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DEFAULTS_DIR = os.path.join(REPO_ROOT, "ASSETS", "TEXTURES", "defaults")

## Pinned in bake_compositor.gd. A facade is authored FLAT at 16 texels/voxel:
## 1024/16 = 64 voxel columns, 512/16 = 32 voxel rows = 4 storeys. Never
## pre-squared to 1024x1024 — D34 reaches the second 512 by mirroring.
FACADE_W = 1024
FACADE_H = 512

## Grayscale means R == G == B. The tolerance is for PNG quantisation, not for
## "a bit of colour": the rejected earth delivery was over this by a mile.
CHANNEL_TOLERANCE = 2


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
    if (w, h) != (FACADE_W, FACADE_H):
        ok = False
        extra = ""
        if (w, h) == (FACADE_W, FACADE_W):
            extra = "  <- pre-squared; author 1024x512, the compositor mirrors it"
        notes.append("dimensions %dx%d, expected %dx%d%s" % (w, h, FACADE_W, FACADE_H, extra))

    ## 2. Grayscale, every pixel. Not sampled — a colour cast can live in one
    ## band, and this file is small enough that the full pass is instant.
    rgb = im.convert("RGB")
    non_gray = 0
    total = w * h
    for r, g, b in list(rgb.getdata()):
        if max(r, g, b) - min(r, g, b) > CHANNEL_TOLERANCE:
            non_gray += 1
    if non_gray:
        ok = False
        notes.append("non-grayscale on %d of %d pixels (%.2f%%) — B2; colour comes "
                     "from base_color via MULTIPLY, not from the art"
                     % (non_gray, total, 100.0 * non_gray / total))

    ## 3. Alpha — REPORTED, NEVER FAILED, and that is a correction rather than a
    ## leniency. This check originally failed any alpha below 255, and the first
    ## run of this script failed the SHIPPED facade_concrete.png (min alpha 224),
    ## which renders correctly in game and has for months. B3 is the reason: the
    ## silhouette's alpha comes from the canonical voxel atom, so whatever a
    ## facade carries in that channel is discarded. A gate that fails known-good
    ## art is measuring the wrong thing.
    if "A" in im.getbands():
        alpha = im.convert("RGBA").getchannel("A")
        lo, _hi = alpha.getextrema()
        if lo < 255:
            notes.append("note: alpha channel dips to %d. Harmless — B3 discards "
                         "facade alpha — but it means the export carried a channel "
                         "nothing reads." % lo)

    ## 4. Imported. The silent killer: TextureResolver goes through
    ## ResourceLoader.exists(), so an un-imported PNG is invisible to the bake.
    ##
    ## The check is "does the COMPILED resource exist", not "is the sidecar
    ## newer than the PNG". An mtime comparison was the first version and it
    ## failed facade_metal.png, which renders fine: Godot rewrites
    ## .godot/imported/<name>-<hash>.ctex on reimport and leaves the sidecar's
    ## mtime alone. Reading `dest_files` asks the question that actually matters.
    imp = path + ".import"
    if not os.path.exists(imp):
        ok = False
        notes.append("no .import sidecar — Godot has not imported this file, so the "
                     "bake cannot see it. Focus the editor, or run: "
                     "godot --headless --import --path .")
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


def main():
    args = sys.argv[1:]
    if not args:
        print(__doc__.strip().split("## Usage:")[1].strip())
        return 2

    if args == ["--all"]:
        paths = sorted(
            os.path.join(DEFAULTS_DIR, f)
            for f in os.listdir(DEFAULTS_DIR)
            if f.startswith("facade_") and f.endswith(".png")
        )
        if not paths:
            print("[FACADE] no facade_*.png found in %s" % DEFAULTS_DIR)
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
    print("[FACADE] %d file(s), %s" % (len(paths), "all PASS" if all_ok else "FAILURES above"))
    return 0 if all_ok else 1


if __name__ == "__main__":
    sys.exit(main())
