#!/usr/bin/env python3
"""glb_close_opening.py — close a see-through opening in a model's wall with a face of its own, as a BYTE edit of the .glb (MOVEMENT §11.6).

Why (2026-11-26, the Director on the short stock's receiver: "tem um buraco no corpo da arma"; then "poe o fundo preto na janela e pode
instalar"): the pack's `Shotgun Short Stock.glb` models its ejection port as a hole in the receiver's right wall with no floor, and the game
draws one side of a face only, so the far wall and the hand behind the gun show through it. This finds the one open edge loop that lies flat
in a plane facing ACROSS the barrel (the loops facing along it, x, are the barrel's open ends hidden inside the receiver, and stay), and closes
it with one polygon facing outward, in the given material: its vertices (position, a flat normal) and triangles are APPENDED to that
material's primitive. Every other byte of the model is kept: the nodes, the other primitives, the vertices already there and their order
(checked after writing). Only POSITION / NORMAL primitives are handled; anything else fails loudly. A new file; an existing one is refused.

    python3 tools/asset_generation/weapons/glb_close_opening.py <src.glb> <out.glb> [--material Black]
"""
import json
import math
import os
import struct
import sys

WELD = 1e-5          # the model's own units: the coincident copies of a vertex that a per-face export leaves (Blender's remove_doubles default)
FLAT = 1e-4          # a loop is flat across an axis when it spans less than this along it
SPAN = 1e-3          # ... and it must reach along the barrel (x) more than this to be a side wall's opening
COMP = {5121: ("B", 1), 5123: ("H", 2), 5125: ("I", 4)}
GLB, JSON_CHUNK, BIN_CHUNK = 0x46546C67, 0x4E4F534A, 0x004E4942


def fail(msg):
    sys.exit(f"[glb_close_opening] {msg}")


def read_glb(path):
    b = open(path, "rb").read()
    magic, version, _length = struct.unpack_from("<III", b, 0)
    if magic != GLB or version != 2:
        fail(f"{path}: not a binary glTF 2")
    n, kind = struct.unpack_from("<II", b, 12)
    if kind != JSON_CHUNK:
        fail(f"{path}: the first chunk is not JSON")
    j = json.loads(b[20:20 + n])
    m, kind = struct.unpack_from("<II", b, 20 + n)
    if kind != BIN_CHUNK:
        fail(f"{path}: the second chunk is not BIN")
    return j, b[28 + n:28 + n + m]


def write_glb(path, j, data):
    js = json.dumps(j, separators=(",", ":")).encode()
    js += b" " * (-len(js) % 4)
    data += b"\0" * (-len(data) % 4)
    with open(path, "wb") as f:
        f.write(struct.pack("<III", GLB, 2, 12 + 8 + len(js) + 8 + len(data)))
        f.write(struct.pack("<II", len(js), JSON_CHUNK) + js)
        f.write(struct.pack("<II", len(data), BIN_CHUNK) + data)


def accessor_bytes(j, data, i):
    """the accessor's own bytes, tightly packed (a stride, a sparse accessor or a shared offset is refused)"""
    a = j["accessors"][i]
    if "sparse" in a or "bufferView" not in a:
        fail(f"accessor {i}: sparse or without a buffer view")
    v = j["bufferViews"][a["bufferView"]]
    size = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}[a["type"]] * COMP.get(a["componentType"], ("f", 4))[1]
    if v.get("byteStride", size) != size:
        fail(f"accessor {i}: interleaved (stride {v['byteStride']})")
    start = v.get("byteOffset", 0) + a.get("byteOffset", 0)
    return data[start:start + a["count"] * size]


def vec3s(raw):
    return [struct.unpack_from("<3f", raw, k) for k in range(0, len(raw), 12)]


def indices(j, data, i):
    fmt, size = COMP[j["accessors"][i]["componentType"]]
    raw = accessor_bytes(j, data, i)
    return list(struct.unpack(f"<{len(raw) // size}{fmt}", raw))


def weld(points):
    """each point's representative: the first point within WELD of it (a grid of WELD cells, the 27 neighbours searched)"""
    cells, rep = {}, []
    for i, q in enumerate(points):
        c = tuple(int(math.floor(x / WELD)) for x in q)
        found = None
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                for dz in (-1, 0, 1):
                    for k in cells.get((c[0] + dx, c[1] + dy, c[2] + dz), ()):
                        if math.dist(points[k], q) <= WELD:
                            found = k
                            break
                    if found is not None:
                        break
                if found is not None:
                    break
        if found is None:
            cells.setdefault(c, []).append(i)
            rep.append(i)
        else:
            rep.append(rep[found])
    return rep


def ear_clip(pts2):
    """triangles (index triples into pts2, in the polygon's own winding) of a simple polygon"""
    area = sum(pts2[i][0] * pts2[(i + 1) % len(pts2)][1] - pts2[(i + 1) % len(pts2)][0] * pts2[i][1] for i in range(len(pts2)))
    s = 1.0 if area > 0 else -1.0
    cross = lambda o, a, b: (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])

    def inside(p, a, b, c):
        return s * cross(a, b, p) >= 0 and s * cross(b, c, p) >= 0 and s * cross(c, a, p) >= 0

    left, tris = list(range(len(pts2))), []
    while len(left) > 3:
        for k in range(len(left)):
            i0, i1, i2 = left[k - 1], left[k], left[(k + 1) % len(left)]
            a, b, c = pts2[i0], pts2[i1], pts2[i2]
            if s * cross(a, b, c) <= 0:
                continue
            if any(inside(pts2[m], a, b, c) for m in left if m not in (i0, i1, i2)):
                continue
            tris.append((i0, i1, i2))
            left.pop(k)
            break
        else:
            fail("the opening is not a simple polygon: no ear left to cut")
    tris.append(tuple(left))
    return tris


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if len(args) != 2:
        fail("usage: glb_close_opening.py <src.glb> <out.glb> [--material Black]")
    src, out = args
    material = sys.argv[sys.argv.index("--material") + 1] if "--material" in sys.argv else "Black"
    if os.path.exists(out):
        fail(f"{out} exists: not overwritten")
    j, data = read_glb(src)
    if j.get("extensionsRequired") or len(j.get("buffers", [])) != 1 or "uri" in j["buffers"][0]:
        fail("only a plain one-buffer .glb is handled")
    if len(j["meshes"]) != 1:
        fail(f"{len(j['meshes'])} meshes: one expected")
    prims = j["meshes"][0]["primitives"]

    # every triangle of the mesh, welded, to find the open edges
    points, tris = [], []
    for p in prims:
        if p.get("mode", 4) != 4:
            fail("a primitive that is not triangles")
        base = len(points)
        points += vec3s(accessor_bytes(j, data, p["attributes"]["POSITION"]))
        ix = indices(j, data, p["indices"])
        tris += [(base + ix[k], base + ix[k + 1], base + ix[k + 2]) for k in range(0, len(ix), 3)]
    rep = weld(points)
    count = {}
    for t in tris:
        w = [rep[v] for v in t]
        if len(set(w)) < 3:
            continue
        for e in ((w[0], w[1]), (w[1], w[2]), (w[2], w[0])):
            key = (min(e), max(e))
            count[key] = count.get(key, 0) + 1
    open_edges = [e for e, n in count.items() if n == 1]
    links = {}
    for a, b in open_edges:
        links.setdefault(a, []).append(b)
        links.setdefault(b, []).append(a)
    seen, loops = set(), []
    for v in links:
        if v in seen:
            continue
        group, stack = [], [v]
        while stack:
            x = stack.pop()
            if x in seen:
                continue
            seen.add(x)
            group.append(x)
            stack.extend(links[x])
        loops.append(group)
    side = []
    for g in loops:
        ext = [max(points[v][k] for v in g) - min(points[v][k] for v in g) for k in range(3)]
        flat = min(range(3), key=lambda k: ext[k])
        print(f"[glb_close_opening] open loop: {len(g)} vertices, flat across {'xyz'[flat]} ({ext[flat]:.2e}), spans x {ext[0]:.5f}")
        if flat != 0 and ext[flat] < FLAT and ext[0] > SPAN:
            side.append((g, flat))
    if len(side) != 1:
        fail(f"{len(side)} openings facing across the barrel (exactly one wanted)")
    g, axis = side[0]
    if any(len(links[v]) != 2 for v in g):
        fail("the opening's rim is not one simple loop")
    order, prev = [g[0]], None
    while True:
        nxt = [x for x in links[order[-1]] if x != prev]
        if nxt[0] == order[0]:
            break
        prev = order[-1]
        order.append(nxt[0])
    pts = [points[v] for v in order]
    # facing outward: away from the mesh's centre along the flat axis (Newell's normal of the ordered rim tells the winding)
    centre = sum(q[axis] for q in points) / len(points)
    outward = 1.0 if pts[0][axis] > centre else -1.0
    newell = sum((pts[i][(axis + 1) % 3] - pts[(i + 1) % len(pts)][(axis + 1) % 3]) *
                 (pts[i][(axis + 2) % 3] + pts[(i + 1) % len(pts)][(axis + 2) % 3]) for i in range(len(pts)))
    if newell * outward < 0:
        pts.reverse()
    u, w = (axis + 1) % 3, (axis + 2) % 3       # the plane's axes in cyclic order: counter-clockwise seen from +axis stays so in (u, w)
    faces = ear_clip([(q[u], q[w]) for q in pts])
    normal = [0.0, 0.0, 0.0]
    normal[axis] = outward

    # the material's primitive: its accessors must be its own, so they can grow
    mats = [m.get("name") for m in j.get("materials", [])]
    target = [p for p in prims if p.get("material") is not None and mats[p["material"]] == material]
    if len(target) != 1:
        fail(f"{len(target)} primitives in the material {material!r} (materials {mats})")
    p = target[0]
    if set(p["attributes"]) != {"POSITION", "NORMAL"} or p.get("targets"):
        fail(f"the {material} primitive carries {sorted(p['attributes'])}{' and morph targets' if p.get('targets') else ''}: only POSITION / NORMAL is handled")
    edited = {p["attributes"]["POSITION"], p["attributes"]["NORMAL"], p["indices"]}
    for i in edited:
        view = j["accessors"][i]["bufferView"]
        if any(a.get("bufferView") == view for k, a in enumerate(j["accessors"]) if k != i):
            fail(f"accessor {i} shares its buffer view: not handled")
    n0 = j["accessors"][p["attributes"]["POSITION"]]["count"]
    fmt, size = COMP[j["accessors"][p["indices"]]["componentType"]]
    if n0 + len(pts) > {1: 255, 2: 65535, 4: 2 ** 32 - 1}[size]:
        fail("the new vertices do not fit the index type")
    grown = {
        p["attributes"]["POSITION"]: accessor_bytes(j, data, p["attributes"]["POSITION"]) + b"".join(struct.pack("<3f", *q) for q in pts),
        p["attributes"]["NORMAL"]: accessor_bytes(j, data, p["attributes"]["NORMAL"]) + struct.pack("<3f", *normal) * len(pts),
        p["indices"]: accessor_bytes(j, data, p["indices"]) + struct.pack(f"<{3 * len(faces)}{fmt}", *[n0 + k for f in faces for k in f]),
    }
    original = {i: accessor_bytes(j, data, i) for i in range(len(j["accessors"]))}
    by_view = {j["accessors"][i]["bufferView"]: i for i in grown}
    blob = bytearray()
    for vi, v in enumerate(j["bufferViews"]):
        chunk = grown[by_view[vi]] if vi in by_view else data[v.get("byteOffset", 0):v.get("byteOffset", 0) + v["byteLength"]]
        blob += b"\0" * (-len(blob) % 4)
        v["byteOffset"] = len(blob)
        v["byteLength"] = len(chunk)
        blob += chunk
    for i in grown:
        a = j["accessors"][i]
        a["count"] += len(pts) if i != p["indices"] else 3 * len(faces)
        if i == p["attributes"]["POSITION"] or "min" in a:       # POSITION must carry its bounds (the spec); the others keep theirs right if they had any
            if i == p["indices"]:
                vals = struct.unpack(f"<{len(grown[i]) // size}{fmt}", grown[i])
                a["min"], a["max"] = [min(vals)], [max(vals)]
            else:
                allv = vec3s(grown[i])
                a["min"] = [min(q[k] for q in allv) for k in range(3)]
                a["max"] = [max(q[k] for q in allv) for k in range(3)]
    j["buffers"][0]["byteLength"] = len(blob)
    write_glb(out, j, bytes(blob))

    # check what was written: every accessor as it was, the three grown ones starting with their old bytes
    j2, d2 = read_glb(out)
    for i in range(len(j2["accessors"])):
        now = accessor_bytes(j2, d2, i)
        if (now != original[i]) if i not in grown else (now[:len(original[i])] != original[i] or now != grown[i]):
            fail(f"accessor {i} did not survive the rewrite: {out} is wrong, delete it")
    j0, _ = read_glb(src)
    for k in j0:
        if k not in ("accessors", "bufferViews", "buffers") and j0[k] != j2[k]:
            fail(f"the {k!r} section changed: {out} is wrong, delete it")
    print(f"[glb_close_opening] closed a {len(pts)}-edge opening flat across {'xyz'[axis]} at {pts[0][axis]:+.6f} "
          f"(x {min(q[0] for q in pts):+.5f}..{max(q[0] for q in pts):+.5f}, the model's units), facing {'+' if outward > 0 else '-'}{'xyz'[axis]}: "
          f"{len(faces)} triangles in {material}, {n0} -> {n0 + len(pts)} vertices; {len(open_edges) - len(pts)} open edges left")
    print(f"[glb_close_opening] wrote {out}")


if __name__ == "__main__":
    main()
