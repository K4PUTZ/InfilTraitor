"""emblems.py — the four faction emblems as flat RGBA decals (1024 x 1024), for the coat-emblem test (ACTOR D90).

PLACEHOLDERS: the shapes are the circle poster's (tools/asset_generation/plot_circle_poster.py: the FID shield and five-point star, the
Calm Waters quad drone, the Bunsen Burners flask and flame, the GRUB DRILL curled grub) and the colours COSMETICS §9.4's primaries; they are
replaced when the faction logos are drawn. The default is the ruled look, the LOGO ALONE (Director, 2026-10-31: "sem o círculo em volta do
símbolo, e nem o fundo branco"): what was white inside the logo (the rotors' holes, the gaps between the grub's segments) is transparent, so
the coat shows through. `medallion` draws the first test's look (a white disc in a ring of the faction's colour) for comparison.
Drawn 4x larger and reduced (LANCZOS) for clean edges. Also writes emblems_row.png, the four over the mustard coat colour.
Usage: python3 -I emblems.py <out_dir> [medallion]
"""
import math
import sys
from PIL import Image, ImageDraw

OUT = sys.argv[1]
MEDALLION = len(sys.argv) > 2 and sys.argv[2] == "medallion"
N, SS, R = 1024, 4, 2.5                      # image side, supersampling, half the drawing's extent in poster units
K = N * SS / (2 * R)
HOLE = (0, 0, 0, 0)                          # ImageDraw on RGBA writes the value: this punches a transparent hole


def hexc(h):
    h = h.lstrip("#"); return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


def mix(a, b, t):
    return tuple(round(x + (y - x) * t) for x, y in zip(a, b))


PAPER = hexc("F2F2F2")
WHITE = PAPER if MEDALLION else HOLE         # what reads as "paper" inside a logo


def px(p):
    return (N * SS / 2 + p[0] * K, N * SS / 2 - p[1] * K)


def catmull(pts, n=8):
    out = []; L = len(pts)
    for i in range(L):
        p0, p1, p2, p3 = (pts[(i + k) % L] for k in (-1, 0, 1, 2))
        for s in range(n):
            t = s / n
            out.append(tuple(0.5 * ((2 * b) + (-a + c) * t + (2 * a - 5 * b + 4 * c - d) * t * t + (-a + 3 * b - 3 * c + d) * t ** 3)
                             for a, b, c, d in zip(p0, p1, p2, p3)))
    return out


def rrect(w, h, r, n=6):
    pts = []
    for cx, cy, a0 in ((w / 2 - r, h / 2 - r, 0), (-w / 2 + r, h / 2 - r, 90), (-w / 2 + r, -h / 2 + r, 180), (w / 2 - r, -h / 2 + r, 270)):
        for k in range(n + 1):
            a = math.radians(a0 + 90 * k / n); pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def rot(pts, deg):
    c, s = math.cos(math.radians(deg)), math.sin(math.radians(deg))
    return [(x * c - y * s, x * s + y * c) for x, y in pts]


def shift(pts, dx, dy):
    return [(x + dx, y + dy) for x, y in pts]


def circ(d, c, r, fill):
    d.ellipse([px((c[0] - r, c[1] + r)), px((c[0] + r, c[1] - r))], fill=fill)


def poly(d, pts, fill):
    d.polygon([px(p) for p in pts], fill=fill)


def medal(d, rim):
    if MEDALLION:
        circ(d, (0, 0), 2.45, rim); circ(d, (0, 0), 2.27, PAPER)


def fid(d):
    c = hexc("2E6FD8"); medal(d, c)
    sh = shift(catmull([(-1.42, 1.45), (-0.55, 1.46), (0.0, 1.3), (0.55, 1.46), (1.42, 1.45), (1.38, 0.35), (1.12, -0.62), (0.6, -1.32),
                        (0.0, -1.78), (-0.6, -1.32), (-1.12, -0.62), (-1.38, 0.35)], 5), 0, 0.1)
    poly(d, sh, c); poly(d, [(x * 0.8, y * 0.8 + 0.02) for x, y in sh], mix(c, PAPER, 0.55))
    star = []
    for k in range(10):                          # five points, never six (a six-point star reads as a religious symbol)
        r = 0.74 if k % 2 == 0 else 0.3; a = math.radians(90 + k * 36)
        star.append((r * math.cos(a), r * math.sin(a) + 0.08))
    poly(d, star, c)


def cws(d):
    c = hexc("B3121E"); medal(d, c)
    for a in (45, -45):
        poly(d, rot(rrect(3.1, 0.34, 0.17), a), c)
    o = 1.55 * math.cos(math.radians(45))
    for sx, sy in ((1, 1), (-1, 1), (1, -1), (-1, -1)):
        circ(d, (sx * o, sy * o), 0.56, c); circ(d, (sx * o, sy * o), 0.4, WHITE); circ(d, (sx * o, sy * o), 0.14, c)
    poly(d, rot(rrect(1.05, 1.05, 0.22), 45), c); circ(d, (0, 0), 0.2, mix(c, PAPER, 0.45))


def bbm(d):
    c = hexc("F08A24"); medal(d, c); dy = -0.41
    poly(d, shift([(-0.32, 0.75), (-0.32, 0.2), (-1.25, -1.15), (-1.12, -1.38), (1.12, -1.38), (1.25, -1.15), (0.32, 0.2), (0.32, 0.75)], 0, dy), c)
    poly(d, shift(rrect(0.95, 0.2, 0.08), 0, 0.82 + dy), c)
    poly(d, shift([(-0.78, -0.55), (-1.06, -1.2), (1.06, -1.2), (0.78, -0.55)], 0, dy), hexc("46C2C2"))
    poly(d, shift(catmull([(0, 0.98), (0.38, 1.12), (0.5, 1.45), (0.36, 1.8), (0.14, 2.2), (0.1, 1.88), (-0.12, 2.02), (-0.38, 1.72),
                           (-0.48, 1.4), (-0.34, 1.1)], 6), 0, dy), hexc("5C8F2A"))


def corp(d):
    c = hexc("141416"); medal(d, hexc("6B2FA0")); n = 11
    for i in reversed(range(n)):                 # tail first, so each segment's gap cuts the one behind it
        t = i / (n - 1); a = math.radians(150 - 300 * t); r = 0.62 - 0.36 * t; p = (1.12 * math.cos(a), 1.12 * math.sin(a))
        circ(d, p, r + 0.06, WHITE); circ(d, p, r, c)
    ha = math.radians(150); circ(d, (1.12 * math.cos(ha) - 0.12, 1.12 * math.sin(ha) + 0.22), 0.1, PAPER)


NAMES = ("fid", "cws", "bbm", "corp")
for name, fn in zip(NAMES, (fid, cws, bbm, corp)):
    im = Image.new("RGBA", (N * SS, N * SS), HOLE); fn(ImageDraw.Draw(im))
    im.resize((N, N), Image.LANCZOS).save(f"{OUT}/emb_{name}.png")
row = Image.new("RGBA", (4 * 256, 256), hexc("CCA33D"))
for i, name in enumerate(NAMES):
    row.alpha_composite(Image.open(f"{OUT}/emb_{name}.png").resize((256, 256), Image.LANCZOS), (i * 256, 0))
row.save(f"{OUT}/emblems_row.png")
print(f"[emblems] wrote {OUT}/emb_{{{','.join(NAMES)}}}.png ({'medallion' if MEDALLION else 'logo alone'})")
