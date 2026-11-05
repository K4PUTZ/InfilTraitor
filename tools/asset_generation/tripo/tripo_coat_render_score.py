# tripo_coat_render_score.py — counts what the flat renders of tripo_coat_counterfactual.py (CF_RENDER) show, per row, clip and frame (the four views summed). System python, no Blender.
# BELT and SHIRT: their pixels. THROUGH: trouser pixels with coat BELOW them in the same column, so a leg through the cloth counts and a leg in the open slit or under the hem does not. FLECKS: shirt pixels outside the shirt's largest connected patch of each view (the opening's). LINING: pixels of the coat's inner wall.
# Usage: python3 tools/asset_generation/tripo/tripo_coat_render_score.py temp/coat_study/render [figure ...]
import collections
import glob
import os
import re
import sys
import numpy as np
from PIL import Image
from scipy import ndimage


def srgb(c):
    return tuple(int(round(255 * (x * 12.92 if x <= .0031308 else 1.055 * x ** (1 / 2.4) - .055))) for x in c)


PAL = {"belt": srgb((.9, .75, .05)), "shirt": srgb((.95, .95, .95)), "trousers": srgb((.05, .2, .8)), "coat": srgb((.1, .65, .25)), "lining": srgb((.05, .85, .85))}


def mask(a, c):
    return np.abs(a - np.array(c)).max(2) < 14


def score(path):
    a = np.array(Image.open(path).convert("RGB")).astype(int)
    coat, trou, shirt = mask(a, PAL["coat"]), mask(a, PAL["trousers"]), mask(a, PAL["shirt"])
    lining = mask(a, PAL["lining"])
    cloth = coat | lining
    # rows grow downward: a column's cloth below a row = cumulative from the bottom
    below = np.flip(np.logical_or.accumulate(np.flip(cloth, 0), 0), 0)
    lab, n = ndimage.label(shirt)
    flecks = 0
    if n:
        sizes = ndimage.sum(shirt, lab, range(1, n + 1))
        flecks = int(sizes.sum() - sizes.max())
    # LIN_OUT: patches of lining with coat all around them: the inner wall coming through the outer one (the lining seen through the open front has other things beside it)
    lab, n = ndimage.label(lining)
    lin_out = 0
    for k, piece in enumerate(ndimage.find_objects(lab), 1):
        y0, x0 = max(piece[0].start - 1, 0), max(piece[1].start - 1, 0)
        window = (slice(y0, piece[0].stop + 1), slice(x0, piece[1].stop + 1))
        this = lab[window] == k
        ring = ndimage.binary_dilation(this) & ~this
        if ring.any() and coat[window][ring].mean() > 0.8:
            lin_out += int(this.sum())
    return dict(belt=int(mask(a, PAL["belt"]).sum()), shirt=int(shirt.sum()), through=int((trou & below).sum()), flecks=flecks, lining=int(lining.sum()), lin_out=lin_out)


root = sys.argv[1]
figures = sys.argv[2:] or sorted(d for d in os.listdir(root) if os.path.isdir(f"{root}/{d}"))
KEYS = ("belt", "shirt", "through", "flecks", "lin_out", "lining")
for fig in figures:
    rows = sorted(d for d in os.listdir(f"{root}/{fig}") if os.path.isdir(f"{root}/{fig}/{d}"))
    order = ["today", "keys"] + [r for r in rows if r not in ("today", "keys")]
    print(f"== {fig}: per clip, mean / worst over the frames of the four views' sum")
    print(f"{'row':22s} {'clip':5s} " + " ".join(f"{k:>12s}" for k in KEYS))
    for row in order:
        if row not in rows:
            continue
        per = collections.defaultdict(lambda: collections.defaultdict(lambda: collections.Counter()))
        for p in glob.glob(f"{root}/{fig}/{row}/*_v?.png"):
            clip, f, v = re.match(r"(\w+?)_f(\d+)_v(\d)\.png", os.path.basename(p)).groups()
            per[clip][int(f)].update(score(p))
        for clip in sorted(per):
            cells = []
            for k in KEYS:
                vals = [per[clip][f][k] for f in per[clip]]
                cells.append(f"{np.mean(vals):6.0f}/{max(vals):5d}")
            print(f"{row:22s} {clip:5s} " + " ".join(cells))
