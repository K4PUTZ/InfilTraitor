# tripo_anim_bank.py — MOVEMENT MV-1: the ANIMATION BANK. Every clip of every Tripo GLB listed in bank_sources.json, taken out of the
# character file it came in and kept per FIGURE (MOVEMENT v1.2, Director 2026-10-29: "vamos ter que guardar elas em pares"):
#   ASSETS/ANIMATIONS/bank/<figure>/<id>.glb   the source's Mixamo skeleton with that one action
#   ASSETS/ANIMATIONS/bank/bank.json           the catalogue: one row per clip id, one entry per figure, the pairs' gaps flagged
# What a clip keeps (MOVEMENT §1.3, measured 2026-10-27): every joint's ROTATION, and the Hips' translation DIVIDED BY THE SOURCE'S HIP
# HEIGHT (a player multiplies it back by its own); Tripo's location keys on the other 64 joints and every scale key are dropped (they
# carry the source figure's bone lengths). A row: source file and original name, frames, fps, seconds, the Hips' horizontal travel per
# second and height range (in hip heights), whether it loops (first and last pose within LOOP_DEG on every joint).
# The same clip from two files of one figure is kept once when every rotation matches within DUP_DEG at every frame, else as <id>_b.
# Env: BANK_SOURCES (default: bank_sources.json beside this file), BANK_OUT (default ASSETS/ANIMATIONS/bank).
# Usage (from the repo root): blender -b -P tools/asset_generation/tripo/tripo_anim_bank.py
import json, math, os, re, sys, unicodedata
import bpy
from mathutils import Quaternion

TAG = "tripo_anim_bank"
HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.environ.get("BANK_SOURCES", os.path.join(HERE, "bank_sources.json"))
OUT = os.environ.get("BANK_OUT", "ASSETS/ANIMATIONS/bank")
LOOP_DEG, DUP_DEG = 12.0, 2.0
P = "mixamorig:"


def fail(msg):
    print(f"[{TAG}] ERROR: {msg}"); sys.exit(1)


def slug(name):
    """a clip id: the name without Blender's .001 copies, ASCII, lower case, words joined by _, at most 48 characters"""
    n = re.sub(r"\.\d{3}$", "", name)
    n = unicodedata.normalize("NFKD", n).encode("ascii", "ignore").decode().lower()
    return re.sub(r"[^a-z0-9]+", "_", n).strip("_")[:48].rstrip("_") or "clip"


def channels(act):
    """(container, fcurve) pairs of an action, legacy or slotted (Blender 4.4+)"""
    out = []
    if getattr(act, "layers", None):
        for layer in act.layers:
            for strip in layer.strips:
                for cb in strip.channelbags:
                    out += [(cb.fcurves, fc) for fc in cb.fcurves]
    elif hasattr(act, "fcurves"):
        out = [(act.fcurves, fc) for fc in act.fcurves]
    return out


def bind(arm, act):
    arm.animation_data.action = act
    if getattr(arm.animation_data, "action_slot", 1) is None and len(getattr(act, "slots", [])):
        arm.animation_data.action_slot = act.slots[0]


def sample(arm, act, f0, f1):
    """per frame: {bone: rotation quaternion} and the Hips head in world space"""
    bind(arm, act); sc = bpy.context.scene; rots, hips = [], []
    for f in range(f0, f1 + 1):
        sc.frame_set(f)
        rots.append({b.name: b.rotation_quaternion.copy() if b.rotation_mode == 'QUATERNION' else b.rotation_euler.to_quaternion()
                     for b in arm.pose.bones})
        hips.append((arm.matrix_world @ arm.pose.bones[P + "Hips"].head).copy())
    return rots, hips


def max_deg(ra, rb):
    return max(math.degrees(ra[n].rotation_difference(rb[n]).angle) for n in ra if n in rb)


def main():
    if not os.path.exists(SRC):
        fail(f"no sources list at {SRC}")
    sources = json.load(open(SRC))["sources"]
    os.makedirs(OUT, exist_ok=True)
    cat, kept = {}, {}                                   # kept[(figure, id)] = rotations, to tell a duplicate from a variant
    for s in sources:
        path, fig = s["path"], s["figure"]
        if not os.path.exists(path):
            fail(f"{path} (in {SRC}) does not exist")
        bpy.ops.wm.read_factory_settings(use_empty=True); bpy.ops.import_scene.gltf(filepath=path)
        arms = [o for o in bpy.data.objects if o.type == 'ARMATURE']
        if len(arms) != 1 or P + "Hips" not in arms[0].data.bones:
            fail(f"{path}: expected one Mixamo armature, found {len(arms)}")
        arm = arms[0]
        for o in [o for o in bpy.data.objects if o.type != 'ARMATURE']:
            bpy.data.objects.remove(o)
        if arm.animation_data is None:
            arm.animation_data_create()
        for t in arm.animation_data.nla_tracks:
            t.mute = True
        arm.data.pose_position = 'REST'; bpy.context.view_layer.update()
        hip_h = (arm.matrix_world @ arm.data.bones[P + "Hips"].head_local).z
        arm.data.pose_position = 'POSE'; fps = bpy.context.scene.render.fps
        acts = list(bpy.data.actions); n_new = n_dup = 0
        for act in acts:
            f0, f1 = (int(round(x)) for x in act.frame_range)
            rots, hips = sample(arm, act, f0, f1)
            cid = slug(act.name); key = (fig, cid)
            if key in kept:
                prev = kept[key]
                if len(prev) == len(rots) and max(max_deg(a, b) for a, b in zip(prev, rots)) < DUP_DEG:
                    n_dup += 1; cat[cid][fig].setdefault("also_in", []).append(path); continue
                cid += "_b"; key = (fig, cid)
            kept[key] = rots
            # keep rotations and the Hips' translation (divided by the hip height); drop the rest
            for cont, fc in channels(act):
                dp = fc.data_path
                bone = dp.split('"')[1] if 'pose.bones["' in dp else ""
                if dp.endswith(".scale") or (dp.endswith(".location") and bone != P + "Hips"):
                    cont.remove(fc)
                elif dp.endswith(".location"):
                    for kp in fc.keyframe_points:
                        kp.co.y /= hip_h; kp.handle_left.y /= hip_h; kp.handle_right.y /= hip_h
            for other in acts:
                if other is not act:
                    other.use_fake_user = True
            bind(arm, act)
            dst = os.path.join(OUT, fig, cid + ".glb"); os.makedirs(os.path.dirname(dst), exist_ok=True)
            for o in bpy.data.objects:
                o.select_set(o is arm)
            bpy.context.view_layer.objects.active = arm
            bpy.ops.export_scene.gltf(filepath=dst, use_selection=True, export_animations=True, export_animation_mode='ACTIVE_ACTIONS',
                                      export_force_sampling=True)
            secs = (f1 - f0) / float(fps) if fps else 0.0
            dx = (hips[-1] - hips[0]); travel = math.hypot(dx.x, dx.y) / hip_h / secs if secs > 0 else 0.0
            zs = [h.z / hip_h for h in hips]
            row = {"source": path, "name": act.name, "frames": [f0, f1], "fps": fps, "seconds": round(secs, 3),
                   "travel_hips_per_s": round(travel, 3), "height_range_hips": [round(min(zs), 3), round(max(zs), 3)],
                   "loops": max_deg(rots[0], rots[-1]) < LOOP_DEG, "hip_height_m": round(hip_h, 4), "file": dst}
            cat.setdefault(cid, {})[fig] = row; n_new += 1
        print(f"[{TAG}] {path} ({fig}): {len(acts)} clips, {n_new} kept, {n_dup} duplicates of clips already in the bank")
    figs = sorted({s["figure"] for s in sources})
    for cid, row in cat.items():
        miss = [f for f in figs if f not in row]
        if miss:
            row["missing"] = miss
    pairs = sorted(c for c, r in cat.items() if "missing" not in r)
    json.dump({"figures": figs, "pairs": pairs, "clips": dict(sorted(cat.items()))}, open(os.path.join(OUT, "bank.json"), "w"), indent=1,
              sort_keys=True)
    print(f"[{TAG}] {len(cat)} clips, {len(pairs)} complete pairs: {pairs}")
    for f in figs:
        print(f"[{TAG}]   {f}: {sum(1 for r in cat.values() if f in r)} clips, missing {sum(1 for r in cat.values() if f in r.get('missing', []))}")


main()
