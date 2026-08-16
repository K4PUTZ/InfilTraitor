"""CHARACTER_MASTER_PLAN Part 3 — contact sheet for the three postures.

Reads what p3_posture_export.py rendered and builds one sheet at TRUE SHIP SIZE
and one at 3x, following p2_grip_sheet.py's convention and for its reason: S1
paid for the lesson on 2026-08-14, when six compression variants were obviously
different at 8x and indistinguishable at real size.

WHAT IT GATES, because a sheet that merely looks right proves nothing:
  - a silhouette touching the canvas edge FAILS. A cropped prone figure is
    exactly what a 288 px frame is there to prevent;
  - the ground line and the voxel ruler are DERIVED from the manifest's own
    projection constants, not drawn where they look right — so the Director can
    literally count the 10.0 / 6.1 / 2.9 voxels rather than take them from a log.

WHAT IT DELIBERATELY DOES NOT GATE: silhouette height against
`height x cos(elevation)`. That comparison was written twice in one day on
2026-08-16, in two languages, and reported a false failure both times — an
isometric silhouette is TALLER than its figure, because the body's own depth
projects into screen-Y as well. Scale is gated where it can be gated exactly,
in the export (metres) and in the Godot bake (a 0.20 m rise must draw 20 px).

Run (system python3, NOT Blender — this one needs PIL):
  python3 tools/asset_generation/p3_posture_sheet.py
"""

import json
import math
import os
import sys

from PIL import Image, ImageDraw

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(REPO_ROOT, "Screenshots", "p3_postures")
# Named, not auto_: the rotation keeps only the 50 most recent auto_ files.
OUT_1X = os.path.join(REPO_ROOT, "Screenshots", "history", "p3_postures.png")
OUT_3X = os.path.join(REPO_ROOT, "Screenshots", "history", "p3_postures_3x.png")

BG = (58, 60, 66)
INK = (232, 233, 238)
DIM = (150, 152, 160)
RULE = (92, 95, 104)
GROUND = (196, 128, 96)
PAD = 14
LABEL_W = 96
HEAD_H = 26
FOOT_H = 34

ELEV_DEG = 30.0
VOXEL_M = 0.20
# The camera target p3_posture_export.py inherits from p2_grip_spike.setup_render.
CAM_TARGET_Z = 0.98


def fail(m):
    print("[P3-SHEET][FAIL] %s" % m)
    sys.exit(1)


def ground_y(frame_h, px_per_m):
    """Screen row of world z=0, derived from the camera the render actually used.

    The camera looks at CAM_TARGET_Z, which therefore lands on the frame's centre
    row; a world-vertical metre occupies cos(elevation) metres of screen."""
    return frame_h * 0.5 + CAM_TARGET_Z * math.cos(math.radians(ELEV_DEG)) * px_per_m


def main():
    man_path = os.path.join(SRC, "manifest.json")
    if not os.path.isfile(man_path):
        fail("%s missing — run p3_posture_export.py first" % man_path)
    man = json.load(open(man_path))
    fw, fh = man["frame"]
    px_per_m = man["px_per_screen_m"]
    facings = [man["facings"][k] for k in sorted(man["facings"], key=int)]
    postures = [p["name"] for p in man["postures"]]

    gy = ground_y(fh, px_per_m)
    voxel_px = VOXEL_M * math.cos(math.radians(ELEV_DEG)) * px_per_m
    print("[P3-SHEET] ground row %.1f, one voxel of HEIGHT draws %.2f px" % (gy, voxel_px))

    tiles = {}
    for posture in postures:
        for facing in facings:
            path = os.path.join(SRC, "%s_%s.png" % (posture, facing))
            if not os.path.isfile(path):
                fail("missing frame %s" % os.path.relpath(path, REPO_ROOT))
            img = Image.open(path).convert("RGBA")
            if img.size != (fw, fh):
                fail("%s is %s, manifest says %s" % (path, img.size, (fw, fh)))
            box = img.getchannel("A").point(lambda a: 255 if a > 20 else 0).getbbox()
            if box is None:
                fail("%s/%s rendered an EMPTY frame" % (posture, facing))
            if box[0] <= 0 or box[1] <= 0 or box[2] >= fw or box[3] >= fh:
                fail("%s/%s is CROPPED (silhouette %s in a %dx%d frame)"
                     % (posture, facing, box, fw, fh))
            tiles[(posture, facing)] = (img, box)
            # The foot row is reported against the derived ground line: a posture
            # that floats or sinks shows up here as pixels, before it reaches a
            # bake that would accept it silently.
            print("[P3-SHEET] %-9s %-2s silhouette %dx%d, foot row %d (ground %.0f, "
                  "delta %+.0f px), top %.2f voxels above ground"
                  % (posture, facing, box[2] - box[0], box[3] - box[1], box[3],
                     gy, box[3] - gy, (gy - box[1]) / voxel_px))

    for scale, out in ((1, OUT_1X), (3, OUT_3X)):
        tw, th = fw * scale, fh * scale
        W = LABEL_W + PAD + len(facings) * (tw + PAD)
        H = HEAD_H + len(postures) * (th + PAD) + FOOT_H
        sheet = Image.new("RGB", (W, H), BG)
        d = ImageDraw.Draw(sheet)
        d.text((PAD, 7), "CHARACTER Part 3 — postures, grip %s, %dx"
               % (man["grip"], scale), fill=INK)

        for r, posture in enumerate(postures):
            y = HEAD_H + r * (th + PAD)
            d.text((PAD, y + th // 2 - 6), posture, fill=INK)
            for c, facing in enumerate(facings):
                x = LABEL_W + PAD + c * (tw + PAD)
                if r == 0:
                    d.text((x + tw // 2 - 8, 7), facing, fill=DIM)
                img, _ = tiles[(posture, facing)]
                if scale != 1:
                    img = img.resize((tw, th), Image.NEAREST)
                # The voxel ruler, drawn UNDER the figure so it never hides it.
                gy_s = gy * scale
                step = voxel_px * scale
                n = 0
                while gy_s - n * step > y - y + 0:
                    yy = y + gy_s - n * step
                    if yy < y:
                        break
                    d.line([(x, yy), (x + tw, yy)],
                           fill=GROUND if n == 0 else RULE, width=1)
                    n += 1
                sheet.paste(img, (x, y), img)
                d.rectangle([x, y, x + tw - 1, y + th - 1], outline=RULE)

        # Read from the manifest, never typed in. The one number this sheet ever
        # hardcoded went stale within the hour, on the same day the same class of
        # error was caught by the Godot bake's height gate.
        measured = " / ".join("%s %.2f" % (p["name"], p["voxels"])
                              for p in man["postures"])
        d.text((PAD, H - FOOT_H + 6),
               "one rule = one voxel of HEIGHT (%.2f px at %dx); orange = world z=0. "
               "Measured off the exported GLBs, in voxels: %s."
               % (voxel_px * scale, scale, measured), fill=DIM)
        os.makedirs(os.path.dirname(out), exist_ok=True)
        sheet.save(out)
        print("[P3-SHEET] wrote %s (%dx%d)" % (os.path.relpath(out, REPO_ROOT), W, H))


if __name__ == "__main__":
    main()
