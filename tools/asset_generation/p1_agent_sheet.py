"""CHARACTER_MASTER_PLAN Part 1 — composites the T-pose preview into one sheet.

Separate from p1_agent_preview.py because that one runs inside Blender, whose
bundled Python has no PIL. This is plain system python3 and only reads the PNGs
Blender already wrote.

The sheet deliberately ends with the figure at SHIP SIZE (196 px, §4.7) beside a
3x blow-up of the same pixels. Judging a model only at poster size is judging a
view the player never sees -- S1 paid for that on 2026-08-14, when six
compression variants were obvious in an 8x strip and indistinguishable at the
shotgun's real 66x33 px.

Run:
  python3 tools/asset_generation/p1_agent_sheet.py
"""

import os
import sys

from PIL import Image, ImageDraw, ImageFont

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(REPO_ROOT, "Screenshots", "p1_preview")
OUT = os.path.join(REPO_ROOT, "Screenshots", "history", "p1_agent_tpose_sheet.png")

BG = (58, 58, 64)
INK = (238, 238, 242)
INK_DIM = (168, 168, 176)
PAD = 20

FONTS = ["/System/Library/Fonts/Supplemental/Arial Bold.ttf",
         "/System/Library/Fonts/Supplemental/Arial.ttf"]


def font(size):
    for p in FONTS:
        if os.path.isfile(p):
            try:
                return ImageFont.truetype(p, size)
            except OSError:
                pass
    return ImageFont.load_default()


def load(name):
    p = os.path.join(SRC, name)
    if not os.path.isfile(p):
        print("[P1-SHEET][FAIL] missing %s\nRun p1_agent_preview.py first." % p)
        sys.exit(1)
    return Image.open(p).convert("RGBA")


def main():
    views = [("view_front.png", "FRONT"), ("view_side.png", "SIDE"),
             ("view_back.png", "BACK"), ("view_game.png", "GAME CAMERA\nelev 30 / azim 45")]
    ims = [(load(n), lab) for n, lab in views]
    vw, vh = ims[0][0].size

    ship_g, ship_f = load("ship_game.png"), load("ship_front.png")
    sw, sh = ship_g.size
    ship_block_w = sw * 2 + 16 + (sw * 3) * 2 + 16 + 24

    head_h = 74
    strip_y = head_h + vh + 10
    W = PAD * 2 + max(vw * len(ims), ship_block_w)
    # Height accounts for the 3x blow-ups UP FRONT. Growing the canvas after
    # compositing does not un-clip anything that was already pasted past the old
    # edge -- the first run lost the bottom 85% of both blow-ups that way.
    H = strip_y + 22 + sh * 3 + PAD

    sheet = Image.new("RGBA", (W, H), BG)
    d = ImageDraw.Draw(sheet)
    d.text((PAD, 16), "The agent — first real T-pose", font=font(30), fill=INK)
    d.text((PAD, 50),
           "20 bones · 36 rigid parts · 2432 faces · 1.898 m tall · 1.760 m span · "
           "rest pose verified an exact T off the armature",
           font=font(15), fill=INK_DIM)

    for i, (im, lab) in enumerate(ims):
        x = PAD + i * vw
        sheet.alpha_composite(im, (x, head_h))
        for j, line in enumerate(lab.split("\n")):
            d.text((x + 12, head_h + vh - 34 + j * 17), line,
                   font=font(15 if j == 0 else 13),
                   fill=INK if j == 0 else INK_DIM)

    y = strip_y
    d.text((PAD, y), "AT SHIP SIZE — 196 px (§4.7: 9.8 voxels × VOXEL_STEP_PX 20), "
                     "then the same pixels at 3×",
           font=font(15), fill=INK_DIM)
    x = PAD
    for im in (ship_g, ship_f):
        sheet.alpha_composite(im, (x, y + 22))
        x += im.width + 16
    x += 24
    for im in (ship_g, ship_f):
        big = im.resize((im.width * 3, im.height * 3), Image.NEAREST)
        sheet.alpha_composite(big, (x, y + 22))
        x += big.width + 16

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    sheet.convert("RGB").save(OUT)
    print("[P1-SHEET] wrote %s (%dx%d)"
          % (os.path.relpath(OUT, REPO_ROOT), sheet.width, sheet.height))


if __name__ == "__main__":
    main()
