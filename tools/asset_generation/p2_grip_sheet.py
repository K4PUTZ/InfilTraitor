"""CHARACTER_MASTER_PLAN Part 2 — contact sheet for the three-grip spike.

Reads what p2_grip_spike.py rendered and builds two sheets: one at TRUE SHIP
SIZE, which is the one the decision is made on, and one at 3x for inspecting why.
Both exist because S1 paid for the lesson on 2026-08-14 — six compression
variants were obviously different at 8x and indistinguishable at real size.

IT ALSO GATES, because a contact sheet that merely looks right proves nothing:
  - every frame's figure is MEASURED from its alpha channel and compared against
    the size the game's own projection demands (VOXEL_STEP_PX / voxel metres),
    so a camera drift shows up as a number rather than as a vague impression;
  - any frame whose silhouette touches the canvas edge fails, because a cropped
    weapon is exactly the thing this spike cannot afford to hide.

Run (system python3, NOT Blender — this one needs PIL):
  python3 tools/asset_generation/p2_grip_sheet.py
"""

import json
import os
import sys

from PIL import Image, ImageDraw

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(REPO_ROOT, "Screenshots", "p2_grips")
# Named, not auto_: the rotation keeps only the 50 most recent auto_ files, and
# 16 of 23 captures cited across the docs were already gone when that was
# measured on 2026-08-03. A cited capture has to opt out of the rotation.
OUT_1X = os.path.join(REPO_ROOT, "Screenshots", "history", "p2_grip_matrix.png")
OUT_3X = os.path.join(REPO_ROOT, "Screenshots", "history", "p2_grip_matrix_3x.png")

BG = (58, 60, 66)
INK = (232, 233, 238)
DIM = (150, 152, 160)
RULE = (92, 95, 104)
PAD = 14
LABEL_W = 104
HEAD_H = 26

# The reference silhouette is predicted by projecting the real vertices through
# the real camera, so this is an alignment tolerance, not a fudge factor: a
# couple of pixels for the alpha threshold at the silhouette's edge.
SIZE_TOL_PX = 3.0


def fail(m):
    print("[P2-SHEET][FAIL] %s" % m)
    sys.exit(1)


def alpha_bbox(im):
    return im.getchannel("A").getbbox()


def weapon_read(with_gun, without_gun):
    """How much of the weapon actually reaches the screen, and how far it sits
    from what is behind it.

    Two numbers, both from the same frame pair:
      px      — pixels that changed when the weapon was added. This is the
                weapon's VISIBLE area after the body occludes it, not its area.
      delta_L — mean |luminance| difference over exactly those pixels. A weapon
                can occupy 300 px and still be unreadable if every one of them
                is within a few levels of the charcoal suit behind it.
    """
    if not os.path.isfile(without_gun):
        fail("missing body-only frame for %s" % os.path.basename(with_gun))
    a = Image.open(with_gun).convert("RGBA")
    b = Image.open(without_gun).convert("RGBA")
    if a.size != b.size:
        fail("frame pair size mismatch for %s" % os.path.basename(with_gun))
    pa, pb = a.load(), b.load()
    n, total = 0, 0.0
    for y in range(a.height):
        for x in range(a.width):
            ra, ga, ba, aa = pa[x, y]
            rb, gb, bb, ab = pb[x, y]
            if (ra, ga, ba, aa) == (rb, gb, bb, ab):
                continue
            n += 1
            la = (0.2126 * ra + 0.7152 * ga + 0.0722 * ba) * (aa / 255.0)
            lb = (0.2126 * rb + 0.7152 * gb + 0.0722 * bb) * (ab / 255.0)
            total += abs(la - lb)
    return dict(weapon_px=n, weapon_delta_l=round(total / n, 1) if n else 0.0)


def build(frames, manifest, zoom, out_path):
    cell_w, cell_h = manifest["frame"]
    cw, ch = cell_w * zoom, cell_h * zoom
    yaws = manifest["yaws"]
    rows = [tuple(k) for k in manifest["order"]]

    w = LABEL_W + PAD + len(yaws) * (cw + PAD)
    h = HEAD_H + PAD + len(rows) * (ch + PAD)
    sheet = Image.new("RGB", (w, h), BG)
    draw = ImageDraw.Draw(sheet)

    facings = manifest["facings"]
    for ci, yaw in enumerate(yaws):
        x = LABEL_W + PAD + ci * (cw + PAD)
        # The compass name is what the frame IS; the yaw is only how it was
        # produced. Labelling by yaw invites exactly the misreading the glossary
        # bans.
        draw.text((x + 2, 8), "facing %s   (yaw %d)" % (facings[str(yaw)], yaw),
                  fill=INK)

    for ri, (weapon, grip) in enumerate(rows):
        y = HEAD_H + PAD + ri * (ch + PAD)
        draw.text((6, y + 4), weapon, fill=INK)
        draw.text((6, y + 18), grip, fill=DIM)
        draw.line([(0, y - PAD // 2), (w, y - PAD // 2)], fill=RULE)
        for ci, yaw in enumerate(yaws):
            fn = "%s_%s_yaw%03d.png" % (weapon, grip, yaw)
            p = os.path.join(SRC, fn)
            if not os.path.isfile(p):
                fail("missing frame %s" % fn)
            im = Image.open(p).convert("RGBA")
            if zoom != 1:
                im = im.resize((cw, ch), Image.NEAREST)
            x = LABEL_W + PAD + ci * (cw + PAD)
            sheet.paste(im, (x, y), im)

    sheet.save(out_path)
    print("[P2-SHEET] wrote %s (%dx%d, %dx)"
          % (os.path.relpath(out_path, REPO_ROOT), w, h, zoom))


def main():
    mpath = os.path.join(SRC, "manifest.json")
    if not os.path.isfile(mpath):
        fail("no manifest — run p2_grip_spike.py in Blender first")
    with open(mpath) as fh:
        manifest = json.load(fh)
    frames = manifest["frames"]
    cell_w, cell_h = manifest["frame"]

    print("[P2-SHEET] scale: %.2f px per screen-metre at elevation %.0f — a "
          "0.20 m voxel draws 20.0 px, and the %.3f m figure occludes %.1f px "
          "of vertical (%.2f voxels, §4.7)"
          % (manifest["px_per_screen_m"], manifest["elevation_deg"],
             manifest["figure_height_m"], manifest["vertical_reach_px"],
             manifest["figure_height_m"] / 0.20))

    problems = []

    # THE SIZE GATE. Measured silhouette vs the box predicted by projecting the
    # real vertices through the real camera. Any camera drift shows up here as
    # pixels, on a weapon-free frame so nothing else can absorb the error.
    ref = os.path.join(SRC, manifest["reference_frame"])
    if not os.path.isfile(ref):
        fail("reference frame missing: %s" % manifest["reference_frame"])
    got = alpha_bbox(Image.open(ref).convert("RGBA"))
    want = manifest["reference_bbox_predicted"]
    if got is None:
        fail("reference frame is empty")
    dev = max(abs(got[i] - want[i]) for i in range(4))
    print("[P2-SHEET] size gate: reference silhouette measured %s vs predicted "
          "%s -> worst edge %.1f px" % (got, tuple(round(v, 1) for v in want), dev))
    if dev > SIZE_TOL_PX:
        problems.append("the reference silhouette is %.1f px off its predicted "
                        "box — the render is not at the projection this spike "
                        "claims to judge at" % dev)

    for f in frames:
        p = os.path.join(SRC, f["file"])
        if not os.path.isfile(p):
            fail("missing frame %s" % f["file"])
        box = alpha_bbox(Image.open(p).convert("RGBA"))
        if box is None:
            problems.append("%s is empty" % f["file"])
            continue
        x0, y0, x1, y1 = box
        if x0 <= 0 or y0 <= 0 or x1 >= cell_w or y1 >= cell_h:
            problems.append("%s is CROPPED (bbox %s in %dx%d) — the silhouette "
                            "runs off the canvas, which is the one thing this "
                            "spike cannot judge around"
                            % (f["file"], box, cell_w, cell_h))
        f["px"] = [x1 - x0, y1 - y0]
        f.update(weapon_read(p, os.path.join(SRC, "nogun", f["file"])))

    if problems:
        for p in problems:
            print("[P2-SHEET][FAIL] %s" % p)
        sys.exit(1)

    print("[P2-SHEET] weapon read — visible px and mean luminance distance from "
          "what is behind them:")
    for f in frames:
        print("[P2-SHEET]   %-8s %-8s %-3s -> silhouette %3dx%3d | weapon %4d px "
              "| delta L %5.1f"
              % (f["weapon"], f["grip"], f["facing"], f["px"][0], f["px"][1],
                 f["weapon_px"], f["weapon_delta_l"]))

    os.makedirs(os.path.dirname(OUT_1X), exist_ok=True)
    build(frames, manifest, 1, OUT_1X)
    build(frames, manifest, 3, OUT_3X)


if __name__ == "__main__":
    main()
