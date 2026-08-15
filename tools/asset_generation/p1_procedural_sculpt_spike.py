"""CHARACTER_MASTER_PLAN Part 8 / D49 — CAN THE SHOWCASE MODEL BE SCULPTED PROCEDURALLY?

THE DIRECTOR'S QUESTION, 2026-08-15: "D49 a gente não consegue esculpir
proceduralmente?" This spike answers it with a render rather than an opinion, by
building the SAME figure at the highest fidelity a script can reach and putting
it beside the bevelled-prism version.

WHAT ACTUALLY SEPARATES THE TWO, mechanically. p1_agent_model.py builds each part
as an 8-vertex tapered box with a bevel. That gives four flat sides and a hard
outline no matter how the numbers are tuned -- the form is capped by the topology,
not by the parameters. This builds each part as a LOFTED CONTROL CAGE: several
cross sections along the part's axis, each a superellipse with its own width,
depth and squareness, joined into a tube and then run through a SUBDIVISION
SURFACE. Subdivision is the lever: a coarse cage becomes a smooth limit surface,
so the shape is set by where the sections sit rather than by how many polygons
were typed. That is the same construction a human modeller uses before they ever
open sculpt mode, and it is fully scriptable.

WHAT A SCRIPT STILL CANNOT DO, stated plainly so this is not oversold. Sculpting
is an iterative visual judgement loop -- push, look, push again -- and a script
cannot look. Everything below is a shape someone REASONED about, not one anyone
FELT. Anatomy that reads as alive, weight and asymmetry, the accidents that make
a figure specific rather than generic: those are the parts of D49's dedicated
stage that this cannot replace. The honest framing is therefore not "procedural
versus sculpted" but WHICH PARTS need a human eye in the loop, and this spike
exists to show where that line actually falls.

WHAT IT DELIBERATELY REUSES. The armature, bone names, sockets, scale and sanity
checks are imported from p1_agent_model.py unchanged -- only the geometry is
replaced. That is D48's own principle demonstrated rather than asserted: the
skeleton survives, the art is what gets replaced.

Run:
  /Applications/Blender.app/Contents/MacOS/Blender --background \
    --python tools/asset_generation/p1_procedural_sculpt_spike.py
"""

import math
import os
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import p1_agent_model as base   # noqa: E402  (needs the path above)

OUT_DIR = os.path.join(base.REPO_ROOT, "ASSETS", "ISOMETRIC", "source_assets",
                       "imported_models", "agent")
OUT_GLB = os.path.join(OUT_DIR, "agent_hifi.glb")
OUT_BLEND = os.path.join(OUT_DIR, "agent_hifi.blend")

RADIAL = 12          # cage resolution around the axis
SUBSURF = 2          # limit surface levels


def log(m):
    print("[P1-SCULPT] %s" % m)


def superellipse(angle, hw, hd, squareness):
    """Cross-section point. squareness 2 = ellipse, 4 = squircle, 8 = nearly a
    rounded box. A torso is not a tube and a limb is not a slab; letting each
    section choose its own squareness is most of what makes these read as forms
    rather than as pipes."""
    ca, sa = math.cos(angle), math.sin(angle)
    e = 2.0 / squareness
    x = math.copysign(abs(ca) ** e, ca) * hw
    y = math.copysign(abs(sa) ** e, sa) * hd
    return x, y


def loft(name, p0, p1, profile, mat_key, radial=RADIAL, levels=SUBSURF):
    """`profile` is a list of (t, half_w, half_d, squareness) along p0->p1.

    Tapering the first and last sections inward is not cosmetic: subdivision
    pulls an open flat cap into a dome, so a cage that ends bluntly loses its
    length to rounding. Ending narrow keeps the silhouette where it was authored.
    """
    p0, p1 = Vector(p0), Vector(p1)
    e0, e1 = base.frame_for(p1 - p0)

    verts, faces = [], []
    for (t, hw, hd, sq) in profile:
        c = p0.lerp(p1, t)
        for i in range(radial):
            a = 2.0 * math.pi * i / radial
            x, y = superellipse(a, hw, hd, sq)
            verts.append(tuple(c + e0 * x + e1 * y))

    rings = len(profile)
    for s in range(rings - 1):
        for i in range(radial):
            j = (i + 1) % radial
            faces.append((s * radial + i, s * radial + j,
                          (s + 1) * radial + j, (s + 1) * radial + i))
    faces.append(tuple(range(radial - 1, -1, -1)))
    faces.append(tuple(range((rings - 1) * radial, rings * radial)))

    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    me.validate()
    me.update()
    ob = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(ob)
    ob.data.materials.append(base.material(mat_key))

    bpy.context.view_layer.objects.active = ob
    mod = ob.modifiers.new("subsurf", "SUBSURF")
    mod.levels = levels
    mod.render_levels = levels
    bpy.ops.object.modifier_apply(modifier="subsurf")
    bpy.ops.object.shade_smooth()
    return ob


def limb_profile(w0, d0, w1, d1, sq=3.0, mid=1.06):
    """Ends drawn in, a slight swell at mid-length. A limb that is a pure linear
    taper reads as a cone; the swell is what makes it read as a limb."""
    return [(0.00, w0 * 0.62, d0 * 0.62, sq),
            (0.10, w0 * 0.99, d0 * 0.99, sq),
            (0.50, (w0 + w1) * 0.5 * mid, (d0 + d1) * 0.5 * mid, sq),
            (0.90, w1 * 0.99, d1 * 0.99, sq),
            (1.00, w1 * 0.62, d1 * 0.62, sq)]


def build_segments(z):
    """Same parts, same bones, same measurements — different topology."""
    g = base.JOINT_GAP
    L = base.LIMB_W
    HIP_W, CHEST_D, SHOULDER_W = base.HIP_W, base.CHEST_D, base.SHOULDER_W
    zh, zc, zn, zhd, zs = (z["z_hip"], z["z_chest"], z["z_neck"],
                           z["z_head"], z["z_shoulder"])
    segs = []

    # --- Torso. Three bones, so three meshes; but each is now a shaped cage.
    segs.append(("hips", loft("seg_hips", (0, 0, zh - 0.03), (0, 0, zh + base.HIP_H - g),
                              [(0.00, HIP_W * 0.40, CHEST_D * 0.34, 4.0),
                               (0.30, HIP_W * 0.51, CHEST_D * 0.46, 4.2),
                               (1.00, HIP_W * 0.46, CHEST_D * 0.42, 4.0)], "suit")))
    segs.append(("spine", loft("seg_abdomen", (0, 0, zh + base.HIP_H), (0, 0, zc - g),
                               [(0.00, HIP_W * 0.45, CHEST_D * 0.41, 4.0),
                                (0.45, HIP_W * 0.40, CHEST_D * 0.37, 4.4),   # waist
                                (1.00, HIP_W * 0.48, CHEST_D * 0.44, 4.2)], "suit")))
    # The chest carries the suit's whole line: ribcage out of the waist, then a
    # shoulder shelf wider and flatter than the ribs.
    segs.append(("chest", loft("seg_chest", (0, 0, zc), (0, 0, zn - g),
                               [(0.00, HIP_W * 0.47, CHEST_D * 0.43, 4.2),
                                (0.35, SHOULDER_W * 0.42, CHEST_D * 0.50, 4.0),
                                (0.72, SHOULDER_W * 0.49, CHEST_D * 0.50, 4.6),
                                (0.94, SHOULDER_W * 0.52, CHEST_D * 0.46, 5.2),
                                (1.00, SHOULDER_W * 0.46, CHEST_D * 0.40, 5.0)], "suit")))
    # HARD SURFACE. A jacket hem is a cut edge; subdivided it became a bulb and
    # the suit read went with it.
    segs.append(("spine", base.prism("seg_jacket_hem",
                                     (0, 0, zh + base.HIP_H * 0.34),
                                     (0, 0, zh + base.HIP_H + base.ABDOMEN_H * 0.48),
                                     HIP_W * 1.18, CHEST_D * 1.08,
                                     HIP_W * 0.88, CHEST_D * 0.82, "suit")))
    segs.append(("chest", loft("seg_shirt", (0, CHEST_D * 0.30, zn - 0.175),
                               (0, CHEST_D * 0.34, zn - g),
                               [(0.00, 0.030, 0.055, 3.0),
                                (0.55, 0.055, 0.062, 3.0),
                                (1.00, 0.085, 0.066, 3.2)], "shirt")))
    segs.append(("chest", base.prism("seg_collar", (0, 0, zn - 0.040),
                                     (0, 0, zn + 0.024),
                                     0.152, 0.132, 0.122, 0.112, "shirt", bevel=0.005)))
    segs.append(("neck", loft("seg_neck", (0, 0, zn - 0.02), (0, 0, zhd + 0.02),
                              [(0.00, 0.052, 0.050, 2.6),
                               (1.00, 0.046, 0.046, 2.6)], "skin")))

    # Head: cranium, brow, cheek, jaw, chin. Still no face — but a SHAPE.
    segs.append(("head", loft("seg_head", (0, 0, zhd), (0, 0, zhd + base.HEAD_H - g),
                              [(0.00, 0.052, 0.058, 3.0),   # under the jaw
                               (0.22, 0.066, 0.079, 3.0),   # jaw
                               (0.48, 0.074, 0.090, 2.8),   # cheek
                               (0.72, 0.077, 0.088, 2.8),   # brow
                               (0.92, 0.072, 0.078, 2.6),
                               (1.00, 0.050, 0.055, 2.4)], "skin")))

    # Fedora — hard-surface, so the prism/disc construction already suits it.
    brim_z = zhd + base.HEAD_H * 0.62
    segs.append(("head", base.disc("seg_fedora_brim", (0, 0, brim_z),
                                   base.FEDORA_BRIM_R, 0.018, "hat", top_scale=0.90)))
    segs.append(("head", base.disc("seg_fedora_curl", (0, 0, brim_z + 0.016),
                                   base.FEDORA_BRIM_R * 0.99, 0.014, "hat",
                                   top_scale=0.86)))
    segs.append(("head", base.disc("seg_fedora_band", (0, 0, brim_z + 0.034),
                                   base.FEDORA_CROWN_R * 1.06, 0.030, "band")))
    segs.append(("head", base.disc("seg_fedora_crown",
                                   (0, 0, brim_z + 0.034 + base.FEDORA_CROWN_H * 0.5),
                                   base.FEDORA_CROWN_R, base.FEDORA_CROWN_H, "hat",
                                   top_scale=0.82)))

    for side, sx in (("L", 1.0), ("R", -1.0)):
        sh_x = sx * SHOULDER_W * 0.5
        x1 = sh_x + sx * base.UPPERARM_L
        x2 = x1 + sx * base.FOREARM_L
        x3 = x2 + sx * base.HAND_L
        hip_x = sx * HIP_W * 0.5
        z_knee = z["z_hip"] - base.THIGH_L
        z_crop = base.FOOT_H + base.SHIN_L * 0.26

        segs.append(("upperarm_%s" % side,
                     base.ball("joint_shoulder_%s" % side, (sh_x, 0, zs),
                               base.BALL_R * 1.10, "joint")))
        segs.append(("forearm_%s" % side,
                     base.ball("joint_elbow_%s" % side, (x1, 0, zs),
                               base.BALL_R * 0.88, "joint")))
        segs.append(("thigh_%s" % side,
                     base.ball("joint_hip_%s" % side, (hip_x, 0, z["z_hip"]),
                               base.BALL_R * 1.05, "joint")))
        segs.append(("shin_%s" % side,
                     base.ball("joint_knee_%s" % side, (hip_x, 0, z_knee),
                               base.BALL_R * 0.95, "joint")))

        segs.append(("upperarm_%s" % side,
                     loft("seg_upperarm_%s" % side, (sh_x + sx * g, 0, zs),
                          (x1 - sx * g, 0, zs),
                          limb_profile(L * 0.54, L * 0.54, L * 0.45, L * 0.46), "suit")))
        segs.append(("forearm_%s" % side,
                     loft("seg_forearm_%s" % side, (x1 + sx * g, 0, zs),
                          (x2 - sx * g, 0, zs),
                          limb_profile(L * 0.45, L * 0.46, L * 0.34, L * 0.38,
                                       mid=1.10), "suit")))
        segs.append(("hand_%s" % side,
                     loft("seg_hand_%s" % side, (x2 + sx * g, 0, zs), (x3, 0, zs),
                          [(0.00, L * 0.34, L * 0.24, 3.4),
                           (0.35, L * 0.42, L * 0.27, 3.6),
                           (0.80, L * 0.38, L * 0.24, 3.4),
                           (1.00, L * 0.22, L * 0.16, 3.0)], "skin")))

        segs.append(("thigh_%s" % side,
                     loft("seg_thigh_%s" % side, (hip_x, 0, z["z_hip"] - g),
                          (hip_x, 0, z_knee + g),
                          limb_profile(L * 0.66, L * 0.66, L * 0.53, L * 0.55,
                                       sq=3.4, mid=1.05), "suit_lo")))
        segs.append(("shin_%s" % side,
                     loft("seg_shin_%s" % side, (hip_x, 0, z_knee - g), (hip_x, 0, z_crop),
                          [(0.00, L * 0.34, L * 0.34, 3.2),
                           (0.12, L * 0.55, L * 0.57, 3.2),
                           (0.34, L * 0.58, L * 0.62, 3.0),   # calf
                           (0.80, L * 0.44, L * 0.46, 3.0),
                           (1.00, L * 0.39, L * 0.42, 3.0)], "suit_lo")))
        # HARD SURFACE from here down: the sock's cuff and the shoe's sole are
        # both cut edges, and both dissolved under uniform subdivision.
        segs.append(("shin_%s" % side,
                     base.prism("seg_sock_%s" % side, (hip_x, 0, z_crop),
                                (hip_x, 0, base.FOOT_H),
                                L * 0.86, L * 0.86, L * 0.80, L * 0.84, "sock")))
        segs.append(("foot_%s" % side,
                     base.prism("seg_shoe_%s" % side,
                                (hip_x, -base.FOOT_L * 0.22, base.FOOT_H * 0.62),
                                (hip_x, base.FOOT_L * 0.72, base.FOOT_H * 0.40),
                                L * 1.02, base.FOOT_H * 1.15,
                                L * 0.74, base.FOOT_H * 0.80, "shoe")))
        segs.append(("foot_%s" % side,
                     base.prism("seg_sole_%s" % side,
                                (hip_x, -base.FOOT_L * 0.24, 0.012),
                                (hip_x, base.FOOT_L * 0.74, 0.010),
                                L * 1.08, 0.024, L * 0.80, 0.020, "shoe",
                                bevel=0.004)))
    return segs


def main():
    base.reset_scene()
    arm, z = base.build_armature()
    segs = build_segments(z)
    base.bind_rigid(arm, segs)
    base.add_sockets(arm, z)
    height, span = base.sanity_checks(arm, segs, z)

    faces = sum(len(ob.data.polygons) for _, ob in segs)
    os.makedirs(OUT_DIR, exist_ok=True)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=OUT_GLB, export_format="GLB",
                              export_apply=True, export_skins=True, export_yup=True)
    bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)
    log("DONE — %d bones, %d parts, %d faces, %.3f m tall, span %.3f m"
        % (len(arm.data.bones), len(segs), faces, height, span))
    log("prism version was 2432 faces; subdivision buys form, and costs polygons")


if __name__ == "__main__":
    main()
