#!/usr/bin/env python3
"""
d33_part3d_fixture_gen.py — D33 Part 3d (ceiling DENTED) equality-proof
fixtures. Same discipline as Parts 2/3b/3c: real, unmodified
generate_voxel.py functions.

Run from repo root:
    python3 tools/asset_generation/d33_part3d_fixture_gen.py

Writes to godot/scripts/tools/fixtures/d33_part3d/:
    atom.png    — generate_voxel_atom(concrete) — the substrate carved
    bottom.png  — generate_dented_voxel(atom, atom, "bottom") — the reference
                  (generate_half_voxel(concrete, "bottom") delegates to
                  exactly this call, per its own docstring)
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

import generate_voxel as gv

FIXTURE_DIR = Path("godot/scripts/tools/fixtures/d33_part3d")


def main() -> None:
    FIXTURE_DIR.mkdir(parents=True, exist_ok=True)

    concrete = gv.MATERIALS["concrete"]
    atom = gv.generate_voxel_atom(concrete)
    bottom = gv.generate_dented_voxel(atom, atom, "bottom")

    atom.save(FIXTURE_DIR / "atom.png", "PNG")
    bottom.save(FIXTURE_DIR / "bottom.png", "PNG")

    print(f"Wrote fixtures to {FIXTURE_DIR}/:")
    print("  atom.png")
    print("  bottom.png")

    print("\nGeometry used (must match the GDScript port exactly):")
    print(f"  V_WB={gv.V_WB} V_SB={gv.V_SB} V_EB={gv.V_EB}")
    print(f"  DENTED_CUT_DEPTH={gv.DENTED_CUT_DEPTH}")


if __name__ == "__main__":
    main()
