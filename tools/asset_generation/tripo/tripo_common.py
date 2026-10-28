# tripo_common.py — what the Tripo tools share (ACTOR D85): load a Tripo rigged GLB in its REST pose, read and write skin weights, the welded
# islands, the LONG COAT's weight rules, and the clay review renders and sheets. Imported by scripts run with `blender -b -P <script>`; each script
# puts this folder on sys.path itself.
#
# The coat's rules (measured on the first detective, 2026-10-26: Tripo's auto-rig binds in the A pose it generated, where the hands hang beside the
# coat's skirt, so it gives the skirt to the HANDS; of the skirt's vertices off the legs only 97 followed the thighs). On every vertex except the
# hands' own pieces (a welded island whose mean hand weight > 0.5):
#   (1) OFF THE ARM (> ARM_R from the shoulder -> elbow -> wrist line, below the shoulder) a vertex loses every forearm / hand / finger weight, and the
#       upper arm's below the elbow. ARM_R sits in a measured gap: the sleeve lies 2-5 % of the height off that line, the coat's side starts past 6 %;
#   (2) THE SKIRT (below the hips, above the hem, farther than LEG_IN..LEG_OUT from both leg lines, blended over that band) hangs from Hips (85 %) and
#       Spine (15 %), following its own side's thigh more toward the knee (10 % at the hips, 60 % at the knee); the front opening splits the sides.
# Islands are read on the WELDED surface: Tripo splits vertices along every hard edge (its faceted shading). Lengths are fractions of the FIGURE's
# height H (Tripo exports a 1 m figure standing on z = 0). Weights keep 4 influences (the glTF export and the handsets' skinning).
import bpy, math, sys
import numpy as np
from mathutils import Vector

ARM_R, LEG_IN, LEG_OUT = 0.055, 0.055, 0.075           # fractions of the height (see the header)
NEED = ("Hips", "Spine", "LeftUpLeg", "LeftLeg", "LeftFoot", "RightUpLeg", "RightLeg", "RightFoot",
        "LeftArm", "LeftForeArm", "LeftHand", "RightArm", "RightForeArm", "RightHand")


def fail(tag, msg):
    print(f"[{tag}] ERROR: {msg}")
    sys.exit(1)


def load(tag, glb):
    """import a Tripo rigged GLB and put it in REST pose -> (armature, Mixamo prefix, bone heads B, skinned meshes)"""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=glb)
    arms = [o for o in bpy.data.objects if o.type == 'ARMATURE']
    meshes = [o for o in bpy.data.objects if o.type == 'MESH' and o.vertex_groups]
    if len(arms) != 1 or not meshes:
        fail(tag, f"{glb}: expected one armature and a skinned mesh, found {len(arms)} armatures and {len(meshes)} skinned meshes")
    arm = arms[0]
    hips = [b.name for b in arm.data.bones if b.name.endswith("Hips")]
    if not hips:
        fail(tag, f"{glb}: no Mixamo Hips bone in {[b.name for b in arm.data.bones][:8]}...")
    P = hips[0][:-len("Hips")]                          # the Mixamo prefix, "mixamorig:" from Tripo
    missing = [n for n in NEED if P + n not in arm.data.bones]
    if missing:
        fail(tag, f"{glb}: the skeleton lacks {missing}")
    if arm.animation_data:
        for t in arm.animation_data.nla_tracks:
            t.mute = True
    arm.data.pose_position = 'REST'; bpy.context.view_layer.update()
    B = {n: np.array((arm.matrix_world @ arm.data.bones[P + n].head_local)[:]) for n in NEED}
    fix_unrigged(tag, meshes, P)
    return arm, P, B, meshes


def fix_unrigged(tag, meshes, P):
    """Tripo binds a few vertices to a 'neutral_bone' outside the Mixamo set, which no clip moves: in motion they stay at the rest pose and a
    face stretches from the figure back to where it started (measured on the first male with the coat, 2026-10-27: 1 coat vertex and 2 under
    the hat, edges 2.4 m long). Each such vertex takes the weights of the nearest vertex of its own mesh weighted to Mixamo bones only."""
    n_fix = 0
    for o in meshes:
        W = read_weights(o); bad = [i for i, w in enumerate(W) if any(not g.startswith(P) for g in w)]
        if not bad:
            continue
        V = world_verts(o); good = np.array([i for i in range(len(W)) if i not in set(bad)])
        if not len(good):
            fail(tag, f"{o.name}: every vertex is weighted to a bone outside {P}*")
        for i in bad:
            W[i] = dict(W[good[np.argmin(np.linalg.norm(V[good] - V[i], axis=1))]])
        write_weights(o, W); n_fix += len(bad)
    if n_fix:
        print(f"[{tag}] {n_fix} vertices bound to a bone outside the Mixamo set (Tripo's neutral_bone) took their nearest neighbour's weights")


def world_verts(o):
    return np.array([(o.matrix_world @ v.co)[:] for v in o.data.vertices])


def read_weights(o):
    gname = {g.index: g.name for g in o.vertex_groups}
    return [{gname[g.group]: g.weight for g in v.groups if g.weight > 1e-5} for v in o.data.vertices]


def write_weights(o, W):
    for g in list(o.vertex_groups):
        g.remove(list(range(len(o.data.vertices))))
    grp = {g.name: g for g in o.vertex_groups}
    for i, w in enumerate(W):
        for n, x in w.items():
            if n not in grp:
                grp[n] = o.vertex_groups.new(name=n)
            grp[n].add([i], x, 'REPLACE')


def top4(w, fallback):
    if not w:
        return {fallback: 1.0}
    top = sorted(w.items(), key=lambda kv: -kv[1])[:4]; s_ = sum(x for _, x in top)
    return {n: x / s_ for n, x in top}


def welded_islands(V, edges, H):
    """an island id per vertex, read on the surface welded by position"""
    key = {}; rep = np.arange(len(V))
    for i, q in enumerate(np.round(V / (1e-5 * H)).astype(np.int64)):
        rep[i] = key.setdefault(tuple(q), i)
    par = rep.copy()

    def find(a):
        while par[a] != a:
            par[a] = par[par[a]]; a = par[a]
        return a

    for e in edges:
        a, b = find(rep[e.vertices[0]]), find(rep[e.vertices[1]])
        if a != b:
            par[a] = b
    return np.array([find(rep[i]) for i in range(len(V))])


def segd(V, a, b):
    ab = b - a; t = np.clip((V - a) @ ab / (ab @ ab), 0, 1)
    return np.linalg.norm(V - (a + t[:, None] * ab), axis=1)


def hem_band(V, band, bins=72):
    """the HEM BAND of a coat (ACTOR D86, Director 2026-10-28): every vertex within `band` (a length) of the hem AT ITS OWN AZIMUTH about the
    skirt's vertical axis, so it follows the hem all round, front tips and back alike, outer wall and lining together (a single height slab
    from the lowest point took only the front tips: they hang below the back) -> a weight per vertex, 1 at the hem fading to 0 at `band`"""
    lo, hi = V.min(0), V.max(0); skirt = V[:, 2] < lo[2] + 0.5 * (hi[2] - lo[2])
    c = V[skirt, :2].mean(0); az = ((np.arctan2(V[:, 1] - c[1], V[:, 0] - c[0]) + math.pi) / (2 * math.pi) * bins).astype(int) % bins
    hem = np.full(bins, np.inf)
    np.minimum.at(hem, az[skirt], V[skirt, 2])
    d = V[:, 2] - hem[az]
    return np.where(skirt & np.isfinite(d), np.clip(1.0 - d / band, 0.0, 1.0), 0.0)


def sstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def coat_fix(V, W0, B, P, H, fix):
    """the coat's two rules on the vertices where `fix` holds -> (new weights, stats); stats["hem"] is None when no skirt was found"""
    d_arm = np.minimum.reduce([segd(V, B[s + "Arm"], B[s + "ForeArm"]) for s in ("Left", "Right")] +
                              [segd(V, B[s + "ForeArm"], B[s + "Hand"]) for s in ("Left", "Right")])
    d_leg = np.minimum.reduce([segd(V, B[s + "UpLeg"], B[s + "Leg"]) for s in ("Left", "Right")] +
                              [segd(V, B[s + "Leg"], B[s + "Foot"]) for s in ("Left", "Right")])
    on_arm = (d_arm < ARM_R * H) & (V[:, 2] < B["LeftArm"][2] - 0.02 * H)
    hz, kz, ez = B["Hips"][2], B["LeftLeg"][2], B["LeftForeArm"][2]
    skirt_zone = fix & (d_leg > LEG_OUT * H) & (V[:, 2] > 0.12 * H) & (V[:, 2] < hz)     # 0.12: above the shoes
    hem = float(V[skirt_zone, 2].min()) if skirt_zone.any() else None
    left_x = np.sign(B["LeftUpLeg"][0])

    def is_fore(n): return "ForeArm" in n or "Hand" in n
    def is_upper(n): return n == P + "LeftArm" or n == P + "RightArm"

    W1 = []; n_strip = n_skirt = 0
    for i, w in enumerate(W0):
        if not fix[i] or on_arm[i]:
            W1.append(w); continue
        z = V[i, 2]
        w2 = {n: x for n, x in w.items() if not is_fore(n) and not (is_upper(n) and z < ez)}
        if len(w2) != len(w):
            n_strip += 1
        k = 0.0 if hem is None else \
            sstep(LEG_IN * H, LEG_OUT * H, d_leg[i]) * sstep(hz + 0.03 * H, hz - 0.01 * H, z) * sstep(hem - 0.03 * H, hem - 0.005 * H, z)
        if k > 0:
            t = float(np.clip((hz - z) / (hz - kz), 0, 1)); follow = 0.10 + 0.50 * t
            s_l = float(sstep(-0.04 * H, 0.04 * H, V[i, 0] * left_x))
            sk = {P + "Hips": (1 - follow) * 0.85, P + "Spine": (1 - follow) * 0.15, P + "LeftUpLeg": follow * s_l, P + "RightUpLeg": follow * (1 - s_l)}
            tot = sum(w2.values()) or 1.0
            mix = {n: x / tot * (1 - k) for n, x in w2.items()}
            for n, x in sk.items():
                mix[n] = mix.get(n, 0.0) + x * k
            w2 = mix; n_skirt += 1
        W1.append(top4(w2, P + "Hips"))
    return W1, {"hz": hz, "kz": kz, "hem": hem, "on_arm": int((fix & on_arm).sum()), "stripped": n_strip, "skirt": n_skirt}


# ---- clay review renders and sheets ----
def setup_renders(show, colours=None):
    """hide every mesh but `show`, colour them (clay, or `colours[name]` RGB), flat-shade them; -> (camera data, camera object)"""
    sc = bpy.context.scene
    for o in bpy.data.objects:
        if o.type == 'MESH' and o not in show:
            o.hide_render = True
    clay = bpy.data.materials.new("clay")                              # Blender 5.x: a new material always has its node tree
    b = clay.node_tree.nodes["Principled BSDF"]; b.inputs["Base Color"].default_value = (0.42, 0.42, 0.44, 1); b.inputs["Roughness"].default_value = 0.65
    for o in show:
        m = clay
        if colours:
            m = bpy.data.materials.new("rv_" + o.name)
            m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (*colours[o.name], 1)
            m.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.65
        o.data.materials.clear(); o.data.materials.append(m)
        for p in o.data.polygons:
            p.use_smooth = False
    sc.render.engine = 'BLENDER_EEVEE'; sc.render.film_transparent = False; sc.view_settings.view_transform = 'Standard'
    wd = bpy.data.worlds.new("w"); sc.world = wd; wd.node_tree.nodes["Background"].inputs[0].default_value = (0.34, 0.35, 0.38, 1)
    for nm, en, rot in (("key", 3.4, (50, 0, -35)), ("fill", 1.2, (60, 0, 140)), ("rim", 2.0, (70, 0, 200))):
        lt = bpy.data.lights.new(nm, 'SUN'); lt.energy = en
        lo = bpy.data.objects.new(nm, lt); sc.collection.objects.link(lo); lo.rotation_euler = [math.radians(x) for x in rot]
    cam = bpy.data.cameras.new("c"); cam.type = 'ORTHO'; co = bpy.data.objects.new("c", cam); sc.collection.objects.link(co); sc.camera = co
    sc.render.resolution_x, sc.render.resolution_y = 300, 420
    return cam, co


def shot(cam, co, path, az, ctr, ortho):
    a, e = math.radians(az), math.radians(8)
    d = Vector((math.cos(e) * math.sin(a), -math.cos(e) * math.cos(a), math.sin(e)))
    cam.ortho_scale = ortho; cam.clip_start = 0.01; cam.clip_end = 50
    co.location = ctr + d * 10; co.rotation_euler = (ctr - co.location).to_track_quat('-Z', 'Y').to_euler()
    bpy.context.scene.render.filepath = path; bpy.ops.render.render(write_still=True)


def render_clips(arm, P, H, rv_out, tag, clips, cam, co):
    """4 frames of each clip, at 3/4 and from the side, following the hips (the clips carry root motion) -> {(clip, view, frame): path}"""
    sc = bpy.context.scene; ad = arm.animation_data
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
            hp = arm.matrix_world @ arm.pose.bones[P + "Hips"].head
            ctr = Vector((hp.x, hp.y, 0.52 * H))
            for vi, az in enumerate((35, 90)):
                path = f"{rv_out}/{tag}_{ci}_{vi}_{fi}.png"; shot(cam, co, path, az, ctr, 1.25 * H)
                files[(ci, vi, fi)] = path
    return files


def sheet(rows, cols, files, path):
    """paste `files[(row, col)]` (all the scene's render size) into one PNG, row 0 on top"""
    sc = bpy.context.scene; w, h = sc.render.resolution_x, sc.render.resolution_y
    S = np.zeros((rows * h, cols * w, 4), np.float32)
    for (r, c), f in files.items():
        im = bpy.data.images.load(f)
        px = np.array(im.pixels[:], np.float32).reshape(h, w, 4); bpy.data.images.remove(im)
        y = (rows - 1 - r) * h                                         # Blender's pixel rows run bottom-up
        S[y:y + h, c * w:(c + 1) * w] = px
    out = bpy.data.images.new("sheet", cols * w, rows * h, alpha=True); out.pixels = S.ravel()
    out.filepath_raw = path; out.file_format = 'PNG'; out.save(); bpy.data.images.remove(out)


def export(path, objs, arm):
    """the armature, `objs` and every action, as one GLB"""
    if arm.animation_data:
        arm.animation_data.action = None
    arm.data.pose_position = 'POSE'
    for o in bpy.data.objects:
        o.select_set(o in objs or o is arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.export_scene.gltf(filepath=path, use_selection=True, export_animations=True, export_animation_mode='ACTIONS')
