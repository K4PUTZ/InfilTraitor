# hero_piece_sheets.py — one contact sheet per piece from hero_piece_renders.py's output: the four views side by side on a neutral backdrop, titled with the piece,
# its meshes, triangles (master LOD) and posed height. Usage: python3 -I hero_piece_sheets.py <out folder>
import json, os, sys
from PIL import Image, ImageDraw, ImageFont

OUT = sys.argv[1].rstrip("/") + "/"
REP = json.load(open(OUT + "pieces.json"))
FONT = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"
FONT_N = "/System/Library/Fonts/Supplemental/Arial Narrow Bold.ttf"
H = 640; PAD = 24; TOP = 96; BOT = 46
VIEW_NAMES = {"three_quarter": "3/4", "three_quarter_back": "3/4 back", "game_camera": "game camera (30°/45°)"}


def backdrop(w, h):
    im = Image.new("RGBA", (w, h))
    d = ImageDraw.Draw(im)
    for y in range(h):
        t = y / max(1, h - 1)
        c = tuple(int(a + (b - a) * t) for a, b in zip((112, 116, 124), (78, 81, 88)))
        d.line([(0, y), (w, y)], fill=c + (255,))
    return im


for key, r in REP.items():
    panels = [(vn, Image.open(p).convert("RGBA")) for vn, p in r["views"]]
    panels = [(vn, im.resize((int(im.width * H / im.height), H), Image.LANCZOS)) for vn, im in panels]
    W = PAD + sum(im.width + PAD for _, im in panels)
    sheet = backdrop(W, TOP + H + BOT)
    d = ImageDraw.Draw(sheet)
    d.text((PAD, 16), r["label"], fill=(245, 245, 245), font=ImageFont.truetype(FONT, 34))
    meta = f'{" + ".join(r["meshes"])}   ·   {r["tris"]:,} tris (master)   ·   {r["height_cm"]} cm tall   ·   pose: {r["pose"]}'.replace(",", " ")
    d.text((PAD, 60), meta, fill=(205, 208, 214), font=ImageFont.truetype(FONT_N, 21))
    x = PAD
    for vn, im in panels:
        sheet.alpha_composite(im, (x, TOP))
        d.text((x + im.width // 2, TOP + H + 10), VIEW_NAMES.get(vn, vn), fill=(225, 228, 232), font=ImageFont.truetype(FONT_N, 24), anchor="mt")
        x += im.width + PAD
    sheet.convert("RGB").save(OUT + f"sheet_{key}.png")
    print("wrote", OUT + f"sheet_{key}.png", sheet.size)
