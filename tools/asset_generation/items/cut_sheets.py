"""ITEMS_MASTER_PLAN §2.11 / §7 — re-cut every Nano Banana reference sheet (kept in REFERENCES/ITEMS/) and gather each object's
views for Tripo into temp/items_tripo/by_object/<object>/{front,side,top}.png. temp/ may be wiped at any time: this rebuilds it.
Each sheet's flags are the ones that cut it clean (2026-11-16, checked by eye); a pale or thin object gets a row run of its own.
Then it lays them out as PAGES for Tripo (Director, 2026-11-16): two images per page, the same objects in the same slots, one with every
object's FRONT and one with every object's SIDE (or every object's TOP): temp/items_tripo/pages/PAGE_<n>_FRONT.png + _SIDE / _TOP.png.
Run: python3 tools/asset_generation/items/cut_sheets.py"""
import os, shutil, subprocess, sys, tempfile
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
REF = os.path.join(ROOT, "REFERENCES", "ITEMS")
OUT = os.path.join(ROOT, "temp", "items_tripo")
CROP = os.path.join(os.path.dirname(__file__), "crop_sheet.py")

# sheet -> (file, names, flags, [row runs: (y0, y1, names, flags)])
SHEETS = {
    "sheet1": ("Gemini_Generated_Image_jzebf0jzebf0jzeb.jpeg", "taser,brass_knuckles,detonator,universal_remote,spray_can",
               ["--left", "front"], []),
    "sheet2": ("Gemini_Generated_Image_uqqbj2uqqbj2uqqb.jpeg", "wrist_bracer,wrist_blade,grapple_launcher,grappling_hook_rope,lockpicks,zip_ties",
               ["--left", "side", "--open", "3", "--min-area", "0.0003"], []),
    "sheet3": ("Gemini_Generated_Image_nkpviunkpviunkpv.jpeg", "c4_block,breaching_charge,gas_grenade,emp_charge,tripwire_flash",
               ["--left", "side", "--keep", "-1"], []),
    "sheet4": ("Gemini_Generated_Image_gavaq2gavaq2gava.jpeg", "firework_lure,baseball,drink_can,chloroform_bottle,folded_rag",
               ["--views", "front,top", "--row-gap", "5"],
               [(240, 405, "baseball", ["--views", "front,top", "--min-area", "0.01", "--raw", "--raw-pad", "20"]),
                (415, 600, "glass_tumbler", ["--views", "front,top", "--threshold", "8", "--open", "3", "--min-area", "0.01", "--raw"])]),
    "sheet5": ("Gemini_Generated_Image_vyxq89vyxq89vyxq.jpeg", "alarm_clock,radio_clock,drone_controller,radio_scrambler,phone_cloner",
               ["--views", "front,side", "--keep", "-1", "--row-gap", "10"], []),
    "sheet6": ("Gemini_Generated_Image_xdsru2xdsru2xdsr.jpeg", "tablet,camera_loop_rig,shadow_generator,motion_detector,noise_detector",
               ["--views", "front,side", "--keep", "-1", "--row-gap", "10"], []),
    "sheet7": ("Gemini_Generated_Image_gizydngizydngizy.jpeg", "sample_case,police_badge",
               ["--views", "front,side", "--row-gap", "10", "--keep", "-1"], []),
    "sheet8": ("Gemini_Generated_Image_my1ryfmy1ryfmy1r.jpeg", "scout_drone,c4_block,breaching_charge,universal_remote,zip_ties",
               ["--views", "front,top", "--row-gap", "10", "--keep", "-1", "--open", "5", "--min-area", "0.0005"], []),
    "sheet9": ("Gemini_Generated_Image_chtytchtytchtytc.jpeg", "brass_knuckles,lockpicks,wedding_ring",
               ["--views", "front,top", "--row-gap", "30", "--keep", "-1", "--open", "5", "--min-area", "0.0005"],
               [(590, 785, "lockpicks", ["--views", "front,top", "--row-gap", "30", "--keep", "-1", "--open", "3", "--min-area", "0.002"])]),
}

# object -> {Tripo view: "sheetN/<file stem>"}. Where a sheet's column is not the view its name says, the mapping says what it is
# (sheet 3's gas grenade and EMP: the right column is a TOP; sheet 8's C4 / remote "front" is a second top, so only their top is used).
# Not here: the folded rag (made by hand), the hand crossbow (cut down from a downloaded crossbow).
OBJECTS = {
    "taser": {"front": "sheet1/taser_front", "side": "sheet1/taser_side"},
    "brass_knuckles": {"front": "sheet1/brass_knuckles_front", "side": "sheet1/brass_knuckles_side", "top": "sheet9/brass_knuckles_top"},
    "detonator": {"front": "sheet1/detonator_front", "side": "sheet1/detonator_side"},
    "universal_remote": {"front": "sheet1/universal_remote_front", "top": "sheet8/universal_remote_top"},
    "spray_can": {"front": "sheet1/spray_can_front", "side": "sheet1/spray_can_side"},
    "wrist_bracer": {"side": "sheet2/wrist_bracer_side", "front": "sheet2/wrist_bracer_front"},
    "wrist_blade": {"side": "sheet2/wrist_blade_side", "front": "sheet2/wrist_blade_front"},
    "grapple_launcher": {"side": "sheet2/grapple_launcher_side", "front": "sheet2/grapple_launcher_front"},
    "grappling_hook_rope": {"side": "sheet2/grappling_hook_rope_side", "front": "sheet2/grappling_hook_rope_front"},
    "lockpicks": {"front": "sheet9/lockpicks_front", "top": "sheet9/lockpicks_top"},
    "zip_ties": {"front": "sheet8/zip_ties_front", "top": "sheet8/zip_ties_top"},
    "c4_block": {"side": "sheet3/c4_block_side", "front": "sheet3/c4_block_front", "top": "sheet8/c4_block_top"},
    "breaching_charge": {"side": "sheet3/breaching_charge_side", "front": "sheet3/breaching_charge_front", "top": "sheet8/breaching_charge_top"},
    "gas_grenade": {"front": "sheet3/gas_grenade_side", "top": "sheet3/gas_grenade_front"},
    "emp_charge": {"front": "sheet3/emp_charge_side", "top": "sheet3/emp_charge_front"},
    "tripwire_flash": {"side": "sheet3/tripwire_flash_side", "front": "sheet3/tripwire_flash_front"},
    "firework_lure": {"front": "sheet4/firework_lure_front", "top": "sheet4/firework_lure_top"},
    "baseball": {"front": "sheet4/baseball_front", "top": "sheet4/baseball_top"},
    "glass_tumbler": {"front": "sheet4/glass_tumbler_front", "top": "sheet4/glass_tumbler_top"},
    "drink_can": {"front": "sheet4/drink_can_front", "top": "sheet4/drink_can_top"},
    "chloroform_bottle": {"front": "sheet4/chloroform_bottle_front", "top": "sheet4/chloroform_bottle_top"},
    "alarm_clock": {"front": "sheet5/alarm_clock_front", "side": "sheet5/alarm_clock_side"},
    "radio_clock": {"front": "sheet5/radio_clock_front", "side": "sheet5/radio_clock_side"},
    "drone_controller": {"front": "sheet5/drone_controller_front", "side": "sheet5/drone_controller_side"},
    "radio_scrambler": {"front": "sheet5/radio_scrambler_front"},   # its "side" was drawn as a second front
    "phone_cloner": {"front": "sheet5/phone_cloner_front", "side": "sheet5/phone_cloner_side"},
    "tablet": {"front": "sheet6/tablet_front", "side": "sheet6/tablet_side"},
    "camera_loop_rig": {"front": "sheet6/camera_loop_rig_front", "side": "sheet6/camera_loop_rig_side"},
    "shadow_generator": {"front": "sheet6/shadow_generator_front", "side": "sheet6/shadow_generator_side"},
    "motion_detector": {"front": "sheet6/motion_detector_front", "side": "sheet6/motion_detector_side"},
    "noise_detector": {"front": "sheet6/noise_detector_front", "side": "sheet6/noise_detector_side"},
    "sample_case": {"front": "sheet7/sample_case_front", "side": "sheet7/sample_case_side"},
    "police_badge": {"front": "sheet7/police_badge_front", "side": "sheet7/police_badge_side"},
    "scout_drone": {"front": "sheet8/scout_drone_front", "top": "sheet8/scout_drone_top"},
    "wedding_ring": {"front": "sheet9/wedding_ring_front", "top": "sheet9/wedding_ring_top"},
}


def crop(src, out, names, flags):
    r = subprocess.run([sys.executable, CROP, src, out, "--names", names] + flags, capture_output=True, text=True)
    if r.returncode != 0:
        raise SystemExit("[cut_sheets] %s: %s" % (src, r.stderr.strip() or r.stdout.strip()))


for sheet, (fname, names, flags, rows) in SHEETS.items():
    out = os.path.join(OUT, sheet)
    shutil.rmtree(out, ignore_errors=True)
    src = os.path.join(REF, fname)
    crop(src, out, names, flags)
    for y0, y1, name, rflags in rows:
        with tempfile.TemporaryDirectory() as tmp:
            im = Image.open(src)
            row = os.path.join(tmp, "row.png")
            im.crop((0, y0, im.size[0], y1)).save(row)
            crop(row, os.path.join(tmp, "cut"), name, rflags)
            for f in os.listdir(os.path.join(tmp, "cut")):
                if f.startswith(name):
                    shutil.copy(os.path.join(tmp, "cut", f), os.path.join(out, f))
    print("[cut_sheets] %s cut" % sheet)

by = os.path.join(OUT, "by_object")
shutil.rmtree(by, ignore_errors=True)
count = 0
for obj, views in OBJECTS.items():
    os.makedirs(os.path.join(by, obj))
    for view, stem in views.items():
        shutil.copy(os.path.join(OUT, stem + ".png"), os.path.join(by, obj, view + ".png"))
        count += 1
print("[cut_sheets] %d objects, %d views -> %s" % (len(OBJECTS), count, by))

# Pages: objects of a similar size, four to a page, one slot each (top to bottom). An object's two views come from its own squared cut,
# so they share one scale; each slot is filled by its object. The scrambler has no second view and is left out (one image is enough).
# A FRONT + TOP page also gets a FRONT + SIDE version (a top cannot stand in for a side: the can is 12.2 cm tall from the front and
# 6.6 cm from above, and no object is both, standing). A round object is LAID DOWN (below); the three flat ones take a front + side
# pair cut together on sheets 1 / 2 (one scale). Both are filed as front_fs / side_fs.
ROUND = ["gas_grenade", "emp_charge", "firework_lure", "chloroform_bottle", "baseball", "glass_tumbler", "drink_can", "wedding_ring",
         "scout_drone"]
FRONT_SIDE_PAIR = {"universal_remote": ("sheet1/universal_remote_front", "sheet1/universal_remote_side"),
                   "lockpicks": ("sheet2/lockpicks_side", "sheet2/lockpicks_front"),
                   "zip_ties": ("sheet2/zip_ties_side", "sheet2/zip_ties_front")}
# LAID DOWN (the Director, 2026-11-16): a round object is laid on its side, its axis left-right. Its FRONT is then its front turned
# 90 degrees (its top to the left) and its LEFT side is its TOP view, both as tall as its diameter: one object, consistent, and the
# top's detail (a can's tab, the drone's arms) reaches Tripo. The model is stood back up by hand.
def object_box(im):
    """The object's box (x0, y0, x1, y1) in a cut: the pixels that differ from the cut's own corner background."""
    import numpy as np
    a = np.asarray(im.convert("RGB")).astype(np.int16)
    bg = np.median(np.concatenate([a[:6, :6].reshape(-1, 3), a[-6:, -6:].reshape(-1, 3)]), axis=0)
    ys, xs = np.nonzero(np.abs(a - bg).max(axis=2) > 18)
    return xs.min(), ys.min(), xs.max() + 1, ys.max() + 1


for obj in ROUND:
    front = Image.open(os.path.join(by, obj, "front.png")).rotate(90, expand=True)
    front.save(os.path.join(by, obj, "front_fs.png"))
    # The image model drew some tops at another scale than their front (the gas grenade's circle ~1.6x its body): the top is scaled
    # so its height matches the laid front's height (both are the diameter), and centred where the front is.
    top = Image.open(os.path.join(by, obj, "top.png"))
    fx0, fy0, fx1, fy1 = object_box(front)
    tx0, ty0, tx1, ty1 = object_box(top)
    k = (fy1 - fy0) / float(ty1 - ty0)
    part = top.crop((tx0, ty0, tx1, ty1)).resize((max(1, round((tx1 - tx0) * k)), fy1 - fy0), Image.LANCZOS)
    canvas = Image.new("RGB", top.size, top.getpixel((2, 2)))
    canvas.paste(part, ((top.width - part.width) // 2, fy0))
    canvas.save(os.path.join(by, obj, "side_fs.png"))
for obj, (f, sd) in FRONT_SIDE_PAIR.items():
    shutil.copy(os.path.join(OUT, f + ".png"), os.path.join(by, obj, "front_fs.png"))
    shutil.copy(os.path.join(OUT, sd + ".png"), os.path.join(by, obj, "side_fs.png"))

PAGES = [
    ("side", ["taser", "detonator", "spray_can", "phone_cloner"]),
    ("side", ["brass_knuckles", "motion_detector", "noise_detector", "police_badge"]),
    ("side", ["wrist_bracer", "wrist_blade", "grapple_launcher", "grappling_hook_rope"]),
    ("side", ["c4_block", "breaching_charge", "tripwire_flash", "camera_loop_rig"]),
    ("side", ["alarm_clock", "radio_clock", "drone_controller", "tablet"]),
    ("side", ["shadow_generator", "sample_case"]),
    ("top", ["gas_grenade", "emp_charge", "firework_lure", "chloroform_bottle"]),
    ("top", ["baseball", "glass_tumbler", "drink_can", "wedding_ring"]),
    ("top", ["scout_drone", "universal_remote", "lockpicks", "zip_ties"]),
]
SLOT, MARGIN = 512, 64
PAGE_BG = (222, 222, 220)   # ONE background for every page (Director, 2026-11-16: the sheets' greys and white differed)
BG_TOLERANCE = 14


# A clear object is nearly the background: a tighter tolerance keeps the flood out of it.
BG_TOLERANCE_OF = {"glass_tumbler": 4}


def unify_background(im, tolerance=BG_TOLERANCE):
    """The background as seen from the image's border (flood: every near-background pixel connected to the border, so a light
    object's own inside, a white ball, a clear glass, is not touched) becomes PAGE_BG; a cut's square of another grey goes with it."""
    import numpy as np
    from scipy import ndimage
    a = np.asarray(im.convert("RGB")).astype(np.int16)
    edge = np.concatenate([a[0], a[-1], a[:, 0], a[:, -1]])
    bg = np.median(edge, axis=0)
    near = np.abs(a - bg).max(axis=2) <= tolerance
    lab, _ = ndimage.label(near)
    border = np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))
    outside = np.isin(lab, border[border > 0])
    a[outside] = PAGE_BG
    # A speck the sheet left (the tick of a measure line) is a tiny island of non-background: it goes too.
    objects, n = ndimage.label(~outside)
    if n > 1:
        sizes = ndimage.sum(np.ones_like(objects), objects, range(1, n + 1))
        for k, size in enumerate(sizes, start=1):
            if size < 0.01 * sizes.max():   # tiny next to the object itself (a lone small object, the blade's end, is its own largest)
                a[objects == k] = PAGE_BG
    return Image.fromarray(a.astype(np.uint8))

pages = os.path.join(OUT, "pages")
shutil.rmtree(pages, ignore_errors=True)
os.makedirs(pages)
for n, (second, objs) in enumerate(PAGES, start=1):
    sets = [("front", "front"), (second, second)]
    if second == "top":   # the SIDE version of a top page
        sets += [("front_fs", "front_laid"), ("side_fs", "side_laid")]
    for view, label in sets:
        page = Image.new("RGB", (SLOT + 2 * MARGIN, len(objs) * SLOT + (len(objs) + 1) * MARGIN), PAGE_BG)
        for i, obj in enumerate(objs):
            name = view

            im = unify_background(Image.open(os.path.join(by, obj, name + ".png")).resize((SLOT, SLOT), Image.LANCZOS),
                                  BG_TOLERANCE_OF.get(obj, BG_TOLERANCE))
            page.paste(im, (MARGIN, MARGIN + i * (SLOT + MARGIN)))
        page.save(os.path.join(pages, "PAGE_%d_%s.png" % (n, label.upper())))
print("[cut_sheets] %d pages (front + side / top) -> %s" % (len(PAGES), pages))

