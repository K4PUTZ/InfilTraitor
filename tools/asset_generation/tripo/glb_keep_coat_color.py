# glb_keep_coat_color.py — copy the coat's COLOR_0 (D94's push data: direction in alpha, DecalMask in blue) from one Agent GLB into another
# whose coat has the same vertices (2026-11-06). Blender's round trip of a finished Agent writes that alpha as 1.0 (the skirt tips glued, the
# coat through the legs), so a re-dress of a finished Agent (tripo_surface.py) is followed by this. Plain Python, edits KEEP_DST in place.
# The two may store it in different types (8 or 16 bit, float): the values are converted.
# Usage: python3 glb_keep_coat_color.py <source.glb> <dest.glb>
import json, struct, sys


def coat_color(b):
    n = struct.unpack("<I", b[12:16])[0]; j = json.loads(b[20:20 + n]); base = 20 + n + 8
    m = [m for m in j["meshes"] if m["name"] == "Outfit_Coat"]
    if not m:
        sys.exit("glb_keep_coat_color: no Outfit_Coat")
    a = j["accessors"][m[0]["primitives"][0]["attributes"]["COLOR_0"]]; bv = j["bufferViews"][a["bufferView"]]
    if bv.get("byteStride") not in (None, {5126: 16, 5123: 8, 5121: 4}[a["componentType"]]):
        sys.exit("glb_keep_coat_color: interleaved COLOR_0")
    return base + bv.get("byteOffset", 0) + a.get("byteOffset", 0), {5126: 4, 5123: 2, 5121: 1}[a["componentType"]] * 4 * a["count"], a["componentType"]


src = open(sys.argv[1], "rb").read(); dst = bytearray(open(sys.argv[2], "rb").read())
s0, ss, ts = coat_color(src); d0, ds, td = coat_color(bytes(dst))
import numpy as np
DT = {5126: np.float32, 5123: np.uint16, 5121: np.uint8}
def as_float(raw, t):
    a = np.frombuffer(raw, DT[t]).astype(np.float64)
    return a if t == 5126 else a / np.iinfo(DT[t]).max
vals = as_float(src[s0:s0 + ss], ts)
if len(vals) * {5126: 4, 5123: 2, 5121: 1}[td] != ds:
    sys.exit(f"glb_keep_coat_color: the coats differ ({len(vals) // 4} / {ds // ({5126: 4, 5123: 2, 5121: 1}[td] * 4)} vertices)")
out = vals.astype(np.float32) if td == 5126 else np.round(vals * np.iinfo(DT[td]).max).astype(DT[td])   # the source's values in the dest's type
dst[d0:d0 + ds] = out.tobytes(); open(sys.argv[2], "wb").write(dst)
print(f"[glb_keep_coat_color] {sys.argv[2]}: coat COLOR_0 ({ss} bytes) from {sys.argv[1]}")
