# tripo_coat_weights.py — clean the skin weights of a LONG COAT on a character auto-rigged by Tripo as ONE mesh (Mixamo skeleton; ACTOR D85,
# 2026-10-26). Tripo's rig gives the coat's skirt to the hands (they hang beside it in the A pose it binds in): the coat flew out in flaps on every
# run, punch or gesture. The rules and the measurements they sit on are tripo_common.py's (coat_fix); the hands' own pieces keep their weights.
# A character SEGMENTED by Tripo (one mesh per part) goes through tripo_assemble.py instead, which applies the same rules to its coat.
# Env: TRIPO_GLB (input), TRIPO_OUT (fixed GLB), RV_OUT (optional folder: BEFORE / AFTER clay renders of RV_CLIPS, 4 frames each at 3/4 and side,
# and one sheet per clip), RV_CLIPS (comma list of action names; default every action).  Usage: blender -b -P tripo_coat_weights.py
import os, sys
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import tripo_common as tc

TAG = "tripo_coat_weights"
GLB, OUT = os.environ["TRIPO_GLB"], os.environ["TRIPO_OUT"]
RV_OUT = os.environ.get("RV_OUT", "").rstrip("/")

arm, P, B, meshes = tc.load(TAG, GLB)
mo = max(meshes, key=lambda o: len(o.data.vertices))
V = tc.world_verts(mo)
H = float(V[:, 2].max() - V[:, 2].min())
isl = tc.welded_islands(V, mo.data.edges, H)
W0 = tc.read_weights(mo)
handw = np.array([sum(x for n, x in w.items() if "Hand" in n) for w in W0])
hand_isl = [u for u in np.unique(isl) if handw[isl == u].mean() > 0.5]
FIX = ~np.isin(isl, hand_isl)
W1, st = tc.coat_fix(V, W0, B, P, H, FIX)
if st["hem"] is None:
    tc.fail(TAG, f"{GLB}: no skirt found below the hips (is this a long coat?)")
print(f"[{TAG}] {len(V)} verts, height {H:.3f}, {len(np.unique(isl))} welded islands, {len(hand_isl)} hand islands; "
      f"hips z {st['hz']:.3f} knee z {st['kz']:.3f} hem z {st['hem']:.3f}; on the arm {st['on_arm']}; "
      f"stripped of forearm/hand {st['stripped']}; skirt re-weighted {st['skirt']}")

orig_mats = list(mo.data.materials); orig_smooth = [p.use_smooth for p in mo.data.polygons]
if RV_OUT:
    os.makedirs(RV_OUT, exist_ok=True)
    import bpy
    clips = [c for c in os.environ.get("RV_CLIPS", "").split(",") if c] or [a.name for a in bpy.data.actions]
    unknown = [c for c in clips if c not in bpy.data.actions]
    if unknown:
        tc.fail(TAG, f"no action {unknown}; the file has {[a.name for a in bpy.data.actions]}")
    cam, co = tc.setup_renders([mo])
    before = tc.render_clips(arm, P, H, RV_OUT, "before", clips, cam, co)
    tc.write_weights(mo, W1)
    after = tc.render_clips(arm, P, H, RV_OUT, "after", clips, cam, co)
    for ci, cn in enumerate(clips):
        files = {(r, vi * 4 + fi): f[(ci, vi, fi)] for r, f in ((0, before), (1, after)) for vi in range(2) for fi in range(4)}
        path = f"{RV_OUT}/sheet_{ci}_{''.join(ch if ch.isalnum() else '_' for ch in cn)}.png"
        tc.sheet(2, 8, files, path)
        print(f"[{TAG}] sheet {path} (top BEFORE, bottom AFTER)")
else:
    tc.write_weights(mo, W1)
mo.data.materials.clear()
for m in orig_mats:
    mo.data.materials.append(m)
for p, sm in zip(mo.data.polygons, orig_smooth):
    p.use_smooth = sm
tc.export(OUT, [mo], arm)
print(f"[{TAG}] wrote {OUT}")
