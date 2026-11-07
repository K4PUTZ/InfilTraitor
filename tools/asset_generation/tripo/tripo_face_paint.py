# tripo_face_paint.py — the head's MASTER map, painted on FaceUV (CHARACTER §7a TX-3, ACTOR D108, 2026-11-06). Plain Python (numpy + PIL).
# Starts from tripo_face_uv.py's maps (Tripo's colour on FaceUV, the hair cover, the valid mask) and lays OUR layers over it, each driven by
# face_paint.json (per figure, in map pixels of the 2048 master, x right = the figure's left as a front view sees it, y down):
#   (1) fill: texels that must be skin are repainted from the skin around them (a push-pull fill): Tripo's painted hair on the forehead
#       (dark, not under our hair, above `brow_line`, outside the eye boxes), the boxes in `fill_rects` (dark texels), and colours in
#       `fill_hues` (the male's blue collar painted on his neck);
#   (2) scalp: what our hair covers takes the hair's colour (a gap in the locks reads as hair, not as skin or Tripo's black);
#   (3) brows and `strokes` (the upper lash line): strokes (a quadratic curve, width tapering inner -> outer), mirrored about `mid_x`;
#   (4) lips: an ellipse tinted toward `lips.colour` keeping the shading (multiply), the mouth line darkened.
# The result is the master; the game's map is this file downscaled (tripo_face_apply.py), nothing is painted twice. The Director paints it
# BY HAND in Blender (tripo_face_paint_file.py, from 2026-11-08): a figure marked `"hand": true` in face_paint.json is refused here, since a
# re-run starts from Tripo's colour and would wipe the hand paint; FP_FORCE=1 overrides (and loses it).
# Env: FP_FIG, FP_IN (tripo_face_uv's folder), FP_SPEC (default face_paint.json beside this file), FP_OUT (the master PNG), FP_FORCE.
import json, os, sys
import numpy as np
from PIL import Image, ImageFilter

FIG = os.environ["FP_FIG"]; IN = os.environ["FP_IN"]; OUT = os.environ["FP_OUT"]
SPEC = json.load(open(os.environ.get("FP_SPEC", os.path.join(os.path.dirname(os.path.abspath(__file__)), "face_paint.json"))))[FIG]
if SPEC.get("hand") and os.path.exists(OUT) and os.environ.get("FP_FORCE") != "1":
    sys.exit(f"[tripo_face_paint] {FIG}: the master is painted BY HAND (face_paint.json \"hand\": true); a re-run would wipe it. FP_FORCE=1 to override")
A = np.asarray(Image.open(f"{IN}/{FIG}_base.png").convert("RGB")).astype(np.float32) / 255.0
H, W = A.shape[:2]
valid = np.load(f"{IN}/{FIG}_valid.npy")
cov_s = np.load(f"{IN}/{FIG}_hair.npy")
cov = np.asarray(Image.fromarray((cov_s * 255).astype(np.uint8)).resize((W, H), Image.BILINEAR)
                 .filter(ImageFilter.GaussianBlur(SPEC.get("hair_soft_px", 6)))).astype(np.float32) / 255.0
ys, xs = np.mgrid[0:H, 0:W]
lum = A.mean(2)
hexrgb = lambda h: np.array([int(h[i:i + 2], 16) for i in (1, 3, 5)], np.float32) / 255.0


def push_pull(img, known):
    """fill the unknown texels of img (H, W, 3) from the known ones, coarse to fine"""
    levels = []; a = img * known[..., None]; w = known.astype(np.float32)
    while min(a.shape[:2]) > 4:
        levels.append((a, w))
        h2, w2 = a.shape[0] // 2, a.shape[1] // 2
        a = a[:h2 * 2, :w2 * 2].reshape(h2, 2, w2, 2, 3).sum((1, 3)); w = w[:h2 * 2, :w2 * 2].reshape(h2, 2, w2, 2).sum((1, 3))
    col = a / np.maximum(w, 1e-6)[..., None]
    for a_, w_ in reversed(levels):
        up = np.asarray(Image.fromarray(np.clip(col * 255, 0, 255).astype(np.uint8)).resize((a_.shape[1], a_.shape[0]), Image.BILINEAR)).astype(np.float32) / 255.0
        here = a_ / np.maximum(w_, 1e-6)[..., None]; k = np.clip(w_, 0, 1)[..., None]
        col = here * k + up * (1 - k)
    return col


def soft(mask, px):
    return np.asarray(Image.fromarray((mask * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(px))).astype(np.float32) / 255.0


# (1) fill
eyes = np.zeros((H, W), bool)
for ex, ey, rx, ry in SPEC.get("eye_boxes", []):
    eyes |= ((xs - ex) / rx) ** 2 + ((ys - ey) / ry) ** 2 <= 1.0
fill = np.zeros((H, W), bool)
fb = SPEC.get("forehead")
if fb:
    fill |= valid & (lum < fb["dark"]) & (cov < 0.5) & (ys < fb["brow_line"]) & ~eyes
    if "all_above" in fb:                                                  # every forehead texel above this row (Tripo's shading under the fringe read as a grey band, 2026-11-07)
        fill |= valid & (cov < 0.5) & (ys < fb["all_above"]) & ~eyes
for x0, y0, x1, y1, dark in SPEC.get("fill_rects", []):
    fill |= valid & (xs >= x0) & (xs <= x1) & (ys >= y0) & (ys <= y1) & (lum < dark)
for hue in SPEC.get("fill_hues", []):
    if hue == "blue":
        fill |= valid & (A[..., 2] > A[..., 0] + 0.04) & (A[..., 2] > A[..., 1] + 0.05)
fill = soft(fill.astype(np.float32), 1.5) > 0.2
known = valid & ~fill & (cov < 0.5) & ~eyes                              # never the sclera: the lids would turn white
ss = SPEC.get("skin_source")
if ss:                                                                    # read the skin from the face band only (the fused skull's texels are not skin)
    known &= (ys >= ss[0]) & (ys <= ss[1]) & (lum >= ss[2])
skin = push_pull(A, known)
out = np.where(fill[..., None], skin, A)
es = SPEC.get("eye_skin")                                                 # [tolerance, feather px]: inside the eye boxes, the texels that are SKIN (close to the
if es:                                                                    # fill's skin) take the fill: Tripo's lighter under-eye left a box around each eye (2026-11-07)
    near = eyes & valid & (np.abs(A - skin).max(2) < es[0])
    k = soft(near.astype(np.float32), es[1])[..., None] * eyes[..., None]
    out = out * (1 - k) + skin * k
# (2) scalp
hc = hexrgb(SPEC["hair_colour"])
out = out * (1 - cov[..., None]) + hc[None, None, :] * cov[..., None]


# (3) brows
def stroke(p0, p1, p2, w0, w1, col, alpha):
    t = np.linspace(0, 1, 200)[:, None]
    pts = (1 - t) ** 2 * np.array(p0) + 2 * (1 - t) * t * np.array(p1) + t ** 2 * np.array(p2)
    wid = w0 + (w1 - w0) * t[:, 0]
    m = np.zeros((H, W), np.float32)
    x0, y0 = (pts.min(0) - max(w0, w1)).astype(int); x1, y1 = (pts.max(0) + max(w0, w1)).astype(int)
    sy, sx = np.mgrid[y0:y1, x0:x1]
    d = np.full(sy.shape, 1e9, np.float32); wn = np.zeros(sy.shape, np.float32)
    for (px, py), ww in zip(pts, wid):
        dd = np.hypot(sx - px, sy - py) / (ww / 2.0)
        better = dd < d; d[better] = dd[better]; wn[better] = ww
    m[y0:y1, x0:x1] = np.clip(1.5 - d * 1.2, 0, 1)                      # soft edge
    m = soft(m, 1.2) * alpha
    return m
for bspec in ([SPEC["brows"]] if "brows" in SPEC else []) + SPEC.get("strokes", []):   # the brows, then any other stroke (the upper lash line)
    bc = hexrgb(bspec["colour"]); mid = SPEC["mid_x"]
    for side in (1, -1):
        pts = [(mid + side * (x - mid), y) for x, y in bspec["curve"]]
        m = stroke(pts[0], pts[1], pts[2], bspec["width"][0], bspec["width"][1], bc, bspec["alpha"])
        out = out * (1 - m[..., None]) + bc[None, None, :] * m[..., None]
# (4) lips
lp = SPEC.get("lips")
if lp:
    cx, cy, rx, ry = lp["ellipse"]
    e = np.clip(1.0 - (((xs - cx) / rx) ** 2 + ((ys - cy) / ry) ** 2), 0, 1)
    e = soft((e > 0).astype(np.float32), lp.get("soft_px", 6)) * np.clip(e * 3, 0, 1)
    tint = hexrgb(lp["colour"]) / max(float(np.median(skin[known][:, :].mean(1))), 1e-3)
    out = out * (1 - lp["strength"] * e[..., None]) + np.clip(out * tint[None, None, :], 0, 1) * (lp["strength"] * e[..., None])
    ly, lw, ld = lp["line"]
    line = np.exp(-((ys - ly) / lw) ** 2) * (e > 0.05)
    out = out * (1 - ld * line[..., None])
out[~valid] = out[~valid] * 0 + hc                                        # no texel left black for a filter to bleed in
Image.fromarray((np.clip(out, 0, 1) * 255 + 0.5).astype(np.uint8)).save(OUT)
print(f"[tripo_face_paint] {FIG}: filled {int(fill.sum())} texels, scalp {float((cov > 0.5).mean() * 100):.1f} %, wrote {OUT}")
