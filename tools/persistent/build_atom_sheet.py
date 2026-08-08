#!/usr/bin/env python3
##
## build_atom_sheet.py — compose a printable contact sheet of every baked
## damage atom (ATOM-EXPORT, Director 2026-08-08).
##
## Input is whatever `INFILTRAITOR_CAPTURE_ACTION=export_atoms` dumped into
## Screenshots/atoms/ — one PNG per atom plus manifest.json. Produces a
## labeled PNG and a PDF of the same layout.
##
## Why the split (Godot dumps, Python composes): GDScript's Image API has no
## text rendering, and the whole point of this sheet is knowing WHICH decal you
## are looking at while you edit its source art. PIL has fonts and writes PDF
## directly.
##
## The atoms are 32x36 voxel tiles on transparent backgrounds. They are drawn
## on a light checkerboard rather than a flat fill: several decals are
## themselves near-white or near-black, and on a flat background one end of
## that range disappears into it — the exact failure this sheet exists to
## catch.
##
##   python3 tools/persistent/build_atom_sheet.py [--scale N] [--substrate S]
##
##   --scale      integer upscale, nearest-neighbour (default 4)
##   --substrate  only this substrate index, or "all" (default "all")
##

import argparse
import json
import os
import sys

try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:
    sys.exit("[ATOM-SHEET] Pillow is required: pip3 install Pillow")

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ATOMS_DIR = os.path.join(PROJECT_ROOT, "Screenshots", "atoms")
OUT_PNG = os.path.join(PROJECT_ROOT, "Screenshots", "atom_sheet.png")
OUT_PDF = os.path.join(PROJECT_ROOT, "Screenshots", "atom_sheet.pdf")

## Surfaces in a fixed reading order, so the sheet looks the same every run.
ELEMENT_ORDER = ["WALL", "CEILING", "FLOOR"]

BG = (250, 250, 250)
CHECK_A = (214, 214, 218)
CHECK_B = (232, 232, 236)
INK = (20, 20, 22)
MUTED = (110, 110, 118)
RULE = (198, 198, 204)

PAD = 24
GUTTER = 14
LABEL_H = 17


def load_font(size, bold=False):
    candidates = [
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf" if bold
        else "/System/Library/Fonts/Supplemental/Arial.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf" if bold
        else "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    ]
    for path in candidates:
        if os.path.exists(path):
            try:
                return ImageFont.truetype(path, size)
            except OSError:
                continue
    return ImageFont.load_default()


def checkerboard(size, cell=6):
    """Neutral backdrop that keeps both near-white and near-black decals readable."""
    w, h = size
    board = Image.new("RGB", size, CHECK_A)
    draw = ImageDraw.Draw(board)
    for y in range(0, h, cell):
        for x in range(0, w, cell):
            if ((x // cell) + (y // cell)) % 2 == 0:
                draw.rectangle([x, y, x + cell - 1, y + cell - 1], fill=CHECK_B)
    return board


def group_atoms(manifest, substrate_filter):
    """material -> element -> family -> [atom rows], each sorted by (substrate, variant)."""
    grouped = {}
    for atom in manifest["atoms"]:
        if substrate_filter != "all" and int(atom["substrate"]) != int(substrate_filter):
            continue
        grouped.setdefault(atom["material"], {}) \
               .setdefault(atom["element"], {}) \
               .setdefault(atom["family"], []).append(atom)
    for material in grouped:
        for element in grouped[material]:
            for family in grouped[material][element]:
                grouped[material][element][family].sort(
                    key=lambda a: (int(a["substrate"]), int(a["variant"])))
    return grouped


def elements_of(by_element):
    """ELEMENT_ORDER first, then anything unexpected — a new surface class must
    appear on the sheet rather than be silently dropped from it."""
    ordered = [e for e in ELEMENT_ORDER if e in by_element]
    extra = sorted(e for e in by_element if e not in ordered)
    if extra:
        print("[ATOM-SHEET] note: unlisted element_class(es) appended: %s" % ", ".join(extra))
    return ordered + extra


def main():
    parser = argparse.ArgumentParser(description="Compose the baked-damage-atom contact sheet")
    parser.add_argument("--scale", type=int, default=4, help="integer upscale (default 4)")
    parser.add_argument("--substrate", default="all", help='substrate index, or "all" (default)')
    args = parser.parse_args()

    manifest_path = os.path.join(ATOMS_DIR, "manifest.json")
    if not os.path.exists(manifest_path):
        sys.exit("[ATOM-SHEET] no manifest at %s\n"
                 "  Export first:  INFILTRAITOR_CAPTURE_ACTION=export_atoms "
                 "python3 tools/persistent/auto_screenshot.py" % manifest_path)
    with open(manifest_path) as handle:
        manifest = json.load(handle)

    grouped = group_atoms(manifest, args.substrate)
    if not grouped:
        sys.exit("[ATOM-SHEET] nothing matched substrate=%s" % args.substrate)

    scale = max(1, args.scale)
    tile_w, tile_h = 32 * scale, 36 * scale
    title_font = load_font(30, bold=True)
    material_font = load_font(22, bold=True)
    element_font = load_font(15, bold=True)
    row_font = load_font(13)
    small_font = load_font(11)

    ## Measure first, draw second — the sheet's height depends on how many
    ## families each material actually has, which differs per material
    ## (metal/wood have no blast-crack: crack_factor 0).
    materials = sorted(grouped)
    column_w = max(tile_w * 3 + GUTTER * 2, 260) + GUTTER * 2
    heights = []
    for material in materials:
        height = 34
        for element in elements_of(grouped[material]):
            height += 24
            for family in sorted(grouped[material][element]):
                count = len(grouped[material][element][family])
                per_row = max(1, min(count, 3))
                rows = (count + per_row - 1) // per_row
                height += LABEL_H + rows * (tile_h + 6) + 8
        heights.append(height)

    sheet_w = PAD * 2 + column_w * len(materials)
    sheet_h = PAD * 2 + 58 + max(heights)
    sheet = Image.new("RGB", (sheet_w, sheet_h), BG)
    draw = ImageDraw.Draw(sheet)

    draw.text((PAD, PAD), "INFILTRAITOR — baked damage atoms", font=title_font, fill=INK)
    subtitle = "map %s · %d atoms · substrate %s · %dx" % (
        manifest.get("map_id", "?"), sum(
            len(v) for m in grouped.values() for e in m.values() for v in e.values()),
        args.substrate, scale)
    draw.text((PAD, PAD + 34), subtitle, font=small_font, fill=MUTED)

    for index, material in enumerate(materials):
        x0 = PAD + index * column_w
        y = PAD + 58
        if index:
            draw.line([(x0 - GUTTER, PAD + 58), (x0 - GUTTER, sheet_h - PAD)], fill=RULE)

        draw.text((x0, y), material.upper(), font=material_font, fill=INK)
        y += 34

        for element in elements_of(grouped[material]):
            draw.text((x0, y), element, font=element_font, fill=(60, 90, 150))
            y += 24
            for family in sorted(grouped[material][element]):
                atoms = grouped[material][element][family]
                draw.text((x0, y), "%s  (%d)" % (family, len(atoms)), font=row_font, fill=MUTED)
                y += LABEL_H
                for slot, atom in enumerate(atoms):
                    col = slot % 3
                    row = slot // 3
                    tx = x0 + col * (tile_w + GUTTER)
                    ty = y + row * (tile_h + 6)
                    path = os.path.join(ATOMS_DIR, atom["file"])
                    if not os.path.exists(path):
                        draw.rectangle([tx, ty, tx + tile_w, ty + tile_h], outline=(200, 60, 60))
                        continue
                    atom_img = Image.open(path).convert("RGBA")
                    atom_img = atom_img.resize((tile_w, tile_h), Image.NEAREST)
                    backdrop = checkerboard((tile_w, tile_h), cell=max(4, scale * 2))
                    backdrop.paste(atom_img, (0, 0), atom_img)
                    sheet.paste(backdrop, (tx, ty))
                rows = (len(atoms) + 2) // 3
                y += rows * (tile_h + 6) + 8

    sheet.save(OUT_PNG)
    sheet.convert("RGB").save(OUT_PDF, "PDF", resolution=150.0)
    print("[ATOM-SHEET] %s  (%dx%d)" % (os.path.relpath(OUT_PNG, PROJECT_ROOT), sheet_w, sheet_h))
    print("[ATOM-SHEET] %s" % os.path.relpath(OUT_PDF, PROJECT_ROOT))


if __name__ == "__main__":
    main()
