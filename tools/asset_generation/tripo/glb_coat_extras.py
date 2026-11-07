# glb_coat_extras.py — set one key of the coat node's glTF `extras` in a finished Agent GLB, touching nothing else (2026-11-07).
# The binary chunk is copied byte for byte; only the JSON chunk is rewritten (glb_swap_image.py's lesson: a Blender round trip of a finished Agent loses the coat's COLOR_0).
# The value is the JSON file's text, stored as a string, the way `coat_push` is (Godot hands `extras` over as the node's metadata).
# Usage: python3 glb_coat_extras.py <agent.glb> <key> <value.json>   (edits the GLB in place)
import json, struct, sys

path, key, src = sys.argv[1], sys.argv[2], sys.argv[3]
b = open(path, "rb").read()
jlen = struct.unpack("<I", b[12:16])[0]; j = json.loads(b[20:20 + jlen]); rest = b[20 + jlen:]
meshes = [k for k, m in enumerate(j["meshes"]) if m["name"] == "Outfit_Coat"]
nodes = [nd for nd in j["nodes"] if nd.get("mesh") in meshes]
if len(nodes) != 1:
    sys.exit(f"glb_coat_extras: {len(nodes)} coat nodes in {path}")
value = json.dumps(json.load(open(src)), separators=(",", ":"))
nodes[0].setdefault("extras", {})[key] = value
js = json.dumps(j, separators=(",", ":")).encode(); js += b" " * ((4 - len(js) % 4) % 4)
out = struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(js) + len(rest)) + struct.pack("<II", len(js), 0x4E4F534A) + js + rest
open(path, "wb").write(out)
print(f"[glb_coat_extras] {path}: coat extras {key} = {value}")
