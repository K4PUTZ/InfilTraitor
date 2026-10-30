# tripo_waist_check.py — count, over every clip of a base (.blend), the waist cloth that shows where it should not; the gate for
# tripo_waist.py and for any hand edit of a waist. Read along rays out from the POSED belt's own axis (tripo_waist.BeltFrame, its axis
# pointed at the chest: a world-up axis flipped while the body lay or hung upside down in the dive and counted the whole shirt as hanging
# below the belt), on the waist's own vertices picked at REST (a thigh swung up into the belt's height is not the waist):
#   B  shirt / trousers outside the belt's outer face, within its height (came through the belt)
#   S  trousers above the belt with no shirt beyond them within 3 cm (came through the shirt; a sleeve farther out does not cover)
#   G  shirt below the belt's bottom edge with no trousers beyond it within 3 cm (hangs out under the belt)
# Measured 2026-10-30 over every frame (dive 66 / heart_pose 130): MALE_BASE_edit B 296 / 1721, S 2735 / 4012, G 126 / 7 vertex-frames;
# MALE_BASE_edit_waist (tripo_waist.py) 0 everywhere.
# Env: STEP (every Nth frame, default 1), WAIST_SHIRT, WAIST_TROUSERS (as tripo_waist.py).  Usage: blender -b X.blend -P tripo_waist_check.py
import os, sys
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import tripo_waist as tw

TAG = "tripo_waist_check"
STEP = int(os.environ.get("STEP", 1)); EPS = 0.0003
SH = bpy.data.objects[os.environ.get("WAIST_SHIRT", "tripo_part_3")]
TRS = [bpy.data.objects[n] for n in os.environ.get("WAIST_TROUSERS", "tripo_part_5,tripo_part_6").split(",") if n in bpy.data.objects]
BELT = bpy.data.objects["Outfit_Belt"]
arm = [o for o in bpy.data.objects if o.type == 'ARMATURE'][0]


def posed(objs):
    dg = bpy.context.evaluated_depsgraph_get(); V, T = [], []
    for o in objs:
        e = o.evaluated_get(dg); m = e.to_mesh(); M = o.matrix_world; b = len(V)
        V += [M @ v.co for v in m.vertices]; T += [[b + i for i in p.vertices] for p in m.polygons]; e.to_mesh_clear()
    return V, BVHTree.FromPolygons(V, T)


def frame(BV, SV):
    return tw.BeltFrame(BV, up=sum(SV, Vector()) / len(SV) - sum(BV, Vector()) / len(BV))


def beyond(bvh, F, th, h, r):
    """a surface of `bvh` at or beyond radius r (within 3 cm) on this ray: the vertex is covered"""
    return any(x > r - EPS for x in tw.hits(bvh, F.C + F.N * h, F.dir(th), r + 0.03))


arm.data.pose_position = 'REST'; bpy.context.view_layer.update()
BV, _ = posed([BELT]); SV, _ = posed([SH]); TV, _ = posed(TRS); F0 = frame(BV, SV)


def rest_pick(V, test):
    out = []
    for i, p in enumerate(V):
        th, h, r = F0.polar(p); lo, hi = F0.band(th)
        if test(h, lo, hi):
            out.append(i)
    return out


S_B = rest_pick(SV, lambda h, lo, hi: lo - 0.03 <= h <= hi + 0.03); T_B = rest_pick(TV, lambda h, lo, hi: lo - 0.03 <= h <= hi + 0.03)
T_S = rest_pick(TV, lambda h, lo, hi: h >= lo); S_G = rest_pick(SV, lambda h, lo, hi: h <= hi + 0.01)
print(f"[{TAG}] judged: shirt {len(S_B)} near the belt, {len(S_G)} at its hem; trousers {len(T_B)} near the belt, {len(T_S)} at the waist and up")
arm.data.pose_position = 'POSE'
for act in bpy.data.actions:
    arm.animation_data.action = act
    if getattr(arm.animation_data, "action_slot", 1) is None and len(act.slots):
        arm.animation_data.action_slot = act.slots[0]
    f0, f1 = map(int, act.frame_range); tot = dict(B=0, S=0, G=0); worst = dict(B=(0, 0), S=(0, 0), G=(0, 0)); n = 0
    for fr in range(f0, f1 + 1, STEP):
        bpy.context.scene.frame_set(fr); n += 1
        BV, bvb = posed([BELT]); SV, bvs = posed([SH]); TV, bvt = posed(TRS); F = frame(BV, SV); c = dict(B=0, S=0, G=0)
        for p in [SV[i] for i in S_B] + [TV[i] for i in T_B]:
            th, h, r = F.polar(p); lo, hi = F.band(th)
            if lo <= h <= hi:
                hs = tw.hits(bvb, F.C + F.N * h, F.dir(th))
                c['B'] += bool(hs) and r > hs[-1] + EPS
        for i in T_S:
            th, h, r = F.polar(TV[i]); lo, hi = F.band(th)
            c['S'] += hi + 0.001 < h < hi + 0.06 and not beyond(bvs, F, th, h, r)
        for i in S_G:
            th, h, r = F.polar(SV[i]); lo, hi = F.band(th)
            c['G'] += lo - 0.06 < h < lo - 0.001 and not beyond(bvt, F, th, h, r)
        for k in c:
            tot[k] += c[k]; worst[k] = max(worst[k], (c[k], fr))
    print(f"[{TAG}] {act.name}: {n} frames | through the belt B {tot['B']} (worst {worst['B'][0]} @ {worst['B'][1]}) | trousers through "
          f"the shirt S {tot['S']} (worst {worst['S'][0]} @ {worst['S'][1]}) | shirt below the belt G {tot['G']} (worst {worst['G'][0]} @ {worst['G'][1]})")
