#!/usr/bin/env python3
"""Remove one morph target from a mesh of a finished Agent .glb, as a BYTE edit (the counterpart of glb_add_morph.py; ACTOR D108).

The target's entry, weight and name go; its accessors stay in the buffer unreferenced (a few KiB; the next full build drops them).
Godot finds blend shapes by NAME, so the other targets' new indices change nothing.

Usage: glb_remove_morph.py <in.glb> <out.glb> <mesh name> <morph name>
"""
import sys

from glb_add_morph import read_glb, write_glb


def main():
    if len(sys.argv) != 5:
        sys.exit(__doc__)
    src, dst, mesh_name, morph = sys.argv[1:]
    doc, blob = read_glb(src)
    meshes = [m for m in doc["meshes"] if m["name"] == mesh_name]
    if len(meshes) != 1:
        sys.exit(f"[glb_remove_morph] '{mesh_name}' is not one mesh")
    mesh = meshes[0]
    names = mesh.get("extras", {}).get("targetNames", [])
    if morph not in names:
        sys.exit(f"[glb_remove_morph] no morph '{morph}' on {mesh_name}: {names}")
    i = names.index(morph)
    names.pop(i)
    for prim in mesh["primitives"]:
        prim["targets"].pop(i)
    if "weights" in mesh:
        mesh["weights"].pop(i)
    write_glb(dst, doc, blob)
    print(f"[glb_remove_morph] {morph} removed from {mesh_name}; targets now {names}")


if __name__ == "__main__":
    main()
