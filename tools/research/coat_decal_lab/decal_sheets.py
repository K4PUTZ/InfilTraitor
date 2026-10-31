"""decal_sheets.py — contact sheets of decal_render.py's renders, female row over male row (ACTOR D90).
full:   sheet_1_quatro_simbolos.png (the four emblems from behind), sheet_2_decal_vs_assado.png (A the decal, B baked into the coat's own
        1024 texture), sheet_3_movimento.png (6 frames per clip: both figures' stealth run, the male's walk and run), sheet_4_jogo_x1.png /
        sheet_4_jogo_x3.png (the game camera at size and x3), run_costas.gif (the stealth run from behind, both figures).
stills: v2_costas.png, v2_close.png, v2_jogo_x2.png (STILLS_ONLY renders: every emblem from behind, up close, at the game camera x2).
Tags expected: f, m (and m_walk, m_run for the male's walk / run in `full`).
Usage: python3 -I decal_sheets.py <full|stills> <render_dir> <out_dir>
"""
import sys
from PIL import Image, ImageDraw, ImageFont

MODE, R, OUT = sys.argv[1], sys.argv[2], sys.argv[3]
BG = (44, 45, 50)
K = ("fid", "cws", "bbm", "corp")
try:
    FONT = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf", 22)
except OSError:
    FONT = ImageFont.load_default()


def im(name, size=None, nearest=False):
    i = Image.open(f"{R}/{name}").convert("RGB")
    return i.resize(size, Image.NEAREST if nearest else Image.LANCZOS) if size else i


def grid(rows, labels, path, pad=6, lab_w=150):
    w = max(sum(i.width for i in r) + pad * (len(r) - 1) for r in rows) + lab_w
    h = sum(max(i.height for i in r) for r in rows) + pad * (len(rows) - 1)
    S = Image.new("RGB", (w, h), BG); d = ImageDraw.Draw(S); y = 0
    for r, lab in zip(rows, labels):
        x = lab_w; rh = max(i.height for i in r)
        for i in r:
            S.paste(i, (x, y)); x += i.width + pad
        d.multiline_text((10, y + rh // 2 - 24), lab, fill=(230, 230, 230), font=FONT, spacing=4)
        y += rh + pad
    S.save(path); print(f"[decal_sheets] {path}")


FM = ["feminino", "masculino"]
if MODE == "full":
    grid([[im(f"{t}_back_{k}.png", (270, 378)) for k in K] for t in "fm"], FM, f"{OUT}/sheet_1_quatro_simbolos.png")
    grid([[im(f"{t}_close_decal.png", (420, 420)), im(f"{t}_close_baked.png", (420, 420))] for t in "fm"],
         ["feminino\nA | B", "masculino\nA | B"], f"{OUT}/sheet_2_decal_vs_assado.png")
    runs = [("f", "fem.\ncorrida\nfurtiva"), ("m", "masc.\ncorrida\nfurtiva"), ("m_walk", "masc.\ncaminhada"), ("m_run", "masc.\ncorrida")]
    grid([[im(f"{t}_run_{i:02d}.png", (240, 240)) for i in range(0, 24, 4)] for t, _ in runs], [l for _, l in runs], f"{OUT}/sheet_3_movimento.png")

    def game(t):
        return [f"{t}_game_rest_135.png", f"{t}_game_rest_225.png"] + [f"{t}_game_run_{i:02d}.png" for i in (0, 6, 12, 18)]
    grid([[im(n) for n in game(t)] for t in "fm"], FM, f"{OUT}/sheet_4_jogo_x1.png", lab_w=130)
    grid([[im(n, (480, 720), nearest=True) for n in game(t)[:3]] for t in "fm"], ["feminino\n(x3)", "masculino\n(x3)"], f"{OUT}/sheet_4_jogo_x3.png")
    frames = []
    for i in range(24):
        S = Image.new("RGB", (726, 360), BG); S.paste(im(f"f_run_{i:02d}.png", (360, 360)), (0, 0)); S.paste(im(f"m_run_{i:02d}.png", (360, 360)), (366, 0))
        frames.append(S)
    frames[0].save(f"{OUT}/run_costas.gif", save_all=True, append_images=frames[1:], duration=66, loop=0); print(f"[decal_sheets] {OUT}/run_costas.gif")
elif MODE == "stills":
    grid([[im(f"{t}_back_{k}.png", (270, 378)) for k in K] for t in "fm"], FM, f"{OUT}/v2_costas.png")
    grid([[im(f"{t}_close_{k}.png", (330, 330)) for k in K] for t in "fm"], FM, f"{OUT}/v2_close.png")
    grid([[im(f"{t}_game_{k}.png", (320, 480), nearest=True) for k in K] for t in "fm"], ["feminino\n(x2)", "masculino\n(x2)"], f"{OUT}/v2_jogo_x2.png")
else:
    sys.exit(f"[decal_sheets] ERROR: mode {MODE!r} is neither full nor stills")
