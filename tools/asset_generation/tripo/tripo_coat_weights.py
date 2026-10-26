# tripo_coat_weights.py — clean the skin weights of a LONG COAT on a character auto-rigged by Tripo (Mixamo skeleton; ACTOR D85, 2026-10-26).
# Tripo's rig binds in the A pose it generated, where the hands hang beside the coat's skirt, so it gives the skirt to the HANDS: measured on the
# first detective (2026-10-26), of the skirt's vertices off the legs only 97 followed the thighs and the rest followed the hand / forearm, so the coat
# flew out in flaps on every run, punch or gesture. Two rules, on every vertex except the hands' own pieces (an island whose mean hand weight > 0.5):
#   (1) OFF THE ARM (> ARM_R from the shoulder -> elbow -> wrist line, below the shoulder) a vertex loses every forearm / hand / finger weight, and the
#       upper arm's below the elbow. ARM_R sits in a measured gap: the sleeve lies 2-5 % of the height off that line, the coat's side starts past 6 %;
#   (2) THE SKIRT (below the hips, above the hem, farther than LEG_IN..LEG_OUT from both leg lines, blended over that band) hangs from Hips (85 %) and
#       Spine (15 %), following its own side's thigh more toward the knee (10 % at the hips, 60 % at the knee); the front opening splits the sides.
# Islands are read on the WELDED surface: Tripo splits vertices along every hard edge (its faceted shading), so the raw coat is dozens of islands.
# Lengths are fractions of the figure's height (Tripo exports a 1 m figure). Keeps 4 influences (the glTF export and the handsets' skinning).
# Env: TRIPO_GLB (input), TRIPO_OUT (fixed GLB), RV_OUT (optional folder: BEFORE / AFTER clay renders of RV_CLIPS, 4 frames each at 3/4 and side,
# and one sheet per clip), RV_CLIPS (comma list of action names; default every action).  Usage: blender -b -P tripo_coat_weights.py
import bpy, bmesh, math, os, sys
import numpy as np
from mathutils import Vector

GLB, OUT = os.environ["TRIPO_GLB"], os.environ["TRIPO_OUT"]
RV_OUT = os.environ.get("RV_OUT", "").rstrip("/")
ARM_R, LEG_IN, LEG_OUT = 0.055, 0.055, 0.075           # fractions of the height (see the header)


def fail(msg):
    print(f"[tripo_coat_weights] ERROR: {msg}")
    sys.exit(1)


bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=GLB)
sc = bpy.context.scene
arms = [o for o in bpy.data.objects if o.type == 'ARMATURE']
meshes = [o for o in bpy.data.objects if o.type == 'MESH' and o.vertex_groups]
if len(arms) != 1 or not meshes:
    fail(f"{GLB}: expected one armature and a skinned mesh, found {len(arms)} armatures and {len(meshes)} skinned meshes")
arm = arms[0]; mo = max(meshes, key=lambda o: len(o.data.vertices))
hips = [b.name for b in arm.data.bones if b.name.endswith("Hips")]
if not hips:
    fail(f"{GLB}: no Mixamo Hips bone in {[b.name for b in arm.data.bones][:8]}...")
P = hips[0][:-len("Hips")]                              # the Mixamo prefix, "mixamorig:" from Tripo
NEED = ("Hips", "Spine", "LeftUpLeg", "LeftLeg", "LeftFoot", "RightUpLeg", "RightLeg", "RightFoot",
        "LeftArm", "LeftForeArm", "LeftHand", "RightArm", "RightForeArm", "RightHand")
missing = [n for n in NEED if P + n not in arm.data.bones]
if missing:
    fail(f"{GLB}: the skeleton lacks {missing}")
ad = arm.animation_data
if ad:
    for t in ad.nla_tracks:
        t.mute = True
arm.data.pose_position = 'REST'; bpy.context.view_layer.update()
B = {n: np.array((arm.matrix_world @ arm.data.bones[P + n].head_local)[:]) for n in NEED}
V = np.array([(mo.matrix_world @ v.co)[:] for v in mo.data.vertices])
H = float(V[:, 2].max() - V[:, 2].min())

# the welded islands, and the hands' own pieces
key = {}; rep = np.arange(len(V))
for i, q in enumerate(np.round(V / (1e-5 * H)).astype(np.int64)):
    rep[i] = key.setdefault(tuple(q), i)
par = rep.copy()


def find(a):
    while par[a] != a:
        par[a] = par[par[a]]; a = par[a]
    return a


for e in mo.data.edges:
    a, b = find(rep[e.vertices[0]]), find(rep[e.vertices[1]])
    if a != b:
        par[a] = b
isl = np.array([find(rep[i]) for i in range(len(V))])
gname = {g.index: g.name for g in mo.vertex_groups}
W0 = [{gname[g.group]: g.weight for g in v.groups if g.weight > 1e-5} for v in mo.data.vertices]
handw = np.array([sum(x for n, x in w.items() if "Hand" in n) for w in W0])
hand_isl = [u for u in np.unique(isl) if handw[isl == u].mean() > 0.5]
FIX = ~np.isin(isl, hand_isl)


def segd(a, b):
    ab = b - a; t = np.clip((V - a) @ ab / (ab @ ab), 0, 1)
    return np.linalg.norm(V - (a + t[:, None] * ab), axis=1)


def sstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


d_arm = np.minimum.reduce([segd(B[s + "Arm"], B[s + "ForeArm"]) for s in ("Left", "Right")] +
                          [segd(B[s + "ForeArm"], B[s + "Hand"]) for s in ("Left", "Right")])
d_leg = np.minimum.reduce([segd(B[s + "UpLeg"], B[s + "Leg"]) for s in ("Left", "Right")] +
                          [segd(B[s + "Leg"], B[s + "Foot"]) for s in ("Left", "Right")])
on_arm = (d_arm < ARM_R * H) & (V[:, 2] < B["LeftArm"][2] - 0.02 * H)
hz, kz, ez = B["Hips"][2], B["LeftLeg"][2], B["LeftForeArm"][2]
skirt_zone = FIX & (d_leg > LEG_OUT * H) & (V[:, 2] > 0.12 * H) & (V[:, 2] < hz)     # 0.12: above the shoes
if not skirt_zone.any():
    fail(f"{GLB}: no skirt found below the hips (is this a long coat?)")
hem = float(V[skirt_zone, 2].min())
left_x = np.sign(B["LeftUpLeg"][0])


def is_fore(n): return "ForeArm" in n or "Hand" in n
def is_upper(n): return n == P + "LeftArm" or n == P + "RightArm"


W1 = []; n_strip = n_skirt = 0
for i, w in enumerate(W0):
    if not FIX[i] or on_arm[i]:
        W1.append(w); continue
    z = V[i, 2]
    w2 = {n: x for n, x in w.items() if not is_fore(n) and not (is_upper(n) and z < ez)}
    if len(w2) != len(w):
        n_strip += 1
    k = sstep(LEG_IN * H, LEG_OUT * H, d_leg[i]) * sstep(hz + 0.03 * H, hz - 0.01 * H, z) * sstep(hem - 0.03 * H, hem - 0.005 * H, z)
    if k > 0:
        t = float(np.clip((hz - z) / (hz - kz), 0, 1)); follow = 0.10 + 0.50 * t
        s_l = float(sstep(-0.04 * H, 0.04 * H, V[i, 0] * left_x))
        sk = {P + "Hips": (1 - follow) * 0.85, P + "Spine": (1 - follow) * 0.15, P + "LeftUpLeg": follow * s_l, P + "RightUpLeg": follow * (1 - s_l)}
        tot = sum(w2.values()) or 1.0
        mix = {n: x / tot * (1 - k) for n, x in w2.items()}
        for n, x in sk.items():
            mix[n] = mix.get(n, 0.0) + x * k
        w2 = mix; n_skirt += 1
    if not w2:
        w2 = {P + "Hips": 1.0}
    top = sorted(w2.items(), key=lambda kv: -kv[1])[:4]; s_ = sum(x for _, x in top)
    W1.append({n: x / s_ for n, x in top})
print(f"[tripo_coat_weights] {len(V)} verts, height {H:.3f}, {len(np.unique(isl))} welded islands, {len(hand_isl)} hand islands; "
      f"hips z {hz:.3f} knee z {kz:.3f} hem z {hem:.3f}; on the arm {int((FIX & on_arm).sum())}; "
      f"stripped of forearm/hand {n_strip}; skirt re-weighted {n_skirt}")


def apply(W):
    for g in list(mo.vertex_groups):
        g.remove(list(range(len(V))))
    grp = {g.name: g for g in mo.vertex_groups}
    for i, w in enumerate(W):
        for n, x in w.items():
            if n not in grp:
                grp[n] = mo.vertex_groups.new(name=n)
            grp[n].add([i], x, 'REPLACE')


# ---- optional review renders (clay, BEFORE and AFTER); the materials and shading are restored before the export ----
def setup_renders():
    for o in bpy.data.objects:
        if o.type == 'MESH' and o is not mo:
            o.hide_render = True
    clay = bpy.data.materials.new("clay")                              # Blender 5.x: a new material always has its node tree
    b = clay.node_tree.nodes["Principled BSDF"]; b.inputs["Base Color"].default_value = (0.42, 0.42, 0.44, 1); b.inputs["Roughness"].default_value = 0.65
    mo.data.materials.clear(); mo.data.materials.append(clay)
    for p in mo.data.polygons:
        p.use_smooth = False
    sc.render.engine = 'BLENDER_EEVEE'; sc.render.film_transparent = False; sc.view_settings.view_transform = 'Standard'
    wd = bpy.data.worlds.new("w"); sc.world = wd; wd.node_tree.nodes["Background"].inputs[0].default_value = (0.34, 0.35, 0.38, 1)
    for nm, en, rot in (("key", 3.4, (50, 0, -35)), ("fill", 1.2, (60, 0, 140)), ("rim", 2.0, (70, 0, 200))):
        lt = bpy.data.lights.new(nm, 'SUN'); lt.energy = en
        lo = bpy.data.objects.new(nm, lt); sc.collection.objects.link(lo); lo.rotation_euler = [math.radians(x) for x in rot]
    cam = bpy.data.cameras.new("c"); cam.type = 'ORTHO'; co = bpy.data.objects.new("c", cam); sc.collection.objects.link(co); sc.camera = co
    sc.render.resolution_x, sc.render.resolution_y = 300, 420
    return cam, co


def render_clips(tag, clips, cam, co):
    arm.data.pose_position = 'POSE'; files = {}
    for ci, cn in enumerate(clips):
        act = bpy.data.actions[cn]; ad.action = act
        try:
            ad.action_slot = act.slots[0]
        except (AttributeError, IndexError):
            pass
        f0, f1 = act.frame_range
        for fi, fr in enumerate(np.linspace(f0, f1, 5)[:4]):
            sc.frame_set(int(round(fr)))
            hp = arm.matrix_world @ arm.pose.bones[P + "Hips"].head          # the clips carry root motion: follow the hips
            ctr = Vector((hp.x, hp.y, 0.52 * H))
            for vi, az in enumerate((35, 90)):
                a, e = math.radians(az), math.radians(8)
                d = Vector((math.cos(e) * math.sin(a), -math.cos(e) * math.cos(a), math.sin(e)))
                cam.ortho_scale = 1.25 * H; cam.clip_start = 0.01; cam.clip_end = 50
                co.location = ctr + d * 10; co.rotation_euler = (ctr - co.location).to_track_quat('-Z', 'Y').to_euler()
                path = f"{RV_OUT}/{tag}_{ci}_{vi}_{fi}.png"; sc.render.filepath = path; bpy.ops.render.render(write_still=True)
                files[(ci, vi, fi)] = path
    return files


def sheet(clips, before, after):
    """one PNG per clip: BEFORE on top, AFTER below, 4 frames at 3/4 then 4 at the side"""
    w, h = sc.render.resolution_x, sc.render.resolution_y
    for ci, cn in enumerate(clips):
        S = np.zeros((2 * h, 8 * w, 4), np.float32)
        for row, files in ((1, before), (0, after)):                   # Blender's pixel rows run bottom-up
            for vi in range(2):
                for fi in range(4):
                    im = bpy.data.images.load(files[(ci, vi, fi)])
                    px = np.array(im.pixels[:], np.float32).reshape(h, w, 4); bpy.data.images.remove(im)
                    c = (vi * 4 + fi) * w; S[row * h:(row + 1) * h, c:c + w] = px
        out = bpy.data.images.new(f"sheet_{ci}", 8 * w, 2 * h, alpha=True); out.pixels = S.ravel()
        safe = "".join(ch if ch.isalnum() else "_" for ch in cn)
        out.filepath_raw = f"{RV_OUT}/sheet_{ci}_{safe}.png"; out.file_format = 'PNG'; out.save()
        print(f"[tripo_coat_weights] sheet {out.filepath_raw} (top BEFORE, bottom AFTER)")


orig_mats = list(mo.data.materials); orig_smooth = [p.use_smooth for p in mo.data.polygons]
if RV_OUT:
    os.makedirs(RV_OUT, exist_ok=True)
    clips = [c for c in os.environ.get("RV_CLIPS", "").split(",") if c] or [a.name for a in bpy.data.actions]
    unknown = [c for c in clips if c not in bpy.data.actions]
    if unknown:
        fail(f"no action {unknown}; the file has {[a.name for a in bpy.data.actions]}")
    cam, co = setup_renders()
    before = render_clips("before", clips, cam, co)
    apply(W1)
    after = render_clips("after", clips, cam, co)
    sheet(clips, before, after)
else:
    apply(W1)
mo.data.materials.clear()
for m in orig_mats:
    mo.data.materials.append(m)
for p, sm in zip(mo.data.polygons, orig_smooth):
    p.use_smooth = sm
if ad:
    ad.action = None
arm.data.pose_position = 'POSE'
for o in bpy.data.objects:
    o.select_set(o in (arm, mo))
bpy.context.view_layer.objects.active = arm
bpy.ops.export_scene.gltf(filepath=OUT, use_selection=True, export_animations=True, export_animation_mode='ACTIONS')
print(f"[tripo_coat_weights] wrote {OUT}")
