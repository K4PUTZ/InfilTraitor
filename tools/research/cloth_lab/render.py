"""render.py — a software renderer for the lab (PIL): the game's iso camera (30 deg elevation, 45 deg azimuth), flat shading,
painter's order, plus a section profile plot. Substitution to declare: this is NOT Godot and NOT Blender; it shows the physics only."""
import math
import numpy as np
from PIL import Image, ImageDraw, ImageFont

EL, AZ = math.radians(30.0), math.radians(45.0)
LIGHT = np.array([0.35, 0.85, 0.40]); LIGHT /= np.linalg.norm(LIGHT)
CAM = np.array([math.cos(EL) * math.sin(AZ), math.sin(EL), math.cos(EL) * math.cos(AZ)])   # points toward the camera
RIGHT = np.array([math.cos(AZ), 0.0, -math.sin(AZ)])
UP = np.cross(CAM, RIGHT)
if UP[1] < 0:
    UP = -UP


def font(size):
    try:
        return ImageFont.load_default(size=size)
    except TypeError:
        return ImageFont.load_default()


class Camera:
    def __init__(self, centre, scale, size):
        self.c, self.s, self.size = np.asarray(centre, float), scale, size

    def project(self, P):
        P = np.asarray(P, float) - self.c
        u = P @ RIGHT
        v = P @ UP
        return np.stack([self.size[0] * 0.5 + u * self.s, self.size[1] * 0.5 - v * self.s], axis=-1)

    @staticmethod
    def depth(P):
        return np.asarray(P, float) @ CAM          # larger = nearer the camera


def box_quads(lo, hi, step=0.25):
    """Six faces of a box, split into small quads so the painter's sort stays honest next to the cloth."""
    lo, hi = np.asarray(lo, float), np.asarray(hi, float)
    quads = []
    for axis in range(3):
        a1, a2 = [k for k in range(3) if k != axis]
        n1 = max(1, int(round((hi[a1] - lo[a1]) / step)))
        n2 = max(1, int(round((hi[a2] - lo[a2]) / step)))
        for side in (0, 1):
            normal = np.zeros(3); normal[axis] = -1.0 if side == 0 else 1.0
            if normal @ CAM <= 0:
                continue
            for i in range(n1):
                for j in range(n2):
                    q = []
                    for (di, dj) in ((0, 0), (1, 0), (1, 1), (0, 1)):
                        p = np.zeros(3)
                        p[axis] = lo[axis] if side == 0 else hi[axis]
                        p[a1] = lo[a1] + (hi[a1] - lo[a1]) * (i + di) / n1
                        p[a2] = lo[a2] + (hi[a2] - lo[a2]) * (j + dj) / n2
                        q.append(p)
                    quads.append((np.array(q), normal))
    return quads


def render_scene(grid, cam, boxes, base_color, pinned=None, size=(800, 720), ss=2, post=None, title=None):
    W, H = size[0] * ss, size[1] * ss
    cam2 = Camera(cam.c, cam.s * ss, (W, H))
    img = Image.new("RGB", (W, H), (28, 30, 34))
    dr = ImageDraw.Draw(img)
    # floor tiles
    for gx in range(11, 23):
        a, b = cam2.project([gx, 0, 3]), cam2.project([gx, 0, 13])
        dr.line([tuple(a), tuple(b)], fill=(46, 48, 54), width=ss)
    for gz in range(3, 14):
        a, b = cam2.project([11, 0, gz]), cam2.project([22, 0, gz])
        dr.line([tuple(a), tuple(b)], fill=(46, 48, 54), width=ss)
    polys = []
    wall = np.array([0.55, 0.56, 0.58])
    for lo, hi in boxes:
        for q, nrm in box_quads(lo, hi):
            shade = 0.45 + 0.55 * max(0.0, float(nrm @ LIGHT))
            polys.append((Camera.depth(q.mean(axis=0)), cam2.project(q), tuple(int(255 * c * shade) for c in wall)))
    if post is not None:
        for q, nrm in box_quads(*post, step=0.25):
            shade = 0.45 + 0.55 * max(0.0, float(nrm @ LIGHT))
            polys.append((Camera.depth(q.mean(axis=0)), cam2.project(q), tuple(int(255 * c * shade) for c in (0.42, 0.30, 0.20))))
    nx, nz = grid.shape[:2]
    P = grid
    for i in range(nx - 1):
        for j in range(nz - 1):
            q = np.array([P[i, j], P[i + 1, j], P[i + 1, j + 1], P[i, j + 1]])
            n = np.cross(q[1] - q[0], q[3] - q[0]) + np.cross(q[2] - q[1], q[2] - q[3])
            ln = np.linalg.norm(n)
            if ln < 1e-12:
                continue
            n /= ln
            back = (n @ CAM) < 0
            if back:
                n = -n
            shade = 0.38 + 0.62 * max(0.0, float(n @ LIGHT))
            if back:
                shade *= 0.72
            col = tuple(int(255 * min(1.0, c * shade)) for c in base_color)
            polys.append((Camera.depth(q.mean(axis=0)), cam2.project(q), col))
    polys.sort(key=lambda t: t[0])
    for _, pts, col in polys:
        dr.polygon([tuple(p) for p in pts], fill=col)
    if pinned is not None:
        for p in P.reshape(-1, 3)[pinned]:
            x, y = cam2.project(p)
            dr.ellipse([x - 2 * ss, y - 2 * ss, x + 2 * ss, y + 2 * ss], fill=(230, 80, 60))
    img = img.resize(size, Image.LANCZOS)
    if title:
        ImageDraw.Draw(img).text((14, 10), title, fill=(220, 220, 225), font=font(20))
    return img


def profile_panel(paths, labels, size=(480, 330), ymax=2.3, floor=0.0, xmax=5.8, note=None, colors=None):
    """Section plot: height (y) against the horizontal distance along the section. `paths`: list of (s, y) arrays; the last one is drawn bold."""
    img = Image.new("RGB", size, (24, 26, 30))
    dr = ImageDraw.Draw(img)
    m = 38
    def tx(s): return m + (s / xmax) * (size[0] - 2 * m)
    def ty(y): return size[1] - m - (y / ymax) * (size[1] - 2 * m)
    dr.line([(tx(0), ty(floor)), (tx(xmax), ty(floor))], fill=(90, 92, 98), width=2)
    dr.line([(tx(0), ty(2.0)), (tx(xmax), ty(2.0))], fill=(54, 56, 62), width=1)
    dr.text((tx(xmax) - 120, ty(2.0) - 16), "roof level (2 GU)", fill=(110, 112, 120), font=font(12))
    dr.rectangle([tx(-0.18), ty(2.0), tx(0.0), ty(0.0)], fill=(110, 112, 118))
    for k, (s, y) in enumerate(paths):
        last = k == len(paths) - 1
        col = (colors[k] if colors else ((120, 200, 255) if last else (70, 82, 96)))
        pts = [(tx(a), ty(b)) for a, b in zip(s, y)]
        dr.line(pts, fill=col, width=3 if last else 1)
    for k, lab in enumerate(labels):
        dr.text((m, 8 + 15 * k), lab, fill=(210, 212, 218), font=font(13))
    if note:
        dr.text((m, size[1] - 22), note, fill=(150, 152, 160), font=font(12))
    return img


# ---------------------------------------------------------------------------------------------------------------------
# z-buffer renderer: smooth normals, true occlusion, a blob shadow on the floor (replaces render_scene for the study)
def _grid_normals(P):
    dX, dZ = np.gradient(P, axis=0), np.gradient(P, axis=1)
    N = np.cross(dX, dZ)
    return N / np.maximum(np.linalg.norm(N, axis=-1, keepdims=True), 1e-12)


def _raster(zb, cb, scr, dep, nrm, base, two_sided=True, ss=2):
    """One triangle: scr (3,2) pixels, dep (3,), nrm (3,3) per-vertex normals, base colour (3,)."""
    h, w = zb.shape
    x0, y0 = scr[0]; x1, y1 = scr[1]; x2, y2 = scr[2]
    minx, maxx = int(max(0, math.floor(min(x0, x1, x2)))), int(min(w - 1, math.ceil(max(x0, x1, x2))))
    miny, maxy = int(max(0, math.floor(min(y0, y1, y2)))), int(min(h - 1, math.ceil(max(y0, y1, y2))))
    if maxx < minx or maxy < miny:
        return
    den = (y1 - y2) * (x0 - x2) + (x2 - x1) * (y0 - y2)
    if abs(den) < 1e-9:
        return
    xs, ys = np.meshgrid(np.arange(minx, maxx + 1) + 0.5, np.arange(miny, maxy + 1) + 0.5)
    l0 = ((y1 - y2) * (xs - x2) + (x2 - x1) * (ys - y2)) / den
    l1 = ((y2 - y0) * (xs - x2) + (x0 - x2) * (ys - y2)) / den
    l2 = 1.0 - l0 - l1
    m = (l0 >= -1e-6) & (l1 >= -1e-6) & (l2 >= -1e-6)
    if not m.any():
        return
    d = l0 * dep[0] + l1 * dep[1] + l2 * dep[2]
    sl = (slice(miny, maxy + 1), slice(minx, maxx + 1))
    ok = m & (d > zb[sl])
    if not ok.any():
        return
    n = l0[..., None] * nrm[0] + l1[..., None] * nrm[1] + l2[..., None] * nrm[2]
    n /= np.maximum(np.linalg.norm(n, axis=-1, keepdims=True), 1e-9)
    facing = n @ CAM
    if two_sided:
        flip = facing < 0
        n = np.where(flip[..., None], -n, n)
    lam = np.clip(n @ LIGHT, 0.0, 1.0)
    shade = 0.34 + 0.66 * lam
    if two_sided:
        shade = np.where(flip, shade * 0.74, shade)
    col = shade[..., None] * np.asarray(base, float)
    zb[sl] = np.where(ok, d, zb[sl])
    cb[sl] = np.where(ok[..., None], col, cb[sl])


def render_scene_zb(grid, cam, boxes, base_color, pinned=None, size=(800, 720), ss=2, post=None, title=None):
    W, H = size[0] * ss, size[1] * ss
    cam2 = Camera(cam.c, cam.s * ss, (W, H))
    img = Image.new("RGB", (W, H), (28, 30, 34))
    dr = ImageDraw.Draw(img)
    for gx in range(11, 23):
        dr.line([tuple(cam2.project([gx, 0, 3])), tuple(cam2.project([gx, 0, 13]))], fill=(46, 48, 54), width=ss)
    for gz in range(3, 14):
        dr.line([tuple(cam2.project([11, 0, gz])), tuple(cam2.project([22, 0, gz]))], fill=(46, 48, 54), width=ss)
    # blob shadow: the cloth flattened onto the floor, darkened (the sun is high), drawn UNDER everything
    nx, nz = grid.shape[:2]
    flat = grid.copy(); flat[..., 1] = 0.0
    sp = cam2.project(flat.reshape(-1, 3)).reshape(nx, nz, 2)
    for i in range(0, nx - 1, 1):
        for j in range(0, nz - 1, 1):
            if grid[i:i + 2, j:j + 2, 1].mean() > 0.02:
                dr.polygon([tuple(sp[i, j]), tuple(sp[i + 1, j]), tuple(sp[i + 1, j + 1]), tuple(sp[i, j + 1])], fill=(18, 19, 22))
    cb = np.asarray(img, dtype=float) / 255.0
    zb = np.full((H, W), -1e9)
    # boxes as triangles with flat normals
    for lo, hi in list(boxes) + ([post] if post is not None else []):
        colr = (0.55, 0.56, 0.58) if (post is None or (lo, hi) != post) else (0.42, 0.30, 0.20)
        lo, hi = np.asarray(lo, float), np.asarray(hi, float)
        for axis in range(3):
            a1, a2 = [k for k in range(3) if k != axis]
            for side in (0, 1):
                nrm = np.zeros(3); nrm[axis] = -1.0 if side == 0 else 1.0
                if nrm @ CAM <= 0:
                    continue
                q = []
                for (u, v) in ((0, 0), (1, 0), (1, 1), (0, 1)):
                    p = np.zeros(3); p[axis] = lo[axis] if side == 0 else hi[axis]
                    p[a1] = lo[a1] if u == 0 else hi[a1]; p[a2] = lo[a2] if v == 0 else hi[a2]
                    q.append(p)
                q = np.array(q); sc = cam2.project(q); dp = Camera.depth(q); nn = np.tile(nrm, (3, 1))
                _raster(zb, cb, sc[[0, 1, 2]], dp[[0, 1, 2]], nn, colr, two_sided=False)
                _raster(zb, cb, sc[[0, 2, 3]], dp[[0, 2, 3]], nn, colr, two_sided=False)
    # the cloth
    N = _grid_normals(grid)
    SC = cam2.project(grid.reshape(-1, 3)).reshape(nx, nz, 2)
    DP = Camera.depth(grid.reshape(-1, 3)).reshape(nx, nz)
    for i in range(nx - 1):
        for j in range(nz - 1):
            for tri in (((i, j), (i + 1, j), (i + 1, j + 1)), ((i, j), (i + 1, j + 1), (i, j + 1))):
                idx = [t for t in tri]
                _raster(zb, cb, np.array([SC[a, b] for a, b in idx]), np.array([DP[a, b] for a, b in idx]),
                        np.array([N[a, b] for a, b in idx]), base_color, two_sided=True)
    img = Image.fromarray((np.clip(cb, 0, 1) * 255).astype(np.uint8))
    dr = ImageDraw.Draw(img)
    if pinned is not None:
        for p in grid.reshape(-1, 3)[pinned]:
            x, y = cam2.project(p)
            dr.ellipse([x - 2 * ss, y - 2 * ss, x + 2 * ss, y + 2 * ss], fill=(230, 80, 60))
    img = img.resize(size, Image.LANCZOS)
    if title:
        ImageDraw.Draw(img).text((14, 10), title, fill=(220, 220, 225), font=font(20))
    return img
