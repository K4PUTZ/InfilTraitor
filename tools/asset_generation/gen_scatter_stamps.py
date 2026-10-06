#!/usr/bin/env python3
##
## gen_scatter_stamps.py — the CLUSTER STAMPS of the scatter class (SURFACES_MASTER_PLAN DS-11): `leaf_litter`, `pebbles`, `dirt`, `oil`,
## three macro-patterns each, written as `ASSETS/materials/_generic/decals/decal_patch_<kind>_<n>.png` (RGBA, 512 x 512).
##
## A stamp is SEVERAL marks baked into ONE image: one quad on the floor is a handful of leaves or a scatter of pebbles, so a forest floor is
## tens of quads, not hundreds. The map instances a stamp many times at varied positions, rotations and scales (`ground_scatter`), so the
## repetition a player could notice is broken by rotation, scale and by mixing kinds, not by authoring more art. The edges fall off softly
## (a stamp overlaps its neighbours: it must not read as a square).
##
## Procedural and seeded, so the (git-ignored) PNGs are reproducible from this file. `leaf_litter` is built from the single leaf art
## (`decal_patch_leaf_0.png`): when the Director redraws the leaf, re-run this script and every stamp follows. Sizes in GU per kind are
## in `surfaces/rules.json`.
##
##     python3 tools/asset_generation/gen_scatter_stamps.py
##     /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import

import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy.ndimage import gaussian_filter

ROOT = Path(__file__).resolve().parents[2]
DECALS = ROOT / "ASSETS" / "materials" / "_generic" / "decals"
S = 512


def norm(a: np.ndarray) -> np.ndarray:
    return (a - a.mean()) / (a.std() + 1e-9)


def soft_disc(rng: np.random.Generator, count: int, falloff: float = 0.85) -> list[tuple[float, float]]:
    """`count` points inside the stamp, denser toward the middle so the edge thins out."""
    pts = []
    while len(pts) < count:
        r = (rng.random() ** 0.8) * falloff * (S / 2.0 - 40)
        a = rng.random() * 2 * np.pi
        pts.append((S / 2.0 + r * np.cos(a), S / 2.0 + r * np.sin(a)))
    return pts


def save(kind: str, n: int, img: Image.Image) -> None:
    out = DECALS / ("decal_patch_%s_%d.png" % (kind, n))
    img.save(out)
    a = np.array(img)[..., 3]
    print("[STAMPS] %s_%d: alpha coverage %.0f%%, max alpha %d -> %s" % (kind, n, 100.0 * (a > 8).mean(), a.max(), out.relative_to(ROOT)))


def leaf_litter(rng: np.random.Generator, n: int) -> Image.Image:
    """Leaves scattered over the stamp, each the single leaf art rotated, scaled and tinted (green to yellow to brown)."""
    src = DECALS / "decal_patch_leaf_0.png"
    leaf = Image.open(src).convert("RGBA")
    leaf = leaf.crop(leaf.getbbox())
    canvas = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    tints = [(1.00, 1.00, 1.00), (1.15, 1.05, 0.55), (1.20, 0.80, 0.40), (0.95, 0.60, 0.30), (0.75, 0.80, 0.45)]
    for (x, y) in soft_disc(rng, int(rng.integers(16, 24))):
        scale = rng.uniform(0.18, 0.34) * S / max(leaf.size)
        im = leaf.resize((max(2, int(leaf.width * scale)), max(2, int(leaf.height * scale))), Image.LANCZOS)
        im = im.rotate(float(rng.uniform(0, 360)), expand=True, resample=Image.BICUBIC)
        t = tints[int(rng.integers(len(tints)))]
        arr = np.array(im).astype(float)
        arr[..., :3] = np.clip(arr[..., :3] * np.array(t) * rng.uniform(0.85, 1.1), 0, 255)
        edge = np.hypot(x - S / 2.0, y - S / 2.0) / (S / 2.0)
        arr[..., 3] *= float(np.clip(1.15 - edge * 0.55, 0.35, 1.0))
        im = Image.fromarray(arr.astype(np.uint8), "RGBA")
        canvas.alpha_composite(im, (int(x - im.width / 2), int(y - im.height / 2)))
    return canvas


def pebbles(rng: np.random.Generator, n: int) -> Image.Image:
    """Pebbles: rounded stones with a lit top left, a dark rim bottom right and a short shadow."""
    yy, xx = np.mgrid[0:S, 0:S].astype(float)
    rgb = np.zeros((S, S, 3))
    alpha = np.zeros((S, S))
    shadow = np.zeros((S, S))
    palette = [(0.52, 0.50, 0.47), (0.40, 0.38, 0.36), (0.62, 0.58, 0.52), (0.46, 0.42, 0.38), (0.55, 0.53, 0.55)]
    for (x, y) in soft_disc(rng, int(rng.integers(22, 34)), 0.9):
        a, b = rng.uniform(7, 20), rng.uniform(6, 15)
        ang = rng.uniform(0, np.pi)
        dx, dy = xx - x, yy - y
        u = dx * np.cos(ang) + dy * np.sin(ang)
        v = -dx * np.sin(ang) + dy * np.cos(ang)
        d = (u / a) ** 2 + (v / b) ** 2
        inside = d < 1.0
        h = np.sqrt(np.clip(1.0 - d, 0, 1))
        light = np.clip(0.62 + 0.55 * (-(dx * 0.6 + dy * 0.8) / (max(a, b) * 1.2)) * h + 0.25 * h, 0.25, 1.25)
        col = np.array(palette[int(rng.integers(len(palette)))]) * rng.uniform(0.85, 1.15)
        rgb[inside] = (col[None, :] * light[inside][:, None])
        alpha[inside] = 1.0
        sd = ((u - 3.0) / (a * 1.15)) ** 2 + ((v - 4.0) / (b * 1.15)) ** 2
        shadow = np.maximum(shadow, np.clip(1.2 - sd, 0, 1) * 0.5)
    out = np.zeros((S, S, 4))
    out[..., :3] = np.where(alpha[..., None] > 0, rgb, 0.05)
    out[..., 3] = np.clip(np.maximum(alpha, shadow * (1.0 - alpha)), 0, 1)
    return Image.fromarray((np.clip(out, 0, 1) * 255).astype(np.uint8), "RGBA")


def dirt(rng: np.random.Generator, n: int) -> Image.Image:
    """A soft, irregular patch of bare dirt: noise-shaped alpha that feathers to nothing at the edge, mottled brown."""
    yy, xx = np.mgrid[0:S, 0:S].astype(float)
    r = np.hypot(xx - S / 2.0, yy - S / 2.0) / (S / 2.0)
    shape = norm(gaussian_filter(rng.normal(size=(S, S)), 28)) * 0.35 + norm(gaussian_filter(rng.normal(size=(S, S)), 9)) * 0.12
    mask = np.clip((0.95 - r) * 2.2 + shape, 0, 1)
    mask = mask * mask * (3 - 2 * mask)
    mask *= np.clip((0.97 - r) * 6.0, 0, 1)         # hard zero before the image edge: a stamp never ends in a straight cut
    mott = norm(gaussian_filter(rng.normal(size=(S, S)), 5))
    fine = norm(gaussian_filter(rng.normal(size=(S, S)), 1.2))
    base = np.array([0.36, 0.26, 0.17])
    rgb = base[None, None, :] * (1.0 + 0.16 * mott[..., None] + 0.07 * fine[..., None])
    out = np.zeros((S, S, 4))
    out[..., :3] = np.clip(rgb, 0, 1)
    out[..., 3] = mask * 0.82
    return Image.fromarray((out * 255).astype(np.uint8), "RGBA")


def oil(rng: np.random.Generator, n: int) -> Image.Image:
    """An oil stain: a dark, glossy, noise-edged puddle with a rainbow sheen, and a few drops around it."""
    yy, xx = np.mgrid[0:S, 0:S].astype(float)

    def blob(cx, cy, rad, wobble):
        ang = np.arctan2(yy - cy, xx - cx)
        warp = 1.0 + wobble * (np.sin(3 * ang + rng.uniform(0, 6)) * 0.5 + np.sin(5 * ang + rng.uniform(0, 6)) * 0.3
                               + np.sin(2 * ang + rng.uniform(0, 6)) * 0.4)
        d = np.hypot(xx - cx, yy - cy) / (rad * warp)
        return np.clip((1.0 - d) * 6.0, 0, 1)
    mask = blob(S / 2.0, S / 2.0, rng.uniform(95, 125), 0.22)
    for _ in range(int(rng.integers(4, 9))):
        a = rng.uniform(0, 2 * np.pi)
        r = rng.uniform(130, 190)
        mask = np.maximum(mask, blob(S / 2.0 + r * np.cos(a), S / 2.0 + r * np.sin(a), rng.uniform(5, 14), 0.1))
    sheen = np.sin((xx * 0.021 + yy * 0.015) + 4.0 * norm(gaussian_filter(rng.normal(size=(S, S)), 24))) * 0.5 + 0.5
    base = np.array([0.045, 0.045, 0.05])
    tint = np.stack([0.05 * sheen, 0.025 + 0.05 * (1 - sheen), 0.06 + 0.04 * sheen], axis=-1)
    spec = np.clip(norm(gaussian_filter(rng.normal(size=(S, S)), 7)) * 0.5 - 0.6, 0, 1)
    rgb = np.clip(base[None, None, :] + tint * mask[..., None] + 0.45 * spec[..., None] * mask[..., None], 0, 1)
    out = np.zeros((S, S, 4))
    out[..., :3] = rgb
    out[..., 3] = mask * 0.88
    return Image.fromarray((out * 255).astype(np.uint8), "RGBA")


# ── SINGLES: one mark each, 256 px, three variants; small (0.3-0.8 GU) so they mix with the stamps and break up their repetition ──
SS = 256


def _single_canvas() -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    yy, xx = np.mgrid[0:SS, 0:SS].astype(float)
    return xx, yy, np.zeros((SS, SS, 4))


def _to_image(arr: np.ndarray) -> Image.Image:
    return Image.fromarray((np.clip(arr, 0, 1) * 255).astype(np.uint8), "RGBA")


def _one_leaf(n: int) -> Image.Image:
    """One leaf of the leaf art: the art is a PAIR, so the connected parts of its alpha are separated and one of them (n mod parts) is
    cut out."""
    from scipy.ndimage import label
    art = Image.open(DECALS / "decal_patch_leaf_0.png").convert("RGBA")
    alpha = np.array(art)[..., 3]
    labels, count = label(alpha > 24)
    if count < 2:
        return art.crop(art.getbbox())
    sizes = [(labels == i).sum() for i in range(1, count + 1)]
    keep = [i + 1 for i in sorted(range(count), key=lambda k: -sizes[k])[:2]]
    part = keep[n % len(keep)]
    arr = np.array(art)
    arr[..., 3] = np.where(labels == part, arr[..., 3], 0)
    one = Image.fromarray(arr, "RGBA")
    return one.crop(one.getbbox())


def leaf_single(rng: np.random.Generator, n: int) -> Image.Image:
    """ONE leaf (the leaf art, tinted and turned), filling most of its quad."""
    leaf = _one_leaf(n)
    scale = 0.86 * SS / max(leaf.size)
    im = leaf.resize((max(2, int(leaf.width * scale)), max(2, int(leaf.height * scale))), Image.LANCZOS)
    im = im.rotate(float(rng.uniform(0, 360)), expand=True, resample=Image.BICUBIC)
    tint = [(1.0, 1.0, 1.0), (1.2, 0.95, 0.5), (1.0, 0.62, 0.3)][n % 3]
    arr = np.array(im).astype(float)
    arr[..., :3] = np.clip(arr[..., :3] * np.array(tint), 0, 255)
    im = Image.fromarray(arr.astype(np.uint8), "RGBA")
    canvas = Image.new("RGBA", (SS, SS), (0, 0, 0, 0))
    im.thumbnail((SS - 8, SS - 8))
    canvas.alpha_composite(im, ((SS - im.width) // 2, (SS - im.height) // 2))
    return canvas


def pebble(rng: np.random.Generator, n: int) -> Image.Image:
    """ONE stone, lit from the top left, with a short shadow."""
    xx, yy, out = _single_canvas()
    a, b = rng.uniform(70, 100), rng.uniform(55, 85)
    ang = rng.uniform(0, np.pi)
    dx, dy = xx - SS / 2.0, yy - SS / 2.0
    u = dx * np.cos(ang) + dy * np.sin(ang)
    v = -dx * np.sin(ang) + dy * np.cos(ang)
    d = (u / a) ** 2 + (v / b) ** 2
    h = np.sqrt(np.clip(1.0 - d, 0, 1))
    light = np.clip(0.62 + 0.5 * (-(dx * 0.6 + dy * 0.8) / (max(a, b) * 1.2)) * h + 0.25 * h, 0.25, 1.25)
    col = np.array([(0.52, 0.50, 0.47), (0.40, 0.38, 0.36), (0.60, 0.55, 0.48)][n % 3]) * rng.uniform(0.9, 1.1)
    grain = 1.0 + 0.06 * norm(gaussian_filter(rng.normal(size=(SS, SS)), 1.2))
    inside = d < 1.0
    sd = ((u - 8.0) / (a * 1.12)) ** 2 + ((v - 10.0) / (b * 1.12)) ** 2
    shadow = np.clip(1.2 - sd, 0, 1) * 0.45
    out[..., :3] = np.where(inside[..., None], col[None, None, :] * (light * grain)[..., None], 0.04)
    out[..., 3] = np.clip(np.maximum(inside.astype(float), shadow * (~inside)), 0, 1)
    return _to_image(out)


def twig(rng: np.random.Generator, n: int) -> Image.Image:
    """A thin dry twig with a fork: a bent stroke, darker at the edge, lit from above."""
    xx, yy, out = _single_canvas()
    alpha = np.zeros((SS, SS))
    ang0 = rng.uniform(0, 2 * np.pi)

    def stroke(x0, y0, ang, length, width, bend):
        a = ang
        x, y = x0, y0
        for t in range(int(length)):
            a += bend * rng.normal(0, 0.012)
            x += np.cos(a)
            y += np.sin(a)
            w = width * (1.0 - 0.55 * t / length)
            d = np.hypot(xx - x, yy - y)
            alpha[:] = np.maximum(alpha, np.clip((w - d) * 1.4, 0, 1))
        return x, y, a
    ex, ey, ea = stroke(SS / 2.0 - np.cos(ang0) * 90, SS / 2.0 - np.sin(ang0) * 90, ang0, 185, 6.5, 1.0)
    mx = SS / 2.0 - np.cos(ang0) * 20
    my = SS / 2.0 - np.sin(ang0) * 20
    stroke(mx, my, ang0 + rng.choice([-0.6, 0.6]), 62, 3.8, 1.4)
    grain = norm(gaussian_filter(rng.normal(size=(SS, SS)), 1.0))
    base = np.array([0.30, 0.21, 0.13])
    out[..., :3] = np.clip(base[None, None, :] * (1.0 + 0.2 * grain[..., None]), 0, 1)
    out[..., 3] = alpha
    return _to_image(out)


def dirt_spot(rng: np.random.Generator, n: int) -> Image.Image:
    """A small soft patch of bare dirt."""
    xx, yy, out = _single_canvas()
    r = np.hypot(xx - SS / 2.0, yy - SS / 2.0) / (SS / 2.0)
    shape = norm(gaussian_filter(rng.normal(size=(SS, SS)), 16)) * 0.3
    mask = np.clip((0.85 - r) * 2.6 + shape, 0, 1)
    mask = mask * mask * (3 - 2 * mask) * np.clip((0.96 - r) * 6.0, 0, 1)
    mott = norm(gaussian_filter(rng.normal(size=(SS, SS)), 4))
    out[..., :3] = np.clip(np.array([0.36, 0.26, 0.17])[None, None, :] * (1.0 + 0.16 * mott[..., None]), 0, 1)
    out[..., 3] = mask * 0.85
    return _to_image(out)


def oil_drop(rng: np.random.Generator, n: int) -> Image.Image:
    """One or two small glossy oil drops."""
    xx, yy, out = _single_canvas()
    alpha = np.zeros((SS, SS))
    for _ in range(int(rng.integers(1, 3))):
        cx, cy = SS / 2.0 + rng.uniform(-50, 50), SS / 2.0 + rng.uniform(-50, 50)
        rad = rng.uniform(34, 62)
        ang = np.arctan2(yy - cy, xx - cx)
        warp = 1.0 + 0.18 * np.sin(3 * ang + rng.uniform(0, 6)) + 0.1 * np.sin(5 * ang + rng.uniform(0, 6))
        alpha = np.maximum(alpha, np.clip((1.0 - np.hypot(xx - cx, yy - cy) / (rad * warp)) * 5.0, 0, 1))
    spec = np.clip(norm(gaussian_filter(rng.normal(size=(SS, SS)), 5)) * 0.5 - 0.7, 0, 1)
    out[..., :3] = np.clip(np.array([0.045, 0.045, 0.05])[None, None, :] + 0.4 * spec[..., None], 0, 1)
    out[..., 3] = alpha * 0.88
    return _to_image(out)


STAMPS = {"leaf_litter": leaf_litter, "pebbles": pebbles, "dirt": dirt, "oil": oil,
          "leaf_single": leaf_single, "pebble": pebble, "twig": twig, "dirt_spot": dirt_spot, "oil_drop": oil_drop}


def main() -> int:
    if not (DECALS / "decal_patch_leaf_0.png").exists():
        print("[STAMPS] decal_patch_leaf_0.png is missing: leaf_litter cannot be built")
        return 1
    for k, (kind, fn) in enumerate(STAMPS.items()):
        for n in range(3):
            save(kind, n, fn(np.random.default_rng(5000 + k * 10 + n), n))
    return 0


if __name__ == "__main__":
    sys.exit(main())
