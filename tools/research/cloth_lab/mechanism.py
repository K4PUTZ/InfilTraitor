"""mechanism.py — one picture of how the sheet works: nodes, three kinds of spring, and the crease (plasticity)."""
import math, os
from PIL import Image, ImageDraw
from render import font

OUT = os.environ.get("CLOTH_OUT", "out")
W, H = 760, 470
BG, INK, DIM = (24, 26, 30), (225, 226, 232), (140, 144, 154)
NODE, HOT = (190, 196, 208), (255, 170, 80)

def panel(title, sub):
    im = Image.new("RGB", (W, H), BG); d = ImageDraw.Draw(im)
    d.text((16, 12), title, fill=INK, font=font(21)); d.text((16, 42), sub, fill=DIM, font=font(14))
    return im, d

def grid_pts(ox=70, oy=120, step=78, n=5):
    return [[(ox + i * step, oy + j * step * 0.82) for j in range(n)] for i in range(n)]

def dots(d, g, r=6, hot=()):
    for i, row in enumerate(g):
        for j, p in enumerate(row):
            c = HOT if (i, j) in hot else NODE
            d.ellipse([p[0] - r, p[1] - r, p[0] + r, p[1] + r], fill=c)

def p1():
    im, d = panel("1  A node per voxel", "each node is a point of mass; the sheet is a grid of them")
    g = grid_pts()
    for i in range(5):
        for j in range(5):
            if i < 4: d.line([g[i][j], g[i + 1][j]], fill=(60, 64, 72), width=1)
            if j < 4: d.line([g[i][j], g[i][j + 1]], fill=(60, 64, 72), width=1)
    dots(d, g)
    d.text((16, H - 56), "4 GU roof = 33 x 33 nodes at one per voxel (1/8 GU).", fill=INK, font=font(15))
    d.text((16, H - 34), "gravity pulls every node down; the walls hold the pinned ones.", fill=DIM, font=font(14))
    return im

def p2():
    im, d = panel("2  Stretch + shear springs", "keep every length: the cloth does not stretch; shear = how easily squares become diamonds")
    g = grid_pts()
    for i in range(4):
        for j in range(5):
            d.line([g[i][j], g[i + 1][j]], fill=(110, 190, 255), width=2)
    for i in range(5):
        for j in range(4):
            d.line([g[i][j], g[i][j + 1]], fill=(110, 190, 255), width=2)
    for i in range(4):
        for j in range(4):
            d.line([g[i][j], g[i + 1][j + 1]], fill=(120, 220, 140), width=1)
            d.line([g[i + 1][j], g[i][j + 1]], fill=(120, 220, 140), width=1)
    dots(d, g)
    d.text((16, H - 56), "blue: stretch (stiff for all)   green: shear (soft for cloth, stiff for cardboard)", fill=INK, font=font(15))
    d.text((16, H - 34), "this part alone gives a CLOTH: it hangs and folds anywhere.", fill=DIM, font=font(14))
    return im

def p3():
    im, d = panel("3  The bend spring", "three nodes in a row: a - 2b + c is zero only when they are straight")
    a, b, c = (110, 260), (340, 330), (570, 235)
    chord = ((a[0] + c[0]) / 2, (a[1] + c[1]) / 2)
    d.line([a, b, c], fill=NODE, width=3)
    d.line([a, c], fill=(70, 74, 84), width=1)
    d.line([chord, b], fill=HOT, width=4)
    for p in (a, b, c):
        d.ellipse([p[0] - 8, p[1] - 8, p[0] + 8, p[1] + 8], fill=NODE)
    d.text((a[0] - 10, a[1] - 30), "a", fill=INK, font=font(18)); d.text((b[0] - 4, b[1] + 14), "b", fill=INK, font=font(18)); d.text((c[0] - 4, c[1] - 30), "c", fill=INK, font=font(18))
    d.text((b[0] + 12, (chord[1] + b[1]) / 2 - 10), "bend = how far b sits from the chord", fill=HOT, font=font(15))
    d.text((16, H - 78), "force = B x bend.   B is one number per material, given as a LENGTH:", fill=INK, font=font(15))
    d.text((16, H - 56), "lb = (B / weight per area)^(1/3)   the span at which a strip sags a lot.", fill=INK, font=font(15))
    d.text((16, H - 34), "canvas cloth lb ~ 0.12 GU   corrugated cardboard lb ~ 0.7 GU", fill=DIM, font=font(14))
    return im

def p4():
    im, d = panel("4  The crease (cardboard only)", "past a certain bend the cardboard stops springing back: the fold is kept")
    x0, y0, w, h = 90, 400, 600, 270
    d.line([(x0, y0), (x0 + w, y0)], fill=DIM, width=2); d.line([(x0, y0), (x0, y0 - h)], fill=DIM, width=2)
    d.text((x0 + w - 150, y0 + 8), "bend (curvature)", fill=DIM, font=font(14)); d.text((x0 - 70, y0 - h - 22), "restoring moment", fill=DIM, font=font(14))
    yk = (x0 + 250, y0 - 190)
    d.line([(x0, y0), yk], fill=(255, 160, 70), width=4)
    d.line([yk, (x0 + w - 20, y0 - 190)], fill=(255, 160, 70), width=4)
    d.line([(x0, y0), (x0 + w - 20, y0 - 18)], fill=(170, 170, 178), width=2)
    d.line([(x0 + w - 20, y0 - 190), (x0 + 360, y0)], fill=(255, 160, 70), width=2)
    d.text((x0 + 262, y0 - 232), "yield: the moment stops growing", fill=(255, 170, 80), font=font(15))
    d.text((x0 + 330, y0 - 150), "unloaded: it stays bent", fill=(255, 170, 80), font=font(14))
    d.text((x0 + 260, y0 - 40), "cloth: almost no moment", fill=(170, 170, 178), font=font(14))
    d.text((16, H - 34), "no crease = it springs back (elastic).  Crease = a hinge line forms where the moment peaks.", fill=INK, font=font(15))
    return im

sheet = Image.new("RGB", (2 * W, 2 * H), BG)
for k, f in enumerate((p1, p2, p3, p4)):
    sheet.paste(f(), ((k % 2) * W, (k // 2) * H))
sheet.save(os.path.join(OUT, "mechanism.png"))
print("saved")
