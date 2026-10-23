"""INFILTRAITOR plot poster: the four factions in the sheet's corners, the favour arrows between them, the Agent at the centre.

Run from the repo root (Blender 5.2; the fonts are macOS system fonts):
    /Applications/Blender.app/Contents/MacOS/Blender --background --python tools/asset_generation/plot_circle_poster.py -- [out.png] [scale]
Default output: DIAGRAMS/CIRCULO_ENREDO.png at scale 1.0 (1754 x 2480, A4). The canon it draws is DESIGN_MASTER_PLAN §2.1, §2.6, §2.7.
Units are centimetres of an A4 sheet (21 x 29.7), origin at the centre. Symbols are placeholders until the faction logos exist; each
faction's symbol is its own block below, so a logo replaces one block without touching the layout.
"""
import bpy, bmesh, math, os, sys
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = argv[0] if argv else os.path.join(REPO, "DIAGRAMS", "CIRCULO_ENREDO.png")
SCALE = float(argv[1]) if len(argv) > 1 else 1.0

W, H = 21.0, 29.7
PAPER, INK, MUTED = "#E9EDEB", "#1A1F22", "#545E63"
FID, CWS, BBM, CORP = "#2B5A8A", "#21756A", "#B0541E", "#7A3961"
HL, BAD, FLAME = "#F2D33F", "#9E2E28", "#E9963F"
FONT_DISPLAY = "/System/Library/Fonts/Supplemental/DIN Condensed Bold.ttf"
FONT_BODY = "/System/Library/Fonts/Supplemental/Arial Narrow.ttf"
FONT_BODY_B = "/System/Library/Fonts/Supplemental/Arial Narrow Bold.ttf"
FONT_BODY_I = "/System/Library/Fonts/Supplemental/Arial Narrow Italic.ttf"

# ---------- scene ----------
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
for engine in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
    try:
        scene.render.engine = engine
        break
    except TypeError:
        pass
scene.render.resolution_x = int(1754 * SCALE)
scene.render.resolution_y = int(2480 * SCALE)
scene.render.resolution_percentage = 100
scene.render.filepath = OUT
scene.render.image_settings.file_format = "PNG"
scene.view_settings.view_transform = "Standard"
scene.view_settings.look = "None"
try:
    scene.eevee.taa_render_samples = 64
except AttributeError:
    pass

world = bpy.data.worlds.new("world")
scene.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.8, 0.8, 0.8, 1)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.42

cam_data = bpy.data.cameras.new("cam")
cam_data.type = "ORTHO"
cam_data.ortho_scale = H
cam = bpy.data.objects.new("cam", cam_data)
cam.location = (0, 0, 40)
scene.collection.objects.link(cam)
scene.camera = cam

sun_data = bpy.data.lights.new("sun", "SUN")
sun_data.energy = 2.05
sun_data.angle = math.radians(9)
sun = bpy.data.objects.new("sun", sun_data)
sun.rotation_euler = (math.radians(28), math.radians(-22), 0)
scene.collection.objects.link(sun)


# ---------- helpers ----------
def lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def rgba(h):
    h = h.lstrip("#")
    return tuple(lin(int(h[i:i + 2], 16) / 255) for i in (0, 2, 4)) + (1.0,)


def mix(a, b, t):
    a, b = a.lstrip("#"), b.lstrip("#")
    ca = [int(a[i:i + 2], 16) for i in (0, 2, 4)]
    cb = [int(b[i:i + 2], 16) for i in (0, 2, 4)]
    return "#" + "".join(f"{round(x * t + y * (1 - t)):02X}" for x, y in zip(ca, cb))


_mats = {}


def lit(hexc, rough=0.5):
    key = ("lit", hexc, rough)
    if key not in _mats:
        m = bpy.data.materials.new(f"lit_{hexc}")
        m.use_nodes = True
        b = m.node_tree.nodes["Principled BSDF"]
        b.inputs["Base Color"].default_value = rgba(hexc)
        b.inputs["Roughness"].default_value = rough
        _mats[key] = m
    return _mats[key]


def flat(hexc):
    key = ("flat", hexc)
    if key not in _mats:
        m = bpy.data.materials.new(f"flat_{hexc}")
        m.use_nodes = True
        nt = m.node_tree
        nt.nodes.clear()
        e = nt.nodes.new("ShaderNodeEmission")
        e.inputs["Color"].default_value = rgba(hexc)
        e.inputs["Strength"].default_value = 1.0
        o = nt.nodes.new("ShaderNodeOutputMaterial")
        nt.links.new(e.outputs[0], o.inputs[0])
        _mats[key] = m
    return _mats[key]


def link(ob):
    scene.collection.objects.link(ob)
    return ob


def prism(name, pts, depth, mat, loc=(0, 0), z0=0.0, bevel=0.03):
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    vs = [bm.verts.new((x, y, 0.0)) for x, y in pts]
    face = bm.faces.new(vs)
    face.normal_update()
    if face.normal.z < 0:
        face.normal_flip()
    res = bmesh.ops.extrude_face_region(bm, geom=[face])
    top = [g for g in res["geom"] if isinstance(g, bmesh.types.BMVert)]
    bmesh.ops.translate(bm, verts=top, vec=(0, 0, depth))
    bmesh.ops.delete(bm, geom=[face], context="FACES")
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.to_mesh(me)
    bm.free()
    ob = link(bpy.data.objects.new(name, me))
    ob.location = (loc[0], loc[1], z0)
    me.materials.append(mat)
    if bevel > 0:
        md = ob.modifiers.new("bevel", "BEVEL")
        md.width = bevel
        md.segments = 3
        md.limit_method = "ANGLE"
    return ob


def circle_pts(r, n=72, cx=0.0, cy=0.0):
    return [(cx + r * math.cos(2 * math.pi * i / n), cy + r * math.sin(2 * math.pi * i / n)) for i in range(n)]


def ring(name, rin, rout, depth, mat, loc, z0=0.0, n=72):
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    rows = []
    for z in (0.0, depth):
        rows.append([bm.verts.new((rin * math.cos(2 * math.pi * i / n), rin * math.sin(2 * math.pi * i / n), z)) for i in range(n)])
        rows.append([bm.verts.new((rout * math.cos(2 * math.pi * i / n), rout * math.sin(2 * math.pi * i / n), z)) for i in range(n)])
    ib, ob_, it, ot = rows
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((it[i], ot[i], ot[j], it[j]))
        bm.faces.new((ib[j], ob_[j], ob_[i], ib[i]))
        bm.faces.new((ob_[i], ob_[j], ot[j], ot[i]))
        bm.faces.new((ib[j], ib[i], it[i], it[j]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = True
    o = link(bpy.data.objects.new(name, me))
    o.location = (loc[0], loc[1], z0)
    me.materials.append(mat)
    return o


def sphere(name, r, loc, mat, z0, zscale=0.5):
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=40, v_segments=20, radius=r)
    for v in bm.verts:
        v.co.z *= zscale
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = True
    o = link(bpy.data.objects.new(name, me))
    o.location = (loc[0], loc[1], z0)
    me.materials.append(mat)
    return o


def catmull(pts, n=8):
    out = []
    L = len(pts)
    for i in range(L):
        p0, p1, p2, p3 = (Vector(pts[(i + k) % L]) for k in (-1, 0, 1, 2))
        for s in range(n):
            t = s / n
            q = 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t + (-p0 + 3 * p1 - 3 * p2 + p3) * t ** 3)
            out.append((q.x, q.y))
    return out


def rrect(w, h, r, n=6):
    pts = []
    for cx, cy, a0 in ((w / 2 - r, h / 2 - r, 0), (-w / 2 + r, h / 2 - r, 90), (-w / 2 + r, -h / 2 + r, 180), (w / 2 - r, -h / 2 + r, 270)):
        for k in range(n + 1):
            a = math.radians(a0 + 90 * k / n)
            pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def rot(pts, deg, dx=0.0, dy=0.0):
    c, s = math.cos(math.radians(deg)), math.sin(math.radians(deg))
    return [(x * c - y * s + dx, x * s + y * c + dy) for x, y in pts]


def shift(pts, dx, dy):
    return [(x + dx, y + dy) for x, y in pts]


fonts = {k: bpy.data.fonts.load(p) for k, p in (("d", FONT_DISPLAY), ("b", FONT_BODY), ("bb", FONT_BODY_B), ("bi", FONT_BODY_I))}
TEXTS = []


def text(body, x, y, size, font, color, align="LEFT", spacing=1.0, z=0.03):
    cu = bpy.data.curves.new("txt", "FONT")
    cu.body = body
    cu.font = fonts[font]
    cu.size = size
    cu.align_x = align
    cu.align_y = "CENTER"
    cu.space_character = spacing
    o = link(bpy.data.objects.new("txt", cu))
    o.location = (x, y, z)
    cu.materials.append(flat(color))
    TEXTS.append(o)
    return o


def arrow(a, b, w=0.13, hl=0.62, hw=0.56):
    a, b = Vector(a), Vector(b)
    d = (b - a).normalized()
    n = Vector((-d.y, d.x))
    s = b - d * hl
    pts = [a + n * w / 2, s + n * w / 2, s + n * hw / 2, b, s - n * hw / 2, s - n * w / 2, a - n * w / 2]
    prism("arrow", [(p.x, p.y) for p in pts], 0.1, lit(INK, 0.6), bevel=0.02)


MED_R = 2.45
MED_Z = 0.08


def medallion(cx, cy, color, tint=0.2):
    prism("medal", circle_pts(MED_R, 96), MED_Z, lit(mix(color, PAPER, tint), 0.7), loc=(cx, cy), bevel=0.03)
    ring("medal_rim", MED_R - 0.1, MED_R, MED_Z + 0.04, lit(color, 0.5), (cx, cy))


# ---------- paper and frame ----------
prism("paper", rrect(W + 2, H + 2, 0.01, 1), 0.001, lit(PAPER, 0.92), z0=-0.002, bevel=0)
inset = 0.5
for bw, bh, bx, by in ((W - 2 * inset, 0.035, 0, H / 2 - inset), (W - 2 * inset, 0.035, 0, -H / 2 + inset),
                       (0.035, H - 2 * inset, W / 2 - inset, 0), (0.035, H - 2 * inset, -W / 2 + inset, 0)):
    prism("frame", rrect(bw, bh, 0.0, 1), 0.005, flat(INK), loc=(bx, by), bevel=0)

# ---------- corner positions ----------
PX, PY = 6.8, 10.3
P, M, T, C = (-PX, PY), (PX, PY), (PX, -PY), (-PX, -PY)
AG = (0.0, 0.8)
Z1 = MED_Z + 0.01

# Police (FID): a badge shield with a five-point star (never a six-point star: it reads as a religious symbol)
medallion(*P, FID)
shield = catmull([(-1.42, 1.45), (-0.55, 1.46), (0.0, 1.3), (0.55, 1.46), (1.42, 1.45), (1.38, 0.35),
                  (1.12, -0.62), (0.6, -1.32), (0.0, -1.78), (-0.6, -1.32), (-1.12, -0.62), (-1.38, 0.35)], 5)
shield = shift(shield, 0, 0.1)
prism("fid_shield", shield, 0.3, lit(FID, 0.45), loc=P, z0=Z1, bevel=0.05)
prism("fid_inner", [(x * 0.8, y * 0.8 + 0.02) for x, y in shield], 0.36, lit(mix(FID, PAPER, 0.25), 0.6), loc=P, z0=Z1, bevel=0.03)
star = []
for k in range(10):
    a = math.radians(90 + k * 36)
    r = 0.74 if k % 2 == 0 else 0.3
    star.append((r * math.cos(a), r * math.sin(a) + 0.08))
prism("fid_star", star, 0.46, lit(FID, 0.4), loc=P, z0=Z1, bevel=0.03)

# Militia (Calm Waters Security): a quad drone
medallion(*M, CWS)
for ang in (45, -45):
    prism("cws_arm", rot(rrect(3.1, 0.34, 0.17), ang), 0.26, lit(CWS, 0.45), loc=M, z0=Z1, bevel=0.03)
prism("cws_body", rot(rrect(1.05, 1.05, 0.22), 45), 0.42, lit(CWS, 0.4), loc=M, z0=Z1, bevel=0.05)
prism("cws_eye", circle_pts(0.2, 32), 0.48, lit(mix(CWS, PAPER, 0.3), 0.5), loc=M, z0=Z1, bevel=0.03)
off = 1.55 * math.cos(math.radians(45))
for sx, sy in ((1, 1), (-1, 1), (1, -1), (-1, -1)):
    c = (M[0] + sx * off, M[1] + sy * off)
    ring("cws_rotor", 0.4, 0.56, 0.3, lit(CWS, 0.45), c, z0=Z1)
    prism("cws_hub", circle_pts(0.14, 24), 0.34, lit(CWS, 0.45), loc=c, z0=Z1, bevel=0.02)

# Traffickers (Bunsen Burners MC): a flask with a flame
medallion(*T, BBM)
dy = -0.41
flask = shift([(-0.32, 0.75), (-0.32, 0.2), (-1.25, -1.15), (-1.12, -1.38), (1.12, -1.38), (1.25, -1.15), (0.32, 0.2), (0.32, 0.75)], 0, dy)
prism("bbm_flask", flask, 0.32, lit(BBM, 0.45), loc=T, z0=Z1, bevel=0.05)
prism("bbm_lip", shift(rrect(0.95, 0.2, 0.08), 0, 0.82 + dy), 0.34, lit(BBM, 0.45), loc=T, z0=Z1, bevel=0.03)
liquid = shift([(-0.78, -0.55), (-1.06, -1.2), (1.06, -1.2), (0.78, -0.55)], 0, dy)
prism("bbm_liquid", liquid, 0.38, lit(mix(BBM, PAPER, 0.35), 0.5), loc=T, z0=Z1, bevel=0.03)
flame = catmull([(0, 0.98), (0.38, 1.12), (0.5, 1.45), (0.36, 1.8), (0.14, 2.2), (0.1, 1.88), (-0.12, 2.02), (-0.38, 1.72), (-0.48, 1.4), (-0.34, 1.1)], 6)
prism("bbm_flame", shift(flame, 0, dy), 0.3, lit(FLAME, 0.4), loc=T, z0=Z1, bevel=0.04)

# Corporation (GRUB DRILL INC): the curled grub
medallion(*C, CORP)
n_seg = 11
for i in range(n_seg):
    t = i / (n_seg - 1)
    a = math.radians(150 - 300 * t)
    rr = 1.12
    r = 0.62 - 0.36 * t
    pos = (C[0] + rr * math.cos(a), C[1] + rr * math.sin(a))
    shade = CORP if i else mix(CORP, INK, 0.75)
    sphere("grub", r, pos, lit(shade, 0.35), Z1 + r * 0.5, 0.5)
ha = math.radians(150)
sphere("grub_eye", 0.1, (C[0] + 1.12 * math.cos(ha) - 0.12, C[1] + 1.12 * math.sin(ha) + 0.22), lit(PAPER, 0.3), Z1 + 0.62, 0.6)

# The Agent: a fedora, the band in the truth yellow
prism("ag_medal", circle_pts(2.3, 96), MED_Z, lit(mix(HL, PAPER, 0.35), 0.7), loc=AG, bevel=0.03)
ring("ag_rim", 2.2, 2.3, MED_Z + 0.04, lit(INK, 0.5), AG)
hy = -0.63
brim = []
xs = [-2.0 + 4.0 * i / 24 for i in range(25)]
for x in xs:
    brim.append((x * 0.95, 0.22 + 0.27 * (abs(x) / 2) ** 3 + hy))
for x in reversed(xs):
    brim.append((x * 0.95, -0.04 + 0.34 * (abs(x) / 2) ** 3 + hy))
prism("ag_brim", brim, 0.28, lit(INK, 0.55), loc=AG, z0=Z1, bevel=0.03)
crown = [(-1.0, 0.2), (1.0, 0.2), (0.88, 1.15), (0.45, 1.33), (0.0, 1.13), (-0.45, 1.33), (-0.88, 1.15)]
prism("ag_crown", shift(crown, 0, hy), 0.34, lit(INK, 0.55), loc=AG, z0=Z1, bevel=0.05)
band = [(-0.995, 0.22), (0.995, 0.22), (0.958, 0.5), (-0.958, 0.5)]
prism("ag_band", shift(band, 0, hy), 0.38, lit(HL, 0.45), loc=AG, z0=Z1, bevel=0.02)

# ---------- arrows: the circle of favours ----------
G = 4.05
arrow((-G, PY), (G, PY))
arrow((PX, PY - 2.75), (PX, -PY + 2.75))
arrow((G, -PY), (-G, -PY))
arrow((-PX, -PY + 2.75), (-PX, PY - 2.75))

# ---------- text ----------
text("INFILTRAITOR", 0, 13.62, 1.18, "d", INK, "CENTER", 1.05)
text("O CÍRCULO DE FAVORES", 0, 12.78, 0.36, "d", MUTED, "CENTER", 1.25)

text("GRAVES PEDE", 0, 11.42, 0.32, "d", MUTED, "CENTER", 1.2)
text("achar o vazamento, por fora", 0, 10.88, 0.46, "b", INK, "CENTER")
text("DEACON PEDE", 0, -10.92, 0.32, "d", MUTED, "CENTER", 1.2)
text("achar quem vaza para a Milícia", 0, -11.46, 0.46, "b", INK, "CENTER")
text("KESSLER PEDE", 6.38, 0.92, 0.32, "d", MUTED, "RIGHT", 1.2)
text("provar que foram", 6.38, 0.4, 0.44, "b", INK, "RIGHT")
text("os traficantes", 6.38, -0.1, 0.44, "b", INK, "RIGHT")
text("PRYCE PEDE", -6.38, 0.92, 0.32, "d", MUTED, "LEFT", 1.2)
text("provar a negligência", -6.38, 0.4, 0.44, "b", INK, "LEFT")
text("do Estado", -6.38, -0.1, 0.44, "b", INK, "LEFT")
text("aqui Graves toma", -6.38, -0.62, 0.34, "bi", BAD, "LEFT")
text("o distintivo", -6.38, -1.0, 0.34, "bi", BAD, "LEFT")


def block(x, y0, align, color, name, org, leaders, fail, clue):
    text(name, x, y0, 0.98, "d", color, align, 1.04)
    text(org, x, y0 - 0.66, 0.3, "d", MUTED, align, 1.22)
    text(leaders, x, y0 - 1.2, 0.46, "bb", INK, align)
    text(fail, x, y0 - 1.74, 0.37, "b", INK, align)
    text(clue, x, y0 - 2.22, 0.37, "bi", MUTED, align)


block(-6.1, 7.2, "LEFT", FID, "POLÍCIA", "FID · FEDERAL INQUIRY DIRECTORATE", "Graves → Barrow",
      "Falha: barrou as inspeções da cava", "Pista: credencial policial no bloqueio")
block(6.1, 7.2, "RIGHT", CWS, "MILÍCIA", "CALM WATERS SECURITY", "Kessler → Hardcastle",
      "Falha: as sirenes ficaram mudas", "Pista: o drone decolou no perímetro")
block(6.1, -4.62, "RIGHT", BBM, "TRAFICANTES", "BUNSEN BURNERS MC", "“Deacon” → “Choirboy”",
      "Falha: rejeito químico no reservatório", "Pista: peças de drone no desmanche")
block(-6.1, -4.62, "LEFT", CORP, "CORPORAÇÃO", "GRUB DRILL INC", "Pryce → Marsh",
      "Falha: o relatório enterrado", "Pista: puts compradas por uma laranja")

text("O AGENTE", 0, -2.12, 0.78, "d", INK, "CENTER", 1.05)
hl_txt = text("o vazamento e o autor do ataque", 0, -2.74, 0.4, "b", INK, "CENTER", z=0.05)
prism("hl_strip", rrect(5.5, 0.44, 0.04), 0.002, flat(HL), loc=(0, -2.72), z0=0.02, bevel=0)

text("VOLTA 1: CADA LÍDER TROCA O QUE SABE POR UM FAVOR QUE APONTA PARA O PRÓXIMO  ·  VOLTA 2: OS QUATRO, EM QUALQUER ORDEM",
     0, -13.72, 0.29, "d", MUTED, "CENTER", 1.12)
text("Líder → sublíder que assume o posto  ·  símbolos provisórios: os logos das facções virão depois",
     0, -14.18, 0.3, "b", MUTED, "CENTER")

# ---------- overlap report (text boxes, in sheet units) ----------
bpy.context.view_layer.update()
boxes = []
for o in TEXTS:
    bb = [o.matrix_world @ Vector(c) for c in o.bound_box]
    xs_ = [v.x for v in bb]
    ys_ = [v.y for v in bb]
    boxes.append((o.data.body[:28], min(xs_), max(xs_), min(ys_), max(ys_)))
for name, x0, x1, y0, y1 in boxes:
    if x0 < -W / 2 + 0.6 or x1 > W / 2 - 0.6:
        print(f"[poster] EDGE {name!r} x {x0:.2f}..{x1:.2f}")
for i in range(len(boxes)):
    for j in range(i + 1, len(boxes)):
        a, b = boxes[i], boxes[j]
        if a[1] < b[2] and b[1] < a[2] and a[3] < b[4] and b[3] < a[4]:
            print(f"[poster] OVERLAP {a[0]!r} x {b[0]!r}")
for name, x0, x1, y0, y1 in boxes:
    print(f"[poster] box {name!r:32} x {x0:6.2f}..{x1:6.2f}  y {y0:6.2f}..{y1:6.2f}")

bpy.ops.render.render(write_still=True)
print(f"[poster] wrote {OUT}")
