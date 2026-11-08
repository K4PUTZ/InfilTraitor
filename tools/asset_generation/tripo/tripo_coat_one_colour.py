# tripo_coat_one_colour.py — the coat with BOTH SIDES in the outer colour (Director, 2026-11-08: a PROVISIONAL solution for the black patches, see `CHARACTER` §7a and the note in
# `docs/production/technical_debt.md`).
#
# The POLICE coat's map paints the outer wall mustard and the lining black, and on the LIGHT the lining comes out through the outer wall in wedges. Until the coat is fixed or regenerated
# (optimization phase), nothing on the coat is black: every texel of the lining colour takes the outer colour, in the outer cloth's own grain (a mirrored tiling of the largest all-cloth
# square of the same map, so a repainted patch does not read as a flat fill). Empty UV space is filled too, which keeps a mip level from bleeding black into the islands' borders.
# Everything else stays exact: the outer cloth, the buttons (a dark grey well above the lining's colour) and the ALPHA, which still says the wall (`actor_coat3d.gdshader`).
# The shader draws a face seen from its back in the other wall's colour, so the `coat_sides` extras get lining = outer as well.
#
# The two-sided source is NOT touched (`painted/<fig>_coat_police_light.png`): to go back, run glb_swap_image.py with it and glb_coat_extras.py with the lining's colour (#0B0B0D).
#
# Usage: python3 tripo_coat_one_colour.py <female|male> [--install]     (--install puts the map and the extras into AGENT_<FIG>_LIGHT.glb, byte edits; then reimport)
import json, os, struct, subprocess, sys
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OFFICIAL = os.path.abspath(os.path.join(HERE, "..", "..", "..", "ASSETS", "MODELS", "official"))
LINING_MAX = 24      # a texel whose brightest channel is at most this is the lining (#0B0B0D) or empty UV space (0, 0, 0); the buttons start at 32
CLOTH_MIN_R = 120    # the mustard cloth's red channel starts well above this


def largest_cloth_square(cloth):
    """(x, y, side) of the largest axis-aligned square that is all cloth: a binary search on the side over a summed-area table"""
    h, w = cloth.shape
    sat = np.zeros((h + 1, w + 1), np.int64)
    sat[1:, 1:] = cloth.astype(np.int64).cumsum(0).cumsum(1)
    lo, hi, found = 1, min(h, w), None
    while lo <= hi:
        s = (lo + hi) // 2
        full = sat[s:, s:] - sat[:-s, s:] - sat[s:, :-s] + sat[:-s, :-s] == s * s
        if full.any():
            y, x = np.unravel_index(np.argmax(full), full.shape)
            found = (int(x), int(y), s)
            lo = s + 1
        else:
            hi = s - 1
    if found is None:
        sys.exit("tripo_coat_one_colour: the map has no cloth")
    return found


def glb_coat_sides(glb):
    b = open(glb, "rb").read()
    jl = struct.unpack("<I", b[12:16])[0]
    j = json.loads(b[20:20 + jl])
    nodes = [n for n in j["nodes"] if n.get("name") == "Outfit_Coat"]
    if len(nodes) != 1 or "coat_sides" not in nodes[0].get("extras", {}):
        sys.exit(f"tripo_coat_one_colour: no coat_sides in {glb}")
    return json.loads(nodes[0]["extras"]["coat_sides"])


def main():
    if len(sys.argv) < 2 or sys.argv[1] not in ("female", "male"):
        sys.exit("usage: tripo_coat_one_colour.py <female|male> [--install]")
    fig = sys.argv[1]
    src = os.path.join(OFFICIAL, "painted", f"{fig}_coat_police_light.png")
    out = os.path.join(OFFICIAL, "painted", f"{fig}_coat_police_one_colour_light.png")
    js = os.path.join(OFFICIAL, "painted", f"{fig}_coat_sides_one_colour.json")
    glb = os.path.join(OFFICIAL, f"AGENT_{fig.upper()}_LIGHT.glb")
    a = np.array(Image.open(src).convert("RGBA"))
    fill = a[..., :3].max(axis=2) <= LINING_MAX
    cloth = (a[..., 0] > CLOTH_MIN_R) & ~fill
    x, y, s = largest_cloth_square(cloth)
    tile = a[y:y + s, x:x + s, :3]
    ys, xs = np.nonzero(fill)
    u = xs % (2 * s)
    v = ys % (2 * s)
    u = np.where(u >= s, 2 * s - 1 - u, u)
    v = np.where(v >= s, 2 * s - 1 - v, v)
    b = a.copy()
    b[ys, xs, :3] = tile[v, u]
    Image.fromarray(b, "RGBA").save(out)
    sides = glb_coat_sides(glb)
    with open(js, "w") as f:
        json.dump({"version": 1, "outer": sides["outer"], "lining": sides["outer"]}, f)
    changed = (a[..., :3] != b[..., :3]).any(axis=2)
    print(f"[tripo_coat_one_colour] {fig}: {int(fill.sum())} texels filled from the {s} x {s} cloth square at ({x}, {y}); {int(changed.sum())} changed, {int((changed & ~fill).sum())} outside the fill, alpha unchanged: {bool((a[..., 3] == b[..., 3]).all())}")
    print(f"[tripo_coat_one_colour] wrote {out} and {js} (lining = outer = {sides['outer']})")
    if "--install" in sys.argv:
        subprocess.check_call([sys.executable, os.path.join(HERE, "glb_swap_image.py"), glb, f"{fig}_coat_light", out])
        subprocess.check_call([sys.executable, os.path.join(HERE, "glb_coat_extras.py"), glb, "coat_sides", js])


main()
