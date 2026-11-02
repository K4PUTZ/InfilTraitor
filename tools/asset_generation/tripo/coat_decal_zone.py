# coat_decal_zone.py — the coat's emblem ZONE (ACTOR D95, 2026-11-02): where on the back the logo lands, as per-vertex data. D90's method, with the numbers in `coat_decal_zone.json` (not in code).
# The zone is a rectangle projected from BEHIND along the depth axis at rest (Blender +y; the front is -y) onto the coat and kept in a UV map of its own, `DecalUV` (u runs right to left seen from
# behind so the logo reads true); a per-vertex mask is 1 on the OUTER back wall and 0 where a ray out of the back meets the coat again (the lining, the front panels) or where the surface turns away from the back.
# The unit u is the coat's height at rest (hem to collar top), so the same JSON fits COAT_BASE (1 m) and the Agent's coat (0.72 H). A logo of another aspect is fitted inside the rectangle by the shader's art, not here.
# Used by `tripo_coat_decal.py` (the store render) and `coat_push.bake` (the game coat). Env overrides for experiments: ZONE_W, ZONE_ZC (both in u), ZONE_X0 (metres).
import json, os
import numpy as np

ZONE_JSON = os.path.join(os.path.dirname(os.path.abspath(__file__)), "coat_decal_zone.json")


def load_zone():
    with open(ZONE_JSON) as fh:
        z = json.load(fh)
    z["width_u"] = float(os.environ.get("ZONE_W", z["width_u"]))
    z["centre_u"] = float(os.environ.get("ZONE_ZC", z["centre_u"]))
    z["centre_x"] = float(os.environ.get("ZONE_X0", z["centre_x"]))
    return z


def bake_zone(coat, aspect=None):
    """-> (uv per LOOP (L, 2) in Blender's V-up convention, mask per vertex (N,), the zone's numbers incl. the coat's height u and the rectangle in metres)"""
    from mathutils import Vector
    from mathutils.bvhtree import BVHTree
    z = load_zone()
    me = coat.data
    V = np.array([(coat.matrix_world @ v.co)[:] for v in me.vertices])
    z0, u = float(V[:, 2].min()), float(V[:, 2].max() - V[:, 2].min())
    W = z["width_u"] * u
    H = W * float(aspect if aspect else z["aspect_h_over_w"])
    X0, ZC = z["centre_x"], z0 + z["centre_u"] * u
    vert = np.array([l.vertex_index for l in me.loops])
    uv = np.stack([0.5 - (V[vert, 0] - X0) / W, 0.5 + (V[vert, 2] - ZC) / H], axis=1)
    me.calc_loop_triangles()
    bvh = BVHTree.FromPolygons([tuple(v) for v in V], [tuple(t.vertices) for t in me.loop_triangles])
    nrm = np.array([(coat.matrix_world.to_3x3() @ v.normal)[:] for v in me.vertices])
    mask = np.zeros(len(V), np.float32)
    m, eps, reach = z["mask_margin"], 2e-4 * u, z["mask_ray_u"] * u
    for i, p in enumerate(V):
        if abs(p[0] - X0) > m * W or abs(p[2] - ZC) > m * H or nrm[i][1] < 0.1:
            continue
        if bvh.ray_cast(Vector(p + np.array([0, eps, 0])), Vector((0, 1, 0)), reach)[0] is not None:
            continue
        t = float(np.clip((nrm[i][1] - 0.1) / 0.5, 0, 1))
        mask[i] = t * t * (3 - 2 * t)
    return uv, mask, dict(u=u, hem=z0, W=W, H=H, x0=X0, zc=ZC)
