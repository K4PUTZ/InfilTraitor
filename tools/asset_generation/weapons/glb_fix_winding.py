"""glb_fix_winding.py — turn a GLB's inward-facing triangles out, as a BYTE edit (2026-11-27).

Why: the polypizza grenade launchers ship with every quad as loose geometry and about a fifth to a third of their triangles wound
inward (the 20: 306 of 1512 faces). Blender's Solid view draws both sides and hides it; anything that culls back faces (Material
Preview, the game) shows those parts hollow, the 20's trigger grip first (the Director, 2026-11-27).

How: per mesh primitive (triangles, indexed), the corners are welded by position (rounded to `WELD` m) only to find who touches whom;
the winding is propagated across every edge two triangles share (a shared edge runs opposite ways when both agree), shell by shell;
each shell is then turned so its signed volume is positive (outward). Only the ORDER of each triangle's indices changes (b and c
swapped): positions, normals, UVs, materials and every other byte stay. A flat, open shell (volume ~0) is left as it was.
Vertex NORMALS, if the primitive has them, are flipped for the vertices used only by flipped triangles.

  python3 glb_fix_winding.py <in.glb> [<out.glb>]      (no out: report only)
"""
import json, struct, sys
from collections import defaultdict, deque

import numpy as np

WELD = 1e-5
CT = {5120: "b", 5121: "B", 5122: "h", 5123: "H", 5125: "I", 5126: "f"}
NC = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}


def read_glb(path):
    data = open(path, "rb").read()
    magic, ver, length = struct.unpack_from("<III", data, 0)
    assert magic == 0x46546C67, "not a GLB"
    off, chunks = 12, []
    while off < length:
        clen, ctype = struct.unpack_from("<II", data, off)
        chunks.append([ctype, bytearray(data[off + 8: off + 8 + clen])])
        off += 8 + clen
    return json.loads(chunks[0][1].decode("utf-8")), chunks


def write_glb(path, chunks):
    body = b"".join(struct.pack("<II", len(c), t) + bytes(c) for t, c in chunks)
    open(path, "wb").write(struct.pack("<III", 0x46546C67, 2, 12 + len(body)) + body)


def accessor_view(gj, binc, ai):
    a = gj["accessors"][ai]
    bv = gj["bufferViews"][a["bufferView"]]
    fmt = CT[a["componentType"]]
    n = NC[a["type"]]
    item = struct.calcsize("<" + fmt) * n
    stride = bv.get("byteStride", item)
    start = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
    return a, fmt, n, start, stride


def read_acc(gj, binc, ai):
    a, fmt, n, start, stride = accessor_view(gj, binc, ai)
    out = [struct.unpack_from("<" + fmt * n, binc, start + i * stride) for i in range(a["count"])]
    return np.array(out, dtype=float if fmt == "f" else np.int64), (fmt, n, start, stride)


def orient(pos, tris):
    """the set of triangle indices to flip"""
    key = {tuple(k): i for i, k in enumerate(np.round(pos / WELD).astype(np.int64).tolist())}
    wid = np.array([key[tuple(k)] for k in np.round(pos / WELD).astype(np.int64).tolist()])
    T = wid[tris]
    edges = defaultdict(list)
    for t, (a, b, c) in enumerate(T):
        for u, v in ((a, b), (b, c), (c, a)):
            edges[(min(u, v), max(u, v))].append((t, u < v))
    flip = np.zeros(len(T), bool)
    seen = np.zeros(len(T), bool)
    out = set()
    shells = 0
    for s in range(len(T)):
        if seen[s] or len(set(T[s])) < 3:
            continue
        shells += 1
        seen[s] = True
        q, shell = deque([s]), [s]
        while q:
            t = q.popleft()
            a, b, c = T[t]
            for u, v in ((a, b), (b, c), (c, a)):
                link = edges[(min(u, v), max(u, v))]
                if len(link) != 2:
                    continue        # an open or non-manifold edge carries no orientation
                for o, fwd in link:
                    if o == t or seen[o]:
                        continue
                    mine = (u < v) != flip[t]
                    flip[o] = fwd == mine        # agreeing neighbours run the shared edge opposite ways
                    seen[o] = True
                    q.append(o)
                    shell.append(o)
        P = pos[tris[shell]]
        w = np.where(flip[shell], -1.0, 1.0)
        vol = (w * np.einsum("ij,ij->i", P[:, 0], np.cross(P[:, 1], P[:, 2]))).sum() / 6.0
        scale = np.abs(P).max() ** 3 * 1e-6 + 1e-18
        if vol < -scale:
            flip[shell] = ~flip[shell]
        elif abs(vol) <= scale:
            flip[shell] = False      # flat / open: no inside to point away from
        out.update(int(t) for t in shell if flip[t])
    return out, shells


def main():
    a = sys.argv[1:]
    if not a:
        sys.exit(__doc__)
    gj, chunks = read_glb(a[0])
    binc = chunks[1][1]
    total = 0
    for mi, mesh in enumerate(gj["meshes"]):
        for pi, prim in enumerate(mesh["primitives"]):
            if prim.get("mode", 4) != 4 or "indices" not in prim:
                print(f"[glb_fix_winding] mesh {mi} prim {pi}: not indexed triangles, skipped")
                continue
            pos, _ = read_acc(gj, binc, prim["attributes"]["POSITION"])
            idx, (fmt, n, start, stride) = read_acc(gj, binc, prim["indices"])
            tris = idx.reshape(-1, 3)
            flips, shells = orient(pos, tris)
            total += len(flips)
            print(f"[glb_fix_winding] mesh {mi} '{mesh.get('name', '')}' prim {pi}: {len(tris)} triangles, {shells} shells, {len(flips)} flipped")
            size = struct.calcsize("<" + fmt)
            for t in flips:
                b, c = tris[t][1], tris[t][2]
                struct.pack_into("<" + fmt, binc, start + (3 * t + 1) * size, c)
                struct.pack_into("<" + fmt, binc, start + (3 * t + 2) * size, b)
            if "NORMAL" in prim["attributes"] and flips:
                used_by = defaultdict(set)
                for t, tri in enumerate(tris):
                    for v in tri:
                        used_by[int(v)].add(t)
                nrm, (nf, nn, ns, nst) = read_acc(gj, binc, prim["attributes"]["NORMAL"])
                for v, ts in used_by.items():
                    if ts <= flips:
                        struct.pack_into("<fff", binc, ns + v * nst, *(-nrm[v]))
    print(f"[glb_fix_winding] {a[0]}: {total} triangles flipped")
    if len(a) > 1:
        write_glb(a[1], chunks)
        print(f"[glb_fix_winding] wrote {a[1]}")


if __name__ == "__main__":
    main()
