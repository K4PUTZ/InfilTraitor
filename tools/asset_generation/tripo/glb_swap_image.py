# glb_swap_image.py — replace ONE embedded image of a finished Agent GLB by a PNG, touching nothing else (2026-11-06).
# Why: re-dressing a finished Agent through Blender (tripo_surface.py) rewrites every mesh, and the coat's COLOR_0 (D94's push data) does not
# survive it (its alpha written as 1.0, or the attribute exported as VEC3). A texture change needs no geometry: this re-packs the GLB's binary
# chunk with the image's bufferView swapped and every offset shifted, the JSON otherwise unchanged.
# Usage: python3 glb_swap_image.py <agent.glb> <image name in the GLB> <new.png>   (edits the GLB in place)
import json, struct, sys

path, name, png = sys.argv[1], sys.argv[2], sys.argv[3]
b = open(path, "rb").read()
jlen = struct.unpack("<I", b[12:16])[0]; j = json.loads(b[20:20 + jlen])
bin_off = 20 + jlen + 8; bin_len = struct.unpack("<I", b[20 + jlen:24 + jlen])[0]; BIN = b[bin_off:bin_off + bin_len]
imgs = [i for i, im in enumerate(j["images"]) if im.get("name") == name]
if len(imgs) != 1:
    sys.exit(f"glb_swap_image: {len(imgs)} images named {name} in {path}")
target = j["images"][imgs[0]]["bufferView"]
new = open(png, "rb").read()
if new[:8] != b"\x89PNG\r\n\x1a\n":
    sys.exit(f"glb_swap_image: {png} is not a PNG")
out = bytearray()
for i, bv in enumerate(j["bufferViews"]):
    data = new if i == target else BIN[bv.get("byteOffset", 0):bv.get("byteOffset", 0) + bv["byteLength"]]
    while len(out) % 4:
        out.append(0)
    bv["byteOffset"] = len(out); bv["byteLength"] = len(data); out += data
while len(out) % 4:
    out.append(0)
j["buffers"][0]["byteLength"] = len(out)
js = json.dumps(j, separators=(",", ":")).encode()
js += b" " * ((4 - len(js) % 4) % 4)
glb = struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(out)) + struct.pack("<II", len(js), 0x4E4F534A) + js + struct.pack("<II", len(out), 0x004E4942) + out
open(path, "wb").write(glb)
print(f"[glb_swap_image] {path}: {name} <- {png} ({len(new)} bytes)")
