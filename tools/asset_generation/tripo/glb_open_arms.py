#!/usr/bin/env python3
"""Open both arms of a bank clip by N degrees, IN THE CLIP's DATA (a byte edit of the .glb's animation; Director 2026-11-14: "transferir os 6º pro
Blender e tirar isso do código", the layer `TripoFigure._open_arms` used to add at build time was a trap for whoever reads the clip elsewhere).

The rotation is the one the code applied: about the figure's front axis (+Z of the skeleton) expressed in the shoulder's PARENT frame at REST, put BEFORE
each key of <side>Arm (q' = layer * q), the sign per arm so both open outward (its forearm lies on the +x or -x side at rest).

Usage: glb_open_arms.py <clip.glb> <degrees>      (in place; keep a copy)
"""
import json
import math
import struct
import sys

import numpy as np


def qmul(a, b):
    ax, ay, az, aw = a
    bx, by, bz, bw = b
    return (aw * bx + ax * bw + ay * bz - az * by, aw * by - ax * bz + ay * bw + az * bx, aw * bz + ax * by - ay * bx + az * bw, aw * bw - ax * bx - ay * by - az * bz)


def qrot(q, v):
    x, y, z, w = q
    u = np.array([x, y, z])
    v = np.array(v, dtype=float)
    return 2.0 * u.dot(v) * u + (w * w - u.dot(u)) * v + 2.0 * w * np.cross(u, v)


def main():
    path, degrees = sys.argv[1], float(sys.argv[2])
    data = bytearray(open(path, "rb").read())
    jlen = struct.unpack("<I", data[12:16])[0]
    doc = json.loads(data[20:20 + jlen])
    bin_start = 28 + jlen
    nodes = doc["nodes"]
    parent = {c: i for i, n in enumerate(nodes) for c in n.get("children", [])}
    joints = set(doc["skins"][0]["joints"])

    def global_rest(i):
        """(rotation, origin) of joint node i relative to the skeleton (the product over joint ancestors only)"""
        chain = []
        while i is not None and i in joints:
            chain.append(i)
            i = parent.get(i)
        rot, org = (0.0, 0.0, 0.0, 1.0), np.zeros(3)
        for j in reversed(chain):
            n = nodes[j]
            org = org + qrot(rot, n.get("translation", [0, 0, 0]))
            rot = qmul(rot, tuple(n.get("rotation", [0, 0, 0, 1])))
        return rot, org

    def find(name):
        for i, n in enumerate(nodes):
            if i in joints and n.get("name", "").split(":")[-1].split("_")[-1] == name:
                return i
        sys.exit(f"[glb_open_arms] no joint {name} in {path}")

    done = 0
    for side in ("Left", "Right"):
        arm, fore = find(side + "Arm"), find(side + "ForeArm")
        out = math.copysign(1.0, global_rest(fore)[1][0] - global_rest(arm)[1][0])
        prot = global_rest(parent[arm])[0]
        inv = (-prot[0], -prot[1], -prot[2], prot[3])
        axis = qrot(inv, (0.0, 0.0, 1.0))
        axis = axis / np.linalg.norm(axis)
        half = math.radians(degrees) * out * 0.5
        layer = (axis[0] * math.sin(half), axis[1] * math.sin(half), axis[2] * math.sin(half), math.cos(half))
        for anim in doc.get("animations", []):
            for ch in anim["channels"]:
                if ch["target"].get("node") != arm or ch["target"]["path"] != "rotation":
                    continue
                acc = doc["accessors"][anim["samplers"][ch["sampler"]]["output"]]
                view = doc["bufferViews"][acc["bufferView"]]
                if acc["componentType"] != 5126 or view.get("byteStride", 16) != 16:
                    sys.exit("[glb_open_arms] a rotation output that is not plain float VEC4: not handled")
                start = bin_start + view.get("byteOffset", 0) + acc.get("byteOffset", 0)
                for k in range(acc["count"]):
                    o = start + 16 * k
                    q = struct.unpack("<4f", data[o:o + 16])
                    data[o:o + 16] = struct.pack("<4f", *qmul(layer, q))
                done += acc["count"]
    open(path, "wb").write(data)
    print(f"[glb_open_arms] {path}: both arms opened {degrees} deg on {done} keys")


if __name__ == "__main__":
    main()
