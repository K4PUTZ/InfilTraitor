# face_uv_map.py — the head's FaceUV as a function of the position (CHARACTER §7a TX-2): plain numpy, shared by tripo_face_uv.py (the FULL head,
# where the params are taken) and tripo_face_apply.py (any head of the same figure: the FULL, the LIGHT), so both land on the same texels.
# u = the angle round the head's vertical axis (front = 0.5, the figure's left toward u = 1, as a front view sees it), the front +-FRONT_DEG
# taking FRONT_SHARE of the width; v = the height between the head's lowest and highest point, inside a 1 % margin. Lengths in the figure's metres.
import math
import numpy as np

FRONT_DEG = 75.0
FRONT_SHARE = 0.70
MARGIN = 0.01


def params_from_head(V):
    """the axis and height range of a head (its welded world vertices, (n, 3)): the axis through the centre of the part above the neck"""
    z0, z1 = float(V[:, 2].min()), float(V[:, 2].max())
    up = V[V[:, 2] > z0 + 0.35 * (z1 - z0)]
    return {"xc": float((up[:, 0].min() + up[:, 0].max()) / 2.0), "yc": float((up[:, 1].min() + up[:, 1].max()) / 2.0),
            "z0": z0, "z1": z1, "front_deg": FRONT_DEG, "front_share": FRONT_SHARE, "margin": MARGIN}


def radius(P, prm):
    return np.hypot(P[..., 0] - prm["xc"], P[..., 1] - prm["yc"])


def uv(P, prm):
    """FaceUV of points P (..., 3) -> (..., 2), before the seam fix"""
    th = np.arctan2(P[..., 0] - prm["xc"], -(P[..., 1] - prm["yc"]))
    a = np.abs(th); tf = math.radians(prm["front_deg"]); fs = prm["front_share"]
    s = np.where(a <= tf, a / tf * (fs / 2.0), fs / 2.0 + (a - tf) / (math.pi - tf) * ((1.0 - fs) / 2.0))
    u = 0.5 + np.sign(th) * s
    m = prm["margin"]
    v = m + (P[..., 2] - prm["z0"]) / (prm["z1"] - prm["z0"]) * (1.0 - 2.0 * m)
    return np.stack([u, v], -1)


def tri_uv(P, prm):
    """FaceUV of triangles P (T, 3, 3) -> (T, 3, 2): a triangle across the back seam keeps its corners together (u past 1)"""
    U = uv(P, prm)
    span = U[:, :, 0].max(1) - U[:, :, 0].min(1)
    wrap = span > 0.5
    U[wrap, :, 0] = np.where(U[wrap, :, 0] < 0.5, U[wrap, :, 0] + 1.0, U[wrap, :, 0])
    return U
