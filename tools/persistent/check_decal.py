#!/usr/bin/env python3
##
## check_decal.py — the acceptance gate for a delivered damage decal.
##
## WHY THIS EXISTS, and why it is a SEPARATE gate from check_facade.py. A decal
## fails differently from a facade, in three ways that all render *something*:
##
##   - a decal with NO transparency is not a mark, it is a new face: it covers
##     the whole voxel side and the material underneath disappears;
##   - a decal delivered with two variants instead of three is a hard B6 error
##     at boot, because the runtime picks its variant by hashing the voxel's
##     coordinates into 0..IMPACT_DECAL_VARIANTS-1 and expects all three to load;
##   - a material added to VoxelRenderer.IMPACT_DECAL_MATERIALS with no files on
##     disk is a SILENT MISS, not an error — the same failure class as a
##     rejected facade, which is what earned check_facade.py in the first place.
##
## The spec being enforced is ASSETS/ART_SPECIFICATIONS.md §7, and every
## threshold below was measured against the 45 SHIPPED decals rather than read
## off it — the facade gate's first run failed two shipped files because it
## enforced the doc instead of the art, and that correction is the precedent
## here.
##
## Checks, in the order they bite:
##   1. filename        — decal_<family>_<material>_<n>.png, family in the set
##                        THAT MATERIAL claims (glass takes `shard` and nothing
##                        else — G-ART), n in 0..2
##   2. dimensions      — 256x256 exactly, square (§7: a voxel face is square
##                        in flat space; the x20/16 stretch is the generator's)
##   3. alpha channel   — REQUIRED, unlike a facade. §7: "the decal is a mark on
##                        a face, not a face"
##   4. coverage        — how much of the canvas the mark occupies, REPORTED,
##                        and failed only at the two useless extremes. The
##                        shipped art spans 2.6%..82.9%, so any band tighter
##                        than that would reject known-good work
##   5. peak opacity    — reported only. 6 of the 9 shipped concrete decals peak
##                        BELOW 255 (150, 179, 194, 204...): these tint the face
##                        rather than replace it, which is the house style, not
##                        a defect
##   6. imported        — the .import sidecar's own dest_files exist on disk.
##                        NOT an mtime comparison, for check_facade.py's reason
##   7. family complete — with --material, all 3 variants of every family the
##                        material claims. This is the check the runtime needs
##                        and the one a per-file gate cannot do
##
## A SECOND ASSET CLASS lives here since 2026-09-01 (GLASS_MASTER_PLAN G-ART):
## the FRACTURE SHEET, `fracture_<material>_<tight|wide>.png`. It is facade-
## shaped (1024x512 = one 64x32-voxel page) and decal-semantic (it is a mark),
## so neither existing gate fits it — see the FRACTURE_* block below. Its own
## checks are dimensions, grayscale (B2), fracture coverage, IMPORT, and the one
## that justifies the class: the fracture's ORIGIN must be the page centre,
## because G-D21 re-anchors the sheet by (impact - centre) and an off-centre
## origin displaces every crack in the game by a constant nobody will see.
##
## Usage:
##     python3 tools/persistent/check_decal.py <file.png> [<file.png> ...]
##     python3 tools/persistent/check_decal.py --material brick
##     python3 tools/persistent/check_decal.py --material glass
##     python3 tools/persistent/check_decal.py --all
##
## Exit code is 0 only if every file PASSes, so it can gate a delivery.

import os
import re
import sys

try:
    from PIL import Image
except ImportError:
    print("[DECAL] Pillow is required: python3 -m pip install pillow")
    sys.exit(2)

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
## ASSET_TREE_REFORM (2026-08-21): one folder per material, decals in
## `<material>/decals/`. The material-agnostic family lives in `_generic/`.
MATERIALS_ROOT = os.path.join(REPO_ROOT, "ASSETS", "materials")
GENERIC_MATERIAL = "_generic"


def decal_dir(material):
    return os.path.join(MATERIALS_ROOT, material, "decals")
RENDERER = os.path.join(REPO_ROOT, "godot", "scripts", "geometry", "voxel_renderer.gd")
## The two files the SHEET wiring check reads. GlassMaterials owns the width
## roster (the same file CLAUDE.md rule L2 already parses the glass family out
## of), and TextureResolver is where a sheet is accepted or silently dropped.
GLASS_MATERIALS = os.path.join(REPO_ROOT, "godot", "scripts", "systems", "glass_materials.gd")
TEXTURE_RESOLVER = os.path.join(REPO_ROOT, "godot", "scripts", "systems", "texture_resolver.gd")
GLASS_CRACK = os.path.join(REPO_ROOT, "godot", "scripts", "systems", "destruction", "glass_crack.gd")

## §7, pinned: 256x256 is 16x the canonical TEX_AUTHORING_N density, and square
## because a voxel face is square in flat space. The x20/16 vertical stretch
## onto a lateral face belongs to the generator, never to the art.
DECAL_W = 256
DECAL_H = 256

## voxels/manifest.json's own `variant_count`, and the range the runtime hashes
## into. Not a convention — a missing variant is a boot-time B6 failure.
VARIANT_COUNT = 3
FAMILIES = ("bullet", "dent", "crack")

## GLASS_MASTER_PLAN G-ART (2026-09-01). A material's families are no longer a
## single global tuple, because GLASS DOES NOT TAKE THE WALL FAMILIES AND THAT IS
## A RULE RATHER THAN AN OMISSION:
##
##   - `dent` is impossible for glass, permanently. G-D3 amended D22 so CRACKED
##     returns and DENTED never does — glass fractures, it does not deform, and
##     `dent_factor` is pinned at 0.0 to say so. A delivered `decal_dent_glass_*`
##     is a file nothing can ever load, which is the same silent miss this gate
##     is named after.
##   - `bullet` and `crack` are not 256x256 decals for glass either. G-D21 makes
##     a pane fracture a SHEET re-anchored onto the impact (see FRACTURE_* below)
##     with the hole baked at its centre, so the per-voxel bullet mark is folded
##     into the sheet rather than authored separately.
##   - what glass DOES claim as an ordinary decal is `shard` — G-D16b's fallen
##     glass on the floor, which rides `_floor_sunk_decal_plan` exactly like
##     earth's dent and is a mark on a face like any other.
##
## Everything not named here keeps FAMILIES, so all 45 shipped material decals
## are unaffected by construction.
MATERIAL_FAMILIES = {
    "glass": ("shard",),
}


def families_for(material):
    """The families THIS material may claim. Not a filter over one global list:
    a `dent` for glass and a `shard` for concrete are both errors, and only a
    per-material answer can say so."""
    return MATERIAL_FAMILIES.get(material, FAMILIES)


## ---------------------------------------------------------------------------
## Fracture sheets (GLASS_MASTER_PLAN §13, G-D23/G-D27) — a THIRD asset class,
## and it fails like neither of the other two.
##
## A fracture sheet is decal-SEMANTIC (it is a mark, not a surface) and neither
## existing gate is right for it:
##
##   - check_facade.py would PASS a sheet whose fracture is missing or off
##     centre, because it only ever asks about dimensions, grayscale and import;
##   - check_decal.py's own file checks would FAIL it on dimensions, and its
##     alpha rule is actively WRONG here — `BakeCompositor._get_plane_source()`
##     round-trips a facade through RGB8, which flattens any alpha the PNG
##     carries to 255. A sheet authored as "bright crack on transparent" arrives
##     at the compositor as "bright crack on OPAQUE BLACK".
##
## So the sheet is a GRAYSCALE MASK ON A BLACK FIELD: luminance is how much
## fracture is at that texel, and alpha is irrelevant (§7.3's luma-to-alpha step
## applies to the shard DECALS, never to these). That is also what Stable
## Diffusion produces natively, with no matting step at all.
##
## ⚠️ CRACK-02 (G-D27) TOOK THE SIZE CONTRACT OFF THIS CLASS, and this gate moved
## with it in S-1's own commit — the alternative, spelled out in §13.3, is that
## the gate rejects good art on size while `TextureResolver` drops it into the
## generic atlas with no error at all.
##
## Until CRACK-02 the sheet was facade-SHAPED (one 64x32-voxel page) because
## G-D21 had it riding the facade compositing path, re-anchored by offsetting
## `(column_in_run, level)`. It does not ride that path any more: a crack is a
## SPRITE scaled by `GlassCrack.SHEET_SPAN_*`, so PIXEL dimensions carry no
## contract — only the ASPECT does, because the span is authored in voxels and a
## sheet whose aspect disagrees with its span is stretched on the pane.
##
## What survives untouched is the ANCHOR (below): `Sprite2D.centered` puts the
## page centre on the impact, so an off-centre bore still lands every crack a
## fixed distance from the round that made it. G-D28's four classes (S-4) will
## make that rule class-dependent — `blast` has no centre at all — and this gate
## grows a class column when that art is ordered, not before.
## ⚠️ A FALLBACK, NOT THE RULE — CORRECTED 2026-09-05 (G-D35 B-3). The rule was
## always the sentence three paragraphs up: *"a sheet whose aspect disagrees with
## its SPAN is stretched on the pane"*. 2.0 was true of every span that existed,
## so the constant and the rule were indistinguishable until a class arrived whose
## span is square — and then the constant would have rejected correct art with the
## message "square; the span is 2:1", which is a gate confidently wrong. The span
## is read from the manifest per sheet now; this stands in only when the manifest
## has no row, where the check is nearly meaningless anyway.
FRACTURE_ASPECT = 2.0           ## width / height, when the manifest cannot say
FRACTURE_ASPECT_SLACK = 0.02    ## PNG dimensions are integers; 2% absorbs rounding
FRACTURE_MIN_PX = 128           ## below this there is no web to resolve, at any span
## G-D35 B-3 — how much worse a tile's wrap seam may look than the same edge's own
## inward neighbour. Measured on both sides before it was written down: the worst
## of the 18 shipped craze sheets scores 1.35, and a page with the toroidal wrap
## removed scores 7.26 / 11.69.
FRACTURE_SEAM_MAX_RATIO = 2.0
TEX_AUTHORING_N = 16    ## pinned, ASSETS/ART_SPECIFICATIONS.md §1

## G-D14's two hole sizes, and the sheet count is exactly two because of it:
## pistol/shotgun take the tight web, rifle-class the wide/spaced one.
## ⛔ IT WAS `("tight", "wide")`. CRACK-04 retired both — they drew a ROUND hole,
## and no member of the opening family is round. The roster is one family per
## OPENING x variant now, read from the manifest the generator writes beside the
## sheets rather than listed here: `glass_opening.gd` is the one authority, and a
## copy in this file would pass a stale gate on stale art.
FRACTURE_MANIFEST = os.path.join(REPO_ROOT, "ASSETS/materials/glass/fracture_manifest.json")


def _fracture_manifest():
    import json
    if not os.path.exists(FRACTURE_MANIFEST):
        return {}
    with open(FRACTURE_MANIFEST) as f:
        return json.load(f)

## Which materials claim a sheet. `glass_armored` and `glass_screen_*` reuse
## these (G-D16: the variants differ by tint and class, never by geometry), so
## G-VARIANT adds no art and this tuple does not grow with it.
FRACTURE_MATERIALS = ("glass",)

## B2, and the tolerance is check_facade.py's own: for PNG quantisation, not for
## "a bit of colour".
CHANNEL_TOLERANCE = 2

## ⚠️ UNLIKE EVERY OTHER NUMBER IN THIS FILE, THE THREE BELOW ARE NOT MEASURED —
## there is no shipped fracture art to measure against yet, and this gate is
## deliberately being earned BEFORE the delivery (the M2a precedent). So they sit
## at the useless extremes only, which is the same discipline COVERAGE_FLOOR /
## COVERAGE_CEILING already follow for decals. Re-measure them against the first
## accepted sheet rather than leaving them as a spec nobody checked.
FRACTURE_INK_MIN = 8            ## luminance above the black field = fracture
FRACTURE_COVERAGE_FLOOR = 0.1   ## below this the page carries no crack at all
FRACTURE_COVERAGE_CEILING = 90.0  ## above this it is a lit page, not a fracture

## THE ONE THRESHOLD THAT IS STRUCTURAL RATHER THAN AESTHETIC, and the reason
## this check exists at all. `GlassCrackSprite` is `centered`, so the page centre
## goes on the impact: the fracture's ORIGIN must be the sheet's centre. Author it
## off centre and every crack in the game lands a fixed distance from where the
## round actually hit — systematically, invisibly, forever. A radial fracture's
## ink-weighted centroid IS its origin by construction, so the centroid is a
## direct measurement of that claim.
##
## ⚠️ A FRACTION OF THE PAGE, NOT A VOXEL COUNT — and it is the SAME tolerance,
## re-expressed. It used to read "4 voxels" against a fixed 64x32 authoring page,
## which is 4/64 of the width and 4/32 of the height. With CRACK-02 the page has
## no fixed voxel extent (its span is a runtime dial, GlassCrack.SHEET_SPAN_*), so
## a voxel count would have quietly become 3x more permissive on a `tight` sheet.
FRACTURE_ORIGIN_SLACK_X = 4.0 / 64.0    ## of page width
FRACTURE_ORIGIN_SLACK_Y = 4.0 / 32.0    ## of page height

## Measured over all 45 shipped decals: coverage runs 2.6% to 82.9% — a span
## wide enough that ANY meaningful band would reject known-good art. The generic
## crack family sits at 2.9% and is correct at that size. So the gate rejects
## only the two extremes that cannot be art at all: an empty canvas and a full
## one.
COVERAGE_FLOOR = 0.5
COVERAGE_CEILING = 99.5


def _wired_materials():
    """The materials VoxelRenderer will actually ask the disk for.

    Read from the source rather than duplicated here, because the whole failure
    this gate exists for is the two lists DISAGREEING: a material in
    IMPACT_DECAL_MATERIALS with no files on disk is a silent miss, and a
    material with files but not in the list is 9 PNGs nothing will ever load.
    Returns None if the constant cannot be found, so a refactor of that file
    degrades this to "cannot check" instead of to a false pass.
    """
    wired = None
    floor = ""
    try:
        for line in open(RENDERER, encoding="utf-8", errors="replace"):
            if line.startswith("const IMPACT_DECAL_MATERIALS"):
                ## Split on "=" FIRST. Splitting on "[" straight away picks up
                ## the one in `Array[String]` and mangles the first entry into
                ## `String] = ["concrete` — caught by running this against
                ## concrete, which is wired and complete and was reported as
                ## unwired.
                rhs = line.split("=", 1)[-1]
                inside = rhs.split("[", 1)[-1].rsplit("]", 1)[0]
                wired = [t.strip().strip('"') for t in inside.split(",") if t.strip()]
            elif line.startswith("const IMPACT_FLOOR_MATERIAL"):
                ## `earth` is wired through a DIFFERENT constant — it is the
                ## shared floor-dent family every ground material routes to
                ## (D26), deliberately outside IMPACT_DECAL_MATERIALS. Reading
                ## only the first list reported earth's 3 shipped dent files as
                ## "nothing will ever load them", which is the check_facade.py
                ## mistake exactly: a gate that fails known-good art is
                ## measuring the wrong thing.
                floor = line.split("=", 1)[-1].strip().strip('"')
        if wired is not None:
            return wired + ([floor] if floor else [])
    except OSError:
        return None
    return None


def _floor_material():
    """IMPACT_FLOOR_MATERIAL — reported separately so the wiring line is honest
    about WHICH constant carries the material."""
    try:
        for line in open(RENDERER, encoding="utf-8", errors="replace"):
            if line.startswith("const IMPACT_FLOOR_MATERIAL"):
                return line.split("=", 1)[-1].strip().strip('"')
    except OSError:
        pass
    return ""


def _parse_name(name):
    """decal_<family>_<material>_<n>.png -> (family, material, n) or None."""
    if not name.startswith("decal_") or not name.endswith(".png"):
        return None
    stem = name[len("decal_"):-len(".png")]
    parts = stem.split("_")
    if len(parts) < 3 or not parts[-1].isdigit():
        return None
    family = parts[0]
    ## The material may itself contain an underscore (the generic family is
    ## "generic_bullet_dented"), so it is everything between family and index.
    material = "_".join(parts[1:-1])
    return family, material, int(parts[-1])


def _import_notes(path):
    """The compiled-resource check, shared with check_facade.py's reasoning."""
    notes = []
    imp = path + ".import"
    if not os.path.exists(imp):
        return ["no .import sidecar — Godot has not imported this file, so the "
                "runtime cannot load it and every affected voxel hard-errors at "
                "boot (B6). Focus the editor, or run: "
                "godot --headless --import --path ."]
    dests = []
    for line in open(imp, encoding="utf-8", errors="replace"):
        if line.startswith("dest_files="):
            dests = [d.strip().strip('"') for d in
                     line.split("[", 1)[-1].rstrip().rstrip("]").split(",") if d.strip()]
            break
    if not dests:
        return [".import sidecar names no dest_files — the import did not complete. "
                "Run: godot --headless --import --path ."]
    missing = [d for d in dests
               if not os.path.exists(os.path.join(REPO_ROOT, d.replace("res://", "")))]
    if missing:
        notes.append("compiled resource missing (%s) — reimport: "
                     "godot --headless --import --path ." % ", ".join(missing))
    return notes


def check(path):
    """Returns (ok: bool, lines: list[str])."""
    name = os.path.basename(path)
    notes = []

    if not os.path.exists(path):
        return False, ["%-34s FAIL  file does not exist" % name]

    ok = True

    ## 1. Filename. The runtime composes this name rather than scanning the
    ## directory (a scan does not survive export packing), so a typo here is a
    ## file that exists and is never read.
    parsed = _parse_name(name)
    if parsed is None:
        ok = False
        notes.append("filename does not parse as decal_<family>_<material>_<n>.png")
    else:
        family, material, index = parsed
        ## Per-material, not global (G-ART): `decal_dent_glass_0.png` parses
        ## perfectly and is still art nothing can load, because glass has no
        ## DENTED tier to reach. The generic family is material-agnostic by
        ## definition and keeps its exemption.
        allowed = families_for(material)
        if family not in allowed and not name.startswith("decal_generic_"):
            ok = False
            notes.append("family %r is not one of %s for material %r"
                         % (family, "/".join(allowed), material))
        if index >= VARIANT_COUNT:
            ok = False
            notes.append("variant index %d is outside 0..%d — the runtime hashes "
                         "into that range and will never pick this file"
                         % (index, VARIANT_COUNT - 1))

    try:
        im = Image.open(path)
    except Exception as exc:
        return False, ["%-34s FAIL  not a readable image: %s" % (name, exc)]

    ## 2. Dimensions.
    w, h = im.size
    if (w, h) != (DECAL_W, DECAL_H):
        ok = False
        extra = "  <- not square; §7 requires square, the stretch is the generator's" \
            if w != h else ""
        notes.append("dimensions %dx%d, expected %dx%d%s" % (w, h, DECAL_W, DECAL_H, extra))

    ## 3. TRANSPARENCY REQUIRED — the one place this gate is strictly harsher
    ## than the facade gate, and for the opposite reason. A facade's alpha is
    ## discarded (B3 takes the silhouette from the canonical atom); a decal IS
    ## its transparency. Without it the mark is an opaque square that replaces
    ## the face.
    ##
    ## ⚠️ THE QUESTION IS "IS THE IMAGE TRANSPARENT", NOT "DOES THE FILE HAVE AN
    ## ALPHA BAND", and the difference cost this gate a false rejection. The
    ## first version asked `"A" in im.getbands()` and failed two of the nine
    ## delivered brick cracks — PALETTE PNGs carrying their transparency in a
    ## tRNS chunk, which is an ordinary export. Godot decodes them to RGBA8 with
    ## it intact: measured on the IMPORTED textures, 89.4% and 91.1% of their
    ## pixels are fully transparent. The art was right and the gate was wrong,
    ## which is check_facade.py's own first-run mistake arriving a third time.
    ## Convert first, then ask.
    alpha = im.convert("RGBA").getchannel("A")
    hist = alpha.histogram()
    total = w * h
    opaque_px = total - hist[0]
    coverage = 100.0 * opaque_px / total
    peak = alpha.getextrema()[1]

    ## 4. Coverage, at the two extremes only. The upper one is what now catches a
    ## genuinely opaque delivery: a file with no transparency AT ALL reads 100%
    ## here whether or not it has an alpha band, which is the property that
    ## actually matters.
    if coverage < COVERAGE_FLOOR:
        ok = False
        notes.append("effectively empty — %.2f%% of the canvas carries any alpha. "
                     "A blank decal renders nothing and reports no error"
                     % coverage)
    elif coverage > COVERAGE_CEILING:
        ok = False
        notes.append("fully opaque — %.2f%% of the canvas is solid, so this is a "
                     "face, not a mark on one" % coverage)

    ## 5. Peak opacity — reported. Measured on the shipped concrete family:
    ## bullet 150/204/179, dent 194/254/179, crack 204/255/179. Two thirds of
    ## the reference art never reaches 255 on purpose.
    ## Suppressed when the canvas is empty: "peaks at alpha 0, so it tints
    ## rather than replaces" is true and useless, and a gate that prints
    ## reassurance next to a failure is training the reader to skim.
    if 0 < peak < 255:
        notes.append("note: peaks at alpha %d, so the mark TINTS the face rather "
                     "than replacing it — matches the shipped art, not a defect"
                     % peak)

    ## 6. Imported.
    for n in _import_notes(path):
        ok = False
        notes.append(n)

    head = "%-34s %s  %dx%d %s  coverage %.1f%%" % (
        name, "PASS" if ok else "FAIL", w, h, im.mode, coverage)
    return ok, [head] + ["    - " + n for n in notes]


def _parse_fracture_name(name):
    """fracture_<material>_<width>.png -> (material, width) or None.

    Split from the RIGHT, because the material can itself carry an underscore
    (`glass_armored`) while the width never does — the same reasoning
    `_parse_name` uses for the generic family, applied to the other end of the
    string."""
    if not name.startswith("fracture_") or not name.endswith(".png"):
        return None
    ## ⚠️ SPLIT FROM THE LEFT AGAINST THE KNOWN MATERIALS, not from the right.
    ## Right-splitting worked while the tail was one word (`tight`); every opening
    ## id carries underscores (`star_wild`, `chamfer_45_wide`), so it read
    ## `fracture_glass_star_wild_2` as material `glass_star_wild` / width `2` and
    ## reported BOTH halves unknown on all 36 files — the shape of a parser
    ## failing, not of art failing.
    stem = name[len("fracture_"):-len(".png")]
    for mat in sorted(FRACTURE_MATERIALS, key=len, reverse=True):
        if stem.startswith(mat + "_"):
            return mat, stem[len(mat) + 1:]
    return None


def fracture_path(material, width):
    """Beside the facade, NOT under `decals/` — and that is forced, not chosen.
    `TextureResolver.resolve(id, folder)` reads
    `res://ASSETS/materials/<folder>/<id>.png` with no subdirectory step, so a
    sheet in a subfolder is Tier.NONE: unresolved, no error, generic atlas."""
    return os.path.join(MATERIALS_ROOT, material, "fracture_%s_%s.png" % (material, width))


def check_fracture(path):
    """The fracture-sheet gate. Returns (ok: bool, lines: list[str])."""
    name = os.path.basename(path)
    notes = []

    if not os.path.exists(path):
        return False, ["%-34s FAIL  file does not exist" % name]

    ok = True

    ## 1. Filename. Two things ride on it and both fail silently.
    ##
    ## ⚠️ THE PREFIX IS LOAD-BEARING. `TextureResolver._validate_dimensions()`
    ## infers a texture's category from the filename prefix and returns FALSE for
    ## anything it does not recognise — the file is rejected, the surface falls
    ## back to the generic atlas, and nothing is printed above a WARN. Today the
    ## recognised prefixes are `facade_`, `slice_` and `slab_` ONLY, so a sheet
    ## named `fracture_*` needs its category added there before it resolves.
    ## That one line is listed in ART_ORDER_GLASS.md §4 as work to do when the
    ## art lands, deliberately NOT done in advance: a resolver branch for an
    ## asset class that does not exist yet is a branch nothing exercises.
    parsed = _parse_fracture_name(name)
    if parsed is None:
        ok = False
        notes.append("filename does not parse as fracture_<material>_<width>.png")
    else:
        material, width = parsed
        roster = _fracture_manifest().get("openings", {})
        opening = width.rsplit("_", 1)[0] if "_" in width else width
        if roster and opening not in roster:
            ok = False
            notes.append("opening %r is not in fracture_manifest.json (%d known) — "
                         "the runtime resolves sheets by opening id, so nothing "
                         "will ever load this file" % (opening, len(roster)))
        if material not in FRACTURE_MATERIALS:
            ok = False
            notes.append("material %r claims no fracture sheet (%s do) — nothing "
                         "will ever load this file"
                         % (material, "/".join(FRACTURE_MATERIALS)))

    try:
        im = Image.open(path)
    except Exception as exc:
        return False, ["%-34s FAIL  not a readable image: %s" % (name, exc)]

    ## 2. Dimensions — FREE SINCE CRACK-02, except for the aspect. The sprite is
    ## scaled to `SHEET_SPAN_*` voxels, so pixel size is resolution and nothing
    ## more; but the span is 2:1 (20x10 tight, 44x22 wide), so a sheet authored
    ## square arrives on the pane stretched, and nothing on screen says so.
    w, h = im.size
    ## The span this sheet's own manifest row declares, which is what the aspect
    ## has to match. `armored` is 10x5 and `blast_*` is 8x8; both are correct, and
    ## a single constant can only ever describe one of them.
    span_row = _fracture_manifest().get("openings", {}).get(
        (width.rsplit("_", 1)[0] if parsed and "_" in width else (width if parsed else "")),
        {}).get("span", [])
    want_aspect = (float(span_row[0]) / float(span_row[1])
                   if len(span_row) == 2 and float(span_row[1]) > 0.0 else FRACTURE_ASPECT)
    if w < FRACTURE_MIN_PX or h < FRACTURE_MIN_PX:
        ok = False
        notes.append("dimensions %dx%d — under %d px there is no web left to "
                     "resolve at any span" % (w, h, FRACTURE_MIN_PX))
    elif abs((float(w) / float(h)) - want_aspect) > FRACTURE_ASPECT_SLACK * want_aspect:
        ok = False
        notes.append("aspect %.3f, but its span is %g x %g so the page must be "
                     "%.3f +/- %.0f%% — this arrives stretched on the pane"
                     % (float(w) / float(h), span_row[0] if span_row else 0,
                        span_row[1] if span_row else 0, want_aspect,
                        FRACTURE_ASPECT_SLACK * 100.0))

    ## 3. Grayscale (B2), every pixel — check_facade.py's rule and its tolerance.
    ## Colour reaches a wall through base_color's MULTIPLY, never through a
    ## pattern source, and a fracture sheet is a pattern source.
    ## `tobytes()` rather than `getdata()`: the latter is deprecated for removal
    ## in Pillow 14 and warns on every run, and a gate that prints noise beside
    ## its verdict trains the reader to skim it.
    raw = im.convert("RGB").tobytes()
    total = w * h
    non_gray = 0
    for i in range(0, len(raw), 3):
        r, g, b = raw[i], raw[i + 1], raw[i + 2]
        if max(r, g, b) - min(r, g, b) > CHANNEL_TOLERANCE:
            non_gray += 1
    if non_gray:
        ok = False
        notes.append("non-grayscale on %d of %d pixels (%.2f%%) — B2"
                     % (non_gray, total, 100.0 * non_gray / total))

    ## 4. Ink — the fracture itself, measured as luminance above the black field.
    ## Alpha is NOT consulted and must not be: the facade path round-trips
    ## through RGB8 and flattens it (bake_compositor.gd:556), so a sheet whose
    ## crack lives only in its alpha channel measures as an EMPTY page here,
    ## which is exactly how it would render.
    lum = im.convert("L")
    ink_px = 0
    sum_x = 0.0
    sum_y = 0.0
    sum_w = 0.0
    min_x, max_x, min_y, max_y = w, -1, h, -1
    px = lum.tobytes()
    for i, v in enumerate(px):
        if v < FRACTURE_INK_MIN:
            continue
        x = i % w
        y = i // w
        ink_px += 1
        sum_x += x * v
        sum_y += y * v
        sum_w += v
        if x < min_x:
            min_x = x
        if x > max_x:
            max_x = x
        if y < min_y:
            min_y = y
        if y > max_y:
            max_y = y
    coverage = 100.0 * ink_px / total

    if coverage < FRACTURE_COVERAGE_FLOOR:
        ok = False
        notes.append("effectively empty — %.3f%% of the page carries any fracture "
                     "above luminance %d. A black page renders an untouched pane "
                     "and reports no error" % (coverage, FRACTURE_INK_MIN))
    elif coverage > FRACTURE_COVERAGE_CEILING:
        ok = False
        notes.append("effectively solid — %.1f%% of the page is lit, so this is a "
                     "bright surface, not a fracture on one" % coverage)

    ## 5a. G-D35 B-3 — THE TILE CLASS, WHERE 5 DOES NOT APPLY AND THIS DOES.
    ##
    ## A blast craze has no impact and no centre, so "the ink centroid is the page
    ## centre" is not a claim about it — and worse, a uniform field satisfies it
    ## TRIVIALLY (measured: -0.8%, +0.4%). A check that passes for reasons
    ## unrelated to what it is checking is worse than none: it reads as coverage
    ## and provides none. What the class actually claims is that it TILES, and
    ## that is a real measurement.
    ##
    ## The measurement: on a page that wraps, the first and last columns are
    ## NEIGHBOURS, so their mean absolute difference should look like any other
    ## adjacent pair inside the page. On one that does not, they are two unrelated
    ## slices of the image.
    ##
    ## ⚠️ THE THRESHOLD IS MEASURED AGAINST BOTH SIDES, not picked. Over the 18
    ## shipped craze sheets the worst score is **1.35**; a page drawn with the
    ## toroidal wrap removed — the shape of not tiling — scores **7.26 / 11.69**.
    ## 2.0 sits between them with a factor of 5.4 of separation.
    if parsed and width.rsplit("_", 1)[0] in (_tile_sheets() or set()):
        ratios = _wrap_ratios(im)
        if ratios is None:
            notes.append("seam check skipped — the page could not be read as luma")
        else:
            rc, rr = ratios
            if max(rc, rr) > FRACTURE_SEAM_MAX_RATIO:
                ok = False
                notes.append("THE PAGE DOES NOT TILE — its wrap seam is %.2fx "
                             "(columns) / %.2fx (rows) an ordinary adjacent pair, "
                             "past %.1fx. The shader samples this class with "
                             "repeat_enable, so the seam would be a visible line "
                             "across every crazed pane"
                             % (rc, rr, FRACTURE_SEAM_MAX_RATIO))
            else:
                notes.append("tiles — wrap seam %.2fx / %.2fx an ordinary adjacent "
                             "pair (1.0 = indistinguishable)" % (rc, rr))
    ## 5. THE ORIGIN — the requirement CRACK-02 did NOT remove, and the failure
    ## this gate is worth writing for. `GlassCrackSprite` is `centered`, so the
    ## page centre goes on the impact; if the fracture's origin is not the centre,
    ## every crack in the game sits a fixed distance from the round that made it.
    ## Nothing on screen says so — it just always looks slightly wrong.
    if sum_w > 0.0 and not (parsed and width.rsplit("_", 1)[0] in (_tile_sheets() or set())):
        cx = sum_x / sum_w
        cy = sum_y / sum_w
        fx = (cx - w / 2.0) / float(w)
        fy = (cy - h / 2.0) / float(h)
        ## The span this width is drawn at, so the report can speak in PANE
        ## voxels — the unit the Director actually sees — while the gate itself
        ## stays in page fractions.
        span = _declared_sheet_spans().get(parsed[1] if parsed else "", None)
        as_voxels = ""
        if span:
            as_voxels = "  (%+.1f, %+.1f pane voxels at span %gx%g)" % (
                fx * span[0], fy * span[1], span[0], span[1])
        if abs(fx) > FRACTURE_ORIGIN_SLACK_X or abs(fy) > FRACTURE_ORIGIN_SLACK_Y:
            ok = False
            notes.append("fracture origin is off centre — ink centroid sits "
                         "(%+.1f%%, %+.1f%%) of the page from its centre, past the "
                         "(%.1f%%, %.1f%%) slack%s. The sprite is centred on the "
                         "impact, so this offset would apply to EVERY crack"
                         % (fx * 100.0, fy * 100.0,
                            FRACTURE_ORIGIN_SLACK_X * 100.0,
                            FRACTURE_ORIGIN_SLACK_Y * 100.0, as_voxels))
        else:
            notes.append("origin ok — centroid (%+.1f%%, %+.1f%%) of the page from "
                         "centre%s" % (fx * 100.0, fy * 100.0, as_voxels))

        ## 6. Reach — REPORTED, never failed. This is the number that decides
        ## whether G-D23's "a centred hit can crack the whole pane" is real: the
        ## maximum pane is 64 x 32 voxels, so reaching it from the centre needs 32
        ## columns and 16 rows OF PANE. A tight web is SUPPOSED to fall short
        ## (G-D14), which is why this cannot be a failure.
        rx = max(abs(max_x - w / 2.0), abs(w / 2.0 - min_x)) / float(w)
        ry = max(abs(max_y - h / 2.0), abs(h / 2.0 - min_y)) / float(h)
        if span:
            notes.append("reach %.1f col / %.1f row PANE voxels from centre at "
                         "span %gx%g (a max pane needs 32 / 16 to crack edge to "
                         "edge, G-D23)"
                         % (rx * span[0], ry * span[1], span[0], span[1]))
        else:
            notes.append("reach %.0f%% / %.0f%% of the page from centre (no span "
                         "declared for this width, so it cannot be stated in "
                         "pane voxels)" % (rx * 100.0, ry * 100.0))

    ## 7. Imported — the same check, for the same reason, as every other asset.
    for n in _import_notes(path):
        ok = False
        notes.append(n)

    head = "%-34s %s  %dx%d %s  fracture %.2f%%" % (
        name, "PASS" if ok else "FAIL", w, h, im.mode, coverage)
    return ok, [head] + ["    - " + n for n in notes]


def check_material_fractures(material):
    """The sheet half of `--material`. Separate from family completeness because
    a sheet is not a family: there are no variants to be missing, only the two
    G-D14 widths to be present."""
    man = _fracture_manifest()
    roster = man.get("openings", {})
    if not roster:
        print("  fracture sheets — NO MANIFEST (%s)\n"
              % os.path.relpath(FRACTURE_MANIFEST, REPO_ROOT))
        print("  Run: python3 tools/persistent/gen_fracture_sheet.py --all\n")
        return False
    variants = int(man.get("variants", 1))
    print("  fracture sheets (G-D21 / CRACK-04) — %d openings x %d variants\n"
          % (len(roster), variants))
    all_ok = True
    checked = 0
    failed = []
    for opening in sorted(roster):
        for v in range(variants):
            path = os.path.join(REPO_ROOT, "ASSETS/materials/glass",
                                "fracture_glass_%s_%d.png" % (opening, v))
            if not os.path.exists(path):
                print("  %-24s v%d  ABSENT" % (opening, v))
                all_ok = False
                continue
            ok, lines = check_fracture(path)
            checked += 1
            if not ok:
                all_ok = False
                failed.append((opening, v, lines))
    ## ⚠️ ONLY FAILURES ARE PRINTED IN FULL. 36 passing sheets is six screens of
    ## text nobody reads, and a gate whose output is skipped is not a gate.
    for opening, v, lines in failed:
        print("  %s v%d:" % (opening, v))
        for line in lines:
            print("    " + line)
    print("  %d sheet(s) checked, %d failed\n" % (checked, len(failed)))
    all_ok = _check_fracture_wiring() and all_ok
    return all_ok


def _declared_sheet_spans():
    """GlassCrack.SHEET_SPAN_<WIDTH>, in (run, level) pane voxels, per width.

    Read from the source for the same reason the widths are: the number that
    decides how big a crack looks on the pane is a Director dial in
    `glass_crack.gd`, and a copy of it here would rot the first time he moves it.
    An unreadable file yields {} and the reports degrade to page fractions rather
    than lying in voxels.
    """
    out = {}
    try:
        for line in open(GLASS_CRACK, encoding="utf-8", errors="replace"):
            if not line.startswith("static var SHEET_SPAN_"):
                continue
            name = line.split()[2].split(":")[0]           ## SHEET_SPAN_TIGHT
            width = name[len("SHEET_SPAN_"):].lower()
            body = line[line.index("Vector2(") + len("Vector2("):]
            body = body[:body.index(")")]
            xs, ys = body.split(",")
            out[width] = (float(xs), float(ys))
    except (OSError, ValueError, IndexError):
        return {}
    return out


def _declared_fracture_widths():
    """GlassMaterials.FRACTURE_WIDTHS, or None if it cannot be read.

    Parsed off ONE line for the same reason L2 parses the family roster off one:
    a multi-line literal would silently defeat the parser, so a parse failure is
    reported as a violation rather than skipped.
    """
    try:
        for line in open(GLASS_MATERIALS, encoding="utf-8", errors="replace"):
            if line.startswith("const FRACTURE_WIDTHS"):
                ## Split on "=" first: the TYPE is `Array[String]`, so taking
                ## the first "[" on the line grabs the type parameter and the
                ## roster comes back as ['String] = ["tight', 'wide'].
                body = line.split("=", 1)[-1].strip()
                body = body[body.index("[") + 1:body.rindex("]")]
                return [w.strip().strip('"') for w in body.split(",") if w.strip()]
    except OSError:
        pass
    return None


def _resolver_knows_fracture():
    """Does TextureResolver._validate_dimensions() have a `fracture_` category?

    ⚠️ THE FAILURE THIS CATCHES IS TOTALLY SILENT. The function infers a
    texture's category from the filename prefix and `return false` for anything
    it does not recognise: the file is rejected, the surface falls back to the
    generic atlas, and nothing above a WARN is printed. The same Tier.NONE trap
    once swallowed a full-colour facade_earth.png.
    """
    try:
        return 'begins_with("fracture_")' in open(
            TEXTURE_RESOLVER, encoding="utf-8", errors="replace").read()
    except OSError:
        return None


def _check_fracture_wiring():
    """The sheet half of the two-lists check: files on disk are only half the
    claim, and this is the seam that decides whether they are ever read.

    ⚠️ IT USED TO COMPARE `GlassMaterials.FRACTURE_WIDTHS` AGAINST A COPY HERE.
    CRACK-04 removed the width axis entirely — sheets resolve by (opening,
    variant) through `GlassCrack.sheet_path()`. So the claim that matters now is
    that the manifest covers the FAMILY, and the family's one authority is
    `glass_opening.gd`."""
    man = _fracture_manifest()
    roster = set(man.get("openings", {}).keys())
    src = os.path.join(REPO_ROOT, "godot/scripts/systems/destruction/glass_opening.gd")
    if not os.path.exists(src):
        print("  WIRING FAIL  %s is missing — cannot confirm the manifest covers "
              "the family" % os.path.relpath(src, REPO_ROOT))
        return False
    family = set()
    with open(src) as f:
        in_family = False
        for line in f:
            t = line.strip()
            if t.startswith("const FAMILY"):
                in_family = True
                continue
            if in_family:
                if t.startswith("}"):
                    break
                ## ⚠️ Only a TOP-LEVEL key, i.e. one whose value opens a dict —
                ## and matched with a REGEX, because the table is column-aligned.
                ## Matching any quoted token pulled `"angles"` out of `star_wild`'s
                ## own spec; matching the literal `": {"` then missed the four
                ## members whose padding is `":    {"`. Both failures reported real
                ## openings as missing or foreign, which is the gate lying in the
                ## direction that gets art regenerated for no reason.
                m = re.match(r'^"([A-Za-z0-9_]+)"\s*:\s*\{', t)
                if m:
                    family.add(m.group(1))
    ## ⚠️ NOT EVERY SHEET IS AN OPENING, since G-D28's `armored` (CRACK-05).
    ## A pane that STOPS the round loses no voxel, so its sheet answers to no
    ## polygon and must never be in `GlassOpening.FAMILY` — putting it there
    ## would make it pickable by `pick()` and cuttable by `refresh_glass_rims()`,
    ## on the one pane that may not be cut. It is still REQUIRED: read out of
    ## `glass_crack.gd`, which owns the selection, rather than copied here.
    classless = _classless_sheets()
    if classless is None:
        print("  WIRING FAIL  glass_crack.gd is missing — cannot confirm which "
              "sheets are not openings")
        return False
    ok = True
    missing = sorted((family | classless) - roster)
    extra = sorted(roster - family - classless)
    if missing:
        ok = False
        print("  WIRING FAIL  the manifest has no sheets for %s — run "
              "tools/persistent/gen_fracture_sheet.py --all" % ", ".join(missing))
    if extra:
        ok = False
        print("  WIRING FAIL  the manifest carries %s, which the family no longer "
              "defines. Regenerate, or the art describes a hole nothing cuts"
              % ", ".join(extra))
    if ok:
        print("  wiring ok — the manifest covers all %d openings the family defines, "
              "plus %d sheet(s) that are not openings (%s)"
              % (len(family), len(classless), ", ".join(sorted(classless)) or "none"))
    return ok


def _tile_sheets():
    """The sheet ids that are TILED fields rather than pages centred on an impact.

    Read off `GlassCrack.CRAZE_SHEET_*` for the same reason `_classless_sheets()`
    reads the armoured pair: the runtime owns which class is which, and a copy
    here would keep testing the old answer after it moved. Returns None when the
    file is unreadable, which the callers treat as "no tile classes"."""
    src = os.path.join(REPO_ROOT, "godot/scripts/systems/destruction/glass_crack.gd")
    try:
        text = open(src, encoding="utf-8", errors="replace").read()
    except OSError:
        return None
    ## The roster is two ARRAYS since the Director's six (2026-09-05), so the ids
    ## are pulled out of the bracket rather than off one constant each — still a
    ## parse of the owner, which is the point: a tuple here is how a gate starts
    ## testing a roster the runtime has moved on from.
    out = set()
    for m in re.finditer(r'^const\s+CRAZE_BUCKET_[A-Z]+\s*:\s*Array\[String\]\s*=\s*\[([^\]]*)\]',
                         text, re.M):
        out.update(re.findall(r'"([A-Za-z0-9_]+)"', m.group(1)))
    return out


def _wrap_ratios(im):
    """(columns, rows) — how the page's wrap seam compares to the SAME edge's own
    inward neighbour. 1.0 means indistinguishable, i.e. the page tiles.

    ⚠️ THE NORMALISER IS `col0 vs col1`, NOT THE PAGE'S MEAN ADJACENT PAIR, AND THE
    FIRST VERSION WAS THE SECOND. Both terms then involve col0, so its INK LEVEL
    cancels — which is the whole problem with a page mean: a wrap column that
    happens to lie along a crack has a large difference against anything, while
    the page average is dominated by the black between cracks, so the ratio
    measured "is this column on ink" as much as "does it wrap". Measured over the
    18 shipped craze sheets: the old normaliser put the worst PASSING sheet at
    **1.94** against a 2.0 threshold — a margin that a reseed would have crossed,
    failing correct art. The same 18 score **1.35** at worst under this one, and
    the non-wrapping control moves the other way, 3.15 -> **7.26**. Same threshold,
    a factor of 5.4 of separation instead of 1.6.

    Pure PIL and integers on purpose: this file is a gate, and a gate that needs
    numpy is a gate that stops running the day an environment lacks it."""
    try:
        g = im.convert("L")
    except Exception:
        return None
    w, h = g.size
    if w < 2 or h < 2:
        return None
    px = g.tobytes()

    def row(y):
        return px[y * w:(y + 1) * w]

    seam_c = 0
    inner_c = 0
    for y in range(h):
        r = row(y)
        seam_c += abs(r[0] - r[w - 1])       ## the wrap pair
        inner_c += abs(r[0] - r[1])          ## the same column's own neighbour
    seam_c /= float(h)
    inner_c /= float(h)

    top, second, bot = row(0), row(1), row(h - 1)
    seam_r = sum(abs(top[x] - bot[x]) for x in range(w)) / float(w)
    inner_r = sum(abs(top[x] - second[x]) for x in range(w)) / float(w)

    ## A perfectly flat page has no adjacent variation to compare against; the
    ## coverage checks above have already rejected it, so 1.0 is the honest answer
    ## rather than a division by zero.
    return (seam_c / inner_c if inner_c > 0.0 else 1.0,
            seam_r / inner_r if inner_r > 0.0 else 1.0)


def _floor_family_consumer(material):
    """Does anything actually load this material's FLOOR decal files?

    ⚠️ A PATH GREP, AND THE PATH IS THE CONTRACT. `IMPACT_DECAL_MATERIALS` only
    reaches the wall families, so a floor-only family is loaded by whoever wants
    it — for glass that is `VoxelRenderer._floor_shard_texture()`. Asking whether
    the LITERAL path appears in the renderer is the same discipline the rest of
    this file follows: read the owner, never keep a second copy of the answer.
    """
    src = os.path.join(REPO_ROOT, "godot/scripts/geometry/voxel_renderer.gd")
    try:
        text = open(src, encoding="utf-8", errors="replace").read()
    except OSError:
        return False
    for family in families_for(material):
        if "decal_%s_%s_" % (family, material) in text:
            return True
    return False


def _classless_sheets():
    """The sheet ids that are NOT members of the opening family, read off
    `glass_crack.gd`'s own constants. Returns None when the file is unreadable.

    Kept as a parse of the owner rather than a tuple here for the same reason
    the family is: two copies of a roster is how a gate starts passing for art
    the engine no longer asks for."""
    src = os.path.join(REPO_ROOT, "godot/scripts/systems/destruction/glass_crack.gd")
    try:
        text = open(src, encoding="utf-8", errors="replace").read()
    except OSError:
        return None
    out = set()
    ## ⚠️ TWO CLASSES NOW, AND BOTH ARE READ RATHER THAN LISTED. `ARMORED_SHEET_*`
    ## (G-D28) and `CRAZE_SHEET_*` (G-D35 B-3) are both sheet ids that answer to no
    ## opening polygon — the armoured pane loses no voxel, and a blast craze's
    ## perforation is chosen per voxel at runtime (B-4) rather than drawn into the
    ## art. A hard-coded tuple here is how a gate starts passing for art the
    ## engine no longer asks for.
    for m in re.finditer(r'^const\s+ARMORED_SHEET_[A-Z]+\s*:\s*String\s*=\s*"([A-Za-z0-9_]+)"',
                         text, re.M):
        out.add(m.group(1))
    ## The craze roster lives in the bucket arrays; `_tile_sheets()` owns that
    ## parse, and every one of them is a non-opening sheet too.
    out |= (_tile_sheets() or set())
    return out

def check_material(material):
    """7. Family completeness — the check a per-file pass cannot make."""
    print("[DECAL] material %r — family completeness\n" % material)
    all_ok = True
    found_any = False
    for family in families_for(material):
        paths = [os.path.join(decal_dir(material), "decal_%s_%s_%d.png" % (family, material, i))
                 for i in range(VARIANT_COUNT)]
        present = [p for p in paths if os.path.exists(p)]
        if not present:
            ## Two different absences, and conflating them was wrong the moment
            ## families became per-material: `crack` missing from metal is the
            ## RULE (D32.6 — metal does not fracture), while `shard` missing from
            ## glass is UNDELIVERED ART. Only the second one is a to-do.
            if material in MATERIAL_FAMILIES:
                print("  %-8s —  absent — %r claims this family (G-ART); art not "
                      "delivered yet" % (family, material))
            else:
                print("  %-8s —  absent (this material does not claim the family)" % family)
            continue
        found_any = True
        if len(present) != VARIANT_COUNT:
            all_ok = False
            missing = [os.path.basename(p) for p in paths if p not in present]
            print("  %-8s FAIL  %d of %d variants — missing %s"
                  % (family, len(present), VARIANT_COUNT, ", ".join(missing)))
            print("           the runtime hashes a voxel's coordinates into 0..%d and "
                  "loads whichever it lands on; a gap is a boot-time B6 error, not a "
                  "fallback." % (VARIANT_COUNT - 1))
        else:
            print("  %-8s ok    %d/%d variants" % (family, VARIANT_COUNT, VARIANT_COUNT))
        for p in paths:
            if not os.path.exists(p):
                continue
            ok, lines = check(p)
            all_ok = all_ok and ok
            for line in lines:
                print("    " + line)
        print("")

    ## The sheet class, for the materials that claim one.
    if material in FRACTURE_MATERIALS:
        all_ok = check_material_fractures(material) and all_ok

    ## The two-lists check — the silent miss this whole gate is named after.
    wired = _wired_materials()
    if wired is None:
        print("  ⚠ could not read IMPACT_DECAL_MATERIALS from %s — the wiring half of"
              % os.path.relpath(RENDERER, REPO_ROOT))
        print("    this check did not run. Fix the parser rather than trusting a PASS.")
    elif material in wired:
        if not found_any:
            all_ok = False
            print("  WIRING FAIL  %r is in IMPACT_DECAL_MATERIALS with NO files on disk."
                  % material)
            print("               That renders wrong without erroring: the runtime asks")
            print("               for decal_<family>_%s_<n>.png and gets nothing." % material)
        else:
            where = "IMPACT_DECAL_MATERIALS"
            if material == _floor_material():
                where = "IMPACT_FLOOR_MATERIAL (the shared floor-dent family, D26)"
            print("  wiring  ok    %r is wired through %s" % (material, where))
    else:
        if found_any:
            ## ⚠️ NOT `all_ok = False` HERE ANY MORE — that line predated the third
            ## state below and made "correctly absent" impossible to express: the
            ## verdict was already a failure before the branches decided which of
            ## the three cases this is. Each branch now fails for itself.
            ## ⚠️ THE REMEDY IS NOT THE SAME FOR EVERY MATERIAL, and printing the
            ## wrong one is worse than printing none. `_decal_material()` composes
            ## a name from the DAMAGE STATE, so IMPACT_DECAL_MATERIALS only ever
            ## reaches the WALL families (bullet/crack/dent). A material whose
            ## only family is a FLOOR one — glass's `shard`, G-D16b — is not
            ## reachable from that list at all, and adding its id there would ask
            ## the renderer for `<id>_bullet_cracked_*`, exactly the art G-D21
            ## folded into the fracture sheet and says must never exist.
            wall_families = [f for f in families_for(material) if f in FAMILIES]
            if wall_families:
                all_ok = False
                print("  WIRING FAIL  the files exist but %r is NOT in IMPACT_DECAL_MATERIALS,"
                      % material)
                print("               so nothing will ever load them — the material still")
                print("               falls back to the generic family. Add the id.")
            elif _floor_family_consumer(material):
                ## ✅ THE THIRD STATE THIS GATE DID NOT HAVE, and it stood as a
                ## standing WIRING FAIL from CRACK-05 (2026-09-04) until G6 was
                ## built (2026-09-05). A material can be CORRECTLY ABSENT from
                ## IMPACT_DECAL_MATERIALS and still be loaded — glass's `shard` is
                ## a FLOOR mark, which that list cannot reach by construction, and
                ## `VoxelRenderer._floor_shard_texture()` is what asks the disk for
                ## it. "Absent from the list" and "nothing loads it" were being
                ## reported as one thing; they are two, and the gate now checks the
                ## one that matters — that SOMETHING loads the files.
                print("  wiring  ok    %r's floor family is loaded directly by the"
                      % material)
                print("                renderer (G6), which is why it is correctly")
                print("                absent from IMPACT_DECAL_MATERIALS")
            else:
                all_ok = False
                print("  WIRING FAIL  the files exist and nothing loads them — but DO NOT")
                print("               add %r to IMPACT_DECAL_MATERIALS. Its only family"
                      % material)
                print("               (%s) is a FLOOR mark, and that list reaches the wall"
                      % "/".join(families_for(material)))
                print("               families only: the id there would compose")
                print("               %s_bullet_cracked_*, the art G-D21 folded into the"
                      % material)
                print("               fracture sheet. The real consumer is G6/GlassFall,")
                print("               unbuilt (glass_fall.gd names the shape and stops).")
        else:
            print("  wiring  ok    %r is not wired and has no files — it takes its marks"
                  % material)
            print("                through the material-agnostic GENERIC family, which is")
            print("                a real mark, not an absence.")
    return all_ok



def _usage_text():
    """The `## Usage:` block from this file's own header.

    These tools document themselves in a `##` comment block, not a docstring, so
    `__doc__` is None and the original `__doc__.strip()` raised AttributeError on
    the one path it existed for — running the tool with no arguments, which is
    exactly what someone reaching for the usage does. Read the header back off
    disk instead of duplicating it here, so the text stays single-sourced.
    """
    try:
        with open(__file__, encoding="utf-8") as fh:
            header = []
            for line in fh:
                if line.startswith("#"):
                    header.append(line.rstrip("\n"))
                elif header:
                    break
        text = "\n".join(header)
        if "## Usage:" in text:
            body = text.split("## Usage:")[1]
            return "Usage:\n" + "\n".join(
                l.lstrip("#").rstrip() for l in body.splitlines() if l.strip("# ").strip()
            )
    except OSError:
        pass
    return "Usage: python3 %s <file.png> [<file.png> ...] | --all" % __file__


def main():
    args = sys.argv[1:]
    if not args:
        print(_usage_text())
        return 2

    if args[0] == "--material":
        if len(args) != 2:
            print("[DECAL] --material takes exactly one material id")
            return 2
        ok = check_material(args[1])
        print("[DECAL] material %r: %s" % (args[1], "PASS" if ok else "FAILURES above"))
        return 0 if ok else 1

    if args == ["--all"]:
        paths = []
        for material in sorted(os.listdir(MATERIALS_ROOT)) if os.path.isdir(MATERIALS_ROOT) else []:
            ## Sheets sit BESIDE the facade, in the material folder itself —
            ## TextureResolver has no subdirectory step (see fracture_path).
            mdir = os.path.join(MATERIALS_ROOT, material)
            if os.path.isdir(mdir):
                paths.extend(sorted(
                    os.path.join(mdir, f) for f in os.listdir(mdir)
                    if f.startswith("fracture_") and f.endswith(".png")
                ))
            ddir = decal_dir(material)
            if not os.path.isdir(ddir):
                continue
            paths.extend(sorted(
                os.path.join(ddir, f) for f in os.listdir(ddir)
                if f.startswith("decal_") and f.endswith(".png")
            ))
        if not paths:
            print("[DECAL] no decal_*.png or fracture_*.png found under %s" % MATERIALS_ROOT)
            return 1
    else:
        paths = args

    all_ok = True
    for p in paths:
        ## One entry point, two asset classes: they fail differently and the
        ## filename is what says which set of rules applies.
        checker = check_fracture if os.path.basename(p).startswith("fracture_") else check
        ok, lines = checker(p)
        all_ok = all_ok and ok
        for line in lines:
            print(line)

    print("")
    print("[DECAL] %d file(s), %s" % (len(paths), "all PASS" if all_ok else "FAILURES above"))
    return 0 if all_ok else 1


if __name__ == "__main__":
    sys.exit(main())
