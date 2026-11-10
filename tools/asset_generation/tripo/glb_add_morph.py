#!/usr/bin/env python3
"""Add (or replace) one morph target on a mesh of a finished Agent .glb, as a BYTE edit (never a Blender round trip: ACTOR D108).

The data is a JSON with the shape key's coordinates in Blender space, exported from the .blend the Director worked in:
    {"name": "DrawFix", "basis": [[x, y, z], ...], "key": [[x, y, z], ...]}
Blender's order is not trusted: every glTF vertex is matched by POSITION to the nearest Basis vertex (a seam split shares it), and the
run stops if any match is farther than MAX_MATCH_M. POSITION and NORMAL deltas are written; the normals are recomputed on the glTF's own triangles.

Usage: glb_add_morph.py <in.glb> <out.glb> <mesh name> <key.json>
"""
import json
import struct
import sys

import numpy as np

MAX_MATCH_M = 1e-4
COMPONENT_SIZE = {5120: 1, 5121: 1, 5122: 2, 5123: 2, 5125: 4, 5126: 4}
COMPONENT_DTYPE = {5121: "<u1", 5123: "<u2", 5125: "<u4", 5126: "<f4"}
TYPE_COUNT = {"SCALAR": 1, "VEC3": 3}


def read_glb(path):
    data = open(path, "rb").read()
    json_len = struct.unpack("<I", data[12:16])[0]
    doc = json.loads(data[20:20 + json_len])
    bin_len = struct.unpack("<I", data[20 + json_len:24 + json_len])[0]
    return doc, bytearray(data[28 + json_len:28 + json_len + bin_len])


def write_glb(path, doc, blob):
    text = json.dumps(doc, separators=(",", ":")).encode()
    text += b" " * ((4 - len(text) % 4) % 4)
    blob = bytes(blob) + b"\0" * ((4 - len(blob) % 4) % 4)
    total = 12 + 8 + len(text) + 8 + len(blob)
    with open(path, "wb") as out:
        out.write(struct.pack("<III", 0x46546C67, 2, total))
        out.write(struct.pack("<II", len(text), 0x4E4F534A) + text)
        out.write(struct.pack("<II", len(blob), 0x004E4942) + blob)


def accessor(doc, blob, index):
    acc = doc["accessors"][index]
    view = doc["bufferViews"][acc["bufferView"]]
    start = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
    n = TYPE_COUNT[acc["type"]]
    size = COMPONENT_SIZE[acc["componentType"]]
    stride = view.get("byteStride", n * size)
    if stride != n * size:
        sys.exit(f"[glb_add_morph] accessor {index} is interleaved: not handled")
    arr = np.frombuffer(bytes(blob[start:start + acc["count"] * n * size]), dtype=COMPONENT_DTYPE[acc["componentType"]])
    return arr.reshape(-1, n) if n > 1 else arr


def vertex_normals(pos, tris):
    face = np.cross(pos[tris[:, 1]] - pos[tris[:, 0]], pos[tris[:, 2]] - pos[tris[:, 0]])
    out = np.zeros_like(pos)
    for k in range(3):
        np.add.at(out, tris[:, k], face)
    length = np.linalg.norm(out, axis=1, keepdims=True)
    return out / np.maximum(length, 1e-12)


def append_vec3(doc, blob, values, with_bounds):
    blob.extend(b"\0" * ((4 - len(blob) % 4) % 4))
    raw = values.astype("<f4").tobytes()
    doc["bufferViews"].append({"buffer": 0, "byteOffset": len(blob), "byteLength": len(raw)})
    blob.extend(raw)
    acc = {"bufferView": len(doc["bufferViews"]) - 1, "componentType": 5126, "count": len(values), "type": "VEC3"}
    if with_bounds:
        acc["min"] = [float(x) for x in values.min(axis=0)]
        acc["max"] = [float(x) for x in values.max(axis=0)]
    doc["accessors"].append(acc)
    return len(doc["accessors"]) - 1


def main():
    if len(sys.argv) != 5:
        sys.exit(__doc__)
    src, dst, mesh_name, key_path = sys.argv[1:]
    doc, blob = read_glb(src)
    key = json.load(open(key_path))
    meshes = [m for m in doc["meshes"] if m["name"] == mesh_name]
    if len(meshes) != 1 or len(meshes[0]["primitives"]) != 1:
        sys.exit(f"[glb_add_morph] '{mesh_name}' is not one mesh of one primitive")
    mesh = meshes[0]
    prim = mesh["primitives"][0]
    base = accessor(doc, blob, prim["attributes"]["POSITION"]).astype(float)
    tris = accessor(doc, blob, prim["indices"]).astype(int).reshape(-1, 3)
    to_gltf = lambda a: np.stack([a[:, 0], a[:, 2], -a[:, 1]], axis=1)
    k_base = to_gltf(np.array(key["basis"], dtype=float))
    k_key = to_gltf(np.array(key["key"], dtype=float))
    delta_of_key = k_key - k_base
    match = np.empty(len(base), dtype=int)
    worst = 0.0
    for i, p in enumerate(base):
        d = ((k_base - p) ** 2).sum(axis=1)
        match[i] = int(d.argmin())
        worst = max(worst, float(d[match[i]]))
    worst = worst ** 0.5
    if worst > MAX_MATCH_M:
        sys.exit(f"[glb_add_morph] a vertex of the glb is {worst:.6f} from any Basis vertex: this key was not made on this mesh")
    delta = delta_of_key[match]
    moved = np.linalg.norm(delta, axis=1) > 1e-6
    normal_delta = vertex_normals(base + delta, tris) - vertex_normals(base, tris)
    normal_delta[~moved] = 0.0
    target = {"POSITION": append_vec3(doc, blob, delta, True), "NORMAL": append_vec3(doc, blob, normal_delta, False)}
    extras = mesh.setdefault("extras", {})
    names = extras.setdefault("targetNames", [])
    targets = prim.setdefault("targets", [])
    if key["name"] in names:
        targets[names.index(key["name"])] = target
    else:
        names.append(key["name"])
        targets.append(target)
        mesh["weights"] = mesh.get("weights", []) + [0]
    doc["buffers"][0]["byteLength"] = len(blob) + ((4 - len(blob) % 4) % 4)
    write_glb(dst, doc, blob)
    print(f"[glb_add_morph] {key['name']} on {mesh_name}: {int(moved.sum())} of {len(base)} vertices move, largest {np.linalg.norm(delta, axis=1).max():.4f}, worst match {worst:.2e}; targets now {names}")


if __name__ == "__main__":
    main()
