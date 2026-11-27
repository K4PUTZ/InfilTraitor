"""MOVEMENT_MASTER_PLAN §11.6 step 2 — a hold family's LAB FILE: every model of the family in the Agent's hand, in the family's aim.

Director, 2026-11-16 (§11.8 Q11): "todos os modelos da mesma família lado a lado, próximos do agente, e vamos conferir o tamanho e a
posição uma por uma, usando a mesma pose (aim)". 2026-11-17: "começar a preparar as cenas de trabalho no Blender, com o personagem em
cada tipo de empunhadura (aim) + todas as armas daquele tipo, para ajustar os tamanhos. Começando pelas pistolas".

THE FILE. `ASSETS/MODELS/actors/agent/<fig>/work/FAMILY_<family>_aim_<FIG>.blend`: a LINE of Agents side by side (one per model, 0.45 apart along X, all
facing -Y), every one frozen in the aim the GAME plays (the family's timeline at its `aim` marker: for H1 the Director's
`SEQ_draw_pistol_<FIG>_arm6.blend`, frame 23 = `sequences/<fig>/draw_pistol.json`'s last stop), each holding ONE model, child of
its RightHand bone. Agent 01 holds the family's certified reference as the timeline holds it (`PROP_pistol`, untouched). The others
are opened at a STARTING size (the guns pack at the certified pistol's factor 0.0600, §11.5; another source at a length relative to
the reference, the roster's number) and a STARTING grip: same orientation as the reference, the GRIP ANCHOR (the top of the grip, at
its back: where the web of the hand sits; `grip_anchor`) on the reference's. Each model's object origin is its grip anchor, so S and
R act about the hand. A label on the floor names each one. The Director sets the size and the grip of each by hand (object or Edit
Mode, both are read back: the read-back fits the SOURCE model's vertices to where they now are, a similarity transform, so any mix
of moves, turns and uniform scales is recovered; reshaping is reported) and saves.

The pose is the family's, shared by every model (§11.2): it is not edited here. The file is built ONCE and never rebuilt over his
work (`pose_lab.py family` opens it as it is).

H3, THE LONG GUNS (2026-11-23, the Director: "A certificação do tamanho da escopeta está ok. Vamos conferir as demais armas da
família"). The same line in the long gun's aim: the Director's `SEQ_draw_shotgun_<FIG>.blend` at its `aim` marker (frame 31), opened
and never saved (the lab is saved as a new file). The long gun rides the LEFT hand (the timeline keys it there), so every model is a
child of the LeftHand bone. The reference is the certified shotgun AS THE TIMELINE HOLDS IT (`PROP_shotgun`: the glb's raw mesh at the
object's x8.5, i.e. x0.085 of the pack's units); its glb frame is found by fitting its source to it. A model's frame and anchor are
EXPLICIT per model (`FAMILIES["H3"]`), because the guessed ones fail on long guns (measured 2026-11-23 on side renders: the grip-low
rule turned the bullpup, a sniper, three sci-fi rifles and the lightning gun barrel-backwards, one launcher lies on its side, and the
grip anchor lands on the BUTT): `frame` is the turn that puts the barrel along +X and the top up, `anchor` the centre of the TRIGGER
GUARD (the hole of the side silhouette in front of the grip, picked by eye where there are several), so the right hand's index finger
finds every trigger where it finds the shotgun's. The pack's models open at the shotgun's own factor (one pack, one scale); the others
at a length relative to it. Three have no shoulder stock (the sawed-off, the short stock and the MGL-style launcher): they stand in the
shouldered aim only to be sized and gripped; their aim is two arms forward (H2's way, the Director 2026-11-17).

H3 IN FIVE SCENES (2026-11-23, the Director: "vamos separar um pouco as armas porque as animações vão ter que ser um pouco
diferentes. Shotguns, rifles, sniper, scyfi e grenade launcher. Este último não tem posição mirada, vai ser só cintura"; on the two
sci-fi snipers: "Com os snipers"). One file per animation group (`H3_GROUPS`): the H3 line restricted to the group's models, each
still numbered as in the one H3 file (the numbers he judges them by), the certified shotgun as 01 in every one (each model is read
back relative to it). The grenade launchers have no aimed stage: their scene stands at the HIP (`hip` marker), on the shotgun's grip
until a grip of their own exists.

A MODEL WITH A GRIP OF ITS OWN (2026-11-24, the Director on the bullpup: "A última arma especificamente tem um design diferente,
então eu tive que modificar o esqueleto. Vamos já deixar essa empunhadura salva"). He may re-pose the Agent that holds one model.
The game still plays ONE body per family until POLISH-01 ("a pegada individual por arma pra fase de polimento", 2026-11-23), so
the read-back gives that model twice: `rel_*` on the FAMILY's body (its place in the world, read in the reference Agent's hand: what
the one body shows), and `own_grip` in its own re-posed hand, with the bones he changed. `grip` writes that Agent's whole pose as a
pose file (`TripoFigure`'s format, the model in its own hand), so the grip is kept for POLISH-01; nothing in the game reads it yet.

Run inside Blender:
  blender -b --python family_lab.py -- build  <family> <figure> <out .blend> [readback .json] [--marker <name>]
      <family>: H1, H3, or one of H3's groups (H3_SHOTGUNS, H3_RIFLES, H3_SNIPERS, H3_SCIFI, H3_LAUNCHERS)
      with a read-back: every model opens where that read-back placed it relative to the reference (the female's file from the
      male's sizes; her own aim, the same pistol, so only the figures' difference is left to adjust)
      --marker: the line at another stop of the timeline than the family's (2026-11-24: the rifles' `hip` after their aim)
  blender -b --python family_lab.py -- grip <saved .blend> <nn> <out .json>   -> Agent nn's whole pose + its model in its hand,
      a pose file whose id is the file's name (`ASSETS/ANIMATIONS/poses/<figure>/grip_<model>_<stance>.json`)
  blender -b --python family_lab.py -- seq <family timeline .blend> <nn> <out .blend> <marker>=<lab .blend> [...]
      -> model nn's OWN draw timeline: the family's, the model in the reference's place, each named stop posed as that lab scene's Agent
         (`seq`'s docstring; `SEQ_draw_<model>_<FIG>.blend`, read back by `pose_lab.py sequence draw_<model>`)
  blender -b --python family_lab.py -- in_step <his family timeline> <his model timeline> <her family timeline> <out .blend>
      -> the other figure's model timeline in step with his: his change from his family timeline put on her own keys, the model at his place in
         her hand, her right hand on it where his is (`in_step`'s docstring; `SEQ_draw_bullpup_FEMALE.blend`)
  blender -b --python family_lab.py -- raise <timeline .blend> <out .blend> <f0> <f1> <breakdowns,comma> [bulge m] [turn deg] [turn end] [bulge end m|-]
      -> the raise between two stops rebuilt from the gun: its path straight and eased, bowed forward out of the coat, both hands on it at
         the breakdowns, the slide re-keyed (`raise_from_gun`'s docstring; the female's bullpup, hip 23 to aim 31); a turn about the left palm
         in mid-raise keeps a stocked gun's butt out of the coat (2026-11-26, the short stock). The hip before it: `long_gun_pose.py`;
         the cuts it leaves: `gun_cuts.py`
  blender -b --python family_lab.py -- render <saved .blend> <out prefix> [readback .json] -> <prefix>_line.png (the whole line, three-quarters)
                                                                                  <prefix>_tile_<nn>.png (each gun hand from the side, one scale)
  blender -b --python family_lab.py -- swap <saved .blend> "<nn name>" <old glb> <new glb>   -> a model replaced by its edited version, in place
  blender -b --python family_lab.py -- readback <saved .blend> <out .json>       -> each model's placement read off the saved file

THE READ-BACK. Each model's SOURCE vertices (the glb, imported and turned as the build did) are fitted to where they now are in the
frame of what holds them (the RightHand bone; a muzzle attachment: its carrier pistol), a similarity transform (Umeyama): scale,
rotation, offset, and the residual (above a tenth of a millimetre at the reference's size the model was RESHAPED, not just placed:
reported, never hidden). The reference is read the same way, and each model is then given RELATIVE TO IT: `rel_scale` (the model's
native units to the reference model's), `rel_quat` and `rel_pos` (the model's frame in the reference model's glTF frame), so the
family's timeline, which places the reference at every stop, places the model by one product. Also: its length relative to the
reference, how far the Director moved it from the build's start, and a proposed muzzle (the centre of the foremost vertices along the
barrel, glTF space of the source).
"""
import os as _os, sys as _sys
_sys.path.insert(0, _os.path.join(_os.path.dirname(_os.path.abspath(__file__)), ".."))
import model_paths as mp  # where every model lives (ASSETS/MODELS layout)
import bpy, bmesh, sys, os, math, json, re
from mathutils import Matrix, Quaternion, Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
FIT = None   # per figure: mp.agent(figure, "work")
IMPORTED = os.path.join(ROOT, "ASSETS", "ISOMETRIC", "source_assets", "imported_models")
PACK = os.path.join(IMPORTED, "quaternius_ultimate_guns_pack", "extracted")
PP = os.path.join(IMPORTED, "items_polypizza")
SOURCES = os.path.join(ROOT, mp.props())
PREFIX = "mixamorig:"
PACK_FACTOR = 0.0600     # the certified pistol's factor on the pack's native units (MOVEMENT §11.5): where the pack's guns OPEN
SPACING = 0.45           # between two Agents of the line, along X (the figure's units: the male stands 0.88 with the hat)
REMOVE = ("Body_Hair", "Outfit_Belt", "Outfit_Shirt", "Outfit_Trousers", "Icosphere")   # hidden in the game's dressed set (`TripoFigure.UNDRESSED_PIECES`)

# A family: the timeline whose `aim` marker is the game's aim, the prop the timeline holds (the certified reference) and the models.
# A model: (label, source glb, start, kind). start = "pack" (PACK_FACTOR) or a float: its length as a fraction of the reference's.
# kind = "held" (in the hand at the grip anchor) or "muzzle" (an attachment: a copy of the reference with the model on its muzzle).
FAMILIES = {
    "H1": {
        "timeline": "draw_pistol", "marker": "aim", "reference": "pistol", "reference_label": "Pistol-52kQzphmeF (certified)",
        "reference_glb": "ASSETS/props/pistol_quaternius/pistol.glb",
        "muzzle": (0.1266, 0.0349, 0.0),    # the reference's `model.muzzle` (weapons/pistol.json), glTF space of its model
        "models": [
            ("Pistol", os.path.join(PACK, "Pistol.glb"), "pack", "held"),
            ("Pistol-J3i9KDQ3kt", os.path.join(PACK, "Pistol-J3i9KDQ3kt.glb"), "pack", "held"),
            ("Pistol-Z7aOjJu583", os.path.join(PACK, "Pistol-Z7aOjJu583.glb"), "pack", "held"),
            ("Revolver", os.path.join(PACK, "Revolver.glb"), "pack", "held"),
            ("Revolver-9C26wSpMS0", os.path.join(PACK, "Revolver-9C26wSpMS0.glb"), "pack", "held"),
            ("Revolver-XrnLUz6kQj", os.path.join(PACK, "Revolver-XrnLUz6kQj.glb"), "pack", "held"),
            ("Taser (Tripo)", os.path.join(SOURCES, "tripo_props1_zoned", "taser.glb"), 0.75, "held"),            # 15 cm vs ~20
            ("Hand crossbow", os.path.join(SOURCES, "hand_crossbow", "hand_crossbow.glb"), 1.35, "held"),         # hand_crossbow.py
            ("Flare gun", os.path.join(PP, "flare", "Flare_Gun-44H9OBUqTC.glb"), 1.0, "held"),
            ("Scifi_Pistol-TuHM3CURcC", os.path.join(PP, "scifi", "Scifi_Pistol-TuHM3CURcC.glb"), 1.0, "held"),
            ("Scifi_Pistol-U0Q1BrKL1y", os.path.join(PP, "scifi", "Scifi_Pistol-U0Q1BrKL1y.glb"), 1.0, "held"),
            ("Scifi_Pistol-uw4B33Mm0d", os.path.join(PP, "scifi", "Scifi_Pistol-uw4B33Mm0d.glb"), 1.0, "held"),
            ("Ray gun", os.path.join(PP, "scifi", "Ray_Gun-DIcib0mihf.glb"), 1.0, "held"),
            ("Grapple launcher (Tripo)", os.path.join(SOURCES, "tripo_props3_zoned", "grapple_launcher.glb"), 1.2, "held"),  # ITEMS Q3 open
            ("Suppressor-QWfBIqy0VW", os.path.join(PP, "suppressors", "Suppressor-QWfBIqy0VW.glb"), 0.6, "muzzle"),
            ("Suppressor-VLiLj3j1tS", os.path.join(PP, "suppressors", "Suppressor-VLiLj3j1tS.glb"), 0.6, "muzzle"),
        ],
    },
    # A long-gun model: (label, source glb, start, frame, anchor). start = "pack" (the reference's own factor: the same pack, the same
    # native units) or its length as a fraction of the reference's. frame = the turns, in order, that put the imported model barrel +X,
    # up +Z ([axis, degrees] pairs). anchor = (x, z) of the trigger guard's centre in that frame, the model's own units, y = the box's
    # middle. Read off side renders on 2026-11-23 (the silhouette's holes; `MOVEMENT` §11.6 step 2 has the record).
    "H3": {
        "long": True, "timeline_file": "SEQ_draw_shotgun_{FIG}.blend", "marker": "aim", "hand": "LeftHand",
        "reference": "shotgun", "reference_label": "Shotgun (certified)", "reference_glb": "ASSETS/props/shotgun/shotgun.glb",
        "reference_anchor": (0.4894, -0.2153),
        "spacing": 0.6,
        "render": {"tile_ortho": 0.9, "tile_target": (0.0, -0.1, 0.05), "line": False},
        "models": [
            ("Shotgun-ZmPTnh7njL", os.path.join(PACK, "Shotgun-ZmPTnh7njL.glb"), "pack", [["Z", 0]], (0.4929, -0.2047)),
            ("Shotgun Sawed Off", os.path.join(PACK, "Shotgun Sawed Off.glb"), "pack", [["Z", 0]], (0.5365, -0.0471)),
            # the game's copy, not the pack's: its ejection port is closed (2026-11-26, `glb_close_opening.py`), and `family_rows.py --h3`
            # copies this source over ASSETS/props/shotgun_short_stock/ (the same file now, so the copy is skipped and the floor stays)
            ("Shotgun Short Stock", os.path.join(ROOT, "ASSETS", "props", "shotgun_short_stock", "shotgun_short_stock.glb"), "pack", [["Z", 0]],
             (0.7765, -0.0224)),
            ("Assault Rifle", os.path.join(PACK, "Assault Rifle.glb"), "pack", [["Z", 0]], (0.4553, 0.2565)),
            ("Assault Rifle-Bgvuu4CUMV", os.path.join(PACK, "Assault Rifle-Bgvuu4CUMV.glb"), "pack", [["Z", 0]], (0.4694, 0.2624)),
            ("Assault Rifle-fpLucho45C", os.path.join(PACK, "Assault Rifle-fpLucho45C.glb"), "pack", [["Z", 0]], (0.4659, 0.2612)),
            ("Bullpup", os.path.join(PACK, "Bullpup.glb"), "pack", [["Z", 0]], (0.5659, 0.2812)),
            ("Sniper Rifle", os.path.join(PACK, "Sniper Rifle.glb"), "pack", [["Z", 0]], (0.6094, -0.2012)),
            ("Sniper Rifle-ASOMZIErq3", os.path.join(PACK, "Sniper Rifle-ASOMZIErq3.glb"), "pack", [["Z", 0]], (0.4518, -0.1400)),
            ("Sniper Rifle-TKaBjAEofL", os.path.join(PACK, "Sniper Rifle-TKaBjAEofL.glb"), "pack", [["Z", 0]], (0.3176, -0.0200)),
            ("Sniper Rifle-i65hEldsw6", os.path.join(PACK, "Sniper Rifle-i65hEldsw6.glb"), "pack", [["Z", 0]], (-0.3706, 0.1506)),
            ("Scifi_AR-MJmAjTeT9h", os.path.join(PP, "scifi", "Scifi_AR-MJmAjTeT9h.glb"), 0.95, [["Z", 0]], (0.1834, 0.0680)),
            ("Scifi_Assault_Rifle-JqdHbURERk", os.path.join(PP, "scifi", "Scifi_Assault_Rifle-JqdHbURERk.glb"), 0.95, [["Z", 0]], (0.2421, 0.0676)),
            ("Scifi_Assault_Rifle-RGtBoJNn3N", os.path.join(PP, "scifi", "Scifi_Assault_Rifle-RGtBoJNn3N.glb"), 0.95, [["Z", 0]], (0.1355, 0.0645)),
            ("Scifi_Sniper-46615JyFm7", os.path.join(PP, "scifi", "Scifi_Sniper-46615JyFm7.glb"), 1.1, [["Z", 0]], (0.0869, 0.0522)),
            ("Scifi_Sniper-VU7QiZYae0", os.path.join(PP, "scifi", "Scifi_Sniper-VU7QiZYae0.glb"), 1.1, [["Z", 0]], (0.1372, 0.0930)),
            ("Lightning_Gun-Nl8qWErOw2", os.path.join(PP, "scifi", "Lightning_Gun-Nl8qWErOw2.glb"), 0.8, [["Z", 270]], (0.6177, 0.1782)),
            ("Grenade_Launcher-ZKvWhvu4tV", os.path.join(PP, "launchers", "Grenade_Launcher-ZKvWhvu4tV.glb"), 0.65, [["Z", 180]], (-0.1859, -0.1093)),
            ("Grenade_Launcher-phmPZCnGOA", os.path.join(PP, "launchers", "Grenade_Launcher-phmPZCnGOA.glb"), 0.8,
             [["Z", 90], ["X", -90], ["Z", 180]], (-0.2432, -0.0885)),
            ("Scifi_Grenade_Launcher-r10Gkf9yDs", os.path.join(PP, "launchers", "Scifi_Grenade_Launcher-r10Gkf9yDs.glb"), 0.8, [["Z", 0]], (0.0988, 0.0616)),
        ],
    },
}
# H3 split by animation (the module's header): each group is H3 with its models only, numbered as in the one H3 file (02-21 in the
# order of FAMILIES["H3"]["models"]), and the marker it is sized at.
H3_GROUPS = {
    "H3_SHOTGUNS": {"numbers": (2, 3, 4), "marker": "aim"},
    "H3_RIFLES": {"numbers": (5, 6, 7, 8), "marker": "aim"},
    "H3_SNIPERS": {"numbers": (9, 10, 11, 12, 16, 17), "marker": "aim"},
    "H3_SCIFI": {"numbers": (13, 14, 15, 18), "marker": "aim"},
    "H3_LAUNCHERS": {"numbers": (19, 20, 21), "marker": "hip"},
}
for _group, _spec in H3_GROUPS.items():
    FAMILIES[_group] = dict(FAMILIES["H3"], numbers=list(_spec["numbers"]), marker=_spec["marker"],
                            models=[FAMILIES["H3"]["models"][n - 2] for n in _spec["numbers"]])

RENDER_DEFAULT = {"tile_ortho": 0.42, "tile_target": (0.0, -0.06, 0.0)}   # H1's tiles (a pistol hand)

CM = Matrix(((1, 0, 0), (0, 0, 1), (0, -1, 0))).to_4x4()    # Blender (x, y, z) -> glTF (x, z, -y)


def fail(msg):
    print(f"[family_lab] ERROR: {msg}")
    sys.exit(1)


def args_after_dashes():
    a = sys.argv
    return a[a.index("--") + 1:] if "--" in a else []


# ---- the models ------------------------------------------------------------------------------------------------------------------------------
def import_model(path, name):
    """The model as ONE mesh object, every node transform applied to its vertices, at the origin, its materials as authored."""
    if not os.path.exists(path):
        fail(f"{os.path.relpath(path, ROOT)} does not exist")
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    new = [o for o in bpy.data.objects if o not in before]
    meshes = [o for o in new if o.type == "MESH"]
    if not meshes:
        fail(f"{os.path.relpath(path, ROOT)}: no mesh")
    others = [o.name for o in new if o.type != "MESH"]
    for o in meshes:
        o.data = o.data.copy() if o.data.users > 1 else o.data
        o.data.transform(o.matrix_world)
        o.parent = None
        o.matrix_world = Matrix.Identity(4)     # the transform is in the vertices now: a join must not apply it a second time
        if "custom_normal" in o.data.attributes:
            o.data.attributes.remove(o.data.attributes["custom_normal"])
    if len(meshes) > 1:
        ctx = {"active_object": meshes[0], "selected_editable_objects": meshes}
        with bpy.context.temp_override(**ctx):
            bpy.ops.object.join()
    ob = meshes[0]
    for n in others:   # the empties of the glTF hierarchy (the joined meshes are gone already)
        if n in bpy.data.objects:
            bpy.data.objects.remove(bpy.data.objects[n])
    ob.parent = None
    ob.matrix_world = Matrix.Identity(4)
    ob.name = name
    return ob


def verts(ob):
    return [v.co.copy() for v in ob.data.vertices]


def box(points):
    return (Vector([min(p[i] for p in points) for i in range(3)]), Vector([max(p[i] for p in points) for i in range(3)]))


def grip_anchor(points):
    """(anchor, grip height) of a handgun-shaped model in the gun frame (barrel +X, up +Z): the top of the grip at its back. Slices from
    the bottom up: the first whose vertices span over 70 % of the length is the body's underside (the slide, the frame, the receiver);
    the grip's back is the rearmost vertex in the band just under it."""
    lo, hi = box(points)
    L, h = hi.x - lo.x, hi.z - lo.z
    n = 48
    z_top = None
    for i in range(n):
        a, b = lo.z + h * i / n, lo.z + h * (i + 1) / n
        xs = [p.x for p in points if a <= p.z < b]
        if xs and max(xs) - min(xs) > 0.7 * L:
            z_top = a
            break
    if z_top is None or z_top <= lo.z + 0.05 * h:
        return Vector((lo.x, 0.0, hi.z)), 0.0          # no grip found under a body: the rear-top corner
    band = [p for p in points if z_top - 0.2 * h <= p.z <= z_top + 1e-6]
    return Vector((min(p.x for p in band), 0.0, z_top)), z_top - lo.z


def to_gun_frame(ob):
    """Turns the model's mesh to the gun frame (barrel along +X, up +Z, centred on y = 0): the long horizontal axis to X, then the
    grip (the low part) to the rear. Returns the turn applied (about Z), in degrees."""
    pts = verts(ob)
    lo, hi = box(pts)
    turn = 0.0
    if hi.y - lo.y > hi.x - lo.x:
        ob.data.transform(Matrix.Rotation(math.radians(90), 4, "Z"))
        turn += 90.0
        pts = verts(ob)
        lo, hi = box(pts)
    low = [p for p in pts if p.z < lo.z + 0.35 * (hi.z - lo.z)]
    if low and sum(p.x for p in low) / len(low) > (lo.x + hi.x) / 2.0:
        ob.data.transform(Matrix.Rotation(math.radians(180), 4, "Z"))
        turn += 180.0
        pts = verts(ob)
        lo, hi = box(pts)
    ob.data.transform(Matrix.Translation((0.0, -(lo.y + hi.y) / 2.0, 0.0)))
    return turn


def gun_frame_matrix(frame):
    """The turn (4x4) that puts an imported model in the gun frame (barrel +X, up +Z): `frame` is a list of [axis, degrees] applied in
    order (H3's explicit frames), or one angle about Z."""
    if not isinstance(frame, (list, tuple)):
        frame = [["Z", float(frame)]]
    m = Matrix.Identity(4)
    for ax, deg in frame:
        m = Matrix.Rotation(math.radians(float(deg)), 4, str(ax)) @ m
    return m


# ---- the figure ------------------------------------------------------------------------------------------------------------------------------
def freeze(scene, frame):
    """The timeline's state at `frame` made static: the pose, the coat's keys, the reference prop's place and visibility; the actions,
    the markers and the frame range go."""
    scene.frame_set(frame)
    bpy.context.view_layer.update()
    held = []
    for ob in bpy.data.objects:
        if ob.animation_data and ob.animation_data.action:
            if ob.type == "ARMATURE":
                state = [(pb, pb.rotation_mode, pb.rotation_quaternion.copy(), pb.rotation_euler.copy(), pb.location.copy(), pb.scale.copy()) for pb in ob.pose.bones]
                held.append(("arm", ob, state))
            else:
                held.append(("obj", ob, (ob.matrix_world.copy(), ob.hide_viewport, ob.hide_render)))
        if ob.type == "MESH" and ob.data.shape_keys and ob.data.shape_keys.animation_data:
            held.append(("keys", ob, [(kb, kb.value) for kb in ob.data.shape_keys.key_blocks]))
    for kind, ob, state in held:
        if kind == "keys":
            ob.data.shape_keys.animation_data_clear()
            for kb, v in state:
                kb.value = v
        else:
            ob.animation_data_clear()
            if kind == "arm":
                for pb, mode, q, e, loc, s in state:
                    pb.rotation_mode = mode
                    pb.rotation_quaternion = q
                    pb.rotation_euler = e
                    pb.location = loc
                    pb.scale = s
            else:
                mw, hv, hr = state
                ob.matrix_world = mw
                ob.hide_viewport = False
                ob.hide_render = False
    scene.timeline_markers.clear()
    scene.frame_start = scene.frame_end = scene.frame_current = 1
    bpy.context.view_layer.update()


def clone_figure(arm, meshes, offset, coll):
    a2 = arm.copy()
    coll.objects.link(a2)
    a2.matrix_world = Matrix.Translation(offset) @ arm.matrix_world
    for k in list(a2.keys()):
        if k.startswith("lab_"):
            del a2[k]
    for m in meshes:
        m2 = m.copy()
        coll.objects.link(m2)
        m2.parent = a2
        m2.matrix_parent_inverse = m.matrix_parent_inverse.copy()
        for mod in m2.modifiers:
            if mod.type == "ARMATURE":
                mod.object = a2
    return a2


def label(text, loc, coll, size=0.028):
    cu = bpy.data.curves.new("label", "FONT")
    cu.body = text
    cu.size = size
    cu.align_x = "CENTER"
    ob = bpy.data.objects.new("LABEL " + text.split("\n")[0], cu)
    coll.objects.link(ob)
    ob.location = loc
    ob.rotation_euler = (math.radians(70), 0, 0)    # standing up toward the front (-Y), tilted back: readable from the front and from above
    mat = bpy.data.materials.get("lab_ink") or bpy.data.materials.new("lab_ink")
    mat.use_nodes = True
    mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.02, 0.02, 0.02, 1)
    cu.materials.append(mat)
    ob.hide_select = True
    return ob


def build(family, figure, out_blend, from_json=None, marker=None):
    if family not in FAMILIES:
        fail(f"unknown family {family} (have {', '.join(FAMILIES)})")
    if os.path.exists(out_blend):
        fail(f"{os.path.relpath(out_blend, ROOT)} exists: it holds the Director's work and is never rebuilt")
    fam = FAMILIES[family]
    if fam.get("long"):
        return build_long(family, figure, out_blend, from_json, marker)
    if marker:
        fail("--marker is for the long guns' timeline (H3)")
    placed = None
    if from_json:    # every model at the place another figure's read-back gave it, relative to the reference (the female from the male's sizes)
        with open(from_json) as f:
            placed = json.load(f)["models"]
    timeline = os.path.join(ROOT, mp.agent(figure, "work", f"SEQ_{fam['timeline']}_{figure.upper()}_arm6.blend"))
    bpy.ops.wm.open_mainfile(filepath=timeline)
    scene = bpy.context.scene
    markers = {m.name: m.frame for m in scene.timeline_markers}
    if fam["marker"] not in markers:
        fail(f"{os.path.basename(timeline)} has no marker '{fam['marker']}' (has {markers})")
    frame = markers[fam["marker"]]
    freeze(scene, frame)
    for n in REMOVE:
        if n in bpy.data.objects:
            bpy.data.objects.remove(bpy.data.objects[n])
    arms = [o for o in bpy.data.objects if o.type == "ARMATURE"]
    if len(arms) != 1:
        fail(f"{os.path.basename(timeline)}: expected one armature, found {len(arms)}")
    arm = arms[0]
    ref = bpy.data.objects.get("PROP_" + fam["reference"])
    if ref is None or ref.parent is not arm or ref.parent_bone != PREFIX + "RightHand":
        fail(f"{os.path.basename(timeline)}: no PROP_{fam['reference']} on the RightHand")
    body = [o for o in bpy.data.objects if o.type == "MESH" and o.parent is arm and o is not ref]
    for o in bpy.data.objects:
        o.select_set(False)
    if bpy.context.object and bpy.context.object.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")

    # Agent 01: the timeline's own figure and the certified reference, in a collection of its own.
    root = scene.collection
    c0 = bpy.data.collections.new(f"01 {fam['reference_label']}")
    root.children.link(c0)
    for o in [arm, ref] + body:
        for c in list(o.users_collection):
            c.objects.unlink(o)
        c0.objects.link(o)
    ref.name = f"GUN_01 {fam['reference_label']}"
    ref["lab_role"] = "reference"
    ref["lab_source"] = fam["reference_glb"]
    ref_pts = verts(ref)
    ref_lo, ref_hi = box(ref_pts)
    ref_len = ref_hi.x - ref_lo.x
    ref_anchor, ref_grip_h = grip_anchor(ref_pts)
    ref_world = ref.matrix_world.copy()
    print(f"[family_lab] {figure} {family}: the aim is {os.path.basename(timeline)} frame {frame}; reference {ref_len:.4f} long, grip anchor "
          f"{tuple(round(v, 4) for v in ref_anchor)}, grip {ref_grip_h:.4f} tall")
    label(f"01\n{fam['reference_label']}", Vector((0.0, -0.42, 0.012)), c0)
    arm["lab_family"] = family
    arm["lab_figure"] = figure
    arm["lab_aim"] = f"{os.path.basename(timeline)}@{frame}"

    rows = []
    for i, (name, path, start, kind) in enumerate(fam["models"], start=2):
        offset = Vector(((i - 1) * SPACING, 0.0, 0.0))
        coll = bpy.data.collections.new(f"{i:02d} {name}")
        root.children.link(coll)
        a2 = clone_figure(arm, body, offset, coll)
        bpy.context.view_layer.update()
        gun = import_model(path, f"GUN_{i:02d} {name}")
        for c in list(gun.users_collection):
            c.objects.unlink(gun)
        coll.objects.link(gun)
        turn = to_gun_frame(gun)
        pts = verts(gun)
        lo, hi = box(pts)
        length = hi.x - lo.x
        if placed is not None:
            key = f"{i:02d} {name}"
            if key not in placed:
                fail(f"{os.path.basename(from_json)} has no '{key}'")
            r = placed[key]
            if kind == "held":
                anchor_t, grip_h = grip_anchor(pts)
            else:
                anchor_t, grip_h = Vector((lo.x, (lo.y + hi.y) / 2.0, (lo.z + hi.z) / 2.0)), 0.0
            # back to the glb's own frame (the read-back's `rel` maps it), the origin kept on the grip anchor
            to_raw = Matrix.Rotation(math.radians(-turn), 4, "Z") @ Matrix.Translation((0.0, (lo.y + hi.y) / 2.0, 0.0))
            gun.data.transform(to_raw)
            anchor = to_raw @ anchor_t
            gun.data.transform(Matrix.Translation(-anchor))
            q = r["rel_quat"]
            from mathutils import Quaternion
            g = Matrix.Translation(Vector(r["rel_pos"])) @ Quaternion((q[3], q[0], q[1], q[2])).to_matrix().to_4x4() @ Matrix.Scale(r["rel_scale"], 4)
            rel = CM.inverted() @ g @ CM
            if kind == "held":
                parent, holder_bone = a2, PREFIX + "RightHand"
                carrier_world = Matrix.Translation(offset) @ ref_world
            else:
                pistol = ref.copy()
                pistol.name = f"GUN_{i:02d} {fam['reference_label'].split(' ')[0]} (carrier)"
                pistol["lab_role"] = "carrier"
                coll.objects.link(pistol)
                pistol.parent = a2
                pistol.parent_type = "BONE"
                pistol.parent_bone = PREFIX + "RightHand"
                bpy.context.view_layer.update()
                pistol.matrix_world = Matrix.Translation(offset) @ ref_world
                bpy.context.view_layer.update()
                parent, holder_bone = pistol, None
                carrier_world = pistol.matrix_world.copy()
            gun.parent = parent
            if holder_bone:
                gun.parent_type = "BONE"
                gun.parent_bone = holder_bone
            bpy.context.view_layer.update()
            gun.matrix_world = carrier_world @ rel @ Matrix.Translation(anchor)
            gun["lab_role"] = kind
            gun["lab_source"] = os.path.relpath(path, ROOT)
            gun["lab_start_factor"] = r["rel_scale"]
            gun["lab_turn_deg"] = 0.0
            gun["lab_anchor"] = list(anchor)
            gun["lab_from"] = os.path.basename(from_json)
            label(f"{i:02d}\n{name}", offset + Vector((0.0, -0.42, 0.012)), coll)
            print(f"[family_lab]   {i:02d} {name:28s} {kind:6s} placed from {os.path.basename(from_json)}: x{r['rel_scale']:.4f} of the reference's units")
            rows.append(name)
            continue
        factor = PACK_FACTOR if start == "pack" else float(start) * ref_len / length
        gun.data.transform(Matrix.Scale(factor, 4))
        pts = verts(gun)
        if kind == "held":
            anchor, grip_h = grip_anchor(pts)
            gun.data.transform(Matrix.Translation(-anchor))
            local = Matrix.Translation(ref_anchor)
            holder_bone = PREFIX + "RightHand"
            parent = a2
        else:   # an attachment: a copy of the reference in this Agent's hand, the model's rear end on its muzzle, the model its child
            pistol = ref.copy()
            pistol.name = f"GUN_{i:02d} {fam['reference_label'].split(' ')[0]} (carrier)"
            pistol["lab_role"] = "carrier"
            coll.objects.link(pistol)
            pistol.parent = a2
            pistol.parent_type = "BONE"
            pistol.parent_bone = PREFIX + "RightHand"
            bpy.context.view_layer.update()
            pistol.matrix_world = Matrix.Translation(offset) @ ref_world
            bpy.context.view_layer.update()
            lo, hi = box(pts)
            rear = Vector((lo.x, (lo.y + hi.y) / 2.0, (lo.z + hi.z) / 2.0))
            gun.data.transform(Matrix.Translation(-rear))
            mz = fam["muzzle"]
            local = Matrix.Translation((mz[0], -mz[2], mz[1]))      # glTF -> Blender
            anchor, grip_h = rear, 0.0
            parent = pistol
            holder_bone = None
        gun.parent = parent
        if holder_bone:
            gun.parent_type = "BONE"
            gun.parent_bone = holder_bone
        bpy.context.view_layer.update()
        carrier_world = (Matrix.Translation(offset) @ ref_world) if kind == "held" else parent.matrix_world
        gun.matrix_world = carrier_world @ local
        gun["lab_role"] = kind
        gun["lab_source"] = os.path.relpath(path, ROOT)
        gun["lab_start_factor"] = factor
        gun["lab_turn_deg"] = turn
        gun["lab_anchor"] = list(anchor / factor)          # in the source's units, after the turn: where the origin sits
        tris = sum(len(p.vertices) - 2 for p in gun.data.polygons)
        label(f"{i:02d}\n{name}", offset + Vector((0.0, -0.42, 0.012)), coll)
        print(f"[family_lab]   {i:02d} {name:28s} {kind:6s} start x{factor:.4f} ({'pack' if start == 'pack' else f'{float(start):.2f} x the reference'}), "
              f"{length * factor / ref_len:.2f} x the reference's length, turned {turn:.0f}, grip {grip_h:.4f} tall, {tris} tris")
        rows.append(name)

    for o in bpy.data.objects:
        o.select_set(False)
    bpy.context.view_layer.objects.active = None
    scene["lab_family"] = family
    os.makedirs(os.path.dirname(out_blend), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=out_blend)
    print(f"[family_lab] wrote {os.path.relpath(out_blend, ROOT)}: {len(rows) + 1} Agents, one model each")


def build_long(family, figure, out_blend, from_json=None, marker=None):
    """A LONG-gun family's lab file (the module's header, H3): the line in the family's aim, every model a child of the hand bone that
    holds the reference (the LEFT hand), its trigger guard on the reference's, its barrel along the reference's. Each model's mesh is
    in the figure's units about its trigger guard, so its object reads Scale 1.0 at the start and S scales it about the trigger.
    `marker`: another stop of the timeline (the hip); a read-back's placements are relative to the reference, so they hold there too."""
    fam = FAMILIES[family]
    placed = None
    if from_json:    # every model at the place another figure's read-back gave it, relative to the reference
        with open(from_json) as f:
            placed = json.load(f)["models"]
    timeline = os.path.join(ROOT, mp.agent(figure, "work", fam["timeline_file"].format(FIG=figure.upper())))
    bpy.ops.wm.open_mainfile(filepath=timeline)      # the Director's timeline: read here, never saved (the lab is saved as a new file)
    scene = bpy.context.scene
    markers = {m.name: m.frame for m in scene.timeline_markers}
    marker = marker or fam["marker"]
    if marker not in markers:
        fail(f"{os.path.basename(timeline)} has no marker '{marker}' (has {markers})")
    frame = markers[marker]
    freeze(scene, frame)
    for n in REMOVE:
        if n in bpy.data.objects:
            bpy.data.objects.remove(bpy.data.objects[n])
    arms = [o for o in bpy.data.objects if o.type == "ARMATURE"]
    if len(arms) != 1:
        fail(f"{os.path.basename(timeline)}: expected one armature, found {len(arms)}")
    arm = arms[0]
    hand = PREFIX + fam["hand"]
    ref = bpy.data.objects.get("PROP_" + fam["reference"])
    if ref is None or ref.parent is not arm or ref.parent_bone != hand:
        fail(f"{os.path.basename(timeline)}: no PROP_{fam['reference']} on the {fam['hand']}")
    body = [o for o in bpy.data.objects if o.type == "MESH" and o.parent is arm and o is not ref]
    for o in bpy.data.objects:
        o.select_set(False)
    if bpy.context.object and bpy.context.object.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")

    # The reference's glb frame in the world: its source as `import_model` gives it (the frame every read-back uses) fitted to where the
    # timeline holds its raw mesh. The same glb, so the same vertices in the same order: the fit is exact or the file is not what we think.
    src = import_model(os.path.join(ROOT, fam["reference_glb"]), "_ref_src")
    sp = verts(src)
    bpy.data.objects.remove(src)
    rw = [ref.matrix_world @ v.co for v in ref.data.vertices]
    if len(sp) != len(rw):
        fail(f"PROP_{fam['reference']} has {len(rw)} vertices, {fam['reference_glb']} {len(sp)}: not the reference's model")
    s_ref, R_ref, t_ref, rms = umeyama(sp, rw)
    if rms > 1e-5:
        fail(f"PROP_{fam['reference']} does not fit {fam['reference_glb']} (rms {rms:.2e}): its vertices are not the glb's")
    ref_imp = _sim(s_ref, R_ref, t_ref)
    lo, hi = box(sp)
    ref_len = hi.x - lo.x
    ra = fam["reference_anchor"]
    a_ref = ref_imp @ Vector((ra[0], (lo.y + hi.y) / 2.0, ra[1]))
    rot = R_ref.to_4x4()
    print(f"[family_lab] {figure} {family}: the {marker} is {os.path.basename(timeline)} frame {frame}; reference x{s_ref:.4f} of its units "
          f"(fit rms {rms:.1e}), {ref_len * s_ref:.4f} long, trigger guard at {tuple(round(v, 4) for v in a_ref)}")

    root = scene.collection
    c0 = bpy.data.collections.new(f"01 {fam['reference_label']}")
    root.children.link(c0)
    for o in [arm, ref] + body:
        for c in list(o.users_collection):
            c.objects.unlink(o)
        c0.objects.link(o)
    ref.name = f"GUN_01 {fam['reference_label']}"
    ref["lab_role"] = "reference"
    ref["lab_source"] = fam["reference_glb"]
    label(f"01\n{fam['reference_label']}", Vector((0.0, -0.42, 0.012)), c0)
    arm["lab_family"] = family
    arm["lab_figure"] = figure
    arm["lab_aim"] = f"{os.path.basename(timeline)}@{frame}"

    rows = []
    numbers = fam.get("numbers") or list(range(2, len(fam["models"]) + 2))     # a group keeps the one H3 file's numbers
    for slot, (i, (name, path, start, gframe, anchor2)) in enumerate(zip(numbers, fam["models"]), start=1):
        offset = Vector((slot * fam["spacing"], 0.0, 0.0))
        coll = bpy.data.collections.new(f"{i:02d} {name}")
        root.children.link(coll)
        a2 = clone_figure(arm, body, offset, coll)
        bpy.context.view_layer.update()
        gun = import_model(path, f"GUN_{i:02d} {name}")
        for c in list(gun.users_collection):
            c.objects.unlink(gun)
        coll.objects.link(gun)
        g_turn = gun_frame_matrix(gframe)
        gun.data.transform(g_turn)
        pts = verts(gun)
        lo, hi = box(pts)
        length = hi.x - lo.x
        anchor = Vector((anchor2[0], (lo.y + hi.y) / 2.0, anchor2[1]))     # the trigger guard: gun frame, the model's own units
        if placed is not None:
            key = f"{i:02d} {name}"
            if key not in placed:
                fail(f"{os.path.basename(from_json)} has no '{key}'")
            r = placed[key]
            gun.data.transform(g_turn.inverted())          # back to the glb's own frame (the read-back's `rel` maps it), origin on the anchor
            anchor = g_turn.inverted() @ anchor
            gun.data.transform(Matrix.Translation(-anchor))
            from mathutils import Quaternion
            q = r["rel_quat"]
            g = Matrix.Translation(Vector(r["rel_pos"])) @ Quaternion((q[3], q[0], q[1], q[2])).to_matrix().to_4x4() @ Matrix.Scale(r["rel_scale"], 4)
            loc, quat, sc = (Matrix.Translation(offset) @ ref_imp @ (CM.inverted() @ g @ CM) @ Matrix.Translation(anchor)).decompose()
            gun.data.transform(Matrix.Scale(sc.x, 4))       # the size in the mesh: the object reads Scale 1.0
            world = Matrix.Translation(loc) @ quat.to_matrix().to_4x4()
            mesh_frame = []
            factor = r["rel_scale"]
        else:
            factor = 1.0 if start == "pack" else float(start) * ref_len / length
            gun.data.transform(Matrix.Translation(-anchor))
            gun.data.transform(Matrix.Scale(factor * s_ref, 4))
            world = Matrix.Translation(offset) @ Matrix.Translation(a_ref) @ rot
            mesh_frame = gframe
        gun.parent = a2
        gun.parent_type = "BONE"
        gun.parent_bone = hand
        bpy.context.view_layer.update()
        gun.matrix_world = world
        gun["lab_role"] = "held"
        gun["lab_source"] = os.path.relpath(path, ROOT)
        gun["lab_start_factor"] = factor                     # the start, in the reference's units per the model's
        gun["lab_mesh_frame"] = json.dumps(mesh_frame)      # the turn from the source to THIS mesh (the read-back turns the source by it)
        gun["lab_gun_frame"] = json.dumps(gframe)           # the turn from the source to the gun frame, barrel +X (the muzzle is read there)
        gun["lab_anchor"] = list(anchor)
        if placed is not None:
            gun["lab_from"] = os.path.basename(from_json)
        tris = sum(len(p.vertices) - 2 for p in gun.data.polygons)
        label(f"{i:02d}\n{name}", offset + Vector((0.0, -0.42, 0.012)), coll)
        how = f"from {os.path.basename(from_json)}" if placed is not None else ("pack" if start == "pack" else f"{float(start):.2f} x the reference")
        print(f"[family_lab]   {i:02d} {name:36s} x{factor:.4f} of the reference's units ({how}), {length * factor / ref_len:.2f} x its length, "
              f"frame {gframe}, {tris} tris")
        rows.append(name)

    for o in bpy.data.objects:
        o.select_set(False)
    bpy.context.view_layer.objects.active = None
    scene["lab_family"] = family
    os.makedirs(os.path.dirname(out_blend), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=out_blend)
    print(f"[family_lab] wrote {os.path.relpath(out_blend, ROOT)}: {len(rows) + 1} Agents, one model each")


# ---- the render ------------------------------------------------------------------------------------------------------------------------------
def _setup_render(scene, w, h):
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x, scene.render.resolution_y = w, h
    world = bpy.data.worlds.new("lab_w")
    scene.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.78, 0.78, 0.80, 1)
    for rot, en in (((50, 0, -30), 3.0), ((-40, 0, 150), 1.0)):
        s = bpy.data.objects.new("lab_sun", bpy.data.lights.new("lab_sun", "SUN"))
        scene.collection.objects.link(s)
        s.rotation_euler = tuple(math.radians(a) for a in rot)
        s.data.energy = en
    scene.view_settings.view_transform = "Standard"
    cam = bpy.data.objects.new("lab_cam", bpy.data.cameras.new("lab_cam"))
    scene.collection.objects.link(cam)
    scene.camera = cam
    return cam


def render(blend, prefix, readback_json=None):
    bpy.ops.wm.open_mainfile(filepath=blend)
    scene = bpy.context.scene
    if readback_json:     # a red bead on each proposed muzzle, in the Agent's collection (so its tile shows it)
        with open(readback_json) as f:
            rb = json.load(f)["models"]
        mat = bpy.data.materials.new("lab_muzzle")
        mat.use_nodes = True
        mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (1.0, 0.02, 0.02, 1)
        mat.node_tree.nodes["Principled BSDF"].inputs["Emission Color"].default_value = (1.0, 0.0, 0.0, 1)
        mat.node_tree.nodes["Principled BSDF"].inputs["Emission Strength"].default_value = 2.0
        for key, r in rb.items():
            ob = bpy.data.objects.get("GUN_" + key)
            if ob is None or r["role"] == "muzzle":
                continue
            me = bpy.data.meshes.new("bead")
            bm = bmesh.new()
            bmesh.ops.create_uvsphere(bm, u_segments=12, v_segments=8, radius=0.004)
            bm.to_mesh(me)
            bm.free()
            me.materials.append(mat)
            bead = bpy.data.objects.new("MUZZLE_" + key, me)
            ob.users_collection[0].objects.link(bead)
            bead.location = Vector(r["muzzle_world"])
    guns = sorted([o for o in bpy.data.objects if o.name.startswith("GUN_") and o.get("lab_role") != "carrier"], key=lambda o: o.name)
    look = dict(RENDER_DEFAULT)
    look.update(FAMILIES.get(scene.get("lab_family", ""), {}).get("render", {}))
    cam = _setup_render(scene, 2400, 1000)
    if look.get("line", True):
        # the whole line, from the front three-quarters, above the hands. Not for the long guns: from the front (even three-quarters,
        # even from above) a long gun points at the camera and reads as nothing (H3's first renders, 2026-11-23); their tiles say it all
        xs = [o.matrix_world.translation.x for o in guns]
        mid = Vector(((min(xs) + max(xs)) / 2.0, -0.1, 0.62))
        cam.data.lens = 28
        cam.location = mid + Vector((-1.0, -6.6, 1.4))
        cam.rotation_euler = (mid - cam.location).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = prefix + "_line.png"
        bpy.ops.render.render(write_still=True)
        print(f"[family_lab] rendered {scene.render.filepath}")
    # each gun hand from the Agent's right side (-X), orthographic, one scale for all: a tile per model
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = look["tile_ortho"]
    scene.render.resolution_x, scene.render.resolution_y = 520, 420
    tiles = []
    for o in guns:
        mine = set(o.users_collection[0].objects)
        for x in bpy.data.objects:            # only this Agent and its model: the side camera looks down the whole line
            if x.type in ("MESH", "FONT", "ARMATURE"):
                x.hide_render = x not in mine
        p = o.matrix_world.translation.copy()
        target = p + Vector(look["tile_target"])
        cam.location = target + Vector((-2.0, 0.0, 0.0))
        cam.rotation_euler = (math.radians(90), 0, math.radians(-90))
        path = f"{prefix}_tile_{o.name[4:6]}.png"
        scene.render.filepath = path
        bpy.ops.render.render(write_still=True)
        tiles.append((path, o.name[4:]))
    with open(prefix + "_tiles.json", "w") as f:
        json.dump(tiles, f)
    print(f"[family_lab] rendered {len(tiles)} hand tiles ({prefix}_tiles.json lists them)")


# ---- the read-back --------------------------------------------------------------------------------------------------------------------------
def umeyama(src, dst):
    """(s, R, t, rms): dst ~ s R src + t, least squares (Umeyama 1991), R a proper rotation."""
    import numpy as np
    A = np.array([tuple(v) for v in src]); B = np.array([tuple(v) for v in dst])
    ma, mb = A.mean(0), B.mean(0)
    a, b = A - ma, B - mb
    U, D, Vt = np.linalg.svd(b.T @ a / len(A))
    S = np.eye(3)
    if np.linalg.det(U) * np.linalg.det(Vt) < 0:
        S[2, 2] = -1
    R = U @ S @ Vt
    s = float(np.trace(np.diag(D) @ S) / (a ** 2).sum(1).mean())
    t = mb - s * R @ ma
    rms = float(np.sqrt((((s * (R @ a.T)).T + mb - B) ** 2).sum(1).mean()))
    return s, Matrix(R.tolist()), Vector(t.tolist()), rms


def _sim(s, R, t):
    m = R.to_4x4() @ Matrix.Scale(s, 4)
    m.translation = t
    return m


def _mesh_frame(ob):
    """The turn the build gave the model's mesh (the read-back turns the source by it before fitting)."""
    if "lab_mesh_frame" in ob:      # a long-gun file (`build_long`): the turns are stored, not found again
        return gun_frame_matrix(json.loads(ob["lab_mesh_frame"]))
    if ob.get("lab_role") != "reference":
        return Matrix.Rotation(math.radians(float(ob.get("lab_turn_deg", 0.0))), 4, "Z")
    return Matrix.Identity(4)


def _source_points(ob, mesh_frame):
    src = import_model(os.path.join(ROOT, ob["lab_source"]), "_src")
    src.data.transform(mesh_frame)
    sp = verts(src)
    bpy.data.objects.remove(src)
    if len(sp) != len(ob.data.vertices):
        fail(f"{ob.name}: {len(ob.data.vertices)} vertices in the file, {len(sp)} in its source: the mesh was edited beyond a placement")
    return sp


def _fit_in(ob, sp, frame):
    """(s, R, t, rms): the model's source points fitted to where its vertices are, in `frame`'s coordinates."""
    to_frame = frame.inverted()
    return umeyama(sp, [to_frame @ (ob.matrix_world @ v.co) for v in ob.data.vertices])


def _reposed(arm, ref_arm):
    """How `arm` (a lab Agent) differs from `ref_arm` (the reference Agent: the family's body), or None when it holds the same pose:
    the bones he changed himself [(name, degrees turned, distance moved with G)], read on the pose channels. The test is element by
    element on the evaluated matrices (anything that poses a bone counts): a quaternion of an evaluated matrix is not a unit one where
    the rig carries a scale (1.000008 on the right leg), and its dot with itself reads as a 0.13 degree turn (2026-11-24)."""
    differs = any(max(abs(x - y) for ra, rb in zip(pb.matrix, ref_arm.pose.bones[pb.name].matrix) for x, y in zip(ra, rb)) > 1e-6
                  for pb in arm.pose.bones)
    if not differs:
        return None
    out = []
    for pb in arm.pose.bones:
        a, b = pb.matrix_basis, ref_arm.pose.bones[pb.name].matrix_basis
        qa, qb = a.to_3x3().normalized().to_quaternion().normalized(), b.to_3x3().normalized().to_quaternion().normalized()
        deg = math.degrees(2.0 * math.acos(min(1.0, abs(qa.dot(qb)))))
        moved = (a.translation - b.translation).length
        if deg > 0.05 or moved > 1e-5:
            out.append((pb.name.replace(PREFIX, ""), round(deg, 2), round(moved, 6)))
    return out


def _rel_fields(rel):
    """A transform in the reference model's frame (Blender axes) as the read-back's `rel_*` (glTF axes)."""
    g = CM @ rel @ CM.inverted()
    gl, gq, gs = g.decompose()
    return {"rel_scale": round(gs.x, 5), "rel_pos": [round(c, 5) for c in gl], "rel_quat": [round(gq.x, 5), round(gq.y, 5), round(gq.z, 5), round(gq.w, 5)],
            "rel_turn_deg": round(math.degrees(gq.angle), 2)}


def readback(blend, out_json):
    import numpy as np
    bpy.ops.wm.open_mainfile(filepath=blend)
    bpy.context.view_layer.update()
    guns = sorted([o for o in bpy.data.objects if o.name.startswith("GUN_") and o.get("lab_role") != "carrier"], key=lambda o: o.name)
    ref_gun = next((o for o in guns if o.get("lab_role") == "reference"), None)
    ref_arm = ref_gun.parent if ref_gun is not None and ref_gun.parent_type == "BONE" else None
    rows = {}
    ref_m = None
    for ob in guns:
        role = ob.get("lab_role")
        explicit = "lab_mesh_frame" in ob      # a long-gun file (`build_long`): the turns are stored, not found again
        mesh_frame = _mesh_frame(ob)
        sp = _source_points(ob, mesh_frame)
        holder = ob.parent
        if ob.parent_type == "BONE":
            pb = holder.pose.bones[ob.parent_bone]
            frame = holder.matrix_world @ pb.matrix
        else:
            frame = holder.matrix_world
        s, R, t, rms = _fit_in(ob, sp, frame)
        # the fit maps the TURNED source; the board loads the glb as it is: fold the build's turn in, so `m` maps the glb's own frame
        m = _sim(s, R, t) @ mesh_frame
        # an Agent he RE-POSED for this model (its own grip, POLISH-01): `rel_*` is the model on the FAMILY's body (where he put it,
        # read in the reference Agent's hand: what the game's one body shows), `own_grip` in its own hand (the module's header)
        own = None
        changed = _reposed(holder, ref_arm) if ob.parent_type == "BONE" and ref_arm is not None and holder is not ref_arm else None
        if changed is not None:
            own = {"m": m, "bones": changed}
            s2, R2, t2, _rms2 = _fit_in(ob, sp, holder.matrix_world @ ref_arm.pose.bones[ob.parent_bone].matrix)
            m = _sim(s2, R2, t2) @ mesh_frame
        # the muzzle and the length are read in the GUN frame (barrel +X), whatever frame the file holds the mesh in: a file built
        # from a read-back keeps the glb's own frame (`lab_turn_deg` 0), so the frame's turn is found again as the build finds it;
        # a long-gun file stores it (`lab_gun_frame`)
        if explicit:
            to_gun = gun_frame_matrix(json.loads(ob["lab_gun_frame"])) @ mesh_frame.inverted()
        else:
            if role != "reference":
                probe = import_model(os.path.join(ROOT, ob["lab_source"]), "_probe")
                frame_turn = to_gun_frame(probe)
                bpy.data.objects.remove(probe)
            else:
                frame_turn = 0.0
            to_gun = Matrix.Rotation(math.radians(frame_turn - (float(ob.get("lab_turn_deg", 0.0)) if role != "reference" else 0.0)), 4, "Z")
        sg = [to_gun @ p for p in sp]
        lo, hi = box(sg)
        tip_x = hi.x - 0.03 * (hi.x - lo.x)
        tip_ids = [i for i, p in enumerate(sg) if p.x >= tip_x]
        muzzle = sum((sp[i] for i in tip_ids), Vector()) / len(tip_ids)
        muzzle_world = ob.matrix_world @ (sum((ob.data.vertices[i].co for i in tip_ids), Vector()) / len(tip_ids))
        muzzle = mesh_frame.inverted() @ muzzle
        muzzle_gltf = CM @ muzzle
        start = float(ob.get("lab_start_factor", 0.0))
        rows[ob.name[4:]] = {"role": role, "source": ob["lab_source"], "holder": ob.parent_bone or holder.name,
                             "scale_in_holder": s, "rms_in_holder": rms, "length_native": hi.x - lo.x,
                             "start_factor": start, "_m": m, "_own": own, "muzzle_proposed": [round(c, 4) for c in muzzle_gltf],
                             "muzzle_world": [round(c, 5) for c in muzzle_world]}
        if role == "reference":
            ref_m = m
            ref_len = hi.x - lo.x
            ref_scale = s
    if ref_m is None:
        fail("no reference model in the file")
    out = {"blend": os.path.relpath(blend, ROOT), "reference": [k for k, r in rows.items() if r["role"] == "reference"][0], "models": {}}
    for k, r in rows.items():
        m = r.pop("_m")
        own = r.pop("_own")
        if own is not None:
            r["own_grip"] = dict(_rel_fields(ref_m.inverted() @ own["m"]), bones=[b[0] for b in own["bones"]],
                                 moved_with_g=[b[0] for b in own["bones"] if b[2] > 1e-5])
            print(f"[family_lab] {k}: its Agent was RE-POSED ({len(own['bones'])} bones: {', '.join(f'{b[0]} {b[1]}' for b in own['bones'])}): "
                  f"rel_* below is on the family's body, own_grip in its own hand (x{r['own_grip']['rel_scale']:.4f}, turn {r['own_grip']['rel_turn_deg']} deg, "
                  f"pos {r['own_grip']['rel_pos']}); moved with G, which the game ignores: {r['own_grip']['moved_with_g'] or 'none'}")
        if r["role"] == "muzzle":     # held by the carrier pistol, already in the reference model's frame
            rel = m
        else:
            rel = ref_m.inverted() @ m
        loc, q, sc = rel.decompose()
        # Blender frame of an imported glb -> glTF frame: the relative transform conjugated by CM
        g = CM @ rel @ CM.inverted()
        gl, gq, gs = g.decompose()
        r["rel_scale"] = round(sc.x, 5)
        r["rel_pos"] = [round(c, 5) for c in gl]
        r["rel_quat"] = [round(gq.x, 5), round(gq.y, 5), round(gq.z, 5), round(gq.w, 5)]
        r["rel_turn_deg"] = round(math.degrees(gq.angle), 2)
        r["length_vs_reference"] = round(r["length_native"] * r["scale_in_holder"] / (ref_len * ref_scale), 4) if r["role"] != "muzzle" else None
        r["changed_from_start"] = None if r["role"] == "reference" else round(r["scale_in_holder"] / ref_scale / r["start_factor"] if r["start_factor"] else 0.0, 4)
        r["reshaped"] = r["rms_in_holder"] / r["scale_in_holder"] * ref_scale > 1e-4
        r["scale_in_holder"] = round(r["scale_in_holder"], 6); r["rms_in_holder"] = round(r["rms_in_holder"], 7)
        out["models"][k] = r
        print(f"[family_lab] {k:40s} x{r['rel_scale']:.4f} of the ref units, length {r['length_vs_reference'] if r['length_vs_reference'] is not None else '-':>6} x ref, "
              f"turn {r['rel_turn_deg']:6.2f} deg, pos {r['rel_pos']}, size vs start {r['changed_from_start']}, rms {r['rms_in_holder']:.2e}{' RESHAPED' if r['reshaped'] else ''}")
    os.makedirs(os.path.dirname(out_json), exist_ok=True)
    with open(out_json, "w") as f:
        json.dump(out, f, indent=1)
    print(f"[family_lab] wrote {out_json}")


def grip(blend, key, out_json):
    """Agent `key`'s whole pose as a pose file, its model in its hand (the module's header: a model with a grip of its own). The pose:
    every bone's Godot local rotation and the Hips' place, by `tripo_pose_lab.Rig` (the maths `sequence` and `extract` use); the model:
    its scene root's placement in the hand bone's frame, the source fitted as the read-back fits it. The id is the file's name. Proof it
    is the same maths: on Agent 01 it gives back the timeline's own stop file (`seq_draw_shotgun_f31.json` for H3's aim)."""
    sys.path.insert(0, os.path.join(ROOT, "tools", "asset_generation", "tripo"))
    import tripo_pose_lab as tpl
    bpy.ops.wm.open_mainfile(filepath=blend)
    bpy.context.view_layer.update()
    guns = [o for o in bpy.data.objects if o.name.startswith("GUN_") and o.get("lab_role") != "carrier"]
    ob = next((o for o in guns if o.name[4:] == key or o.name[4:6] == key), None)
    ref = next((o for o in guns if o.get("lab_role") == "reference"), None)
    if ob is None or ref is None:
        fail(f"no GUN_{key} (or no reference) in {os.path.basename(blend)}")
    arm, ref_arm = ob.parent, ref.parent
    if ob.parent_type != "BONE" or ref.parent_type != "BONE" or "lab_rest" not in ref_arm:
        fail(f"GUN_{key}: not held by an Agent's bone in a lab file built on a pose_lab timeline (no lab_rest)")
    rig = tpl.Rig(arm, json.loads(ref_arm["lab_rest"]))      # the Agents share the reference's armature data: its rest is theirs
    local, G = rig.read()
    ignored = [pb.name.replace(PREFIX, "") for pb in arm.pose.bones if pb.name != PREFIX + "Hips" and pb.location.length > 1e-4]
    if ignored:
        print(f"[family_lab] WARNING: {', '.join(ignored)} MOVED with G: the game plays rotations only, so these joints close where their rotation puts them")
    bone = ob.parent_bone
    pb = arm.pose.bones[bone]
    mesh_frame = _mesh_frame(ob)
    sp = _source_points(ob, mesh_frame)
    s, R, t, rms = _fit_in(ob, sp, arm.matrix_world @ pb.matrix)
    if rms / s > 1e-4:
        print(f"[family_lab] WARNING: GUN_{key} was RESHAPED (fit rms {rms:.2e}): the pose file keeps the model's shape, at the closest fit")
    root_g = CM @ (pb.matrix @ _sim(s, R, t) @ mesh_frame) @ CM.inverted()    # the model's scene root: glTF axes, the armature's space
    node = G[bone.replace(PREFIX, "")].to_4x4()
    node.translation = tpl.CM @ pb.head
    loc, rot, scl = (node.inverted() @ root_g).decompose()
    prop = re.sub(r"[^a-z0-9]+", "_", ob.name[7:].split(" (")[0].lower()).strip("_")
    changed = _reposed(arm, ref_arm) if arm is not ref_arm else None
    out = {"format": "infiltraitor-pose", "v": 1, "figure": ref_arm["lab_figure"], "id": os.path.splitext(os.path.basename(out_json))[0],
           "bones": {n: tpl.xyzw(local[n]) for n in rig.names},
           "props": {prop: {"bone": bone.replace(PREFIX, ""), "pos": [loc.x, loc.y, loc.z], "quat": tpl.xyzw(rot), "scale": (scl.x + scl.y + scl.z) / 3.0}},
           "hips_pos": list(tpl.CM @ arm.pose.bones[PREFIX + "Hips"].matrix.translation),
           "lab": {"file": os.path.basename(blend), "agent": ob.name[4:], "source": ob["lab_source"], "family_pose": ref_arm.get("lab_aim", ""),
                   "bones_changed": [b[0] for b in changed] if changed else [], "moved_with_g_ignored": ignored,
                   "note": "a model's own grip, kept for POLISH-01: nothing in the game reads this file yet; the prop key is the lab model's "
                           "name until its weapon row exists"}}
    os.makedirs(os.path.dirname(out_json), exist_ok=True)
    with open(out_json, "w") as f:
        json.dump(out, f, indent=1)
    print(f"[family_lab] wrote {out_json}: Agent {ob.name[4:]}, {len(out['bones'])} bones ({len(out['lab']['bones_changed'])} changed from the family's), "
          f"{prop} on the {bone.replace(PREFIX, '')} x{out['props'][prop]['scale']:.5f} (fit rms {rms:.1e})")


def _curves(ad):
    """The F-curves of an animation data block (a layered action's channel bags, or a legacy action's curves)."""
    if ad is None or ad.action is None:
        return []
    act = ad.action
    if getattr(act, "layers", None):
        return [fc for l in act.layers for st in l.strips for cb in st.channelbags for fc in cb.fcurves]
    return list(act.fcurves)


def seq(family_blend, key, out_blend, stops):
    """A MODEL'S OWN DRAW TIMELINE (2026-11-24, the Director on the bullpup, its hip and aim grips saved: "Ainda vai ficar faltando o draw, porque ele vai ter
    que segurar em outra parte do cabo. Vamos montar no Blender toda a sequência da mira só com essa arma"). The family's timeline (his
    `SEQ_draw_shotgun_<FIG>.blend`: read, never saved) with model `key` in the reference's place:
      - at each stop a lab scene names (`stops`: {marker: lab .blend}, the scene built on this timeline at that marker), that scene's Agent: its
        rotations and the Hips' place keyed on the timeline (the game reads nothing else: a finger moved with G there is not carried), the model at its
        place in the Agent's hand;
      - before the first of them, the family's body and the family's draw, the model held at the reference's HOLD point (`LONG_HOLD_AT` of its own length,
        on its barrel, in the lab's explicit gun frame) wherever the reference is held: his scaffold for the draw, which he poses on this timeline;
      - between those stops the hand SLIDES along the model (`_bake_slide`: Blender's own interpolation of two places on a bone swings the gun off the hand).
    The coat's keys, the markers and the range stay the family's. Written as a new file, never over one."""
    sys.path.insert(0, os.path.join(ROOT, "tools", "asset_generation", "tripo"))
    import tripo_pose_lab as tpl
    if os.path.exists(out_blend):
        fail(f"{os.path.relpath(out_blend, ROOT)} exists: it holds the Director's work and is never rebuilt")
    grips, prop, source, gframe, factor = {}, None, None, None, None
    for marker, lab in stops.items():
        bpy.ops.wm.open_mainfile(filepath=lab)
        bpy.context.view_layer.update()
        guns = [o for o in bpy.data.objects if o.name.startswith("GUN_") and o.get("lab_role") != "carrier"]
        ob = next((o for o in guns if o.name[4:] == key or o.name[4:6] == key), None)
        ref = next((o for o in guns if o.get("lab_role") == "reference"), None)
        if ob is None or ref is None or ob.parent_type != "BONE":
            fail(f"{os.path.basename(lab)}: no GUN_{key} held by an Agent's bone (or no reference)")
        arm = ob.parent
        if any(pb.rotation_mode != "QUATERNION" for pb in arm.pose.bones):
            fail(f"{os.path.basename(lab)}: Agent {ob.name[4:]} has a bone in an Euler mode: the timeline keys quaternions")
        mesh_frame = _mesh_frame(ob)
        s, R, t, _rms = _fit_in(ob, _source_points(ob, mesh_frame), arm.matrix_world @ arm.pose.bones[ob.parent_bone].matrix)
        name = re.sub(r"[^a-z0-9]+", "_", ob.name[7:].split(" (")[0].lower()).strip("_")
        if prop not in (None, name) or source not in (None, ob["lab_source"]):
            fail(f"the stops hold different models ({prop}, {name})")
        prop, source, factor = name, ob["lab_source"], s
        gframe = json.loads(ob["lab_gun_frame"]) if "lab_gun_frame" in ob else [["Z", float(ob.get("lab_turn_deg", 0.0))]]
        grips[marker] = {"rot": {pb.name: pb.rotation_quaternion.copy() for pb in arm.pose.bones},
                         "hips": arm.pose.bones[PREFIX + "Hips"].location.copy(),
                         "m": _sim(s, R, t) @ mesh_frame,      # the glb's scene root (import coordinates) -> the hand bone's frame
                         "bone": ob.parent_bone, "built_on": ref.parent.get("lab_aim", ""), "lab": os.path.basename(lab)}
        print(f"[family_lab] {marker}: {os.path.basename(lab)} Agent {ob.name[4:]} (built on {grips[marker]['built_on']}), {prop} x{s:.5f} in its hand")
    if os.path.normpath(os.path.join(ROOT, source)) != os.path.normpath(tpl.PROP_GLB.get(prop, "")):
        fail(f"tripo_pose_lab.PROP_GLB['{prop}'] must be {source} (the timeline's read-back loads the model from there)")

    bpy.ops.wm.open_mainfile(filepath=family_blend)      # his timeline: read here, never saved (the model's is saved as a new file)
    sc = bpy.context.scene
    arm, rig = tpl.load_rig_from_blend()
    bpy.context.view_layer.objects.active = arm
    if arm.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")
    markers = {m.name: m.frame for m in sc.timeline_markers}
    fam_prop = json.loads(arm["lab_props"])[0]
    fgun = bpy.data.objects.get("PROP_" + fam_prop)
    if fgun is None or fgun.parent is not arm:
        fail(f"{os.path.basename(family_blend)}: no PROP_{fam_prop} on the armature")
    for marker, g in grips.items():
        base, _sep, frame = g["built_on"].rpartition("@")
        if marker not in markers or base != os.path.basename(family_blend) or not frame.isdigit() or int(frame) != markers[marker]:
            fail(f"{g['lab']} was built on {g['built_on']}, this timeline's '{marker}' is frame {markers.get(marker)} of {os.path.basename(family_blend)}")
        if g["bone"] != fgun.parent_bone:
            fail(f"{g['lab']} holds the model on {g['bone']}, the timeline on {fgun.parent_bone}")
    grip_frames = sorted(markers[m] for m in grips)
    draw_end = max(f for f in markers.values() if f < grip_frames[0])          # the last marker of the family's draw before the first grip (the centre)
    hand_bone = fgun.parent_bone

    def hand_world():
        return arm.matrix_world @ arm.pose.bones[hand_bone].matrix

    def palm_world():
        h, m1 = arm.pose.bones[PREFIX + "LeftHand"], arm.pose.bones[PREFIX + "LeftHandMiddle1"]
        return arm.matrix_world @ ((h.head + m1.head) * 0.5)

    # the family's gun on the hand at each of its keys up to the draw's end (a hidden object is not re-evaluated: its frames take the first shown place)
    keyed = sorted({round(k.co[0]) for fc in _curves(fgun.animation_data) for k in fc.keyframe_points})
    fam = {}
    for f in [f for f in keyed if f <= draw_end]:
        sc.frame_set(f)
        bpy.context.view_layer.update()
        fam[f] = [hand_world().inverted() @ fgun.matrix_world, fgun.hide_viewport, fgun.hide_render]
    shown = next((fam[f][0] for f in sorted(fam) if not fam[f][1]), None)
    for f in fam:
        if fam[f][1] and shown is not None:
            fam[f][0] = shown

    # the model as the game reads it; the reference's hold point matched by the model's own (its gun frame the lab's, its size the lab's)
    probe, _ns = tpl.import_prop(fam_prop, {})
    W0s = probe.matrix_world.copy()
    Fs, ps, _Ls = tpl._gun_frame_points(probe, tpl.LONG_GUN_FACTOR)
    bpy.data.objects.remove(probe)
    gun, node_scale = tpl.import_prop(prop, {})
    W0b = gun.matrix_world.copy()
    Fb, pb_pts, Lb = tpl._gun_frame_points(gun, factor, turn=gun_frame_matrix(gframe))
    K = (Fs @ W0s).inverted() @ Matrix.Translation(ps["hold"] - pb_pts["hold"]) @ (Fb @ W0b)
    print(f"[family_lab] {prop}: {Lb:.3f} long at x{factor:.5f}; held in the draw at its hold {tuple(round(v, 3) for v in pb_pts['hold'])} where the "
          f"{fam_prop} is held at its own")

    # the body at each grip: the lab Agent's rotations and Hips, keyed over the family's keys at that frame
    for marker, g in grips.items():
        f = markers[marker]
        sc.frame_set(f)
        for pb in arm.pose.bones:
            if pb.rotation_mode != "QUATERNION":
                fail(f"{os.path.basename(family_blend)}: {pb.name} is not in quaternions")
            pb.rotation_quaternion = g["rot"][pb.name]
            pb.keyframe_insert("rotation_quaternion", frame=f)
        hb = arm.pose.bones[PREFIX + "Hips"]
        hb.location = g["hips"]
        hb.keyframe_insert("location", frame=f)

    # the model on the hand: the family's draw keys (the hold matched), each grip's place, the slides between
    bpy.data.objects.remove(fgun)
    gun.parent = arm
    gun.parent_type = "BONE"
    gun.parent_bone = grips[next(iter(grips))]["bone"]
    gun.rotation_mode = "QUATERNION"
    gun["lab_node_scale"] = node_scale
    gun["lab_bone"] = gun.parent_bone.replace(PREFIX, "")
    places = {f: (A @ K, hv, hr) for f, (A, hv, hr) in fam.items()}
    for marker, g in grips.items():
        places[markers[marker]] = (g["m"] @ W0b, False, False)
    for f in sorted(places):
        A, hv, hr = places[f]
        sc.frame_set(f)
        bpy.context.view_layer.update()
        gun.matrix_world = hand_world() @ A
        gun.hide_viewport, gun.hide_render = hv, hr
        bpy.context.view_layer.update()
        for path in ("location", "rotation_quaternion", "scale", "hide_viewport", "hide_render"):
            gun.keyframe_insert(path, frame=f)
    ends = [draw_end] + grip_frames
    for f0, f1 in zip(ends, ends[1:]):
        c = []
        for f in (f0, f1):
            sc.frame_set(f)
            bpy.context.view_layer.update()
            c.append(gun.matrix_world.inverted() @ palm_world())       # the model's point under the palm
        tpl._bake_slide(sc, arm, gun, f0, f1, c[0], c[1])
        print(f"[family_lab] frames {f0}-{f1}: the hand slides {(c[1] - c[0]).length * gun.matrix_world.to_scale().x * 1000:.0f} mm along the {prop}")
    arm["lab_pose"] = "draw_" + prop
    arm["lab_props"] = json.dumps([prop])
    arm["lab_grips"] = json.dumps({m: g["lab"] for m, g in grips.items()})
    sc.frame_set(1)
    for o in bpy.data.objects:
        o.select_set(False)
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="POSE")
    os.makedirs(os.path.dirname(out_blend), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=out_blend)
    print(f"[family_lab] wrote {os.path.relpath(out_blend, ROOT)}: the {arm['lab_figure']} {prop} draw on {os.path.basename(family_blend)}'s keys, "
          f"{', '.join(f'{m} {markers[m]}' for m in grips)} from the lab scenes, the draw to {draw_end} the family's")


IN_STEP_PALM_CM = 4.0    # her right hand goes onto the model at the stops where his right palm is within this of it (the 2026-11-23 recipe: his aim at 3.8 cm)


def _palm(arm, side):
    """The palm's centre (between the hand's head and the middle finger's root), world space."""
    pb = arm.pose.bones
    return arm.matrix_world @ ((pb[PREFIX + side + "Hand"].head + pb[PREFIX + side + "HandMiddle1"].head) * 0.5)


def _bvh_world(ob):
    """The object's evaluated surface in world space, for nearest-point queries."""
    from mathutils.bvhtree import BVHTree
    ev = ob.evaluated_get(bpy.context.evaluated_depsgraph_get())
    me = ev.to_mesh()
    tree = BVHTree.FromPolygons([ob.matrix_world @ v.co for v in me.vertices], [tuple(p.vertices) for p in me.polygons])
    ev.to_mesh_clear()
    return tree


def _coat_keys():
    """The open timeline's coat: its animated values and a digest of each shape key, to tell whether two timelines share one coat."""
    import array, hashlib
    coat = bpy.data.objects.get("Outfit_Coat")
    if coat is None or coat.data.shape_keys is None:
        return None
    sk = coat.data.shape_keys
    values = sorted((fc.data_path, fc.array_index, tuple((round(k.co[0], 4), round(k.co[1], 6)) for k in fc.keyframe_points))
                    for fc in _curves(sk.animation_data))
    shapes = {}
    for kb in sk.key_blocks:
        co = array.array("f", [0.0]) * (len(kb.data) * 3)
        kb.data.foreach_get("co", co)
        shapes[kb.name] = hashlib.sha1(co.tobytes()).hexdigest()
    return {"values": values, "shapes": shapes}


def _timeline(path, frames=None, model=False):
    """One of his timelines, read (never saved) at `frames` (default: the frames its armature is keyed on): each bone's rotation and the Hips' place.
    With `model`: its model's keys (the place against the hand's bone, read off the keys themselves), the model's visibility curves, and at each of
    those frames where the model is shown the right hand's place against it and the right palm's distance to it."""
    bpy.ops.wm.open_mainfile(filepath=path)
    sc = bpy.context.scene
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    keyed = sorted({round(k.co[0]) for fc in _curves(arm.animation_data) for k in fc.keyframe_points})
    out = {"keyed": keyed, "rot": {}, "hips": {}, "hip_h": (arm.matrix_world @ arm.data.bones[PREFIX + "Hips"].head_local).z,
           "props": json.loads(arm["lab_props"]), "pose": arm.get("lab_pose", ""), "figure": arm["lab_figure"], "coat": _coat_keys()}
    for f in (frames or keyed):
        sc.frame_set(f)
        out["rot"][f] = {pb.name: pb.rotation_quaternion.copy() for pb in arm.pose.bones}
        out["hips"][f] = arm.pose.bones[PREFIX + "Hips"].location.copy()
    if not model:
        return out
    gun = bpy.data.objects["PROP_" + out["props"][0]]
    hand = arm.pose.bones[gun.parent_bone]
    gkeyed = sorted({round(k.co[0]) for fc in _curves(gun.animation_data) if fc.data_path in ("location", "rotation_quaternion", "scale")
                     for k in fc.keyframe_points})
    out.update({"bone": gun.parent_bone, "gun_keyed": gkeyed, "in_hand": {}, "hidden": {}, "right_rel": {}, "palm_cm": {},
                "vis": [(fc.data_path, fc.array_index, [(tuple(k.co), k.interpolation) for k in fc.keyframe_points])
                        for fc in _curves(gun.animation_data) if fc.data_path.startswith("hide")]})
    if gun.rotation_mode != "QUATERNION":
        fail(f"{os.path.basename(path)}: PROP_{out['props'][0]} is not in quaternions")
    chans = {(fc.data_path, fc.array_index): fc for fc in _curves(gun.animation_data)}

    def key_values(f, path, n, now):
        return [chans[(path, i)].evaluate(f) if (path, i) in chans else now[i] for i in range(n)]

    # the place against the hand's bone read off the KEYS (a hidden object is not re-evaluated by Blender, so its matrix_world is stale there):
    # a child of a bone sits at the bone's tail; checked against the evaluated place wherever the model is shown
    tail = Matrix.Translation((0.0, hand.bone.length, 0.0)) @ gun.matrix_parent_inverse
    for f in gkeyed:
        sc.frame_set(f)
        bpy.context.view_layer.update()
        out["hidden"][f] = gun.hide_viewport
        out["in_hand"][f] = tail @ Matrix.LocRotScale(Vector(key_values(f, "location", 3, gun.location)),
                                                      Quaternion(key_values(f, "rotation_quaternion", 4, gun.rotation_quaternion)).normalized(),
                                                      Vector(key_values(f, "scale", 3, gun.scale)))
        if not gun.hide_viewport:
            ev = hand.matrix.inverted() @ (arm.matrix_world.inverted() @ gun.matrix_world)
            if max(abs(a - b) for ra, rb in zip(ev, out["in_hand"][f]) for a, b in zip(ra, rb)) > 1e-4:
                fail(f"{os.path.basename(path)}: PROP_{out['props'][0]}'s keys at {f} do not give its place on {gun.parent_bone}")
    for f in (frames or keyed):
        sc.frame_set(f)
        bpy.context.view_layer.update()
        if not gun.hide_viewport:
            out["palm_cm"][f], out["right_rel"][f] = _right_on(arm, gun)
    return out


def _right_on(arm, gun):
    """The right palm's distance to the model (cm) and the right hand's place against the model (armature space), for the frame the scene is on."""
    rel = (arm.matrix_world.inverted() @ gun.matrix_world).inverted() @ arm.pose.bones[PREFIX + "RightHand"].matrix
    return _bvh_world(gun).find_nearest(_palm(arm, "Right"))[3] * 100.0, rel


def in_step(ref_blend, fin_blend, her_blend, out_blend):
    """THE FEMALE IN STEP WITH A MODEL'S OWN TIMELINE (2026-11-24, the Director: "Vamos começar primeiro fazendo a versão feminina", on the bullpup).
    His model timeline (`fin_blend`, `SEQ_draw_bullpup_MALE.blend`) is his family timeline (`ref_blend`, `SEQ_draw_shotgun_MALE.blend`) CHANGED; her
    family timeline (`her_blend`, `SEQ_draw_shotgun_FEMALE.blend`, read, never saved; its hip and aim are his own hand's, 2026-11-23) takes THAT CHANGE,
    never his poses over hers (his rule for her hip and aim: "a later male change there is carried by his hand, or by a delta that keeps his keys"):
      - her body, at each frame his model timeline is keyed on but the first (her idle stays hers): each bone's change from his family timeline to his
        model timeline put on hers (Δ = fin · ref⁻¹, left-multiplied), the fingers too (her own curl kept, his change on it); the Hips hers plus his
        change, scaled by the hip heights. A stop his model timeline dropped (keyed in his family timeline, not in his model timeline: the bullpup's
        18 and 20) is dropped on hers;
      - the model in her hand at HIS place against that hand's bone at each of its keys (the slides included: they are kept in the hand's frame), its
        visibility his;
      - her RIGHT hand ON the model at the stops where his palm is within IN_STEP_PALM_CM of it: his hand's place against the model, times HER OWN
        departure from his on the family's gun at that stop when both palms were on it there (her hip and aim by his hand), reached by a two-bone
        solve of her arm and forearm that keeps her elbow's bending plane and turns each bone the least (the 11-22 recipe's solve);
      - her coat, markers and range stay hers: his model timeline must keep his family's coat (checked; carrying a coat change is not built).
    With no change (his model timeline = his family timeline) her family timeline comes back key for key. Written as a new file, never over one."""
    sys.path.insert(0, os.path.join(ROOT, "tools", "asset_generation", "tripo"))
    import tripo_pose_lab as tpl
    if os.path.realpath(out_blend) in {os.path.realpath(p) for p in (ref_blend, fin_blend, her_blend)} or os.path.exists(out_blend):
        fail(f"{os.path.relpath(out_blend, ROOT)} exists or is an input: a timeline is never written over")
    fin = _timeline(fin_blend, model=True)
    ref = _timeline(ref_blend, frames=fin["keyed"], model=True)
    prop = fin["props"][0]
    if fin["figure"] != ref["figure"]:
        fail(f"{os.path.basename(fin_blend)} is the {fin['figure']}'s, {os.path.basename(ref_blend)} the {ref['figure']}'s")
    if fin["coat"] != ref["coat"]:
        fail(f"{os.path.basename(fin_blend)} changed the coat of {os.path.basename(ref_blend)}: carrying a coat change to her is not built")
    if prop not in tpl.PROP_GLB:
        fail(f"tripo_pose_lab.PROP_GLB has no '{prop}'")
    dropped = [f for f in ref["keyed"] if f not in fin["keyed"]]
    print(f"[family_lab] his {fin['pose']} keyed at {fin['keyed']}; his family's at {ref['keyed']}; dropped {dropped}; his right palm on the {prop} "
          f"(cm): {{{', '.join(f'{f}: {d:.2f}' for f, d in fin['palm_cm'].items())}}}")

    bpy.ops.wm.open_mainfile(filepath=her_blend)
    sc = bpy.context.scene
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    bpy.context.view_layer.objects.active = arm
    if arm.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")
    if json.loads(arm["lab_props"]) != ref["props"] or arm["lab_figure"] == fin["figure"]:
        fail(f"{os.path.basename(her_blend)}: the {arm['lab_figure']}'s {arm['lab_props']}, not the other figure's timeline of {ref['props']}")
    if any(pb.rotation_mode != "QUATERNION" for pb in arm.pose.bones):
        fail(f"{os.path.basename(her_blend)}: a bone in an Euler mode (the timeline keys quaternions)")
    old = bpy.data.objects.get("PROP_" + ref["props"][0])
    if old is None or old.parent is not arm or old.parent_bone != fin["bone"]:
        fail(f"{os.path.basename(her_blend)}: no PROP_{ref['props'][0]} on {fin['bone']}")
    her, her_on = {}, {}
    for f in fin["keyed"]:
        sc.frame_set(f)
        bpy.context.view_layer.update()
        her[f] = ({pb.name: pb.rotation_quaternion.copy() for pb in arm.pose.bones}, arm.pose.bones[PREFIX + "Hips"].location.copy())
        if not old.hide_viewport:
            her_on[f] = _right_on(arm, old)
    ratio = (arm.matrix_world @ arm.data.bones[PREFIX + "Hips"].head_local).z / fin["hip_h"]

    # her body: his change on her keys
    prev = dict(her[fin["keyed"][0]][0])
    worst = {}
    for f in fin["keyed"][1:]:
        for pb in arm.pose.bones:
            n = pb.name
            q = (fin["rot"][f][n] @ ref["rot"][f][n].inverted()) @ her[f][0][n]
            q.normalize()
            if q.dot(prev[n]) < 0.0:
                q.negate()
            prev[n] = q
            a = math.degrees(q.rotation_difference(her[f][0][n]).angle)
            worst[n] = max(worst.get(n, 0.0), min(a, 360.0 - a))
            pb.rotation_quaternion = q
            pb.keyframe_insert("rotation_quaternion", frame=f)
        hb = arm.pose.bones[PREFIX + "Hips"]
        hb.location = her[f][1] + (fin["hips"][f] - ref["hips"][f]) * ratio
        hb.keyframe_insert("location", frame=f)
    gone = 0
    for fc in _curves(arm.animation_data):
        while True:
            i = next((i for i, k in enumerate(fc.keyframe_points) if round(k.co[0]) in dropped), None)
            if i is None:
                break
            fc.keyframe_points.remove(fc.keyframe_points[i])
            gone += 1
        fc.update()
    big = sorted(((round(v, 1), n.replace(PREFIX, "")) for n, v in worst.items() if not tpl.is_finger(n)), reverse=True)[:8]
    print(f"[family_lab] her body: his change at {fin['keyed'][1:]} (hip ratio {ratio:.4f}); {gone} keys dropped at {dropped}; the largest turns "
          f"from her own pose: {big}")

    # the model in her hand at his place against the hand's bone
    bpy.data.objects.remove(old)
    gun, node_scale = tpl.import_prop(prop, {})
    gun.parent = arm
    gun.parent_type = "BONE"
    gun.parent_bone = fin["bone"]
    gun.rotation_mode = "QUATERNION"
    gun["lab_node_scale"] = node_scale
    gun["lab_bone"] = fin["bone"].replace(PREFIX, "")
    hand = arm.pose.bones[fin["bone"]]
    gprev = None
    for f in fin["gun_keyed"]:
        sc.frame_set(f)
        bpy.context.view_layer.update()
        gun.matrix_world = arm.matrix_world @ hand.matrix @ fin["in_hand"][f]
        bpy.context.view_layer.update()
        if gprev is not None and gun.rotation_quaternion.dot(gprev) < 0.0:
            gun.rotation_quaternion = -gun.rotation_quaternion
        gprev = gun.rotation_quaternion.copy()
        for path in ("location", "rotation_quaternion", "scale"):
            gun.keyframe_insert(path, frame=f)
    for path, idx, keys in fin["vis"]:
        gun.keyframe_insert(path, frame=keys[0][0][0])
        fc = next(c for c in _curves(gun.animation_data) if c.data_path == path and c.array_index == idx)
        fc.keyframe_points.clear()
        fc.keyframe_points.add(len(keys))
        for kp, (co, interp) in zip(fc.keyframe_points, keys):
            kp.co = co
            kp.interpolation = interp
        fc.update()
    print(f"[family_lab] the {prop} in her {fin['bone'].replace(PREFIX, '')} at his place at {len(fin['gun_keyed'])} keys; visibility his")

    # her right hand where his is on the model
    up, fore, rh = (arm.pose.bones[PREFIX + n] for n in ("RightArm", "RightForeArm", "RightHand"))

    def turn_bone(bone, head, new_dir):
        cur = bone.matrix.to_3x3().normalized()
        rot = (cur @ Vector((0.0, 1.0, 0.0))).rotation_difference(new_dir.normalized()).to_matrix()
        bone.matrix = Matrix.Translation(head) @ (rot @ cur).to_4x4()
        bpy.context.view_layer.update()

    for f in [f for f in fin["keyed"] if fin["palm_cm"].get(f, 1e9) <= IN_STEP_PALM_CM]:
        sc.frame_set(f)
        bpy.context.view_layer.update()
        before = _bvh_world(gun).find_nearest(_palm(arm, "Right"))[3]
        old_q = {b.name: b.rotation_quaternion.copy() for b in (up, fore, rh)}
        dep = Matrix.Identity(4)      # her own departure from his hand's place on the family's gun, when both were on it here
        if ref["palm_cm"].get(f, 1e9) <= IN_STEP_PALM_CM and her_on.get(f, (1e9, None))[0] <= IN_STEP_PALM_CM:
            dep = ref["right_rel"][f].inverted() @ her_on[f][1]
        target = (arm.matrix_world.inverted() @ gun.matrix_world) @ fin["right_rel"][f] @ dep
        W, S, E0 = target.to_translation(), up.head.copy(), fore.head.copy()
        L1, L2 = up.bone.length, fore.bone.length
        d = min((W - S).length, (L1 + L2) * 0.9999)
        u = (W - S).normalized()
        bend = (E0 - S) - u * (E0 - S).dot(u)
        v = bend.normalized() if bend.length > 1e-6 else u.orthogonal().normalized()
        a = (L1 * L1 - L2 * L2 + d * d) / (2.0 * d)
        E = S + u * a + v * math.sqrt(max(L1 * L1 - a * a, 0.0))
        turn_bone(up, S, E - S)
        turn_bone(fore, fore.head.copy(), (S + u * d) - fore.head)
        rh.matrix = Matrix.Translation(rh.head.copy()) @ target.to_3x3().normalized().to_4x4()
        bpy.context.view_layer.update()
        for b in (up, fore, rh):
            if b.rotation_quaternion.dot(old_q[b.name]) < 0.0:
                b.rotation_quaternion = -b.rotation_quaternion
            b.keyframe_insert("rotation_quaternion", frame=f)
        after = _bvh_world(gun).find_nearest(_palm(arm, "Right"))[3]
        _l, dq, _s = dep.decompose()
        sw = arm.matrix_world.to_scale().x * 100.0      # armature units -> cm
        print(f"[family_lab] {f}: her right palm to the {prop} {before * 100:.2f} -> {after * 100:.2f} cm (his {fin['palm_cm'][f]:.2f}); her own "
              f"departure from his hand kept: {dep.to_translation().length * sw:.2f} cm, {math.degrees(dq.angle):.1f} deg; wrist missed by "
              f"{(rh.head - W).length * sw:.2f} cm")

    arm["lab_pose"] = fin["pose"]
    arm["lab_props"] = json.dumps([prop])
    arm["lab_in_step"] = json.dumps({"his_model": os.path.basename(fin_blend), "his_family": os.path.basename(ref_blend),
                                     "her_family": os.path.basename(her_blend)})
    sc.frame_set(1)
    for o in bpy.data.objects:
        o.select_set(False)
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="POSE")
    os.makedirs(os.path.dirname(out_blend), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=out_blend)
    print(f"[family_lab] wrote {os.path.relpath(out_blend, ROOT)}: the {arm['lab_figure']} {prop} draw in step with {os.path.basename(fin_blend)}, "
          f"on {os.path.basename(her_blend)}'s keys")


RAISE_BULGE_M = 0.06     # how far forward of the straight line the gun's origin bows at mid-raise (the female's bullpup, 2026-11-24: 6 cm keeps her
                         # left arm at 97 % of its reach; 8 cm takes all of it and 10 cm more than it has, the wrist then missing by 1.3 cm)


def _ease(t):
    """The raise's timing: a smoothstep, the game's own easing between two resting stops (`ActorAimPose3D`)."""
    return t * t * (3.0 - 2.0 * t)


def _blend_matrix(M0, M1, s):
    """Two places mixed: the offsets and the scales linearly, the turns by slerp."""
    l0, q0, s0 = M0.decompose()
    l1, q1, s1 = M1.decompose()
    sc = s0.lerp(s1, s)
    return Matrix.Translation(l0.lerp(l1, s)) @ q0.slerp(q1, s).to_matrix().to_4x4() @ Matrix.Diagonal((sc.x, sc.y, sc.z, 1.0))


def _reach(arm, side, target):
    """The arm of `side` solved so its hand bone takes `target` (armature space: place and turn): the elbow kept in the bending plane it has now,
    each bone turned the least (in_step's solve). Returns how far the wrist misses (cm) and the share of the arm's length the reach needs."""
    pb = arm.pose.bones
    up, fore, hand = pb[PREFIX + side + "Arm"], pb[PREFIX + side + "ForeArm"], pb[PREFIX + side + "Hand"]

    def turn(bone, head, new_dir):
        cur = bone.matrix.to_3x3().normalized()
        rot = (cur @ Vector((0.0, 1.0, 0.0))).rotation_difference(new_dir.normalized()).to_matrix()
        bone.matrix = Matrix.Translation(head) @ (rot @ cur).to_4x4()
        bpy.context.view_layer.update()

    W, S, E0 = target.to_translation(), up.head.copy(), fore.head.copy()
    L1, L2 = up.bone.length, fore.bone.length
    d = min((W - S).length, (L1 + L2) * 0.9999)
    u = (W - S).normalized()
    bend = (E0 - S) - u * (E0 - S).dot(u)
    v = bend.normalized() if bend.length > 1e-6 else u.orthogonal().normalized()
    a = (L1 * L1 - L2 * L2 + d * d) / (2.0 * d)
    E = S + u * a + v * math.sqrt(max(L1 * L1 - a * a, 0.0))
    turn(up, S, E - S)
    turn(fore, fore.head.copy(), (S + u * d) - fore.head)
    hand.matrix = Matrix.Translation(hand.head.copy()) @ target.to_3x3().normalized().to_4x4()
    bpy.context.view_layer.update()
    return (hand.head - W).length * arm.matrix_world.to_scale().x * 100.0, (W - S).length / (L1 + L2)


def raise_from_gun(src_blend, out_blend, f0, f1, breakdowns, bulge=RAISE_BULGE_M, yaw_deg=0.0, yaw_end=1.0, bulge_end=None):
    """THE RAISE REBUILT FROM THE GUN (2026-11-24, the Director on the female's bullpup, after posing her draw and aim: "o movimento nos últimos
    frames está meio duro. Da uma conferida e veja se consegue suavizar. As poses estão corretas"; on the result: "Pode instalar").
    Measured on his save: a breakdown of the left arm at 27 took the gun out of the coat by turning it ~50 degrees to her left; it came back
    in the last three frames (20 degrees a frame), cut through the hat and the head at 30 and stopped dead at 31, and the right hand hung up
    to 7.5 cm off the grip while the left one carried the gun alone. Without that breakdown the gun rises through the coat. Rebuilt:
      - the stops at f0 and f1 untouched, body and gun as saved (the hip and the aim are his poses);
      - the gun's path between them: its turn slerped straight from f0's to f1's (the muzzle stays on the target), its origin on a cubic arc
        bowed FORWARD by `bulge` (out of the coat), timed by a smoothstep (`_ease`);
      - at each breakdown frame both hands ON it: the left at the slide's place (the palm's point of the gun from f0's to f1's while the gun
        turns in the hand from f0's hold to f1's: `tripo_pose_lab._bake_slide`'s formula, on the same smoothstep), the right at its own place
        on the gun mixed from f0's to f1's; each arm by `_reach`; their keys there replace what was keyed (a shoulder's own key stays);
      - the gun keyed on the left hand at every frame between, on the same smoothstep (the slide), so it rides the hand.
    Between the breakdowns Blender's own interpolation of the arms keeps both palms within a centimetre of their holds (measured on the
    bullpup: left 0.5-1.0 cm, right 2.1-2.8 cm, as at the stops). The read-back makes each breakdown a PASSING stop; the game eases a span
    between two resting stops with its own smoothstep and passes these linearly, so the spacing they carry is eased a second time when the
    game plays a model's own timeline (POLISH-01).
    THE BUTT KEPT OUT OF THE COAT (2026-11-26, the Director: "evitar que as armas entrem no casaco durante as movimentações"): on every stocked
    long gun the straight raise takes the butt up the coat's right front (the family shotgun's own raise, in the game: up to 22 coat
    triangles at 25; the stockless sawed-off is clean), and a larger forward bow does not cure it (the left arm runs out of reach first).
    `yaw_deg` also TURNS the gun about the vertical through the left palm in mid-raise, a sin(pi s / yaw_end) bump (the muzzle to the
    figure's left, the butt out beside the coat's flank, back into the shoulder by the end; `yaw_end` < 1 ends the turn earlier); the
    left hand keeps its place on the gun and turns with it. `bulge_end` bows the arc's second control point by its own amount. The short
    stock: the female 4 cm and 15 deg, the male 3 cm and 25 deg (his coat is wider). With the defaults (no turn) the raise is as before.
    Written as a new file, never over one."""
    if os.path.abspath(src_blend) == os.path.abspath(out_blend) or os.path.exists(out_blend):
        fail(f"{os.path.relpath(out_blend, ROOT)}: the raise is written as a new file, never over one")
    if not breakdowns or not all(f0 < f < f1 for f in breakdowns):
        fail(f"breakdowns {breakdowns} must lie strictly between {f0} and {f1}")
    bpy.ops.wm.open_mainfile(filepath=src_blend)
    sc = bpy.context.scene
    arm = next((o for o in bpy.data.objects if o.type == "ARMATURE"), None)
    gun = next((o for o in bpy.data.objects if o.name.startswith("PROP_")), None)
    if arm is None or gun is None or gun.parent is not arm or gun.parent_bone != PREFIX + "LeftHand":
        fail(f"{os.path.basename(src_blend)}: no PROP_ riding the armature's LeftHand (the slide is the left hand's)")
    keyed = {round(k.co[0]) for fc in _curves(arm.animation_data) for k in fc.keyframe_points}
    if f0 not in keyed or f1 not in keyed:
        fail(f"{os.path.basename(src_blend)}: the armature is not keyed at {f0} and {f1} (the raise runs between two stops)")
    inv = arm.matrix_world.inverted()

    def hand_w(side):
        return arm.matrix_world @ arm.pose.bones[PREFIX + side + "Hand"].matrix

    end = {}
    for f in (f0, f1):
        sc.frame_set(f)
        bpy.context.view_layer.update()
        if gun.hide_viewport:
            fail(f"the {gun.name} is hidden at {f}: its place there is not evaluated")
        G = gun.matrix_world.copy()
        end[f] = {"G": G, "A": hand_w("Left").inverted() @ G, "c": G.inverted() @ _palm(arm, "Left"), "R": G.inverted() @ hand_w("Right")}
    P0, Q0, S0 = end[f0]["G"].decompose()
    P1, Q1, S1 = end[f1]["G"].decompose()
    pts = [v.co for v in gun.data.vertices]
    ext = [max(c[i] for c in pts) - min(c[i] for c in pts) for i in range(3)]
    axis = ext.index(max(ext))                        # the barrel: the model's longest axis
    barrel = end[f1]["G"].to_3x3().normalized() @ Vector([1.0 if i == axis else 0.0 for i in range(3)])
    fwd = Vector((barrel.x, barrel.y, 0.0)).normalized()
    if fwd.dot(Vector((0.0, -1.0, 0.0))) < 0.0:       # every Agent faces -Y: the muzzle's end of the axis
        fwd = -fwd
    if fwd.dot(Vector((0.0, -1.0, 0.0))) < 0.7:
        fail(f"the barrel at {f1} points {tuple(round(v, 2) for v in fwd)}, not ahead of the Agent (-Y)")
    _l, qa0, sa0 = end[f0]["A"].decompose()
    _l, qa1, sa1 = end[f1]["A"].decompose()
    c0, c1 = end[f0]["c"], end[f1]["c"]
    p0, p1 = end[f0]["A"] @ c0, end[f1]["A"] @ c1

    def in_hand(s):
        sc_ = sa0.lerp(sa1, s)
        return (Matrix.Translation(p0.lerp(p1, s)) @ qa0.slerp(qa1, s).to_matrix().to_4x4() @ Matrix.Diagonal((sc_.x, sc_.y, sc_.z, 1.0))
                @ Matrix.Translation(-c0.lerp(c1, s)))

    def gun_at(s):
        b1, b2, u = P0 + fwd * bulge, P1 + fwd * (bulge if bulge_end is None else bulge_end), 1.0 - s
        pos = P0 * (u ** 3) + b1 * (3.0 * u * u * s) + b2 * (3.0 * u * s * s) + P1 * (s ** 3)
        sc_ = S0.lerp(S1, s)
        G = Matrix.Translation(pos) @ Q0.slerp(Q1, s).to_matrix().to_4x4() @ Matrix.Diagonal((sc_.x, sc_.y, sc_.z, 1.0))
        if not yaw_deg or s >= yaw_end:
            return G
        piv = G @ c0.lerp(c1, s)                      # the left palm's point on the gun: the turn's pivot
        ang = math.radians(yaw_deg) * math.sin(math.pi * s / yaw_end)
        return Matrix.Translation(piv) @ Matrix.Rotation(ang, 4, Vector((0.0, 0.0, 1.0))) @ Matrix.Translation(-piv) @ G

    print(f"[family_lab] raise {f0}-{f1} of {os.path.basename(src_blend)}: the {gun.name} turns {math.degrees(Q0.rotation_difference(Q1).angle):.1f} deg and "
          f"travels {(P1 - P0).length * 100:.1f} cm, bowed {bulge * 100:.0f} cm forward"
          f"{'' if bulge_end is None else f' ({bulge_end * 100:.0f} cm at its end)'}{f', turned {yaw_deg:.0f} deg at mid-raise' if yaw_deg else ''}; "
          f"the left hand slides {(c1 - c0).length * S0.x * 1000:.0f} mm along it")
    names = [s + b for s in ("Left", "Right") for b in ("Arm", "ForeArm", "Hand")]
    for f in sorted(breakdowns):
        s = _ease((f - f0) / float(f1 - f0))
        sc.frame_set(f)
        bpy.context.view_layer.update()
        before = {n: arm.pose.bones[PREFIX + n].rotation_quaternion.copy() for n in names}
        Gs = gun_at(s)
        missL, reachL = _reach(arm, "Left", inv @ Gs @ in_hand(s).inverted())
        missR, reachR = _reach(arm, "Right", inv @ Gs @ _blend_matrix(end[f0]["R"], end[f1]["R"], s))
        for n in names:                                   # keyed only once both arms are solved: a key re-reads the animation on the next update
            b = arm.pose.bones[PREFIX + n]
            if b.rotation_quaternion.dot(before[n]) < 0.0:
                b.rotation_quaternion = -b.rotation_quaternion
            b.keyframe_insert("rotation_quaternion", frame=f)
        if max(missL, missR) > 0.5:
            print(f"[family_lab] WARNING: at {f} a wrist misses by {max(missL, missR):.2f} cm (out of reach): a smaller bulge keeps the arm in reach")
        print(f"[family_lab] breakdown {f} ({s * 100:.0f} % of the raise): left wrist off by {missL:.2f} cm at {reachL * 100:.0f} % of its reach, "
              f"right by {missR:.2f} cm at {reachR * 100:.0f} %")
    for f in range(f0 + 1, f1):
        for path in ("location", "rotation_quaternion", "scale"):
            try:
                gun.keyframe_delete(path, frame=f)
            except RuntimeError:
                pass
    sc.frame_set(f0)
    bpy.context.view_layer.update()
    qprev = gun.rotation_quaternion.copy()
    for f in range(f0 + 1, f1):
        sc.frame_set(f)
        bpy.context.view_layer.update()
        gun.matrix_world = hand_w("Left") @ in_hand(_ease((f - f0) / float(f1 - f0)))
        bpy.context.view_layer.update()
        if gun.rotation_quaternion.dot(qprev) < 0.0:
            gun.rotation_quaternion = -gun.rotation_quaternion
        qprev = gun.rotation_quaternion.copy()
        for path in ("location", "rotation_quaternion", "scale"):
            gun.keyframe_insert(path, frame=f)
    rec = {"from": os.path.basename(src_blend), "span": [f0, f1], "breakdowns": sorted(breakdowns), "bulge_m": bulge}
    if yaw_deg or bulge_end is not None:
        rec.update({"yaw_deg": yaw_deg, "yaw_end": yaw_end, "bulge_end_m": bulge_end})
    arm["lab_raise"] = json.dumps(rec)
    sc.frame_set(1)
    os.makedirs(os.path.dirname(out_blend), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=out_blend)
    print(f"[family_lab] wrote {os.path.relpath(out_blend, ROOT)}: {f0} and {f1} as saved, both hands on the {gun.name} at {sorted(breakdowns)}, "
          f"the slide re-keyed on {f0 + 1}-{f1 - 1}")


def swap(blend, key, old_glb, new_glb):
    """A model of a SAVED lab file replaced by a new version of its source (the Director's own edit of the model): the old source is
    fitted to the mesh as it sits in the file (its size and grip, untouched) and the new source gets the same transform. The new
    version must keep the old one's frame (the same model, edited); the object, its place and its properties stay, `lab_source`
    then names the new file. The file is saved in place: back it up first."""
    bpy.ops.wm.open_mainfile(filepath=blend)
    ob = bpy.data.objects.get("GUN_" + key)
    if ob is None:
        fail(f"no GUN_{key} in {os.path.basename(blend)}")
    if "lab_mesh_frame" in ob:      # a long-gun file stores its turn
        turn = gun_frame_matrix(json.loads(ob["lab_mesh_frame"]))
    else:
        turn = Matrix.Rotation(math.radians(float(ob.get("lab_turn_deg", 0.0))), 4, "Z")
    old = import_model(old_glb, "_old")
    old.data.transform(turn)
    sp = verts(old)
    if len(sp) != len(ob.data.vertices):
        fail(f"GUN_{key} has {len(ob.data.vertices)} vertices, the old source {len(sp)}: not the model it holds")
    s_, R, t, rms = umeyama(sp, [v.co.copy() for v in ob.data.vertices])
    bpy.data.objects.remove(old)
    new = import_model(new_glb, "_new")
    new.data.transform(_sim(s_, R, t) @ turn)
    mesh_old = ob.data
    ob.data = new.data
    bpy.data.objects.remove(new)
    bpy.data.meshes.remove(mesh_old)
    ob["lab_source"] = os.path.relpath(new_glb, ROOT)
    bpy.ops.wm.save_mainfile()
    print(f"[family_lab] GUN_{key} in {os.path.basename(blend)}: {os.path.basename(new_glb)} in the place of the old source (x{s_:.5f}, rms {rms:.1e})")


def main():
    a = args_after_dashes()
    if not a:
        fail("usage: -- build <family> <figure> <out .blend> [readback .json] [--marker <name>] | render <blend> <out prefix> | readback <blend> <out .json> | grip <blend> <nn> <out .json>")
    if a[0] == "build":
        marker = None
        if "--marker" in a:
            i = a.index("--marker")
            marker = a[i + 1]
            a = a[:i] + a[i + 2:]
        build(a[1], a[2], a[3], a[4] if len(a) > 4 else None, marker)
    elif a[0] == "grip":
        grip(a[1], a[2], a[3])
    elif a[0] == "seq":
        stops = dict(x.split("=", 1) for x in a[4:])
        if not stops:
            fail("seq needs at least one <marker>=<lab .blend>")
        seq(a[1], a[2], a[3], stops)
    elif a[0] == "in_step":
        in_step(a[1], a[2], a[3], a[4])
    elif a[0] == "raise":
        raise_from_gun(a[1], a[2], int(a[3]), int(a[4]), [int(x) for x in a[5].split(",") if x],
                       float(a[6]) if len(a) > 6 else RAISE_BULGE_M, float(a[7]) if len(a) > 7 else 0.0,
                       float(a[8]) if len(a) > 8 else 1.0, float(a[9]) if len(a) > 9 and a[9] != "-" else None)
    elif a[0] == "swap":
        swap(a[1], a[2], a[3], a[4])
    elif a[0] == "readback":
        readback(a[1], a[2])
    elif a[0] == "render":
        render(a[1], a[2], a[3] if len(a) > 3 else None)
    else:
        fail(f"unknown mode {a[0]}")


if __name__ == "__main__":
    main()
