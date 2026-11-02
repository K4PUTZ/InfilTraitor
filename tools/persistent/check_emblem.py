#!/usr/bin/env python3
##
## check_emblem.py — the acceptance gate for a delivered coat EMBLEM (ACTOR D95, 2026-11-02): `ASSETS/emblems/emblem_<id>.png` (or .webp).
##
## WHY A GATE OF ITS OWN. The resolver (`TextureResolver`, the `emblem_` branch) rejects a bad file at RUN time with a log line and the coat stays plain; this catches it before the game boots,
## the way check_facade.py / check_decal.py do for theirs. It is NOT check_decal.py: "decal" is the damage marks' word (ART_SPECIFICATIONS §7).
##
## The contract (the same numbers the resolver enforces, plus the art rules the resolver cannot see):
##   1. filename   — emblem_<id>.png|webp, <id> lowercase letters, digits, underscore
##   2. size       — long side <= 1024 px, short side >= 16 px, file under 10 MB
##   3. alpha      — RGBA with real transparency: an opaque logo is a patch of cloth, not a mark (D90: the logo ALONE)
##   4. margin     — the outer 1 % of each side fully transparent (the projection CLIPs at the rectangle's edge; the reference skull's flames and chin come within 1.5 % of it: D95 first said 4 %,
##                   measured on the Director's art, 2026-11-02)
##   5. coverage   — reported; failed when under 2 % (nothing to see) or over 90 % (a rectangle, not a logo)
##
## Usage: python3 tools/persistent/check_emblem.py [path ...]   (default: every file under ASSETS/emblems/)   Exit 0 = all pass.
import os
import re
import sys

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
EMBLEM_DIR = os.path.join(REPO_ROOT, "ASSETS", "emblems")
NAME = re.compile(r"^emblem_[a-z0-9_]+\.(png|webp)$")
MAX_SIDE, MIN_SIDE, MAX_BYTES, MARGIN = 1024, 16, 10 * 1024 * 1024, 0.01


def check(path):
    from PIL import Image
    fails = []
    name = os.path.basename(path)
    if not NAME.match(name):
        fails.append(f"filename {name!r} is not emblem_<id>.png|webp (lowercase, digits, underscore)")
    if os.path.getsize(path) > MAX_BYTES:
        fails.append(f"file is {os.path.getsize(path) / 1048576:.1f} MB (cap 10 MB)")
    im = Image.open(path)
    w, h = im.size
    if max(w, h) > MAX_SIDE or min(w, h) < MIN_SIDE:
        fails.append(f"size {w}x{h} outside {MIN_SIDE}..{MAX_SIDE} px")
    if im.mode not in ("RGBA", "LA", "PA") and "transparency" not in im.info:
        fails.append(f"mode {im.mode} carries no alpha")
        return fails, 0.0
    a = im.convert("RGBA").getchannel("A")
    lo, hi = a.getextrema()
    if lo > 0:
        fails.append("no transparent pixel at all (an opaque logo is a patch, not a mark)")
    mx, my = int(w * MARGIN), int(h * MARGIN)
    for label, box in (("left", (0, 0, mx, h)), ("right", (w - mx, 0, w, h)), ("top", (0, 0, w, my)), ("bottom", (0, h - my, w, h))):
        if box[2] > box[0] and box[3] > box[1] and a.crop(box).getextrema()[1] > 0:
            fails.append(f"the {label} 1 % margin is not transparent (the zone would cut the art)")
    cover = sum(a.histogram()[9:]) / float(w * h)
    if cover < 0.02 or cover > 0.90:
        fails.append(f"coverage {cover:.1%} (want 2..90 %)")
    return fails, cover


def main():
    paths = sys.argv[1:] or sorted(os.path.join(EMBLEM_DIR, f) for f in os.listdir(EMBLEM_DIR) if f.lower().endswith((".png", ".webp"))) if os.path.isdir(EMBLEM_DIR) else []
    if not paths:
        print("check_emblem: no emblems under ASSETS/emblems/ (nothing to check)")
        return 0
    bad = 0
    for p in paths:
        fails, cover = check(p)
        print(f"{'FAIL' if fails else 'PASS'}  {os.path.relpath(p, REPO_ROOT)}  coverage {cover:.1%}")
        for f in fails:
            print(f"      - {f}")
        bad += bool(fails)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
