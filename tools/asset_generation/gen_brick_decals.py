#!/usr/bin/env python3
##
## gen_brick_decals.py — R3D-LOOK L1: the nine brick damage decals, redrawn LIGHTER than the wall.
##
## WHY. Measured 2026-10-05: brick is the darkest wall (mean luminance 0.21) and its shipped decals were dark and translucent
## (bullet luminance 0.16-0.21 at alpha ~0.35, crack ~0.00 at alpha ~0.4), so the mark changed the face by 3-10 % and
## vanished in the facade's mortar lines. Concrete's decals read (10-13 %) because they are LIGHT and cover half the voxel. Brick damage in
## the world is light too: the struck brick shows its pale pink-orange core and a halo of pulverised dust, with a dark hole.
##
## WHAT IT WRITES (ART_SPECIFICATIONS §7: 256x256 RGBA, 3 variants per family, flat and unprojected):
##   decal_bullet_brick_{0,1,2}  a puncture: dark hole, pale chipped crater, dust halo        (~35-55 % coverage)
##   decal_crack_brick_{0,1,2}   fracture running along the courses and the joints, pale edge (~15-25 %)
##   decal_dent_brick_{0,1,2}    a spall scar: pale pulverised patch with dark pits           (~55-75 %)
##
## Deterministic (seeded per file): re-running writes the same bytes. Back the old art up first; this OVERWRITES.
## Usage:  python3 tools/asset_generation/gen_brick_decals.py [--out DIR]
## Then:   python3 tools/persistent/check_decal.py --material brick   and reimport the project.

import argparse
import math
import random
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "ASSETS/materials/brick/decals"
N = 256
SS = 2  ## supersample for the line work

CORE = np.array([214.0, 150.0, 122.0])   ## the struck brick's exposed core
DUST = np.array([206.0, 192.0, 178.0])   ## pulverised mortar / brick dust
DARK = np.array([22.0, 11.0, 9.0])       ## the hole and the pits
RIM = np.array([70.0, 30.0, 22.0])       ## the shaded lip of the hole
TINT = np.ones(3)                        ## a multiplier applied after the desaturation (stone: a cool grey)
DESAT = 0.0                              ## 0..1: how much of the photo's colour is taken out (stone: Rock063 is covered in moss)
SEED_OFFSET = 0                          ## so two materials never share a pattern
CRACK_PALETTE = None                     ## None: the brick (dark-wall) look; a dict: the light-wall look of gen_crack_decals

## Per-material configuration (the module globals above and PHOTO_FILL below are set from it by `use()`).
CONFIGS = {
    "brick": {},
    "concrete": {
        "dark": (18, 18, 20), "rim": (52, 52, 54), "core": (176, 174, 168), "dust": (206, 205, 200), "seed": 100, "desat": 0.0, "tint": (1.0, 1.0, 1.0),
        "photo": {
            "bullet": [("concrete/Concrete036/Concrete036_2K-JPG_Color.jpg", 0.74), ("concrete/Concrete044D/Concrete044D_2K-JPG_Color.jpg", 0.62)],
            "dent": [("concrete/Concrete036/Concrete036_2K-JPG_Color.jpg", 0.70), ("shared/Plaster007/Plaster007_2K-JPG_Color.jpg", 0.76)],
            "crack": [("concrete/Concrete036/Concrete036_2K-JPG_Color.jpg", 0.74)],
        },
        "crack_palette": {"dark": (26, 26, 28), "lip": (228, 228, 224), "haze": (84, 84, 86)},
    },
    "metal": {
        "dark": (14, 15, 18), "rim": (40, 42, 48), "core": (176, 182, 190), "dust": (214, 218, 224), "seed": 300, "desat": 0.0, "tint": (1.0, 1.0, 1.0),
        "photo": {
            "bullet": [("metal/Metal053C/Metal053C_2K-JPG_Color.jpg", 0.66)],
            "dent": [("metal/Metal053C/Metal053C_2K-JPG_Color.jpg", 0.60)],
            "crack": [("metal/Metal053C/Metal053C_2K-JPG_Color.jpg", 0.60)],
        },
        "crack_palette": {"dark": (20, 21, 24), "lip": (220, 224, 230), "haze": (70, 74, 82)},
    },
    "stone": {
        "dark": (16, 17, 22), "rim": (48, 50, 58), "core": (168, 170, 178), "dust": (204, 206, 212), "seed": 200, "desat": 1.0, "tint": (0.96, 0.98, 1.04),
        "photo": {
            "bullet": [("stone/Rock063/Rock063_2K-JPG_Color.jpg", 0.72)],
            "dent": [("stone/Rock063/Rock063_2K-JPG_Color.jpg", 0.68), ("concrete/Concrete036/Concrete036_2K-JPG_Color.jpg", 0.74)],
            "crack": [("concrete/Concrete036/Concrete036_2K-JPG_Color.jpg", 0.74)],
        },
        "crack_palette": {"dark": (22, 23, 28), "lip": (222, 224, 230), "haze": (78, 80, 88)},
    },
}


def use(material: str) -> None:
    """Point the module at one material's configuration (brick keeps the module defaults)."""
    global CORE, DUST, DARK, RIM, TINT, DESAT, SEED_OFFSET, PHOTO_FILL, CRACK_PALETTE
    cfg = CONFIGS[material]
    if not cfg:
        return
    CORE, DUST, DARK, RIM = (np.array(cfg[k], dtype=float) for k in ("core", "dust", "dark", "rim"))
    DESAT, SEED_OFFSET, TINT = float(cfg["desat"]), int(cfg["seed"]), np.array(cfg["tint"], dtype=float)
    PHOTO_FILL = cfg["photo"]
    CRACK_PALETTE = cfg["crack_palette"]


def fbm(rng: np.random.Generator, size: int, octaves: int = 5, base: int = 4) -> np.ndarray:
    """Value-noise fbm in [0, 1], (size, size)."""
    out = np.zeros((size, size))
    amp, total = 1.0, 0.0
    for o in range(octaves):
        cells = base * (2 ** o)
        grid = rng.random((cells + 1, cells + 1))
        img = Image.fromarray((grid * 255).astype(np.uint8)).resize((size, size), Image.BICUBIC)
        out += amp * np.asarray(img, dtype=float) / 255.0
        total += amp
        amp *= 0.5
    out /= total
    return (out - out.min()) / max(out.max() - out.min(), 1e-9)


def radial_blob(rng: np.random.Generator, radius: float, stretch: tuple[float, float], rough: float, angle: float) -> np.ndarray:
    """A signed field > 0 inside an irregular blob centred on the canvas (units: fraction of the canvas)."""
    ys, xs = np.mgrid[0:N, 0:N]
    x = (xs - N / 2.0) / N
    y = (ys - N / 2.0) / N
    ca, sa = math.cos(angle), math.sin(angle)
    u = (x * ca + y * sa) / stretch[0]
    v = (-x * sa + y * ca) / stretch[1]
    dist = np.sqrt(u * u + v * v)
    wobble = (fbm(rng, N, 5, 3) - 0.5) * 2.0 * rough
    return radius * (1.0 + wobble) - dist


def feather(field: np.ndarray, width: float) -> np.ndarray:
    """Field (> 0 inside) -> alpha 0..1 with a soft edge `width` (canvas fraction) wide."""
    return np.clip(field / width + 0.5, 0.0, 1.0)


def shade(rng: np.random.Generator, mix_noise: np.ndarray, grain: float) -> np.ndarray:
    """Pale brick-core / dust colour field (N, N, 3)."""
    t = mix_noise[..., None]
    col = CORE * (1.0 - t) + DUST * t
    g = (rng.random((N, N)) - 0.5) * grain
    return np.clip(col + g[..., None], 0, 255)


PHOTO_ROOT = ROOT / "ASSETS/photo_src"
## The photographic fill of each brick mark (CC0 ambientCG, see docs/PHOTO_SOURCES.md): the mark's COLOUR and TEXTURE come from a crop of
## one of these photos; its SHAPE and alpha stay procedural. (relative path, target mean luminance 0..1 the crop is graded to: the
## decal must be LIGHTER than the wall, 0.21 mean, or it vanishes; see the header.)
PHOTO_FILL = {
    ## Ground111 (brick rubble and dust) for both: a crop of an INTACT brick wall (Bricks097) tried first read as a sticker of a wall
    ## inside the hole; a damaged brick shows its core and its dust, not its courses.
    "bullet": [("brick/Ground111/Ground111_2K-JPG_Color.jpg", 0.62)],
    "dent": [("brick/Ground111/Ground111_2K-JPG_Color.jpg", 0.58)],
    "crack": [("shared/Plaster007/Plaster007_2K-JPG_Color.jpg", 0.66)],
}
_PHOTOS: dict[str, Image.Image] = {}


def photo_fill(rng: np.random.Generator, kind: str, variant_seed: int) -> np.ndarray | None:
    """(N, N, 3) 0..255 from a crop of a photo of `kind`, graded to its target luminance; None when the photo is not on disk."""
    sources = PHOTO_FILL[kind]
    rel, target = sources[variant_seed % len(sources)]
    path = PHOTO_ROOT / rel
    if not path.exists():
        print("  (no photo %s: procedural fill)" % rel)
        return None
    if rel not in _PHOTOS:
        _PHOTOS[rel] = Image.open(path).convert("RGB")
    im = _PHOTOS[rel]
    side = int(rng.integers(420, 760))  ## the crop is ~2-3x the decal's size: a downsample keeps the grain crisp
    x0 = int(rng.integers(0, im.width - side))
    y0 = int(rng.integers(0, im.height - side))
    crop = np.asarray(im.crop((x0, y0, x0 + side, y0 + side)).resize((N, N), Image.LANCZOS), dtype=float)
    grey = (crop @ np.array([0.2126, 0.7152, 0.0722]))[..., None]
    crop = (crop * (1.0 - DESAT) + grey * DESAT) * TINT
    lum = grey[..., 0] / 255.0
    gain = target / max(float(lum.mean()), 1e-3)
    crop = np.clip((crop - crop.mean()) * 1.15 + crop.mean(), 0, 255) * gain  ## a touch more contrast, then to the target
    return np.clip(crop, 0, 255)


def edge_report(name: str, alpha: np.ndarray) -> None:
    """The alpha calibration: the mark must stay clear of the canvas border (a neighbour voxel is not damaged) and fade out softly."""
    border = np.concatenate([alpha[:2].ravel(), alpha[-2:].ravel(), alpha[:, :2].ravel(), alpha[:, -2:].ravel()])
    gy, gx = np.gradient(alpha)
    grad = np.hypot(gx, gy)
    soft = (alpha > 0.02) & (alpha < 0.9)
    print("  alpha: border max %.3f (must be < 0.012), steepest soft edge %.3f /px, soft-edge px %d"
          % (border.max(), grad[soft].max() if soft.any() else 0.0, int(soft.sum())))
    assert border.max() < 0.012, "%s touches the canvas border" % name


EDGE_FADE = 0.10  ## canvas fraction over which every mark fades to nothing at the border


def edge_window() -> np.ndarray:
    """1 inside, a smoothstep down to 0 at the canvas border: a mark never reaches the voxel's edge (its neighbour is not damaged)."""
    c = (np.arange(N) + 0.5) / N
    d = np.minimum(c, 1.0 - c)
    t = np.clip(d / EDGE_FADE, 0.0, 1.0)
    w = t * t * (3.0 - 2.0 * t)
    return np.minimum.outer(w, w)


def compose(rgb: np.ndarray, alpha: np.ndarray) -> Image.Image:
    alpha = np.clip(alpha, 0, 1) * edge_window()
    out = np.dstack([np.clip(rgb, 0, 255), alpha * 255.0]).astype(np.uint8)
    return Image.fromarray(out, "RGBA")


def bullet(seed: int, radius: float, stretch: tuple[float, float], angle: float) -> Image.Image:
    seed += SEED_OFFSET
    rng = np.random.default_rng(seed)
    crater = radial_blob(rng, radius, stretch, 0.35, angle)
    halo = radial_blob(rng, radius * 1.22, stretch, 0.45, angle)
    body = fbm(rng, N, 5, 5)
    rgb = photo_fill(rng, "bullet", seed)
    if rgb is None:
        rgb = shade(rng, body, 26.0)
    ## Hole: dark, ragged, off-centre a little; a shaded rim fakes depth.
    hole = radial_blob(rng, radius * 0.38, (1.0, 0.9), 0.4, angle)
    rim = radial_blob(rng, radius * 0.55, (1.0, 0.9), 0.4, angle)
    rim_a = feather(rim, 0.03) * (1.0 - feather(hole, 0.012))
    rgb = rgb * (1.0 - rim_a[..., None] * 0.7) + RIM * rim_a[..., None] * 0.7
    hole_a = feather(hole, 0.012)
    rgb = rgb * (1.0 - hole_a[..., None]) + DARK * hole_a[..., None]
    ## Chipped facets: a few darker radial fracture lines out of the hole.
    img = Image.new("L", (N * SS, N * SS), 0)
    d = ImageDraw.Draw(img)
    r = random.Random(seed)
    for _ in range(r.randint(4, 6)):
        a = r.uniform(0, math.tau)
        length = radius * r.uniform(0.9, 1.5) * N * SS
        x, y = N * SS / 2.0, N * SS / 2.0
        pts = [(x, y)]
        for _s in range(4):
            a += r.uniform(-0.35, 0.35)
            x += math.cos(a) * length / 4.0
            y += math.sin(a) * length / 4.0
            pts.append((x, y))
        d.line(pts, fill=255, width=SS * 2)
    lines = np.asarray(img.resize((N, N), Image.LANCZOS), dtype=float) / 255.0
    rgb = rgb * (1.0 - lines[..., None] * 0.7) + DARK * lines[..., None] * 0.7
    alpha = np.maximum(feather(crater, 0.05) * 0.92, feather(halo, 0.10) * 0.38)
    alpha = np.maximum(alpha, hole_a)
    return compose(rgb, alpha)


def crack(seed: int, branches: int, spread: float, palette: dict | None = None) -> Image.Image:
    palette = palette if palette is not None else CRACK_PALETTE
    """Fracture lines: they favour the courses (near-horizontal runs) and the joints (near-vertical), but wander in between,
    taper towards their tips and stay inside the canvas (a mark never reaches its voxel's border: neighbours are not cracked)."""
    seed += SEED_OFFSET
    rng = np.random.default_rng(seed)
    r = random.Random(seed)
    course = N * SS / 8.0
    lines = Image.new("L", (N * SS, N * SS), 0)
    d = ImageDraw.Draw(lines)
    lo, hi = N * SS * 0.10, N * SS * 0.90

    def snap(heading: float) -> float:
        ## Pull a heading toward the nearest course / joint direction, never fully.
        best = min((0.0, math.pi / 2, math.pi, -math.pi / 2), key=lambda a: abs(math.atan2(math.sin(heading - a), math.cos(heading - a))))
        diff = math.atan2(math.sin(best - heading), math.cos(best - heading))
        return heading + diff * 0.45

    def walk(x: float, y: float, heading: float, steps: int, width: float, depth: int) -> None:
        for _i in range(steps):
            heading = snap(heading + r.uniform(-0.55, 0.55))
            step = course * r.uniform(0.5, 1.1)
            nx, ny = x + math.cos(heading) * step, y + math.sin(heading) * step
            if not (lo < nx < hi and lo < ny < hi):
                break
            w = max(1.0, width * (1.0 - _i / max(steps, 1)) ** 0.7)
            d.line([(x, y), (nx, ny)], fill=255, width=int(round(w * SS)))
            x, y = nx, ny
            if depth < 2 and r.random() < 0.2:
                walk(x, y, heading + r.choice((-1, 1)) * r.uniform(0.5, 1.1), r.randint(2, 5), width * 0.6, depth + 1)

    cx, cy = N * SS / 2.0 + r.uniform(-14, 14) * SS, N * SS / 2.0 + r.uniform(-14, 14) * SS
    for k in range(branches):
        walk(cx, cy, k * math.tau / branches + r.uniform(-0.4, 0.4), r.randint(5, 9), r.uniform(4.5, 6.0), 0)
    mask = np.asarray(lines.resize((N, N), Image.LANCZOS), dtype=float) / 255.0
    core = np.clip(mask * 1.4, 0, 1)
    ## A pale lip along the crack (spalled edge) and a dust haze around it: what makes it read on a dark wall.
    m8 = Image.fromarray((mask * 255).astype(np.uint8))
    haze = np.asarray(m8.filter(ImageFilter.GaussianBlur(8)), dtype=float) / 255.0
    lip = np.asarray(m8.filter(ImageFilter.MaxFilter(7)).filter(ImageFilter.GaussianBlur(1.0)), dtype=float) / 255.0
    lip = np.clip(lip - mask * 0.9, 0, 1)
    if palette is None:
        rgb = photo_fill(rng, "crack", seed)
        if rgb is None:
            rgb = shade(rng, fbm(rng, N, 4, 6), 24.0)
        rgb = rgb * (1.0 - core[..., None]) + DARK * core[..., None]
        alpha = np.maximum.reduce([core * 0.97, lip * 0.9, np.clip(haze * 1.8, 0, 1) * spread])
        return compose(rgb, alpha)
    ## A light wall (concrete, stone): the line is dark, its chipped lip catches the light, and the haze is a SHADOW, not dust.
    dark, lip_col, haze_col = (np.array(palette[k], dtype=float) for k in ("dark", "lip", "haze"))
    grain = (rng.random((N, N)) - 0.5) * 18.0
    rgb = np.zeros((N, N, 3)) + haze_col + grain[..., None]
    lip_w = (lip / np.maximum(lip + haze, 1e-6))[..., None]
    rgb = rgb * (1.0 - lip_w) + lip_col * lip_w
    rgb = rgb * (1.0 - core[..., None]) + dark * core[..., None]
    alpha = np.maximum.reduce([core * 0.97, lip * 0.9, np.clip(haze * 1.8, 0, 1) * spread])
    return compose(rgb, alpha)


def dent(seed: int, radius: float, stretch: tuple[float, float], angle: float) -> Image.Image:
    """A spall scar on a cut plane: broad, pale, pulverised, with dark pits."""
    seed += SEED_OFFSET
    rng = np.random.default_rng(seed)
    scar = radial_blob(rng, radius, stretch, 0.22, angle)
    body = fbm(rng, N, 6, 4)
    rgb = photo_fill(rng, "dent", seed)
    if rgb is None:
        rgb = shade(rng, np.clip(body * 1.2, 0, 1), 34.0)
    pits_field = fbm(rng, N, 5, 7)
    pits = np.clip((pits_field - 0.66) / 0.06, 0, 1) * feather(scar, 0.08)
    rgb = rgb * (1.0 - pits[..., None] * 0.8) + DARK * pits[..., None] * 0.8
    ## A darker, thinner rim under the lower edge reads as the lip of the depression.
    inner = radial_blob(rng, radius * 0.82, stretch, 0.30, angle)
    lipband = np.clip(feather(scar, 0.05) - feather(inner, 0.10), 0, 1)
    rgb = rgb * (1.0 - lipband[..., None] * 0.35)
    alpha = feather(scar, 0.09) * (0.72 + 0.12 * body)
    return compose(rgb, np.clip(alpha, 0, 1))


SPECS = {
    "bullet": [
        lambda: bullet(11, 0.21, (1.0, 0.85), 0.3),
        lambda: bullet(12, 0.24, (1.15, 0.85), -0.4),
        lambda: bullet(13, 0.27, (1.0, 0.95), 1.1),
    ],
    "crack": [
        lambda: crack(21, 5, 0.40),
        lambda: crack(22, 4, 0.45),
        lambda: crack(23, 6, 0.38),
    ],
    "dent": [
        lambda: dent(31, 0.27, (1.2, 0.8), 0.5),
        lambda: dent(32, 0.30, (1.0, 0.9), -0.6),
        lambda: dent(33, 0.28, (1.3, 0.75), 1.2),
    ],
}


def main() -> int:
    parser = argparse.ArgumentParser(description="R3D-LOOK L1: write the nine brick damage decals (see the header)")
    parser.add_argument("--material", default="brick", choices=sorted(CONFIGS))
    parser.add_argument("--out", default=None)
    args = parser.parse_args()
    use(args.material)
    out = Path(args.out) if args.out else ROOT / "ASSETS/materials" / args.material / "decals"
    out.mkdir(parents=True, exist_ok=True)
    for family, makers in SPECS.items():
        for variant, make in enumerate(makers):
            img = make()
            a = np.asarray(img)[..., 3]
            path = out / ("decal_%s_%s_%d.png" % (family, args.material, variant))
            img.save(path, "PNG")
            print("%s  coverage %.0f %%  peak alpha %d" % (path.name, float((a > 13).mean()) * 100.0, int(a.max())))
            edge_report(path.name, a.astype(float) / 255.0)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
