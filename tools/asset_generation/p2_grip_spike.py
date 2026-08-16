"""CHARACTER_MASTER_PLAN Part 2 — the three-grip spike.

THE QUESTION, and it is the only one this answers: does the small figure read as
*holding* a shotgun and a pistol at the size the player actually sees? Under D56
that is the whole bar — `hand_R`/`hand_L` are RIGID sockets, no finger deforms
around a barrel, and at ship size the hand is ~19 px with ~2 px fingers. So the
hold has to be sold by ARM POSE and by where the weapon sits, never by the hand.

WHAT IT RENDERS. D40's three grips (lowered / ready / aimed) x two weapons x
D44's four facings = 24 frames, from the bake camera (D26: elevation 30 /
azimuth 45 — any other angle breaks the runtime light maths silently).

HONEST SCOPE, stated up front. This is a Blender render at the game's camera
convention, NOT the Godot bake + relight path — the same declared substitution
s2_turn_render.py and s2_weapon_in_hand.py made. It is evidence about SILHOUETTE
READ at real size, and about nothing else. Part 2's actual definition of done
(§10) is that `agent.gd::_draw()`'s vector placeholder is gone; this spike is the
art decision that has to land before that is worth building.

--------------------------------------------------------------------------------
THREE THINGS DERIVED RATHER THAN COPIED, each because the copy would have been
wrong:

1. THE ARM POSE IS SOLVED FROM THE WEAPON, not tuned against it. Each grip
   declares only where the right hand grips and which way the muzzle points; a
   two-bone IK then places the elbow. For the two-handed shotgun the left hand
   is targeted at the FOREND, whose distance from the grip is measured off the
   real mesh — so both hands land ON the weapon by construction instead of near
   it. s2_weapon_in_hand.py did the reverse (pose first, drop the gun between
   the hands) and could only ever be approximately right.

2. THE REST POSE IS A T, NOT ARMS-DOWN. s2_weapon_in_hand.py's rotations are
   unusable here and were not adapted: its comment states "every arm bone points
   straight DOWN in rest", which was true of the S2 mockup and is false of
   Part 1's model, whose arms run along +/-X (p1_agent_model.py build_armature).
   Local Euler angles carried over would have thrown the arms sideways. Every
   bone here is aimed at a WORLD direction and then verified by measurement.

3. THE WEAPON'S AXES ARE MEASURED, NOT ASSUMED. Both GLBs were measured and then
   CONFIRMED BY EYE with an axis-marked render before a line of this was written:
   muzzle +X, up +Z, for the shotgun and the pistol alike. D30 paid for the
   alternative once, with a copied PERSPECTIVE_YAW_DEG that came out 178 degrees
   wrong.

--------------------------------------------------------------------------------
AND ONE MEASUREMENT THAT CONTRADICTS AN EXISTING SCRIPT, stated because it
changes what "ship size" means:

`ortho_scale = 2.15` is used by p1_agent_preview.py and p8_sculpt_start_scene.py
for what both call the ship-size view. It is a FRAMING value, not a scale one.
The game's own projection is fixed by VOXEL_STEP_PX = 20 px per 0.20 m voxel of
height, and at an elevation-30 orthographic camera a world-vertical metre
occupies cos(30) metres of screen, so the frame's pixels-per-screen-metre is
pinned at 20 / (0.20 * cos 30) = 115.47 and NOTHING else reproduces the game's
size. At ortho 2.15 in a 196 px frame the figure draws ~150 px; the game draws it
~190 px. This script derives the ortho scale from the constants instead, and then
MEASURES the rendered figure to prove it landed (p2_grip_sheet.py gates on it).
The old value made the figure look 21% smaller than it ships, which is the safe
direction to be wrong in, but it is still wrong.

Run:
  /Applications/Blender.app/Contents/MacOS/Blender --background \
    --python tools/asset_generation/p2_grip_spike.py
Then:
  python3 tools/asset_generation/p2_grip_sheet.py
"""

import json
import math
import os
import sys

import bpy
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Matrix, Quaternion, Vector

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
_MODEL = os.environ.get("P2_MODEL", "agent_base")
BLEND = os.path.join(REPO_ROOT, "ASSETS", "ISOMETRIC", "source_assets",
                     "imported_models", "agent", "%s.blend" % _MODEL)
PACK = os.path.join(REPO_ROOT, "ASSETS", "ISOMETRIC", "source_assets",
                    "imported_models", "quaternius_ultimate_guns_pack", "extracted")
OUT_DIR = os.path.join(REPO_ROOT, "Screenshots", "p2_grips")

# --- The game's projection. Not adjustable: these are the game's constants. ----
GAME_ELEV, GAME_AZIM = 30.0, 45.0     # D26 / CollectibleBakeConfig
VOXEL_M = 0.20                        # §4.7
VOXEL_STEP_PX = 20.0                  # QUICK_REFERENCE
# Pixels per metre measured IN THE SCREEN PLANE. A world-vertical metre projects
# to cos(elevation) metres of screen, so this is what makes 0.20 m draw as 20 px.
PX_PER_SCREEN_M = VOXEL_STEP_PX / (VOXEL_M * math.cos(math.radians(GAME_ELEV)))

# The canvas is BIGGER than the plan's 133x196 on purpose, and the scale is
# untouched: at true ship scale a 0.85 m shotgun held across the body overruns a
# 133 px frame, and even at 208x216 the first run cropped every single frame at
# the feet — an isometric silhouette is TALLER than the figure's height in
# pixels, because the body's own depth projects into screen-Y as well. Widening
# the window changes what is visible, never how big anything is drawn.
FRAME = (232, 256)

# --- Weapons: every number below was MEASURED, see the docstring. -------------
# `grip_at` / `fore_at` are fractions along the model's own +X axis, from the
# rear, read off the axis-marked diagnostic renders.
WEAPONS = {
    "shotgun": dict(
        glb="Shotgun Short Stock.glb",
        length_m=0.85,      # a short-stock shotgun
        grip_at=0.30,       # palm behind the trigger
        fore_at=0.80,       # the pump
        two_handed=True,
    ),
    "pistol": dict(
        glb="Pistol.glb",
        length_m=0.22,
        grip_at=0.16,
        fore_at=None,
        two_handed=False,
    ),
}

# --- The grips (D40). Each declares only WHERE the right hand grips and WHICH
# WAY the muzzle points; every joint angle is solved from that. `pole` steers the
# elbow and is the one purely aesthetic knob. The figure faces +Y — established
# by two independent facts in p1_agent_model.py, the feet pointing +Y and
# socket_chest sitting at +CHEST_D, not by assumption.
GRIPS = {
    # The shotgun's grip sits CLOSE to the body on purpose. The forend is a
    # measured 0.425 m further along the barrel, and the arm is 0.57 m: push the
    # grip forward and the left hand simply cannot reach the weapon.
    ("shotgun", "lowered"): dict(
        grip=(-0.19, 0.08, 1.14), aim=(0.30, 0.87, -0.39),
        pole_r=(-1.0, -0.4, -0.5), pole_l=(0.7, -0.5, -0.6)),
    ("shotgun", "ready"): dict(
        grip=(-0.18, 0.06, 1.28), aim=(0.26, 0.95, -0.17),
        pole_r=(-1.0, -0.3, -0.6), pole_l=(0.5, -0.3, -0.9)),
    ("shotgun", "aimed"): dict(
        grip=(-0.16, 0.05, 1.38), aim=(0.16, 0.99, -0.02),
        pole_r=(-1.0, -0.2, -0.1), pole_l=(0.4, -0.2, -0.9)),
    # `by_facing` overrides the base pose for one facing only. It exists because
    # the 2026-08-16 run measured the pistol at ZERO visible pixels in NE for
    # both of these grips: the camera sits on the +X side, the gun hand is on the
    # figure's right, and at that yaw the torso is exactly between them — an
    # armed player reading as unarmed. It costs nothing to fix, which is the part
    # worth being exact about: §8 already indexes BOTH the body and the weapon on
    # yaw, so a per-facing arm pose lives inside a frame the budget already pays
    # for. It is not mirroring (D45) and it does not index the weapon on pose
    # (D40) — both terms keep their shape.
    ("pistol", "lowered"): dict(
        grip=(-0.24, 0.12, 0.97), aim=(0.05, 0.45, -0.89),
        pole_r=(-0.8, -0.6, -0.4), pole_l=None,
        by_facing={"NE": dict(
            # Out to the figure's right and back toward the camera, clearing the
            # torso's screen span; muzzle near-vertical, which is also the
            # direction that projects LONGEST on a 2:1 diamond.
            grip=(-0.31, -0.13, 1.00), aim=(-0.10, 0.10, -0.99),
            pole_r=(-1.0, -0.5, -0.3))}),
    ("pistol", "ready"): dict(
        grip=(-0.19, 0.15, 1.31), aim=(0.10, 0.55, 0.83),
        pole_r=(-1.0, -0.3, -0.5), pole_l=None,
        by_facing={"NE": dict(
            grip=(-0.38, -0.02, 1.26), aim=(-0.12, 0.25, 0.96),
            pole_r=(-1.0, -0.4, -0.4))}),
    ("pistol", "aimed"): dict(
        grip=(-0.11, 0.55, 1.45), aim=(0.02, 1.0, 0.06),
        pole_r=(-0.6, -0.2, -0.8), pole_l=None),
}
ORDER = [("shotgun", "lowered"), ("shotgun", "ready"), ("shotgun", "aimed"),
         ("pistol", "lowered"), ("pistol", "ready"), ("pistol", "aimed")]

# The idle left arm, for the one-handed grips: hangs, with a little forward
# swing so it does not read as a mannequin.
IDLE_L = dict(upperarm=(0.13, 0.06, -0.99), forearm=(0.02, 0.22, -0.97),
              hand=(0.0, 0.30, -0.95))

YAWS = [0, 90, 180, 270]

## The height the EXPORTED figure ships at — 10.0 voxels at §4.7's 0.20 m.
## Director's call, 2026-08-16. See scale_to_target_height() for what it costs.
## Affects only the GLB the Godot bake reads; the grip matrix above still renders
## Part 1's own 1.898 m so its measured numbers stay comparable.
EXPORT_HEIGHT_M = 2.00

# DIRECTION_GLOSSARY §2/§3, as SCREEN directions. The compass is vertex-aligned
# — N/E/S/W are the diamond's vertices (straight up/right/down/left) and
# NE/SE/SW/NW are its edges, which are the grid axes and therefore the
# directions a tile-stepping character actually walks in. Each yaw's label is
# MEASURED below by projecting the figure's own forward vector, never asserted:
# the glossary bans "N = upper-right" in so many words, and this is the file
# where that mistake would be easiest to make.
# The edge entries are the glossary's own screen deltas, NOT unit diagonals: a
# 45-degree world direction draws at 26.57 degrees on a 2:1 diamond, so scoring
# NE against (0.707, -0.707) fits at 0.949 and scoring it against (32, -16) fits
# at 1.000. The looser table would still have picked the right name here, and
# would stop doing so the moment a facing sat between two entries.
COMPASS_SCREEN = {
    "N": (0.0, -1.0), "E": (1.0, 0.0), "S": (0.0, 1.0), "W": (-1.0, 0.0),
    "NE": (0.894, -0.447), "SE": (0.894, 0.447),
    "SW": (-0.894, 0.447), "NW": (-0.894, -0.447),
}


def log(m):
    print("[P2-GRIP] %s" % m)


def fail(m):
    print("[P2-GRIP][FAIL] %s" % m)
    sys.exit(1)


# --- Posing -------------------------------------------------------------------
def bone_dir(pb):
    """The bone's own head->tail direction in armature space, read from the live
    pose matrix rather than from the rest data."""
    return (pb.matrix.to_quaternion() @ Vector((0.0, 1.0, 0.0))).normalized()


def aim_bone(arm, name, target_dir):
    """Rotate a pose bone so it points along `target_dir` in ARMATURE space,
    keeping its head where the parent chain put it. Roll is left at the minimal
    rotation, which is exactly right for rigid parts and irrelevant for the
    weapon, which takes its orientation from the grip and not from the hand."""
    pb = arm.pose.bones.get(name)
    if pb is None:
        fail("bone %s missing from the rig" % name)
    t = Vector(target_dir).normalized()
    bpy.context.view_layer.update()
    m = pb.matrix.copy()
    head = m.to_translation()
    rot = m.to_quaternion()
    cur = (rot @ Vector((0.0, 1.0, 0.0))).normalized()
    pb.matrix = Matrix.Translation(head) @ (cur.rotation_difference(t) @ rot).to_matrix().to_4x4()
    bpy.context.view_layer.update()
    return pb


def rotate_toward(src, dst, t):
    """`src` rotated `t` of the way toward `dst`. Both unit directions."""
    q = src.rotation_difference(dst)
    if abs(q.angle) < 1e-6:
        return src.copy()
    return (Quaternion(q.axis, q.angle * t) @ src).normalized()


def shoulder_assist(arm, side, target, max_k=0.7):
    """Rotate the SHOULDER bone toward the target, by the least amount that
    brings the target inside the arm's reach — and by nothing at all when the arm
    can already get there.

    This exists because the first run of this script failed its own gate: the
    left hand was 0.356 m short of the shotgun's forend. That is not a solver bug
    and it is not fixable by tuning angles — with a 0.57 m arm and a 0.42 m
    shoulder span, a two-handed hold is genuinely out of reach for a rigid torso.
    Real shooters solve it by bringing the support shoulder forward, and the rig
    already has the bone for it (p1_agent_model.py builds shoulder_L/shoulder_R).
    Leaving those bones at rest was the actual error."""
    up_name = "upperarm_%s" % side
    sh_name = "shoulder_%s" % side
    sh = arm.pose.bones[sh_name]
    sh.matrix_basis.identity()
    bpy.context.view_layer.update()
    rest_dir = bone_dir(sh)
    joint = arm.pose.bones[up_name].matrix.to_translation()
    reach = (arm.data.bones[up_name].length
             + arm.data.bones["forearm_%s" % side].length)
    limit = reach * 0.95
    if (Vector(target) - joint).length <= limit:
        return 0.0

    want = (Vector(target) - sh.matrix.to_translation()).normalized()

    def gap(k):
        aim_bone(arm, sh_name, rotate_toward(rest_dir, want, k))
        return (Vector(target) - arm.pose.bones[up_name].matrix.to_translation()).length

    lo, hi = 0.0, max_k
    if gap(hi) > limit:
        return hi          # as far as the shoulder is allowed to go; the IK gate
                           # downstream is what decides whether that was enough
    for _ in range(14):
        mid = (lo + hi) * 0.5
        if gap(mid) > limit:
            lo = mid
        else:
            hi = mid
    gap(hi)
    return hi


def two_bone_ik(arm, side, target, pole, hand_dir):
    """Place the elbow analytically so the WRIST reaches `target`.

    Law of cosines on the real bone lengths read off the armature — never the
    module constants, so a re-proportioned model cannot silently desync this.
    Returns the achieved wrist error in metres for the caller to gate on."""
    up_name, fo_name, hd_name = ("upperarm_%s" % side, "forearm_%s" % side,
                                 "hand_%s" % side)
    a = arm.data.bones[up_name].length
    b = arm.data.bones[fo_name].length

    # Reset the chain so the joint is read from the current shoulder and not from
    # whatever the previous grip left behind.
    for n in (up_name, fo_name, hd_name):
        arm.pose.bones[n].matrix_basis.identity()
    bpy.context.view_layer.update()
    k = shoulder_assist(arm, side, target)
    shoulder = arm.pose.bones[up_name].matrix.to_translation()

    to_t = Vector(target) - shoulder
    d = to_t.length
    reach = a + b
    clamped = False
    if d > reach * 0.999:
        to_t = to_t.normalized() * (reach * 0.999)
        d = to_t.length
        clamped = True
    if d < abs(a - b) + 1e-4:
        to_t = to_t.normalized() * (abs(a - b) + 1e-4)
        d = to_t.length
        clamped = True

    u = to_t.normalized()
    p = Vector(pole)
    v = p - u * p.dot(u)
    if v.length < 1e-5:
        fail("pole vector for %s is parallel to the reach direction" % side)
    v.normalize()

    cos_a = max(-1.0, min(1.0, (a * a + d * d - b * b) / (2.0 * a * d)))
    ang = math.acos(cos_a)
    elbow = shoulder + u * (a * math.cos(ang)) + v * (a * math.sin(ang))

    aim_bone(arm, up_name, elbow - shoulder)
    bpy.context.view_layer.update()
    elbow_actual = arm.pose.bones[fo_name].matrix.to_translation()
    aim_bone(arm, fo_name, Vector(target) - elbow_actual)
    aim_bone(arm, hd_name, hand_dir)

    bpy.context.view_layer.update()
    wrist = arm.pose.bones[hd_name].matrix.to_translation()
    return (wrist - Vector(target)).length, clamped, k


def reset_pose(arm):
    for pb in arm.pose.bones:
        pb.matrix_basis.identity()
    bpy.context.view_layer.update()


# --- The weapon ---------------------------------------------------------------
def import_weapon(spec):
    """Import and return the root, the two anchor points in the model's own
    UNSCALED units, the scale factor, and every object created."""
    path = os.path.join(PACK, spec["glb"])
    if not os.path.isfile(path):
        fail("weapon missing: %s" % path)
    before = set(bpy.data.objects.keys())
    bpy.ops.import_scene.gltf(filepath=path)
    new = [bpy.data.objects[k] for k in set(bpy.data.objects.keys()) - before]
    meshes = [o for o in new if o.type == "MESH"]
    if not meshes:
        fail("%s imported no mesh" % spec["glb"])

    pts = [m.matrix_world @ v.co for m in meshes for v in m.data.vertices]
    mn = Vector((min(p[i] for p in pts) for i in range(3)))
    mx = Vector((max(p[i] for p in pts) for i in range(3)))
    dims = mx - mn
    if dims.x < dims.y or dims.x < dims.z:
        fail("%s: longest axis is not X (dims %s) — the measured convention "
             "no longer holds, re-measure before trusting the placement"
             % (spec["glb"], tuple(round(v, 3) for v in dims)))
    scale = spec["length_m"] / dims.x

    root = bpy.data.objects.new("WeaponRoot", None)
    bpy.context.collection.objects.link(root)
    # Reparent the TOP-LEVEL imported objects: a GLB brings its own root, so
    # filtering the MESHES for "no parent" matches nothing and leaves the root
    # childless — a bug s2_weapon_in_hand.py hit and caught only by comparing
    # two identical-looking renders.
    for o in [o for o in new if o.parent is None or o.parent not in new]:
        o.parent = root
        o.matrix_parent_inverse = Matrix.Identity(4)

    # Anchors stay in the model's own units; the root's matrix applies the scale
    # exactly once, when the point is transformed to world.
    def anchor(frac):
        return Vector((mn.x + dims.x * frac, (mn.y + mx.y) * 0.5,
                       (mn.z + mx.z) * 0.5))
    grip_local = anchor(spec["grip_at"])
    fore_local = anchor(spec["fore_at"]) if spec["two_handed"] else None
    grip_to_fore_m = (fore_local - grip_local).length * scale if fore_local else 0.0
    log("%s: measured %.3f u -> scale %.4f for %.2f m; grip->fore %.3f m"
        % (spec["glb"], dims.x, scale, spec["length_m"], grip_to_fore_m))
    return root, grip_local, grip_to_fore_m, scale, new


def place_weapon(root, grip_local, scale, grip_world, aim):
    """Seat the weapon so its grip point lands on `grip_world` and its +X points
    along `aim`, with +Z kept as upright as the aim allows."""
    f = Vector(aim).normalized()
    world_up = Vector((0.0, 0.0, 1.0))
    if abs(f.dot(world_up)) > 0.999:
        world_up = Vector((0.0, 1.0, 0.0))
    right = f.cross(world_up).normalized()      # the weapon's -Y
    up = right.cross(f).normalized()            # the weapon's +Z
    basis = Matrix((
        (f.x, -right.x, up.x),
        (f.y, -right.y, up.y),
        (f.z, -right.z, up.z),
    )).to_4x4()
    root.matrix_world = (Matrix.Translation(Vector(grip_world)) @ basis
                         @ Matrix.Scale(scale, 4))
    bpy.context.view_layer.update()
    # Slide the root so it is the GRIP POINT, not the root origin, that sits at
    # grip_world. Measured after the fact rather than solved in advance.
    drift = Vector(grip_world) - (root.matrix_world @ grip_local)
    root.matrix_world = Matrix.Translation(drift) @ root.matrix_world
    bpy.context.view_layer.update()
    landed = (root.matrix_world @ grip_local) - Vector(grip_world)
    if landed.length > 1e-4:
        fail("weapon grip landed %.4f m off its target" % landed.length)


# --- Rendering ----------------------------------------------------------------
def setup_render():
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.render.resolution_x, sc.render.resolution_y = FRAME
    sc.render.resolution_percentage = 100
    sc.render.film_transparent = True
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    sh = sc.display.shading
    sh.light = "STUDIO"
    sh.show_shadows = False
    sh.color_type = "MATERIAL"     # the suit/shirt/skin split IS the art here

    cam_data = bpy.data.cameras.new("cam_p2")
    cam_data.type = "ORTHO"
    # ortho_scale maps to the LARGER render dimension.
    cam_data.ortho_scale = max(FRAME) / PX_PER_SCREEN_M
    cam = bpy.data.objects.new("cam_p2", cam_data)
    bpy.context.collection.objects.link(cam)
    sc.camera = cam

    target = Vector((0.0, 0.0, 0.98))
    e, a = math.radians(GAME_ELEV), math.radians(GAME_AZIM)
    dist = 10.0
    cam.location = Vector((
        target.x + dist * math.cos(e) * math.sin(a),
        target.y - dist * math.cos(e) * math.cos(a),
        dist * math.sin(e) + target.z,
    ))
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
    # Flush it. Without this, cam.matrix_world is still IDENTITY for any Python
    # query made before the next render, and world_to_camera_view silently
    # answers for a camera at the origin looking down -Z — which is how the
    # facing measurement below first reported N/E/S/W with a perfect 1.000 fit
    # while the rendered frames were, correctly, NE/NW/SW/SE. Same class as the
    # Godot pitfall §5 records: geometry read straight after a transform is
    # written is a frame stale.
    bpy.context.view_layer.update()
    log("camera: elev %.0f / azim %.0f, ortho %.4f m over %d px -> %.2f px per "
        "screen-metre (a 0.20 m voxel draws %.1f px)"
        % (GAME_ELEV, GAME_AZIM, cam_data.ortho_scale, max(FRAME),
           PX_PER_SCREEN_M, VOXEL_M * math.cos(e) * PX_PER_SCREEN_M))
    return cam


def grip_for(key, facing_name):
    """The grip's pose for one facing: the base entry, with any `by_facing`
    override merged over it key by key. Partial overrides are the point — an
    override that had to restate every field would drift from its base."""
    g = dict(GRIPS[key])
    over = g.pop("by_facing", {}) or {}
    g["overridden"] = facing_name in over
    g.update(over.get(facing_name, {}))
    return g


def measure_facings():
    """Which compass direction each yaw actually draws, read off the camera.

    The figure faces +Y — itself a measured fact from p1_agent_model.py, where
    the feet point +Y and socket_chest sits at +CHEST_D. This projects that
    forward vector through the real camera at each yaw and names the result from
    the glossary's screen table. The reason it is worth the twenty lines: the
    four yaws could plausibly have come out as the diamond's VERTICES rather than
    its edges, which would have made all 24 frames the wrong 24 frames."""
    sc = bpy.context.scene
    cam = sc.camera
    origin = Vector((0.0, 0.0, 1.0))
    o = world_to_camera_view(sc, cam, origin)
    out = {}
    for yaw in YAWS:
        r = math.radians(yaw)
        fwd = Vector((-math.sin(r), math.cos(r), 0.0))    # +Y turned by yaw
        p = world_to_camera_view(sc, cam, origin + fwd)
        # NDC y runs up; screen y runs down.
        d = Vector(((p.x - o.x) * FRAME[0], -(p.y - o.y) * FRAME[1]))
        d.normalize()
        name, best = None, -2.0
        for k, v in COMPASS_SCREEN.items():
            dot = d.x * v[0] + d.y * v[1]
            if dot > best:
                name, best = k, dot
        out[yaw] = name
        log("yaw %3d: forward projects to screen %s -> %s (fit %.3f)"
            % (yaw, (round(d.x, 3), round(d.y, 3)), name, best))
    if sorted(out.values()) != ["NE", "NW", "SE", "SW"]:
        fail("the four yaws are %s, not the grid-axis set NE/SE/SW/NW — a "
             "tile-stepping character walks the diamond's EDGES, so this set "
             "would be 45 degrees off every facing the game can produce"
             % sorted(out.values()))
    return out


def materialise_for_export():
    """Give every node-less material a real Principled BSDF carrying its own
    colour, so the glTF exporter can see it.

    THE BUG THIS FIXES, because it is bigger than it looks. `p1_agent_model.py`
    builds its palette with `use_nodes = False` and `diffuse_color` — the
    VIEWPORT display colour. Blender's Workbench renderer reads it, which is why
    every character render this project has judged so far (the T-pose sheet, S2,
    the grip matrix) shows the suit/shirt/skin/hat split correctly. **The glTF
    exporter does not read it.** It reads the Principled BSDF's Base Color, and
    with no node tree there is none, so every material exports WHITE.

    Measured, not deduced: the first agent bake came out at mean RGB (234,233,233)
    with 53% of its opaque pixels pure white, and §4.8's whole albedo argument —
    D31's "lit = albedo * (ambient + light) cannot manufacture a colour that was
    never baked in" — applies to a palette that never left Blender.

    WHAT THE .blend ACTUALLY HOLDS, measured rather than assumed — the first
    version of this function guessed and repaired ZERO materials. `use_nodes =
    False` does not survive the save: every material reloads with `use_nodes =
    True` and a Principled BSDF still at Blender's default 0.8 grey, while
    `diffuse_color` carries the authored palette. So the exporter does not see a
    missing material, it sees a uniform grey one — which is why the bake came out
    plausible-looking rather than obviously broken.

    THE RULE, and it is narrow on purpose: sync only materials whose Principled
    base colour is still that untouched default while `diffuse_color` says
    something else. That signature means "authored via diffuse_color only". The
    weapon arrives from a GLB with real base colours, so it is left alone.

    `diffuse_color` is preserved, so Workbench keeps rendering exactly what it
    rendered before and the grip matrix stays reproducible."""
    default_grey = (0.8, 0.8, 0.8, 1.0)
    fixed = 0
    for m in bpy.data.materials:
        if not m.use_nodes or m.node_tree is None:
            m.use_nodes = True
        bsdf = m.node_tree.nodes.get("Principled BSDF") if m.node_tree else None
        if bsdf is None:
            continue
        base = tuple(round(v, 3) for v in bsdf.inputs["Base Color"].default_value)
        rgba = tuple(m.diffuse_color)
        if base != default_grey:
            continue
        if tuple(round(v, 3) for v in rgba) == default_grey:
            continue
        bsdf.inputs["Base Color"].default_value = rgba
        if "Roughness" in bsdf.inputs:
            bsdf.inputs["Roughness"].default_value = 0.85
        if "Metallic" in bsdf.inputs:
            bsdf.inputs["Metallic"].default_value = 0.0
        log("  material %-10s base colour %s -> %s"
            % (m.name, base, tuple(round(v, 3) for v in rgba)))
        fixed += 1
    log("materials: %d carried the palette in diffuse_color only; the exporter "
        "can now see it" % fixed)
    if fixed == 0:
        fail("no material needed the diffuse_color -> base colour sync. Either "
             "p1_agent_model.py now authors real node colours (in which case "
             "delete this function) or the .blend changed shape — do NOT export "
             "a figure whose palette has not been confirmed to survive")
    return fixed


def override_suit_value(value):
    """Repaint the suit (jacket + trousers) to a given brightness, keeping its
    hue, for the near-black bracket.

    Director, 2026-08-16: *"digamos que a gente queira que o terno dele seja bem
    escuro, quase totalmente preto mas ainda distinguindo o volume com a
    iluminação."* Whether that is possible is a question about the RUNTIME, not
    about Blender, so the only honest way to answer it is to bake several suit
    values and read them under the room's real light — hence a parameter rather
    than an edit.

    The suit's authored colour is (0.26, 0.27, 0.34): a charcoal with a blue
    cast. Scaling all three channels by the same factor preserves that cast
    exactly, so the bracket varies ONE thing. `suit_lo` (the trousers, a shade
    under the jacket) keeps its relationship for the same reason."""
    if value is None:
        return
    for name, authored in (("suit", (0.26, 0.27, 0.34)),
                           ("suit_lo", (0.19, 0.20, 0.26))):
        m = bpy.data.materials.get(name)
        if m is None:
            fail("material %s missing — cannot run the suit bracket" % name)
        k = value / 0.26          ## the jacket is the reference channel
        rgba = (authored[0] * k, authored[1] * k, authored[2] * k, 1.0)
        m.diffuse_color = rgba
        bsdf = m.node_tree.nodes.get("Principled BSDF") if m.node_tree else None
        if bsdf is not None:
            bsdf.inputs["Base Color"].default_value = rgba
        log("suit bracket: %-8s -> (%.3f, %.3f, %.3f)"
            % (name, rgba[0], rgba[1], rgba[2]))


def scale_to_target_height(arm):
    """Scale the whole rig so the figure ships at EXPORT_HEIGHT_M.

    Director, 2026-08-16: *"aumenta um pouquinho o boneco todo [...] pra ver se
    ele tem aprox. 10 voxels de altura em standing com chapéu."* 10 voxels at
    §4.7's 0.20 m is 2.00 m, against the 1.898 m Part 1 built — a 5.4% lift.

    IT SCALES THE MODEL, NOT THE CAMERA, and the difference is the whole point.
    agent_frame_bake_spike.gd derives its pixel scale from VOXEL_STEP_PX and
    gates on it, so nudging MESH_SCALE there would still pass the gate while
    making the figure "bigger" in a way that corresponds to no real height —
    §4.7's metres would quietly become a fiction. Changing the height here keeps
    every downstream number honest: he is drawn bigger because he IS bigger.

    ⚠️ THE COST, stated rather than absorbed: §4.7 records the BODY at 1.80 m =
    9.0 voxels exactly, and `s2_posture_scale.py` VERIFIED the standing/crouched/
    prone bands against it. Scaling the whole figure carries the body to 1.897 m
    (9.49 voxels), so that verification no longer describes this asset. The
    alternative that preserves it is raising only the hat — the question
    `agent_sculpt_start.blend` deliberately draws as two labelled lines — and it
    is one constant away if the Director prefers it."""
    src = 1.898
    factor = EXPORT_HEIGHT_M / src
    arm.scale = (factor,) * 3
    bpy.context.view_layer.update()
    log("scale: figure %.3f m -> %.3f m (x%.4f) = %.2f voxels at %.2f m/voxel"
        % (src, EXPORT_HEIGHT_M, factor, EXPORT_HEIGHT_M / 0.20, 0.20))
    log("       body carried from 1.800 m (9.00 voxels) to %.3f m (%.2f voxels) "
        "— see this function's note" % (1.80 * factor, 1.80 * factor / 0.20))


def export_posed(arm, key, facing_name):
    """Write ONE posed figure + weapon as a static GLB, for the Godot bake.

    Why static rather than rigged: `actor_frame_bake_spike.gd` loads a single
    GLB and rotates the OBJECT between frames — it has no rig and wants none. So
    the pose is applied to the geometry here (`export_apply`, skins off) and what
    lands on disk is a posed mesh, not a character to animate. The rig stays in
    `agent_base.blend`; this is a render source.
    """
    weapon, grip_name = key
    spec = WEAPONS[weapon]
    g = grip_for(key, facing_name)
    aim = Vector(g["aim"]).normalized()
    grip_world = Vector(g["grip"])

    arm.rotation_euler = (0.0, 0.0, 0.0)
    reset_pose(arm)
    root, grip_local, grip_to_fore_m, wscale, created = import_weapon(spec)
    root.parent = arm
    root.matrix_parent_inverse = Matrix.Identity(4)
    socket_off = arm.data.bones["hand_R"].length * 0.5
    err_r, _, _ = two_bone_ik(arm, "R", grip_world - aim * socket_off, g["pole_r"], aim)
    if spec["two_handed"]:
        err_l, _, _ = two_bone_ik(arm, "L",
                                  grip_world + aim * grip_to_fore_m - aim * socket_off,
                                  g["pole_l"], aim)
    else:
        for part, d in (("upperarm", IDLE_L["upperarm"]), ("forearm", IDLE_L["forearm"]),
                        ("hand", IDLE_L["hand"])):
            aim_bone(arm, "%s_L" % part, d)
        err_l = 0.0
    if err_r > 0.02 or err_l > 0.02:
        fail("export pose did not reach (R %.4f L %.4f)" % (err_r, err_l))
    place_weapon(root, grip_local, wscale, grip_world, aim)

    materialise_for_export()
    suit_env = os.environ.get("P2_SUIT_VALUE", "")
    suit = float(suit_env) if suit_env else None
    override_suit_value(suit)
    scale_to_target_height(arm)
    suffix = "" if suit is None else "_suit%03d" % int(round(suit * 1000))
    # The SOURCE model's variant has to reach the filename too. It did not, and
    # two exports of different models silently overwrote each other at the same
    # path — caught only because the re-import mesh count changed from 49 to 37.
    suffix += "" if _MODEL == "agent_base" else _MODEL.replace("agent_base", "")
    out = os.path.join(os.path.dirname(BLEND),
                       "agent_posed_%s_%s%s.glb" % (weapon, grip_name, suffix))
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=out, export_format="GLB",
                              export_apply=True, export_skins=False,
                              export_yup=True)

    # Verify the EXPORT, not the scene it came from — export_apply silently
    # doing nothing would leave a T-posed figure on disk while every check above
    # passed. Re-import and measure what actually landed.
    before = set(bpy.data.objects.keys())
    bpy.ops.import_scene.gltf(filepath=out)
    back = [bpy.data.objects[k] for k in set(bpy.data.objects.keys()) - before
            if bpy.data.objects[k].type == "MESH"]
    pts = [m.matrix_world @ v.co for m in back for v in m.data.vertices]
    if not pts:
        fail("the exported GLB re-imports with no geometry")
    height = max(p.z for p in pts) - min(p.z for p in pts)
    span_x = max(p.x for p in pts) - min(p.x for p in pts)
    log("exported %s — re-imported %d meshes, height %.3f m (%.2f voxels), "
        "x-span %.3f m" % (os.path.relpath(out, REPO_ROOT), len(back), height,
                           height / 0.20, span_x))
    if abs(height - EXPORT_HEIGHT_M) > 0.01:
        fail("exported figure is %.3f m, expected %.3f — the pose or the scale "
             "did not survive the export" % (height, EXPORT_HEIGHT_M))
    if span_x > 1.4 * (EXPORT_HEIGHT_M / 1.898):
        fail("exported figure spans %.3f m in X — that is the T-POSE (1.76 m "
             "span), so export_apply did not bake the pose in" % span_x)
    return out


def main():
    if not os.path.isfile(BLEND):
        fail("model missing: %s — run p1_agent_model.py first" % BLEND)
    bpy.ops.wm.open_mainfile(filepath=BLEND)
    arm = bpy.data.objects.get("AgentRig")
    if arm is None:
        fail("AgentRig not found in %s" % BLEND)
    # Every target below is written in WORLD coordinates while the solver reads
    # ARMATURE space. That is only the same space while the rig sits at identity,
    # so it is checked rather than assumed.
    drift = max(abs(arm.matrix_world[r][c] - (1.0 if r == c else 0.0))
                for r in range(4) for c in range(4))
    if drift > 1e-5:
        fail("AgentRig is not at identity (max element drift %.5f) — armature "
             "space would not equal world space and every grip target would be "
             "silently offset" % drift)

    for name in ("socket_hand_R", "socket_hand_L"):
        if bpy.data.objects.get(name) is None:
            fail("%s missing — the §4.3 socket contract is what this spike "
                 "exercises" % name)

    setup_render()
    os.makedirs(OUT_DIR, exist_ok=True)
    facing = measure_facings()

    # P2_EXPORT_GLB=shotgun:ready writes the posed source the Godot bake reads,
    # then stops. Same pose machinery as the sheet, so the thing that goes into
    # the game is the thing the Director judged — not a second pose that merely
    # resembles it.
    want = os.environ.get("P2_EXPORT_GLB", "")
    if want:
        parts = want.split(":")
        key = (parts[0], parts[1])
        if key not in GRIPS:
            fail("P2_EXPORT_GLB=%s is not one of %s"
                 % (want, ["%s:%s" % k for k in ORDER]))
        export_posed(arm, key, parts[2] if len(parts) > 2 else "NE")
        return

    frames = []

    os.makedirs(os.path.join(OUT_DIR, "nogun"), exist_ok=True)
    socket_off = arm.data.bones["hand_R"].length * 0.5

    for key in ORDER:
        weapon, grip_name = key
        spec = WEAPONS[key[0]]
        root, grip_local, grip_to_fore_m, wscale, created = import_weapon(spec)
        root.parent = arm
        root.matrix_parent_inverse = Matrix.Identity(4)

        # The pose is now solved PER FACING, not once per grip. Yaw was always an
        # axis of both §8 terms, so this multiplies nothing — it just stops
        # pretending one arm pose can serve four camera-relative situations. Most
        # facings still take the base pose verbatim.
        for yaw in YAWS:
            g = grip_for(key, facing[yaw])
            aim = Vector(g["aim"]).normalized()
            grip_world = Vector(g["grip"])

            # Pose at identity: the solver works in armature space, and that is
            # only world space while the rig is unrotated.
            arm.rotation_euler = (0.0, 0.0, 0.0)
            reset_pose(arm)

            # The wrist target is the grip point pulled back along the hand's own
            # direction by the socket's offset, so it is the SOCKET that lands on
            # the weapon — the contract Part 4's compositor will bind to.
            err_r, clamped_r, k_r = two_bone_ik(arm, "R", grip_world - aim * socket_off,
                                                g["pole_r"], aim)
            if spec["two_handed"]:
                fore_world = grip_world + aim * grip_to_fore_m
                err_l, clamped_l, k_l = two_bone_ik(
                    arm, "L", fore_world - aim * socket_off, g["pole_l"], aim)
            else:
                for part, d in (("upperarm", IDLE_L["upperarm"]),
                                ("forearm", IDLE_L["forearm"]),
                                ("hand", IDLE_L["hand"])):
                    aim_bone(arm, "%s_L" % part, d)
                err_l, clamped_l, k_l = 0.0, False, 0.0

            place_weapon(root, grip_local, wscale, grip_world, aim)

            # Verify against the SOCKETS, which is the thing that has to be right.
            bpy.context.view_layer.update()
            sr = bpy.data.objects["socket_hand_R"].matrix_world.translation
            off_r = (sr - grip_world).length
            log("%s/%s %-2s%s: wrist err R %.4f L %.4f m%s | shoulder assist "
                "R %.2f L %.2f | socket_hand_R %.3f m from the grip"
                % (weapon, grip_name, facing[yaw], "*" if g["overridden"] else " ",
                   err_r, err_l, " (CLAMPED)" if (clamped_r or clamped_l) else "",
                   k_r, k_l, off_r))
            if err_r > 0.02 or err_l > 0.02:
                fail("%s/%s %s: IK did not reach (R %.4f L %.4f) — the target is "
                     "outside the arm's reach, so the pose on screen is NOT the "
                     "pose declared" % (weapon, grip_name, facing[yaw], err_r, err_l))
            if off_r > 0.09:
                fail("%s/%s %s: the right hand socket is %.3f m from the grip — "
                     "at ship size that is %.0f px of daylight between hand and "
                     "weapon" % (weapon, grip_name, facing[yaw], off_r,
                                 off_r * PX_PER_SCREEN_M))

            # Rendered TWICE, with the weapon and without. The pair is what lets
            # p2_grip_sheet.py measure how many weapon pixels survive the body's
            # occlusion and how far they sit from what is behind them — the
            # difference between "it reads" as an impression and as a number.
            arm.rotation_euler = (0.0, 0.0, math.radians(yaw))
            bpy.context.view_layer.update()
            name = "%s_%s_yaw%03d.png" % (weapon, grip_name, yaw)
            for hide, folder in ((False, OUT_DIR), (True, os.path.join(OUT_DIR, "nogun"))):
                for ob in created:
                    ob.hide_render = hide
                bpy.context.scene.render.filepath = os.path.join(folder, name)
                bpy.ops.render.render(write_still=True)
            for ob in created:
                ob.hide_render = False
            frames.append(dict(weapon=weapon, grip=grip_name, yaw=yaw,
                               facing=facing[yaw], overridden=g["overridden"],
                               file=name))
        arm.rotation_euler = (0.0, 0.0, 0.0)

        # Remove EVERY object the import created, not just the meshes — a GLB
        # brings its own empties, and leaked ones would accumulate across the six
        # passes and quietly appear in later frames.
        for ob in created + [root]:
            if ob.name in bpy.data.objects:
                bpy.data.objects.remove(ob, do_unlink=True)

    # --- The reference frame the size gate reads. -----------------------------
    # A weapon-free idle, with its pixel box PREDICTED by projecting the real
    # evaluated vertices through the real camera. The first version of this gate
    # compared the alpha box against height x cos(elevation) and failed every
    # frame by 8.5% — not because the camera was wrong, but because an isometric
    # silhouette is taller than the figure: the body's depth projects into
    # screen-Y too. Comparing a measurement against an ANALYTIC ideal that
    # models less than the render does is how a good gate reports a false
    # failure. This one predicts exactly what it measures.
    reset_pose(arm)
    for side, mirror in (("L", 1.0), ("R", -1.0)):
        for part in ("upperarm", "forearm", "hand"):
            d = IDLE_L[part]
            aim_bone(arm, "%s_%s" % (part, side), (d[0] * mirror, d[1], d[2]))
    bpy.context.view_layer.update()

    body = [ob for ob in bpy.data.objects if ob.type == "MESH" and ob.parent == arm]
    deps = bpy.context.evaluated_depsgraph_get()
    cam = bpy.context.scene.camera
    sc = bpy.context.scene
    xs, ys, zs = [], [], []
    for ob in body:
        ev = ob.evaluated_get(deps)
        me = ev.to_mesh()
        for v in me.vertices:
            w = ev.matrix_world @ v.co
            zs.append(w.z)
            ndc = world_to_camera_view(sc, cam, w)
            xs.append(ndc.x * FRAME[0])
            ys.append((1.0 - ndc.y) * FRAME[1])
        ev.to_mesh_clear()
    height_m = max(zs) - min(zs)
    predicted = [min(xs), min(ys), max(xs), max(ys)]

    ref = "reference_idle_yaw000.png"
    sc.render.filepath = os.path.join(OUT_DIR, ref)
    bpy.ops.render.render(write_still=True)

    manifest = dict(
        frame=list(FRAME),
        px_per_screen_m=PX_PER_SCREEN_M,
        elevation_deg=GAME_ELEV,
        figure_height_m=height_m,
        # The game's own reach: how many voxel levels the figure occludes. This
        # is §4.7's 196 px, and it is NOT the sprite's pixel height.
        vertical_reach_px=height_m * math.cos(math.radians(GAME_ELEV)) * PX_PER_SCREEN_M,
        reference_frame=ref,
        reference_bbox_predicted=predicted,
        order=[list(k) for k in ORDER],
        yaws=YAWS,
        facings={str(k): v for k, v in facing.items()},
        frames=frames,
    )
    with open(os.path.join(OUT_DIR, "manifest.json"), "w") as fh:
        json.dump(manifest, fh, indent=2)
    log("figure is %.3f m = %.2f voxels -> occludes %.1f px of vertical"
        % (height_m, height_m / VOXEL_M, manifest["vertical_reach_px"]))
    log("reference silhouette predicted at %s px"
        % (tuple(round(v, 1) for v in predicted),))
    log("wrote %d frames + reference + manifest.json to %s"
        % (len(frames), os.path.relpath(OUT_DIR, REPO_ROOT)))


if __name__ == "__main__":
    main()
