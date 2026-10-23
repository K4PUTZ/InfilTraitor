# faction_dress_art.py — the 2D side of the D78 decision renders (ACTOR_MASTER_PLAN D78, COSMETICS_MASTER_PLAN §9): the faction textures
# hero_faction_dress.py puts on the hero (emblems, armbands, regimental ties, the officer coat's back roundel, the ranking banner), and the
# contact sheets that show its renders, with a deuteranopia row (most colour-blind players) under the game-size figures.
# Placeholder emblems, as on the plot poster (DIAGRAMS/CIRCULO_ENREDO.png): a shield with a five-point star (FID), a quad drone (Calm Waters),
# a flask with a flame (Bunsen Burners), the curled grub (GRUB DRILL). The palette is data: faction_palette.json.
# Usage (system Python 3 with PIL + numpy):
#   python3 faction_dress_art.py textures <out_dir>
#   python3 faction_dress_art.py sheets <out_dir>        (after the Blender renders landed in <out_dir>)
import json, math, os, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
PAL = json.load(open(os.path.join(HERE, "faction_palette.json")))
FONT = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"
FONT_NARROW = "/System/Library/Fonts/Supplemental/Arial Narrow Bold.ttf"


def rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def font(size, narrow=False):
    path = FONT_NARROW if narrow else FONT
    return ImageFont.truetype(path, size) if os.path.exists(path) else ImageFont.load_default()


def emblem(kind, fg, fg2=None, size=512):
    """one emblem as an RGBA image, drawn at 2x and reduced for clean edges; fg2 colours the second element (the flame)"""
    S = size * 2
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    P = lambda x, y: (x * S, y * S)
    fg = rgb(fg) + (255,)
    fg2 = (rgb(fg2) + (255,)) if fg2 else fg
    if kind == "shield_star":
        shield = [P(0.17, 0.10), P(0.50, 0.17), P(0.83, 0.10), P(0.81, 0.52), P(0.50, 0.92), P(0.19, 0.52)]
        d.polygon(shield, outline=fg, width=int(S * 0.055))
        cx, cy, ro, ri = 0.5, 0.47, 0.19, 0.08
        star = [P(cx + (ro if k % 2 == 0 else ri) * math.sin(k * math.pi / 5), cy - (ro if k % 2 == 0 else ri) * math.cos(k * math.pi / 5)) for k in range(10)]
        d.polygon(star, fill=fg)
    elif kind == "quad_drone":
        w = int(S * 0.07)
        for sx in (-1, 1):
            for sy in (-1, 1):
                d.line([P(0.5, 0.5), P(0.5 + sx * 0.27, 0.5 + sy * 0.27)], fill=fg, width=w)
                c = P(0.5 + sx * 0.29, 0.5 + sy * 0.29)
                r = S * 0.15
                d.ellipse([c[0] - r, c[1] - r, c[0] + r, c[1] + r], outline=fg, width=int(S * 0.045))
        r = S * 0.11
        d.polygon([P(0.5, 0.5 - 0.13), P(0.5 + 0.13, 0.5), P(0.5, 0.5 + 0.13), P(0.5 - 0.13, 0.5)], fill=fg)
    elif kind == "flask_flame":
        d.rectangle([P(0.43, 0.38), P(0.57, 0.56)], fill=fg)
        d.polygon([P(0.43, 0.55), P(0.57, 0.55), P(0.80, 0.92), P(0.20, 0.92)], fill=fg)
        d.rectangle([P(0.39, 0.35), P(0.61, 0.40)], fill=fg)
        flame = [P(0.50, 0.04), P(0.60, 0.20), P(0.58, 0.31), P(0.50, 0.34), P(0.42, 0.31), P(0.40, 0.20)]
        d.polygon(flame, fill=fg2)
    elif kind == "grub":
        n = 9
        for k in range(n, -1, -1):
            a = math.radians(200 - k * 34)
            r = 0.115 - k * 0.0065
            cx, cy = 0.5 + 0.27 * math.cos(a), 0.52 - 0.27 * math.sin(a)
            d.ellipse([P(cx - r, cy - r), P(cx + r, cy + r)], fill=fg)
        a = math.radians(200)
        hx, hy = 0.5 + 0.27 * math.cos(a), 0.52 - 0.27 * math.sin(a)
        e = 0.03
        d.ellipse([P(hx - e + 0.02, hy - e - 0.03), P(hx + e + 0.02, hy + e - 0.03)], fill=(0, 0, 0, 0))
    else:
        raise SystemExit(f"[faction_dress_art] unknown emblem kind: {kind}")
    return im.resize((size, size), Image.LANCZOS)


def tie_texture(base, stripe, thin, metal):
    """hero_tailor.py's tie layout (diagonal stripes, a flat metal patch the tie bar's UVs point into) in faction colours, so the UVs match"""
    n = 256
    X, Y = np.meshgrid(np.arange(n), np.arange(n))
    img = np.zeros((n, n, 3)) + np.array(rgb(base)) / 255.0
    tw = 0.5 + 0.5 * np.sin((X - Y) * 2 * math.pi / 3.0)
    img *= (0.93 + 0.07 * tw)[..., None]
    s = ((X + Y) % 13) < 2
    img[s] = (np.array(rgb(stripe)) / 255.0) * (0.93 + 0.07 * tw[s])[..., None]
    s2 = ((X + Y + 6) % 13) == 0
    img[s2] = np.array(rgb(thin)) / 255.0
    img[n - 24:, :24] = np.array(rgb(metal)) / 255.0
    # hero_tailor writes rows bottom-up (Blender's buffer); a PNG is top-down, so flip to keep every UV on the same texel
    return Image.fromarray((np.flipud(np.clip(img, 0, 1)) * 255).astype(np.uint8), "RGB")


def armband(f):
    W, H = 1024, 256
    ov = f.get("armband", {})       # an override where the primary would vanish on the mustard coat (the bikers' orange, for deuteranopes)
    im = Image.new("RGB", (W, H), rgb(ov.get("base", f["primary"])))
    d = ImageDraw.Draw(im)
    trim = ov.get("stripe", f["secondary"])
    d.rectangle([0, 0, W, 22 if not ov else 34], fill=rgb(trim))
    d.rectangle([0, H - (22 if not ov else 34), W, H], fill=rgb(trim))
    mark = f["secondary"]
    mark2 = None
    if f["emblem"] == "flask_flame":
        mark, mark2 = f["secondary"], f["accents"][1]
    if f["emblem"] == "quad_drone":
        mark = f["accents"][1]
    if f["emblem"] == "grub":
        mark = f["metal"]
    mark, mark2 = ov.get("mark", mark), ov.get("mark2", mark2)
    for cx in (W * 0.25, W * 0.75):
        if f.get("armband_text"):
            e = emblem(f["emblem"], mark, mark2, 150)
            im.paste(e, (int(cx - 150), int(H / 2 - 75)), e)
            fo = font(120)
            d.text((cx + 5, H / 2), f["armband_text"], fill=rgb(mark), font=fo, anchor="lm")
        else:
            e = emblem(f["emblem"], mark, mark2, 190)
            im.paste(e, (int(cx - 95), int(H / 2 - 95)), e)
    return im


def roundel(f):
    o = f["officer_coat"]
    S = 512
    im = Image.new("RGBA", (S * 2, S * 2), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.ellipse([8, 8, S * 2 - 8, S * 2 - 8], fill=rgb(o["roundel"]) + (255,), outline=rgb(o["hem"]) + (255,), width=34)
    im = im.resize((S, S), Image.LANCZOS)
    e = emblem(f["emblem"], o["mark"], o.get("mark2"), 330)
    im.alpha_composite(e, (S // 2 - 165, S // 2 - 165))
    return im


def banner(f, W=600, H=860):
    """the ranking card: the faction's field, a large emblem watermark behind the figure, the name above, the background below"""
    field = np.array(rgb(f["primary"])) * (0.72 if f["primary"] != "#141416" else 1.0)
    im = Image.new("RGB", (W, H), tuple(int(c) for c in field))
    d = ImageDraw.Draw(im)
    trim = f["secondary"] if f["primary"] != "#F2F2F2" else f["primary"]
    d.rectangle([0, 0, W - 1, H - 1], outline=rgb(trim), width=14)
    wm_col = f["secondary"] if f["emblem"] != "grub" else f["secondary"]
    e = emblem(f["emblem"], wm_col, f["accents"][1] if f["emblem"] == "flask_flame" else None, 520)
    a = np.array(e)
    a[..., 3] = (a[..., 3] * 0.55).astype(np.uint8)
    e = Image.fromarray(a, "RGBA")
    im.paste(e, (W // 2 - 260, 120), e)
    txt = f["metal"] if f["primary"] == "#141416" else "#F2F2F2"
    d.text((W // 2, 52), f["name"].upper(), fill=rgb(txt), font=font(40, True), anchor="mm")
    d.text((W // 2, 92), f["background"].upper(), fill=rgb(txt), font=font(26, True), anchor="mm")   # under the name: the figure's feet cover the bottom
    return im


def textures(out):
    os.makedirs(out, exist_ok=True)
    for k in PAL["order"]:
        f = PAL["factions"][k]
        t = f["tie"]
        tie_texture(t["base"], t["stripe"], t["thin"], f["metal"]).save(os.path.join(out, f"tie_{k}.png"))
        armband(f).save(os.path.join(out, f"arm_{k}.png"))
        roundel(f).save(os.path.join(out, f"back_{k}.png"))
        banner(f).save(os.path.join(out, f"banner_{k}.png"))
    print("[faction_dress_art] textures ->", out)


# ---------------- sheets ----------------
DEUTAN = np.array([[0.367322, 0.860646, -0.227968], [0.280085, 0.672501, 0.047413], [-0.011820, 0.042940, 0.968881]])  # Machado 2009, severity 1


def deutan(im):
    a = np.asarray(im.convert("RGB")).astype(np.float64) / 255.0
    lin = np.where(a <= 0.04045, a / 12.92, ((a + 0.055) / 1.055) ** 2.4)
    s = np.clip(lin @ DEUTAN.T, 0, 1)
    out = np.where(s <= 0.0031308, s * 12.92, 1.055 * s ** (1 / 2.4) - 0.055)
    return Image.fromarray((out * 255).astype(np.uint8), "RGB")


def on_bg(path, bg):
    fig = Image.open(path).convert("RGBA")
    base = bg.copy().convert("RGBA") if isinstance(bg, Image.Image) else Image.new("RGBA", fig.size, rgb(bg) + (255,))
    base = base.resize(fig.size)
    base.alpha_composite(fig)
    return base.convert("RGB")


def label(im, text, size=26):
    d = ImageDraw.Draw(im)
    d.text((im.width // 2, 8), text, fill=(235, 235, 235), font=font(size, True), anchor="mt")


def sheet_rows(rows, titles, out_path, row_labels=None, pad=16, title=None):
    """a grid: column widths from the widest image in each column, every image centred in its cell, titles over the columns"""
    cols = len(rows[0])
    colw = [max(r[c].width for r in rows) for c in range(cols)]
    rowh = [max(i.height for i in r) for r in rows]
    left = 170 if row_labels else 0
    top = 60 if title else 0
    W = left + sum(colw) + pad * (cols + 1)
    H = top + 40 + sum(rowh) + pad * (len(rows) + 1)
    sheet = Image.new("RGB", (max(W, 1400 if title else 0), H), (24, 25, 28))
    d = ImageDraw.Draw(sheet)
    if title:
        d.text((pad, 16), title, fill=(240, 240, 240), font=font(30, True))
    x = left + pad
    for c in range(cols):
        d.text((x + colw[c] // 2, top + 20), titles[c], fill=(240, 240, 240), font=font(24, True), anchor="mm")
        x += colw[c] + pad
    y = top + 40 + pad
    for ri, r in enumerate(rows):
        if row_labels:
            d.text((pad, y + rowh[ri] // 2), row_labels[ri], fill=(210, 210, 210), font=font(22, True), anchor="lm")
        x = left + pad
        for c, i in enumerate(r):
            sheet.paste(i, (x + (colw[c] - i.width) // 2, y + (rowh[ri] - i.height) // 2))
            x += colw[c] + pad
        y += rowh[ri] + pad
    sheet.save(out_path)
    print("[faction_dress_art] sheet ->", out_path)


def sheets(out):
    order = PAL["order"]
    names = [f"{PAL['factions'][k]['name']} · {PAL['factions'][k]['background']}" for k in order]
    short = [PAL["factions"][k]["name"] for k in order]
    board = "#2A2B2F"     # a dark board floor: the worst case for the dark factions
    # 1. the ranking portraits: the figure over its faction's banner
    portraits = [on_bg(os.path.join(out, f"agent_{k}_portrait.png"), Image.open(os.path.join(out, f"banner_{k}.png"))) for k in order]
    details = [on_bg(os.path.join(out, f"agent_{k}_detail.png"), "#3A3C42") for k in order]
    sheet_rows([portraits, details], names, os.path.join(out, "sheet_agent_portraits.png"),
               title="D78 · the Agent per background: ranking portrait (banner behind) and detail · Blender EEVEE mock, not the engine")
    # 2. the game size: 132x200 on a dark board, real size and 3x, then the 3x through a deuteranopia simulation
    game = [on_bg(os.path.join(out, f"agent_{k}_game.png"), board) for k in order]
    big = [g.resize((g.width * 3, g.height * 3), Image.NEAREST) for g in game]
    sheet_rows([game, big, [deutan(b) for b in big]], short, os.path.join(out, "sheet_agent_game.png"),
               row_labels=["132x200", "same, x3", "deuteranopia"],
               title="D78 · the Agent at play size (camera 30° / 45°), dark board · Blender mock")
    # 3. the field officers' overcoats from behind (what the LED coat imitates), portrait and play size, plus deuteranopia
    ob = [on_bg(os.path.join(out, f"officer_{k}_back.png"), "#3A3C42") for k in order]
    og = [on_bg(os.path.join(out, f"officer_{k}_game.png"), board) for k in order]
    ogb = [g.resize((g.width * 3, g.height * 3), Image.NEAREST) for g in og]
    sheet_rows([ob, ogb, [deutan(b) for b in ogb]], short, os.path.join(out, "sheet_officer_coats.png"),
               row_labels=["from behind", "play size x3", "deuteranopia"],
               title="D78 · field officers' overcoats from behind (the LED coat's bluff view) · Blender mock")
    # 4. the Agent in each faction's uniform (the coat changes colour; his fedora does not), if rendered
    if os.path.exists(os.path.join(out, f"uniform_{order[0]}_portrait.png")):
        fr = [on_bg(os.path.join(out, f"uniform_{k}_portrait.png"), "#3A3C42") for k in order]
        bk = [on_bg(os.path.join(out, f"uniform_{k}_back.png"), "#3A3C42") for k in order]
        ug = [on_bg(os.path.join(out, f"uniform_{k}_game.png"), board) for k in order]
        ugb = [g.resize((g.width * 3, g.height * 3), Image.NEAREST) for g in ug]
        sheet_rows([fr, bk, ugb, [deutan(b) for b in ugb]], short, os.path.join(out, "sheet_agent_uniforms.png"),
                   row_labels=["front", "behind", "play size x3", "deuteranopia"],
                   title="D78 · the Agent in each faction's uniform (fedora his own, armband follows the coat) · Blender mock")


if __name__ == "__main__":
    if len(sys.argv) != 3 or sys.argv[1] not in ("textures", "sheets"):
        raise SystemExit("usage: faction_dress_art.py textures|sheets <out_dir>")
    (textures if sys.argv[1] == "textures" else sheets)(sys.argv[2])
