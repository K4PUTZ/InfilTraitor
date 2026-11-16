"""ITEMS_MASTER_PLAN §2.11 — cut a Nano Banana reference sheet (rows = objects, two columns = two views) into one clean image per
object per view, for Tripo's multi-view input.

The image model draws labels, dimension lines and arrows even when told not to, so the cut keeps only the OBJECTS: the pixels that
differ from the background are opened (thin strokes, text and arrows vanish), the surviving blobs locate the objects, and each object
is cut back out of the original with a small dilation (its own thin parts survive, a stroke that does not touch it does not). Blobs in
the same row and the same column are one view (the spray can and its cap). Both views of an object share ONE scale and the row's
vertical span (Director, 2026-11-16: the front and the side must keep their relative size), squared on the sheet's background.
Run: python3 tools/asset_generation/items/crop_sheet.py <sheet.jpg> <out_dir> --names taser,brass_knuckles,... [--size 1024]
Writes <out_dir>/<name>_front.png and <name>_side.png (--left says which column is which) and <out_dir>/_check.png."""
import argparse, os
import numpy as np
from PIL import Image
from scipy import ndimage

ap = argparse.ArgumentParser()
ap.add_argument("sheet"); ap.add_argument("out")
ap.add_argument("--names", required=True)
ap.add_argument("--size", type=int, default=1024)
ap.add_argument("--left", choices=("front", "side"), default="front", help="which view the sheet's LEFT column is (as prompted)")
ap.add_argument("--threshold", type=int, default=18)
ap.add_argument("--open", type=int, default=7, help="opening kernel: strokes thinner than this are dropped")
ap.add_argument("--keep", type=int, default=8, help="dilation (px) that brings an object's own thin parts back")
args = ap.parse_args()

img = np.asarray(Image.open(args.sheet).convert("RGB")).astype(np.int16)
H, W, _ = img.shape
corners = np.concatenate([img[:8, :8].reshape(-1, 3), img[:8, -8:].reshape(-1, 3), img[-8:, :8].reshape(-1, 3), img[-8:, -8:].reshape(-1, 3)])
bg = np.median(corners, axis=0)
mask = np.abs(img - bg).max(axis=2) > args.threshold
core = ndimage.binary_opening(mask, structure=np.ones((args.open, args.open)))
lab, n = ndimage.label(core)
blobs = []
for i, sl in enumerate(ndimage.find_objects(lab), start=1):
    area = int((lab[sl] == i).sum())
    if area < 0.0015 * H * W:
        continue
    cy, cx = (sl[0].start + sl[0].stop) / 2.0, (sl[1].start + sl[1].stop) / 2.0
    blobs.append({"id": i, "cy": cy, "col": 0 if cx < W / 2.0 else 1, "y0": sl[0].start, "y1": sl[0].stop})

# Rows: blobs whose vertical spans overlap belong to one row.
blobs.sort(key=lambda b: b["cy"])
rows = []
for b in blobs:
    if rows and b["y0"] < max(x["y1"] for x in rows[-1]):
        rows[-1].append(b)
    else:
        rows.append([b])
names = args.names.split(",")
if len(rows) != len(names):
    raise SystemExit("found %d rows, %d names given: %s" % (len(rows), len(names), [round(r[0]["cy"]) for r in rows]))

os.makedirs(args.out, exist_ok=True)
cuts = []
views = (("front", "side") if args.left == "front" else ("side", "front"))
for name, row in zip(names, rows):
    # ONE scale per object: both views are cut from the row's common vertical span and squared on the same side, so the
    # front and the side keep the sheet's relative size and height (Tripo reads the two as one object).
    found = []
    for col, view in ((0, views[0]), (1, views[1])):
        ids = [b["id"] for b in row if b["col"] == col]
        if not ids:
            print("[crop] %s: nothing in the %s column" % (name, view)); continue
        seed = np.isin(lab, ids)
        region = ndimage.binary_dilation(seed, iterations=args.keep) & mask
        parts, _ = ndimage.label(region)   # a stroke the dilation reached but that does not touch the object goes
        region = np.isin(parts, np.unique(parts[seed & region])) & (parts > 0)
        ys, xs = np.nonzero(region)
        found.append((view, region, ys.min(), ys.max() + 1, xs.min(), xs.max() + 1))
    if not found:
        continue
    ry0, ry1 = min(f[2] for f in found), max(f[3] for f in found)
    side = int(max([ry1 - ry0] + [f[5] - f[4] for f in found]) * 1.15)
    for view, region, y0, y1, x0, x1 in found:
        out = np.where(region[..., None], img, bg).astype(np.uint8)[ry0:ry1, x0:x1]
        canvas = np.empty((side, side, 3), np.uint8); canvas[:] = bg.astype(np.uint8)
        oy, ox = (side - (ry1 - ry0)) // 2, (side - (x1 - x0)) // 2
        canvas[oy:oy + ry1 - ry0, ox:ox + x1 - x0] = out
        im = Image.fromarray(canvas).resize((args.size, args.size), Image.LANCZOS)
        path = os.path.join(args.out, "%s_%s.png" % (name, view))
        im.save(path); cuts.append(im)
        print("[crop] %s  (%d x %d px on the sheet)" % (path, x1 - x0, y1 - y0))

thumb = 256
check = Image.new("RGB", (thumb * 2, thumb * ((len(cuts) + 1) // 2)), "white")
for i, im in enumerate(cuts):
    check.paste(im.resize((thumb, thumb)), ((i % 2) * thumb, (i // 2) * thumb))
check.save(os.path.join(args.out, "_check.png"))
