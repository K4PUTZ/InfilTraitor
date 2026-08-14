"""CHARACTER_MASTER_PLAN Part 0 / S2 — generates the rigged action-figure mockup.

WHAT THIS IS FOR. S2 asks a game-feel question (CHARACTER_MASTER_PLAN D45): how
many intermediate frames does a turn need before it reads as fluid, and where
does it start feeling sluggish in a turn-based game? That cannot be answered by
reasoning, and it was blocked because the project had no rigged humanoid at all
-- actor_part0_spike's synthetic figure is unrigged voxel blocks, and every mesh
in imported_models/ is a weapon or a grenade.

WHY IT CAN BE SCRIPTED AT ALL. Because the Director chose the action-figure look
(D35): an action figure is RIGID SEGMENTS ON VISIBLE JOINTS. Every segment binds
100% to exactly one bone, so there is no weight painting, no falloff, and no
skinning artifacts to hand-fix -- the thing that normally makes a character
un-scriptable is absent by art direction. The style and the automation agree,
the same way D35 records that the style and the layering architecture agree.

WHAT IT IS NOT. Not the character. Proportions are a first pass, the silhouette
is blocky, and none of it is art-directed. It exists to answer one question
about motion, and CHARACTER_MASTER_PLAN §6 S2 says so explicitly: a mockup
judged for fluidity, not for beauty.

AUTHORED IN REAL-WORLD UNITS. The figure is built 1.80 Blender units tall, one
unit = one metre, rather than at some pre-guessed sprite scale. §4.7 forbids
inheriting the placeholder's scale (agent.gd's 61 px silhouette is 39% of a
158 px storey -- a person about one metre tall) and requires deriving it. Real
units keep that derivation possible downstream instead of baking a guess in.

SOCKETS. Every attachment point from §4.3 is exported as an empty parented to
its bone, so the layer system (D34/D40) has a real anchor per pose and yaw
rather than a guessed offset. They carry nothing yet; they exist so Part 4 has
something to bind to.

Run:
  /Applications/Blender.app/Contents/MacOS/Blender --background \
    --python tools/asset_generation/s2_mockup_character.py
"""

import math
import os
import sys

import bpy
from mathutils import Vector

# --- Output -----------------------------------------------------------------
REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT_DIR = os.path.join(
    REPO_ROOT, "ASSETS", "ISOMETRIC", "source_assets", "imported_models", "s2_mockup"
)
OUT_GLB = os.path.join(OUT_DIR, "s2_mockup_character.glb")
OUT_BLEND = os.path.join(OUT_DIR, "s2_mockup_character.blend")

# --- Proportions -------------------------------------------------------------
# Real-world metres. A 1.80 m figure in roughly heroic 7.5-head proportion; the
# fedora is here from the first pass on purpose, because it is the single
# strongest silhouette cue in the gangster/Michael Jackson direction (D35) and a
# fluidity test on a bare-headed blob would be judging a different silhouette
# than the one that ships.
HEIGHT = 1.80
HEAD_H = HEIGHT / 7.5          # 0.24
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

# Visible gap at every joint -- this IS the action-figure read (D35), not a
# tolerance. Without it the segments merge into one blob and the whole reason
# rigid binding is legitimate disappears.
JOINT_GAP = 0.018

FEDORA_BRIM_R = 0.26
FEDORA_BRIM_H = 0.02
FEDORA_CROWN_R = 0.135
FEDORA_CROWN_H = 0.13


def log(msg):
    print("[S2-MOCKUP] %s" % msg)


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def add_box(name, size, center):
    """Axis-aligned box. size/center are (x, y, z) in metres."""
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=center)
    ob = bpy.context.active_object
    ob.name = name
    ob.scale = Vector((size[0], size[1], size[2]))
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return ob


def add_cylinder(name, radius, depth, center):
    bpy.ops.mesh.primitive_cylinder_add(radius=radius, depth=depth,
                                        vertices=12, location=center)
    ob = bpy.context.active_object
    ob.name = name
    return ob


# --- Skeleton ----------------------------------------------------------------
# The ~20-bone set CHARACTER_MASTER_PLAN §4.2 proposes. Named so a retarget onto
# a second archetype (D32: ONE skeleton, two bodies) is a rename-free operation.
def build_armature():
    arm_data = bpy.data.armatures.new("AgentRig")
    arm = bpy.data.objects.new("AgentRig", arm_data)
    bpy.context.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm_data.edit_bones

    z_hip = FOOT_H + SHIN_L + THIGH_L          # 0.92
    z_chest = z_hip + HIP_H + ABDOMEN_H        # 1.21
    z_neck = z_chest + CHEST_H                 # 1.55
    z_head = z_neck + NECK_H                   # 1.60

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
        bone("shoulder_%s" % side, (sx * 0.05, 0, z_neck - 0.03),
             (sh_x, 0, z_neck - 0.05), "chest")
        bone("upperarm_%s" % side, (sh_x, 0, z_neck - 0.05),
             (sh_x, 0, z_neck - 0.05 - UPPERARM_L), "shoulder_%s" % side, True)
        bone("forearm_%s" % side, (sh_x, 0, z_neck - 0.05 - UPPERARM_L),
             (sh_x, 0, z_neck - 0.05 - UPPERARM_L - FOREARM_L),
             "upperarm_%s" % side, True)
        bone("hand_%s" % side,
             (sh_x, 0, z_neck - 0.05 - UPPERARM_L - FOREARM_L),
             (sh_x, 0, z_neck - 0.05 - UPPERARM_L - FOREARM_L - HAND_L),
             "forearm_%s" % side, True)

        hip_x = sx * HIP_W * 0.5
        bone("thigh_%s" % side, (hip_x, 0, z_hip), (hip_x, 0, z_hip - THIGH_L), "hips")
        bone("shin_%s" % side, (hip_x, 0, z_hip - THIGH_L),
             (hip_x, 0, FOOT_H), "thigh_%s" % side, True)
        bone("foot_%s" % side, (hip_x, 0, FOOT_H),
             (hip_x, FOOT_L * 0.6, 0.0), "shin_%s" % side, True)

    bpy.ops.object.mode_set(mode="OBJECT")
    log("armature: %d bones" % len(arm_data.bones))
    return arm, dict(z_hip=z_hip, z_chest=z_chest, z_neck=z_neck, z_head=z_head)


# --- Segments ----------------------------------------------------------------
def build_segments(z):
    """One mesh per bone. Rigid by construction -- see the module docstring."""
    g = JOINT_GAP
    segs = []

    segs.append(("hips", add_box("seg_hips", (HIP_W, CHEST_D * 0.9, HIP_H - g),
                                 (0, 0, z["z_hip"] + HIP_H / 2))))
    segs.append(("spine", add_box("seg_abdomen", (HIP_W * 0.92, CHEST_D * 0.85, ABDOMEN_H - g),
                                  (0, 0, z["z_hip"] + HIP_H + ABDOMEN_H / 2))))
    # Chest tapers up from the waist -- the suited gangster read starts here.
    segs.append(("chest", add_box("seg_chest", (SHOULDER_W * 0.86, CHEST_D, CHEST_H - g),
                                  (0, 0, z["z_chest"] + CHEST_H / 2))))
    segs.append(("neck", add_box("seg_neck", (0.09, 0.09, NECK_H),
                                 (0, 0, z["z_neck"] + NECK_H / 2))))
    segs.append(("head", add_box("seg_head", (0.15, 0.17, HEAD_H - g),
                                 (0, 0, z["z_head"] + HEAD_H / 2))))

    # Fedora: brim + crown, both bound to the head bone so it turns with it.
    brim = add_cylinder("seg_fedora_brim", FEDORA_BRIM_R, FEDORA_BRIM_H,
                        (0, 0, z["z_head"] + HEAD_H - 0.01))
    segs.append(("head", brim))
    crown = add_cylinder("seg_fedora_crown", FEDORA_CROWN_R, FEDORA_CROWN_H,
                         (0, 0, z["z_head"] + HEAD_H - 0.01 + FEDORA_CROWN_H / 2))
    segs.append(("head", crown))

    for side, sx in (("L", 1.0), ("R", -1.0)):
        sh_x = sx * SHOULDER_W * 0.5
        top = z["z_neck"] - 0.05
        segs.append(("upperarm_%s" % side,
                     add_box("seg_upperarm_%s" % side, (LIMB_W, LIMB_W, UPPERARM_L - g),
                             (sh_x, 0, top - UPPERARM_L / 2))))
        segs.append(("forearm_%s" % side,
                     add_box("seg_forearm_%s" % side,
                             (LIMB_W * 0.88, LIMB_W * 0.88, FOREARM_L - g),
                             (sh_x, 0, top - UPPERARM_L - FOREARM_L / 2))))
        segs.append(("hand_%s" % side,
                     add_box("seg_hand_%s" % side,
                             (LIMB_W * 0.85, LIMB_W * 0.6, HAND_L - g),
                             (sh_x, 0, top - UPPERARM_L - FOREARM_L - HAND_L / 2))))

        hip_x = sx * HIP_W * 0.5
        segs.append(("thigh_%s" % side,
                     add_box("seg_thigh_%s" % side, (LIMB_W * 1.2, LIMB_W * 1.2, THIGH_L - g),
                             (hip_x, 0, z["z_hip"] - THIGH_L / 2))))
        segs.append(("shin_%s" % side,
                     add_box("seg_shin_%s" % side, (LIMB_W * 1.05, LIMB_W * 1.05, SHIN_L - g),
                             (hip_x, 0, FOOT_H + (z["z_hip"] - THIGH_L - FOOT_H) / 2))))
        segs.append(("foot_%s" % side,
                     add_box("seg_foot_%s" % side, (LIMB_W * 1.1, FOOT_L, FOOT_H),
                             (hip_x, FOOT_L * 0.22, FOOT_H / 2))))
    return segs


def bind_rigid(arm, segs):
    """Each segment 100% to one bone. No weight painting: an action figure's
    parts do not deform, so a single full-weight vertex group is not an
    approximation of skinning -- it is exactly right."""
    for bone_name, ob in segs:
        vg = ob.vertex_groups.new(name=bone_name)
        vg.add(range(len(ob.data.vertices)), 1.0, "REPLACE")
        mod = ob.modifiers.new(name="Armature", type="ARMATURE")
        mod.object = arm
        ob.parent = arm
    log("bound %d segments rigidly" % len(segs))


def add_sockets(arm, z):
    """CHARACTER_MASTER_PLAN §4.3. Empties parented to bones, exported with the
    model so Part 4's layer compositor binds to a real anchor per pose+yaw."""
    top = z["z_neck"] - 0.05
    hand_z = top - UPPERARM_L - FOREARM_L - HAND_L
    spec = [
        ("socket_hand_R", "hand_R", (-SHOULDER_W * 0.5, 0.06, hand_z)),
        ("socket_hand_L", "hand_L", (SHOULDER_W * 0.5, 0.06, hand_z)),
        ("socket_back_upper", "chest", (0.0, -CHEST_D * 0.55, z["z_chest"] + CHEST_H * 0.8)),
        ("socket_chest", "chest", (0.0, CHEST_D * 0.55, z["z_chest"] + CHEST_H * 0.6)),
        ("socket_shoulder_L", "shoulder_L", (SHOULDER_W * 0.5, 0.0, z["z_neck"] - 0.05)),
        ("socket_shoulder_R", "shoulder_R", (-SHOULDER_W * 0.5, 0.0, z["z_neck"] - 0.05)),
        ("socket_arm_L", "upperarm_L", (SHOULDER_W * 0.5, 0.0, top - UPPERARM_L * 0.55)),
    ]
    for name, bone_name, loc in spec:
        e = bpy.data.objects.new(name, None)
        e.empty_display_type = "ARROWS"
        e.empty_display_size = 0.05
        e.location = loc
        bpy.context.collection.objects.link(e)
        e.parent = arm
        e.parent_type = "BONE"
        e.parent_bone = bone_name
        e.matrix_world.translation = Vector(loc)
    log("sockets: %d" % len(spec))


def sanity_checks(arm, segs):
    """Loud-fail rather than exporting something quietly wrong (B6's spirit)."""
    problems = []
    bones = {b.name for b in arm.data.bones}
    for bone_name, ob in segs:
        if bone_name not in bones:
            problems.append("segment %s bound to missing bone %s" % (ob.name, bone_name))
        if not ob.data.vertices:
            problems.append("segment %s has no geometry" % ob.name)

    zs = [(ob.matrix_world @ v.co).z for _, ob in segs for v in ob.data.vertices]
    lo, hi = min(zs), max(zs)
    height = hi - lo
    log("measured height: %.3f m (floor at z=%.3f)" % (height, lo))
    if abs(lo) > 0.02:
        problems.append("figure does not stand on z=0 (floor at %.3f)" % lo)
    # The fedora legitimately adds above HEIGHT; the check is that we are in the
    # right neighbourhood, not that a hat is forbidden.
    if not (HEIGHT * 0.95 <= height <= HEIGHT * 1.15):
        problems.append("height %.3f m outside the expected band" % height)

    if problems:
        for p in problems:
            print("[S2-MOCKUP][FAIL] %s" % p)
        sys.exit(1)
    log("sanity checks passed")
    return height


def main():
    reset_scene()
    arm, z = build_armature()
    segs = build_segments(z)
    bind_rigid(arm, segs)
    add_sockets(arm, z)
    height = sanity_checks(arm, segs)

    os.makedirs(OUT_DIR, exist_ok=True)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(
        filepath=OUT_GLB,
        export_format="GLB",
        export_apply=True,
        export_skins=True,
        export_yup=True,
    )
    bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)
    log("wrote %s" % OUT_GLB)
    log("wrote %s" % OUT_BLEND)
    log("DONE — %d bones, %d segments, %.3f m tall" %
        (len(arm.data.bones), len(segs), height))


if __name__ == "__main__":
    main()
