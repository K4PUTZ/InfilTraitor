"""CHARACTER_MASTER_PLAN Part 1 — the agent's base model and rig, in T-POSE.

WHAT THIS SUPERSEDES. s2_mockup_character.py built a box figure to answer ONE
motion question, and its own docstring says so: "not the character... none of it
is art-directed". It stays as the S2 artifact. This is the first model authored
as art, at the Director's call (2026-08-15): "acho que chegou a hora de dar uma
trabalhada na arte da modelagem e fazer a primeira T pose de verdade."

WHY T-POSE, AND WHY IT IS NOT A STYLE CHOICE. D32 requires the second archetype
to be a MESH RETARGET onto this skeleton, never a second rig
(CHARACTER_MASTER_PLAN §4.2). Retargeting needs a rest pose whose limbs are
unambiguously aligned to axes; an arms-down rest bakes a shoulder rotation into
the bind that every retarget then has to undo. T-pose is also what every DCC and
every glTF consumer assumes. The mockup's arms-down rest was fine for spinning a
figure on the spot and is wrong as a foundation.

WHAT IS DELIBERATELY UNCHANGED. Every skeletal proportion, every z height, and
the ~20-bone name set are carried over from the mockup EXACTLY. That is not
laziness -- §4.7's scale (1 voxel = 0.20 m; standing 9.8 / crouched 5.5 / prone
2.2 voxels) was MEASURED against those numbers by s2_posture_scale.py and is
recorded as SETTLED. Re-proportioning the figure here would silently invalidate a
verified result, and the art problem the Director raised is about FORM, not about
metrics. Bone names are identical so every existing pose/render script keeps
working.

WHERE THE WORK WENT INSTEAD -- form, and specifically silhouette. The figure is
seen at ~196 px tall in a fixed 3/4 view, so anything finer than a couple of
centimetres is invisible and anything that changes the OUTLINE is worth its
polygons:
  - every limb is a TAPERED prism, not a constant box, and every hard edge is
    bevelled -- the chamfer is what reads as moulded plastic rather than as
    programmer geometry
  - real BALL JOINTS at shoulder, elbow, hip and knee. This is the action-figure
    read of D35 stated in geometry instead of in a gap. Each ball binds to the
    CHILD bone, so it rotates with the moving limb the way a real toy's does
  - the fedora gets a brim with a raised outer curl, a tapered crown and a
    hatband -- the single strongest silhouette cue in the gangster/Michael
    Jackson direction (D35), and cheap
  - jacket shoulders flare wider than the chest and the hem flares below a
    narrowed waist; trousers taper and crop above the shoe, which is the MJ
    read the Director named
  - shoes are a soled, tapered last rather than a slab

MATERIALS. Flat unlit albedo only, which is exactly what §4.8's bake pass wants
(lighting is applied at runtime by flat_normal_relight.gdshader, never baked).
§4.8 also flags the trap in advance: D31 measured the pistol's baked albedo at
RGB (47,46,45) -- dark AND hueless -- so no runtime light could restore colour
that was never captured. These values are therefore deliberately mid-bright and
saturated at source rather than "realistically" dark.

Run:
  /Applications/Blender.app/Contents/MacOS/Blender --background \
    --python tools/asset_generation/p1_agent_model.py
"""

import math
import os
import sys

import bpy
from mathutils import Vector

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT_DIR = os.path.join(REPO_ROOT, "ASSETS", "ISOMETRIC", "source_assets",
                       "imported_models", "agent")
_VARIANT = os.environ.get("P1_VARIANT", "")
OUT_GLB = os.path.join(OUT_DIR, "agent_base%s.glb" % _VARIANT)
OUT_BLEND = os.path.join(OUT_DIR, "agent_base%s.blend" % _VARIANT)

# --- Proportions: CARRIED OVER VERBATIM from the mockup. See the docstring. ---
HEIGHT = 1.80
HEAD_H = HEIGHT / 7.5
NECK_H = 0.05
CHEST_H = 0.34
ABDOMEN_H = 0.16
HIP_H = 0.13
THIGH_L = 0.44
SHIN_L = 0.42
FOOT_H = 0.06
FOOT_L = 0.24
UPPERARM_L = 0.30
FOREARM_L = 0.27
HAND_L = 0.10

SHOULDER_W = 0.42
CHEST_D = 0.20
HIP_W = 0.30
LIMB_W = 0.10

JOINT_GAP = 0.018

FEDORA_BRIM_R = 0.168
FEDORA_CROWN_R = 0.112
FEDORA_CROWN_H = 0.115

BEVEL_W = 0.008
BALL_R = LIMB_W * 0.62

# Albedo. The suit family went NEAR-BLACK on 2026-08-16 (Director, after the
# p2_suit_bracket capture: "o mais escuro de cima ficou ótimo [...] vamos aplicar
# no sapato e no chapéu"), so the §4.8 note about grading bright at source now
# applies only to the skin/shirt/sock/band group.
#
# WHAT GOING NEAR-BLACK COSTS, and it is why the crease geometry below exists:
# the runtime relight is MULTIPLICATIVE (lit = albedo * (ambient + light)), so a
# 0.02 albedo compresses the whole lit-to-shadowed range into roughly 2..9 of
# 255. Volume can no longer come from the lighting's value gradient, so it has to
# come from GEOMETRY and from albedo edges — the Director's own answer:
# "o que pode ajudar com o volume são dobrinhas e vincos na roupa, com shades
# marcando os contornos."
MATS = {
    "suit":    (0.020, 0.021, 0.026, 1.0),  # near-black, blue cast preserved
    "suit_lo": (0.015, 0.016, 0.020, 1.0),  # trousers, a shade under the jacket
    # The crease/fold family. Deliberately a MULTIPLE of the suit rather than an
    # offset: at this albedo an additive lift would vanish under one light and
    # blow out under another, while a ratio keeps the same relationship in both.
    "seam_hi": (0.050, 0.052, 0.063, 1.0),  # 2.5x — a fold catching the light
    # 0.65x, not 0.4x. At 0.4x these read as hard black BARS rather than as
    # fabric — a fold is a gradient and a cut edge is not, and the four-frame
    # comparison showed the difference plainly. Softened 2026-08-16.
    "seam_lo": (0.013, 0.013, 0.017, 1.0),
    "shirt":   (0.86, 0.87, 0.90, 1.0),
    "skin":    (0.72, 0.55, 0.42, 1.0),
    "hat":     (0.020, 0.020, 0.025, 1.0),  # applied 2026-08-16
    "band":    (0.62, 0.16, 0.18, 1.0),     # hatband: the one warm accent
    "shoe":    (0.016, 0.015, 0.018, 1.0),  # applied 2026-08-16
    # Same colour as the suit, still its OWN material. The Director asked to see
    # the joints in the suit's material; giving them the suit material outright
    # would make them unaddressable, and the next task on the list is tinting
    # exactly these yellow for DEV VISION. Same value, separate handle.
    "joint":   (0.020, 0.021, 0.026, 1.0),
    "sock":    (0.90, 0.90, 0.92, 1.0),     # the MJ white sock, above the shoe
}


def log(msg):
    print("[P1-MODEL] %s" % msg)


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


# DEV VISION build. Director, 2026-08-16: "deixamos as juntas amarelas no DEV
# VISION, pra facilitar o debug." P1_JOINTS_YELLOW=1 recolours ONLY the joint
# material, which is the entire reason the joints kept their own material when
# they were given the suit's colour rather than being merged into it.
_JOINTS_YELLOW = os.environ.get("P1_JOINTS_YELLOW") == "1"
if _JOINTS_YELLOW:
    MATS["joint"] = (0.92, 0.78, 0.10, 1.0)


def material(key):
    if key in bpy.data.materials:
        return bpy.data.materials[key]
    m = bpy.data.materials.new(key)
    m.use_nodes = False
    m.diffuse_color = MATS[key]
    return m


def finish(ob, mat_key, bevel=BEVEL_W):
    """Bevel and shade one part. The chamfer is the moulded-plastic read; without
    it every silhouette corner is a mathematically perfect right angle and the
    figure looks like collision geometry."""
    ob.data.materials.append(material(mat_key))
    if bevel > 0.0:
        bpy.context.view_layer.objects.active = ob
        mod = ob.modifiers.new("bev", "BEVEL")
        mod.width = bevel
        mod.segments = 2
        mod.limit_method = "ANGLE"
        mod.angle_limit = math.radians(35.0)
        bpy.ops.object.modifier_apply(modifier="bev")
    return ob


def frame_for(direction):
    """The two axes a segment's cross section is measured along, given its
    direction. This exists because the obvious approach is silently WRONG.

    The first pass oriented each prism with `axis.to_track_quat("Z", "Y")`, which
    fixes where local Z points but leaves the ROLL about that axis undefined for
    a near-vertical segment. Pure-Z segments happened to land one way and the
    shirt panel -- vertical but tilted a few degrees in Y to follow the chest --
    landed another, so its 85 mm WIDTH became 85 mm of DEPTH: a blade sticking
    straight out of the chest, clearly visible in the side view. The lesson is
    the same one D30 paid for with a copied PERSPECTIVE_YAW_DEG that came out
    178 degrees wrong -- derive the frame, never inherit it from a convenience
    function whose convention you have not checked.

    Semantics, fixed here once: `w` runs along the returned e0, `d` along e1.
      vertical segments (torso, limbs)  -> w = world X, d = world Y
      X-aligned segments (T-pose arms)  -> w = world Y, d = world Z
      Y-aligned segments (feet)         -> w = world X, d = world Z
    """
    d = direction.normalized()
    if abs(d.x) > 0.9:
        e0 = Vector((0.0, 1.0, 0.0))
    else:
        e0 = Vector((1.0, 0.0, 0.0))
    e1 = d.cross(e0)
    if e1.length < 1e-6:
        e1 = d.cross(Vector((0.0, 0.0, 1.0)))
    e1.normalize()
    e0 = e1.cross(d).normalized()
    return e0, e1


def prism(name, p0, p1, w0, d0, w1, d1, mat_key, bevel=BEVEL_W):
    """A tapered 8-vertex box from p0 to p1, with independent cross sections at
    each end. Vertices are placed directly in world space against frame_for()'s
    explicit axes -- no object rotation, so nothing depends on an implicit roll."""
    p0, p1 = Vector(p0), Vector(p1)
    axis = p1 - p0
    if axis.length < 1e-6:
        raise ValueError("degenerate segment %s" % name)
    e0, e1 = frame_for(axis)

    verts = []
    for (p, w, d) in ((p0, w0, d0), (p1, w1, d1)):
        verts += [tuple(p - e0 * (w * 0.5) - e1 * (d * 0.5)),
                  tuple(p + e0 * (w * 0.5) - e1 * (d * 0.5)),
                  tuple(p + e0 * (w * 0.5) + e1 * (d * 0.5)),
                  tuple(p - e0 * (w * 0.5) + e1 * (d * 0.5))]
    faces = [(0, 1, 2, 3), (7, 6, 5, 4), (0, 4, 5, 1),
             (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)]

    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    me.update()
    me.validate()
    ob = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(ob)
    return finish(ob, mat_key, bevel)


def ball(name, centre, radius, mat_key):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=8,
                                         radius=radius, location=centre)
    ob = bpy.context.active_object
    ob.name = name
    bpy.ops.object.shade_flat()
    return finish(ob, mat_key, bevel=0.0)


def disc(name, centre, radius, height, mat_key, verts=20, top_scale=1.0):
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=radius,
                                    radius2=radius * top_scale, depth=height,
                                    location=centre)
    ob = bpy.context.active_object
    ob.name = name
    return finish(ob, mat_key, bevel=0.004)


# --- Skeleton -----------------------------------------------------------------
def build_armature():
    """Same 20 bones, same names. The ARMS are the change: they run along +/-X
    at shoulder height instead of hanging down."""
    arm_data = bpy.data.armatures.new("AgentRig")
    arm = bpy.data.objects.new("AgentRig", arm_data)
    bpy.context.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm_data.edit_bones

    z_hip = FOOT_H + SHIN_L + THIGH_L
    z_chest = z_hip + HIP_H + ABDOMEN_H
    z_neck = z_chest + CHEST_H
    z_head = z_neck + NECK_H
    z_shoulder = z_neck - 0.05

    def bone(name, head, tail, parent=None, connected=False):
        b = eb.new(name)
        b.head = Vector(head)
        b.tail = Vector(tail)
        if parent is not None:
            b.parent = eb[parent]
            b.use_connect = connected
        return b

    bone("root", (0, 0, 0), (0, 0, 0.12))
    bone("hips", (0, 0, z_hip), (0, 0, z_hip + HIP_H), "root")
    bone("spine", (0, 0, z_hip + HIP_H), (0, 0, z_chest), "hips", True)
    bone("chest", (0, 0, z_chest), (0, 0, z_neck), "spine", True)
    bone("neck", (0, 0, z_neck), (0, 0, z_head), "chest", True)
    bone("head", (0, 0, z_head), (0, 0, z_head + HEAD_H), "neck", True)

    for side, sx in (("L", 1.0), ("R", -1.0)):
        sh_x = sx * SHOULDER_W * 0.5
        bone("shoulder_%s" % side, (sx * 0.04, 0, z_neck - 0.03),
             (sh_x, 0, z_shoulder), "chest")
        x0 = sh_x
        x1 = sh_x + sx * UPPERARM_L
        x2 = x1 + sx * FOREARM_L
        x3 = x2 + sx * HAND_L
        bone("upperarm_%s" % side, (x0, 0, z_shoulder), (x1, 0, z_shoulder),
             "shoulder_%s" % side, True)
        bone("forearm_%s" % side, (x1, 0, z_shoulder), (x2, 0, z_shoulder),
             "upperarm_%s" % side, True)
        bone("hand_%s" % side, (x2, 0, z_shoulder), (x3, 0, z_shoulder),
             "forearm_%s" % side, True)

        hip_x = sx * HIP_W * 0.5
        bone("thigh_%s" % side, (hip_x, 0, z_hip), (hip_x, 0, z_hip - THIGH_L), "hips")
        bone("shin_%s" % side, (hip_x, 0, z_hip - THIGH_L), (hip_x, 0, FOOT_H),
             "thigh_%s" % side, True)
        bone("foot_%s" % side, (hip_x, 0, FOOT_H), (hip_x, FOOT_L * 0.6, 0.0),
             "shin_%s" % side, True)

    bpy.ops.object.mode_set(mode="OBJECT")
    log("armature: %d bones, arms in T" % len(arm_data.bones))
    return arm, dict(z_hip=z_hip, z_chest=z_chest, z_neck=z_neck,
                     z_head=z_head, z_shoulder=z_shoulder)


# --- Body ---------------------------------------------------------------------
def build_segments(z):
    g = JOINT_GAP
    segs = []
    zh, zc, zn, zhd, zs = (z["z_hip"], z["z_chest"], z["z_neck"],
                           z["z_head"], z["z_shoulder"])

    # Torso. The suit's line is the point: hips solid, waist pinched, chest
    # flaring to a shoulder wider than the ribcage.
    segs.append(("hips", prism("seg_hips", (0, 0, zh), (0, 0, zh + HIP_H - g),
                               HIP_W, CHEST_D * 0.92, HIP_W * 0.88,
                               CHEST_D * 0.84, "suit")))
    # JACKET, not torso. Director, 2026-08-16: "a roupa está muito colada no
    # corpo e não parece um terno." The old waist pinched to HIP_W*0.80 and the
    # chest tapered like a ribcage — that is a BODY, and a body in a dark
    # material reads as a wetsuit. Tailoring does the opposite of anatomy: it
    # holds a near-straight line from chest to hem, stands off the waist, and
    # carries the shoulder past the joint. Every number below moved outward.
    segs.append(("spine", prism("seg_abdomen", (0, 0, zh + HIP_H),
                                (0, 0, zc - g),
                                HIP_W * 0.98, CHEST_D * 0.92,
                                HIP_W * 1.04, CHEST_D * 0.98, "suit")))
    segs.append(("chest", prism("seg_chest", (0, 0, zc), (0, 0, zn - g),
                                HIP_W * 1.06, CHEST_D * 1.02,
                                SHOULDER_W * 1.09, CHEST_D * 1.06, "suit")))
    # Jacket hem: a short flare below the waist, the strongest "wearing a suit"
    # silhouette cue that costs almost nothing.
    segs.append(("spine", prism("seg_jacket_hem", (0, 0, zh + HIP_H * 0.30),
                                (0, 0, zh + HIP_H + ABDOMEN_H * 0.60),
                                HIP_W * 1.24, CHEST_D * 1.14,
                                HIP_W * 1.02, CHEST_D * 0.96, "suit")))
    # Shirt V, INSET so its outer face is flush with the chest rather than
    # floating in front of it, plus a collar at the neck.
    shirt_t = 0.016
    segs.append(("chest", prism("seg_shirt",
                                (0, CHEST_D * 0.478 - shirt_t * 0.5, zn - 0.17),
                                (0, CHEST_D * 0.500 - shirt_t * 0.5, zn - g),
                                0.085, shirt_t, 0.155, shirt_t,
                                "shirt", bevel=0.004)))
    segs.append(("chest", prism("seg_collar", (0, 0, zn - 0.035), (0, 0, zn + 0.022),
                                0.155, 0.135, 0.125, 0.115,
                                "shirt", bevel=0.005)))

    segs.append(("neck", prism("seg_neck", (0, 0, zn), (0, 0, zhd),
                               0.095, 0.095, 0.085, 0.085, "skin")))
    # Head: cranium wide, jaw narrower.
    segs.append(("head", prism("seg_head", (0, 0, zhd), (0, 0, zhd + HEAD_H - g),
                               0.145, 0.165, 0.165, 0.175, "skin")))

    # Fedora. Brim disc with a raised outer curl, tapered crown, hatband.
    brim_z = zhd + HEAD_H * 0.62
    segs.append(("head", disc("seg_fedora_brim", (0, 0, brim_z),
                              FEDORA_BRIM_R, 0.018, "hat", top_scale=0.90)))
    segs.append(("head", disc("seg_fedora_curl", (0, 0, brim_z + 0.016),
                              FEDORA_BRIM_R * 0.99, 0.014, "hat",
                              top_scale=0.86)))
    segs.append(("head", disc("seg_fedora_band", (0, 0, brim_z + 0.034),
                              FEDORA_CROWN_R * 1.06, 0.030, "band",
                              top_scale=1.0)))
    segs.append(("head", disc("seg_fedora_crown",
                              (0, 0, brim_z + 0.034 + FEDORA_CROWN_H * 0.5),
                              FEDORA_CROWN_R, FEDORA_CROWN_H, "hat",
                              top_scale=0.82)))

    for side, sx in (("L", 1.0), ("R", -1.0)):
        sh_x = sx * SHOULDER_W * 0.5
        x1 = sh_x + sx * UPPERARM_L
        x2 = x1 + sx * FOREARM_L
        x3 = x2 + sx * HAND_L

        # Ball joints bind to the CHILD bone so they rotate with the moving limb.
        segs.append(("upperarm_%s" % side,
                     ball("joint_shoulder_%s" % side, (sh_x, 0, z["z_shoulder"]),
                          BALL_R * 1.08, "joint")))
        segs.append(("forearm_%s" % side,
                     ball("joint_elbow_%s" % side, (x1, 0, z["z_shoulder"]),
                          BALL_R * 0.88, "joint")))

        segs.append(("upperarm_%s" % side,
                     prism("seg_upperarm_%s" % side,
                           (sh_x + sx * g, 0, z["z_shoulder"]),
                           (x1 - sx * g, 0, z["z_shoulder"]),
                           LIMB_W * 1.22, LIMB_W * 1.22,
                           LIMB_W * 1.10, LIMB_W * 1.10, "suit")))
        segs.append(("forearm_%s" % side,
                     prism("seg_forearm_%s" % side,
                           (x1 + sx * g, 0, z["z_shoulder"]),
                           (x2 - sx * g, 0, z["z_shoulder"]),
                           LIMB_W * 1.06, LIMB_W * 1.06,
                           LIMB_W * 0.88, LIMB_W * 0.92, "suit")))
        segs.append(("hand_%s" % side,
                     prism("seg_hand_%s" % side,
                           (x2 + sx * g, 0, z["z_shoulder"]),
                           (x3, 0, z["z_shoulder"]),
                           LIMB_W * 0.80, LIMB_W * 0.52,
                           LIMB_W * 0.66, LIMB_W * 0.44, "skin")))

        hip_x = sx * HIP_W * 0.5
        z_knee = z["z_hip"] - THIGH_L
        segs.append(("thigh_%s" % side,
                     ball("joint_hip_%s" % side, (hip_x, 0, z["z_hip"]),
                          BALL_R * 1.05, "joint")))
        segs.append(("shin_%s" % side,
                     ball("joint_knee_%s" % side, (hip_x, 0, z_knee),
                          BALL_R * 0.95, "joint")))

        segs.append(("thigh_%s" % side,
                     prism("seg_thigh_%s" % side,
                           (hip_x, 0, z["z_hip"] - g), (hip_x, 0, z_knee + g),
                           LIMB_W * 1.26, LIMB_W * 1.26,
                           LIMB_W * 1.06, LIMB_W * 1.06, "suit_lo")))
        # Trousers crop above the shoe and a white sock shows: the MJ read.
        z_crop = FOOT_H + SHIN_L * 0.26
        segs.append(("shin_%s" % side,
                     prism("seg_shin_%s" % side,
                           (hip_x, 0, z_knee - g), (hip_x, 0, z_crop),
                           LIMB_W * 1.12, LIMB_W * 1.16,
                           LIMB_W * 0.80, LIMB_W * 0.84, "suit_lo")))
        segs.append(("shin_%s" % side,
                     prism("seg_sock_%s" % side,
                           (hip_x, 0, z_crop), (hip_x, 0, FOOT_H),
                           LIMB_W * 0.86, LIMB_W * 0.86,
                           LIMB_W * 0.80, LIMB_W * 0.84, "sock")))

        # Shoe: a soled last, tapering and dropping toward the toe.
        segs.append(("foot_%s" % side,
                     prism("seg_shoe_%s" % side,
                           (hip_x, -FOOT_L * 0.22, FOOT_H * 0.62),
                           (hip_x, FOOT_L * 0.72, FOOT_H * 0.40),
                           LIMB_W * 1.02, FOOT_H * 1.15,
                           LIMB_W * 0.74, FOOT_H * 0.80, "shoe")))
        segs.append(("foot_%s" % side,
                     prism("seg_sole_%s" % side,
                           (hip_x, -FOOT_L * 0.24, 0.012),
                           (hip_x, FOOT_L * 0.74, 0.010),
                           LIMB_W * 1.08, 0.024,
                           LIMB_W * 0.80, 0.020, "shoe", bevel=0.004)))
    # P1_NO_CREASES=1 builds the same figure without the fold/seam family, so the
    # creases' contribution can be judged against its own control instead of
    # against a memory of the previous capture.
    segs.extend(build_backpack(z))
    if os.environ.get("P1_NO_CREASES") != "1":
        segs.extend(build_creases(z))
    else:
        log("creases: SKIPPED (P1_NO_CREASES=1) — this is the control")
    return segs


def build_backpack(z):
    """The small pack on the agent's back.

    Director, 2026-08-16: *"uma mochilinha nas costas, que vai ser de onde ele
    vai tirar o sobretudo/capuz e demais gadgets, e guardar o chapéu."*

    THIS IS NOT A NEW MECHANIC — it is the missing object in one that was already
    ratified. D53's costume flip describes the hat as *stowed "numa mochila"*,
    and that row records the stow as costing NOTHING to author: the hat is a
    `head` layer switched off, not stowed geometry. What was missing was the
    container the fiction refers to. Giving it a body changes no budget term:
    §4.3 already has `back_upper` carrying the hood and the overcoat (D37/D43),
    and §8 classes a rigid adornment on a socket as ADDITIVE, never
    multiplicative.

    SIZED TO STAY OUT OF THE WAY OF TWO THINGS. It stops below the shoulder-blade
    yoke so the back creases added earlier today still read — the back was a flat
    black shape until those landed and the pack must not undo it — and it is
    shallow enough (0.11 m) that it does not blow out the figure's silhouette in
    the side facings, where a deep pack would read as a hunch rather than as kit.
    """
    segs = []
    zc, zn = z["z_chest"], z["z_neck"]
    back = -CHEST_D * 0.53          ## just proud of the jacket's back face
    # Raised 0.04 m on the Director's call, 2026-08-16 ("um pouquinho mais pra
    # cima"). The ceiling is not taste: the shoulder-blade yoke sits at
    # zn - 0.115, and the pack must stay under it or it swallows the one crease
    # that breaks up the back's flat mass. z_top = zn - 0.12 lands just below it.
    z_top = zn - 0.12
    z_bot = zc - 0.02

    # The body of the pack. Slightly narrower at the bottom so it reads as a
    # flap-over satchel rather than as a box.
    segs.append(("chest", prism("seg_pack", (0, back - 0.055, z_bot),
                                (0, back - 0.050, z_top),
                                0.185, 0.082, 0.235, 0.112,
                                "suit", bevel=0.010)))
    # The flap's lower edge — the line that says "this opens".
    segs.append(("chest", prism("seg_pack_flap", (0, back - 0.112, z_top - 0.085),
                                (0, back - 0.112, z_top - 0.070),
                                0.225, 0.020, 0.225, 0.020,
                                "seam_lo", bevel=0.003)))
    # Shoulder straps, over the top of each shoulder and onto the chest. Two
    # narrow bars are the whole reason the pack reads as WORN instead of as a
    # block parked behind the figure.
    for sx in (1.0, -1.0):
        side = "L" if sx > 0 else "R"
        segs.append(("chest", prism("seg_pack_strap_%s" % side,
                                    (sx * 0.078, back - 0.030, z_top - 0.010),
                                    (sx * 0.070, CHEST_D * 0.52, zc + 0.11),
                                    0.030, 0.018, 0.026, 0.016,
                                    "seam_hi", bevel=0.003)))
    log("backpack: %d parts" % len(segs))
    return segs


def build_creases(z):
    """Folds and creases in the clothing — the near-black suit's ONLY source of
    volume, and now on the BACK as well as the front.

    Director, 2026-08-16: *"o vinco é bom, pode ser um pouco mais fina a linha.
    Precisa estar nas costas também para criar mais coerência."*

    WHY THE BACK MATTERS, and it is measured rather than assumed: diffing the
    baked frames showed the first crease set covering 9.9% of the figure in frame
    S and 0.7% in frame N — a 14x gap, because every crease was a front feature
    and N/E are the facings that show the agent's back. In half the room's
    perspectives he was a flat black shape. Back coverage is worth more here than
    any amount of extra contrast on the front.

    LINE WEIGHT: thinned from 0.020-0.026 to 0.014-0.018 on the Director's call.
    That is close to the floor — at 115.47 px per screen-metre, 0.014 m resolves
    to about 1.6 px, and anything below one pixel is authored, invisible, and
    still paid for in RAM.

    Each crease still works on two channels: as geometry it breaks the surface
    normal (captured by the normal bake, relit at runtime) and notches the
    silhouette; as an albedo edge it survives where the lighting is flat, which
    at a 0.02 albedo is most places.
    """
    segs = []
    zh, zc, zn = z["z_hip"], z["z_chest"], z["z_neck"]
    zs = z["z_shoulder"]

    # --- FRONT -------------------------------------------------------------
    # Lapel V — the strongest tailoring cue, and the one place a LIGHTER seam
    # belongs: a lapel folds outward, so it catches light.
    for sx in (1.0, -1.0):
        segs.append(("chest", prism("seg_lapel_%s" % ("L" if sx > 0 else "R"),
                                    (sx * 0.050, 0.112, zn - 0.045),
                                    (sx * 0.020, 0.107, zc + 0.13),
                                    0.018, 0.015, 0.015, 0.013,
                                    "seam_hi", bevel=0.003)))

    # The jacket's front opening, button down through the hem.
    segs.append(("spine", prism("seg_jacket_open", (0, 0.106, zc + 0.05),
                                (0, 0.112, zh + HIP_H * 0.45),
                                0.015, 0.013, 0.014, 0.012,
                                "seam_lo", bevel=0.003)))

    # Shade band under the jacket hem: where the jacket ends against the
    # trousers. Thinner than the first pass, which read as a belt.
    segs.append(("spine", prism("seg_hem_shade",
                                (0, 0.108, zh + HIP_H * 0.30 - 0.006),
                                (0, 0.108, zh + HIP_H * 0.30 + 0.008),
                                HIP_W * 1.20, 0.016, HIP_W * 1.20, 0.016,
                                "seam_lo", bevel=0.003)))

    # --- BACK --------------------------------------------------------------
    # Centre back seam, collar to hem. On a real jacket this is the line that
    # tells you it is tailored rather than draped.
    segs.append(("chest", prism("seg_back_seam_up", (0, -0.106, zn - 0.04),
                                (0, -0.104, zc + 0.02),
                                0.016, 0.014, 0.015, 0.013,
                                "seam_hi", bevel=0.003)))
    segs.append(("spine", prism("seg_back_seam_lo", (0, -0.102, zc + 0.02),
                                (0, -0.110, zh + HIP_H * 0.30),
                                0.015, 0.013, 0.014, 0.012,
                                "seam_hi", bevel=0.003)))

    # The yoke — the horizontal panel line across the shoulder blades. This is
    # what breaks the back's flat mass into two faces.
    segs.append(("chest", prism("seg_back_yoke",
                                (0, -0.104, zn - 0.115),
                                (0, -0.104, zn - 0.100),
                                SHOULDER_W * 0.86, 0.016,
                                SHOULDER_W * 0.86, 0.016,
                                "seam_lo", bevel=0.003)))

    # The vent — the slit at the bottom of the back of the jacket.
    segs.append(("spine", prism("seg_back_vent",
                                (0, -0.110, zh + HIP_H * 0.30),
                                (0, -0.108, zh + HIP_H * 0.72),
                                0.014, 0.014, 0.013, 0.013,
                                "seam_lo", bevel=0.003)))

    for side, sx in (("L", 1.0), ("R", -1.0)):
        hip_x = sx * HIP_W * 0.5
        z_knee = zh - THIGH_L

        # Trouser crease, front of the leg. Pressed fabric catches light.
        segs.append(("thigh_%s" % side,
                     prism("seg_crease_thigh_%s" % side,
                           (hip_x, 0.068, zh - 0.03), (hip_x, 0.058, z_knee + 0.02),
                           0.015, 0.013, 0.014, 0.012, "seam_hi", bevel=0.003)))
        segs.append(("shin_%s" % side,
                     prism("seg_crease_shin_%s" % side,
                           (hip_x, 0.062, z_knee - 0.02), (hip_x, 0.046, 0.20),
                           0.014, 0.012, 0.013, 0.011, "seam_hi", bevel=0.003)))

        # And the same seam down the BACK of the leg, which is what makes the
        # trouser read as a tube of cloth from every facing rather than from two.
        segs.append(("thigh_%s" % side,
                     prism("seg_seam_thigh_back_%s" % side,
                           (hip_x, -0.066, zh - 0.03), (hip_x, -0.056, z_knee + 0.02),
                           0.015, 0.013, 0.014, 0.012, "seam_hi", bevel=0.003)))
        segs.append(("shin_%s" % side,
                     prism("seg_seam_shin_back_%s" % side,
                           (hip_x, -0.060, z_knee - 0.02), (hip_x, -0.044, 0.20),
                           0.014, 0.012, 0.013, 0.011, "seam_hi", bevel=0.003)))

        # Knee break — fabric bunching above the knee.
        segs.append(("shin_%s" % side,
                     prism("seg_knee_fold_%s" % side,
                           (hip_x, 0.060, z_knee - 0.055),
                           (hip_x, 0.060, z_knee - 0.042),
                           LIMB_W * 1.06, 0.016, LIMB_W * 1.06, 0.016,
                           "seam_lo", bevel=0.003)))

        # Shoulder seam along the top of the sleeve, plus the cuff line — the
        # two seams that make a sleeve read as tailored rather than as a tube.
        x0 = sx * SHOULDER_W * 0.5
        x1 = x0 + sx * UPPERARM_L
        x2 = x1 + sx * FOREARM_L
        segs.append(("upperarm_%s" % side,
                     prism("seg_sleeve_seam_%s" % side,
                           (x0 + sx * 0.02, 0.0, zs + 0.064),
                           (x0 + sx * (UPPERARM_L - 0.02), 0.0, zs + 0.060),
                           0.016, 0.014, 0.015, 0.013, "seam_hi", bevel=0.003)))
        segs.append(("forearm_%s" % side,
                     prism("seg_cuff_%s" % side,
                           (x2 - sx * 0.045, 0.0, zs),
                           (x2 - sx * 0.030, 0.0, zs),
                           LIMB_W * 1.02, LIMB_W * 1.02,
                           LIMB_W * 1.02, LIMB_W * 1.02,
                           "seam_lo", bevel=0.003)))

    log("creases: %d fold/seam parts" % len(segs))
    return segs


def bind_rigid(arm, segs):
    for bone_name, ob in segs:
        vg = ob.vertex_groups.new(name=bone_name)
        vg.add(range(len(ob.data.vertices)), 1.0, "REPLACE")
        mod = ob.modifiers.new(name="Armature", type="ARMATURE")
        mod.object = arm
        ob.parent = arm
    log("bound %d parts rigidly" % len(segs))


def add_sockets(arm, z):
    """§4.3, unchanged in intent. The positions move with the T-pose because the
    hands are now out to the sides -- a socket that kept the mockup's coordinates
    would sit in mid-air, which is exactly the class of error D30 paid for when a
    copied constant came out 178 degrees wrong."""
    zs = z["z_shoulder"]
    hand_x = SHOULDER_W * 0.5 + UPPERARM_L + FOREARM_L + HAND_L * 0.5
    spec = [
        ("socket_hand_R", "hand_R", (-hand_x, 0.0, zs)),
        ("socket_hand_L", "hand_L", (hand_x, 0.0, zs)),
        ("socket_back_upper", "chest", (0.0, -CHEST_D * 0.55, z["z_chest"] + CHEST_H * 0.80)),
        ("socket_chest", "chest", (0.0, CHEST_D * 0.55, z["z_chest"] + CHEST_H * 0.60)),
        ("socket_shoulder_L", "shoulder_L", (SHOULDER_W * 0.5, 0.0, zs)),
        ("socket_shoulder_R", "shoulder_R", (-SHOULDER_W * 0.5, 0.0, zs)),
        ("socket_arm_L", "upperarm_L", (SHOULDER_W * 0.5 + UPPERARM_L * 0.62, 0.0, zs)),
    ]
    for name, bone_name, loc in spec:
        e = bpy.data.objects.new(name, None)
        e.empty_display_type = "ARROWS"
        e.empty_display_size = 0.05
        bpy.context.collection.objects.link(e)
        e.parent = arm
        e.parent_type = "BONE"
        e.parent_bone = bone_name
        e.matrix_world.translation = Vector(loc)
    log("sockets: %d" % len(spec))


def sanity_checks(arm, segs, z):
    """Loud-fail rather than exporting something quietly wrong (B6's spirit).
    The T-pose check is new and is the whole point of this pass: a rest pose that
    is only ALMOST a T is worse than an honest A-pose, because every retarget
    downstream will assume it is exact."""
    problems = []
    bones = {b.name for b in arm.data.bones}
    for bone_name, ob in segs:
        if bone_name not in bones:
            problems.append("part %s bound to missing bone %s" % (ob.name, bone_name))
        if not ob.data.vertices:
            problems.append("part %s has no geometry" % ob.name)

    world = [(ob.matrix_world @ v.co) for _, ob in segs for v in ob.data.vertices]
    zs = [p.z for p in world]
    lo, hi = min(zs), max(zs)
    height = hi - lo
    log("measured height: %.3f m (floor at z=%+.4f)" % (height, lo))
    if abs(lo) > 0.02:
        problems.append("figure does not stand on z=0 (floor at %.3f)" % lo)
    if not (HEIGHT * 0.95 <= height <= HEIGHT * 1.15):
        problems.append("height %.3f m outside the expected band" % height)

    # T-POSE: every arm bone must be horizontal, and the arms must be level with
    # each other. Measured off the armature, not assumed from the code above.
    for side in ("L", "R"):
        for part in ("upperarm", "forearm", "hand"):
            b = arm.data.bones["%s_%s" % (part, side)]
            drop = abs(b.tail_local.z - b.head_local.z)
            if drop > 1e-4:
                problems.append("%s_%s is not horizontal (dz=%.4f)" % (part, side, drop))
    zl = arm.data.bones["hand_L"].tail_local.z
    zr = arm.data.bones["hand_R"].tail_local.z
    if abs(zl - zr) > 1e-4:
        problems.append("arms not level (L %.4f vs R %.4f)" % (zl, zr))

    span = max(p.x for p in world) - min(p.x for p in world)
    log("arm span: %.3f m (height %.3f m, ratio %.3f)" % (span, height, span / height))

    if problems:
        for p in problems:
            print("[P1-MODEL][FAIL] %s" % p)
        sys.exit(1)
    log("sanity checks passed — rest pose is an exact T")
    return height, span


def main():
    reset_scene()
    arm, z = build_armature()
    segs = build_segments(z)
    bind_rigid(arm, segs)
    add_sockets(arm, z)
    height, span = sanity_checks(arm, segs, z)

    tris = sum(len(ob.data.polygons) for _, ob in segs)
    os.makedirs(OUT_DIR, exist_ok=True)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=OUT_GLB, export_format="GLB",
                              export_apply=True, export_skins=True,
                              export_yup=True)
    bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)
    log("wrote %s" % OUT_GLB)
    log("DONE — %d bones, %d parts, %d faces, %.3f m tall, span %.3f m"
        % (len(arm.data.bones), len(segs), tris, height, span))


if __name__ == "__main__":
    main()
