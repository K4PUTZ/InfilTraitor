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
##   1. filename        — decal_<family>_<material>_<n>.png, family in
##                        bullet/dent/crack, n in 0..2
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
## Usage:
##     python3 tools/persistent/check_decal.py <file.png> [<file.png> ...]
##     python3 tools/persistent/check_decal.py --material brick
##     python3 tools/persistent/check_decal.py --all
##
## Exit code is 0 only if every file PASSes, so it can gate a delivery.

import os
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

## §7, pinned: 256x256 is 16x the canonical TEX_AUTHORING_N density, and square
## because a voxel face is square in flat space. The x20/16 vertical stretch
## onto a lateral face belongs to the generator, never to the art.
DECAL_W = 256
DECAL_H = 256

## voxels/manifest.json's own `variant_count`, and the range the runtime hashes
## into. Not a convention — a missing variant is a boot-time B6 failure.
VARIANT_COUNT = 3
FAMILIES = ("bullet", "dent", "crack")

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
        family, _material, index = parsed
        if family not in FAMILIES and not name.startswith("decal_generic_"):
            ok = False
            notes.append("family %r is not one of %s" % (family, "/".join(FAMILIES)))
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


def check_material(material):
    """7. Family completeness — the check a per-file pass cannot make."""
    print("[DECAL] material %r — family completeness\n" % material)
    all_ok = True
    found_any = False
    for family in FAMILIES:
        paths = [os.path.join(decal_dir(material), "decal_%s_%s_%d.png" % (family, material, i))
                 for i in range(VARIANT_COUNT)]
        present = [p for p in paths if os.path.exists(p)]
        if not present:
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
            all_ok = False
            print("  WIRING FAIL  the files exist but %r is NOT in IMPACT_DECAL_MATERIALS,"
                  % material)
            print("               so nothing will ever load them — the material still")
            print("               falls back to the generic family. Add the id.")
        else:
            print("  wiring  ok    %r is not wired and has no files — it takes its marks"
                  % material)
            print("                through the material-agnostic GENERIC family, which is")
            print("                a real mark, not an absence.")
    return all_ok


def main():
    args = sys.argv[1:]
    if not args:
        print(__doc__.strip().split("## Usage:")[1].strip())
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
            ddir = decal_dir(material)
            if not os.path.isdir(ddir):
                continue
            paths.extend(sorted(
                os.path.join(ddir, f) for f in os.listdir(ddir)
                if f.startswith("decal_") and f.endswith(".png")
            ))
        if not paths:
            print("[DECAL] no decal_*.png found under %s" % MATERIALS_ROOT)
            return 1
    else:
        paths = args

    all_ok = True
    for p in paths:
        ok, lines = check(p)
        all_ok = all_ok and ok
        for line in lines:
            print(line)

    print("")
    print("[DECAL] %d file(s), %s" % (len(paths), "all PASS" if all_ok else "FAILURES above"))
    return 0 if all_ok else 1


if __name__ == "__main__":
    sys.exit(main())
